// D:\ttu_housing_app\lib\services\notification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';
import 'push_sender.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final _db = FirebaseFirestore.instance;
  final _push = PushSender();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Stream<List<AppNotification>> watchForUser(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => AppNotification.fromMap(d.data(), id: d.id))
              .toList();
        });
  }

  Stream<int> watchUnreadCount(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  String _prefKeyFromType(String type) {
    if (type.startsWith('rental_request_')) return 'rentalUpdates';
    if (type.startsWith('apartment_')) return 'apartmentUpdates';
    if (type.startsWith('complaint_')) return 'complaintUpdates';
    if (type.startsWith('chat_') || type.startsWith('message_'))
      return 'messageUpdates';
    return 'apartmentUpdates';
  }

  Future<void> markAllReadForUser(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final docs = snap.docs;
    for (var i = 0; i < docs.length; i += 450) {
      final batch = _db.batch();
      final chunk = docs.skip(i).take(450);

      for (final d in chunk) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    }
  }

  Future<bool> _pushAllowedForUser(String userId, String type) async {
    final key = _prefKeyFromType(type);
    try {
      final doc = await _db.collection('notification_prefs').doc(userId).get();
      final data = doc.data();
      if (data == null) return true; // default ON
      final v = data[key];
      return (v is bool) ? v : true;
    } catch (_) {
      return true; // ما نكسر النظام إذا فشلت القراءة
    }
  }

  Future<void> create({
    required String userId,
    required String type,
    required String titleEn,
    required String titleAr,
    required String bodyEn,
    required String bodyAr,
    Map<String, dynamic>? data,
  }) async {
    final ref = _col.doc();

    await ref.set({
      'userId': userId,
      'type': type,

      'titleEn': titleEn,
      'titleAr': titleAr,
      'bodyEn': bodyEn,
      'bodyAr': bodyAr,

      // للعرض السريع (حسب شاشتك)
      'title': titleEn,
      'body': bodyEn,

      'data': data ?? <String, dynamic>{},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final isRental =
        type == 'rental_request_new' || type == 'rental_request_status';

    final allowed = await _pushAllowedForUser(userId, type);
    if (!allowed) return;

    try {
      if (isRental) {
        // ✅ Push عبر Supabase Backend (بدون قراءة users/{uid} من Flutter)
        await Supabase.instance.client.functions.invoke(
          'send-push-to-user',
          body: {
            'userId': userId,
            'title': titleEn,
            'body': bodyEn,
            'data': {
              'type': type,
              'notificationId': ref.id,
              ...?data,
            }.map((k, v) => MapEntry(k.toString(), v.toString())),
          },
        );
      } else {
        await _push.sendToUser(
          userId: userId,
          title: titleEn,
          body: bodyEn,
          data: {'type': type, 'notificationId': ref.id, ...?data},
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Push failed: $e');
    }
  }

  Future<void> markRead(String id) async {
    await _col.doc(id).update({'read': true});
  }

  Future<void> deleteOne(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> clearAllForUser(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).get();

    final docs = snap.docs;
    for (var i = 0; i < docs.length; i += 450) {
      final batch = _db.batch();
      final chunk = docs.skip(i).take(450);

      for (final d in chunk) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}
