// D:\ttu_housing_app\lib\screens\app_gate.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ttu_housing_app/models/models.dart';
import 'login_register_screen.dart';
import 'home_screen.dart';
import 'profile_completion_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:ttu_housing_app/services/fcm_service.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _supabaseReady = false;
  String? _tokenStoredForUid;

  @override
  void initState() {
    super.initState();
    _initSupabaseSession();
  }

  Future<void> _initSupabaseSession() async {
    debugPrint('Supabase session init: START');

    try {
      final supabase = Supabase.instance.client;

      debugPrint('Before: session = ${supabase.auth.currentSession != null}');

      if (supabase.auth.currentSession == null) {
        await supabase.auth.signInAnonymously();
        debugPrint('SignInAnonymously: DONE');
      }

      debugPrint('Supabase user: ${supabase.auth.currentUser?.id}');
    } catch (e) {
      debugPrint('Supabase anonymous sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _supabaseReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ممكن نخليها تكمّل حتى لو supabase مش جاهز، بس الأفضل ننتظر ثانية
    if (!_supabaseReady) return const _GateLoading();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _GateLoading();
        }

        final firebaseUser = authSnap.data;

        // 1) مش مسجل دخول
        if (firebaseUser == null) {
          return const LoginRegister();
        }

        // 2) مسجل دخول: راقب وثيقة user
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _GateLoading();
            }

            final doc = userSnap.data;

            if (doc == null || !doc.exists || doc.data() == null) {
              return const ProfileCompletionScreen();
            }

            final appUser = AppUser.fromMap(doc.data()!, id: doc.id);

            final phone = appUser.phone?.trim();
            if (phone == null || phone.isEmpty) {
              return const ProfileCompletionScreen();
            }

            if (_tokenStoredForUid != appUser.id) {
              _tokenStoredForUid = appUser.id;
              unawaited(FcmService().initForUser(appUser.id));
            }

            Future<void> logout() async {
              await FirebaseAuth.instance.signOut();
            }

            final initial = appUser.role == UserRole.owner
                ? 'owner-dashboard'
                : appUser.role == UserRole.admin
                ? 'admin-panel'
                : null;
            // الآن ندخل الجميع على MainHomePage (حتى ما نكسر Owner/Admin اللي بعتمدوا على mock/state)
            return MainHomePage(
              currentUser: appUser,
              onLogout: logout,
              initialNavigate: initial,
            );
          },
        );
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
