import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 3-screen value-prop swipe shown to first-time launchers BEFORE auth.
/// Lays out what the app is and asks for permission softly (no OS prompt yet).
class ValuePropScreen extends StatefulWidget {
  const ValuePropScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<ValuePropScreen> createState() => _ValuePropScreenState();
}

class _ValuePropScreenState extends State<ValuePropScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    (
      icon: Icons.directions_run_rounded,
      title: 'Run like a scientist.',
      body: 'GPS tracking, pace, elevation, and on-device form analysis on every run.',
    ),
    (
      icon: Icons.psychology_alt_rounded,
      title: 'AI coach in your pocket.',
      body: 'Race plans, recovery scoring, and daily insights that adapt to YOUR body.',
    ),
    (
      icon: Icons.local_fire_department_rounded,
      title: 'Show up every day.',
      body: 'Streaks, challenges, and friends keep you running — even when you don\'t feel like it.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: TextButton(
                  onPressed: widget.onContinue,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.electricLime.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Icon(p.icon,
                              color: AppTheme.electricLime, size: 80),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppTheme.electricLime
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _index == _pages.length - 1
                      ? widget.onContinue
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.electricLime,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _index == _pages.length - 1 ? 'Get started' : 'Next',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
