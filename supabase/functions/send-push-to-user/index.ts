import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

type SendPushToUserBody = {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
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

  const sa = JSON.parse(saJson);

  const clientEmail: string = sa.client_email;
  const privateKeyPem: string = sa.private_key;

  if (!clientEmail || !privateKeyPem) {
    throw new Error("Service account JSON missing client_email/private_key");
  }

  const now = Math.floor(Date.now() / 1000);
  const tokenUrl = "https://oauth2.googleapis.com/token";

  // ✅ نحتاج Messaging + Firestore (datastore)
  const scope =
    "https://www.googleapis.com/auth/firebase.messaging " +
    "https://www.googleapis.com/auth/datastore";

  const key = await importPKCS8(privateKeyPem, "RS256");

  const jwt = await new SignJWT({ scope })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience(tokenUrl)
    .setIssuedAt(now)
    .setExpirationTime(now + 60 * 60)
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
  if (!resp.ok) throw new Error(`OAuth token error: ${resp.status} ${text}`);

  const parsed = JSON.parse(text);
  const accessToken = parsed.access_token as string;
  if (!accessToken) throw new Error("OAuth token response missing access_token");

  return { accessToken, projectId };
}

// ------- Firestore helpers (REST doc parsing) -------
function toMillisFromFirestoreValue(v: any): number {
  // updatedAt (timestampValue) OR updatedAtLocal (integerValue)
  if (!v) return 0;

  // TimestampValue: "2026-01-08T12:34:56.000Z"
  if (typeof v.timestampValue === "string") {
    const t = Date.parse(v.timestampValue);
    return Number.isFinite(t) ? t : 0;
  }

  // integerValue is string in Firestore REST
  if (typeof v.integerValue === "string") {
    const n = parseInt(v.integerValue, 10);
    return Number.isFinite(n) ? n : 0;
  }

  return 0;
}

function pickNewestTokenFromFirestoreDoc(doc: any): string | null {
  const fields = doc?.fields;
  const fcmTokens = fields?.fcmTokens?.mapValue?.fields;

  if (!fcmTokens || typeof fcmTokens !== "object") return null;

  let bestToken: string | null = null;
  let bestMillis = -1;

  for (const [token, meta] of Object.entries<any>(fcmTokens)) {
    if (!token) continue;

    // meta is usually mapValue { fields: { updatedAt: ..., updatedAtLocal: ... } }
    const metaFields = meta?.mapValue?.fields;

    const updatedAt = metaFields?.updatedAt;
    const updatedAtLocal = metaFields?.updatedAtLocal;

    const millis = Math.max(
      toMillisFromFirestoreValue(updatedAt),
      toMillisFromFirestoreValue(updatedAtLocal),
    );

    if (millis > bestMillis) {
      bestMillis = millis;
      bestToken = token;
    }
  }

  return bestToken;
}

async function getNewestTokenForUser(userId: string) {
  const { accessToken, projectId } = await getGoogleAccessToken();
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/users/${encodeURIComponent(userId)}`;

  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const text = await resp.text();
  if (!resp.ok) throw new Error(`Firestore read error: ${resp.status} ${text}`);

  const doc = JSON.parse(text);
  const token = pickNewestTokenFromFirestoreDoc(doc);
  return { token, accessToken, projectId };
}

async function sendFcmMessage(params: { token: string; title: string; body: string; data?: Record<string, string> }) {
  const { accessToken, projectId } = await getGoogleAccessToken();
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const notifId =
    (params.data?.notificationId as string | undefined) ??
    (params.data?.id as string | undefined) ??
    undefined;

  const payload = {
    message: {
      token: params.token,
      notification: { title: params.title, body: params.body },
      data: params.data ?? {},
      android: {
        priority: "HIGH",
        collapse_key: notifId ?? "ttu-default",
        notification: { tag: notifId ?? "ttu-default" },
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
  if (!resp.ok) throw new Error(`FCM send error: ${resp.status} ${text}`);

  return JSON.parse(text);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true }, 204);
  if (req.method !== "POST") return json({ ok: false, error: "Use POST" }, 405);

  try {
    const auth = req.headers.get("authorization") || "";
    if (!auth.toLowerCase().startsWith("bearer ")) {
      return json({ ok: false, error: "Missing Authorization: Bearer <token>" }, 401);
    }

    const body = (await req.json()) as Partial<SendPushToUserBody>;
    if (!body.userId || !body.title || !body.body) {
      return json({ ok: false, error: "Required fields: userId, title, body" }, 400);
    }

    // data -> string:string
    const safeData: Record<string, string> = {};
    if (body.data) {
      for (const [k, v] of Object.entries(body.data)) {
        safeData[String(k)] = String(v);
      }
    }

    const { token } = await getNewestTokenForUser(String(body.userId));
    if (!token) return json({ ok: true, skipped: true, reason: "No fcmTokens" }, 200);

    const result = await sendFcmMessage({
      token,
      title: String(body.title),
      body: String(body.body),
      data: safeData,
    });

    return json({ ok: true, result }, 200);
  } catch (e) {
    const msg = String((e as any)?.message ?? e);
    // ✅ 200 لتجنب retry
    return json({ ok: false, error: msg }, 200);
  }
});
