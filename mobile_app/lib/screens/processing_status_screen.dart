import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../models/result_models.dart';
import '../navigation/app_routes.dart';
import '../services/api_service.dart';
import '../services/mock_pose_tracking_service.dart';
import '../services/result_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class ProcessingStatusScreen extends StatefulWidget {
  final CaptureSessionDraft draft;

  const ProcessingStatusScreen({super.key, required this.draft});

  @override
  State<ProcessingStatusScreen> createState() => _ProcessingStatusScreenState();
}

class _ProcessingStatusScreenState extends State<ProcessingStatusScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final MockPoseTrackingService _poseService = MockPoseTrackingService();
  final ResultApi _resultApi = ResultApi();

  late final AnimationController _pulseController;
  late final List<ProcessingStage> _stages;
  Timer? _timer;

  double _progress = 0.0;
  bool _isFinalizing = false;
  bool _isPolling = false;
  PoseAnalysisResult? _legacyResult;
  DeviceCommandInfo? _command;
  ResultSessionDetail? _resultSession;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _stages = _buildProcessingStages();
    if (_usesBackendPipeline) {
      _startBackendPolling();
    } else {
      _startLegacyProgress();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _usesBackendPipeline =>
      widget.draft.commandId != null && widget.draft.deviceId != null;

  bool get _isResultReady => _usesBackendPipeline
      ? (_resultSession?.resultReadyCount ?? 0) > 0
      : _legacyResult != null;

  bool get _hasFailed => _usesBackendPipeline && _command?.status == 'failed';

  int get _activeStageIndex {
    if (_isResultReady || _progress >= 1.0) {
      return _stages.length - 1;
    }

    return (_progress * _stages.length).floor().clamp(0, _stages.length - 1);
  }

  Duration get _estimatedRemaining {
    if (_isResultReady || _hasFailed) {
      return Duration.zero;
    }

    if (!_usesBackendPipeline && _isFinalizing) {
      return const Duration(seconds: 1);
    }

    if (_usesBackendPipeline) {
      if (_resultSession != null) {
        return const Duration(seconds: 2);
      }
      return switch (_command?.status) {
        'acknowledged' => const Duration(seconds: 8),
        'running' => const Duration(seconds: 5),
        'completed' => const Duration(seconds: 3),
        _ => const Duration(seconds: 12),
      };
    }

    final remaining = (1.0 - _progress).clamp(0.0, 1.0);
    final ticks = (remaining / 0.038).ceil();
    return Duration(milliseconds: (ticks * 220) + 420);
  }

  List<ProcessingStage> _buildProcessingStages() {
    return const [
      ProcessingStage(
        title: 'Queued on Backend',
        description:
            'The mobile app created a session and queued a capture command for the Raspberry Pi.',
      ),
      ProcessingStage(
        title: 'Pi Agent Acknowledged',
        description:
            'The edge node claimed the command and is preparing the capture workspace.',
      ),
      ProcessingStage(
        title: 'Capturing + Streaming',
        description:
            'Frames are being replayed or captured on the Pi and pushed into the worker pipeline.',
      ),
      ProcessingStage(
        title: 'Worker Processing Frames',
        description:
            'Pose overlays and per-frame JSON outputs are being written into the result session.',
      ),
      ProcessingStage(
        title: 'Result Session Ready',
        description:
            'The backend session now has processed output that can be opened from the app.',
      ),
    ];
  }

  Future<void> _startBackendPolling() async {
    await _pollBackendStatus();
    if (!mounted || _isResultReady || _hasFailed) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pollBackendStatus();
    });
  }

  void _startLegacyProgress() {
    _timer = Timer.periodic(const Duration(milliseconds: 220), (timer) async {
      if (!mounted || _isFinalizing || _legacyResult != null) {
        timer.cancel();
        return;
      }

      final increment = switch (_progress) {
        < 0.18 => 0.055,
        < 0.36 => 0.045,
        < 0.58 => 0.038,
        < 0.82 => 0.03,
        _ => 0.022,
      };
      final nextProgress = (_progress + increment).clamp(0.0, 1.0).toDouble();

      setState(() {
        _progress = nextProgress;
      });

      if (nextProgress >= 1.0) {
        timer.cancel();
        await _finalizeLegacy();
      }
    });
  }

  double _stageProgress(int index) {
    if (_isResultReady) {
      return 1.0;
    }

    final segmentSize = 1 / _stages.length;
    final segmentStart = index * segmentSize;
    final segmentEnd = segmentStart + segmentSize;

    if (_progress <= segmentStart) {
      return 0.0;
    }

    if (_progress >= segmentEnd) {
      return 1.0;
    }

    return ((_progress - segmentStart) / segmentSize).clamp(0.0, 1.0);
  }

  Future<void> _pollBackendStatus() async {
    if (!_usesBackendPipeline || _isPolling) {
      return;
    }

    final deviceId = widget.draft.deviceId;
    final commandId = widget.draft.commandId;
    if (deviceId == null || commandId == null) {
      return;
    }

    setState(() {
      _isPolling = true;
    });

    try {
      final command = await _api.getDeviceCommandStatus(
        deviceId: deviceId,
        commandId: commandId,
      );

      ResultSessionDetail? resultSession = _resultSession;
      String? resultLookupError;
      try {
        resultSession = await _resultApi.getResultSessionDetail(
          widget.draft.sessionId,
        );
      } on ResultApiException catch (error) {
        if (error.message.contains('not found') ||
            error.message.contains('HTTP 404')) {
          resultSession = null;
        } else {
          resultLookupError = error.message;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _command = command;
        _resultSession = resultSession;
        _progress = _progressForBackend(
          command: command,
          resultSession: resultSession,
        );
        _errorMessage = command.status == 'failed'
            ? (resultLookupError ??
                  'The Raspberry Pi command failed before the result session was completed.')
            : resultLookupError;
        _isPolling = false;
      });

      if (command.status == 'failed' ||
          (resultSession?.resultReadyCount ?? 0) > 0) {
        _timer?.cancel();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPolling = false;
        _errorMessage = extractApiError(error);
      });
    }
  }

  double _progressForBackend({
    required DeviceCommandInfo command,
    required ResultSessionDetail? resultSession,
  }) {
    if (command.status == 'failed') {
      return 0.78;
    }

    if (resultSession != null) {
      if (resultSession.resultReadyCount > 0) {
        return 1.0;
      }
      if (resultSession.frameCount > 0) {
        return 0.86;
      }
      return 0.74;
    }

    return switch (command.status) {
      'acknowledged' => 0.28,
      'running' => 0.56,
      'completed' => 0.72,
      _ => 0.12,
    };
  }

  Future<void> _finalizeLegacy() async {
    setState(() {
      _isFinalizing = true;
    });

    final result = await _poseService.finalizeCapture(widget.draft);

    if (!mounted) {
      return;
    }

    setState(() {
      _legacyResult = result;
      _isFinalizing = false;
    });
  }

  void _goBackHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  void _openResult() {
    if (_usesBackendPipeline) {
      final resultSession = _resultSession;
      if (!_isResultReady || resultSession == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The backend is still waiting for processed frames. Please give the worker a moment.',
            ),
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.captureResult,
        arguments: ResultScreenArgs(
          sessionId: resultSession.sessionId,
          initialFrameId: resultSession.latestResultFrameId,
        ),
      );
      return;
    }

    final result = _legacyResult;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PoseTrack is still generating the result package. Please wait a moment.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.captureResult,
      arguments: result,
    );
  }

  IconData _iconForStage(int index) {
    return switch (index) {
      0 => Icons.upload_rounded,
      1 => Icons.cloud_upload_rounded,
      2 => Icons.movie_filter_rounded,
      3 => Icons.accessibility_new_rounded,
      _ => Icons.analytics_rounded,
    };
  }

  String _formatEta(Duration value) {
    if (value <= Duration.zero) {
      return '0s';
    }

    if (value.inMinutes >= 1) {
      final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '${value.inMinutes}m ${seconds}s';
    }

    return '${value.inSeconds}s';
  }

  String get _captureSummary {
    return switch (widget.draft.mode) {
      CaptureMode.image => 'Single frame upload',
      CaptureMode.video => '${widget.draft.actualDurationSeconds}s motion clip',
    };
  }

  String get _statusLabel {
    if (_isResultReady) {
      return 'Result Ready';
    }
    if (_hasFailed) {
      return 'Failed';
    }
    if (_usesBackendPipeline) {
      return switch (_command?.status) {
        'acknowledged' => 'Claimed',
        'running' => 'Running',
        'completed' => 'Packaging',
        _ => _isPolling ? 'Syncing' : 'Queued',
      };
    }
    return _isFinalizing ? 'Finalizing' : 'AI Running';
  }

  Color get _statusColor {
    if (_isResultReady) {
      return AppColors.success;
    }
    if (_hasFailed || _errorMessage != null) {
      return AppColors.warning;
    }
    return AppColors.primary;
  }

  String get _heroTitle {
    if (_isResultReady) {
      return 'Processing Complete';
    }
    if (_hasFailed) {
      return 'Command Failed';
    }
    if (_usesBackendPipeline) {
      if (_resultSession != null && _resultSession!.frameCount > 0) {
        return 'Worker Processing Frames';
      }
      return switch (_command?.status) {
        'acknowledged' => 'Pi Agent Claimed the Command',
        'running' => 'Capture Stream Is Running',
        'completed' => 'Waiting for Result Files',
        _ => 'Waiting for Raspberry Pi',
      };
    }
    return _stages[_activeStageIndex].title;
  }

  String get _heroDescription {
    if (_isResultReady) {
      return 'Pose overlays, confidence scores, and backend metadata are ready for review.';
    }
    if (_hasFailed) {
      return _errorMessage ??
          'The command reached a failed state. Check the Pi agent log and backend worker output.';
    }
    if (_usesBackendPipeline) {
      if (_resultSession != null && _resultSession!.frameCount > 0) {
        return 'The backend session has started receiving processed frames and is packaging the latest result JSON.';
      }
      return switch (_command?.status) {
        'acknowledged' =>
          'The Pi agent has acknowledged the command and is preparing the replay or capture workflow.',
        'running' =>
          'Frames should now be moving through the Pi agent and ZeroMQ worker pipeline.',
        'completed' =>
          'The edge command completed; the app is waiting for the result session to finish indexing processed frames.',
        _ =>
          'The command is still queued on the backend and waiting for the Raspberry Pi to claim it.',
      };
    }
    return _stages[_activeStageIndex].description;
  }

  @override
  Widget build(BuildContext context) {
    final activeStage = _stages[_activeStageIndex];
    final progressLabel = '${(_progress * 100).round()}%';
    final stageCounter = _isResultReady
        ? '${_stages.length}/${_stages.length}'
        : '${_activeStageIndex + 1}/${_stages.length}';

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
                    'Tracking the PoseTrack mobile upload, server queue, and pose estimation pipeline in real time.',
                onBackPressed: _goBackHome,
                trailing: StatusBadge(
                  label: _statusLabel,
                  color: _statusColor,
                  icon: _isResultReady
                      ? Icons.check_circle_outline_rounded
                      : _hasFailed
                      ? Icons.error_outline_rounded
                      : Icons.motion_photos_on_rounded,
                ),
              ),
              const SizedBox(height: 24),
              GlassPanel(
                highlighted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useColumnLayout = constraints.maxWidth < 360;

                        if (useColumnLayout) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeroCopy(
                                stageCounter: stageCounter,
                                title: _heroTitle,
                                description: _heroDescription,
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: _ProcessingBeacon(
                                  animation: _pulseController,
                                  isComplete: _isResultReady,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _HeroCopy(
                                stageCounter: stageCounter,
                                title: _heroTitle,
                                description: _heroDescription,
                              ),
                            ),
                            const SizedBox(width: 16),
                            _ProcessingBeacon(
                              animation: _pulseController,
                              isComplete: _isResultReady,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                progressLabel,
                                style: AppTypography.h1.copyWith(fontSize: 44),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isResultReady
                                    ? 'Inference finished and results packaged.'
                                    : _hasFailed
                                    ? 'The backend reported a failed command.'
                                    : 'Live stage: ${activeStage.title}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _TelemetryMetric(
                          label: _isResultReady || _hasFailed ? 'Status' : 'ETA',
                          value: _isResultReady
                              ? 'READY'
                              : _hasFailed
                              ? 'FAILED'
                              : _formatEta(_estimatedRemaining),
                          accentColor: _isResultReady
                              ? AppColors.success
                              : _hasFailed
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _AnimatedProgressBar(
                      progress: _progress,
                      animation: _pulseController,
                      isComplete: _isResultReady,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoPill(
                          icon: Icons.badge_rounded,
                          label: 'Session',
                          value: widget.draft.sessionId,
                        ),
                        _InfoPill(
                          icon: Icons.videocam_rounded,
                          label: 'Capture',
                          value: _captureSummary,
                        ),
                        _InfoPill(
                          icon: Icons.schedule_rounded,
                          label: 'Started',
                          value: formatShortDateTime(widget.draft.capturedAt),
                        ),
                        _InfoPill(
                          icon: Icons.cloud_done_rounded,
                          label: 'Upload',
                          value: widget.draft.autoUpload ? 'Auto' : 'Manual',
                        ),
                        if (_usesBackendPipeline)
                          _InfoPill(
                            icon: Icons.memory_rounded,
                            label: 'Command',
                            value: (_command?.status ?? 'pending').toUpperCase(),
                          ),
                        if (_usesBackendPipeline && _resultSession != null)
                          _InfoPill(
                            icon: Icons.filter_frames_rounded,
                            label: 'Frames',
                            value:
                                '${_resultSession!.frameCount} / ${_resultSession!.resultReadyCount} JSON',
                          ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            height: 1.24,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
                                'Processing Timeline',
                                style: AppTypography.h3.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Following the mobile-to-server AI workflow from upload through final pose result generation.',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontSize: 14,
                                  height: 1.24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TelemetryMetric(
                          label: 'Pipeline',
                          value: stageCounter,
                          accentColor: AppColors.accentSoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ..._stages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stage = entry.value;
                      final isComplete =
                          _isResultReady || index < _activeStageIndex;
                      final isActive =
                          !_isResultReady && index == _activeStageIndex;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _stages.length - 1 ? 0 : 14,
                        ),
                        child: _TimelineStageTile(
                          title: stage.title,
                          description: stage.description,
                          icon: _iconForStage(index),
                          progress: _stageProgress(index),
                          isDone: isComplete,
                          isActive: isActive,
                          isLast: index == _stages.length - 1,
                          animation: _pulseController,
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
                  text: 'Open Result',
                  onPressed: _openResult,
                  isLoading: !_usesBackendPipeline && _isFinalizing,
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

class _HeroCopy extends StatelessWidget {
  final String stageCounter;
  final String title;
  final String description;

  const _HeroCopy({
    required this.stageCounter,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.82)),
          ),
          child: Text(
            'Pipeline Step $stageCounter',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Text(
            title,
            key: ValueKey(title),
            style: AppTypography.h2.copyWith(fontSize: 24),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Text(
            description,
            key: ValueKey(description),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Animation<double> animation;
  final bool isComplete;

  const _AnimatedProgressBar({
    required this.progress,
    required this.animation,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = math
            .max(width * safeProgress, safeProgress > 0 ? 32.0 : 0.0)
            .toDouble();
        final shimmerTravel = fillWidth + 80;

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final shimmerOffset = (shimmerTravel * animation.value) - 40;

            return Container(
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: fillWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isComplete
                              ? const [AppColors.success, AppColors.primary]
                              : const [AppColors.primary, AppColors.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.26),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    if (safeProgress > 0)
                      Positioned(
                        left: shimmerOffset,
                        top: -6,
                        bottom: -6,
                        child: Container(
                          width: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.25, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProcessingBeacon extends StatelessWidget {
  final Animation<double> animation;
  final bool isComplete;

  const _ProcessingBeacon({required this.animation, required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final accent = isComplete ? AppColors.success : AppColors.primary;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = (math.sin(animation.value * math.pi * 2) + 1) / 2;
        final outerSize = 102 + (wave * 8);
        final midSize = 76 + (wave * 6);
        final coreSize = 48 + (wave * 4);

        return SizedBox(
          width: 118,
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: midSize,
                height: midSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                  color: accent.withValues(alpha: 0.08),
                ),
              ),
              Container(
                width: coreSize,
                height: coreSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.24),
                      accent.withValues(alpha: 0.84),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.38),
                      blurRadius: 18 + (wave * 10),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isComplete ? Icons.check_rounded : Icons.sync_rounded,
                  color: AppColors.background,
                  size: 26,
                ),
              ),
              Positioned(
                bottom: 8,
                child: Row(
                  children: List.generate(3, (index) {
                    final phase = (animation.value + (index * 0.16)) % 1.0;
                    final barHeight =
                        10 + (((math.sin(phase * math.pi * 2) + 1) / 2) * 8);

                    return Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
                      child: Container(
                        width: 5,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.9 - (index * 0.14)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;

  const _TelemetryMetric({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStageTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final double progress;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final Animation<double> animation;

  const _TimelineStageTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDone
        ? AppColors.success
        : isActive
        ? AppColors.primary
        : AppColors.border;
    final stateLabel = isDone
        ? 'Complete'
        : isActive
        ? '${(progress * 100).round()}%'
        : 'Queued';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Column(
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final glow = isActive
                      ? 0.18 +
                            (((math.sin(animation.value * math.pi * 2) + 1) /
                                    2) *
                                0.2)
                      : isDone
                      ? 0.12
                      : 0.0;

                  return Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(
                        alpha: isDone || isActive ? 0.16 : 0.06,
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.42)),
                      boxShadow: glow > 0
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: glow),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isDone ? Icons.check_rounded : icon,
                      size: 19,
                      color: isDone || isActive ? accent : AppColors.textMuted,
                    ),
                  );
                },
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 84,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(
                          alpha: isDone || isActive ? 0.5 : 0.2,
                        ),
                        AppColors.border.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.background.withValues(alpha: 0.22)
                  : AppColors.background.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : isDone
                    ? AppColors.success.withValues(alpha: 0.24)
                    : AppColors.border.withValues(alpha: 0.68),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: isDone || isActive ? 0.14 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(
                            alpha: isDone || isActive ? 0.28 : 0.2,
                          ),
                        ),
                      ),
                      child: Text(
                        stateLabel,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDone || isActive
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.24,
                  ),
                ),
                const SizedBox(height: 12),
                _StageProgressBar(
                  progress: isDone ? 1.0 : progress,
                  accent: accent,
                  animation: animation,
                  animate: isActive,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final Animation<double> animation;
  final bool animate;

  const _StageProgressBar({
    required this.progress,
    required this.accent,
    required this.animation,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = math
            .max(width * progress.clamp(0.0, 1.0), 0.0)
            .toDouble();

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final shimmerOffset = (fillWidth * animation.value) - 26;

            return Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: fillWidth,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    if (animate && fillWidth > 0)
                      Positioned(
                        left: shimmerOffset,
                        top: -4,
                        bottom: -4,
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
