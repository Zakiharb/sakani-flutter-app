import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

type SendPushBody = {
  token: string; // FCM device token
  title: string;
  body: string;
  data?: Record<string, string>; // optional deep-link / extra payload
};

function json(resBody: unknown, status = 200) {
  return new Response(JSON.stringify(resBody), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

async function getGoogleAccessToken() {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");

  if (!projectId) throw new Error("Missing secret: FIREBASE_PROJECT_ID");
  if (!saJson) throw new Error("Missing secret: FIREBASE_SERVICE_ACCOUNT_JSON");

  let sa: any;
  try {
    sa = JSON.parse(saJson);
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON");
  }

  const clientEmail: string = sa.client_email;
  const privateKeyPem: string = sa.private_key;

  if (!clientEmail || !privateKeyPem) {
    throw new Error("Service account JSON missing client_email/private_key");
  }

  const now = Math.floor(Date.now() / 1000);
  const tokenUrl = "https://oauth2.googleapis.com/token";
  const scope = "https://www.googleapis.com/auth/firebase.messaging";

  const key = await importPKCS8(privateKeyPem, "RS256");

  const jwt = await new SignJWT({ scope })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience(tokenUrl)
    .setIssuedAt(now)
    .setExpirationTime(now + 60 * 60) // 1 hour
    .sign(key);


  const resp = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`OAuth token error: ${resp.status} ${text}`);
  }

  const parsed = JSON.parse(text);
  const accessToken = parsed.access_token as string;

  if (!accessToken) throw new Error("OAuth token response missing access_token");

  return { accessToken, projectId };
}

async function sendFcmMessage(params: SendPushBody) {
  const { accessToken, projectId } = await getGoogleAccessToken();
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

 const notifId =
  (params.data?.notificationId as string | undefined) ??
  (params.data?.id as string | undefined) ??
  undefined;

const payload = {
  message: {
    token: params.token,
    notification: {
      title: params.title,
      body: params.body,
    },
    data: params.data ?? {},
    android: {
      priority: "HIGH",
      // ✅ دمج/استبدال إشعارات متشابهة
      collapse_key: notifId ?? "ttu-default",
      notification: {
        tag: notifId ?? "ttu-default",
      },
    },
  },
};

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`FCM send error: ${resp.status} ${text}`);
  }

  return JSON.parse(text);
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return json({ ok: true }, 204);
  }

  if (req.method !== "POST") {
    return json({ ok: false, error: "Use POST" }, 405);
  }

  try {
    // Supabase Functions تحتاج Bearer token (anon) من العميل
    const auth = req.headers.get("authorization") || "";
    if (!auth.toLowerCase().startsWith("bearer ")) {
      return json(
        { ok: false, error: "Missing Authorization: Bearer <SUPABASE_ANON_KEY>" },
        401,
      );
    }

    const body = (await req.json()) as Partial<SendPushBody>;

    if (!body.token || !body.title || !body.body) {
      return json(
        { ok: false, error: "Required fields: token, title, body" },
        400,
      );
    }

    // تأكد data نوعها string->string
    const safeData: Record<string, string> = {};
    if (body.data) {
      for (const [k, v] of Object.entries(body.data)) {
        safeData[String(k)] = String(v);
      }
    }

    const result = await sendFcmMessage({
      token: body.token,
      title: body.title,
      body: body.body,
      data: safeData,
    });

    return json({ ok: true, result }, 200);
  } catch (e) {
  const msg = String((e as any)?.message ?? e);
  return json({ ok: false, error: msg }, 200); 
}

});
