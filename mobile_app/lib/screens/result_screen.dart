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
  bool _isSaved = false;

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
      _isSaved = false;
      _isLoading = false;
    });
  }

  String _confidenceText(PoseAnalysisResult result) {
    return '${(result.confidence * 100).toStringAsFixed(1)}%';
  }

  List<_FeedbackSignal> _feedbackSignals(PoseAnalysisResult result) {
    final coverage = result.keypointsDetected / result.keypointsTotal;
    final confidence = result.confidence;

    return [
      _FeedbackSignal(
        icon: Icons.control_camera_rounded,
        text: coverage >= 0.95
            ? 'All major landmarks were captured clearly across the detected body pose.'
            : 'Most landmarks were detected, but a cleaner frame can improve point coverage.',
      ),
      _FeedbackSignal(
        icon: Icons.accessibility_new_rounded,
        text: confidence >= 0.95
            ? 'Basic posture feedback suggests balanced shoulder and hip alignment.'
            : 'Basic posture feedback suggests re-centering the body and improving lighting.',
      ),
      _FeedbackSignal(
        icon: result.mode == CaptureMode.video
            ? Icons.timeline_rounded
            : Icons.image_search_rounded,
        text: result.mode == CaptureMode.video
            ? 'Motion tracking remained stable throughout the recorded sequence.'
            : 'The single-frame pose stayed centered for quick inspection and export.',
      ),
    ];
  }

  void _openDetails() {
    final result = _result;
    if (result == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.surfaceGradient,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.26),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Result Details',
                              style: AppTypography.h2.copyWith(fontSize: 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Expanded session metadata for the processed PoseTrack result package.',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                height: 1.24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge(
                        label: result.mode.label,
                        color: AppColors.accentSoft,
                        icon: result.mode == CaptureMode.video
                            ? Icons.videocam_rounded
                            : Icons.image_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(label: 'Session ID', value: result.sessionId),
                  _DetailRow(
                    label: 'Captured',
                    value: formatSessionTimestamp(result.capturedAt),
                  ),
                  _DetailRow(label: 'Device', value: result.deviceNode),
                  _DetailRow(label: 'Server', value: result.serverNode),
                  _DetailRow(
                    label: 'Confidence',
                    value: _confidenceText(result),
                  ),
                  _DetailRow(
                    label: 'Keypoints',
                    value:
                        '${result.keypointsDetected}/${result.keypointsTotal}',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _saveResult() {
    if (_isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This result is already saved in the demo history.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result saved successfully for the project demo history.'),
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
                    'Processed mobile capture with skeleton overlay, analytics cards, and posture feedback.',
                onBackPressed: _goHome,
                trailing: const StatusBadge(
                  label: 'Result Ready',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
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
                  aspectRatio: 0.88,
                  title: 'Processed Pose Preview',
                  subtitle:
                      'Human skeleton overlay aligned to the captured subject for fast mobile review.',
                  statusLabel: 'Processed Image',
                  footerLabel: 'Confidence Score',
                  footerValue: _confidenceText(result),
                  timerLabel: result.mode.label,
                  processed: true,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _PreviewInfoChip(
                      icon: Icons.control_camera_rounded,
                      label:
                          '${result.keypointsDetected}/${result.keypointsTotal} keypoints tracked',
                    ),
                    const _PreviewInfoChip(
                      icon: Icons.cloud_done_rounded,
                      label: 'Server overlay synced',
                    ),
                    _PreviewInfoChip(
                      icon: Icons.schedule_rounded,
                      label: formatShortDateTime(result.capturedAt),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GlassPanel(
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
                                Text(
                                  'Result Metrics',
                                  style: AppTypography.h3.copyWith(fontSize: 19),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Detected keypoints, confidence score, session ID, and capture timestamp for the final result screen.',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 14,
                                    height: 1.24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusBadge(
                            label: _isSaved ? 'Saved' : 'Live Data',
                            color: _isSaved
                                ? AppColors.success
                                : AppColors.primary,
                            icon: _isSaved
                                ? Icons.bookmark_added_rounded
                                : Icons.bolt_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useTwoColumns = constraints.maxWidth >= 340;
                          final spacing = useTwoColumns ? 12.0 : 0.0;
                          final cardWidth = useTwoColumns
                              ? (constraints.maxWidth - spacing) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _ResultMetricCard(
                                  icon: Icons.accessibility_new_rounded,
                                  label: 'Detected Keypoints',
                                  value:
                                      '${result.keypointsDetected}/${result.keypointsTotal}',
                                  caption: 'Full-body landmark count',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ResultMetricCard(
                                  icon: Icons.auto_graph_rounded,
                                  label: 'Confidence Score',
                                  value: _confidenceText(result),
                                  caption: 'Model confidence estimate',
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ResultMetricCard(
                                  icon: Icons.badge_outlined,
                                  label: 'Session ID',
                                  value: result.sessionId,
                                  caption: 'Processing reference tag',
                                  compactValue: true,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _ResultMetricCard(
                                  icon: Icons.schedule_rounded,
                                  label: 'Timestamp',
                                  value: formatShortDateTime(result.capturedAt),
                                  caption: 'Capture completion time',
                                  compactValue: true,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  highlighted: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Analysis Summary',
                                  style: AppTypography.h3.copyWith(fontSize: 19),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  result.statusMessage,
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.feedback,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._feedbackSignals(result).map(
                        (signal) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AnalysisSignalTile(signal: signal),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SystemChip(
                            icon: Icons.memory_rounded,
                            label: result.deviceNode,
                          ),
                          _SystemChip(
                            icon: Icons.dns_rounded,
                            label: result.serverNode,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'View Details',
                        onPressed: _openDetails,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: _isSaved ? 'Saved Result' : 'Save Result',
                        onPressed: _saveResult,
                        isSecondary: true,
                      ),
                    ),
                  ],
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
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _openHistory,
                    icon: const Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'History',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
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

class _ResultMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final bool compactValue;

  const _ResultMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.74)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
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
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: compactValue ? 2 : 1,
            overflow: TextOverflow.fade,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontSize: compactValue ? 18 : 24,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PreviewInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.88),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisSignalTile extends StatelessWidget {
  final _FeedbackSignal signal;

  const _AnalysisSignalTile({required this.signal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.66)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(signal.icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              signal.text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                fontSize: 14,
                height: 1.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SystemChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.68)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.accentSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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

class _FeedbackSignal {
  final IconData icon;
  final String text;

  const _FeedbackSignal({
    required this.icon,
    required this.text,
  });
}
