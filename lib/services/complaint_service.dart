// D:\ttu_housing_app\lib\services\complaint_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'push_sender.dart';

class ComplaintService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _aptCol =>
      _db.collection('complaint_apartments');

  CollectionReference<Map<String, dynamic>> get _ownerCol =>
      _db.collection('complaint_owners');

  Future<UserRole> _currentRole() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return UserRole.tenant;
    final doc = await _db.collection('users').doc(u.uid).get();
    if (!doc.exists || doc.data() == null) return UserRole.tenant;
    return UserRoleX.fromString(doc.data()!['role']?.toString());
  }

  Future<void> _notifyAdminsNewComplaint({
    required String complaintId,
    required String kind, // 'apartment' | 'owner'
    String? apartmentId,
    String? ownerId,
  }) async {
    // 1) هات كل الأدمن
    final adminsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    if (adminsSnap.docs.isEmpty) return;

    // 2) نص الإشعار
    final titleEn = 'New complaint';
    final titleAr = 'شكوى جديدة';

    final bodyEn = kind == 'apartment'
        ? 'A tenant reported an apartment. Tap to review.'
        : 'A tenant reported an owner. Tap to review.';

    final bodyAr = kind == 'apartment'
        ? 'تم إرسال شكوى على شقة. اضغط للمراجعة.'
        : 'تم إرسال شكوى على مالك. اضغط للمراجعة.';

    final payload = <String, dynamic>{
      'complaintId': complaintId,
      'kind': kind,
      if (apartmentId != null) 'apartmentId': apartmentId,
      if (ownerId != null) 'ownerId': ownerId,
    };

    // 3) خدمات الإشعار
    final inbox = NotificationService();
    final push = PushSender();

    // 4) ابعث لكل أدمن: Inbox + Push
    for (final d in adminsSnap.docs) {
      final adminId = d.id;

      // A) إشعار داخل التطبيق (Firestore)
      await inbox.create(
        userId: adminId,
        type: 'complaint_new',
        titleEn: titleEn,
        titleAr: titleAr,
        bodyEn: bodyEn,
        bodyAr: bodyAr,
        data: payload,
      );

      // B) Push Notification (FCM عبر Supabase Edge Function)
      await push.sendToUser(
        userId: adminId,
        title: titleEn, // خليها انجليزي للـ push (بسيطة حالياً)
        body: bodyEn,
        data: payload,
      );
    }
  }

  // -------- Tenant creates --------

  Future<void> createApartmentComplaint({
    required Apartment apartment,
    required String reason,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Not signed in';

    final role = await _currentRole();
    if (role != UserRole.tenant) throw 'Only tenants can submit complaints';

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final complainantName = (userData['displayName'] ?? userData['name'] ?? '')
        .toString();
    final complainantPhone = (userData['phone'] ?? '').toString();

    final ref = _aptCol.doc();
    await ref.set({
      'complainantId': user.uid,
      'complainantName': complainantName,
      'complainantPhone': complainantPhone,

      'apartmentId': apartment.id,
      'apartmentTitleEn': apartment.title,
      'apartmentTitleAr': apartment.titleAr ?? apartment.title,

      'ownerId': apartment.ownerId,
      'ownerName': apartment.ownerName,
      'ownerPhone': apartment.ownerPhone,

      'reason': reason,
      'description': description,
      'status': 'open',
      'adminNote': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _notifyAdminsNewComplaint(
        complaintId: ref.id,
        kind: 'apartment',
        apartmentId: apartment.id,
        ownerId: apartment.ownerId,
      );
    } catch (e) {
      // لا تفشل إنشاء الشكوى لو الإشعار فشل
      print('Notify admins failed: $e');
    }
  }

  Future<void> createOwnerComplaint({
    required String ownerId,
    required String reason,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Not signed in';

    final role = await _currentRole();
    if (role != UserRole.tenant) throw 'Only tenants can submit complaints';

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final complainantName = (userData['displayName'] ?? userData['name'] ?? '')
        .toString();
    final complainantPhone = (userData['phone'] ?? '').toString();

    String ownerName = '';
    String ownerPhone = '';

    try {
      final ownerDoc = await _db.collection('users').doc(ownerId).get();
      final ownerData = ownerDoc.data() ?? {};
      ownerName = (ownerData['displayName'] ?? ownerData['name'] ?? '')
          .toString();
      ownerPhone = (ownerData['phone'] ?? '').toString();
    } catch (e) {
      ownerName = '';
      ownerPhone = '';
    }

    final ref = _ownerCol.doc();
    await ref.set({
      'complainantId': user.uid,
      'complainantName': complainantName,
      'complainantPhone': complainantPhone,

      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,

      'reason': reason,
      'description': description,
      'status': 'open',
      'adminNote': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await _notifyAdminsNewComplaint(
        complaintId: ref.id,
        kind: 'owner',
        ownerId: ownerId,
      );
    } catch (e) {
      // لا تفشل إنشاء الشكوى لو الإشعار فشل
      print('Notify admins failed: $e');
    }
  }

  // -------- Tenant reads his complaints --------

  Stream<List<ComplaintApartment>> watchMyApartmentComplaints(String uid) {
    return _aptCol
        .where('complainantId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => ComplaintApartment.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<ComplaintOwner>> watchMyOwnerComplaints(String uid) {
    return _ownerCol
        .where('complainantId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => ComplaintOwner.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  String _statusLabelEn(ComplaintStatus s) {
    const map = {
      ComplaintStatus.open: 'Open',
      ComplaintStatus.inReview: 'In review',
      ComplaintStatus.resolved: 'Resolved',
      ComplaintStatus.rejected: 'Rejected',
    };
    return map[s] ?? 'Unknown';
  }

  String _statusLabelAr(ComplaintStatus s) {
    const map = {
      ComplaintStatus.open: 'مفتوحة',
      ComplaintStatus.inReview: 'قيد المراجعة',
      ComplaintStatus.resolved: 'تم الحل',
      ComplaintStatus.rejected: 'مرفوضة',
    };
    return map[s] ?? 'غير معروف';
  }
  // -------- Admin reads all / by status --------

  Stream<List<ComplaintApartment>> watchApartmentComplaints({
    String? status,
    bool includeArchived = false,
  }) {
    Query<Map<String, dynamic>> q = _aptCol.orderBy(
      'createdAt',
      descending: true,
    );

    if (status != null) q = q.where('status', isEqualTo: status);

    return q.snapshots().map((s) {
      final docs = s.docs.where((d) {
        final data = d.data();
        final archived = data['archived'] == true;
        return includeArchived ? true : !archived;
      });

      return docs
          .map((d) => ComplaintApartment.fromMap(d.data(), id: d.id))
          .toList();
    });
  }

  Stream<List<ComplaintOwner>> watchOwnerComplaints({
    String? status,
    bool includeArchived = false,
  }) {
    Query<Map<String, dynamic>> q = _ownerCol.orderBy(
      'createdAt',
      descending: true,
    );

    if (status != null) q = q.where('status', isEqualTo: status);

    return q.snapshots().map((s) {
      final docs = s.docs.where((d) {
        final data = d.data();
        final archived = data['archived'] == true;
        return includeArchived ? true : !archived;
      });

      return docs
          .map((d) => ComplaintOwner.fromMap(d.data(), id: d.id))
          .toList();
    });
  }

  // -------- Admin archives (hide from main list) --------

  Future<void> adminArchiveApartmentComplaint(ComplaintApartment c) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) throw 'Not signed in';

    await _aptCol.doc(c.id).update({
      'archived': true,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': admin.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminArchiveOwnerComplaint(ComplaintOwner c) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) throw 'Not signed in';

    await _ownerCol.doc(c.id).update({
      'archived': true,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': admin.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -------- Admin updates status + optional notify tenant --------

  Future<void> adminUpdateApartmentComplaint({
    required ComplaintApartment c,
    required ComplaintStatus status,
    String? adminNote,
    bool notifyTenant = true,
  }) async {
    await _aptCol.doc(c.id).update({
      'status': status.asString,
      'adminNote': adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final note = (adminNote ?? '').trim();

    final bodyEn = note.isEmpty
        ? 'Your complaint status is now: ${_statusLabelEn(status)}'
        : 'Your complaint status is now: ${_statusLabelEn(status)}\nAdmin note: $note';

    final bodyAr = note.isEmpty
        ? 'تم تحديث حالة الشكوى إلى: ${_statusLabelAr(status)}'
        : 'تم تحديث حالة الشكوى إلى: ${_statusLabelAr(status)}\nملاحظة الإدارة: $note';

    if (notifyTenant) {
      await NotificationService().create(
        userId: c.complainantId,
        type: 'complaint_status',
        titleEn: 'Complaint updated',
        titleAr: 'تم تحديث الشكوى',
        bodyEn: bodyEn,
        bodyAr: bodyAr,
        data: {
          'complaintId': c.id,
          'apartmentId': c.apartmentId,
          'ownerId': c.ownerId,
          'type': 'complaint_status',
        },
      );

      await PushSender().sendToUser(
        userId: c.complainantId,
        title: 'Complaint updated',
        body: bodyEn,
        data: {
          'complaintId': c.id,
          'apartmentId': c.apartmentId,
          'ownerId': c.ownerId,
          'type': 'complaint_status',
        },
      );
    }
  }

  Future<void> adminUpdateOwnerComplaint({
    required ComplaintOwner c,
    required ComplaintStatus status,
    String? adminNote,
    bool notifyTenant = true,
  }) async {
    await _ownerCol.doc(c.id).update({
      'status': status.asString,
      'adminNote': adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final note = (adminNote ?? '').trim();

    final bodyEn = note.isEmpty
        ? 'Your complaint status is now: ${_statusLabelEn(status)}'
        : 'Your complaint status is now: ${_statusLabelEn(status)}\nAdmin note: $note';

    final bodyAr = note.isEmpty
        ? 'تم تحديث حالة الشكوى إلى: ${_statusLabelAr(status)}'
        : 'تم تحديث حالة الشكوى إلى: ${_statusLabelAr(status)}\nملاحظة الإدارة: $note';

    if (notifyTenant) {
      await NotificationService().create(
        userId: c.complainantId,
        type: 'complaint_status',
        titleEn: 'Complaint updated',
        titleAr: 'تم تحديث الشكوى',
        bodyEn: bodyEn,
        bodyAr: bodyAr,
        data: {
          'complaintId': c.id,
          'ownerId': c.ownerId,
          'type': 'complaint_status',
        },
      );

      await PushSender().sendToUser(
        userId: c.complainantId,
        title: 'Complaint updated',
        body: bodyEn,
        data: {
          'complaintId': c.id,
          'ownerId': c.ownerId,
          'type': 'complaint_status',
        },
      );
    }
  }
}
