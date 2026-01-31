// D:\ttu_housing_app\lib\services\supabase_storage_service.dart

import 'dart:math';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ Meta نحتاجه عشان نربط 1:1 بين:
/// Firestore imageDocId  <->  Supabase fileName  <->  storagePath
class UploadedImageMeta {
  final String id; // imageDocId
  final String url; // public url
  final String storagePath; // مثال: apartmentId/imageId.jpg

  const UploadedImageMeta({
    required this.id,
    required this.url,
    required this.storagePath,
  });
}

class SupabaseStorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final _rand = Random();

  static const String bucket = 'apartment-images';

  /// ✅ الدالة القديمة (كما هي): ترفع وترجع URLs فقط
  Future<List<String>> uploadImages({
    required String folderId,
    required List<XFile> files,
  }) async {
    final storage = _client.storage.from(bucket);
    final urls = <String>[];

    for (final xf in files) {
      final ext = _safeExtJpgPngOnly(xf);

      final fileName =
          '${DateTime.now().microsecondsSinceEpoch}_${_rand.nextInt(1 << 32)}.$ext';
      final pathInBucket = '$folderId/$fileName';

      final Uint8List bytes = await xf.readAsBytes();

      await storage.uploadBinary(
        pathInBucket,
        bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        ),
      );

      final publicUrl = storage.getPublicUrl(pathInBucket);
      urls.add(publicUrl);
    }

    return urls;
  }

  /// ✅ الدالة الجديدة (حسب الأصول):
  /// - folderId = apartmentId
  /// - ids = نفس عدد الصور (عادةً Firestore doc ids)
  /// - اسم الملف = id + ext => storagePath ثابت ومضمون
  Future<List<UploadedImageMeta>> uploadImagesWithMeta({
    required String folderId, // apartmentId
    required List<XFile> files,
    required List<String> ids, // doc ids
  }) async {
    if (files.length != ids.length) {
      throw ArgumentError('files.length must equal ids.length');
    }

    final storage = _client.storage.from(bucket);
    final out = <UploadedImageMeta>[];

    for (var i = 0; i < files.length; i++) {
      final xf = files[i];
      final imageId = ids[i];

      final ext = _safeExtJpgPngOnly(xf);

      // إذا الـ id فيه امتداد أصلاً ما نضيف امتداد ثاني
      final fileName = imageId.contains('.') ? imageId : '$imageId.$ext';
      final pathInBucket = '$folderId/$fileName';

      final Uint8List bytes = await xf.readAsBytes();

      await storage.uploadBinary(
        pathInBucket,
        bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        ),
      );

      final publicUrl = storage.getPublicUrl(pathInBucket);

      out.add(
        UploadedImageMeta(
          id: imageId,
          url: publicUrl,
          storagePath: pathInBucket,
        ),
      );
    }

    return out;
  }

  /// ✅ حذف مضمون بالـ storage paths (هذا اللي رح نعتمد عليه بعد ما نخزن storagePath في Firestore)
  Future<void> deleteImagesByPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final storage = _client.storage.from(bucket);
    await storage.remove(paths);
  }

  /// ✅ (للماضي/التحويل فقط) حذف بواسطة URLs ثم استخراج path
  Future<void> deleteImagesByUrls(List<String> urls) async {
    if (urls.isEmpty) return;

    final storage = _client.storage.from(bucket);

    final paths = <String>[];
    for (final url in urls) {
      final path = _pathFromSupabasePublicUrl(url);
      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }

    if (paths.isEmpty) return;

    await storage.remove(paths);
  }

  /// ✅ استخراج path داخل البكت من public url
  String? _pathFromSupabasePublicUrl(String url) {
    final marker = '/storage/v1/object/public/$bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return url.substring(idx + marker.length);
  }

  /// يسمح فقط: jpg/jpeg/png
  String _safeExtJpgPngOnly(XFile xf) {
    final name = xf.name.toLowerCase();
    final parts = name.split('.');
    final ext = (parts.length >= 2) ? parts.last : 'jpg';

    if (ext == 'png') return 'png';
    if (ext == 'jpg' || ext == 'jpeg') return 'jpg';
    return 'jpg';
  }
}
