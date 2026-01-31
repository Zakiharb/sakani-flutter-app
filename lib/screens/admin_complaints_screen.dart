// D:\ttu_housing_app\lib\screens\admin_complaints_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../app_settings.dart';
import '../models/models.dart';
import '../services/complaint_service.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

enum _ComplaintsTab { apartments, owners }

enum _StatusFilter { open, inReview, resolved, rejected, all }

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _service = ComplaintService();

  _ComplaintsTab _tab = _ComplaintsTab.apartments;
  _StatusFilter _filter = _StatusFilter.open;

  bool _showArchived = false;

  String? _filterValue() {
    switch (_filter) {
      case _StatusFilter.open:
        return 'open';
      case _StatusFilter.inReview:
        return 'in_review';
      case _StatusFilter.resolved:
        return 'resolved';
      case _StatusFilter.rejected:
        return 'rejected';
      case _StatusFilter.all:
        return null;
    }
  }

  // ✅ تحقق بسيط: هل المستخدم Admin؟
  Future<bool> _isAdmin() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .get();
    if (!doc.exists || doc.data() == null) return false;

    return UserRoleX.fromString(doc.data()!['role']?.toString()) ==
        UserRole.admin;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != true) {
          return Scaffold(
            appBar: AppBar(title: Text(tr(context, 'Complaints', 'الشكاوى'))),
            body: Center(
              child: Text(tr(context, 'Access denied', 'ليس لديك صلاحية')),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(tr(context, 'Complaints', 'الشكاوى'))),
          body: Column(
            children: [
              _buildTopControls(context),
              const Divider(height: 1),
              Expanded(child: _buildList(context)),
            ],
          ),
        );
      },
    );
  }

  String reasonLabel(BuildContext context, String code) {
    switch (code) {
      case 'scam':
        return tr(context, 'Scam/Fraud', 'احتيال/نصب');
      case 'price':
        return tr(context, 'Unfair price', 'سعر غير منطقي');
      case 'spam':
        return tr(context, 'Spam', 'إعلان مزعج');
      case 'wrong_info':
        return tr(context, 'Wrong information', 'معلومات خاطئة');
      default:
        return tr(context, 'Other', 'أخرى');
    }
  }

  Widget _buildTopControls(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          // Tabs
          Row(
            children: [
              Expanded(
                child: _chip(
                  context,
                  active: _tab == _ComplaintsTab.apartments,
                  label: tr(context, 'Apartment complaints', 'شكاوى الشقق'),
                  onTap: () => setState(() => _tab = _ComplaintsTab.apartments),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  context,
                  active: _tab == _ComplaintsTab.owners,
                  label: tr(context, 'Owner complaints', 'شكاوى المالكين'),
                  onTap: () => setState(() => _tab = _ComplaintsTab.owners),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filter
          Row(
            children: [
              Icon(Icons.filter_list, color: scheme.onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<_StatusFilter>(
                  value: _filter,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: _StatusFilter.open,
                      child: Text(tr(context, 'Open', 'مفتوحة')),
                    ),
                    DropdownMenuItem(
                      value: _StatusFilter.inReview,
                      child: Text(tr(context, 'In review', 'قيد المراجعة')),
                    ),
                    DropdownMenuItem(
                      value: _StatusFilter.resolved,
                      child: Text(tr(context, 'Resolved', 'تم الحل')),
                    ),
                    DropdownMenuItem(
                      value: _StatusFilter.rejected,
                      child: Text(tr(context, 'Rejected', 'مرفوضة')),
                    ),
                    DropdownMenuItem(
                      value: _StatusFilter.all,
                      child: Text(tr(context, 'All', 'الكل')),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _filter = v ?? _StatusFilter.open),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Show archived', 'إظهار المؤرشفة'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              Switch.adaptive(
                value: _showArchived,
                onChanged: (v) => setState(() => _showArchived = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withOpacity(0.12)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: active ? scheme.primary : scheme.onSurface,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final status = _filterValue();

    if (_tab == _ComplaintsTab.apartments) {
      return StreamBuilder<List<ComplaintApartment>>(
        stream: _service.watchApartmentComplaints(
          status: status,
          includeArchived: _showArchived,
        ),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Text(tr(context, 'No complaints', 'لا توجد شكاوى')),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _apartmentTile(context, items[i]),
          );
        },
      );
    }

    return StreamBuilder<List<ComplaintOwner>>(
      stream: _service.watchOwnerComplaints(
        status: status,
        includeArchived: _showArchived,
      ),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final items = snap.data!;
        if (items.isEmpty) {
          return Center(
            child: Text(tr(context, 'No complaints', 'لا توجد شكاوى')),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _ownerTile(context, items[i]),
        );
      },
    );
  }

  Widget _apartmentTile(BuildContext context, ComplaintApartment c) {
    final isAr = AppSettings.of(context).language == AppLanguage.ar;

    final aptTitle = isAr
        ? (c.apartmentTitleAr ?? c.apartmentId)
        : (c.apartmentTitleEn ?? c.apartmentId);

    final ownerName = c.ownerName ?? c.ownerId;
    final tenantName = c.complainantName ?? c.complainantId;

    return ListTile(
      title: Text(
        isAr
            ? 'شكوى على شقة (${c.status.asString})'
            : 'Apartment complaint (${c.status.asString})',
      ),
      subtitle: Text(
        '${tr(context, 'Reason', 'السبب')}: ${reasonLabel(context, c.reason)}\n'
        '${tr(context, 'Apartment', 'الشقة')}: $aptTitle\n'
        '${tr(context, 'Owner', 'المالك')}: $ownerName\n'
        '${tr(context, 'Tenant', 'المستأجر')}: $tenantName',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openApartmentComplaintDetails(context, c),
    );
  }

  Widget _ownerTile(BuildContext context, ComplaintOwner c) {
    final isAr = AppSettings.of(context).language == AppLanguage.ar;
    final title = isAr
        ? 'شكوى على مالك (${c.status.asString})'
        : 'Owner complaint (${c.status.asString})';

    final ownerName = (c.ownerName?.trim().isNotEmpty ?? false)
        ? c.ownerName!
        : c.ownerId;

    final tenantName = (c.complainantName?.trim().isNotEmpty ?? false)
        ? c.complainantName!
        : c.complainantId;

    return ListTile(
      title: Text(title),
      subtitle: Text(
        '${tr(context, 'Reason', 'السبب')}: ${reasonLabel(context, c.reason)}\n'
        '${tr(context, 'Owner', 'المالك')}: $ownerName\n'
        '${tr(context, 'Tenant', 'المستأجر')}: $tenantName',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openOwnerComplaintDetails(context, c),
    );
  }

  Future<void> _openApartmentComplaintDetails(
    BuildContext context,
    ComplaintApartment c,
  ) async {
    final adminNoteCtrl = TextEditingController(text: c.adminNote ?? '');
    ComplaintStatus selected = c.status;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr(ctx, 'Update complaint', 'تحديث الشكوى')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ComplaintStatus>(
                  value: selected,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: ComplaintStatus.values.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.asString));
                  }).toList(),
                  onChanged: (v) => selected = v ?? selected,
                ),

                _prettyDescriptionBox(context, c.description),

                const SizedBox(height: 10),
                TextField(
                  controller: adminNoteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: tr(
                      ctx,
                      'Admin note (optional)',
                      'ملاحظة للأدمن (اختياري)',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(ctx, 'Cancel', 'إلغاء')),
            ),

            TextButton(
              onPressed: () async {
                final ok =
                    selected == ComplaintStatus.resolved ||
                    selected == ComplaintStatus.rejected;

                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          ctx,
                          'Archive is available after Resolved/Rejected.',
                          'الأرشفة متاحة بعد (تم الحل/مرفوضة).',
                        ),
                      ),
                    ),
                  );
                  return;
                }

                final confirm =
                    await showDialog<bool>(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: Text(
                          tr(ctx, 'Archive complaint?', 'أرشفة الشكوى؟'),
                        ),
                        content: Text(
                          tr(
                            ctx,
                            'It will be hidden from the main list. You can show archived using the toggle.',
                            'ستختفي من القائمة الرئيسية ويمكنك إظهارها من زر "إظهار المؤرشفة".',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(tr(ctx, 'Cancel', 'إلغاء')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(tr(ctx, 'Archive', 'أرشفة')),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (!confirm) return;

                await _service.adminArchiveApartmentComplaint(c);

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr(ctx, 'Archive', 'أرشفة')),
            ),

            TextButton(
              onPressed: () async {
                await _service.adminUpdateApartmentComplaint(
                  c: c,
                  status: selected,
                  adminNote: adminNoteCtrl.text.trim().isEmpty
                      ? null
                      : adminNoteCtrl.text.trim(),
                  notifyTenant: true,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr(ctx, 'Save', 'حفظ')),
            ),
          ],
        );
      },
    );
  }

  Widget _prettyDescriptionBox(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final value = text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notes_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                tr(context, 'User description', 'وصف الشكوى'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: tr(context, 'Copy', 'نسخ'),
                onPressed: value.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr(context, 'Copied.', 'تم النسخ.')),
                          ),
                        );
                      },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: SingleChildScrollView(
              child: Text(
                value.isEmpty
                    ? tr(
                        context,
                        'No description provided.',
                        'لا يوجد وصف إضافي.',
                      )
                    : value,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOwnerComplaintDetails(
    BuildContext context,
    ComplaintOwner c,
  ) async {
    final adminNoteCtrl = TextEditingController(text: c.adminNote ?? '');
    ComplaintStatus selected = c.status;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr(ctx, 'Update complaint', 'تحديث الشكوى')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ComplaintStatus>(
                  value: selected,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: ComplaintStatus.values.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s.asString));
                  }).toList(),
                  onChanged: (v) => selected = v ?? selected,
                ),

                Text(
                  tr(context, 'User description', 'وصف الشكوى'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (c.description.trim().isEmpty)
                        ? tr(
                            context,
                            'No description provided.',
                            'لا يوجد وصف إضافي.',
                          )
                        : c.description,
                  ),
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: adminNoteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: tr(
                      ctx,
                      'Admin note (optional)',
                      'ملاحظة للأدمن (اختياري)',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(ctx, 'Cancel', 'إلغاء')),
            ),

            TextButton(
              onPressed: () async {
                final ok =
                    selected == ComplaintStatus.resolved ||
                    selected == ComplaintStatus.rejected;

                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          ctx,
                          'Archive is available after Resolved/Rejected.',
                          'الأرشفة متاحة بعد (تم الحل/مرفوضة).',
                        ),
                      ),
                    ),
                  );
                  return;
                }

                final confirm =
                    await showDialog<bool>(
                      context: ctx,
                      builder: (dialogCtx) => AlertDialog(
                        title: Text(
                          tr(ctx, 'Archive complaint?', 'أرشفة الشكوى؟'),
                        ),
                        content: Text(
                          tr(
                            ctx,
                            'It will be hidden from the main list. You can show archived using the toggle.',
                            'ستختفي من القائمة الرئيسية ويمكنك إظهارها من زر "إظهار المؤرشفة".',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: Text(tr(ctx, 'Cancel', 'إلغاء')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: Text(tr(ctx, 'Archive', 'أرشفة')),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (!confirm) return;

                await _service.adminArchiveOwnerComplaint(c);

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr(ctx, 'Archive', 'أرشفة')),
            ),

            TextButton(
              onPressed: () async {
                await _service.adminUpdateOwnerComplaint(
                  c: c,
                  status: selected,
                  adminNote: adminNoteCtrl.text.trim().isEmpty
                      ? null
                      : adminNoteCtrl.text.trim(),
                  notifyTenant: true,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr(ctx, 'Save', 'حفظ')),
            ),
          ],
        );
      },
    );
  }
}
