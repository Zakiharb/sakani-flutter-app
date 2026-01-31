// D:\ttu_housing_app\lib\services\rental_request_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'notification_service.dart';

class DuplicatePendingRequestException implements Exception {
  final String messageEn;
  final String messageAr;

  DuplicatePendingRequestException({
    this.messageEn = 'You already have a pending request for this apartment.',
    this.messageAr = 'لديك طلب قيد المراجعة لهذه الشقة بالفعل.',
  });

  @override
  String toString() => '$messageEn | $messageAr';
}

class RequestAlreadyAcceptedException implements Exception {
  final String messageEn;
  final String messageAr;

  RequestAlreadyAcceptedException({
    this.messageEn =
        'Your request was already accepted. Please contact the owner to complete the agreement.',
    this.messageAr =
        'تم قبول طلبك مسبقًا. يرجى التواصل مع مالك الشقة لإتمام الاتفاق.',
  });

  @override
  String toString() => '$messageEn | $messageAr';
}

class RentalRequestService {
  final _db = FirebaseFirestore.instance;
  final _notif = NotificationService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('rental_requests');

  CollectionReference<Map<String, dynamic>> get _pendingCol =>
      _db.collection('rental_request_pending');

  Stream<List<RentalRequest>> watchForOwner(String ownerId) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => RentalRequest.fromMap(d.data(), id: d.id))
              .toList();
          list.removeWhere((r) => r.ownerHidden == true);
          return list;
        });
  }

  Stream<List<RentalRequest>> watchForTenant(String tenantId) {
    return _col
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => RentalRequest.fromMap(d.data(), id: d.id))
              .toList();
          list.removeWhere((r) => r.tenantHidden == true);
          return list;
        });
  }

  Stream<List<RentalRequest>> watchForApartment(String apartmentId) {
    return _col
        .where('apartmentId', isEqualTo: apartmentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => RentalRequest.fromMap(d.data(), id: d.id))
              .toList();
        });
  }

  Stream<int> watchApartmentRequestsCount(String apartmentId) {
    return _col
        .where('apartmentId', isEqualTo: apartmentId)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<RentalRequest> createRequest({
    required AppUser tenant,
    required Apartment apartment,
    String? note,
  }) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;

    if (authUid == null) throw Exception('Not signed in');

    // ✅ (3) إذا فيه طلب Accepted سابقًا لنفس الشقة -> امنع برسالة واضحة
    final acceptedSnap = await _col
        .where('tenantId', isEqualTo: authUid)
        .where('apartmentId', isEqualTo: apartment.id)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get();

    if (acceptedSnap.docs.isNotEmpty) {
      throw RequestAlreadyAcceptedException();
    }

    final pendingKey = '${authUid}_${apartment.id}';
    final pendingRef = _pendingCol.doc(pendingKey);

    final requestId =
        '${authUid}_${apartment.id}_${DateTime.now().millisecondsSinceEpoch}';
    final reqRef = _col.doc(requestId);

    final created = await _db.runTransaction<RentalRequest>((tx) async {
      final pendingSnap = await tx.get(pendingRef);

      // ✅ لو القفل موجود: افحص الطلب المرتبط فيه
      if (pendingSnap.exists) {
        final pendingData = pendingSnap.data();
        final oldReqId = pendingData?['requestId']?.toString() ?? '';

        if (oldReqId.isNotEmpty) {
          final oldReqRef = _col.doc(oldReqId);
          final oldReqSnap = await tx.get(oldReqRef);

          final oldStatus = oldReqSnap.exists
              ? (oldReqSnap.data()?['status'] ?? '').toString()
              : '';

          // إذا لسه pending -> امنع
          if (oldReqSnap.exists && oldStatus == 'pending') {
            throw DuplicatePendingRequestException();
          }

          // إذا accepted (احتياط داخل transaction) -> امنع
          if (oldReqSnap.exists && oldStatus == 'accepted') {
            throw RequestAlreadyAcceptedException();
          }

          // إذا rejected/canceled/أو الطلب مش موجود -> القفل stale:
          // ✅ (1)(2) نخفي الطلب القديم عند المستأجر (tenantHidden=true) بدل الحذف
          if (oldReqSnap.exists &&
              (oldStatus == 'rejected' || oldStatus == 'canceled')) {
            tx.update(oldReqRef, {
              'tenantHidden': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          // احذف القفل وكمل
          tx.delete(pendingRef);
        } else {
          throw DuplicatePendingRequestException();
        }
      }

      // أنشئ الطلب الجديد
      tx.set(reqRef, {
        'apartmentId': apartment.id,
        'ownerId': apartment.ownerId,
        'ownerName': apartment.ownerName,
        'tenantId': authUid,
        'status': 'pending',
        'tenantName': (tenant.displayName ?? tenant.email),
        'tenantEmail': tenant.email,
        'tenantPhone': tenant.phone,
        'apartmentTitle': apartment.title,
        'apartmentAddress': apartment.address,
        'monthlyPrice': apartment.price,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tenantHidden': false,
        'ownerHidden': false,
      });

      // أنشئ القفل
      tx.set(pendingRef, {
        'requestId': reqRef.id,
        'tenantId': authUid,
        'ownerId': apartment.ownerId,
        'apartmentId': apartment.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final now = DateTime.now();
      return RentalRequest(
        id: reqRef.id,
        apartmentId: apartment.id,
        ownerId: apartment.ownerId,
        ownerName: apartment.ownerName,
        tenantId: authUid,
        status: 'pending',
        tenantName: (tenant.displayName ?? tenant.email),
        tenantEmail: tenant.email,
        tenantPhone: tenant.phone,
        apartmentTitle: apartment.title,
        apartmentAddress: apartment.address,
        monthlyPrice: apartment.price,
        note: note,
        createdAt: now,
        updatedAt: now,
        tenantHidden: false,
        ownerHidden: false,
      );
    });

    // إشعار المالك
    try {
      await _notif.create(
        userId: created.ownerId,
        type: 'rental_request_new',
        titleEn: 'New rental request',
        titleAr: 'طلب استئجار جديد',
        bodyEn:
            '${created.tenantName} sent a rental request for "${created.apartmentTitle}".',
        bodyAr:
            'قام ${created.tenantName} بإرسال طلب استئجار لشقة "${created.apartmentTitle}".',
        data: {
          'requestId': created.id,
          'apartmentId': created.apartmentId,
          'status': created.status,
          'type': 'rental_request_new',
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('Notify owner failed: $e');
    }

    return created;
  }

  Future<void> setStatusWithNotify({
    required String requestId,
    required String newStatus,
    required String actorId,
  }) async {
    final ref = _col.doc(requestId);

    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final tenantId = (data['tenantId'] ?? '').toString();
    final ownerId = (data['ownerId'] ?? '').toString();
    final aptTitle = (data['apartmentTitle'] ?? '').toString();
    final ownerName = (data['ownerName'] ?? '').toString();
    final tenantName = (data['tenantName'] ?? '').toString();

    if (actorId != ownerId && actorId != tenantId) {
      throw 'Not allowed actor';
    }

    final updateData = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // ✅ (1) إذا المالك رفض -> اخفي الطلب عند المالك تلقائيًا
    final actorIsOwner = actorId == ownerId;
    final actorIsTenant = actorId == tenantId;

    if (actorIsOwner && newStatus == 'rejected') {
      updateData['ownerHidden'] = true;
    }

    // ✅ (2) إذا المستأجر ألغى -> اخفي الطلب عند المستأجر تلقائيًا
    if (actorIsTenant && newStatus == 'canceled') {
      updateData['tenantHidden'] = true;
    }

    await ref.update(updateData);

    // ✅ هنا أصلحنا المشكلة:
    // المالك لا يقدر يعمل get على pending doc حسب rules،
    // فبدل get+delete -> اعمل delete مباشرة.
    final apartmentId = (data['apartmentId'] ?? '').toString();
    final pendingKey = '${tenantId}_$apartmentId';
    final pendingRef = _pendingCol.doc(pendingKey);

    try {
      await pendingRef.delete(); // ✅ بدون get
      // ignore: avoid_print
      print('Pending lock deleted: $pendingKey');
    } catch (e) {
      // ignore: avoid_print
      print('Delete pending lock failed: $e (key=$pendingKey)');
    }

    final recipientId = actorIsOwner ? tenantId : ownerId;

    String bodyEn = '';
    String bodyAr = '';

    final ownerShown = ownerName.isNotEmpty ? ownerName : 'Owner';
    final tenantShown = tenantName.isNotEmpty ? tenantName : 'Tenant';

    if (newStatus == 'accepted') {
      bodyEn = 'Your request for "$aptTitle" was accepted by $ownerShown.';
      bodyAr = 'تمت الموافقة على طلبك لشقة "$aptTitle" من قبل $ownerShown.';
    } else if (newStatus == 'rejected') {
      bodyEn = 'Your request for "$aptTitle" was rejected by $ownerShown.';
      bodyAr = 'تم رفض طلبك لشقة "$aptTitle" من قبل $ownerShown.';
    } else if (newStatus == 'canceled') {
      bodyEn = '$tenantShown canceled the request for "$aptTitle".';
      bodyAr = 'قام $tenantShown بإلغاء طلب استئجار "$aptTitle".';
    } else {
      bodyEn = 'Request status updated for "$aptTitle".';
      bodyAr = 'تم تحديث حالة الطلب لشقة "$aptTitle".';
    }

    try {
      await _notif.create(
        userId: recipientId,
        type: 'rental_request_status',
        titleEn: 'Rental Request',
        titleAr: 'طلب استئجار',
        bodyEn: bodyEn,
        bodyAr: bodyAr,
        data: {
          'requestId': requestId,
          'apartmentId': apartmentId,
          'status': newStatus,
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('Notify recipient failed: $e');
    }
  }

  Future<void> hideForTenant(String requestId) async {
    await _col.doc(requestId).update({
      'tenantHidden': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> hideForOwner(String requestId) async {
    await _col.doc(requestId).update({
      'ownerHidden': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setStatus(
    String requestId,
    String status, {
    String? actorId,
  }) async {
    if (actorId != null && actorId.trim().isNotEmpty) {
      return setStatusWithNotify(
        requestId: requestId,
        newStatus: status,
        actorId: actorId,
      );
    }

    await _col.doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<RentalRequest>> watchForOwnerApartment({
    required String ownerId,
    required String apartmentId,
  }) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .where('apartmentId', isEqualTo: apartmentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => RentalRequest.fromMap(d.data(), id: d.id))
              .toList();
          list.removeWhere((r) => r.ownerHidden == true);
          return list;
        });
  }
}
