// D:\ttu_housing_app\lib\models\rental_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RentalRequest {
  final String id; // tenantId_apartmentId
  final String apartmentId;
  final String ownerId;
  final String tenantId;
  final String ownerName;

  final String status; // pending | accepted | rejected | canceled

  final String tenantName;
  final String tenantEmail;
  final String? tenantPhone;

  final String apartmentTitle;
  final String apartmentAddress;
  final double monthlyPrice;

  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  final bool tenantHidden;
  final bool ownerHidden;

  RentalRequest({
    required this.id,
    required this.apartmentId,
    required this.ownerId,
    required this.tenantId,
    required this.status,
    required this.ownerName,
    required this.tenantName,
    required this.tenantEmail,
    this.tenantPhone,
    required this.apartmentTitle,
    required this.apartmentAddress,
    required this.monthlyPrice,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.tenantHidden = false,
    this.ownerHidden = false,
  });

  RentalRequest copyWith({
    String? id,
    String? apartmentId,
    String? ownerId,
    String? ownerName,
    String? tenantId,
    String? status,
    String? tenantName,
    String? tenantEmail,
    String? tenantPhone,
    String? apartmentTitle,
    String? apartmentAddress,
    double? monthlyPrice,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? tenantHidden,
    bool? ownerHidden,
  }) {
    return RentalRequest(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      tenantId: tenantId ?? this.tenantId,
      status: status ?? this.status,
      tenantName: tenantName ?? this.tenantName,
      tenantEmail: tenantEmail ?? this.tenantEmail,
      tenantPhone: tenantPhone ?? this.tenantPhone,
      apartmentTitle: apartmentTitle ?? this.apartmentTitle,
      apartmentAddress: apartmentAddress ?? this.apartmentAddress,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tenantHidden: tenantHidden ?? this.tenantHidden,
      ownerHidden: ownerHidden ?? this.ownerHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apartmentId': apartmentId,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'tenantId': tenantId,
      'status': status,
      'tenantName': tenantName,
      'tenantEmail': tenantEmail,
      'tenantPhone': tenantPhone,
      'apartmentTitle': apartmentTitle,
      'apartmentAddress': apartmentAddress,
      'monthlyPrice': monthlyPrice,
      'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'tenantHidden': tenantHidden,
      'ownerHidden': ownerHidden,
    };
  }

  factory RentalRequest.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    double parseDouble(dynamic v, [double def = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? def;
    }

    return RentalRequest(
      id: id,
      apartmentId: (map['apartmentId'] ?? '').toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      ownerName: (map['ownerName'] ?? '').toString(),
      tenantId: (map['tenantId'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      tenantName: (map['tenantName'] ?? '').toString(),
      tenantEmail: (map['tenantEmail'] ?? '').toString(),
      tenantPhone: map['tenantPhone'] as String?,
      apartmentTitle: (map['apartmentTitle'] ?? '').toString(),
      apartmentAddress: (map['apartmentAddress'] ?? '').toString(),
      monthlyPrice: parseDouble(map['monthlyPrice'], 0),
      note: map['note'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      tenantHidden: (map['tenantHidden'] as bool?) ?? false,
      ownerHidden: (map['ownerHidden'] as bool?) ?? false,
    );
  }
}
