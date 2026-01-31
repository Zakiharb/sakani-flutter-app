// D:\ttu_housing_app\lib\services\favorite_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _favCol(String uid) {
    return _db.collection('users').doc(uid).collection('favorites');
  }

  /// بثّ لحظي لكل apartmentIds المحفوظة للمستخدم
  Stream<Set<String>> watchIds(String uid) {
    return _favCol(uid).snapshots().map((snap) {
      return snap.docs.map((d) => d.id).toSet(); // docId = apartmentId
    });
  }

  /// ضبط حالة المفضلة (إضافة/إزالة)
  Future<void> setFavorite({
    required String uid,
    required String apartmentId,
    required bool isFavorite,
  }) async {
    final ref = _favCol(uid).doc(apartmentId);

    if (isFavorite) {
      await ref.set({
        'apartmentId': apartmentId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.delete();
    }
  }
}
