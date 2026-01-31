// D:\ttu_housing_app\lib\services\user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class UserService {
  final FirebaseFirestore _db;

  UserService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users');

  Future<AppUser?> getById(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!, id: doc.id);
  }

  Stream<AppUser?> watchById(String uid) {
    return _col.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.data()!, id: doc.id);
    });
  }

  /// Ensure user doc exists after login.
  /// IMPORTANT: لا نغيّر role إذا موجود (عشان Rules + أمان).
  Future<void> ensureUserDoc({
    required String uid,
    required String email,
    String? displayName,
    String? phone,
    String? defaultRoleIfNew, // مثلاً: 'tenant'
  }) async {
    final ref = _col.doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'id': uid,
          'email': email,
          'displayName': displayName ?? '',
          'phone': phone ?? '',
          'role': defaultRoleIfNew ?? 'tenant',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update basic fields only — بدون role
        tx.set(ref, {
          'email': email,
          if (displayName != null) 'displayName': displayName,
          if (phone != null) 'phone': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? phone,
  }) async {
    await _col.doc(uid).update({
      if (displayName != null) 'displayName': displayName,
      if (phone != null) 'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
