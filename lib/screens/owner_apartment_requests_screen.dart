// D:\ttu_housing_app\lib\screens\owner_apartment_requests_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/screens/chat_screen.dart';
import 'package:ttu_housing_app/services/rental_request_service.dart';

class OwnerApartmentRequestsScreen extends StatelessWidget {
  final Apartment apartment;

  OwnerApartmentRequestsScreen({super.key, required this.apartment});

  final _service = RentalRequestService();

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _statusText(BuildContext context, String status) {
    switch (status) {
      case 'accepted':
        return tr(context, 'Accepted', 'مقبول');
      case 'rejected':
        return tr(context, 'Rejected', 'مرفوض');
      case 'canceled':
        return tr(context, 'Canceled', 'ملغي');
      case 'pending':
      default:
        return tr(context, 'Pending', 'قيد المراجعة');
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'accepted':
        return const Color(0xFF22C55E);
      case 'rejected':
        return scheme.error;
      case 'canceled':
        return scheme.outline;
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'Requests to this apartment', 'طلبات هذه الشقة'),
          ),
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0,
        ),
        body: Center(
          child: Text(tr(context, 'Not signed in', 'غير مسجل دخول')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(context, 'Requests to this apartment', 'طلبات هذه الشقة'),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      backgroundColor: scheme.surface,
      body: StreamBuilder<List<RentalRequest>>(
        // ✅ مهم: استعلام مقيّد بالمالك + الشقة (عشان ما يطلع permission-denied)
        stream: _service.watchForOwnerApartment(
          ownerId: ownerUid,
          apartmentId: apartment.id,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mail_outline,
                      size: 64,
                      color: scheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        context,
                        'No requests for this apartment yet.',
                        'لا توجد طلبات على هذه الشقة بعد.',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = items[index];

              // حماية إضافية (اختياري)
              if (r.ownerId != ownerUid) {
                return const SizedBox.shrink();
              }

              final statusText = _statusText(context, r.status);
              final statusColor = _statusColor(context, r.status);

              final title = (r.tenantName.trim().isNotEmpty)
                  ? r.tenantName
                  : tr(context, 'Tenant', 'مستأجر');

              final isPending = r.status == 'pending';

              return Card(
                color: scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              
                                if ((r.tenantPhone ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    r.tenantPhone ?? '',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  '${tr(context, 'Created at', 'تاريخ الطلب')}: ${_formatDate(r.createdAt)}',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (isPending)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                // ✅ تصحيح: القبول => accepted
                                onPressed: () => _service.setStatusWithNotify(
                                  requestId: r.id,
                                  newStatus: 'accepted',
                                  actorId: ownerUid,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(tr(context, 'Approve', 'قبول')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                // ✅ تصحيح: الرفض => rejected
                                onPressed: () => _service.setStatusWithNotify(
                                  requestId: r.id,
                                  newStatus: 'rejected',
                                  actorId: ownerUid,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: scheme.error,
                                  side: BorderSide(
                                    color: scheme.errorContainer,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.close, size: 18),
                                label: Text(tr(context, 'Reject', 'رفض')),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          r.status == 'accepted'
                              ? tr(
                                  context,
                                  'You approved this request.',
                                  'لقد قبلت هذا الطلب.',
                                )
                              : (r.status == 'rejected'
                                    ? tr(
                                        context,
                                        'You rejected this request.',
                                        'لقد رفضت هذا الطلب.',
                                      )
                                    : tr(
                                        context,
                                        'This request is not pending.',
                                        'هذا الطلب ليس قيد المراجعة.',
                                      )),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  recipientId: r.tenantId,
                                  recipientName: title,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: Text(
                            tr(context, 'Chat with tenant', 'محادثة المستأجر'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
