
// D:\ttu_housing_app\lib\models\models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
export 'rental_request.dart';
export 'apartment_image.dart';
export 'complaint.dart';

enum UserRole { tenant, owner, admin }

enum AppLanguage { en, ar }

extension UserRoleX on UserRole {
  String get asString {
    switch (this) {
      case UserRole.tenant:
        return 'tenant';
      case UserRole.owner:
        return 'owner';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'tenant':
      default:
        return UserRole.tenant;
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? phone;
  final UserRole role;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.phone,
    required this.role,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'role': role.asString,
      'createdAt': createdAt,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {required String id}) {
    final rawCreatedAt = map['createdAt'];
    DateTime created;

    if (rawCreatedAt is Timestamp) {
      created = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      created = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      created = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return AppUser(
      id: id,
      email: (map['email'] ?? '') as String,
      displayName: map['displayName'] as String?,
      phone: map['phone'] as String?,
      role: UserRoleX.fromString(map['role'] as String?),
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory AppUser.fromJson(Map<String, dynamic> json, {required String id}) {
    return AppUser.fromMap(json, id: id);
  }
}

class Apartment {
  final String id;
  final String ownerId;

  final String title;
  final String? titleAr;
  final String description;
  final String? descriptionAr;

  final double price;
  final int rooms;
  final int bathrooms;
  final double distance;

  final String address;
  final double? lat;
  final double? lng;

  final bool furnished;
  final List<String> images;

  final String ownerName;
  final String ownerPhone;

  final String status;
  final DateTime createdAt;

  final bool saved;

  final String? coverImageUrl;

  const Apartment({
    required this.id,
    required this.ownerId,
    required this.title,
    this.titleAr,
    required this.description,
    this.descriptionAr,
    required this.price,
    required this.rooms,
    this.bathrooms = 1,
    required this.distance,
    required this.address,
    this.lat,
    this.lng,
    this.furnished = false,
    required this.images,
    required this.ownerName,
    required this.ownerPhone,
    this.status = 'pending',
    required this.createdAt,
    this.saved = false,
    this.coverImageUrl,
  });

  Apartment copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? titleAr,
    String? description,
    String? descriptionAr,
    double? price,
    int? rooms,
    int? bathrooms,
    double? distance,
    String? address,
    double? lat,
    double? lng,
    bool? furnished,
    List<String>? images,
    String? ownerName,
    String? ownerPhone,
    String? status,
    DateTime? createdAt,
    bool? saved,
    String? coverImageUrl,
  }) {
    return Apartment(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      price: price ?? this.price,
      rooms: rooms ?? this.rooms,
      bathrooms: bathrooms ?? this.bathrooms,
      distance: distance ?? this.distance,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      furnished: furnished ?? this.furnished,
      images: images ?? List<String>.from(this.images),
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      saved: saved ?? this.saved,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'titleAr': titleAr,
      'description': description,
      'descriptionAr': descriptionAr,
      'price': price,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'distance': distance,
      'address': address,
      'lat': lat,
      'lng': lng,
      'furnished': furnished,
      'images': images,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'status': status,
      'createdAt': createdAt,
      'coverImageUrl': coverImageUrl,
    };
  }

  factory Apartment.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime created;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      created = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      created = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      created = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    double parseDouble(dynamic v, [double def = 0]) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? def;
    }

    int parseInt(dynamic v, [int def = 0]) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? def;
    }

    final imagesRaw = map['images'];
    final images = (imagesRaw is List)
        ? imagesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return Apartment(
      id: id,
      ownerId: (map['ownerId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      titleAr: map['titleAr']?.toString(),
      description: (map['description'] ?? '').toString(),
      descriptionAr: map['descriptionAr']?.toString(),
      price: parseDouble(map['price'], 0),
      rooms: parseInt(map['rooms'], 0),
      bathrooms: parseInt(map['bathrooms'], 1),
      distance: parseDouble(map['distance'], 0),
      address: (map['address'] ?? '').toString(),
      lat: map['lat'] == null ? null : parseDouble(map['lat']),
      lng: map['lng'] == null ? null : parseDouble(map['lng']),
      furnished: (map['furnished'] as bool?) ?? false,
      images: images,
      ownerName: (map['ownerName'] ?? '').toString(),
      ownerPhone: (map['ownerPhone'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      createdAt: created,
      saved: false,
      coverImageUrl: map['coverImageUrl']?.toString(),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
  });
}

class ChatConversation {
  final String id;
  final String participantId;
  final String participantName;
  final String lastMessage;
  final DateTime timestamp;
  final int unread;

  ChatConversation({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.lastMessage,
    required this.timestamp,
    required this.unread,
  });
}

enum OrderStatus { pending, approved, rejected }

class ApartmentOrder {
  final String id;
  final String apartmentId;
  final String ownerId;

  final String tenantId;
  final String tenantName;
  final String tenantEmail;

  final String? note;
  OrderStatus status;

  final DateTime createdAt;

  ApartmentOrder({
    required this.id,
    required this.apartmentId,
    required this.ownerId,
    required this.tenantId,
    required this.tenantName,
    required this.tenantEmail,
    this.note,
    this.status = OrderStatus.pending,
    required this.createdAt,
  });
}
