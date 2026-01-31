
// D:\ttu_housing_app\lib\models\complaint.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintStatus { open, inReview, resolved, rejected }

extension ComplaintStatusX on ComplaintStatus {
  String get asString {
    switch (this) {
      case ComplaintStatus.open:
        return 'open';
      case ComplaintStatus.inReview:
        return 'in_review';
      case ComplaintStatus.resolved:
        return 'resolved';
      case ComplaintStatus.rejected:
        return 'rejected';
    }
  }

  static ComplaintStatus fromString(String? v) {
    switch (v) {
      case 'in_review':
        return ComplaintStatus.inReview;
      case 'resolved':
        return ComplaintStatus.resolved;
      case 'rejected':
        return ComplaintStatus.rejected;
      case 'open':
      default:
        return ComplaintStatus.open;
    }
  }
}

DateTime _parseDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
  return DateTime.now();
}

/// شكوى على شقة
class ComplaintApartment {
  final String id;
  final String complainantId; // tenant uid
  final String apartmentId;
  final String ownerId;

  final String reason; // type/reason
  final String description;

  final ComplaintStatus status;
  final String? adminNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String? apartmentTitleEn;
  final String? apartmentTitleAr;
  final String? ownerName;
  final String? ownerPhone;
  final String? complainantName;
  final String? complainantPhone;

  ComplaintApartment({
    required this.id,
    required this.complainantId,
    required this.apartmentId,
    required this.ownerId,
    required this.reason,
    required this.description,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
    this.apartmentTitleEn,
    this.apartmentTitleAr,
    this.ownerName,
    this.complainantName,
    this.complainantPhone,
    this.ownerPhone,
  });

  Map<String, dynamic> toMap() => {
    'complainantId': complainantId,
    'apartmentId': apartmentId,
    'ownerId': ownerId,
    'reason': reason,
    'description': description,
    'status': status.asString,
    'adminNote': adminNote,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (apartmentTitleEn != null) 'apartmentTitleEn': apartmentTitleEn,
    if (apartmentTitleAr != null) 'apartmentTitleAr': apartmentTitleAr,
    if (ownerName != null) 'ownerName': ownerName,
    if (ownerPhone != null) 'ownerPhone': ownerPhone,
    if (complainantName != null) 'complainantName': complainantName,
    if (complainantPhone != null) 'complainantPhone': complainantPhone,
  };

  factory ComplaintApartment.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return ComplaintApartment(
      id: id,
      complainantId: (map['complainantId'] ?? '').toString(),
      apartmentId: (map['apartmentId'] ?? '').toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      reason: (map['reason'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      status: ComplaintStatusX.fromString(map['status']?.toString()),
      adminNote: map['adminNote']?.toString(),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      apartmentTitleEn: map['apartmentTitleEn']?.toString(),
      apartmentTitleAr: map['apartmentTitleAr']?.toString(),
      ownerName: map['ownerName']?.toString(),
      ownerPhone: map['ownerPhone']?.toString(),
      complainantName: map['complainantName']?.toString(),
      complainantPhone: map['complainantPhone']?.toString(),
    );
  }
}

/// شكوى على مالك
class ComplaintOwner {
  final String id;
  final String complainantId; // tenant uid
  final String ownerId;

  final String reason;
  final String description;

  final ComplaintStatus status;
  final String? adminNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String? ownerName;
  final String? ownerPhone;
  final String? complainantName;
  final String? complainantPhone;

  ComplaintOwner({
    required this.id,
    required this.complainantId,
    required this.ownerId,
    required this.reason,
    required this.description,
    required this.status,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
    this.ownerName,
    this.ownerPhone,
    this.complainantName,
    this.complainantPhone,
  });

  Map<String, dynamic> toMap() => {
    'complainantId': complainantId,
    'ownerId': ownerId,
    'reason': reason,
    'description': description,
    'status': status.asString,
    'adminNote': adminNote,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    if (ownerName != null) 'ownerName': ownerName,
    if (ownerPhone != null) 'ownerPhone': ownerPhone,
    if (complainantName != null) 'complainantName': complainantName,
    if (complainantPhone != null) 'complainantPhone': complainantPhone,
  };

  factory ComplaintOwner.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return ComplaintOwner(
      id: id,
      complainantId: (map['complainantId'] ?? '').toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      reason: (map['reason'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      status: ComplaintStatusX.fromString(map['status']?.toString()),
      adminNote: map['adminNote']?.toString(),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      ownerName: map['ownerName']?.toString(),
      ownerPhone: map['ownerPhone']?.toString(),
      complainantName: map['complainantName']?.toString(),
      complainantPhone: map['complainantPhone']?.toString(),
    );
  }
}
