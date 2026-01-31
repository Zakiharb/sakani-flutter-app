// D:\ttu_housing_app\lib\services\fcm_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;

  FcmService({FirebaseFirestore? db, FirebaseMessaging? messaging})
    : _db = db ?? FirebaseFirestore.instance,
      _messaging = messaging ?? FirebaseMessaging.instance;

  /// كم توكن نحتفظ فيهم لكل مستخدم
  /// - 1 = يمنع تكرار الإشعارات بشكل قوي
  /// - 2 = لو بدك تدعم جهازين (موبايل + تاب) لنفس الحساب
  static const int _maxTokensToKeep = 1;

  /// نداء بعد تسجيل الدخول وبعد ما يكون users/{uid} موجود
  Future<void> initForUser(String uid) async {
    // 1) طلب صلاحيات الإشعارات (Android 13+ مهم)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('FCM permission status: ${settings.authorizationStatus}');
    }

    // 2) جيب التوكن وخزّنه + نظّف القديم
    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _saveTokenAndPrune(uid, token.trim());
    }

    // 3) لو تغيّر التوكن (token refresh) خزّنه + نظّف القديم
    _messaging.onTokenRefresh.listen((newToken) async {
      final t = newToken.trim();
      if (t.isEmpty) return;
      await _saveTokenAndPrune(uid, t);
    });
  }

  Future<void> _saveTokenAndPrune(String uid, String token) async {
    final userRef = _db.collection('users').doc(uid);

    // اقرأ التوكنات الحالية
    final snap = await userRef.get();
    final data = snap.data();
    final raw = (data == null) ? null : data['fcmTokens'];

    final Map<String, dynamic> existing = (raw is Map)
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    existing[token] = {
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtLocal': DateTime.now().millisecondsSinceEpoch,
      'platform': 'android',
    };

    // ✅ لو عدد التوكنات صار كبير: احذف الزائد (نحتفظ بالأحدث)
    // ملاحظة: updatedAt قد تكون Timestamp أو Map فيها updatedAt
    // عندنا هنا value = Map(platform, updatedAt) عادة
    List<MapEntry<String, dynamic>> entries = existing.entries.toList();

    // ترتيب حسب updatedAt داخل value
    entries.sort((a, b) {
      int toMillis(dynamic v) {
        if (v is Map) {
          final u = v['updatedAt'];
          if (u is Timestamp) {
            return (u).millisecondsSinceEpoch;
          }

          final local = v['updatedAtLocal'];
          if (local is int) return local;
          if (local is double) return local.toInt();
        }

        if (v is Timestamp) return v.millisecondsSinceEpoch;

        return 0; // لو null/غير مفهوم
      }

      return toMillis(b.value).compareTo(toMillis(a.value));
    });

    // التوكنات اللي رح نخليها
    final keep = entries.take(_maxTokensToKeep).map((e) => e.key).toSet();
    keep.add(token);
    // اللي لازم ينحذف
    final toDelete = existing.keys.where((t) => !keep.contains(t)).toList();

    // ✅ اكتب التحديثات
    // 1) خزّن/حدّث التوكن الحالي
    await userRef.set({
      'fcmTokens': {
        token: {
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': 'android',
        },
      },
    }, SetOptions(merge: true));

    // 2) احذف التوكنات الزائدة
    if (toDelete.isNotEmpty) {
      final updates = <String, dynamic>{};
      for (final t in toDelete) {
        updates['fcmTokens.$t'] = FieldValue.delete();
      }
      await userRef.update(updates);
    }

    if (kDebugMode) {
      print('FCM token saved. kept=${keep.length}, deleted=${toDelete.length}');
    }
  }
}
