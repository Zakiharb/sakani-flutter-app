// D:\ttu_housing_app\lib\main.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'supabase_config.dart';

import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'package:ttu_housing_app/screens/splash_screen.dart';
import 'package:ttu_housing_app/screens/onboarding_screen.dart';
import 'screens/app_gate.dart';



/// =======================
/// Local Notifications setup
/// =======================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel ttuChannel = AndroidNotificationChannel(
  'high_importance_channel', // لازم يطابق اللي بالـ Manifest إذا حطيته
  'High Importance Notifications',
  description: 'TTU Housing notifications',
  importance: Importance.high,
);

/// =======================
/// Background handler
/// =======================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // لازم نعمل init لأن هذا ينفذ في isolate لحاله
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ملاحظة: لا تعمل UI هون
  debugPrint('BG Message: ${message.messageId}');
}

Future<void> _initLocalNotifications() async {
  // Android init
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    // لو بدك لاحقاً تفتح شاشة عند الضغط على الإشعار، بنضيف onDidReceiveNotificationResponse هنا
  );

  // إنشاء Channel للأندرويد
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(ttuChannel);
}

void _listenForegroundMessages() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    // لو الرسالة فيها notification payload، نعرضها local حتى في foreground
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            ttuChannel.id,
            ttuChannel.name,
            channelDescription: ttuChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: android.smallIcon ?? '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });
}

Future<void> _initFCM() async {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;

  // Permission (Android 13+ مهم)
  await messaging.requestPermission();

  // (اختياري) Token للاختبار — ممكن لاحقاً تخزنه بفايرستور لكل مستخدم
  final fcmToken = await messaging.getToken();
  debugPrint("FCM_TOKEN: $fcmToken");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Error handlers عندك
  FlutterError.onError = (details) {
    debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('DART ERROR: $error');
    debugPrint(stack.toString());
    return true;
  };

  // Firebase init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Init local notifications + channels
  await _initLocalNotifications();

  // Init FCM + permission + token
  await _initFCM();

  // Listen foreground messages and show local notifications
  _listenForegroundMessages();

  // Supabase init
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const TTUHousingRoot());
}

class TTUHousingRoot extends StatefulWidget {
  const TTUHousingRoot({super.key});

  @override
  State<TTUHousingRoot> createState() => _TTUHousingRootState();
}

class _TTUHousingRootState extends State<TTUHousingRoot> {
  AppLanguage _language = AppLanguage.en;
  ThemeMode _themeMode = ThemeMode.light;

  void _setLanguage(AppLanguage lang) {
    setState(() => _language = lang);
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppSettings(
      language: _language,
      themeMode: _themeMode,
      setLanguage: _setLanguage,
      toggleTheme: _toggleTheme,
      child: MaterialApp(
        title: 'TTU Housing App',
        debugShowCheckedModeBanner: false,

        // ---------- Theme ----------
        themeMode: _themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.dark,
          ).copyWith(
            surface: const Color(0xFF0B1220),
            surfaceContainerHighest: const Color(0xFF111827),
            outlineVariant: const Color(0xFF1F2937),
          ),
        ),

        // ---------- Localization ----------
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        locale: Locale(_language == AppLanguage.ar ? 'ar' : 'en'),

        builder: (context, child) {
          final isAr = _language == AppLanguage.ar;
          return Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },

        home: const AppFlowGate(),

      ),
    );
  }
}



enum AppStage { splash, onboarding, gate }

class AppFlowGate extends StatefulWidget {
  const AppFlowGate({super.key});

  @override
  State<AppFlowGate> createState() => _AppFlowGateState();
}

class _AppFlowGateState extends State<AppFlowGate> {
  AppStage _stage = AppStage.splash;

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case AppStage.splash:
        return SplashScreen(
          onComplete: () => setState(() => _stage = AppStage.onboarding),
        );

      case AppStage.onboarding:
        return Onboarding(
          onComplete: () => setState(() => _stage = AppStage.gate),
        );

      case AppStage.gate:
        return const AppGate();
    }
  }
}
