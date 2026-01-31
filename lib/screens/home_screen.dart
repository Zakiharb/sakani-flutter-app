// D:\ttu_housing_app\lib\screens\home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/widgets/apartment_card.dart';
import 'package:ttu_housing_app/screens/filters_screen.dart';
import 'package:ttu_housing_app/screens/apartment_details_screen.dart';
import 'package:ttu_housing_app/screens/chat_list_screen.dart';
import 'package:ttu_housing_app/screens/chat_screen.dart';
import 'package:ttu_housing_app/screens/owner_dashboard_screen.dart';
import 'package:ttu_housing_app/screens/add_apartment_screen.dart';
import 'package:ttu_housing_app/screens/admin_panel_screen.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'package:ttu_housing_app/screens/tenant_orders_screen.dart';
import 'package:ttu_housing_app/screens/owner_orders_screen.dart';
import 'package:ttu_housing_app/screens/owner_apartment_requests_screen.dart';
import 'package:ttu_housing_app/services/apartment_service.dart';
import 'package:ttu_housing_app/services/rental_request_service.dart';
import 'package:ttu_housing_app/screens/notifications_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttu_housing_app/services/apartment_image_service.dart';
import 'dart:math' as Math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttu_housing_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttu_housing_app/services/favorite_service.dart';
import 'package:ttu_housing_app/screens/my_profile_screen.dart';
import 'package:ttu_housing_app/screens/notification_settings_screen.dart';
// import 'package:ttu_housing_app/screens/my_profile_screen.dart';

class MainHomePage extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;
  final String? initialNavigate;

  const MainHomePage({
    super.key,
    required this.currentUser,
    required this.onLogout,
    this.initialNavigate,
  });

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  List<Apartment> _apartments = [];
  Map<String, dynamic> _filters = {};
  final List<ApartmentOrder> _orders = [];
  final _aptService = ApartmentService();
  final _rentalService = RentalRequestService();
  StreamSubscription<List<Apartment>>? _aptSub;
  final _aptImageService = ApartmentImageService();
  final _notifService = NotificationService();

  final _favService = FavoriteService();
  StreamSubscription<Set<String>>? _favSub;

  final Set<String> _savedIds = {};

  bool _isCreatingRequest = false;

  // اختصارات
  UserRole get userRole => widget.currentUser.role;
  String get currentUserEmail => widget.currentUser.email;
  String get currentUserId => widget.currentUser.id;

  bool _didAutoNavigate = false;

  Future<void> _notifyAdminsApartmentPending({
    required String apartmentId,
    required String ownerId,
    required String ownerName,
    required String apartmentTitle,
  }) async {
    // نرسل للأدمن فقط إذا الشقة pending للمراجعة
    final adminsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    for (final doc in adminsSnap.docs) {
      final adminId = doc.id;

      try {
        await _notifService.create(
          userId: adminId,
          type: 'apartment_pending_review',
          titleEn: 'New apartment pending review',
          titleAr: 'شقة جديدة للمراجعة',
          bodyEn: '$ownerName added a new apartment: "$apartmentTitle".',
          bodyAr: 'قام $ownerName بإضافة شقة جديدة: "$apartmentTitle".',
          data: {
            'apartmentId': apartmentId,
            'ownerId': ownerId,
            'type': 'apartment_pending_review',
          },
        );
      } catch (e) {
        // ignore: avoid_print
        print('Notify admin failed: $e');
      }
    }
  }

  Apartment? _findApt(List<Apartment> list, String id) {
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> _notifyOwnerApartmentStatus({
    required Apartment apt,
    required String newStatus, // approved / rejected
    String? rejectionNote,
  }) async {
    final isApproved = newStatus == 'approved';

    await _notifService.create(
      userId: apt.ownerId,
      type: 'apartment_status',
      titleEn: isApproved ? 'Apartment approved' : 'Apartment rejected',
      titleAr: isApproved ? 'تمت الموافقة على الشقة' : 'تم رفض الشقة',
      bodyEn: isApproved
          ? 'Your apartment "${apt.title}" has been approved and is now visible to tenants.'
          : 'Your apartment "${apt.title}" has been rejected by the admin.'
                '${(rejectionNote != null && rejectionNote.trim().isNotEmpty) ? "\nReason: $rejectionNote" : ""}',

      bodyAr: isApproved
          ? 'تمت الموافقة على شقتك "${apt.titleAr ?? apt.title}" وأصبحت ظاهرة للمستأجرين.'
          : 'تم رفض شقتك "${apt.titleAr ?? apt.title}" من قبل الإدارة.'
                '${(rejectionNote != null && rejectionNote.trim().isNotEmpty) ? "\nالسبب: $rejectionNote" : ""}',

      data: {
        'apartmentId': apt.id,
        'status': newStatus,
        'type': 'apartment_status',
        if (rejectionNote != null) 'rejectionNote': rejectionNote,
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // ✅ 1) اشتراك favorites من Firestore
    _favSub = _favService.watchIds(currentUserId).listen((ids) {
      if (!mounted) return;

      setState(() {
        _savedIds
          ..clear()
          ..addAll(ids);

        // تحديث flags على القائمة الحالية
        _apartments = _apartments
            .map((a) => a.copyWith(saved: _savedIds.contains(a.id)))
            .toList();
      });
    });

    // ✅ 2) اشتراك الشقق (زي ما عندك)
    _aptSub = _aptService.watchApproved().listen((list) {
      if (!mounted) return;

      final merged = list
          .map((a) => a.copyWith(saved: _savedIds.contains(a.id)))
          .toList();

      setState(() => _apartments = merged);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final target = widget.initialNavigate;
      if (!_didAutoNavigate && target != null) {
        _didAutoNavigate = true;
        _handleNavigate(target);
      }
    });
  }

  @override
  void dispose() {
    _aptSub?.cancel();
    _favSub?.cancel();
    super.dispose();
  }

  void _toggleSave(String id) {
    final wasSaved = _savedIds.contains(id);

    // ✅ تحديث فوري UI (Optimistic)
    setState(() {
      if (wasSaved) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }

      _apartments = _apartments
          .map(
            (a) => a.id == id ? a.copyWith(saved: _savedIds.contains(id)) : a,
          )
          .toList();
    });

    // ✅ كتابة على Firestore
    unawaited(
      _favService
          .setFavorite(
            uid: currentUserId,
            apartmentId: id,
            isFavorite: !wasSaved,
          )
          .catchError((e) {
            if (!mounted) return;

            // ❌ لو فشل: رجّع الحالة
            setState(() {
              if (wasSaved) {
                _savedIds.add(id);
              } else {
                _savedIds.remove(id);
              }

              _apartments = _apartments
                  .map(
                    (a) => a.id == id
                        ? a.copyWith(saved: _savedIds.contains(id))
                        : a,
                  )
                  .toList();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Favorite update failed: $e')),
            );
          }),
    );
  }

  Future<void> _createOrder(Apartment apartment) async {
    if (_isCreatingRequest) return;

    // ✅ فقط المستأجر
    if (widget.currentUser.role != UserRole.tenant) {
      // خليه يرجع رسالة من شاشة التفاصيل (أو ابقِ SnackBar هنا إذا بدك)
      throw Exception('ONLY_TENANT');
    }

    // ✅ منع المالك يطلب شقته
    if (widget.currentUser.id == apartment.ownerId) {
      throw Exception('OWN_APARTMENT');
    }

    setState(() => _isCreatingRequest = true);

    try {
      await _rentalService.createRequest(
        tenant: widget.currentUser,
        apartment: apartment,
        note: null,
      );
    } finally {
      if (mounted) setState(() => _isCreatingRequest = false);
    }
  }

  void _viewDetails(String id) {
    final index = _apartments.indexWhere((a) => a.id == id);
    if (index == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Apartment not found (data refreshed). Please try again.',
              'الشقة غير موجودة (تم تحديث البيانات). حاول مرة أخرى.',
            ),
          ),
        ),
      );
      return;
    }
    final apt = _apartments[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApartmentDetailsScreen(
          apartment: apt,
          onToggleSave: _toggleSave,
          onChat: (ownerId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  recipientId: ownerId,
                  recipientName: apt.ownerName,
                ),
              ),
            );
          },
          onRequest: () async => await _createOrder(apt),
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filters = {};
    });
  }

  void _showFilters() {
    // base list اللي بتفلتر عليها في الهوم فعليًا
    final base = _apartments.where((a) => a.status == 'approved').toList();

    // حدود ديناميكية (اختياري) حسب البيانات الحالية
    double minPriceBound = 0;
    double maxPriceBound = 500;
    double maxDistanceBound = 10;

    if (base.isNotEmpty) {
      final prices = base.map((e) => e.price).toList();
      final dists = base.map((e) => e.distance).toList();

      prices.sort();
      dists.sort();

      minPriceBound = (prices.first).floorToDouble();
      maxPriceBound = (prices.last).ceilToDouble();
      if (maxPriceBound <= minPriceBound) maxPriceBound = minPriceBound + 1;

      maxDistanceBound = (dists.last).ceilToDouble();
      if (maxDistanceBound <= 0) maxDistanceBound = 10;

      // سقف لطيف عشان السلايدر ما يصير ضخم
      if (maxPriceBound < 300) maxPriceBound = 300;
      if (maxDistanceBound < 5) maxDistanceBound = 5;
      if (maxDistanceBound > 30) maxDistanceBound = 30;
    }

    // نفس منطق الفلترة (Local) لكن لحساب العدد فقط
    int previewCount(Map<String, dynamic> draft) {
      double? parseDouble(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        final s = v.toString().trim();
        if (s.isEmpty) return null;
        return double.tryParse(s);
      }

      int? parseInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        final s = v.toString().trim();
        if (s.isEmpty) return null;
        return int.tryParse(s);
      }

      final minPrice = parseDouble(draft['minPrice']);
      final maxPrice = parseDouble(draft['maxPrice']);
      final maxDistance = parseDouble(draft['maxDistance']);
      final roomsMin = parseInt(draft['rooms']);
      final bathroomsMin = parseInt(draft['bathrooms']);
      final furnishedOnly = (draft['furnishedOnly'] as bool?) ?? false;

      return base.where((apt) {
        if (minPrice != null && apt.price < minPrice) return false;
        if (maxPrice != null && apt.price > maxPrice) return false;
        if (maxDistance != null && apt.distance > maxDistance) return false;
        if (roomsMin != null && apt.rooms < roomsMin) return false;
        if (bathroomsMin != null && apt.bathrooms < bathroomsMin) return false;
        if (furnishedOnly && !apt.furnished) return false;
        return true;
      }).length;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FiltersScreen(
          initialFilters: _filters,
          priceMinBound: minPriceBound,
          priceMaxBound: maxPriceBound,
          distanceMaxBound: maxDistanceBound,
          previewCount: previewCount,
          onApply: (filters) {
            setState(() {
              _filters = filters;
            });
          },
        ),
      ),
    );
  }

  void _handleNavigate(String screen) {
    if (screen == 'owner-dashboard' && userRole == UserRole.owner) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StreamBuilder<List<Apartment>>(
            stream: _aptService.watchForOwner(currentUserId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Scaffold(
                  body: Center(child: Text('Error: ${snap.error}')),
                );
              }

              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final list = snap.data ?? <Apartment>[];
              final apartments = list
                  .map((a) => a.copyWith(saved: _savedIds.contains(a.id)))
                  .toList();

              return OwnerDashboardScreen(
                apartments: apartments,
                currentOwnerId: currentUserId,
                onAddNew: () async {
                  final safeCtx = this.context;
                  final result = await Navigator.push<Map<String, dynamic>?>(
                    safeCtx,
                    MaterialPageRoute(
                      builder: (_) => const AddApartmentScreen(),
                    ),
                  );

                  if (result == null) return;

                  final lat = double.tryParse((result['lat'] ?? '').toString());
                  final lng = double.tryParse((result['lng'] ?? '').toString());

                  if (lat == null || lng == null) {
                    ScaffoldMessenger.of(safeCtx).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(safeCtx, 'Location is required.', 'الموقع مطلوب.'),
                        ),
                      ),
                    );
                    return;
                  }

                  // ✅ حساب المسافة من الجامعة
                  final aptLat = double.tryParse(
                    (result['lat'] ?? '').toString(),
                  );
                  final aptLng = double.tryParse(
                    (result['lng'] ?? '').toString(),
                  );

                  final distanceKm = (aptLat != null && aptLng != null)
                      ? _haversineKm(_ttuLat, _ttuLng, aptLat, aptLng)
                      : 0.0;

                  final newImagePaths =
                      (result['newImagePaths'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];
                  final coverKey = (result['coverKey'] ?? '').toString().trim();

                  final newApt = Apartment(
                    id: '',
                    ownerId: currentUserId,
                    title: result['title'] as String,
                    titleAr:
                        (result['titleAr'] as String?)?.trim().isEmpty == true
                        ? null
                        : result['titleAr'] as String?,
                    price: double.tryParse(result['price'] as String) ?? 0,
                    rooms: int.tryParse(result['rooms'] as String) ?? 0,
                    bathrooms:
                        int.tryParse((result['bathrooms'] as String? ?? '')) ??
                        1,
                    distance: distanceKm,

                    description: result['description'] as String,
                    descriptionAr:
                        (result['descriptionAr'] as String?)?.trim().isEmpty ==
                            true
                        ? null
                        : result['descriptionAr'] as String?,
                    furnished: result['furnished'] as bool,
                    address: result['address'] as String,
                    lat: lat,
                    lng: lng,
                    images: const [], // نخليها فاضية أولاً
                    ownerName: widget.currentUser.displayName ?? 'Owner',
                    ownerPhone: widget.currentUser.phone ?? '+9627XXXXXXX',
                    status: 'pending',
                    createdAt: DateTime.now(),
                  );

                  String? apartmentId;

                  try {
                    apartmentId = await _aptService.createApartmentAndReturnId(
                      newApt,
                    );

                    final files = newImagePaths.map((p) => XFile(p)).toList();

                    if (files.isNotEmpty) {
                      // 1) ارفع الصور وخذ الـ URLs الجديدة
                      final added = await _aptImageService.addImages(
                        apartmentId: apartmentId,
                        ownerId: currentUserId,
                        files: files,
                        startOrderIndex: 0,
                      );

                      final uploadedUrls = added.map((e) => e.url).toList();

                      // 2) حدّد coverUrl حسب coverKey
                      String? coverUrl;

                      // إذا المستخدم اختار صورة من الصور الجديدة (coverKey = path)
                      final coverIndex = newImagePaths.indexOf(coverKey);
                      if (coverIndex >= 0 && coverIndex < uploadedUrls.length) {
                        coverUrl = uploadedUrls[coverIndex];
                      }

                      // إذا ما حدد أو ما لقيناه: خلّي أول صورة هي الغلاف
                      coverUrl ??= uploadedUrls.isNotEmpty
                          ? uploadedUrls.first
                          : null;

                      // 3) رتّب الصور بحيث الغلاف أولًا
                      final orderedUrls = (coverUrl == null)
                          ? uploadedUrls
                          : [
                              coverUrl,
                              ...uploadedUrls.where((u) => u != coverUrl),
                            ];

                      // 4) طبّق الترتيب والغلاف على Firestore (images[] + coverImageUrl)
                      await _aptImageService.applyOrderAndCoverFromUrls(
                        apartmentId: apartmentId,
                        orderedUrls: orderedUrls,
                      );
                    }

                    // ✅ إشعار الأدمن مرة واحدة
                    await _notifyAdminsApartmentPending(
                      apartmentId: apartmentId,
                      ownerId: currentUserId,
                      ownerName: widget.currentUser.displayName ?? 'Owner',
                      apartmentTitle: newApt.title,
                    );

                    // ✅ SnackBar نجاح للمالك
                    if (!mounted) return;
                    ScaffoldMessenger.of(safeCtx).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr(
                            safeCtx,
                            'Apartment created successfully.',
                            'تم إنشاء الشقة بنجاح.',
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    if (apartmentId != null) {
                      // ✅ تنظيف مضمون
                      await _aptImageService.deleteAllImages(apartmentId);
                      await _aptService.deleteApartment(apartmentId);
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(safeCtx).showSnackBar(
                      SnackBar(
                        content: Text('Error while uploading images: $e'),
                      ),
                    );
                  }
                },
                orders: _orders,
                onEditApartment: (apartment) async {
                  final result = await Navigator.push<Map<String, dynamic>?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddApartmentScreen(initialApartment: apartment),
                    ),
                  );

                  if (result == null) return;

                  final existing =
                      (result['existingImages'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];

                  final newPaths =
                      (result['newImagePaths'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];

                  final coverKey = (result['coverKey'] ?? '').toString().trim();

                  final removed = apartment.images
                      .where(
                        (url) =>
                            url.startsWith('http') && !existing.contains(url),
                      )
                      .toList();

                  try {
                    await _aptImageService.deleteImagesByUrls(
                      apartmentId: apartment.id,
                      urlsToDelete: removed,
                    );

                    final added = await _aptImageService.addImages(
                      apartmentId: apartment.id,
                      ownerId: currentUserId,
                      files: newPaths.map((p) => XFile(p)).toList(),
                      startOrderIndex: existing.length,
                    );

                    final addedUrls = added.map((e) => e.url).toList();

                    final mergedUrls = [...existing, ...addedUrls];

                    // 1) استخرج coverUrl من coverKey
                    String? coverUrl;

                    // إذا coverKey URL (صورة قديمة)
                    if (coverKey.startsWith('http') &&
                        mergedUrls.contains(coverKey)) {
                      coverUrl = coverKey;
                    } else {
                      // إذا coverKey path لصورة جديدة
                      final idx = newPaths.indexOf(coverKey);
                      if (idx >= 0 && idx < addedUrls.length) {
                        coverUrl = addedUrls[idx];
                      }
                    }

                    // إذا ما حدد أو مش موجود: خلّي أول صورة
                    coverUrl ??= mergedUrls.isNotEmpty
                        ? mergedUrls.first
                        : null;

                    // 2) رتّب بحيث الغلاف أولًا
                    final orderedUrls = (coverUrl == null)
                        ? mergedUrls
                        : [coverUrl, ...mergedUrls.where((u) => u != coverUrl)];

                    // 3) طبّق الترتيب والغلاف
                    await _aptImageService.applyOrderAndCoverFromUrls(
                      apartmentId: apartment.id,
                      orderedUrls: orderedUrls,
                    );

                    final newLat = double.tryParse(
                      (result['lat'] ?? '').toString(),
                    );
                    final newLng = double.tryParse(
                      (result['lng'] ?? '').toString(),
                    );

                    // لو فشل التحويل لأي سبب، خذ القديم
                    final latFinal = newLat ?? apartment.lat;
                    final lngFinal = newLng ?? apartment.lng;

                    final distanceKm = (latFinal != null && lngFinal != null)
                        ? _haversineKm(_ttuLat, _ttuLng, latFinal, lngFinal)
                        : apartment.distance;
                    final wasRejected = apartment.status == 'rejected';

                    final updated = apartment.copyWith(
                      status: wasRejected ? 'pending' : apartment.status,

                      title: result['title'] as String,
                      titleAr:
                          (result['titleAr'] as String?)?.trim().isEmpty == true
                          ? null
                          : result['titleAr'] as String?,
                      price:
                          double.tryParse(result['price'].toString()) ??
                          apartment.price,
                      rooms:
                          int.tryParse(result['rooms'].toString()) ??
                          apartment.rooms,
                      bathrooms:
                          int.tryParse(
                            (result['bathrooms'] as String? ?? ''),
                          ) ??
                          apartment.bathrooms,

                      // ✅ بدل result['distance'] (غير موجود)
                      distance: distanceKm,

                      description: result['description'] as String,
                      descriptionAr:
                          (result['descriptionAr'] as String?)
                                  ?.trim()
                                  .isEmpty ==
                              true
                          ? null
                          : result['descriptionAr'] as String?,
                      furnished: result['furnished'] as bool,

                      address:
                          (result['address'] as String?)?.trim().isEmpty == true
                          ? apartment.address
                          : result['address'] as String,

                      lat: latFinal,
                      lng: lngFinal,

                      images: mergedUrls,
                    );

                    await _aptService.updateApartmentDetails(updated);

                    if (wasRejected) {
                      await _aptService.clearRejectionNote(apartment.id);

                      // (اختياري ممتاز) ابعث إشعار للأدمن إن الشقة رجعت للمراجعة
                      await _notifyAdminsApartmentPending(
                        apartmentId: apartment.id,
                        ownerId: currentUserId,
                        ownerName: widget.currentUser.displayName ?? 'Owner',
                        apartmentTitle: updated.title,
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error while updating images: $e'),
                      ),
                    );
                  }
                },

                onDeleteApartment: (apartment) async {
                  final confirmed =
                      await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(tr(ctx, 'Delete apartment', 'حذف الشقة')),
                          content: Text(
                            tr(
                              ctx,
                              'Are you sure you want to delete this apartment?',
                              'هل أنت متأكد أنك تريد حذف هذه الشقة؟',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(tr(ctx, 'Cancel', 'إلغاء')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(tr(ctx, 'Delete', 'حذف')),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!confirmed) return;

                  try {
                    // optional: show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    await _aptImageService.deleteAllImages(apartment.id);
                    await _aptService.deleteApartment(apartment.id);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  } finally {
                    if (Navigator.canPop(context))
                      Navigator.pop(context); // close loading
                  }
                },

                onOpenRequests: (apartment) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OwnerApartmentRequestsScreen(apartment: apartment),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    } else if (screen == 'owner-orders' && userRole == UserRole.owner) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OwnerOrdersScreen()),
      );
    } else if (screen == 'admin-panel' && userRole == UserRole.admin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) {
            return StreamBuilder<List<Apartment>>(
              stream: _aptService.watchAll(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Scaffold(
                    body: Center(child: Text('Error: ${snap.error}')),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final apartments = snap.data ?? <Apartment>[];

                return AdminPanelScreen(
                  apartments: apartments,
                  onApprove: (id) async {
                    final apt = _findApt(apartments, id);
                    if (apt == null) return;

                    final changed = await _aptService.setStatusIfChanged(
                      id,
                      'approved',
                    );
                    if (changed) {
                      await _notifyOwnerApartmentStatus(
                        apt: apt,
                        newStatus: 'approved',
                      );
                    }
                  },
                  onReject: (id, reason) async {
                    final apt = _findApt(apartments, id);
                    if (apt == null) return;

                    final changed = await _aptService.rejectWithNote(
                      id,
                      reason,
                    );
                    if (changed) {
                      await _notifyOwnerApartmentStatus(
                        apt: apt,
                        newStatus: 'rejected',
                        rejectionNote: reason,
                      );
                    }
                  },

                  onOpenApartment: (apartment) {
                    _viewDetails(apartment.id);
                  },
                );
              },
            );
          },
        ),
      );
    } else if (screen == 'chat-list') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatListScreen(
            onSelectChat: (recipientId, recipientName) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    recipientId: recipientId,
                    recipientName: recipientName,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (screen == 'tenant-orders') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TenantOrdersScreen()),
      );
    }
  }

  static const double _ttuLat = 30.8410169;
  static const double _ttuLng = 35.6429248;

  double _deg2rad(double deg) => deg * (Math.pi / 180.0);

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a =
        (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
        Math.cos(_deg2rad(lat1)) *
            Math.cos(_deg2rad(lat2)) *
            (Math.sin(dLon / 2) * Math.sin(dLon / 2));

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      apartments: _apartments,
      onToggleSave: _toggleSave,
      onViewDetails: _viewDetails,
      onShowFilters: _showFilters,
      onNavigate: _handleNavigate,
      userRole: userRole,
      onLogout: widget.onLogout,
      filters: _filters,
      onClearFilters: _clearFilters,
      notifService: _notifService,
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Apartment> apartments;
  final void Function(String id) onToggleSave;
  final void Function(String id) onViewDetails;
  final VoidCallback onShowFilters;
  final void Function(String screen) onNavigate;
  final UserRole userRole;
  final VoidCallback onLogout;
  final Map<String, dynamic> filters;
  final VoidCallback onClearFilters;
  final NotificationService notifService;

  const HomeScreen({
    super.key,
    required this.apartments,
    required this.onToggleSave,
    required this.onViewDetails,
    required this.onShowFilters,
    required this.onNavigate,
    required this.userRole,
    required this.onLogout,
    required this.filters,
    required this.onClearFilters,
    required this.notifService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _activeTab = 'home';

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final u = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(u!.uid)
        .snapshots();
  }

  List<Apartment> _searchFilter(List<Apartment> base) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return base;

    return base.where((apt) {
      final tEn = apt.title.toLowerCase();
      final tAr = (apt.titleAr ?? '').toLowerCase();
      final dEn = apt.description.toLowerCase();
      final dAr = (apt.descriptionAr ?? '').toLowerCase();

      return tEn.contains(q) ||
          tAr.contains(q) ||
          dEn.contains(q) ||
          dAr.contains(q);
    }).toList();
  }

  List<Apartment> _applyFilters(List<Apartment> base) {
    final f = widget.filters;
    if (f.isEmpty) return base;

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    final double? minPrice = parseDouble(f['minPrice']);
    final double? maxPrice = parseDouble(f['maxPrice']);
    final double? maxDistance = parseDouble(f['maxDistance']);

    // ✅ At least (>=)
    final int? roomsMin = parseInt(f['rooms']);
    final int? bathroomsMin = parseInt(f['bathrooms']);

    final bool furnishedOnly = (f['furnishedOnly'] as bool?) ?? false;

    return base.where((apt) {
      if (minPrice != null && apt.price < minPrice) return false;
      if (maxPrice != null && apt.price > maxPrice) return false;
      if (maxDistance != null && apt.distance > maxDistance) return false;

      if (roomsMin != null && apt.rooms < roomsMin) return false;
      if (bathroomsMin != null && apt.bathrooms < bathroomsMin) return false;

      if (furnishedOnly && !apt.furnished) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasActiveFilters = widget.filters.isNotEmpty;

    final approved = widget.apartments
        .where((apt) => apt.status == 'approved')
        .toList();

    final filteredApproved = _applyFilters(approved);

    final nearby = filteredApproved.where((apt) => apt.distance <= 1.5).toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    final recommended = List<Apartment>.from(filteredApproved)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // ✅ الأحدث أولاً

    final savedBase = widget.apartments.where((a) => a.saved).toList();
    final filteredSavedBase = _applyFilters(savedBase);

    final filteredRecommended = _searchFilter(recommended);
    final filteredSaved = _searchFilter(filteredSavedBase);

    Widget buildHomeTab() {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          if (_searchQuery.isEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr(context, 'Nearby to TTU', 'شقق قريبة من الجامعة'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: nearby.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NearbyApartmentsScreen(
                                apartments: nearby,
                                onToggleSave: widget.onToggleSave,
                                onTap: widget.onViewDetails,
                              ),
                            ),
                          );
                        },
                  child: Text(tr(context, 'Show all', 'عرض الكل')),
                ),
              ],
            ),

            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: nearby.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final apt = nearby[index];
                  return SizedBox(
                    width: 280,
                    child: ApartmentCard(
                      apartment: apt,
                      onToggleSave: widget.onToggleSave,
                      onTap: widget.onViewDetails,
                      badgeText: tr(
                        context,
                        'Near TTU',
                        'قريب من الجامعة',
                      ), // ✅ جديد
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            _searchQuery.isEmpty
                ? tr(context, ' Newest Apartments', ' أحدث الشقق')
                : tr(context, ' Search Results', ' نتائج البحث'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (filteredRecommended.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  tr(context, 'No apartments found.', 'لا توجد شقق مطابقة.'),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: filteredRecommended.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 0.78,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final apt = filteredRecommended[index];
                return ApartmentCard(
                  apartment: apt,
                  onToggleSave: widget.onToggleSave,
                  onTap: widget.onViewDetails,
                );
              },
            ),
        ],
      );
    }

    Widget buildSavedTab() {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Text(
            tr(context, ' Saved Apartments', ' الشقق المحفوظة'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (filteredSaved.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  tr(
                    context,
                    'No saved apartments yet.',
                    'لا يوجد عناصر محفوظة.',
                  ),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ...filteredSaved.map(
              (apt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ApartmentCard(
                  apartment: apt,
                  onToggleSave: widget.onToggleSave,
                  onTap: widget.onViewDetails,
                ),
              ),
            ),
        ],
      );
    }

    Widget buildProfileTab() {
      final scheme = Theme.of(context).colorScheme;
      final favCount = widget.apartments.where((a) => a.saved).length;

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            tr(context, 'Profile & Settings', 'الحساب والإعدادات'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // ✅ Header Card
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userDocStream(),
            builder: (context, snap) {
              final auth = FirebaseAuth.instance.currentUser;

              String email = auth?.email ?? '';
              String name = (auth?.displayName ?? '').trim();
              String roleStr = '';
              String phone = '';

              // اقرأ من Firestore إذا متوفر
              if (snap.hasData && snap.data?.data() != null) {
                final data = snap.data!.data()!;
                email = (data['email'] ?? email).toString();
                name = (data['displayName'] ?? name).toString().trim();
                roleStr = (data['role'] ?? '').toString();
                phone = (data['phone'] ?? '').toString().trim();
              }

              if (name.isEmpty) {
                name = tr(context, 'User', 'مستخدم');
              }

              String roleLabel;
              switch (roleStr) {
                case 'admin':
                  roleLabel = tr(context, 'Admin', 'أدمن');
                  break;
                case 'owner':
                  roleLabel = tr(context, 'Owner', 'مالك');
                  break;
                default:
                  roleLabel = tr(context, 'Tenant', 'مستأجر');
              }

              final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Text(
                          initials,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(tr(context, 'Edit', 'تعديل')),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ---------------- Account ----------------
          Text(
            tr(context, 'Account', 'الحساب'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: Icon(Icons.person_outline, color: scheme.onSurface),
            title: Text(tr(context, 'My Profile', 'ملفي الشخصي')),
            subtitle: Text(
              tr(context, 'View account information', 'عرض معلومات الحساب'),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyProfileScreen()),
              );
            },
          ),

          ListTile(
            leading: Icon(
              Icons.favorite_border_rounded,
              color: scheme.onSurface,
            ),
            title: Text(tr(context, 'My Favorites', 'المفضلة')),
            subtitle: Text(
              tr(context, 'View saved apartments', 'عرض الشقق المحفوظة'),
            ),
            trailing: favCount == 0
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      favCount.toString(),
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
            onTap: () {
              setState(() => _activeTab = 'saved');
            },
          ),

          ListTile(
            leading: Icon(Icons.notifications_none, color: scheme.onSurface),
            title: Text(tr(context, 'Notifications', 'الإشعارات')),
            subtitle: Text(
              tr(context, 'View your latest updates', 'عرض آخر التحديثات'),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationsScreen()),
              );
            },
          ),
          const Divider(),

          ListTile(
            leading: Icon(Icons.tune_rounded, color: scheme.onSurface),
            title: Text(
              tr(context, 'Notification Settings', 'إعدادات الإشعارات'),
            ),
            subtitle: Text(
              tr(
                context,
                'Control phone notifications',
                'تحكم بإشعارات الهاتف',
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),

          if (widget.userRole == UserRole.tenant) ...[
            ListTile(
              leading: Icon(Icons.assignment_outlined, color: scheme.onSurface),
              title: Text(
                tr(context, 'My rental requests', 'طلبات الاستئجار الخاصة بي'),
              ),
              subtitle: Text(
                tr(
                  context,
                  'View apartments you requested',
                  'عرض الشقق التي قمت بطلبها',
                ),
              ),
              onTap: () => widget.onNavigate('tenant-orders'),
            ),
            const Divider(),
          ],
          const Divider(),

          // ---------------- App Settings ----------------
          Text(
            tr(context, 'App Settings', 'إعدادات التطبيق'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),

          ListTile(
            leading: Icon(Icons.language_outlined, color: scheme.onSurface),
            title: Text(tr(context, 'Language', 'اللغة')),
            subtitle: Text(
              settings.language == AppLanguage.ar ? 'العربية' : 'English',
            ),
            trailing: TextButton(
              onPressed: settings.toggleLanguage,
              child: Text(tr(context, 'Switch', 'تبديل')),
            ),
          ),

          SwitchListTile(
            value: settings.isDark,
            onChanged: (_) => settings.toggleTheme(),
            title: Text(tr(context, 'Dark Mode', 'الوضع الليلي')),
            secondary: Icon(Icons.dark_mode_outlined, color: scheme.onSurface),
          ),

          const Divider(),

          // ---------------- Owner Tools ----------------
          if (widget.userRole == UserRole.owner) ...[
            Text(
              tr(context, 'Owner Tools', 'خيارات المالك'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),

            ListTile(
              leading: Icon(Icons.home_work_outlined, color: scheme.onSurface),
              title: Text(tr(context, 'My Listings', 'شُققي')),
              onTap: () => widget.onNavigate('owner-dashboard'),
            ),

            ListTile(
              leading: Icon(Icons.add_home_outlined, color: scheme.onSurface),
              title: Text(tr(context, 'Add New Apartment', 'إضافة شقة جديدة')),
              onTap: () => widget.onNavigate('owner-dashboard'),
            ),

            ListTile(
              leading: Icon(Icons.assignment_outlined, color: scheme.onSurface),
              title: Text(
                tr(context, 'Requests to my apartments', 'طلبات على شققي'),
              ),
              onTap: () => widget.onNavigate('owner-orders'),
            ),

            const Divider(),
          ],

          // ---------------- Admin Tools ----------------
          if (widget.userRole == UserRole.admin) ...[
            Text(
              tr(context, 'Admin Tools', 'خيارات الإدارة'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),

            ListTile(
              leading: Icon(
                Icons.admin_panel_settings_outlined,
                color: scheme.onSurface,
              ),
              title: Text(tr(context, 'Admin Panel', 'لوحة الإدارة')),
              onTap: () => widget.onNavigate('admin-panel'),
            ),

            const Divider(),
          ],

          // ---------------- Logout ----------------
          ListTile(
            leading: Icon(Icons.logout_rounded, color: scheme.error),
            title: Text(
              tr(context, 'Log out', 'تسجيل الخروج'),
              style: TextStyle(color: scheme.error),
            ),
            onTap: () async {
              final ok =
                  await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tr(ctx, 'Log out?', 'تسجيل الخروج؟')),
                      content: Text(tr(ctx, 'Are you sure?', 'هل أنت متأكد؟')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(tr(ctx, 'Cancel', 'إلغاء')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(tr(ctx, 'Log out', 'خروج')),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (!ok) return;

              Navigator.of(context).popUntil((route) => route.isFirst);
              widget.onLogout();
            },
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 48,
              left: 24,
              right: 24,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'Find Your Home', 'اعثر على سكنك'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(context, 'Near TTU Campus', 'بالقرب من الجامعة'),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    StreamBuilder<int>(
                      stream: widget.notifService.watchUnreadCount(
                        FirebaseAuth.instance.currentUser!.uid,
                      ),
                      builder: (context, snap) {
                        final unread = snap.data ?? 0;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.notifications_none),
                            ),

                            if (unread > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: scheme.surface,
                                      width: 2,
                                    ), // حل تغطية الخلفية
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : unread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_activeTab == 'home' || _activeTab == 'saved')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: tr(
                              context,
                              'Search apartments...',
                              'ابحث عن شقة...',
                            ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(
                                color: scheme.outlineVariant,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton.outlined(
                            onPressed: widget.onShowFilters,
                            icon: Icon(
                              Icons.tune_rounded,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (hasActiveFilters)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: _activeTab == 'home'
                ? buildHomeTab()
                : _activeTab == 'saved'
                ? buildSavedTab()
                : _activeTab == 'profile'
                ? buildProfileTab()
                : buildHomeTab(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndexFromName(_activeTab),
        onTap: (index) {
          final name = _tabNameFromIndex(index);

          if (name == 'home' && _activeTab == 'home') {
            widget.onClearFilters();
            setState(() {
              _searchQuery = '';
            });
            return;
          }

          setState(() => _activeTab = name);

          if (name == 'messages') {
            widget.onNavigate('chat-list');
          }
        },
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF64748B),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_rounded),
            label: tr(context, 'Home', 'الرئيسية'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_border_rounded),
            label: tr(context, 'Saved', 'المحفوظات'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: tr(context, 'Messages', 'الرسائل'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            label: tr(context, 'Profile', 'حسابي'),
          ),
        ],
      ),
    );
  }

  int _tabIndexFromName(String name) {
    switch (name) {
      case 'home':
        return 0;
      case 'saved':
        return 1;
      case 'messages':
        return 2;
      case 'profile':
        return 3;
      default:
        return 0;
    }
  }

  String _tabNameFromIndex(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'saved';
      case 2:
        return 'messages';
      case 3:
        return 'profile';
      default:
        return 'home';
    }
  }
}

class NearbyApartmentsScreen extends StatelessWidget {
  final List<Apartment> apartments;
  final void Function(String id) onToggleSave;
  final void Function(String id) onTap;

  const NearbyApartmentsScreen({
    super.key,
    required this.apartments,
    required this.onToggleSave,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Nearby to TTU', 'قريبة من الجامعة')),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      backgroundColor: scheme.surface,
      body: apartments.isEmpty
          ? Center(
              child: Text(
                tr(context, 'No nearby apartments.', 'لا توجد شقق قريبة.'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: apartments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final apt = apartments[i];
                return ApartmentCard(
                  apartment: apt,
                  onToggleSave: onToggleSave,
                  onTap: onTap,
                  badgeText: tr(context, 'Near TTU', 'قريب من الجامعة'),
                );
              },
            ),
    );
  }
}
