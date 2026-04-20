import 'dart:convert';
import 'dart:io';

import 'mock_pose_tracking_service.dart';

/// Exception thrown by [ApiService] on HTTP or network errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// ─── Response models ────────────────────────────────────────────────────────

class DeviceInfo {
  final int id;
  final String deviceName;
  final String deviceCode;
  final String status;

  const DeviceInfo({
    required this.id,
    required this.deviceName,
    required this.deviceCode,
    required this.status,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    id: json['id'] as int,
    deviceName: json['device_name'] as String,
    deviceCode: json['device_code'] as String,
    status: json['status'] as String? ?? 'unknown',
  );
}

class HistoryItem {
  final int jobId;
  final String status;
  final String taskType;
  final int progress;
  final DateTime createdAt;

  const HistoryItem({
    required this.jobId,
    required this.status,
    required this.taskType,
    required this.progress,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    jobId: json['job_id'] as int,
    status: json['status'] as String,
    taskType: json['task_type'] as String,
    progress: json['progress'] as int? ?? 0,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

class HistoryDetail {
  final int jobId;
  final String status;
  final String taskType;
  final int progress;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const HistoryDetail({
    required this.jobId,
    required this.status,
    required this.taskType,
    required this.progress,
    required this.errorMessage,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
  });

  factory HistoryDetail.fromJson(Map<String, dynamic> json) => HistoryDetail(
    jobId: json['job_id'] as int,
    status: json['status'] as String,
    taskType: json['task_type'] as String,
    progress: json['progress'] as int? ?? 0,
    errorMessage: json['error_message'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    startedAt: json['started_at'] != null
        ? DateTime.tryParse(json['started_at'] as String)
        : null,
    finishedAt: json['finished_at'] != null
        ? DateTime.tryParse(json['finished_at'] as String)
        : null,
  );
}

// ─── ApiService ─────────────────────────────────────────────────────────────

/// Centralized HTTP client for PoseTrack backend REST API.
///
/// Reads `serverAddress` from [MockPoseTrackingService] settings so it stays
/// in sync with whatever the user configured in the Settings screen.
class ApiService {
  ApiService({MockPoseTrackingService? settingsService})
      : _settingsService = settingsService ?? MockPoseTrackingService();

  final MockPoseTrackingService _settingsService;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns `true` when backend health check succeeds.
  Future<bool> checkHealth() async {
    try {
      final body = await _getJson('/api/health');
      return body['success'] == true;
    } on ApiException {
      return false;
    }
  }

  /// List all registered devices.
  Future<List<DeviceInfo>> getDevices() async {
    final body = await _getJson('/api/devices');
    final raw = body['data'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(DeviceInfo.fromJson)
        .toList(growable: false);
  }

  /// Send heartbeat for a device.
  Future<void> postHeartbeat(int deviceId, String status) async {
    await _postJson(
      '/api/devices/$deviceId/heartbeat',
      {'status': status},
    );
  }

  /// Retrieve job processing history (all jobs, newest first).
  Future<List<HistoryItem>> getHistory() async {
    final body = await _getJson('/api/history');
    final raw = body['data'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(HistoryItem.fromJson)
        .toList(growable: false);
  }

  /// Retrieve detail of a single job.
  Future<HistoryDetail> getHistoryDetail(int jobId) async {
    final body = await _getJson('/api/history/$jobId');
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const ApiException('History detail data is missing');
    }
    return HistoryDetail.fromJson(data);
  }

  /// Poll job status by ID.
  Future<Map<String, dynamic>> getJobStatus(int jobId) async {
    final body = await _getJson('/api/jobs/$jobId');
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = await _buildUri(path);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      return _parseResponse(response);
    } on SocketException {
      throw ApiException(
        'Cannot reach backend at ${uri.host}:${uri.port}. Check the server IP and Wi-Fi.',
      );
    } on HttpException catch (e) {
      throw ApiException(e.message);
    } on FormatException {
      throw const ApiException('Backend returned invalid JSON.');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = await _buildUri(path);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);

    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(body));
      final response = await request.close();
      return _parseResponse(response);
    } on SocketException {
      throw ApiException(
        'Cannot reach backend at ${uri.host}:${uri.port}.',
      );
    } on HttpException catch (e) {
      throw ApiException(e.message);
    } on FormatException {
      throw const ApiException('Backend returned invalid JSON.');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _parseResponse(HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          message = (decoded['message'] ?? decoded['detail'] ?? message)
              .toString();
        }
      } on FormatException {
        // keep generic message
      }
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (body.trim().isEmpty) return const {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException('Unexpected response format from backend.');
  }

  Future<Uri> _buildUri(String path) async {
    final settings = await _settingsService.getSettings();
    var base = settings.serverAddress.trim();
    if (base.isEmpty) base = '127.0.0.1:8002';
    if (!base.contains('://')) base = 'http://$base';
    base = base.replaceFirst(RegExp(r'/$'), '');
    if (base.endsWith('/api')) base = base.substring(0, base.length - 4);
    return Uri.parse(base).resolve(path);
  }
}

String extractApiError(Object error) {
  if (error is ApiException) return error.message;
  return error.toString();
}
