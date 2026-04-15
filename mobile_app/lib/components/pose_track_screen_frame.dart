import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PoseTrackScreenFrame extends StatelessWidget {
  final Widget Function(BuildContext context, double minHeight) builder;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const PoseTrackScreenFrame({
    super.key,
    required this.builder,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
    this.maxWidth = 430,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: LayoutBuilder(
        builder: (context, viewportConstraints) {
          final minHeight = viewportConstraints.maxHeight > 40
              ? viewportConstraints.maxHeight - 40
              : 0.0;

          return Stack(
            children: [
              const Positioned(
                top: -110,
                right: -80,
                child: _GlowOrb(size: 240, color: AppColors.primary),
              ),
              const Positioned(
                left: -70,
                bottom: 140,
                child: _GlowOrb(size: 190, color: AppColors.accent),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: const _TechGridPainter()),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight),
                      child: builder(context, minHeight),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _TechGridPainter extends CustomPainter {
  const _TechGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const step = 42.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
