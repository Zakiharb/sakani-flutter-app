// D:\ttu_housing_app\lib\screens\owner_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttu_housing_app/services/rental_request_service.dart';
import 'package:ttu_housing_app/models/rental_request.dart';

class OwnerOrdersScreen extends StatelessWidget {
  OwnerOrdersScreen({super.key});

  final _service = RentalRequestService();

  @override
  Widget build(BuildContext context) {
    final ownerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Owner Orders')),
      body: StreamBuilder<List<RentalRequest>>(
        stream: _service.watchForOwner(ownerId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? <RentalRequest>[];
          if (items.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];

              return Card(
                child: ListTile(
                  title: Text('${r.apartmentTitle} • ${r.status}'),
                  subtitle: Text(
                    'Tenant: ${r.tenantName}\nNote: ${r.note ?? '-'}',
                  ),
                  isThreeLine: true,
                  trailing: r.status == 'pending'
                      ? Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () => _service.setStatusWithNotify(
                                requestId: r.id,
                                newStatus: 'accepted',
                                actorId: ownerId,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => _service.setStatusWithNotify(
                                requestId: r.id,
                                newStatus: 'rejected',
                                actorId: ownerId,
                              ),
                            ),
                          ],
                        )
                      : TextButton(
                          onPressed: () => _service.hideForOwner(r.id),
                          child: const Text('Remove'),
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
