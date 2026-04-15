import '../utils/app_formatters.dart';

enum CaptureMode { image, video }

extension CaptureModeX on CaptureMode {
  String get label => switch (this) {
    CaptureMode.image => 'Image',
    CaptureMode.video => 'Video',
  };

  String get actionLabel => switch (this) {
    CaptureMode.image => 'Capture Image',
    CaptureMode.video => 'Start Recording',
  };
}

enum SessionState { completed, processing, failed }

class PoseTrackSettings {
  final String raspberryPiIp;
  final String serverAddress;
  final CaptureMode defaultMode;
  final int defaultDurationSeconds;
  final bool autoUpload;

  const PoseTrackSettings({
    required this.raspberryPiIp,
    required this.serverAddress,
    required this.defaultMode,
    required this.defaultDurationSeconds,
    required this.autoUpload,
  });

  PoseTrackSettings copyWith({
    String? raspberryPiIp,
    String? serverAddress,
    CaptureMode? defaultMode,
    int? defaultDurationSeconds,
    bool? autoUpload,
  }) {
    return PoseTrackSettings(
      raspberryPiIp: raspberryPiIp ?? this.raspberryPiIp,
      serverAddress: serverAddress ?? this.serverAddress,
      defaultMode: defaultMode ?? this.defaultMode,
      defaultDurationSeconds:
          defaultDurationSeconds ?? this.defaultDurationSeconds,
      autoUpload: autoUpload ?? this.autoUpload,
    );
  }
}

class CaptureSessionDraft {
  final String sessionId;
  final CaptureMode mode;
  final int targetDurationSeconds;
  final int actualDurationSeconds;
  final DateTime capturedAt;
  final bool autoUpload;
  final String raspberryPiIp;
  final String serverAddress;

  const CaptureSessionDraft({
    required this.sessionId,
    required this.mode,
    required this.targetDurationSeconds,
    required this.actualDurationSeconds,
    required this.capturedAt,
    required this.autoUpload,
    required this.raspberryPiIp,
    required this.serverAddress,
  });
}

class ProcessingStage {
  final String title;
  final String description;

  const ProcessingStage({
    required this.title,
    required this.description,
  });
}

class PoseAnalysisResult {
  final String sessionId;
  final String title;
  final CaptureMode mode;
  final DateTime capturedAt;
  final int durationSeconds;
  final int keypointsDetected;
  final int keypointsTotal;
  final double confidence;
  final String statusMessage;
  final String feedback;
  final String analysisNote;
  final String deviceNode;
  final String serverNode;

  const PoseAnalysisResult({
    required this.sessionId,
    required this.title,
    required this.mode,
    required this.capturedAt,
    required this.durationSeconds,
    required this.keypointsDetected,
    required this.keypointsTotal,
    required this.confidence,
    required this.statusMessage,
    required this.feedback,
    required this.analysisNote,
    required this.deviceNode,
    required this.serverNode,
  });
}

class PoseHistorySession {
  final String sessionId;
  final String title;
  final DateTime capturedAt;
  final SessionState state;
  final CaptureMode mode;
  final double confidence;
  final int durationSeconds;
  final String summary;
  final int keypointsDetected;
  final int keypointsTotal;

  const PoseHistorySession({
    required this.sessionId,
    required this.title,
    required this.capturedAt,
    required this.state,
    required this.mode,
    required this.confidence,
    required this.durationSeconds,
    required this.summary,
    required this.keypointsDetected,
    required this.keypointsTotal,
  });

  PoseAnalysisResult toResult() {
    return PoseAnalysisResult(
      sessionId: sessionId,
      title: title,
      mode: mode,
      capturedAt: capturedAt,
      durationSeconds: durationSeconds,
      keypointsDetected: keypointsDetected,
      keypointsTotal: keypointsTotal,
      confidence: confidence,
      statusMessage: switch (state) {
        SessionState.completed => 'Pose detected successfully',
        SessionState.processing => 'Processing session in progress',
        SessionState.failed => 'Processing needs another pass',
      },
      feedback: summary,
      analysisNote: switch (state) {
        SessionState.completed =>
          'Server-side pose estimation completed with stable landmark extraction.',
        SessionState.processing =>
          'This session is still moving through the AI processing pipeline.',
        SessionState.failed =>
          'Frame quality or alignment likely reduced the confidence of the result.',
      },
      deviceNode: 'Raspberry Pi 4B',
      serverNode: 'FastAPI Pose Server',
    );
  }
}

class MockPoseTrackingService {
  MockPoseTrackingService._();

  static final MockPoseTrackingService _instance = MockPoseTrackingService._();

  factory MockPoseTrackingService() => _instance;

  PoseTrackSettings _settings = const PoseTrackSettings(
    raspberryPiIp: '192.168.1.24',
    serverAddress: '192.168.1.10:8000',
    defaultMode: CaptureMode.video,
    defaultDurationSeconds: 10,
    autoUpload: true,
  );

  final List<PoseHistorySession> _history = <PoseHistorySession>[
    PoseHistorySession(
      sessionId: 'PT-260414-1426',
      title: 'Standing Pose Calibration',
      capturedAt: DateTime(2026, 4, 14, 14, 26),
      state: SessionState.completed,
      mode: CaptureMode.video,
      confidence: 0.984,
      durationSeconds: 12,
      summary:
          'Pose detected successfully with balanced shoulders and stable hip alignment.',
      keypointsDetected: 17,
      keypointsTotal: 17,
    ),
    PoseHistorySession(
      sessionId: 'PT-260414-1038',
      title: 'Arm Raise Diagnostic',
      capturedAt: DateTime(2026, 4, 14, 10, 38),
      state: SessionState.processing,
      mode: CaptureMode.video,
      confidence: 0.941,
      durationSeconds: 8,
      summary:
          'Upload finished. The server is extracting frames and preparing the pose sequence.',
      keypointsDetected: 15,
      keypointsTotal: 17,
    ),
    PoseHistorySession(
      sessionId: 'PT-260413-1708',
      title: 'Single Frame Balance Check',
      capturedAt: DateTime(2026, 4, 13, 17, 8),
      state: SessionState.failed,
      mode: CaptureMode.image,
      confidence: 0.714,
      durationSeconds: 0,
      summary:
          'Low light caused a weak silhouette. Re-capturing with a cleaner frame is recommended.',
      keypointsDetected: 12,
      keypointsTotal: 17,
    ),
  ];

  PoseAnalysisResult? _latestResult;

  Future<PoseTrackSettings> getSettings() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _settings.copyWith();
  }

  Future<void> saveSettings(PoseTrackSettings settings) async {
    await Future.delayed(const Duration(milliseconds: 180));
    _settings = settings;
  }

  Future<CaptureSessionDraft> createCaptureDraft({
    required CaptureMode mode,
    required int targetDurationSeconds,
    required int actualDurationSeconds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final capturedAt = DateTime.now();

    return CaptureSessionDraft(
      sessionId: buildSessionId(capturedAt),
      mode: mode,
      targetDurationSeconds: targetDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      capturedAt: capturedAt,
      autoUpload: _settings.autoUpload,
      raspberryPiIp: _settings.raspberryPiIp,
      serverAddress: _settings.serverAddress,
    );
  }

  List<ProcessingStage> getProcessingStages(CaptureSessionDraft draft) {
    return const [
      ProcessingStage(
        title: 'Uploading Video',
        description:
            'Pushing the capture package from mobile to the server queue.',
      ),
      ProcessingStage(
        title: 'Saving to Server',
        description:
            'Creating a session workspace and validating storage metadata.',
      ),
      ProcessingStage(
        title: 'Extracting Frames',
        description: 'Preparing RGB frames for downstream pose estimation.',
      ),
      ProcessingStage(
        title: 'Running Pose Estimation',
        description:
            'Executing the pose model and confidence aggregation pipeline.',
      ),
      ProcessingStage(
        title: 'Generating Results',
        description:
            'Packaging overlays, metrics, and posture feedback for the app.',
      ),
    ];
  }

  Future<PoseAnalysisResult> finalizeCapture(CaptureSessionDraft draft) async {
    await Future.delayed(const Duration(milliseconds: 220));

    final confidence = switch (draft.mode) {
      CaptureMode.image => 0.978,
      CaptureMode.video => draft.actualDurationSeconds >= 10 ? 0.986 : 0.951,
    };

    final title = switch (draft.mode) {
      CaptureMode.image => 'Single Frame Pose Snapshot',
      CaptureMode.video => 'Motion Sequence Pose Session',
    };

    final feedback = switch (draft.mode) {
      CaptureMode.image =>
        'Pose detected successfully. The skeleton landmarks are crisp and ready for inspection.',
      CaptureMode.video =>
        'Pose sequence captured cleanly. Motion flow and joint tracking remain stable across the clip.',
    };

    final result = PoseAnalysisResult(
      sessionId: draft.sessionId,
      title: title,
      mode: draft.mode,
      capturedAt: draft.capturedAt,
      durationSeconds: draft.actualDurationSeconds,
      keypointsDetected: 17,
      keypointsTotal: 17,
      confidence: confidence,
      statusMessage: 'Pose detected successfully',
      feedback: feedback,
      analysisNote:
          'Raspberry Pi capture and server-side inference completed with consistent landmark confidence and clean overlay generation.',
      deviceNode: 'Raspberry Pi 4B (${draft.raspberryPiIp})',
      serverNode: 'FastAPI Pose Server (${draft.serverAddress})',
    );

    _latestResult = result;
    _history.insert(
      0,
      PoseHistorySession(
        sessionId: draft.sessionId,
        title: title,
        capturedAt: draft.capturedAt,
        state: SessionState.completed,
        mode: draft.mode,
        confidence: confidence,
        durationSeconds: draft.actualDurationSeconds,
        summary: feedback,
        keypointsDetected: 17,
        keypointsTotal: 17,
      ),
    );

    return result;
  }

  Future<PoseAnalysisResult> getLatestResult() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _latestResult ?? _history.first.toResult();
  }

  Future<List<PoseHistorySession>> getHistory() async {
    await Future.delayed(const Duration(milliseconds: 120));
    return List<PoseHistorySession>.from(_history);
  }
}
