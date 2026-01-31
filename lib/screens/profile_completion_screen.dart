// D:\ttu_housing_app\lib\screens\profile_completion_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _phoneCtrl = TextEditingController();
  UserRole _role = UserRole.tenant;
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'Enter phone number.', 'أدخل رقم الهاتف.')),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final uid = authUser.uid;
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);

      final existing = await ref.get();

      final userMap = AppUser(
        id: uid,
        email: authUser.email ?? '',
        displayName: authUser.displayName,
        phone: phone,
        role: _role,
        createdAt: DateTime.now(),
      ).toMap();

      if (existing.exists && (existing.data()?['createdAt'] != null)) {
        userMap.remove('createdAt');
      } else {
        userMap['createdAt'] = FieldValue.serverTimestamp();
      }

      await ref.set(userMap, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'Profile saved.', 'تم حفظ البيانات.')),
        ),
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      final isAr = AppSettings.of(context).language == AppLanguage.ar;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'فشل الحفظ: $e' : 'Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAr = AppSettings.of(context).language == AppLanguage.ar;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Complete Profile', 'إكمال البيانات')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr(
              context,
              'Please complete your profile to continue.',
              'رجاءً أكمل بياناتك للمتابعة.',
            ),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          Text(tr(context, 'Select Role', 'اختر نوع الحساب')),
          const SizedBox(height: 8),
          DropdownButtonFormField<UserRole>(
            value: _role,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                value: UserRole.tenant,
                child: Text(tr(context, 'Tenant', 'مستأجر')),
              ),
              DropdownMenuItem(
                value: UserRole.owner,
                child: Text(tr(context, 'Owner', 'مالك')),
              ),
            ],
            onChanged: (v) => setState(() => _role = v ?? UserRole.tenant),
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
            onPressed: _loading ? null : _save,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(tr(context, 'Save & Continue', 'حفظ والمتابعة')),
          ),
        ],
      ),
    );
  }
}
