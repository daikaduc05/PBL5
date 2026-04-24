import 'dart:convert';

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

class ResultFrameDetailScreen extends StatefulWidget {
  final String sessionId;
  final int frameId;
  final String? initialPoseImageUrl;

  const ResultFrameDetailScreen({
    super.key,
    required this.sessionId,
    required this.frameId,
    this.initialPoseImageUrl,
  });

  @override
  State<ResultFrameDetailScreen> createState() => _ResultFrameDetailScreenState();
}

class _ResultFrameDetailScreenState extends State<ResultFrameDetailScreen> {
  final ResultApi _resultApi = ResultApi();

  FrameResultDetail? _frameDetail;
  String? _poseImageUrl;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFrameDetail();
  }

  Future<void> _loadFrameDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final frameDetail = await _resultApi.getFrameResult(
        widget.sessionId,
        widget.frameId,
      );

      var poseImageUrl = widget.initialPoseImageUrl;
      if (poseImageUrl == null || poseImageUrl.isEmpty) {
        final sessionDetail = await _resultApi.getResultSessionDetail(
          widget.sessionId,
        );
        poseImageUrl = sessionDetail.findFrame(widget.frameId)?.poseImageUrl;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _frameDetail = frameDetail;
        _poseImageUrl = poseImageUrl;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _frameDetail = null;
        _poseImageUrl = widget.initialPoseImageUrl;
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _errorMessage == null
        ? (_isLoading ? AppColors.primary : AppColors.success)
        : AppColors.warning;
    final statusLabel = _errorMessage == null
        ? (_isLoading ? 'Loading Detail' : 'Frame Ready')
        : 'Check Backend';

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'Frame Detail',
                subtitle:
                    'Inspect the processed pose image and JSON result for a single frame from FastAPI.',
                onBackPressed: _goBack,
                trailing: StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  icon: Icons.analytics_rounded,
                ),
              ),
              const SizedBox(height: 24),
              _Hero(sessionId: widget.sessionId, frameId: widget.frameId),
              const SizedBox(height: 18),
              if (_isLoading)
                const _LoadingState(message: 'Loading frame result...')
              else if (_errorMessage != null)
                _ErrorState(
                  message: _errorMessage!,
                  onRetry: _loadFrameDetail,
                )
              else if (_frameDetail == null)
                _EmptyState(onRefresh: _loadFrameDetail)
              else ...[
                _PoseImagePanel(
                  poseImageUrl: _poseImageUrl,
                ),
                const SizedBox(height: 18),
                _SummaryPanel(detail: _frameDetail!),
                const SizedBox(height: 18),
                _MetadataPanel(detail: _frameDetail!),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Refresh Frame',
                      onPressed: _loadFrameDetail,
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

class _Hero extends StatelessWidget {
  final String sessionId;
  final int frameId;

  const _Hero({
    required this.sessionId,
    required this.frameId,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session $sessionId',
            style: AppTypography.h2.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Frame $frameId reads `/api/results/$sessionId/$frameId` for JSON detail and reuses `pose_image_url` to display the stored overlay image.',
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
                icon: Icons.folder_rounded,
                label: sessionId,
              ),
              _InfoChip(
                icon: Icons.flag_rounded,
                label: 'Frame $frameId',
              ),
              const _InfoChip(
                icon: Icons.http_rounded,
                label: 'GET frame detail',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoseImagePanel extends StatelessWidget {
  final String? poseImageUrl;

  const _PoseImagePanel({required this.poseImageUrl});

  @override
  Widget build(BuildContext context) {
    final hasPoseImage = poseImageUrl != null && poseImageUrl!.isNotEmpty;

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
                label: hasPoseImage ? 'Image Ready' : 'No Image',
                color: hasPoseImage ? AppColors.success : AppColors.warning,
                icon: hasPoseImage
                    ? Icons.image_rounded
                    : Icons.image_not_supported_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 0.9,
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
                child: hasPoseImage
                    ? Image.network(
                        poseImageUrl!,
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
                                'The app could not open the pose image from the backend.',
                          );
                        },
                      )
                    : const _ImagePlaceholder(
                        message:
                            'This frame detail was loaded, but no pose image URL is available.',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final FrameResultDetail detail;

  const _SummaryPanel({required this.detail});

  @override
  Widget build(BuildContext context) {
    final tracking = detail.formTracking;
    final primaryDetection = detail.poseOverlay?.primaryDetection;
    final formStatus = tracking?.status ?? primaryDetection?.formStatus;
    final formMessage = tracking?.message ?? primaryDetection?.formFeedback;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frame Summary',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Core status fields parsed from the JSON response.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.26,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(
                icon: Icons.check_circle_outline_rounded,
                label: 'Success',
                value: '${detail.success ?? 'unknown'}',
              ),
              _MetricChip(
                icon: Icons.person_search_rounded,
                label: 'Detections',
                value: '${detail.numDetections ?? 0}',
              ),
              _MetricChip(
                icon: Icons.flag_rounded,
                label: 'Frame',
                value: '${detail.frameId}',
              ),
              if (formStatus != null)
                StatusBadge(
                  label: _formStatusLabel(formStatus),
                  color: _formStatusColor(formStatus),
                  icon: Icons.fitness_center_rounded,
                ),
              if (tracking != null)
                _MetricChip(
                  icon: Icons.repeat_rounded,
                  label: 'Rep',
                  value: '${tracking.repCount}',
                ),
              if (tracking?.stage != null)
                _MetricChip(
                  icon: Icons.stairs_rounded,
                  label: 'Stage',
                  value: tracking!.stage!,
                ),
            ],
          ),
          if (formMessage != null) ...[
            const SizedBox(height: 14),
            _DetailRow(
              label: 'Form feedback',
              value: formMessage,
            ),
          ],
          if (tracking?.kneeMin != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Knee min',
              value: tracking!.kneeMin!.toStringAsFixed(1),
            ),
          ],
          if (tracking?.hipMin != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Hip min',
              value: tracking!.hipMin!.toStringAsFixed(1),
            ),
          ],
          if (detail.poseOutputPath != null) ...[
            const SizedBox(height: 14),
            _DetailRow(
              label: 'Pose output path',
              value: detail.poseOutputPath!,
            ),
          ],
          if (detail.errorMessage != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Inference error',
              value: detail.errorMessage!,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  final FrameResultDetail detail;

  const _MetadataPanel({required this.detail});

  @override
  Widget build(BuildContext context) {
    final metadataEntries = detail.metadataEntries.toList(growable: false);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metadata',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Additional fields from the backend result are shown below, followed by the raw JSON payload.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.26,
            ),
          ),
          const SizedBox(height: 14),
          if (metadataEntries.isEmpty)
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
                'No extra metadata fields were present in the response.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.28,
                ),
              ),
            )
          else
            ...metadataEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DetailRow(
                  label: entry.key,
                  value: _stringifyValue(entry.value),
                ),
              ),
            ),
          const SizedBox(height: 8),
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
              detail.prettyJson,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: 1.34,
              ),
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
            'Unable to load frame detail',
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
            text: 'Retry Frame Detail',
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
            'No frame data available',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'The backend request completed, but the app did not receive a usable frame detail payload.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Refresh Frame',
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

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
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
            '$label: $value',
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

String _stringifyValue(Object? value) {
  if (value == null) {
    return 'null';
  }

  if (value is String || value is num || value is bool) {
    return value.toString();
  }

  return const JsonEncoder.withIndent('  ').convert(value);
}

Color _formStatusColor(String? status) {
  switch (status) {
    case 'GOOD_FORM':
      return AppColors.success;
    case 'BAD_FORM':
      return AppColors.error;
    default:
      return AppColors.warning;
  }
}

String _formStatusLabel(String? status) {
  switch (status) {
    case 'GOOD_FORM':
      return 'Good Form';
    case 'BAD_FORM':
      return 'Bad Form';
    default:
      return 'Unknown Form';
  }
}
