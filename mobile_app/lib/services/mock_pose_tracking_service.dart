import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
//
// Dùng shared_preferences để lưu settings:
//   - Web   : localStorage (tự động bởi shared_preferences)
//   - Android    : SharedPreferences
//   - iOS        : NSUserDefaults
//   - Windows    : Registry / local file
// ---------------------------------------------------------------------------

class MockPoseTrackingService {
  MockPoseTrackingService._();

  static final MockPoseTrackingService _instance = MockPoseTrackingService._();

  factory MockPoseTrackingService() => _instance;

  Future<void>? _settingsLoadFuture;

  static const String _kSettingsKey = 'posetrack_settings_v1';

  // Không dùng const vì defaultServerAddress là getter runtime (kIsWeb)
  PoseTrackSettings _settings = PoseTrackSettings(
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSettingsKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _settings = PoseTrackSettings.fromJson(decoded);
      }
    } catch (_) {
      // Fall back to in-memory defaults when persistence is unavailable.
    }
  }

  Future<void> _persistSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSettingsKey, jsonEncode(_settings.toJson()));
    } catch (_) {
      // Keep the updated in-memory settings even if persistence fails.
    }
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
