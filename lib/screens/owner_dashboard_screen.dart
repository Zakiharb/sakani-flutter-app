// D:\ttu_housing_app\lib\screens\owner_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'package:ttu_housing_app/services/rental_request_service.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final List<Apartment> apartments;
  final String currentOwnerId;

  // ✅ خليهم Future عشان نقدر نعمل await ونحدث UI بعد الرجعة
  final Future<void> Function() onAddNew;
  final List<ApartmentOrder> orders;
  final Future<void> Function(Apartment apartment) onEditApartment;

  final Future<void> Function(Apartment apartment) onDeleteApartment;
  final void Function(Apartment apartment) onOpenRequests;

  const OwnerDashboardScreen({
    super.key,
    required this.apartments,
    required this.currentOwnerId,
    required this.onAddNew,
    required this.orders,
    required this.onEditApartment,
    required this.onDeleteApartment,
    required this.onOpenRequests,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late final RentalRequestService _rentalService;

  @override
  void initState() {
    super.initState();
    _rentalService = RentalRequestService();
  }

  bool _isNetworkImage(String path) => path.startsWith('http');

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return scheme.error;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  String _statusText(BuildContext context, String status) {
    switch (status) {
      case 'approved':
        return tr(context, 'Approved', 'تمت الموافقة');
      case 'pending':
        return tr(context, 'Pending', 'قيد المراجعة');
      case 'rejected':
        return tr(context, 'Rejected', 'مرفوضة');
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final myListings = widget.apartments
        .where((a) => a.ownerId == widget.currentOwnerId)
        .toList();

    Future<void> _refresh() async {
      if (!mounted) return;
      setState(() {});
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'My Listings', 'شُققي')),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await widget.onAddNew();
              await _refresh(); // ✅ يحدث القائمة مباشرة بعد الرجعة
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              tr(context, 'Add New', 'إضافة شقة'),
              style: const TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: scheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      backgroundColor: scheme.surface,
      body: myListings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.home_outlined,
                      size: 64,
                      color: scheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(context, 'No listings yet', 'لا توجد شقق بعد'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        'Start by adding your first apartment listing.',
                        'ابدأ بإضافة أول شقة لك.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await widget.onAddNew();
                        await _refresh();
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        tr(context, 'Add Your First Listing', 'إضافة أول شقة'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: myListings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final apt = myListings[index];

                final statusColor = _statusColor(context, apt.status);
                final chipBg = statusColor.withOpacity(0.12);

                final priceText = tr(
                  context,
                  '${apt.price.toStringAsFixed(0)} JD / month',
                  '${apt.price.toStringAsFixed(0)} دينار / شهر',
                );

                final roomsText = tr(
                  context,
                  '${apt.rooms} room${apt.rooms == 1 ? '' : 's'}',
                  '${apt.rooms} غرفة',
                );

                final distanceText = tr(
                  context,
                  '${apt.distance.toStringAsFixed(1)} km from TTU',
                  '${apt.distance.toStringAsFixed(1)} كم عن الجامعة',
                );

                final firstImage = apt.images.isNotEmpty
                    ? apt.images.first
                    : null;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadiusDirectional.horizontal(
                          start: Radius.circular(16),
                        ),

                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child:
                              (firstImage != null &&
                                  firstImage.trim().isNotEmpty)
                              ? (_isNetworkImage(firstImage)
                                    ? Image.network(
                                        firstImage,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                              if (progress == null)
                                                return child;
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              );
                                            },
                                        errorBuilder: (context, error, stack) {
                                          return Container(
                                            color:
                                                scheme.surfaceContainerHighest,
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              color: scheme.onSurfaceVariant,
                                              size: 28,
                                            ),
                                          );
                                        },
                                      )
                                    : Image.asset(
                                        firstImage,
                                        fit: BoxFit.cover,
                                      ))
                              : Container(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.home_rounded,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr(
                                            context,
                                            apt.title,
                                            apt.titleAr ?? apt.title,
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          priceText,
                                          style: TextStyle(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: chipBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusText(context, apt.status),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$roomsText • $distanceText',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await widget.onEditApartment(apt);
                                      await _refresh(); // ✅ يحدث بعد تعديل الشقة
                                    },
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: Text(tr(context, 'Edit', 'تعديل')),
                                  ),
                                  StreamBuilder<int>(
                                    stream: _rentalService
                                        .watchApartmentRequestsCount(apt.id),
                                    builder: (context, snap) {
                                      final requestsCount = snap.data ?? 0;
                                      final label = requestsCount > 0
                                          ? '${tr(context, 'Requests', 'الطلبات')} ($requestsCount)'
                                          : tr(context, 'Requests', 'الطلبات');

                                      return OutlinedButton.icon(
                                        onPressed: () =>
                                            widget.onOpenRequests(apt),
                                        icon: const Icon(
                                          Icons.message_outlined,
                                          size: 16,
                                        ),
                                        label: Text(label),
                                      );
                                    },
                                  ),

                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final confirmed =
                                          await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text(
                                                tr(
                                                  ctx,
                                                  'Delete apartment',
                                                  'حذف الشقة',
                                                ),
                                              ),
                                              content: Text(
                                                tr(
                                                  ctx,
                                                  'Are you sure you want to delete this apartment?',
                                                  'هل أنت متأكد أنك تريد حذف هذه الشقة؟',
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: Text(
                                                    tr(ctx, 'Cancel', 'إلغاء'),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(true),
                                                  child: Text(
                                                    tr(ctx, 'Delete', 'حذف'),
                                                    style: TextStyle(
                                                      color: Theme.of(
                                                        ctx,
                                                      ).colorScheme.error,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;

                                      if (confirmed) {
                                        await widget.onDeleteApartment(apt);
                                        if (!mounted) return;
                                        setState(() {});
                                      }
                                    },
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: scheme.error,
                                    ),
                                    label: Text(
                                      tr(context, 'Delete', 'حذف'),
                                      style: TextStyle(color: scheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
