// D:\ttu_housing_app\lib\screens\my_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(authUser.uid);
    final snap = await ref.get();

    if (snap.exists && snap.data() != null) {
      final u = AppUser.fromMap(snap.data()!, id: snap.id);
      _user = u;
      _nameCtrl.text = (u.displayName ?? authUser.displayName ?? '').trim();
      _phoneCtrl.text = (u.phone ?? '').trim();
    } else {
      _user = AppUser(
        id: authUser.uid,
        email: authUser.email ?? '',
        displayName: authUser.displayName,
        phone: null,
        role: UserRole.tenant,
        createdAt: DateTime.now(),
      );
      _nameCtrl.text = (authUser.displayName ?? '').trim();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Enter phone number.', 'أدخل رقم الهاتف.'))),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(authUser.uid);

      await ref.set({
        'displayName': name.isEmpty ? null : name,
        'phone': phone,
      }, SetOptions(merge: true));

      if (name.isNotEmpty) {
        await authUser.updateDisplayName(name);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Profile updated.', 'تم تحديث الملف.'))),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAr = AppSettings.of(context).language == AppLanguage.ar;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'My Profile', 'ملفي الشخصي'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(context, 'Account', 'الحساب'),
                            style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                        const SizedBox(height: 8),
                        Text('${tr(context, 'Email', 'البريد')}: ${_user?.email ?? ''}'),
                        const SizedBox(height: 6),
                        Text('${tr(context, 'Role', 'نوع الحساب')}: ${_user?.role.asString ?? 'tenant'}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(tr(context, 'Full name', 'الاسم الكامل')),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: tr(context, 'Your name', 'اسمك'),
                  ),
                ),

                const SizedBox(height: 12),
                Text(tr(context, 'Phone', 'رقم الهاتف')),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: isAr ? '07XXXXXXXX' : '+9627XXXXXXX',
                  ),
                ),

                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(tr(context, 'Save', 'حفظ')),
                ),
              ],
            ),
    );
  }
}
