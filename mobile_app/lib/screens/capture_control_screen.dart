import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import '../models/result_models.dart';
import '../navigation/app_routes.dart';
import '../services/api_service.dart';
import '../services/mock_pose_tracking_service.dart';
import '../services/result_api.dart';
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
  final ResultApi _resultApi = ResultApi();

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
  String? _raspberryPiIp;
  CaptureSessionDraft? _activeRecordingDraft;
  Timer? _timer;
  Timer? _previewRefreshTimer;
  Timer? _liveInferenceTimer;
  int _previewRefreshTick = 0;
  ResultSessionDetail? _liveResultSession;
  ResultFrameItem? _latestInferenceFrame;
  String? _liveInferenceMessage;

  @override
  void initState() {
    super.initState();
    _startPreviewRefreshLoop();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _previewRefreshTimer?.cancel();
    _liveInferenceTimer?.cancel();
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
      _raspberryPiIp = settings.raspberryPiIp.trim();
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

  void _startRecordingTimer([Duration initialElapsed = Duration.zero]) {
    _timer?.cancel();
    final baseSeconds = initialElapsed.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextElapsed = Duration(seconds: baseSeconds + timer.tick);

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

  void _startPreviewRefreshLoop() {
    _previewRefreshTimer?.cancel();
    _previewRefreshTimer = Timer.periodic(
      const Duration(milliseconds: 350),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _previewRefreshTick += 1;
        });
      },
    );
  }

  void _startInferencePolling(CaptureSessionDraft draft) {
    _liveInferenceTimer?.cancel();
    _pollLiveInference(draft);
    _liveInferenceTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      _pollLiveInference(draft);
    });
  }

  void _stopInferencePolling() {
    _liveInferenceTimer?.cancel();
    _liveInferenceTimer = null;
  }

  Future<void> _pollLiveInference(CaptureSessionDraft draft) async {
    try {
      final session = await _resultApi.getResultSessionDetail(draft.sessionId);
      if (!mounted) {
        return;
      }

      final latestFrameId = session.latestResultFrameId ?? session.latestFrameId;
      final latestFrame = latestFrameId == null ? null : session.findFrame(latestFrameId);

      setState(() {
        _liveResultSession = session;
        _latestInferenceFrame = latestFrame?.hasPoseImage == true ? latestFrame : null;
        _liveInferenceMessage = latestFrame == null
            ? 'Frames are still reaching the worker.'
            : latestFrame.hasResultJson
            ? 'Latest inference frame ${latestFrame.frameId} is ready.'
            : 'Latest frame ${latestFrame.frameId} reached the backend. Waiting for JSON.';
      });
    } on ResultApiException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.message.contains('not found') || error.message.contains('HTTP 404')) {
        setState(() {
          _liveResultSession = null;
          _latestInferenceFrame = null;
          _liveInferenceMessage = 'Waiting for the first processed frame...';
        });
        return;
      }

      setState(() {
        _liveInferenceMessage = error.message;
      });
    }
  }

  Future<void> _startRecording() async {
    if (_isLoading || _isSubmittingCapture || _isRecording || _selectedMode != CaptureMode.video) {
      return;
    }

    if (!_pipelineReady) {
      _showPipelineRequiredMessage();
      return;
    }

    setState(() {
      _isSubmittingCapture = true;
    });

    try {
      final draft = await _createBackendCaptureDraft(
        mode: CaptureMode.video,
        targetDurationSeconds: _selectedDurationSeconds,
        actualDurationSeconds: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeRecordingDraft = draft;
        _isRecording = true;
        _elapsed = Duration.zero;
        _liveResultSession = null;
        _latestInferenceFrame = null;
        _liveInferenceMessage = 'Waiting for the worker to produce the first inference frame...';
      });
      _startRecordingTimer();
      _startInferencePolling(draft);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recording started. The Raspberry Pi is now running the capture command.',
          ),
        ),
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

  Future<void> _stopRecording({bool autoTriggered = false}) async {
    if (!_isRecording || _isSubmittingCapture) {
      return;
    }

    final activeDraft = _activeRecordingDraft;
    if (activeDraft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The active recording session was lost. Start a new recording and try again.',
          ),
        ),
      );
      return;
    }

    _timer?.cancel();
    _stopInferencePolling();

    final actualDurationSeconds = _elapsed.inSeconds == 0
        ? 1
        : _elapsed.inSeconds;

    setState(() {
      _isSubmittingCapture = true;
      _elapsed = Duration(seconds: actualDurationSeconds);
    });

    try {
      await _sendStopRecordingCommand(
        draft: activeDraft,
        actualDurationSeconds: actualDurationSeconds,
      );

      if (!mounted) {
        return;
      }

      final finalizedDraft = _completeRecordingDraft(
        draft: activeDraft,
        actualDurationSeconds: actualDurationSeconds,
      );

      setState(() {
        _isRecording = false;
        _activeRecordingDraft = null;
      });

      if (!autoTriggered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recording stopped. Waiting for the Raspberry Pi capture run to finish packaging results.',
            ),
          ),
        );
      }

      Navigator.of(context).pushNamed(
        AppRoutes.processing,
        arguments: finalizedDraft,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = true;
      });
      _startInferencePolling(activeDraft);
      _startRecordingTimer(_elapsed);

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

  Future<void> _sendStopRecordingCommand({
    required CaptureSessionDraft draft,
    required int actualDurationSeconds,
  }) async {
    final backendSessionId = draft.backendSessionId;
    final deviceId = draft.deviceId;
    if (backendSessionId == null || deviceId == null) {
      throw const ApiException(
        'The active recording session is missing backend identifiers.',
      );
    }

    await _api.createDeviceCommand(
      deviceId: deviceId,
      sessionId: backendSessionId,
      commandType: 'stop_recording',
      commandPayload: {
        'capture_mode': 'video',
        'target_duration_seconds': draft.targetDurationSeconds,
        'actual_duration_seconds': actualDurationSeconds,
        'source': 'mobile_app',
      },
    );
  }

  CaptureSessionDraft _completeRecordingDraft({
    required CaptureSessionDraft draft,
    required int actualDurationSeconds,
  }) {
    return CaptureSessionDraft(
      sessionId: draft.sessionId,
      backendSessionId: draft.backendSessionId,
      deviceId: draft.deviceId,
      commandId: draft.commandId,
      mode: draft.mode,
      targetDurationSeconds: draft.targetDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      capturedAt: draft.capturedAt,
      autoUpload: draft.autoUpload,
      raspberryPiIp: draft.raspberryPiIp,
      serverAddress: draft.serverAddress,
    );
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
    final commandType = mode == CaptureMode.image
        ? 'capture_photo'
        : 'start_recording';
    final command = await _api.createDeviceCommand(
      deviceId: captureDevice.id,
      sessionId: session.sessionId,
      commandType: commandType,
      commandPayload: {
        'frames_dir': BackendConfig.defaultPiFramesDir,
        'zmq_host': _resolveZmqHost(settings.serverAddress),
        'zmq_port': BackendConfig.defaultZmqPort,
        'capture_source': 'auto',
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

  Widget _buildCapturePreviewContent() {
    final raspberryPiIp = _raspberryPiIp?.trim();
    final latestPoseImageUrl = _isRecording ? _latestInferenceFrame?.poseImageUrl : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        _PiPreviewSocketView(
          raspberryPiIp: raspberryPiIp,
          port: BackendConfig.defaultPiPreviewSocketPort,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.08),
                AppColors.background.withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
        if (latestPoseImageUrl != null)
          Positioned.fill(
            child: _LivePoseOverlay(
              imageUrl: latestPoseImageUrl,
              refreshTick: _previewRefreshTick,
            ),
          ),
        if (_isRecording)
          Positioned(
            right: 16,
            bottom: 110,
            child: _InferenceOverlay(
              frame: _latestInferenceFrame,
              message: _liveInferenceMessage,
              session: _liveResultSession,
              refreshTick: _previewRefreshTick,
            ),
          ),
      ],
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
                title: _isRecording
                    ? 'Raspberry Pi Live Camera + Inference'
                    : 'Raspberry Pi Live Camera',
                subtitle: _isRecording
                    ? 'The full Pi camera feed stays live while the newest processed frame is surfaced on top.'
                    : 'The Raspberry Pi preview stays embedded here even before you start capture.',
                statusLabel: _isRecording ? 'Recording' : 'Preview',
                footerLabel: 'Tracking',
                footerValue: _isRecording
                    ? (_liveResultSession == null
                        ? 'AI booting'
                        : '${_liveResultSession!.frameCount} frames')
                    : 'Pi Live',
                timerLabel: timerLabel,
                isRecording: _isRecording,
                previewContent: _buildCapturePreviewContent(),
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
                      ? () {
                          _startRecording();
                        }
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

class _PreviewPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PreviewPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundSecondary,
            AppColors.surface,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.h3.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13.5,
                  height: 1.3,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PiPreviewSocketView extends StatefulWidget {
  final String? raspberryPiIp;
  final int port;

  const _PiPreviewSocketView({
    required this.raspberryPiIp,
    required this.port,
  });

  @override
  State<_PiPreviewSocketView> createState() => _PiPreviewSocketViewState();
}

class _PiPreviewSocketViewState extends State<_PiPreviewSocketView> {
  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSubscription;
  Timer? _reconnectTimer;
  final List<int> _buffer = <int>[];
  Uint8List? _frameBytes;
  bool _isConnecting = false;
  bool _handshakeComplete = false;
  String? _statusMessage;
  int _reconnectAttempt = 0;

  @override
  void initState() {
    super.initState();
    _connectIfPossible();
  }

  @override
  void didUpdateWidget(covariant _PiPreviewSocketView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raspberryPiIp != widget.raspberryPiIp || oldWidget.port != widget.port) {
      _resetConnection();
      _connectIfPossible();
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _closeSocket();
    super.dispose();
  }

  void _connectIfPossible() {
    final raspberryPiIp = widget.raspberryPiIp?.trim();
    if (raspberryPiIp == null || raspberryPiIp.isEmpty) {
      setState(() {
        _statusMessage = 'Set the Raspberry Pi IP in Settings so the app can open the live preview socket.';
      });
      return;
    }

    _connect();
  }

  Future<void> _connect() async {
    if (_isConnecting || _socket != null) {
      return;
    }

    final raspberryPiIp = widget.raspberryPiIp?.trim();
    if (raspberryPiIp == null || raspberryPiIp.isEmpty) {
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to the Raspberry Pi preview socket...';
    });

    try {
      final socket = await Socket.connect(
        raspberryPiIp,
        widget.port,
        timeout: const Duration(seconds: 2),
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      unawaited(socket.done.catchError((Object _) {}));
      socket.add(utf8.encode('POSETRACK_PREVIEW 1\n'));
      await socket.flush();

      _socket = socket;
      _socketSubscription = socket.listen(
        _handleSocketData,
        onDone: _handleSocketDisconnected,
        onError: _handleSocketError,
        cancelOnError: true,
      );

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _reconnectAttempt = 0;
          _statusMessage = 'Connected to the Pi preview socket. Waiting for the first frame...';
        });
      }
    } on SocketException {
      _handlePreviewFailure(
        _frameBytes == null
            ? 'Preview socket unavailable.'
            : 'Preview link interrupted.',
      );
    } on TimeoutException {
      _handlePreviewFailure(
        _frameBytes == null
            ? 'Preview socket timed out before the first frame arrived.'
            : 'Preview stream timed out.',
      );
    }
  }

  void _handleSocketData(Uint8List data) {
    _buffer.addAll(data);

    while (true) {
      if (!_handshakeComplete) {
        final newlineIndex = _buffer.indexOf(10);
        if (newlineIndex == -1) {
          return;
        }

        final line = utf8.decode(_buffer.sublist(0, newlineIndex)).trim();
        _buffer.removeRange(0, newlineIndex + 1);

        if (line != 'POSETRACK_PREVIEW_OK') {
          _handlePreviewFailure('Unexpected preview handshake response: $line');
          return;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _handshakeComplete = true;
          _statusMessage = 'Preview socket connected. Waiting for the first camera frame...';
        });
      }

      if (_buffer.length < 4) {
        return;
      }

      final length = (_buffer[0] << 24) |
          (_buffer[1] << 16) |
          (_buffer[2] << 8) |
          _buffer[3];

      if (_buffer.length < 4 + length) {
        return;
      }

      final frameBytes = Uint8List.fromList(_buffer.sublist(4, 4 + length));
      _buffer.removeRange(0, 4 + length);

      if (!mounted) {
        return;
      }

      setState(() {
        _frameBytes = frameBytes;
        _reconnectAttempt = 0;
        _statusMessage = null;
      });
    }
  }

  void _handleSocketDisconnected() {
    _handlePreviewFailure('Preview socket disconnected. Reconnecting to the Raspberry Pi...');
  }

  void _handleSocketError(Object error) {
    _handlePreviewFailure('Preview socket error.');
  }

  void _handlePreviewFailure(String message) {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _closeSocket();

    if (!mounted) {
      return;
    }

    final reconnectDelay = _nextReconnectDelay();
    setState(() {
      _isConnecting = false;
      _handshakeComplete = false;
      _statusMessage = '$message Reconnecting in ${reconnectDelay.inSeconds}s...';
    });

    _scheduleReconnect(reconnectDelay);
  }

  Duration _nextReconnectDelay() {
    _reconnectAttempt += 1;
    if (_reconnectAttempt <= 1) {
      return const Duration(seconds: 1);
    }
    if (_reconnectAttempt == 2) {
      return const Duration(seconds: 2);
    }
    if (_reconnectAttempt == 3) {
      return const Duration(seconds: 4);
    }
    if (_reconnectAttempt == 4) {
      return const Duration(seconds: 8);
    }
    return const Duration(seconds: 12);
  }

  void _scheduleReconnect(Duration delay) {
    if (_reconnectTimer != null) {
      return;
    }

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _connectIfPossible();
    });
  }

  void _resetConnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _closeSocket();
    _buffer.clear();
    _frameBytes = null;
    _isConnecting = false;
    _handshakeComplete = false;
    _reconnectAttempt = 0;
    _statusMessage = null;
  }

  void _closeSocket() {
    final socket = _socket;
    _socket = null;
    if (socket == null) {
      return;
    }

    try {
      socket.destroy();
    } catch (_) {
      // Ignore socket shutdown errors during reconnect/dispose.
    }
  }

  @override
  Widget build(BuildContext context) {
    final raspberryPiIp = widget.raspberryPiIp?.trim();
    if (raspberryPiIp == null || raspberryPiIp.isEmpty) {
      return const _PreviewPlaceholder(
        icon: Icons.videocam_off_rounded,
        title: 'Preview unavailable',
        message:
            'Set the Raspberry Pi IP in Settings so the app can open the live preview socket.',
      );
    }

    if (_frameBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _frameBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
          if (_statusMessage != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        _isConnecting ? Icons.sync_rounded : Icons.wifi_tethering_error_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _PreviewPlaceholder(
          icon: _isConnecting ? Icons.wifi_tethering_rounded : Icons.wifi_find_rounded,
          title: _isConnecting ? 'Connecting to Pi preview' : 'Waiting for Pi preview',
          message: _statusMessage ??
              'The Raspberry Pi preview socket has not delivered the first frame yet.',
        ),
        if (_isConnecting)
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
      ],
    );
  }
}

class _LivePoseOverlay extends StatelessWidget {
  final String imageUrl;
  final int refreshTick;

  const _LivePoseOverlay({
    required this.imageUrl,
    required this.refreshTick,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: 0.94,
            duration: const Duration(milliseconds: 220),
            child: Image.network(
              '$imageUrl?tick=$refreshTick',
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
          Positioned(
            top: 56,
            left: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.28),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_graph_rounded,
                      color: AppColors.success,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Overlay Live',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InferenceOverlay extends StatelessWidget {
  final ResultFrameItem? frame;
  final ResultSessionDetail? session;
  final String? message;
  final int refreshTick;

  const _InferenceOverlay({
    required this.frame,
    required this.session,
    required this.message,
    required this.refreshTick,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = frame?.poseImageUrl;
    final chipLabel = frame == null ? 'AI waiting' : 'Inference F${frame!.frameId}';
    final bodyMessage = message ??
        (frame == null
            ? 'Waiting for the worker to produce the first processed frame.'
            : 'The latest processed pose frame is shown here.');

    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (session != null)
                Text(
                  '${session!.frameCount}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: imageUrl == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_graph_rounded,
                          color: AppColors.textMuted,
                          size: 24,
                        ),
                      ),
                    )
                  : Image.network(
                      '$imageUrl?tick=$refreshTick',
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bodyMessage,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
