// D:\ttu_housing_app\lib\screens\notification_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:ttu_housing_app/app_settings.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;

  bool rentalUpdates = true;
  bool apartmentUpdates = true;
  bool complaintUpdates = true;
  bool messageUpdates = true;

  Future<void> _load() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('notification_prefs')
        .doc(u.uid)
        .get();

    final data = doc.data() ?? {};
    rentalUpdates = (data['rentalUpdates'] as bool?) ?? true;
    apartmentUpdates = (data['apartmentUpdates'] as bool?) ?? true;
    complaintUpdates = (data['complaintUpdates'] as bool?) ?? true;

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Timer? _saveDebounce;

  void _scheduleAutoSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      _save(); // ينحفظ بعد 0.4 ثانية من آخر تغيير
    });
  }

  Future<void> _save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    await FirebaseFirestore.instance
        .collection('notification_prefs')
        .doc(u.uid)
        .set({
          'rentalUpdates': rentalUpdates,
          'apartmentUpdates': apartmentUpdates,
          'complaintUpdates': complaintUpdates,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr(context, 'Saved.', 'تم الحفظ.'))));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Notification Settings', 'إعدادات الإشعارات')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  value: rentalUpdates,
                  onChanged: (v) {
                    setState(() => rentalUpdates = v);
                    _scheduleAutoSave();
                  },
                  title: Text(
                    tr(
                      context,
                      'Rental request updates',
                      'تحديثات طلبات الاستئجار',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: apartmentUpdates,
                  onChanged: (v) {
                    setState(() => apartmentUpdates = v);
                    _scheduleAutoSave();
                  },
                  title: Text(
                    tr(context, 'Apartment updates', 'تحديثات الشقق'),
                  ),
                ),
                SwitchListTile(
                  value: complaintUpdates,
                  onChanged: (v) {
                    setState(() => complaintUpdates = v);
                    _scheduleAutoSave();
                  },
                  title: Text(
                    tr(context, 'Complaints updates', 'تحديثات الشكاوى'),
                  ),
                ), 
              ],
            ),
    );
  }
}
