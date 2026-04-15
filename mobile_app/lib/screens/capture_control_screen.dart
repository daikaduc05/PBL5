import 'dart:async';

import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/option_chip.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/pose_visualization_card.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../navigation/app_routes.dart';
import '../services/mock_device_connection_service.dart';
import '../services/mock_pose_tracking_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class CaptureControlScreen extends StatefulWidget {
  const CaptureControlScreen({super.key});

  @override
  State<CaptureControlScreen> createState() => _CaptureControlScreenState();
}

class _CaptureControlScreenState extends State<CaptureControlScreen> {
  final MockPoseTrackingService _poseService = MockPoseTrackingService();
  final MockDeviceConnectionService _deviceService = MockDeviceConnectionService();

  CaptureMode _selectedMode = CaptureMode.video;
  int _selectedDurationSeconds = 10;
  bool _autoUpload = true;
  bool _isLoading = true;
  bool _isRecording = false;
  bool _pipelineReady = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    final settings = await _poseService.getSettings();
    final devices = await _deviceService.getDevices();
    final ready = devices.every(
      (device) => device.status == DeviceLinkStatus.connected,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMode = settings.defaultMode;
      _selectedDurationSeconds = settings.defaultDurationSeconds;
      _autoUpload = settings.autoUpload;
      _pipelineReady = ready;
      _isLoading = false;
    });
  }

  void _selectMode(CaptureMode mode) {
    if (_isRecording) {
      return;
    }

    setState(() {
      _selectedMode = mode;
      if (mode == CaptureMode.image) {
        _elapsed = Duration.zero;
      }
    });
  }

  void _selectDuration(int duration) {
    if (_isRecording) {
      return;
    }

    setState(() {
      _selectedDurationSeconds = duration;
    });
  }

  void _showDemoModeMessage() {
    if (_pipelineReady) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mock demo mode is active. Connect both endpoints for the full IoT pipeline.',
        ),
      ),
    );
  }

  void _showModeHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _startRecording() {
    if (_isLoading || _isRecording || _selectedMode != CaptureMode.video) {
      return;
    }

    _showDemoModeMessage();

    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextElapsed = Duration(seconds: timer.tick);

      if (!mounted) {
        timer.cancel();
        return;
      }

      if (nextElapsed.inSeconds >= _selectedDurationSeconds) {
        setState(() {
          _elapsed = Duration(seconds: _selectedDurationSeconds);
        });
        _stopRecording(autoTriggered: true);
        return;
      }

      setState(() {
        _elapsed = nextElapsed;
      });
    });
  }

  Future<void> _stopRecording({bool autoTriggered = false}) async {
    if (!_isRecording) {
      return;
    }

    _timer?.cancel();

    final actualDurationSeconds = _elapsed.inSeconds == 0
        ? 1
        : _elapsed.inSeconds;

    setState(() {
      _isRecording = false;
    });

    final draft = await _poseService.createCaptureDraft(
      mode: CaptureMode.video,
      targetDurationSeconds: _selectedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
    );

    if (!mounted) {
      return;
    }

    if (!autoTriggered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved. Preparing AI processing.')),
      );
    }

    Navigator.of(context).pushNamed(
      AppRoutes.processing,
      arguments: draft,
    );
  }

  Future<void> _captureImage() async {
    if (_isLoading || _isRecording || _selectedMode != CaptureMode.image) {
      return;
    }

    _showDemoModeMessage();

    final draft = await _poseService.createCaptureDraft(
      mode: CaptureMode.image,
      targetDurationSeconds: 0,
      actualDurationSeconds: 0,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image captured. Sending frame to the server.')),
    );

    Navigator.of(context).pushNamed(
      AppRoutes.processing,
      arguments: draft,
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerLabel = _selectedMode == CaptureMode.image
        ? 'Frame'
        : formatStopwatch(_elapsed);

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'Capture Control',
                subtitle:
                    'Portrait-first mobile recording controls for the Raspberry Pi and AI pose pipeline.',
                onBackPressed: _goBack,
                trailing: StatusBadge(
                  label: _pipelineReady ? 'Ready' : 'Demo Mode',
                  color: _pipelineReady ? AppColors.success : AppColors.primary,
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
                                'Mobile Capture Session',
                                style: AppTypography.h2.copyWith(fontSize: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Use a clean smartphone control layout to trigger image or video capture, then forward the session to processing.',
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
                            color: AppColors.background.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto Upload',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _autoUpload ? 'ENABLED' : 'MANUAL',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: _autoUpload
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoTag(
                          icon: Icons.memory_rounded,
                          label: 'Edge Node',
                          value: _pipelineReady ? 'Linked' : 'Preview Ready',
                        ),
                        _InfoTag(
                          icon: Icons.cloud_done_rounded,
                          label: 'Server',
                          value: _pipelineReady ? 'Online' : 'Mock Queue',
                        ),
                        _InfoTag(
                          icon: Icons.schedule_rounded,
                          label: 'Duration',
                          value: _selectedMode == CaptureMode.image
                              ? 'Single frame'
                              : '${_selectedDurationSeconds}s',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PoseVisualizationCard(
                aspectRatio: 3 / 4,
                title: _selectedMode == CaptureMode.image
                    ? 'Camera Preview'
                    : 'Live Recording Preview',
                subtitle: _selectedMode == CaptureMode.image
                    ? 'Front camera aligned for a single high-confidence frame.'
                    : 'Capture motion cleanly before the AI pipeline receives the clip.',
                statusLabel: _isRecording ? 'Recording' : 'Preview',
                footerLabel: 'Tracking',
                footerValue: _selectedMode == CaptureMode.image
                    ? '17 keypoints'
                    : '${_selectedDurationSeconds}s profile',
                timerLabel: timerLabel,
                isRecording: _isRecording,
              ),
              const SizedBox(height: 18),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capture Mode',
                      style: AppTypography.h3.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Switch between a single processed image and a short motion clip.',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OptionChip<CaptureMode>(
                          value: CaptureMode.image,
                          selectedValue: _selectedMode,
                          label: 'Image',
                          icon: Icons.photo_camera_rounded,
                          onSelected: _selectMode,
                        ),
                        OptionChip<CaptureMode>(
                          value: CaptureMode.video,
                          selectedValue: _selectedMode,
                          label: 'Video',
                          icon: Icons.videocam_rounded,
                          onSelected: _selectMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Recording Duration',
                      style: AppTypography.h3.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select the motion clip length used for the demo capture workflow.',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [5, 10, 15]
                          .map(
                            (duration) => OptionChip<int>(
                              value: duration,
                              selectedValue: _selectedDurationSeconds,
                              label: '${duration}s',
                              icon: Icons.timer_rounded,
                              onSelected: _selectDuration,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Start Recording',
                  onPressed: _selectedMode == CaptureMode.video && !_isRecording
                      ? _startRecording
                      : () => _showModeHint(
                          'Switch to video mode to start a recording session.',
                        ),
                  isLoading: _isLoading,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Stop Recording',
                  onPressed: _isRecording
                      ? () {
                          _stopRecording();
                        }
                      : () => _showModeHint(
                          'Recording has not started yet.',
                        ),
                  isSecondary: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Capture Image',
                  onPressed: _selectedMode == CaptureMode.image && !_isRecording
                      ? () {
                          _captureImage();
                        }
                      : () => _showModeHint(
                          'Switch to image mode to capture a single frame.',
                        ),
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

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTag({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
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
