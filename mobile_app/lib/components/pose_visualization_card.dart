import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class PoseVisualizationCard extends StatelessWidget {
  final double aspectRatio;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String footerLabel;
  final String footerValue;
  final String? timerLabel;
  final Widget? previewContent;
  final Color accent;
  final bool isRecording;
  final bool processed;

  const PoseVisualizationCard({
    super.key,
    required this.aspectRatio,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.footerLabel,
    required this.footerValue,
    this.timerLabel,
    this.previewContent,
    this.accent = AppColors.primary,
    this.isRecording = false,
    this.processed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.12),
              AppColors.backgroundSecondary,
              AppColors.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.1),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              if (previewContent != null) Positioned.fill(child: previewContent!),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                        accent.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
              if (previewContent == null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PoseVisualizationPainter(
                      accent: accent,
                      isRecording: isRecording,
                      processed: processed,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.06),
                          AppColors.background.withValues(alpha: 0.38),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: _PreviewChip(
                  icon: processed
                      ? Icons.auto_graph_rounded
                      : Icons.videocam_rounded,
                  label: statusLabel,
                  color: accent,
                ),
              ),
              if (timerLabel != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _PreviewChip(
                    icon: isRecording
                        ? Icons.fiber_manual_record_rounded
                        : Icons.timer_outlined,
                    label: timerLabel!,
                    color: isRecording ? AppColors.error : AppColors.accentSoft,
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.26),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.08),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.h3.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 13.5,
                                height: 1.22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              footerLabel,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              footerValue,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseVisualizationPainter extends CustomPainter {
  final Color accent;
  final bool isRecording;
  final bool processed;

  const _PoseVisualizationPainter({
    required this.accent,
    required this.isRecording,
    required this.processed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (double x = 24; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 24; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final framePaint = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final guideRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.08,
        size.width * 0.72,
        size.height * 0.66,
      ),
      const Radius.circular(26),
    );
    canvas.drawRRect(guideRect, framePaint);

    final linePaint = Paint()
      ..color = accent.withValues(alpha: processed ? 0.82 : 0.68)
      ..strokeWidth = processed ? 2.8 : 2.4
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: processed ? 0.16 : 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final nodePaint = Paint()..color = accent;

    final head = Offset(size.width * 0.5, size.height * 0.2);
    final neck = Offset(size.width * 0.5, size.height * 0.3);
    final leftShoulder = Offset(size.width * 0.38, size.height * 0.34);
    final rightShoulder = Offset(size.width * 0.62, size.height * 0.34);
    final leftElbow = Offset(size.width * 0.3, size.height * 0.47);
    final rightElbow = Offset(size.width * 0.7, size.height * 0.44);
    final leftHand = Offset(size.width * 0.28, size.height * 0.63);
    final rightHand = Offset(size.width * 0.72, size.height * 0.62);
    final hip = Offset(size.width * 0.5, size.height * 0.51);
    final leftKnee = Offset(size.width * 0.42, size.height * 0.69);
    final rightKnee = Offset(size.width * 0.61, size.height * 0.69);
    final leftFoot = Offset(size.width * 0.39, size.height * 0.85);
    final rightFoot = Offset(size.width * 0.64, size.height * 0.84);

    final points = [
      head,
      neck,
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
      leftHand,
      rightHand,
      hip,
      leftKnee,
      rightKnee,
      leftFoot,
      rightFoot,
    ];

    for (final point in [head, neck, hip]) {
      canvas.drawCircle(point, processed ? 15 : 12, glowPaint);
    }

    void drawSegment(Offset a, Offset b) {
      canvas.drawLine(a, b, linePaint);
    }

    drawSegment(head, neck);
    drawSegment(neck, leftShoulder);
    drawSegment(neck, rightShoulder);
    drawSegment(leftShoulder, leftElbow);
    drawSegment(rightShoulder, rightElbow);
    drawSegment(leftElbow, leftHand);
    drawSegment(rightElbow, rightHand);
    drawSegment(neck, hip);
    drawSegment(hip, leftKnee);
    drawSegment(hip, rightKnee);
    drawSegment(leftKnee, leftFoot);
    drawSegment(rightKnee, rightFoot);

    for (final point in points) {
      canvas.drawCircle(point, processed ? 3.8 : 3.2, nodePaint);
    }

    if (isRecording) {
      final pulsePaint = Paint()
        ..color = AppColors.error.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.18),
        28,
        pulsePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PoseVisualizationPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.processed != processed;
  }
}
