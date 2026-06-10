import 'dart:async';

import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/option_chip.dart';
import '../components/pi_preview_socket_view.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/pose_visualization_card.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../config/backend_config.dart';
import '../models/preview_frame_metadata.dart';
import '../models/result_models.dart';
import '../navigation/app_routes.dart';
import '../services/api_service.dart';
import '../services/mock_pose_tracking_service.dart';
import '../services/realtime_ws_service.dart';
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
  final RealtimeWsService _realtimeService = RealtimeWsService();
  StreamSubscription<FrameResultDetail>? _realtimeSubscription;
  StreamSubscription<FrameResultDetail>? _idleSubscription;
  ResultSessionDetail? _liveResultSession;
  ResultFrameItem? _latestInferenceFrame;
  FrameResultDetail? _latestInferenceDetail;
  PreviewFrameMetadata? _latestPreviewFrameMetadata;
  String? _liveInferenceMessage;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
    _startIdleInferencePolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtimeSubscription?.cancel();
    _idleSubscription?.cancel();
    _realtimeService.disconnect();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    final settings = await _api.getSettings();
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

  void _startInferencePolling(CaptureSessionDraft draft) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _realtimeService.subscribe(draft.sessionId).listen(
      (detail) {
        if (!mounted) return;
        setState(() {
          _latestInferenceDetail = detail;
          _liveInferenceMessage = detail.formTracking != null
              ? 'Frame ${detail.frameId}: ${detail.formTracking!.status} - ${detail.formTracking!.message}'
              : detail.poseOverlay?.hasDetections == true
                  ? 'Frame ${detail.frameId}: ${detail.poseOverlay!.detections.length} pose detection(s) live.'
                  : 'Frame ${detail.frameId} is ready.';
        });
      },
      onError: (error) {
        print('Realtime WS Stream Error: $error');
      },
    );
  }

  void _stopInferencePolling() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeService.disconnect();
  }

  void _startIdleInferencePolling() {
    _idleSubscription?.cancel();
    _idleSubscription = _realtimeService.subscribe('idle_preview').listen(
      (detail) {
        if (!mounted || _isRecording) return;
        setState(() {
          _latestInferenceDetail = detail;
          _liveInferenceMessage = detail.formTracking != null
              ? 'Idle Frame ${detail.frameId}: ${detail.formTracking!.status} - ${detail.formTracking!.message}'
              : detail.poseOverlay?.hasDetections == true
                  ? 'Idle Frame ${detail.frameId}: ${detail.poseOverlay!.detections.length} pose detection(s) live.'
                  : 'Idle Frame ${detail.frameId} is ready.';
        });
      },
      onError: (error) {
        print('Realtime Idle WS Stream Error: $error');
      },
    );
  }

  void _stopIdleInferencePolling() {
    _idleSubscription?.cancel();
    _idleSubscription = null;
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
        _latestInferenceDetail = null;
        _latestPreviewFrameMetadata = null;
        _liveInferenceMessage = 'Waiting for the worker to produce the first inference frame...';
      });
      _stopIdleInferencePolling();
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
        _latestInferenceDetail = null;
        _latestPreviewFrameMetadata = null;
      });
      _startIdleInferencePolling();

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
    final settings = await _api.getSettings();
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
    final commandPayload = <String, Object>{
      'frames_dir': BackendConfig.defaultPiFramesDir,
      'zmq_host': _resolveZmqHost(settings.serverAddress),
      'zmq_port': BackendConfig.defaultZmqPort,
      'capture_source': 'auto',
      'capture_mode': mode.name,
      'target_duration_seconds': targetDurationSeconds,
      'actual_duration_seconds': actualDurationSeconds,
      'source': 'mobile_app',
    };
    if (mode == CaptureMode.video) {
      commandPayload['camera_fps'] = 8;
      commandPayload['camera_width'] = 640;
      commandPayload['camera_height'] = 480;
    }
    final command = await _api.createDeviceCommand(
      deviceId: captureDevice.id,
      sessionId: session.sessionId,
      commandType: commandType,
      commandPayload: commandPayload,
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
    final livePoseDetail = _latestInferenceDetail;
    final shouldRenderLiveOverlay = _shouldRenderLivePoseOverlay(livePoseDetail);
    final overlayMessage = _buildLiveOverlayMessage(livePoseDetail);

    return Stack(
      fit: StackFit.expand,
      children: [
        PiPreviewSocketView(
          raspberryPiIp: raspberryPiIp,
          port: BackendConfig.defaultPiPreviewSocketPort,
          onMetadataChanged: _handlePreviewFrameMetadataChanged,
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
        if (shouldRenderLiveOverlay) ...[
          Positioned.fill(
            child: _LivePoseMetadataOverlay(
              detail: livePoseDetail!,
            ),
          ),
          const Positioned(
            top: 24,
            left: 24,
            child: StatusBadge(
              label: 'SYNCED',
              color: AppColors.success,
              icon: Icons.bolt,
            ),
          ),
        ],
        if (_isRecording)
          Positioned(
            right: 16,
            bottom: 110,
            child: _InferenceOverlay(
              frame: _latestInferenceFrame,
              detail: _latestInferenceDetail,
              message: overlayMessage,
              session: _liveResultSession,
            ),
          ),
      ],
    );
  }

  void _handlePreviewFrameMetadataChanged(PreviewFrameMetadata? metadata) {
    if (!mounted) {
      return;
    }

    final current = _latestPreviewFrameMetadata;
    final isSameMetadata = current?.frameId == metadata?.frameId &&
        current?.sessionId == metadata?.sessionId &&
        current?.mode == metadata?.mode;
    if (isSameMetadata) {
      return;
    }

    setState(() {
      _latestPreviewFrameMetadata = metadata;
    });
  }

  bool _shouldRenderLivePoseOverlay(FrameResultDetail? detail) {
    if (detail == null) {
      return false;
    }

    final overlay = detail.poseOverlay;
    if (overlay == null || !overlay.hasDetections) {
      return false;
    }

    final previewMetadata = _latestPreviewFrameMetadata;
    if (previewMetadata == null) {
      return false;
    }

    if (_isRecording && !previewMetadata.isRecordingPreview) {
      return false;
    }
    if (!_isRecording && previewMetadata.mode != 'idle_preview') {
      return false;
    }

    if (previewMetadata.sessionId != null && previewMetadata.sessionId != detail.sessionId) {
      return false;
    }

    final previewFrameId = previewMetadata.frameId;
    if (previewFrameId == null) {
      return false;
    }

    final maxDiff = previewMetadata.mode == 'idle_preview' ? 5 : 1;
    return (previewFrameId - detail.frameId).abs() <= maxDiff;
  }

  String? _buildLiveOverlayMessage(FrameResultDetail? detail) {
    if (!_isRecording) {
      return _liveInferenceMessage;
    }

    if (detail == null) {
      return _liveInferenceMessage;
    }

    final previewMetadata = _latestPreviewFrameMetadata;
    if (previewMetadata == null || !previewMetadata.isRecordingPreview) {
      return 'Preview live, AI syncing...';
    }

    if (previewMetadata.sessionId != null && previewMetadata.sessionId != detail.sessionId) {
      return 'Preview live, waiting for the current session overlay...';
    }

    final previewFrameId = previewMetadata.frameId;
    if (previewFrameId == null) {
      return 'Preview live, AI syncing...';
    }

    final frameDiff = (previewFrameId - detail.frameId).abs();
    if (frameDiff > 1) {
      return 'Preview live, AI syncing frame ${detail.frameId}...';
    }

    return _liveInferenceMessage;
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

class _LivePoseMetadataOverlay extends StatelessWidget {
  final FrameResultDetail detail;

  const _LivePoseMetadataOverlay({
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final overlay = detail.poseOverlay;
    if (overlay == null || !overlay.hasDetections) {
      return const SizedBox.shrink();
    }
    final tracking = detail.formTracking;
    final primaryDetection = overlay.primaryDetection;
    final status = tracking?.status ?? primaryDetection?.formStatus ?? 'UNKNOWN';
    final statusColor = _formStatusColor(status);
    final statusLabel = tracking != null || primaryDetection?.formStatus != null
        ? 'Form ${_formStatusShortLabel(status)}'
        : 'AI Overlay Live';

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _LivePosePainter(overlay: overlay),
          ),
          Positioned(
            top: 56,
            left: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.28),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      color: statusColor,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
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
  final FrameResultDetail? detail;
  final ResultSessionDetail? session;
  final String? message;

  const _InferenceOverlay({
    required this.frame,
    required this.detail,
    required this.session,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final chipLabel = frame == null ? 'AI waiting' : 'Inference F${frame!.frameId}';
    final overlay = detail?.poseOverlay;
    final tracking = detail?.formTracking;
    final firstDetection = overlay?.primaryDetection;
    final status = tracking?.status ?? firstDetection?.formStatus ?? 'UNKNOWN';
    final accent = _formStatusColor(status);
    final bodyMessage = tracking?.message ??
        firstDetection?.formFeedback ??
        message ??
        (frame == null
            ? 'Waiting for the worker to produce the first processed frame.'
            : 'The frontend is now rendering pose metadata directly on top of the Pi preview.');

    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
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
                  color: accent.withValues(alpha: 0.14),
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
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniMetricChip(
                label: 'Det',
                value: '${overlay?.detections.length ?? 0}',
                accent: accent,
              ),
              _MiniMetricChip(
                label: 'Form',
                value: _formStatusShortLabel(status),
                accent: accent,
              ),
              if (tracking != null)
                _MiniMetricChip(
                  label: 'Rep',
                  value: '${tracking.repCount}',
                  accent: accent,
                ),
              if (tracking?.stage != null)
                _MiniMetricChip(
                  label: 'Stage',
                  value: tracking!.stage!,
                  accent: accent,
                ),
              if (tracking?.kneeMin != null)
                _MiniMetricChip(
                  label: 'Min K',
                  value: tracking!.kneeMin!.toStringAsFixed(0),
                  accent: accent,
                ),
              if (firstDetection != null && firstDetection.angles['knee'] != null && tracking?.kneeMin == null)
                _MiniMetricChip(
                  label: 'Knee',
                  value: firstDetection.angles['knee']!.toStringAsFixed(0),
                  accent: accent,
                ),
              if (firstDetection != null && firstDetection.angles['hip'] != null)
                _MiniMetricChip(
                  label: 'Hip',
                  value: firstDetection.angles['hip']!.toStringAsFixed(0),
                  accent: accent,
                ),
            ],
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

class _MiniMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MiniMetricChip({
    required this.label,
    required this.value,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '$label $value',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LivePosePainter extends CustomPainter {
  final PoseOverlayData overlay;

  const _LivePosePainter({
    required this.overlay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bboxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.35);

    for (final detection in overlay.detections) {
      final accent = _formStatusColor(detection.formStatus);
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.92);

      final pointPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: 0.96);

      final points = detection.normalizedKeypoints;
      if (points.isEmpty) {
        continue;
      }

      final bbox = detection.bboxNormalized;
      if (bbox != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              bbox.x1 * size.width,
              bbox.y1 * size.height,
              bbox.x2 * size.width,
              bbox.y2 * size.height,
            ),
            const Radius.circular(12),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = bboxPaint.strokeWidth
            ..color = accent.withValues(alpha: 0.76),
        );
        _paintStatusText(
          canvas,
          size,
          _formStatusShortLabel(detection.formStatus),
          anchor: Offset(
            bbox.x1 * size.width,
            bbox.y1 * size.height - 18,
          ),
          accent: accent,
        );
      }

      for (final edge in overlay.skeletonEdges) {
        final startIndex = edge[0];
        final endIndex = edge[1];
        if (startIndex >= points.length || endIndex >= points.length) {
          continue;
        }

        final start = Offset(
          points[startIndex].x * size.width,
          points[startIndex].y * size.height,
        );
        final end = Offset(
          points[endIndex].x * size.width,
          points[endIndex].y * size.height,
        );
        canvas.drawLine(start, end, linePaint);
      }

      for (final point in points) {
        canvas.drawCircle(
          Offset(point.x * size.width, point.y * size.height),
          4.2,
          pointPaint,
        );
      }

      final kneeIndex = detection.sideUsed == 'left' ? 13 : 14;
      final hipIndex = detection.sideUsed == 'left' ? 11 : 12;

      _paintAngleText(
        canvas,
        size,
        points,
        'K ${detection.angles['knee']?.toStringAsFixed(0) ?? '-'}',
        index: kneeIndex,
      );
      _paintAngleText(
        canvas,
        size,
        points,
        'H ${detection.angles['hip']?.toStringAsFixed(0) ?? '-'}',
        index: hipIndex,
      );
    }
  }

  void _paintAngleText(
    Canvas canvas,
    Size size,
    List<PosePoint> points,
    String text, {
    required int index,
  }) {
    if (index >= points.length) {
      return;
    }

    final point = points[index];
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      (point.x * size.width).clamp(0.0, size.width - textPainter.width),
      (point.y * size.height - 20).clamp(0.0, size.height - textPainter.height),
    );

    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      background,
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
    textPainter.paint(canvas, offset);
  }

  void _paintStatusText(
    Canvas canvas,
    Size size,
    String text, {
    required Offset anchor,
    required Color accent,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      anchor.dx.clamp(0.0, size.width - textPainter.width),
      anchor.dy.clamp(0.0, size.height - textPainter.height),
    );

    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      background,
      Paint()..color = accent.withValues(alpha: 0.72),
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LivePosePainter oldDelegate) {
    return oldDelegate.overlay != overlay;
  }
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

String _formStatusShortLabel(String? status) {
  switch (status) {
    case 'GOOD_FORM':
      return 'GOOD';
    case 'BAD_FORM':
      return 'BAD';
    default:
      return 'UNKNOWN';
  }
}
