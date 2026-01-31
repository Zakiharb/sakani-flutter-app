// D:\ttu_housing_app\lib\services\apartment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/supabase_storage_service.dart';

class ApartmentService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('apartments');

  Stream<List<Apartment>> watchApproved({
    String? ownerId, // لو بدنا شقق المالك (كل الحالات)
    bool adminAll = false, // لو بدنا للأدمن كل الشقق
  }) {
    Query<Map<String, dynamic>> q = _col;

    if (adminAll) {
      // الأدمن: كل الشقق (pending/approved/rejected)
    } else if (ownerId != null && ownerId.trim().isNotEmpty) {
      // المالك: كل شققه بكل الحالات
      q = q.where('ownerId', isEqualTo: ownerId);
    } else {
      // الرئيسية للمستأجر: approved فقط
      q = q.where('status', isEqualTo: 'approved');
    }

    return q
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Apartment.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<bool> rejectWithNote(String id, String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      throw Exception('REJECTION_NOTE_REQUIRED');
    }

    return _db.runTransaction<bool>((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return false;

      final data = snap.data() ?? {};
      final currentStatus = (data['status'] ?? '').toString();
      final currentNote = (data['rejectionNote'] ?? '').toString();

      // إذا نفس الحالة ونفس السبب، ما في داعي نعمل إشعار
      if (currentStatus == 'rejected' && currentNote == trimmed) return false;

      tx.update(ref, {
        'status': 'rejected',
        'rejectionNote': trimmed,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<void> clearRejectionNote(String id) async {
    await _col.doc(id).update({
      'rejectionNote': FieldValue.delete(),
      'rejectedAt': FieldValue.delete(),
    });
  }

  Future<void> addApartment(Apartment a) async {
    final ref = _col.doc();
    await ref.set({
      ...a.toMap(),
      'id': ref.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Apartment>> watchForOwner(String ownerId) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Apartment.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<Apartment>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Apartment.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<void> updateApartment(Apartment a) async {
    await _col.doc(a.id).set({
      ...a.toMap(),
      'id': a.id,
    }, SetOptions(merge: true));
  }

  Future<void> deleteApartment(String id) async {
    await _col.doc(id).delete();
  }

  Future<bool> setStatusIfChanged(String id, String newStatus) async {
    return _db.runTransaction<bool>((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return false;

      final current = (snap.data()?['status'] ?? '').toString();
      if (current == newStatus) return false; // ما في تغيير -> لا إشعار

      tx.update(ref, {'status': newStatus});
      return true; // صار تغيير فعلي
    });
  }

  Future<Apartment?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Apartment.fromMap(doc.data()!, id: doc.id);
  }

  Future<String> createApartmentAndReturnId(Apartment a) async {
    final ref = _col.doc();
    await ref.set({
      ...a.toMap(),
      'id': ref.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> setApartmentImages(String apartmentId, List<String> urls) {
    return FirebaseFirestore.instance
        .collection('apartments')
        .doc(apartmentId)
        .update({'images': urls});
  }

  Future<void> deleteApartmentWithImages(String apartmentId) async {
    // 1) اقرأ بيانات الشقة (علشان نجيب images URLs)
    final doc = await _col.doc(apartmentId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final urls = (data['images'] is List)
        ? (data['images'] as List).map((e) => e.toString()).toList()
        : <String>[];

    // 2) احذف الصور من Supabase (إذا فشل → ما نحذف الشقة عشان ما تضل صور يتيمة)
    if (urls.isNotEmpty) {
      await SupabaseStorageService().deleteImagesByUrls(urls);
    }

    // 3) احذف وثيقة الشقة من Firestore
    await _col.doc(apartmentId).delete();
  }

  Future<void> appendApartmentImage(String apartmentId, String url) {
    return _col.doc(apartmentId).update({
      'images': FieldValue.arrayUnion([url]),
    });
  }

  Future<void> updateApartmentDetails(Apartment a) async {
    await _col.doc(a.id).update({
      'ownerId': a.ownerId,
      'title': a.title,
      'titleAr': a.titleAr,
      'description': a.description,
      'descriptionAr': a.descriptionAr,
      'price': a.price,
      'rooms': a.rooms,
      'bathrooms': a.bathrooms,
      'distance': a.distance,
      'address': a.address,
      'lat': a.lat,
      'lng': a.lng,
      'furnished': a.furnished,
      'ownerName': a.ownerName,
      'ownerPhone': a.ownerPhone,
      'status': a.status,
    });
  }
}
