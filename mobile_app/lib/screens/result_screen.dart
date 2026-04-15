import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/pose_visualization_card.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../navigation/app_routes.dart';
import '../services/mock_pose_tracking_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class ResultScreen extends StatefulWidget {
  final PoseAnalysisResult? initialResult;

  const ResultScreen({
    super.key,
    this.initialResult,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final MockPoseTrackingService _poseService = MockPoseTrackingService();

  PoseAnalysisResult? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResult();
  }

  Future<void> _loadResult() async {
    final result = widget.initialResult ?? await _poseService.getLatestResult();

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  void _openDetails() {
    final result = _result;
    if (result == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Result Details',
                style: AppTypography.h2.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 12),
              _DetailRow(label: 'Session ID', value: result.sessionId),
              _DetailRow(
                label: 'Captured',
                value: formatSessionTimestamp(result.capturedAt),
              ),
              _DetailRow(label: 'Device', value: result.deviceNode),
              _DetailRow(label: 'Server', value: result.serverNode),
              _DetailRow(
                label: 'Confidence',
                value: '${(result.confidence * 100).toStringAsFixed(1)}%',
              ),
              _DetailRow(
                label: 'Keypoints',
                value: '${result.keypointsDetected}/${result.keypointsTotal}',
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveResult() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result marked as saved for the project demo history.'),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _openHistory() {
    Navigator.of(context).pushNamed(AppRoutes.history);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'Pose Result',
                subtitle:
                    'Processed mobile capture output with skeleton overlay, confidence metrics, and summary feedback.',
                onBackPressed: _goHome,
                trailing: const StatusBadge(
                  label: 'Inference Ready',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading || result == null)
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
                PoseVisualizationCard(
                  aspectRatio: 3 / 4,
                  title: 'Processed Pose Frame',
                  subtitle:
                      'Server overlay generated with crisp landmarks and aligned skeleton lines.',
                  statusLabel: 'Inference Complete',
                  footerLabel: 'Confidence',
                  footerValue:
                      '${(result.confidence * 100).toStringAsFixed(1)}%',
                  timerLabel: result.durationSeconds == 0
                      ? 'Image'
                      : '${result.durationSeconds}s',
                  processed: true,
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  highlighted: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: AppTypography.h2.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.statusMessage,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        result.feedback,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            label: 'Keypoints',
                            value:
                                '${result.keypointsDetected}/${result.keypointsTotal}',
                            icon: Icons.control_camera_rounded,
                          ),
                          _MetricCard(
                            label: 'Session ID',
                            value: result.sessionId,
                            icon: Icons.badge_outlined,
                          ),
                          _MetricCard(
                            label: 'Timestamp',
                            value: formatShortDateTime(result.capturedAt),
                            icon: Icons.schedule_rounded,
                          ),
                          _MetricCard(
                            label: 'Mode',
                            value: result.mode.label,
                            icon: Icons.camera_alt_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analysis Summary',
                        style: AppTypography.h3.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.analysisNote,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(label: 'Device Node', value: result.deviceNode),
                      _DetailRow(label: 'Server Node', value: result.serverNode),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'View Details',
                    onPressed: _openDetails,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Save Result',
                    onPressed: _saveResult,
                    isSecondary: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'History',
                    onPressed: _openHistory,
                    isSecondary: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Back to Home',
                    onPressed: _goHome,
                    isSecondary: true,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
