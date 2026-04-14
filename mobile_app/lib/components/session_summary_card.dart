import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SessionSummaryCard extends StatelessWidget {
  final String sessionId;
  final String title;
  final String summary;
  final String confidence;
  final String keypoints;
  final String duration;
  final String timestamp;

  const SessionSummaryCard({
    super.key,
    required this.sessionId,
    required this.title,
    required this.summary,
    required this.confidence,
    required this.keypoints,
    required this.duration,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Text(
                        'LATEST SESSION',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: AppTypography.h3.copyWith(fontSize: 20)),
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Session ID',
                      value: sessionId,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      label: 'Captured',
                      value: timestamp,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const _PosePreviewCard(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SessionMetric(label: 'Confidence', value: confidence),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SessionMetric(label: 'Keypoints', value: keypoints),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SessionMetric(label: 'Duration', value: duration),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accentSoft),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SessionMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosePreviewCard extends StatelessWidget {
  const _PosePreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 132,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: CustomPaint(painter: _PosePreviewPainter()),
    );
  }
}

class _PosePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.65)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()..color = AppColors.primary;
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final head = Offset(size.width * 0.5, size.height * 0.18);
    final shoulder = Offset(size.width * 0.5, size.height * 0.34);
    final leftElbow = Offset(size.width * 0.34, size.height * 0.5);
    final rightElbow = Offset(size.width * 0.66, size.height * 0.47);
    final leftHand = Offset(size.width * 0.28, size.height * 0.7);
    final rightHand = Offset(size.width * 0.72, size.height * 0.66);
    final hip = Offset(size.width * 0.5, size.height * 0.58);
    final leftKnee = Offset(size.width * 0.4, size.height * 0.82);
    final rightKnee = Offset(size.width * 0.62, size.height * 0.8);

    canvas.drawCircle(head, 10, glowPaint);
    canvas.drawCircle(shoulder, 8, glowPaint);
    canvas.drawCircle(hip, 8, glowPaint);

    canvas.drawLine(head, shoulder, linePaint);
    canvas.drawLine(shoulder, leftElbow, linePaint);
    canvas.drawLine(shoulder, rightElbow, linePaint);
    canvas.drawLine(leftElbow, leftHand, linePaint);
    canvas.drawLine(rightElbow, rightHand, linePaint);
    canvas.drawLine(shoulder, hip, linePaint);
    canvas.drawLine(hip, leftKnee, linePaint);
    canvas.drawLine(hip, rightKnee, linePaint);

    for (final point in [
      head,
      shoulder,
      leftElbow,
      rightElbow,
      leftHand,
      rightHand,
      hip,
      leftKnee,
      rightKnee,
    ]) {
      canvas.drawCircle(point, 3.2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
