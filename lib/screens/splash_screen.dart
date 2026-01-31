// D:\ttu_housing_app\lib\screens\splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ttu_housing_app/app_settings.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2500), () {
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: _SplashContent()),
    );
  }
}

class _SplashContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'images/sakani_logo.png',
          width: 240,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 18),
        Text(
          tr(context, 'Sakani', 'سكني'),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            context,
            'Find your home near campus',
            'اعثر على سكنك بالقرب من الجامعة',
          ),
          style: const TextStyle(color: Colors.black54, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
