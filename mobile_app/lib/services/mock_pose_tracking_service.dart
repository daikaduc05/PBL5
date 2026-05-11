import 'dart:convert';
import 'dart:io';

import '../config/backend_config.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'raspberry_pi_ip': raspberryPiIp,
      'server_address': serverAddress,
      'default_mode': defaultMode.name,
      'default_duration_seconds': defaultDurationSeconds,
      'auto_upload': autoUpload,
    };
  }

  factory PoseTrackSettings.fromJson(Map<String, dynamic> json) {
    return PoseTrackSettings(
      raspberryPiIp: json['raspberry_pi_ip'] as String? ?? '192.168.1.24',
      serverAddress:
          json['server_address'] as String? ??
          BackendConfig.defaultServerAddress,
      defaultMode: _parseCaptureMode(json['default_mode']),
      defaultDurationSeconds: _parseDurationSeconds(
        json['default_duration_seconds'],
      ),
      autoUpload: json['auto_upload'] as bool? ?? true,
    );
  }
}

class CaptureSessionDraft {
  final String sessionId;
  final int? backendSessionId;
  final int? deviceId;
  final int? commandId;
  final CaptureMode mode;
  final int targetDurationSeconds;
  final int actualDurationSeconds;
  final DateTime capturedAt;
  final bool autoUpload;
  final String raspberryPiIp;
  final String serverAddress;

  const CaptureSessionDraft({
    required this.sessionId,
    this.backendSessionId,
    this.deviceId,
    this.commandId,
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

  const ProcessingStage({required this.title, required this.description});
}

// ---------------------------------------------------------------------------
// SettingsService – singleton that persists user-configured settings locally.
// Named MockPoseTrackingService for backward-compat with existing imports.
// ---------------------------------------------------------------------------

// ignore: avoid_classes_with_only_static_members
class MockPoseTrackingService {
  MockPoseTrackingService._();

  static final MockPoseTrackingService _instance = MockPoseTrackingService._();

  factory MockPoseTrackingService() => _instance;

  Future<void>? _settingsLoadFuture;

  PoseTrackSettings _settings = const PoseTrackSettings(
    raspberryPiIp: '192.168.1.24',
    serverAddress: BackendConfig.defaultServerAddress,
    defaultMode: CaptureMode.video,
    defaultDurationSeconds: 10,
    autoUpload: true,
  );

  Future<PoseTrackSettings> getSettings() async {
    await _ensureSettingsLoaded();
    await Future.delayed(const Duration(milliseconds: 120));
    return _settings.copyWith();
  }

  Future<void> saveSettings(PoseTrackSettings settings) async {
    await _ensureSettingsLoaded();
    await Future.delayed(const Duration(milliseconds: 180));
    _settings = settings;
    await _persistSettings();
  }

  Future<void> _ensureSettingsLoaded() {
    return _settingsLoadFuture ??= _loadStoredSettings();
  }

  Future<void> _loadStoredSettings() async {
    try {
      final file = _settingsFile;
      if (!await file.exists()) {
        return;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _settings = PoseTrackSettings.fromJson(decoded);
      }
    } catch (_) {
      // Fall back to in-memory defaults when local persistence is unavailable.
    }
  }

  Future<void> _persistSettings() async {
    try {
      final file = _settingsFile;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_settings.toJson()), flush: true);
    } catch (_) {
      // Keep the updated in-memory settings even if file persistence fails.
    }
  }

  File get _settingsFile {
    final separator = Platform.pathSeparator;

    if (Platform.isWindows) {
      final root =
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      return File('$root${separator}PoseTrack${separator}settings.json');
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      return File(
        '$home${separator}Library${separator}Application Support${separator}PoseTrack${separator}settings.json',
      );
    }

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      return File(
        '$home$separator.config${separator}posetrack${separator}settings.json',
      );
    }

    return File(
      '${Directory.systemTemp.path}${separator}posetrack_settings.json',
    );
  }
}

CaptureMode _parseCaptureMode(Object? value) {
  final rawValue = value as String?;
  return switch (rawValue) {
    'image' => CaptureMode.image,
    'video' => CaptureMode.video,
    _ => CaptureMode.video,
  };
}

int _parseDurationSeconds(Object? value) {
  if (value is int && value > 0) {
    return value;
  }

  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }

  return 10;
}
