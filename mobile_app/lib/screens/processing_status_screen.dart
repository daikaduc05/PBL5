import 'dart:async';

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

class ProcessingStatusScreen extends StatefulWidget {
  final CaptureSessionDraft draft;

  const ProcessingStatusScreen({
    super.key,
    required this.draft,
  });

  @override
  State<ProcessingStatusScreen> createState() => _ProcessingStatusScreenState();
}

class _ProcessingStatusScreenState extends State<ProcessingStatusScreen> {
  final MockPoseTrackingService _poseService = MockPoseTrackingService();

  late final List<ProcessingStage> _stages;
  Timer? _timer;

  double _progress = 0.0;
  bool _isFinalizing = false;
  PoseAnalysisResult? _result;

  @override
  void initState() {
    super.initState();
    _stages = _poseService.getProcessingStages(widget.draft);
    _startProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _activeStageIndex {
    if (_progress == 1.0) {
      return _stages.length - 1;
    }

    return (_progress * _stages.length)
        .floor()
        .clamp(0, _stages.length - 1);
  }

  void _startProgress() {
    _timer = Timer.periodic(const Duration(milliseconds: 650), (timer) async {
      if (!mounted || _isFinalizing) {
        timer.cancel();
        return;
      }

      final nextProgress = (_progress + 0.18).clamp(0.0, 1.0).toDouble();

      setState(() {
        _progress = nextProgress;
      });

      if (nextProgress >= 1.0) {
        timer.cancel();
        await _finalize();
      }
    });
  }

  Future<void> _finalize() async {
    setState(() {
      _isFinalizing = true;
    });

    final result = await _poseService.finalizeCapture(widget.draft);

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result;
      _isFinalizing = false;
    });
  }

  void _goBackHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _openResult() {
    final result = _result;
    if (result == null) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.results,
      arguments: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressLabel = '${(_progress * 100).round()}%';
    final activeStage = _stages[_activeStageIndex];

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'Processing Status',
                subtitle:
                    'Tracking the Raspberry Pi upload and server-side pose estimation pipeline in real time.',
                onBackPressed: _goBackHome,
                trailing: StatusBadge(
                  label: _result == null ? 'AI Running' : 'Complete',
                  color: _result == null ? AppColors.primary : AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              GlassPanel(
                highlighted: true,
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
                                'Session ${widget.draft.sessionId}',
                                style: AppTypography.h2.copyWith(fontSize: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Captured ${formatSessionTimestamp(widget.draft.capturedAt)} in ${widget.draft.mode.label.toLowerCase()} mode.',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontSize: 14,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                progressLabel,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor:
                            AppColors.background.withValues(alpha: 0.42),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.68),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.psychology_alt_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              activeStage.description,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.86,
                                ),
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      'Processing Timeline',
                      style: AppTypography.h3.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Each stage mirrors the AI workflow described in the project flow diagram.',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._stages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stage = entry.value;
                      final isDone = index < _activeStageIndex || _result != null;
                      final isActive = index == _activeStageIndex && _result == null;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _stages.length - 1 ? 0 : 14,
                        ),
                        child: _StageRow(
                          title: stage.title,
                          description: stage.description,
                          isDone: isDone,
                          isActive: isActive,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: _result == null ? 'Processing...' : 'Open Result',
                  onPressed: _result == null ? () {} : _openResult,
                  isLoading: _isFinalizing,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Back Home',
                  isSecondary: true,
                  onPressed: _goBackHome,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final String title;
  final String description;
  final bool isDone;
  final bool isActive;

  const _StageRow({
    required this.title,
    required this.description,
    required this.isDone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDone
        ? AppColors.success
        : isActive
        ? AppColors.primary
        : AppColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDone || isActive ? 0.14 : 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.36)),
            boxShadow: isDone || isActive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.14),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isDone
                ? Icons.check_rounded
                : isActive
                ? Icons.sync_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13.5,
                  height: 1.22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
