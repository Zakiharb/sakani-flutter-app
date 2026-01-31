// D:\ttu_housing_app\lib\app_settings.dart

import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';

class AppSettings extends InheritedWidget {
  final AppLanguage language;
  final ThemeMode themeMode;
  final void Function(AppLanguage) setLanguage;
  final VoidCallback toggleTheme;

  const AppSettings({
    super.key,
    required this.language,
    required this.themeMode,
    required this.setLanguage,
    required this.toggleTheme,
    required super.child,
  });

  static AppSettings of(BuildContext context) {
    final AppSettings? result = context
        .dependOnInheritedWidgetOfExactType<AppSettings>();
    assert(result != null, 'No AppSettings found in context');
    return result!;
  }

  bool get isDark => themeMode == ThemeMode.dark;
  void toggleLanguage() {
    if (language == AppLanguage.ar) {
      setLanguage(AppLanguage.en);
    } else {
      setLanguage(AppLanguage.ar);
    }
  }

  @override
  bool updateShouldNotify(AppSettings oldWidget) {
    return language != oldWidget.language || themeMode != oldWidget.themeMode;
  }
}

// دالة ترجمة بسيطة: تعطيك النص حسب اللغة الحالية
String tr(BuildContext context, String en, String ar) {
  final settings = AppSettings.of(context);
  return settings.language == AppLanguage.ar ? ar : en;
}
