import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../models/result_models.dart';
import '../navigation/app_routes.dart';
import '../services/result_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class ResultSessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const ResultSessionDetailScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<ResultSessionDetailScreen> createState() =>
      _ResultSessionDetailScreenState();
}

class _ResultSessionDetailScreenState extends State<ResultSessionDetailScreen> {
  final ResultApi _resultApi = ResultApi();

  ResultSessionDetail? _sessionDetail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSessionDetail();
  }

  Future<void> _loadSessionDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionDetail = await _resultApi.getResultSessionDetail(
        widget.sessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sessionDetail = sessionDetail;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sessionDetail = null;
        _errorMessage = extractResultApiMessage(error);
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      AppRoutes.resultSessions,
      (route) => false,
    );
  }

  void _openFrame(ResultFrameItem frame) {
    Navigator.of(context).pushNamed(
      AppRoutes.resultFrameDetail,
      arguments: ResultFrameDetailArgs(
        sessionId: widget.sessionId,
        frameId: frame.frameId,
        poseImageUrl: frame.poseImageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _errorMessage == null
        ? (_isLoading ? AppColors.primary : AppColors.success)
        : AppColors.warning;
    final statusLabel = _errorMessage == null
        ? (_isLoading ? 'Loading Frames' : 'Session Ready')
        : 'Check Backend';

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'Session Detail',
                subtitle:
                    'Read `/api/results/${widget.sessionId}` and browse the processed frames inside this session.',
                onBackPressed: _goBack,
                trailing: StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  icon: Icons.movie_filter_rounded,
                ),
              ),
              const SizedBox(height: 24),
              _SessionHero(
                sessionDetail: _sessionDetail,
                sessionId: widget.sessionId,
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const _LoadingState(message: 'Loading frame list...')
              else if (_errorMessage != null)
                _ErrorState(
                  message: _errorMessage!,
                  onRetry: _loadSessionDetail,
                )
              else if (_sessionDetail == null || _sessionDetail!.frames.isEmpty)
                _EmptyState(onRefresh: _loadSessionDetail)
              else
                Column(
                  children: _sessionDetail!.frames
                      .map(
                        (frame) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _FrameCard(
                            frame: frame,
                            onViewDetail: () => _openFrame(frame),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Refresh Session',
                      onPressed: _loadSessionDetail,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'Back',
                      onPressed: _goBack,
                      isSecondary: true,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionHero extends StatelessWidget {
  final ResultSessionDetail? sessionDetail;
  final String sessionId;

  const _SessionHero({
    required this.sessionDetail,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final capturedLabel = sessionDetail?.capturedAt == null
        ? 'Timestamp unavailable'
        : formatShortDateTime(sessionDetail!.capturedAt!);

    return GlassPanel(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sessionId,
            style: AppTypography.h2.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Each card below represents one processed frame, its pose image, and whether the backend already stored a JSON result file for it.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: capturedLabel,
              ),
              _InfoChip(
                icon: Icons.filter_frames_rounded,
                label: '${sessionDetail?.frameCount ?? 0} frames',
              ),
              _InfoChip(
                icon: Icons.image_rounded,
                label: '${sessionDetail?.poseReadyCount ?? 0} pose images',
              ),
              _InfoChip(
                icon: Icons.data_object_rounded,
                label: '${sessionDetail?.resultReadyCount ?? 0} JSON files',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  final ResultFrameItem frame;
  final VoidCallback onViewDetail;

  const _FrameCard({
    required this.frame,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = frame.hasResultJson
        ? AppColors.success
        : AppColors.warning;
    final badgeLabel = frame.hasResultJson ? 'Detail Ready' : 'Image Only';

    return GlassPanel(
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
                      'Frame ${frame.frameId}',
                      style: AppTypography.h3.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pose preview loaded from `pose_image_url` returned by the backend.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                label: badgeLabel,
                color: badgeColor,
                icon: frame.hasResultJson
                    ? Icons.check_circle_outline_rounded
                    : Icons.image_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.15,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.72),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: frame.hasPoseImage
                    ? Image.network(
                        frame.poseImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) {
                            return child;
                          }

                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const _ImagePlaceholder(
                            message:
                                'The pose image URL could not be opened from this device.',
                          );
                        },
                      )
                    : const _ImagePlaceholder(
                        message: 'No pose image URL was returned for this frame.',
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.image_rounded,
                label: frame.hasPoseImage ? 'Pose image ready' : 'No pose image',
              ),
              _InfoChip(
                icon: Icons.data_object_rounded,
                label: frame.hasResultJson ? 'JSON detail ready' : 'JSON missing',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: 'View Detail',
              onPressed: onViewDetail,
              isSecondary: !frame.hasResultJson,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String message;

  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load session detail',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Retry Session',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No frames in this session',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'The backend returned an empty `frames` array for this session.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Refresh Session',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String message;

  const _ImagePlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textMuted,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.24),
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
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
