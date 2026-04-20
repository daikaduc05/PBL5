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
import '../config/backend_config.dart';
import '../navigation/app_routes.dart';
import '../services/api_service.dart';
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
  final ApiService _api = ApiService();
  final MockPoseTrackingService _poseService = MockPoseTrackingService();

  CaptureMode _selectedMode = CaptureMode.video;
  int _selectedDurationSeconds = 10;
  bool _autoUpload = true;
  bool _isLoading = true;
  bool _isSubmittingCapture = false;
  bool _isRecording = false;
  bool _pipelineReady = false;
  Duration _elapsed = Duration.zero;
  int? _captureDeviceId;
  String? _captureDeviceName;
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
    var ready = false;
    int? captureDeviceId;
    String? captureDeviceName;

    try {
      final backendHealthy = await _api.checkHealth();
      if (backendHealthy) {
        final devices = await _api.getDevices();
        final captureDevice = _pickCaptureDevice(devices);
        ready = captureDevice != null && _isDeviceReady(captureDevice);
        captureDeviceId = captureDevice?.id;
        captureDeviceName = captureDevice?.deviceName;
      }
    } catch (_) {
      ready = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMode = settings.defaultMode;
      _selectedDurationSeconds = settings.defaultDurationSeconds;
      _autoUpload = settings.autoUpload;
      _pipelineReady = ready;
      _captureDeviceId = captureDeviceId;
      _captureDeviceName = captureDeviceName;
      _isLoading = false;
    });
  }

  DeviceInfo? _pickCaptureDevice(List<DeviceInfo> devices) {
    if (devices.isEmpty) {
      return null;
    }

    for (final device in devices) {
      if (device.deviceCode == BackendConfig.defaultPiDeviceCode) {
        return device;
      }
    }

    return devices.first;
  }

  bool _isDeviceReady(DeviceInfo device) {
    final normalizedStatus = device.status.toLowerCase();
    return normalizedStatus != 'offline' && normalizedStatus != 'error';
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

  void _showPipelineRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Connect the backend and Raspberry Pi first, then start the capture command.',
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
    if (_isLoading || _isSubmittingCapture || _isRecording || _selectedMode != CaptureMode.video) {
      return;
    }

    if (!_pipelineReady) {
      _showPipelineRequiredMessage();
      return;
    }

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
    if (!_isRecording || _isSubmittingCapture) {
      return;
    }

    _timer?.cancel();

    final actualDurationSeconds = _elapsed.inSeconds == 0
        ? 1
        : _elapsed.inSeconds;

    setState(() {
      _isRecording = false;
    });

    await _submitCaptureCommand(
      mode: CaptureMode.video,
      targetDurationSeconds: _selectedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      successMessage: autoTriggered
          ? null
          : 'Recording saved. Capture command sent to the Raspberry Pi.',
    );
  }

  Future<void> _captureImage() async {
    if (_isLoading || _isSubmittingCapture || _isRecording || _selectedMode != CaptureMode.image) {
      return;
    }

    if (!_pipelineReady) {
      _showPipelineRequiredMessage();
      return;
    }

    await _submitCaptureCommand(
      mode: CaptureMode.image,
      targetDurationSeconds: 0,
      actualDurationSeconds: 0,
      successMessage: 'Image capture command sent to the Raspberry Pi.',
    );
  }

  Future<void> _submitCaptureCommand({
    required CaptureMode mode,
    required int targetDurationSeconds,
    required int actualDurationSeconds,
    String? successMessage,
  }) async {
    setState(() {
      _isSubmittingCapture = true;
    });

    try {
      final draft = await _createBackendCaptureDraft(
        mode: mode,
        targetDurationSeconds: targetDurationSeconds,
        actualDurationSeconds: actualDurationSeconds,
      );

      if (!mounted) {
        return;
      }

      if (successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }

      Navigator.of(context).pushNamed(
        AppRoutes.processing,
        arguments: draft,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCapture = false;
        });
      }
    }
  }

  Future<CaptureSessionDraft> _createBackendCaptureDraft({
    required CaptureMode mode,
    required int targetDurationSeconds,
    required int actualDurationSeconds,
  }) async {
    final settings = await _poseService.getSettings();
    final captureDevice = await _resolveCaptureDevice();
    if (captureDevice == null || !_isDeviceReady(captureDevice)) {
      throw const ApiException(
        'No online Raspberry Pi device is available on the backend yet.',
      );
    }

    final session = await _api.createSession();
    final command = await _api.createDeviceCommand(
      deviceId: captureDevice.id,
      sessionId: session.sessionId,
      commandType: 'start_recording',
      commandPayload: {
        'frames_dir': BackendConfig.defaultPiFramesDir,
        'zmq_host': _resolveZmqHost(settings.serverAddress),
        'zmq_port': BackendConfig.defaultZmqPort,
        'capture_mode': mode.name,
        'target_duration_seconds': targetDurationSeconds,
        'actual_duration_seconds': actualDurationSeconds,
        'source': 'mobile_app',
      },
    );

    return CaptureSessionDraft(
      sessionId: command.sessionKey,
      backendSessionId: session.sessionId,
      deviceId: captureDevice.id,
      commandId: command.commandId,
      mode: mode,
      targetDurationSeconds: targetDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      capturedAt: session.createdAt ?? DateTime.now(),
      autoUpload: settings.autoUpload,
      raspberryPiIp: settings.raspberryPiIp,
      serverAddress: settings.serverAddress,
    );
  }

  Future<DeviceInfo?> _resolveCaptureDevice() async {
    if (_captureDeviceId != null) {
      final devices = await _api.getDevices();
      for (final device in devices) {
        if (device.id == _captureDeviceId) {
          return device;
        }
      }
    }

    final devices = await _api.getDevices();
    final captureDevice = _pickCaptureDevice(devices);
    if (mounted) {
      setState(() {
        _captureDeviceId = captureDevice?.id;
        _captureDeviceName = captureDevice?.deviceName;
        _pipelineReady = captureDevice != null && _isDeviceReady(captureDevice);
      });
    }
    return captureDevice;
  }

  String _resolveZmqHost(String serverAddress) {
    var value = serverAddress.trim();
    if (value.isEmpty) {
      value = BackendConfig.defaultServerAddress;
    }
    if (!value.contains('://')) {
      value = 'http://$value';
    }
    final uri = Uri.parse(value);
    return uri.host.isEmpty ? 'localhost' : uri.host;
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
                  label: _pipelineReady ? 'Ready' : 'Check Connect',
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
                          value: _captureDeviceName ??
                              (_pipelineReady ? 'Linked' : 'Waiting'),
                        ),
                        _InfoTag(
                          icon: Icons.cloud_done_rounded,
                          label: 'Server',
                          value: _pipelineReady ? 'Command Ready' : 'Check API',
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
                  isLoading: _isLoading || _isSubmittingCapture,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: value,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
