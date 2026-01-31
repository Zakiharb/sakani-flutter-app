// D:\ttu_housing_app\lib\services\push_sender.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushSender {
  final FirebaseFirestore _db;
  final SupabaseClient _supabase;

  PushSender({FirebaseFirestore? db, SupabaseClient? supabase})
    : _db = db ?? FirebaseFirestore.instance,
      _supabase = supabase ?? Supabase.instance.client;

  /// يرجّع Tokens مرتّبة (الأحدث أولًا) ومفلترة.
  /// ملاحظة: إذا كانت fcmTokens عندك Map(token -> timestamp/lastSeen) راح نستفيد من القيم للترتيب.
  Future<List<String>> _getTokensForUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return <String>[];

    final data = doc.data()!;
    final raw = data['fcmTokens'];

    if (raw is Map) {
      final entries = raw.entries
          .map((e) => MapEntry(e.key.toString(), e.value))
          .where((e) => e.key.isNotEmpty)
          .toList();

      // إزالة تكرار المفاتيح احتياطًا
      final seen = <String>{};
      final unique = <MapEntry<String, dynamic>>[];
      for (final e in entries) {
        if (seen.add(e.key)) unique.add(e);
      }

      // ترتيب: إذا القيمة Timestamp/num/StringDate نحاول نرتب حسبها
      unique.sort((a, b) => _compareLastSeen(b.value, a.value));

      return unique.map((e) => e.key).toList();
    }

    return <String>[];
  }

  int _compareLastSeen(dynamic a, dynamic b) {
    int toMillis(dynamic v) {
      // ✅ إذا القيمة Map مثل: {updatedAt: Timestamp, platform: 'android', updatedAtLocal: int}
      if (v is Map) {
        final u = v['updatedAt'];
        if (u is Timestamp) return u.millisecondsSinceEpoch;

        final local = v['updatedAtLocal'];
        if (local is int) return local;
        if (local is double) return local.toInt();
      }

      if (v is Timestamp) return v.millisecondsSinceEpoch;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }

      return 0;
    }

    return toMillis(a).compareTo(toMillis(b));
  }

  Future<void> _removeToken({
    required String uid,
    required String token,
  }) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens.$token': FieldValue.delete(),
    });
  }

  bool _looksLikeInvalidTokenError(Object e, dynamic resData) {
    // نحاول نلقط أشهر رسائل/أكواد FCM
    final msg = (e.toString()).toLowerCase();
    final dataStr = (resData?.toString() ?? '').toLowerCase();

    bool has(String s) => msg.contains(s) || dataStr.contains(s);

    return has('notregistered') ||
        has('registration-token-not-registered') ||
        has('invalidregistration') ||
        has('invalid token') ||
        has('invalidregistrationtoken') ||
        has('mismatched-credential') ||
        has('senderid') ||
        has('unregistered');
  }

  /// إرسال Push لمستخدم:
  /// - يرسل فقط لأحدث Token واحد افتراضيًا (يقلل تكرار الإشعارات)
  /// - إذا بدك آخر 2 (جهازين) غيّر maxTokens = 2
  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int maxTokens = 1, // ✅ أهم سطر لمنع التكرار
  }) async {
    final tokens = await _getTokensForUser(userId);
    if (tokens.isEmpty) return;

    final targets = tokens.take(maxTokens).toList();

    for (final token in targets) {
      try {
        final res = await _supabase.functions.invoke(
          'send-push',
          body: {
            'token': token,
            'title': title,
            'body': body,
            'data': data ?? <String, dynamic>{},
          },
        );

        // إذا الفنكشن بيرجع error داخل data
        final resData = res.data;
        final isError =
            (resData is Map &&
            (resData['error'] == true || resData['success'] == false));

        if (isError) {
          // لو واضح إنه توكن غير صالح → نحذفه
          if (_looksLikeInvalidTokenError(
            Exception('send-push error'),
            resData,
          )) {
            await _removeToken(uid: userId, token: token);
          }
        }
      } catch (e) {
        // لو واضح إنه توكن غير صالح → نحذفه
        if (_looksLikeInvalidTokenError(e, null)) {
          await _removeToken(uid: userId, token: token);
        }
        // غير هيك نخليها تروح للأعلى أو نتجاهلها حسب رغبتك
        rethrow;
      }
    }
  }
}
