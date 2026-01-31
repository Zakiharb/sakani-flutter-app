// D:\ttu_housing_app\lib\screens\admin_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'admin_complaints_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final List<Apartment> apartments;
  final Future<void> Function(String id) onApprove;
  final Future<void> Function(String id, String reason) onReject;

  final void Function(Apartment apartment) onOpenApartment;

  const AdminPanelScreen({
    super.key,
    required this.apartments,
    required this.onApprove,
    required this.onReject,
    required this.onOpenApartment,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

enum _AdminTab { pending, reported, stats }

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  _AdminTab _activeTab = _AdminTab.pending;

  bool _isNetworkImage(String path) => path.startsWith('http');

  // 👇 حالة الحظر للمستخدمين (محلياً – حسب الاسم مؤقتاً)
  final Set<String> _busyAptIds = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pendingApartments = widget.apartments
        .where((apt) => apt.status == 'pending')
        .toList();

    final totalApartments = widget.apartments.length;
    final approvedApartments = widget.apartments
        .where((apt) => apt.status == 'approved')
        .length;
    final pendingCount = widget.apartments
        .where((apt) => apt.status == 'pending')
        .length;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(tr(context, 'Admin Panel', 'لوحة الإدارة')),
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      body: Column(
        children: [
          _buildTabs(pendingCount),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildActiveTab(
                pendingApartments: pendingApartments,
                total: totalApartments,
                approved: approvedApartments,
                pending: pendingCount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- Tabs --------------------

  Widget _buildTabs(int pendingCount) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTabItem(
            label: tr(context, 'Pending', 'قيد المراجعة'),
            icon: Icons.home_outlined,
            tab: _AdminTab.pending,
            badgeCount: pendingCount,
          ),
          _buildTabItem(
            label: tr(context, 'Reported', 'المبلغ عنها'),
            icon: Icons.report_problem_outlined,
            tab: _AdminTab.reported,
          ),
          _buildTabItem(
            label: tr(context, 'Stats', 'الإحصائيات'),
            icon: Icons.bar_chart_rounded,
            tab: _AdminTab.stats,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required _AdminTab tab,
    int? badgeCount,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final isActive = _activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),

              // ✅ هذا يمنع overflow
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12, // أصغر شوي لتناسب الموبايل
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),

              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- Active tab content --------------------

  Widget _buildActiveTab({
    required List<Apartment> pendingApartments,
    required int total,
    required int approved,
    required int pending,
  }) {
    switch (_activeTab) {
      case _AdminTab.pending:
        return _buildPendingTab(pendingApartments);
      case _AdminTab.reported:
        return _buildReportedTab();
      case _AdminTab.stats:
        return _buildStatsTab(
          total: total,
          approved: approved,
          pending: pending,
        );
    }
  }

  // -------------------- Pending --------------------

  Widget _buildPendingTab(List<Apartment> pendingApartments) {
    final scheme = Theme.of(context).colorScheme;

    if (pendingApartments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_outlined, size: 64, color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Text(
                tr(context, 'No pending approvals', 'لا توجد شقق قيد المراجعة'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'All apartments have been reviewed',
                  'تمت مراجعة جميع الشقق',
                ),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: pendingApartments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final apartment = pendingApartments[index];
        final firstImage = apartment.images.isNotEmpty
            ? apartment.images.first
            : null;

        return InkWell(
          onTap: () => widget.onOpenApartment(apartment),
          borderRadius: BorderRadius.circular(16),
          child: Card(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: firstImage != null
                        ? (_isNetworkImage(firstImage)
                              ? Image.network(firstImage, fit: BoxFit.cover)
                              : Image.asset(firstImage, fit: BoxFit.cover))
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
                        Text(
                          tr(
                            context,
                            apartment.title,
                            apartment.titleAr ?? apartment.title,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${apartment.price.toStringAsFixed(0)} ${tr(context, "JD/month", "دينار/شهر")} • ${apartment.rooms} ${tr(context, "rooms", "غرف")}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            context,
                            apartment.description,
                            apartment.descriptionAr ?? apartment.description,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: _busyAptIds.contains(apartment.id)
                                    ? null
                                    : () async {
                                        // ✅ استخدم context ثابت للشاشة (مش context تبع item)
                                        final stableCtx = this.context;
                                        final messenger = ScaffoldMessenger.of(
                                          stableCtx,
                                        );

                                        final okMsg = tr(
                                          stableCtx,
                                          'Apartment approved.',
                                          'تمت الموافقة على الشقة.',
                                        );

                                        setState(
                                          () => _busyAptIds.add(apartment.id),
                                        );

                                        try {
                                          await widget.onApprove(apartment.id);

                                          if (!mounted) return;

                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(okMsg),
                                              backgroundColor: const Color(
                                                0xFF22C55E,
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;

                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Approve failed: $e',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => _busyAptIds.remove(
                                                apartment.id,
                                              ),
                                            );
                                          }
                                        }
                                      },

                                icon: const Icon(Icons.check, size: 18),
                                label: Text(tr(context, 'Approve', 'موافقة')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: scheme.error,
                                  side: BorderSide(
                                    color: scheme.errorContainer,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: _busyAptIds.contains(apartment.id)
                                    ? null
                                    : () async {
                                        final stableCtx = this.context;
                                        final messenger = ScaffoldMessenger.of(
                                          stableCtx,
                                        );

                                        final okMsg = tr(
                                          stableCtx,
                                          'Apartment rejected.',
                                          'تم رفض الشقة.',
                                        );

                                        final errColor = Theme.of(
                                          stableCtx,
                                        ).colorScheme.error;

                                        setState(
                                          () => _busyAptIds.add(apartment.id),
                                        );

                                        try {
                                          final reason = await _askRejectReason(
                                            stableCtx,
                                          );
                                          if (reason == null) {
                                            // المستخدم كنسل
                                            return;
                                          }

                                          await widget.onReject(
                                            apartment.id,
                                            reason,
                                          );

                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(okMsg),
                                              backgroundColor: errColor,
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;

                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Reject failed: $e',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => _busyAptIds.remove(
                                                apartment.id,
                                              ),
                                            );
                                          }
                                        }
                                      },

                                icon: const Icon(Icons.close, size: 18),
                                label: Text(tr(context, 'Reject', 'رفض')),
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
          ),
        );
      },
    );
  }

 

  // -------------------- Reported --------------------

  Widget _buildReportedTab() {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.report_problem_outlined,
              size: 64,
              color: scheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, 'Manage complaints', 'إدارة الشكاوى'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                'Review and update complaint statuses.',
                'راجع الشكاوى وغيّر حالتها.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminComplaintsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(tr(context, 'Open complaints', 'فتح الشكاوى')),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- Stats --------------------

  Widget _buildStatsTab({
    required int total,
    required int approved,
    required int pending,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: cardWidth,
                child: _buildStatCard(
                  icon: Icons.home_rounded,
                  iconColor: scheme.primary,
                  title: tr(context, 'Total Apartments', 'عدد الشقق الكلي'),
                  value: '$total',
                  onTap: () => _showApartmentsForStatus(context, null),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildStatCard(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF22C55E),
                  title: tr(context, 'Approved', 'الموافق عليها'),
                  value: '$approved',
                  onTap: () => _showApartmentsForStatus(context, 'approved'),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildStatCard(
                  icon: Icons.hourglass_bottom_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: tr(context, 'Pending', 'قيد المراجعة'),
                  value: '$pending',
                  onTap: () => _showApartmentsForStatus(context, 'pending'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _askRejectReason(BuildContext context) async {
    final c = TextEditingController();
    bool canSubmit = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void recompute() {
              final ok = c.text.trim().isNotEmpty;
              if (ok != canSubmit) setLocal(() => canSubmit = ok);
            }

            return AlertDialog(
              title: Text(tr(ctx, 'Reject apartment', 'رفض الشقة')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      ctx,
                      'Please write the rejection reason (required).',
                      'اكتب سبب الرفض (إجباري).',
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: c,
                    maxLines: 3,
                    onChanged: (_) => recompute(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: tr(
                        ctx,
                        'e.g. Missing clear photos / Wrong location / Incomplete info',
                        'مثال: صور غير واضحة / موقع غير صحيح / معلومات ناقصة',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(tr(ctx, 'Cancel', 'إلغاء')),
                ),
                ElevatedButton(
                  onPressed: canSubmit
                      ? () => Navigator.pop(ctx, c.text.trim())
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(tr(ctx, 'Reject', 'رفض')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 👇 إظهار قائمة شقق حسب الفلتر (للـ Stats)
  void _showApartmentsForStatus(BuildContext context, String? statusFilter) {
    final scheme = Theme.of(context).colorScheme;

    final list = widget.apartments.where((apt) {
      if (statusFilter == null) return true;
      return apt.status == statusFilter;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: list.isEmpty
                ? Center(
                    child: Text(
                      tr(
                        ctx,
                        'No apartments found for this filter.',
                        'لا توجد شقق تحت هذا التصنيف.',
                      ),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(ctx, 'Apartments list', 'قائمة الشقق'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final apt = list[index];
                            return ListTile(
                              title: Text(
                                tr(
                                  context,
                                  apt.title,
                                  apt.titleAr ?? apt.title,
                                ),
                              ),
                              subtitle: Text(
                                '${apt.price.toStringAsFixed(0)} ${tr(context, "JD/month", "دينار/شهر")} • ${apt.rooms} ${tr(context, "rooms", "غرف")}',
                              ),
                              onTap: () {
                                Navigator.of(
                                  ctx,
                                ).pop(); // نسكر الـ bottom sheet
                                widget.onOpenApartment(apt); // نفتح التفاصيل
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: iconColor.withOpacity(0.12),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
