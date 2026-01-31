// D:\ttu_housing_app\lib\screens\apartment_details_screen.dart
import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_complaint_screen.dart';
import 'package:ttu_housing_app/services/rental_request_service.dart';
import 'fullscreen_gallery_screen.dart';

class ApartmentDetailsScreen extends StatefulWidget {
  final Apartment apartment;
  final void Function(String id) onToggleSave;
  final void Function(String ownerId) onChat;
  final Future<void> Function() onRequest;

  const ApartmentDetailsScreen({
    super.key,
    required this.apartment,
    required this.onToggleSave,
    required this.onChat,
    required this.onRequest,
  });

  @override
  State<ApartmentDetailsScreen> createState() => _ApartmentDetailsScreenState();
}

class _ApartmentDetailsScreenState extends State<ApartmentDetailsScreen> {
  int _currentImageIndex = 0;
  late final PageController _imgCtrl;

  Apartment get _apartment => widget.apartment;

  bool _isNetworkImage(String path) => path.startsWith('http');

  bool _descExpanded = false;

  // ✅ احداثيات الجامعة
  static const double _ttuLat = 30.8410169;
  static const double _ttuLng = 35.6429248;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isSendingRequest = false;

  late bool _savedLocal;

  @override
  void initState() {
    super.initState();
    _savedLocal = widget.apartment.saved;
    _imgCtrl = PageController(initialPage: _currentImageIndex);
  }

  @override
  void dispose() {
    _imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    if (uid == _apartment.ownerId) {
      _snack(
        tr(
          context,
          'You cannot request your own apartment.',
          'لا يمكنك طلب شقتك الخاصة.',
        ),
      );
      return;
    }

    if (_isSendingRequest) return;

    setState(() => _isSendingRequest = true);

    try {
      await widget.onRequest();

      // ✅ نجاح
      _snack(
        tr(
          context,
          'Request sent to the owner.',
          'تم إرسال طلب الاستئجار إلى المالك.',
        ),
      );
    } on DuplicatePendingRequestException catch (e) {
      _snack(tr(context, e.messageEn, e.messageAr));
    } on RequestAlreadyAcceptedException catch (e) {
      _snack(tr(context, e.messageEn, e.messageAr));
    } catch (e) {
      final s = e.toString();

      if (s.contains('ONLY_TENANT')) {
        _snack(
          tr(
            context,
            'Only tenants can send rental requests.',
            'فقط المستأجر يمكنه إرسال طلب استئجار.',
          ),
        );
      } else if (s.contains('OWN_APARTMENT')) {
        _snack(
          tr(
            context,
            'You cannot request your own apartment.',
            'لا يمكنك طلب شقتك الخاصة.',
          ),
        );
      } else {
        _snack(
          tr(
            context,
            'Something went wrong. Please try again.',
            'حدث خطأ، حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingRequest = false);
    }
  }

  Future<void> _openInGoogleMaps() async {
    final lat = _apartment.lat;
    final lng = _apartment.lng;

    if (lat == null || lng == null) {
      _snack(
        tr(
          context,
          'Location is not set for this apartment.',
          'موقع الشقة غير محدد.',
        ),
      );
      return;
    }

    // اختيار نقطة البداية
    final originType = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.school),
                title: Text(tr(ctx, 'From University', 'من الجامعة')),
                onTap: () => Navigator.pop(ctx, 'ttu'),
              ),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: Text(tr(ctx, 'From My Location', 'من موقعي الحالي')),
                onTap: () => Navigator.pop(ctx, 'me'),
              ),
            ],
          ),
        );
      },
    );

    if (originType == null) return;

    // اختيار وسيلة النقل
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(tr(ctx, 'Driving', 'بالسيارة')),
                onTap: () => Navigator.pop(ctx, 'driving'),
              ),
              ListTile(
                leading: const Icon(Icons.directions_walk),
                title: Text(tr(ctx, 'Walking', 'مشياً')),
                onTap: () => Navigator.pop(ctx, 'walking'),
              ),
            ],
          ),
        );
      },
    );

    if (mode == null) return;

    // تحديد origin
    String originParam;
    if (originType == 'ttu') {
      originParam = '$_ttuLat,$_ttuLng';
    } else {
      originParam = 'current+location';
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$originParam'
      '&destination=$lat,$lng'
      '&travelmode=$mode',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _snack(
        tr(context, 'Could not open Google Maps.', 'تعذر فتح Google Maps.'),
      );
    }
  }

  void _handleToggleSave() {
    setState(() => _savedLocal = !_savedLocal);
    widget.onToggleSave(_apartment.id);
  }

  Widget _buildImageHeader(
    BuildContext context,
    ColorScheme scheme,
    List<String> images,
  ) {
    final heroPrefix = 'apt_${_apartment.id}_';

    if (images.isEmpty) {
      return Container(
        height: 260,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.home_rounded,
          color: scheme.onSurfaceVariant,
          size: 42,
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          // ✅ صور بسحب (Swipe)
          PageView.builder(
            controller: _imgCtrl,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (_, i) {
              final imgPath = images[i];

              final img = _isNetworkImage(imgPath)
                  ? Image.network(
                      imgPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurfaceVariant,
                          size: 40,
                        ),
                      ),
                    )
                  : Image.asset(
                      imgPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    );

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullscreenGalleryScreen(
                        images: images,
                        initialIndex: _currentImageIndex,
                        heroPrefix: heroPrefix,
                      ),
                    ),
                  );
                },
                child: Hero(tag: '$heroPrefix$i', child: img),
              );
            },
          ),

          // ✅ تدرج خفيف (يعطي فخامة)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ✅ مؤشر رقم الصور (1/5)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

          Positioned(
            bottom: 42,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tr(context, 'Tap to view', 'اضغط للتكبير'),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

          // ✅ dots
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final isActive = index == _currentImageIndex;
                  return GestureDetector(
                    onTap: () {
                      _imgCtrl.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: isActive ? 20 : 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(isActive ? 1 : 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // ✅ أسهم
          if (_currentImageIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavCircleButton(
                  icon: Icons.chevron_left,
                  onTap: () {
                    _imgCtrl.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),

          if (_currentImageIndex < images.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavCircleButton(
                  icon: Icons.chevron_right,
                  onTap: () {
                    _imgCtrl.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsSheet({
    required BuildContext context,
    required ColorScheme scheme,
    required String titleText,
    required String priceText,
    required String distanceText,
    required String descText,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Title
          Text(
            titleText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),

          // ✅ Price + Distance as chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoChip(
                scheme: scheme,
                icon: Icons.payments_outlined,
                text: priceText,
                strong: true,
              ),
              _infoChip(
                scheme: scheme,
                icon: Icons.location_on_outlined,
                text: distanceText,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ✅ Location Section
          _sectionTitle(context, scheme, tr(context, 'Location', 'الموقع')),
          const SizedBox(height: 8),
          _card(
            scheme: scheme,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _apartment.address,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ✅ Open in maps (button) + preview card
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openInGoogleMaps,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    tr(context, 'Open in Google Maps', 'فتح على Google Maps'),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        

          const SizedBox(height: 18),

          // ✅ Description Section (expand/collapse)
          _sectionTitle(context, scheme, tr(context, 'Description', 'الوصف')),
          const SizedBox(height: 8),
          _card(
            scheme: scheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descText,
                  maxLines: _descExpanded ? 50 : 3,
                  overflow: _descExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (descText.trim().length > 90) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _descExpanded = !_descExpanded),
                      child: Text(
                        _descExpanded
                            ? tr(context, 'Show less', 'إخفاء')
                            : tr(context, 'Read more', 'قراءة المزيد'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ✅ Details Section
          _sectionTitle(context, scheme, tr(context, 'Details', 'التفاصيل')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  scheme: scheme,
                  label: tr(context, 'Bedrooms', 'الغرف'),
                  value: '${_apartment.rooms}',
                  icon: Icons.bed_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat(
                  scheme: scheme,
                  label: tr(context, 'Bathrooms', 'الحمامات'),
                  value: '${_apartment.bathrooms}',
                  icon: Icons.bathtub_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _miniStat(
            scheme: scheme,
            label: tr(context, 'Furnished', 'مفروشة'),
            value: _apartment.furnished
                ? tr(context, 'Yes', 'نعم')
                : tr(context, 'No', 'لا'),
            icon: Icons.weekend_outlined,
          ),

          const SizedBox(height: 18),

          // ✅ Owner Section
          _sectionTitle(context, scheme, tr(context, 'Owner', 'المالك')),
          const SizedBox(height: 8),
          _card(
            scheme: scheme,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primary.withOpacity(0.12),
                  child: Text(
                    _apartment.ownerName.isNotEmpty
                        ? _apartment.ownerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _apartment.ownerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _apartment.ownerPhone,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, ColorScheme scheme, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _card({
    required ColorScheme scheme,
    required Widget child,
    double? height,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
      ),
      child: child,
    );
  }

  Widget _infoChip({
    required ColorScheme scheme,
    required IconData icon,
    required String text,
    bool strong = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: strong ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: strong ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required ColorScheme scheme,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return _card(
      scheme: scheme,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = AppSettings.of(context);
    final isAr = settings.language == AppLanguage.ar;

    final images = _apartment.images;
   

    final titleText = tr(
      context,
      _apartment.title,
      _apartment.titleAr ?? _apartment.title,
    );

    final descText = tr(
      context,
      _apartment.description,
      _apartment.descriptionAr ?? _apartment.description,
    );

    final priceText = isAr
        ? '${_apartment.price.toStringAsFixed(0)} دينار / شهر'
        : '${_apartment.price.toStringAsFixed(0)} JD / month';

    final distanceText = isAr
        ? 'تقريباً ${_apartment.distance.toStringAsFixed(1)} كم عن الجامعة (خط مستقيم)'
        : 'Approx. ${_apartment.distance.toStringAsFixed(1)} km to TTU (straight-line)';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(tr(context, 'Details', 'التفاصيل')),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _handleToggleSave,
            icon: Icon(
              _savedLocal ? Icons.favorite : Icons.favorite_border_rounded,
              color: _savedLocal ? Colors.red : scheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Report', 'إبلاغ'),
            icon: const Icon(Icons.report_gmailerrorred_outlined),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              // منع المالك يبلغ على نفسه
              if (uid == _apartment.ownerId) {
                _snack(
                  tr(
                    context,
                    'Owners cannot report their own listing.',
                    'المالك لا يمكنه الإبلاغ عن شقته.',
                  ),
                );
                return;
              }

              final choice = await showModalBottomSheet<ReportTarget>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.home_outlined),
                        title: Text(
                          tr(ctx, 'Report Apartment', 'الإبلاغ عن الشقة'),
                        ),
                        onTap: () => Navigator.pop(ctx, ReportTarget.apartment),
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          tr(ctx, 'Report Owner', 'الإبلاغ عن المالك'),
                        ),
                        onTap: () => Navigator.pop(ctx, ReportTarget.owner),
                      ),
                    ],
                  ),
                ),
              );

              if (choice == null) return;

              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportComplaintScreen(
                    target: choice,
                    apartment: _apartment,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildImageHeader(context, scheme, images),

          const SizedBox(height: 8),
          _buildDetailsSheet(
            context: context,
            scheme: scheme,
            titleText: titleText,
            priceText: priceText,
            distanceText: distanceText,
            descText: descText,
          ),
          const SizedBox(height: 18),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSendingRequest ? null : _handleRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSendingRequest
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(
                    _isSendingRequest
                        ? tr(context, 'Sending...', 'جاري الإرسال...')
                        : tr(context, 'Request to Rent', 'طلب استئجار'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onChat(_apartment.ownerId),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(
                    tr(context, 'Chat with Owner', 'الدردشة مع المالك'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 24, color: scheme.onSurface),
        ),
      ),
    );
  }
}
