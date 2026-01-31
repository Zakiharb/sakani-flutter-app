
// D:\ttu_housing_app\lib\models\app_notification.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String type;

  // ✅ Bilingual fields
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;

  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,

      'titleEn': titleEn,
      'titleAr': titleAr,
      'bodyEn': bodyEn,
      'bodyAr': bodyAr,

      // للتوافق (اختياري)
      'title': titleEn,
      'body': bodyEn,

      'data': data,
      'read': read,
      'createdAt': createdAt,
    };
  }

  factory AppNotification.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final titleEn = (map['titleEn'] ?? map['title'] ?? '').toString();
    final titleAr = (map['titleAr'] ?? titleEn).toString();
    final bodyEn = (map['bodyEn'] ?? map['body'] ?? '').toString();
    final bodyAr = (map['bodyAr'] ?? bodyEn).toString();

    return AppNotification(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      titleEn: titleEn,
      titleAr: titleAr,
      bodyEn: bodyEn,
      bodyAr: bodyAr,
      data:
          (map['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      read: (map['read'] as bool?) ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
