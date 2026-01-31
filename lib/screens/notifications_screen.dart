// D:\ttu_housing_app\lib\screens\notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttu_housing_app/services/notification_service.dart';
import 'package:ttu_housing_app/services/apartment_service.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/models/app_notification.dart';
import 'package:ttu_housing_app/screens/apartment_details_screen.dart';
import 'package:ttu_housing_app/screens/chat_screen.dart';
import 'package:ttu_housing_app/screens/admin_complaints_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  final _aptService = ApartmentService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _service.markAllReadForUser(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Notifications', 'الإشعارات'))),
        body: Center(
          child: Text(tr(context, 'Please login first.', 'سجّل دخول أولاً.')),
        ),
      );
    }

    final userId = user.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Notifications', 'الإشعارات')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: tr(context, 'Clear all', 'حذف الكل'),
            onPressed: () async {
              final ok =
                  await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        tr(
                          ctx,
                          'Clear all notifications?',
                          'حذف كل الإشعارات؟',
                        ),
                      ),
                      content: Text(
                        tr(
                          ctx,
                          'This will delete all your notifications.',
                          'سيتم حذف جميع إشعاراتك.',
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

              if (!ok) return;

              await _service.clearAllForUser(userId);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(context, 'Cleared.', 'تم الحذف.'))),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<List<AppNotification>>(
        stream: _service.watchForUser(userId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? <AppNotification>[];
          if (items.isEmpty) {
            return Center(
              child: Text(tr(context, 'No notifications', 'لا توجد إشعارات')),
            );
          }

          final isAr = AppSettings.of(context).language == AppLanguage.ar;

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];

              final title = isAr ? n.titleAr : n.titleEn;
              final body = isAr ? n.bodyAr : n.bodyEn;

              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Theme.of(context).colorScheme.error,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            tr(ctx, 'Delete notification?', 'حذف الإشعار؟'),
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
                },
                onDismissed: (_) async {
                  await _service.deleteOne(n.id);
                },
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(body),
                  trailing: (n.read == true)
                      ? null
                      : const Icon(Icons.circle, size: 10),
                  onTap: () async {
                    await _service.markRead(n.id);

                    final data = n.data;
                    final type = n.type;
                    // 1) إشعار شكوى جديدة للأدمن
                    if (type == 'complaint_new' ||
                        type == 'complaint_new_admin') {
                      if (!mounted) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminComplaintsScreen(),
                        ),
                      );
                      return;
                    }

                    // 2) إشعار تحديث حالة شكوى للمستأجر
                    if (type == 'complaint_status') {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(title),
                          content: Text(body),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(tr(context, 'OK', 'حسناً')),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    // 3) إشعار متعلق بشقة (الافتراضي)
                    final aptId = (data['apartmentId'] ?? '').toString().trim();
                    if (aptId.isEmpty) return;

                    final apt = await _aptService.getById(aptId);
                    if (!mounted) return;

                    if (apt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr(
                              context,
                              'Apartment not found',
                              'الشقة غير موجودة',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

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
                                  recipientName: apt.ownerName,
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
                                    'Open Home to request this apartment.',
                                    'ارجع للرئيسية لإرسال طلب الاستئجار.',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
