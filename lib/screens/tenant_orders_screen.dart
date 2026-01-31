// D:\ttu_housing_app\lib\screens\tenant_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttu_housing_app/services/rental_request_service.dart';
import 'package:ttu_housing_app/services/apartment_service.dart';
import 'package:ttu_housing_app/models/rental_request.dart';
import 'package:ttu_housing_app/screens/apartment_details_screen.dart';
import 'package:ttu_housing_app/screens/chat_screen.dart';
import 'package:ttu_housing_app/app_settings.dart';

class TenantOrdersScreen extends StatelessWidget {
  TenantOrdersScreen({super.key});

  final _service = RentalRequestService();
  final _aptService = ApartmentService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'My Requests', 'طلباتي'))),
        body: Center(
          child: Text(tr(context, 'Not signed in', 'غير مسجل دخول')),
        ),
      );
    }
    final tenantId = user.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: StreamBuilder<List<RentalRequest>>(
        stream: _service.watchForTenant(tenantId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? <RentalRequest>[];
          if (items.isEmpty) {
            return const Center(child: Text('No requests yet'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];
              final ownerNameShown = r.ownerName.trim().isNotEmpty
                  ? r.ownerName
                  : 'Owner';

              return Card(
                child: ListTile(
                  title: Text('${r.apartmentTitle} • ${r.status}'),
                  subtitle: Text(
                    'Owner: $ownerNameShown\nNote: ${r.note ?? '-'}',
                  ),
                  isThreeLine: true,

                  // ✅ فتح الشقة عند الضغط
                  onTap: () async {
                    final apt = await _aptService.getById(r.apartmentId);
                    if (apt == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Apartment not found')),
                        );
                      }
                      return;
                    }

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApartmentDetailsScreen(
                          apartment: apt,
                          onToggleSave: (_) {},
                          onChat: (ownerId) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  recipientId: ownerId,
                                  recipientName: ownerNameShown,
                                ),
                              ),
                            );
                          },
                          onRequest: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    context,
                                    'You already requested this apartment.',
                                    'أنت بالفعل قمت بطلب هذه الشقة.',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },

                  trailing: r.status == 'pending'
                      ? TextButton(
                          onPressed: () => _service.setStatusWithNotify(
                            requestId: r.id,
                            newStatus: 'canceled',
                            actorId: tenantId,
                          ),
                          child: Text(tr(context, 'Cancel', 'إلغاء')),
                        )
                      : TextButton(
                          onPressed: () => _service.hideForTenant(r.id),
                          child: Text(tr(context, 'Remove', 'إزالة')),
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
