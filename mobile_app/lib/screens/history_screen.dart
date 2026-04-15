import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../navigation/app_routes.dart';
import '../services/mock_pose_tracking_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MockPoseTrackingService _poseService = MockPoseTrackingService();

  List<PoseHistorySession> _sessions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final sessions = await _poseService.getHistory();

    if (!mounted) {
      return;
    }

    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _openSession(PoseHistorySession session) {
    Navigator.of(context).pushNamed(
      AppRoutes.results,
      arguments: session.toResult(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'History',
                subtitle:
                    'Scrollable session archive for completed, processing, and failed pose estimation runs.',
                onBackPressed: _goHome,
                trailing: StatusBadge(
                  label: '${_sessions.length} sessions',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              GlassPanel(
                highlighted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Timeline',
                      style: AppTypography.h2.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review recent mobile captures and reopen any result card during the engineering demo.',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                )
              else ...[
                ..._sessions.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _HistoryCard(
                      session: session,
                      onTap: () => _openSession(session),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Back to Home',
                  onPressed: _goHome,
                  isSecondary: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PoseHistorySession session;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.session,
    required this.onTap,
  });

  Color get _accent => switch (session.state) {
    SessionState.completed => AppColors.success,
    SessionState.processing => AppColors.primary,
    SessionState.failed => AppColors.warning,
  };

  String get _statusLabel => switch (session.state) {
    SessionState.completed => 'Completed',
    SessionState.processing => 'Processing',
    SessionState.failed => 'Failed',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accent.withValues(alpha: 0.12),
                AppColors.surfaceElevated,
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _accent.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HistoryThumbnail(accent: _accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              style: AppTypography.h3.copyWith(fontSize: 17),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _accent.withValues(alpha: 0.34),
                              ),
                            ),
                            child: Text(
                              _statusLabel.toUpperCase(),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.summary,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 13.5,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _InlineStat(
                            label: 'Captured',
                            value: formatShortDateTime(session.capturedAt),
                          ),
                          _InlineStat(
                            label: 'Mode',
                            value: session.mode.label,
                          ),
                          _InlineStat(
                            label: 'Confidence',
                            value:
                                '${(session.confidence * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;

  const _InlineStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.68)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
                fontSize: 12.5,
              ),
            ),
            TextSpan(
              text: value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryThumbnail extends StatelessWidget {
  final Color accent;

  const _HistoryThumbnail({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: CustomPaint(
        painter: _HistoryThumbnailPainter(accent: accent),
      ),
    );
  }
}

class _HistoryThumbnailPainter extends CustomPainter {
  final Color accent;

  const _HistoryThumbnailPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.72)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()..color = accent;

    final head = Offset(size.width * 0.52, size.height * 0.18);
    final neck = Offset(size.width * 0.52, size.height * 0.32);
    final leftHand = Offset(size.width * 0.3, size.height * 0.48);
    final rightHand = Offset(size.width * 0.7, size.height * 0.44);
    final hip = Offset(size.width * 0.52, size.height * 0.58);
    final leftFoot = Offset(size.width * 0.4, size.height * 0.82);
    final rightFoot = Offset(size.width * 0.64, size.height * 0.8);

    canvas.drawLine(head, neck, linePaint);
    canvas.drawLine(neck, leftHand, linePaint);
    canvas.drawLine(neck, rightHand, linePaint);
    canvas.drawLine(neck, hip, linePaint);
    canvas.drawLine(hip, leftFoot, linePaint);
    canvas.drawLine(hip, rightFoot, linePaint);

    for (final point in [head, neck, leftHand, rightHand, hip, leftFoot, rightFoot]) {
      canvas.drawCircle(point, 3, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryThumbnailPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}
