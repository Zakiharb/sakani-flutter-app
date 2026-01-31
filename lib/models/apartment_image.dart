// D:\ttu_housing_app\lib\models\apartment_image.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ApartmentImage {
  final String id;
  final String url;
  final String storagePath;
  final String uploadedBy;
  final DateTime createdAt;

  final int orderIndex; // ✅ جديد
  final bool isCover; // ✅ جديد

  const ApartmentImage({
    required this.id,
    required this.url,
    required this.storagePath,
    required this.uploadedBy,
    required this.createdAt,
    this.orderIndex = 0,
    this.isCover = false,
  });

  Map<String, dynamic> toMap() => {
    'url': url,
    'storagePath': storagePath,
    'uploadedBy': uploadedBy,
    'createdAt': createdAt,
    'orderIndex': orderIndex,
    'isCover': isCover,
  };

  factory ApartmentImage.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    DateTime created;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is DateTime) {
      created = raw;
    } else if (raw is String) {
      created = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    int parseInt(dynamic v, [int def = 0]) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? def;
    }

    return ApartmentImage(
      id: id,
      url: (map['url'] ?? '').toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
      uploadedBy: (map['uploadedBy'] ?? '').toString(),
      createdAt: created,
      orderIndex: parseInt(map['orderIndex'], 0),
      isCover: (map['isCover'] as bool?) ?? false,
    );
  }
}
