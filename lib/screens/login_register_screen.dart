// D:\ttu_housing_app\lib\screens\login_register_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';

import 'package:ttu_housing_app/services/fcm_service.dart';


class LoginRegister extends StatefulWidget {
  final void Function(AppUser user)? onLogin;
  const LoginRegister({super.key, this.onLogin});

  @override
  State<LoginRegister> createState() => _LoginRegisterState();
}

class _LoginRegisterState extends State<LoginRegister> {
  String _mode = 'login';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.tenant;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ✅ google_sign_in v7+: استخدم instance + initialize + authenticate
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ✅ هذا هو Web Client ID (client_type: 3) من google-services.json عندك
  static const String _serverClientId =
      '40178181277-t23vjdp96gbm0nevbcv2okqukd9l0mo7.apps.googleusercontent.com';

  late final Future<void> _googleInit;

  @override
  void initState() {
    super.initState();

    // ✅ مهم جداً لحل: serverClientId must be provided on Android
    _googleInit = _googleSignIn.initialize(serverClientId: _serverClientId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _safeSnack(String en, String ar) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr(context, en, ar))));
  }

  Future<void> _handleSubmit() async {
    final settings = AppSettings.of(context);
    final isAr = settings.language == AppLanguage.ar;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _safeSnack(
        'Please fill in email and password.',
        'الرجاء إدخال البريد الإلكتروني وكلمة المرور.',
      );
      return;
    }

    if (_mode == 'register' && name.isEmpty) {
      _safeSnack('Please enter your full name.', 'الرجاء إدخال الاسم الكامل.');
      return;
    }

    if (_mode == 'register') {
      if (confirmPassword.isEmpty) {
        _safeSnack('Please confirm your password.', 'أكد كلمة المرور.');
        return;
      }
      if (password != confirmPassword) {
        _safeSnack('Passwords do not match.', 'كلمتا المرور غير متطابقتين.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      UserCredential cred;

      if (_mode == 'login') {
        cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = cred.user!.uid;
        final doc = await _firestore.collection('users').doc(uid).get();

        if (!doc.exists) {
          throw Exception(
            isAr
                ? 'لم يتم العثور على بيانات المستخدم في قاعدة البيانات.'
                : 'User profile not found in Firestore.',
          );
        }

        final data = doc.data()!;
        final appUser = AppUser.fromMap(data, id: doc.id);

        if (!mounted) return;
        await FcmService().initForUser(uid);
        widget.onLogin?.call(appUser);
      } else {
        cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = cred.user!.uid;

        final user = AppUser(
          id: uid,
          email: email,
          displayName: name.isEmpty ? null : name,
          phone: phone.isEmpty ? null : phone,
          role: _selectedRole,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(uid).set({
          ...user.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        final doc = await _firestore.collection('users').doc(uid).get();
        final data = doc.data()!;
        final appUser = AppUser.fromMap(data, id: doc.id);

        if (!mounted) return;
        await FcmService().initForUser(uid);
        widget.onLogin?.call(appUser);
      }
    } on FirebaseAuthException catch (e) {
      String msg;

      if (e.code == 'email-already-in-use') {
        msg = isAr
            ? 'هذا البريد مستخدم بالفعل.'
            : 'This email is already in use.';
      } else if (e.code == 'wrong-password') {
        msg = isAr ? 'كلمة المرور غير صحيحة.' : 'Incorrect password.';
      } else if (e.code == 'user-not-found') {
        msg = isAr
            ? 'لا يوجد مستخدم بهذا البريد.'
            : 'No user found for this email.';
      } else if (e.code == 'weak-password') {
        msg = isAr ? 'كلمة المرور ضعيفة جداً.' : 'The password is too weak.';
      } else {
        msg = isAr ? 'حدث خطأ: ${e.message}' : 'Error: ${e.message}';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'حدث خطأ غير متوقع: $e' : 'Unexpected error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final settings = AppSettings.of(context);
    final isAr = settings.language == AppLanguage.ar;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _safeSnack('Enter your email first.', 'اكتب الإيميل أولاً.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Password reset email sent. Check your inbox.',
              'تم إرسال رابط إعادة تعيين كلمة المرور. افحص الإيميل.',
            ),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      final msg = isAr ? 'خطأ: ${e.message}' : 'Error: ${e.message}';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _handleGoogleLogin() async {
    final settings = AppSettings.of(context);
    final isAr = settings.language == AppLanguage.ar;

    try {
      setState(() => _isLoading = true);

      // ✅ تأكد إن google_sign_in تهيّأ بالـ serverClientId
      await _googleInit;

      // (اختياري) حتى يفتح اختيار الحساب كل مرة
      await _googleSignIn.signOut();

      // ✅ v7+: authenticate بدل signIn
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();
      if (googleUser == null) {
        // المستخدم كنسل
        return;
      }

      // ✅ v7+: authentication لا يحتوي accessToken، ونستخدم idToken (كافي لـ Firebase غالباً)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google idToken is null');
      }

      // ✅ Firebase docs: credential بـ idToken
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);

      final firebaseUser = userCredential.user!;
      final uid = firebaseUser.uid;

      final userDoc = await _firestore.collection('users').doc(uid).get();

      AppUser appUser;

      if (userDoc.exists) {
        appUser = AppUser.fromMap(userDoc.data()!, id: uid);
      } else {
        if (!mounted) return;
        final extra = await _askGoogleExtraData();
        if (extra == null) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          return;
        }

        final role = extra.$1;
        final phone = extra.$2;

        appUser = AppUser(
          id: uid,
          email: firebaseUser.email ?? googleUser.email,
          displayName: firebaseUser.displayName ?? googleUser.displayName,
          phone: phone.isEmpty ? null : phone,
          role: role,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(uid).set({
          ...appUser.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      await FcmService().initForUser(uid);
      widget.onLogin?.call(appUser);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'فشل Google: ${e.message}' : 'Google failed: ${e.message}',
          ),
        ),
      );
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'فشل تسجيل الدخول عبر Google: ${e.code}'
                : 'Google Sign-In failed: ${e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'فشل تسجيل الدخول باستخدام Google: $e'
                : 'Google Sign-In failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<(UserRole, String)?> _askGoogleExtraData() async {
    final settings = AppSettings.of(context);
    final isAr = settings.language == AppLanguage.ar;

    UserRole role = UserRole.tenant;
    final phoneCtrl = TextEditingController();

    final result = await showDialog<(UserRole, String)?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              scrollable: true,
              title: Text(tr(ctx, 'Complete your profile', 'أكمل بياناتك')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: isAr
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Text(tr(ctx, 'Select Role', 'اختر نوع الحساب')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserRole>(
                    value: role,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: UserRole.tenant,
                        child: Text(tr(ctx, 'Tenant', 'مستأجر')),
                      ),
                      DropdownMenuItem(
                        value: UserRole.owner,
                        child: Text(tr(ctx, 'Owner', 'مالك')),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocalState(() => role = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: tr(ctx, 'Phone', 'رقم الهاتف'),
                      border: const OutlineInputBorder(),
                      hintText: isAr ? '07XXXXXXXX' : '+9627XXXXXXX',
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
                  onPressed: () =>
                      Navigator.pop(ctx, (role, phoneCtrl.text.trim())),
                  child: Text(tr(ctx, 'Continue', 'متابعة')),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final isAr = settings.language == AppLanguage.ar;
    final isLogin = _mode == 'login';

    final scheme = Theme.of(context).colorScheme;

    final titleText = isLogin
        ? tr(context, 'Welcome Back', 'مرحباً بعودتك')
        : tr(context, 'Create Account', 'إنشاء حساب جديد');

    final subtitleText = isLogin
        ? tr(context, 'Sign in to continue', 'قم بتسجيل الدخول للمتابعة')
        : tr(
            context,
            'Sign up to get started',
            'سجّل الآن للبدء باستخدام التطبيق',
          );

    final googleText = tr(
      context,
      'Continue with Google',
      'تسجيل الدخول باستخدام جوجل',
    );
    final orText = tr(context, 'or', 'أو');

    final fullNameLabel = tr(context, 'Full Name', 'الاسم الكامل');
    final phoneLabel = tr(context, 'Phone Number', 'رقم الهاتف');
    final emailLabel = tr(context, 'Email', 'البريد الإلكتروني');
    final passwordLabel = tr(context, 'Password', 'كلمة المرور');
    final selectRoleLabel = tr(context, 'Select Role', 'اختر نوع الحساب');
    final tenantLabel = tr(context, 'Tenant', 'مستأجر');
    final ownerLabel = tr(context, 'Owner', 'مالك');

    final loginButtonText = isLogin
        ? tr(context, 'Login with Email', 'تسجيل الدخول بالبريد')
        : tr(context, 'Register', 'إنشاء حساب');

    final toggleText = isLogin
        ? tr(
            context,
            "Don't have an account? Sign up",
            'ليس لديك حساب؟ قم بإنشاء حساب',
          )
        : tr(
            context,
            'Already have an account? Sign in',
            'لديك حساب بالفعل؟ قم بتسجيل الدخول',
          );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: isAr
                          ? 'وضع النهار / الليل'
                          : 'Light / Dark mode',
                      onPressed: settings.toggleTheme,
                      icon: Icon(
                        settings.isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: scheme.onSurface,
                      ),
                    ),
                    IconButton(
                      tooltip: isAr ? 'تبديل اللغة' : 'Change language',
                      onPressed: settings.toggleLanguage,
                      icon: Text(
                        isAr ? 'EN' : 'ع',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primary,
                  child: const Icon(
                    Icons.home_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: const Icon(Icons.g_mobiledata_rounded),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  label: Text(googleText),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: scheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        orText,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(child: Divider(color: scheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isLogin) ...[
                      Text(fullNameLabel),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: isAr ? 'محمد أحمد' : 'John Doe',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(phoneLabel),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: isAr ? '07XXXXXXXX' : '+9627XXXXXXX',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Text(emailLabel),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: isAr ? 'example@mail.com' : 'your@email.com',
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(passwordLabel),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '••••••••',
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? tr(
                                  context,
                                  'Show password',
                                  'إظهار كلمة المرور',
                                )
                              : tr(
                                  context,
                                  'Hide password',
                                  'إخفاء كلمة المرور',
                                ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),

                    if (isLogin)
                      Align(
                        alignment: isAr
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          child: Text(
                            tr(
                              context,
                              'Forgot password?',
                              'نسيت كلمة المرور؟',
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    if (!isLogin) ...[
                      Text(
                        tr(context, 'Confirm Password', 'تأكيد كلمة المرور'),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: '••••••••',
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? tr(
                                    context,
                                    'Show password',
                                    'إظهار كلمة المرور',
                                  )
                                : tr(
                                    context,
                                    'Hide password',
                                    'إخفاء كلمة المرور',
                                  ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(selectRoleLabel),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _RoleChip(
                            label: tenantLabel,
                            selected: _selectedRole == UserRole.tenant,
                            onTap: () =>
                                setState(() => _selectedRole = UserRole.tenant),
                          ),
                          const SizedBox(width: 8),
                          _RoleChip(
                            label: ownerLabel,
                            selected: _selectedRole == UserRole.owner,
                            onTap: () =>
                                setState(() => _selectedRole = UserRole.owner),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.mail_outline_rounded),
                      label: Text(loginButtonText),
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                () => _mode = isLogin ? 'register' : 'login',
                              ),
                        child: Text(toggleText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            color: selected ? scheme.primary.withOpacity(0.08) : scheme.surface,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
