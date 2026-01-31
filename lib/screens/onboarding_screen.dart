// D:\ttu_housing_app\lib\screens\onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:ttu_housing_app/app_settings.dart';

class Onboarding extends StatefulWidget {
  final VoidCallback onComplete;

  const Onboarding({super.key, required this.onComplete});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _SlideData {
  final IconData icon;
  final String titleEn;
  final String titleAr;
  final String descEn;
  final String descAr;

  const _SlideData({
    required this.icon,
    required this.titleEn,
    required this.titleAr,
    required this.descEn,
    required this.descAr,
  });
}

class _OnboardingState extends State<Onboarding> {
  int _currentSlide = 0;

  final _slides = const [
    _SlideData(
      icon: Icons.search_rounded,
      titleEn: 'Find apartments near TTU',
      titleAr: 'اعثر على شقق قرب الجامعة',
      descEn:
          'Browse verified listings close to campus with details and photos.',
      descAr: 'تصفح الشقق الموثوقة القريبة من الجامعة مع صور وتفاصيل كاملة.',
    ),
    _SlideData(
      icon: Icons.chat_bubble_outline_rounded,
      titleEn: 'Chat directly with landlords',
      titleAr: 'تحدث مباشرة مع المالكين',
      descEn: 'Connect instantly with owners and get answers in real-time.',
      descAr: 'تواصل فوراً مع المالكين واحصل على إجابات بسرعة.',
    ),
    _SlideData(
      icon: Icons.verified_rounded,
      titleEn: 'Verified listings & full details',
      titleAr: 'شقق موثوقة وتفاصيل كاملة',
      descEn: 'All properties are reviewed and include complete information.',
      descAr: 'جميع الشقق تتم مراجعتها وتحتوي على معلومات كاملة.',
    ),
  ];

  void _handleNext() {
    if (_currentSlide < _slides.length - 1) {
      setState(() => _currentSlide++);
    } else {
      widget.onComplete();
    }
  }

  void _handleSkip() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slide = _slides[_currentSlide];

    final title = tr(context, slide.titleEn, slide.titleAr);
    final desc = tr(context, slide.descEn, slide.descAr);

    final skipText = tr(context, 'Skip', 'تخطي');
    final nextText = tr(context, 'Next', 'التالي');
    final getStartedText = tr(context, 'Get Started', 'ابدأ الآن');

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(slide.icon, size: 64, color: scheme.primary),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    desc,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    final isActive = index == _currentSlide;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: isActive ? 24 : 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_currentSlide < _slides.length - 1)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleSkip,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: scheme.outlineVariant),
                            foregroundColor: scheme.onSurfaceVariant,
                          ),
                          child: Text(skipText),
                        ),
                      ),
                    if (_currentSlide < _slides.length - 1)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _currentSlide < _slides.length - 1
                              ? nextText
                              : getStartedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
