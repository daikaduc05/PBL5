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

class ResultScreen extends StatefulWidget {
  final ResultScreenArgs? sessionArgs;

  const ResultScreen({
    super.key,
    this.sessionArgs,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ResultApi _resultApi = ResultApi();

  ResultSessionDetail? _session;
  ResultFrameItem? _selectedFrame;
  FrameResultDetail? _frameDetail;

  bool _isLoading = true;
  bool _isLoadingFrameDetail = false;
  String? _errorMessage;
  String? _frameDetailMessage;

  @override
  void initState() {
    super.initState();
    _loadScreen();
  }

  Future<void> _loadScreen() async => _loadBackendSession();

  Future<void> _loadBackendSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _frameDetail = null;
      _frameDetailMessage = null;
    });

    try {
      final session = widget.sessionArgs != null
          ? await _resultApi.getResultSessionDetail(widget.sessionArgs!.sessionId)
          : await _loadLatestSession();

      final selectedFrame = _pickInitialFrame(session);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _selectedFrame = selectedFrame;
        _isLoading = false;
      });

      await _loadSelectedFrameDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _selectedFrame = null;
        _frameDetail = null;
        _errorMessage = extractResultApiMessage(error);
        _isLoading = false;
      });
    }
  }

  Future<ResultSessionDetail> _loadLatestSession() async {
    final sessions = await _resultApi.getResultSessions();
    if (sessions.isEmpty) {
      throw const ResultApiException(
        'No processed sessions are available on the backend yet.',
      );
    }
    return _resultApi.getResultSessionDetail(sessions.first.sessionId);
  }

  ResultFrameItem? _pickInitialFrame(ResultSessionDetail session) {
    if (session.frames.isEmpty) {
      return null;
    }

    final requestedFrameId = widget.sessionArgs?.initialFrameId;
    if (requestedFrameId != null) {
      for (final frame in session.frames) {
        if (frame.frameId == requestedFrameId) {
          return frame;
        }
      }
    }

    for (final frame in session.frames) {
      if (frame.hasResultJson) {
        return frame;
      }
    }

    return session.frames.first;
  }

  Future<void> _selectFrame(ResultFrameItem frame) async {
    setState(() {
      _selectedFrame = frame;
      _frameDetail = null;
      _frameDetailMessage = null;
    });

    await _loadSelectedFrameDetail();
  }

  Future<void> _loadSelectedFrameDetail() async {
    final session = _session;
    final frame = _selectedFrame;

    if (session == null || frame == null) {
      return;
    }

    if (!frame.hasResultJson) {
      setState(() {
        _frameDetail = null;
        _frameDetailMessage =
            'JSON metadata is not available for this frame yet. The pose image is ready, but the worker has not produced frame_<id>_result.json.';
      });
      return;
    }

    setState(() {
      _isLoadingFrameDetail = true;
      _frameDetailMessage = null;
    });

    try {
      final detail = await _resultApi.getFrameResult(
        session.sessionId,
        frame.frameId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _frameDetail = detail;
        _isLoadingFrameDetail = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _frameDetail = null;
        _frameDetailMessage = extractResultApiMessage(error);
        _isLoadingFrameDetail = false;
      });
    }
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
    final session = _session;
    final selectedFrame = _selectedFrame;
    final statusColor = _errorMessage == null
        ? AppColors.success
        : AppColors.warning;
    final statusLabel = _errorMessage == null ? 'Backend Result' : 'Need Retry';

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
                    'Select a frame from the backend session, open the pose image, and inspect the stored JSON metadata.',
                onBackPressed: _goHome,
                trailing: StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  icon: Icons.analytics_rounded,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 90),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                _BackendErrorState(
                  message: _errorMessage!,
                  onRetry: _loadBackendSession,
                  onOpenHistory: _openHistory,
                )
              else if (session == null || selectedFrame == null)
                _NoResultState(
                  onRefresh: _loadBackendSession,
                  onOpenHistory: _openHistory,
                )
              else ...[
                _BackendResultHero(
                  session: session,
                  selectedFrame: selectedFrame,
                ),
                const SizedBox(height: 18),
                _PoseImagePanel(frame: selectedFrame),
                const SizedBox(height: 18),
                _FrameChooserPanel(
                  session: session,
                  selectedFrame: selectedFrame,
                  onSelectFrame: _selectFrame,
                ),
                const SizedBox(height: 18),
                _FrameDetailPanel(
                  isLoading: _isLoadingFrameDetail,
                  detail: _frameDetail,
                  message: _frameDetailMessage,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Refresh Session',
                        onPressed: () {
                          _loadBackendSession();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'Open History',
                        onPressed: _openHistory,
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
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BackendResultHero extends StatelessWidget {
  final ResultSessionDetail session;
  final ResultFrameItem selectedFrame;

  const _BackendResultHero({
    required this.session,
    required this.selectedFrame,
  });

  @override
  Widget build(BuildContext context) {
    final capturedLabel = session.capturedAt == null
        ? 'Timestamp unavailable'
        : formatShortDateTime(session.capturedAt!);

    return GlassPanel(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.sessionId,
            style: AppTypography.h2.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'This screen is driven by `/api/results/{session_id}` and `/api/results/{session_id}/{frame_id}`. Select a frame below to refresh the image and metadata.',
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
              _DetailChip(
                icon: Icons.schedule_rounded,
                label: capturedLabel,
              ),
              _DetailChip(
                icon: Icons.filter_frames_rounded,
                label: '${session.frameCount} frames',
              ),
              _DetailChip(
                icon: Icons.data_object_rounded,
                label: '${session.resultReadyCount} JSON ready',
              ),
              _DetailChip(
                icon: Icons.flag_rounded,
                label: 'Frame ${selectedFrame.frameId}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoseImagePanel extends StatelessWidget {
  final ResultFrameItem frame;

  const _PoseImagePanel({required this.frame});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pose Image',
                  style: AppTypography.h3.copyWith(fontSize: 20),
                ),
              ),
              StatusBadge(
                label: frame.hasPoseImage ? 'Image Ready' : 'No Image',
                color: frame.hasPoseImage
                    ? AppColors.success
                    : AppColors.warning,
                icon: frame.hasPoseImage
                    ? Icons.image_rounded
                    : Icons.image_not_supported_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 0.82,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
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
                                'The app could not open the pose image URL. Confirm `/static/results/...` is reachable from the phone.',
                          );
                        },
                      )
                    : const _ImagePlaceholder(
                        message:
                            'No pose image URL was returned for this frame.',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameChooserPanel extends StatelessWidget {
  final ResultSessionDetail session;
  final ResultFrameItem selectedFrame;
  final ValueChanged<ResultFrameItem> onSelectFrame;

  const _FrameChooserPanel({
    required this.session,
    required this.selectedFrame,
    required this.onSelectFrame,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frame Browser',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a frame to swap the pose image and request its JSON detail endpoint when available.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.26,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: session.frames.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final frame = session.frames[index];
                final isSelected = frame.frameId == selectedFrame.frameId;
                final accent = frame.hasResultJson
                    ? AppColors.success
                    : AppColors.primary;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelectFrame(frame),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withValues(alpha: 0.18)
                            : AppColors.background.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? accent.withValues(alpha: 0.38)
                              : AppColors.border.withValues(alpha: 0.72),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Frame ${frame.frameId}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            frame.hasResultJson ? 'JSON ready' : 'Image only',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameDetailPanel extends StatelessWidget {
  final bool isLoading;
  final FrameResultDetail? detail;
  final String? message;

  const _FrameDetailPanel({
    required this.isLoading,
    required this.detail,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final readyDetail = detail;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frame Metadata',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'This panel reads the JSON produced by the worker for the selected frame.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.26,
            ),
          ),
          const SizedBox(height: 14),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            )
          else if (readyDetail == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.72),
                ),
              ),
              child: Text(
                message ?? 'No JSON detail is available for the selected frame.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.28,
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailChip(
                  icon: Icons.flag_rounded,
                  label: 'Frame ${readyDetail.frameId}',
                ),
                _DetailChip(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Success: ${readyDetail.success}',
                ),
                _DetailChip(
                  icon: Icons.person_search_rounded,
                  label: 'Detections: ${readyDetail.numDetections ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (readyDetail.poseOutputPath != null)
              _DetailRow(
                label: 'Pose output path',
                value: readyDetail.poseOutputPath!,
              ),
            if (readyDetail.errorMessage != null)
              _DetailRow(
                label: 'Inference error',
                value: readyDetail.errorMessage!,
              ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.72),
                ),
              ),
              child: SelectableText(
                readyDetail.prettyJson,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  height: 1.34,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackendErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenHistory;

  const _BackendErrorState({
    required this.message,
    required this.onRetry,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load backend results',
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
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Retry Session',
                  onPressed: () {
                    onRetry();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: 'Open History',
                  onPressed: onOpenHistory,
                  isSecondary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoResultState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenHistory;

  const _NoResultState({
    required this.onRefresh,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No frames available',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'The backend session exists, but no frames were indexed for it yet.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Refresh Session',
                  onPressed: () {
                    onRefresh();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: 'Open History',
                  onPressed: onOpenHistory,
                  isSecondary: true,
                ),
              ),
            ],
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

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({
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
            width: 118,
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
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
