// D:\ttu_housing_app\lib\services\apartment_image_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/apartment_image.dart';
import 'supabase_storage_service.dart';

class ApartmentImageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SupabaseStorageService _storage = SupabaseStorageService();

  CollectionReference<Map<String, dynamic>> _imagesCol(String apartmentId) =>
      _db.collection('apartments').doc(apartmentId).collection('images');

  DocumentReference<Map<String, dynamic>> _aptDoc(String apartmentId) =>
      _db.collection('apartments').doc(apartmentId);

  Future<List<ApartmentImage>> fetchImages(String apartmentId) async {
    final q = await _imagesCol(apartmentId).orderBy('orderIndex').get();

    return q.docs
        .map((d) => ApartmentImage.fromMap(d.data(), id: d.id))
        .toList();
  }

  /// ✅ إضافة صور جديدة (ترفع للـ Supabase + تنشئ docs + تعمل sync للملخص)
  Future<List<ApartmentImage>> addImages({
    required String apartmentId,
    required String ownerId,
    required List<XFile> files,
    required int startOrderIndex,
  }) async {
    if (files.isEmpty) return [];

    // 1) جهّز doc ids قبل الرفع (حتى اسم الملف = docId)
    final docRefs = files.map((_) => _imagesCol(apartmentId).doc()).toList();
    final ids = docRefs.map((d) => d.id).toList();

    // 2) ارفع بـ meta
    final uploaded = await _storage.uploadImagesWithMeta(
      folderId: apartmentId, // ✅ Folder = apartmentId
      files: files,
      ids: ids,
    );

    // 3) اكتب image docs
    final batch = _db.batch();
    for (var i = 0; i < uploaded.length; i++) {
      final meta = uploaded[i];
      batch.set(docRefs[i], {
        'url': meta.url,
        'storagePath': meta.storagePath,
        'uploadedBy': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'orderIndex': startOrderIndex + i,
        'isCover': (startOrderIndex == 0 && i == 0),
      });
    }
    await batch.commit();

    // 4) sync summary
    await syncApartmentImageSummary(apartmentId);

    // رجّع list (اختياري بس مفيد بالـ edit)
    final now = DateTime.now();
    return uploaded.asMap().entries.map((e) {
      final i = e.key;
      final meta = e.value;
      return ApartmentImage(
        id: meta.id,
        url: meta.url,
        storagePath: meta.storagePath,
        uploadedBy: ownerId,
        createdAt: now,
        orderIndex: startOrderIndex + i,
        isCover: (startOrderIndex == 0 && i == 0),
      );
    }).toList();
  }

  /// ✅ حذف صور حسب urls (لكن الحذف الفعلي بالـ storagePath من docs)
  Future<void> deleteImagesByUrls({
    required String apartmentId,
    required List<String> urlsToDelete,
  }) async {
    if (urlsToDelete.isEmpty) return;

    final current = await fetchImages(apartmentId);
    final targetUrls = urlsToDelete.toSet();

    final toDelete = current
        .where((img) => targetUrls.contains(img.url))
        .toList();
    if (toDelete.isEmpty) return;

    final paths = toDelete
        .map((e) => e.storagePath)
        .where((p) => p.isNotEmpty)
        .toList();

    // 1) حذف من Supabase
    await _storage.deleteImagesByPaths(paths);

    // 2) حذف docs
    final batch = _db.batch();
    for (final img in toDelete) {
      batch.delete(_imagesCol(apartmentId).doc(img.id));
    }
    await batch.commit();

    // 3) sync summary
    await syncApartmentImageSummary(apartmentId);
  }

  /// ✅ حذف كل الصور لشقة
  Future<void> deleteAllImages(String apartmentId) async {
    final current = await fetchImages(apartmentId);
    if (current.isEmpty) return;

    final paths = current
        .map((e) => e.storagePath)
        .where((p) => p.isNotEmpty)
        .toList();
    await _storage.deleteImagesByPaths(paths);

    final batch = _db.batch();
    for (final img in current) {
      batch.delete(_imagesCol(apartmentId).doc(img.id));
    }
    await batch.commit();
    await syncApartmentImageSummary(apartmentId);
  }

  /// ✅ ترتيب + cover من قائمة urls (اللي بترجع من شاشة التعديل)
  Future<void> applyOrderAndCoverFromUrls({
    required String apartmentId,
    required List<String> orderedUrls,
  }) async {
    final current = await fetchImages(apartmentId);
    if (current.isEmpty) {
      await _aptDoc(
        apartmentId,
      ).update({'images': <String>[], 'coverImageUrl': FieldValue.delete()});
      return;
    }

    // dedupe مع الحفاظ على الترتيب
    final seen = <String>{};
    final cleanOrder = <String>[];
    for (final u in orderedUrls) {
      if (seen.add(u)) cleanOrder.add(u);
    }

    final byUrl = {for (final img in current) img.url: img};

    final batch = _db.batch();
    for (var i = 0; i < cleanOrder.length; i++) {
      final url = cleanOrder[i];
      final img = byUrl[url];
      if (img == null) continue;

      batch.update(_imagesCol(apartmentId).doc(img.id), {
        'orderIndex': i,
        'isCover': i == 0,
      });
    }
    await batch.commit();

    await syncApartmentImageSummary(apartmentId);
  }

  /// ✅ تحديث ملخص الشقة: images[] + coverImageUrl
  Future<void> syncApartmentImageSummary(String apartmentId) async {
    final current = await fetchImages(apartmentId);

    if (current.isEmpty) {
      await _aptDoc(
        apartmentId,
      ).update({'images': <String>[], 'coverImageUrl': FieldValue.delete()});
      return;
    }

    current.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final urls = current.map((e) => e.url).toList();

    String cover = urls.first;
    final coverDoc = current.firstWhere(
      (e) => e.isCover,
      orElse: () => current.first,
    );
    if (coverDoc.url.isNotEmpty) cover = coverDoc.url;

    await _aptDoc(apartmentId).update({'images': urls, 'coverImageUrl': cover});
  }
}
