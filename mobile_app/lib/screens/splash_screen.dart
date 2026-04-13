import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../navigation/app_routes.dart';
import '../components/app_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _scanController;
  late final Animation<double> _progressAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _scanAnimation;
  late final Animation<double> _scanPulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animations for progress bar and glow
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _scanPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.75,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_scanController);

    _controller.forward();
    _scanController.repeat();

    // Optional: Keep the loading animation for visual effect,
    // but do not navigate automatically. Let the user press the Start button.
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle Grid Background
          Positioned.fill(child: CustomPaint(painter: const GridPainter())),

          // Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Soft Tech Glow Behind Logo
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(30),
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(
                              alpha: 0.2 * _glowAnimation.value,
                            ),
                            Colors.transparent,
                          ],
                          radius: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: 0.3 * _glowAnimation.value,
                            ),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.accessibility_new_rounded,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App Title
                RichText(
                  text: TextSpan(
                    style: AppTypography.h1.copyWith(
                      fontSize: 36,
                      letterSpacing: 2,
                    ),
                    children: const [
                      TextSpan(
                        text: 'POSE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'TRACK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'PRECISION AI MOTION ANALYSIS',
                  style: AppTypography.bodyMedium.copyWith(
                    letterSpacing: 2.5,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return SizedBox.expand(
                    child: CustomPaint(
                      painter: ScanOverlayPainter(
                        scanProgress: _scanAnimation.value,
                        intensity: _scanPulseAnimation.value,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Loading Bar
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SYSTEM READY',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Text(
                          '${(_progressAnimation.value * 100).toInt()}%',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 2,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Only show Start Button after loading reaches 100% (or always show it but make it look nice)
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return AnimatedOpacity(
                      opacity: _progressAnimation.value == 1.0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: _progressAnimation.value == 1.0
                          ? AppButton(
                              text: 'Start',
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed(AppRoutes.home);
                              },
                            )
                          : const SizedBox(
                              height: 56,
                            ), // Placeholder height so layout doesn't jump
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the subtle grid background
class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const double step = 30.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ScanOverlayPainter extends CustomPainter {
  const ScanOverlayPainter({
    required this.scanProgress,
    required this.intensity,
  });

  final double scanProgress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final bandHeight = size.height * 0.24;
    final scanY = lerpDouble(
      -bandHeight,
      size.height + bandHeight,
      scanProgress,
    )!;
    final bandRect = Rect.fromLTWH(
      0,
      scanY - (bandHeight / 2),
      size.width,
      bandHeight,
    );

    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.05 * intensity),
          AppColors.primary.withValues(alpha: 0.14 * intensity),
          AppColors.primary.withValues(alpha: 0.28 * intensity),
          AppColors.primary.withValues(alpha: 0.1 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.18, 0.38, 0.5, 0.72, 1.0],
      ).createShader(bandRect);

    canvas.drawRect(bandRect, bandPaint);

    final lineRect = Rect.fromLTWH(0, scanY - 1.5, size.width, 3);
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.95 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(lineRect);

    canvas.drawRect(lineRect, linePaint);

    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.26 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    canvas.drawRect(Rect.fromLTWH(0, scanY - 10, size.width, 20), glowPaint);

    for (
      double offset = -bandHeight * 0.32;
      offset <= bandHeight * 0.32;
      offset += bandHeight * 0.11
    ) {
      final distance = (offset.abs() / (bandHeight * 0.32)).clamp(0.0, 1.0);
      final alpha = (1 - distance) * 0.1 * intensity;
      final streakPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: alpha)
        ..strokeWidth = 1;

      canvas.drawLine(
        Offset(24, scanY + offset),
        Offset(size.width - 24, scanY + offset),
        streakPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress ||
        oldDelegate.intensity != intensity;
  }
}
