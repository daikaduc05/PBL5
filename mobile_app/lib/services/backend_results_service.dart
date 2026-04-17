import 'dart:convert';
import 'dart:io';

import 'mock_pose_tracking_service.dart';

class BackendResultsException implements Exception {
  final String message;

  const BackendResultsException(this.message);

  @override
  String toString() => message;
}

class ResultScreenArgs {
  final String sessionId;
  final int? initialFrameId;

  const ResultScreenArgs({
    required this.sessionId,
    this.initialFrameId,
  });
}

class ResultFrameSummary {
  final int frameId;
  final String? poseImageUrl;
  final String? resultJsonUrl;

  const ResultFrameSummary({
    required this.frameId,
    required this.poseImageUrl,
    required this.resultJsonUrl,
  });

  bool get hasPoseImage => poseImageUrl != null && poseImageUrl!.isNotEmpty;

  bool get hasResultJson => resultJsonUrl != null && resultJsonUrl!.isNotEmpty;

  factory ResultFrameSummary.fromJson(Map<String, dynamic> json) {
    return ResultFrameSummary(
      frameId: _parseInt(json['frame_id']) ?? 0,
      poseImageUrl: json['pose_image_url'] as String?,
      resultJsonUrl: json['result_json_url'] as String?,
    );
  }
}

class ResultSessionSummary {
  final String sessionId;
  final List<ResultFrameSummary> frames;
  final DateTime? capturedAt;

  const ResultSessionSummary({
    required this.sessionId,
    required this.frames,
    required this.capturedAt,
  });

  int get frameCount => frames.length;

  int get poseReadyCount => frames.where((frame) => frame.hasPoseImage).length;

  int get resultReadyCount =>
      frames.where((frame) => frame.hasResultJson).length;

  int? get latestFrameId => frames.isEmpty ? null : frames.last.frameId;

  factory ResultSessionSummary.fromJson(Map<String, dynamic> json) {
    final sessionId = json['session_id'] as String? ?? 'unknown_session';
    final rawFrames = json['frames'] as List<dynamic>? ?? const <dynamic>[];
    final frames = rawFrames
        .whereType<Map>()
        .map(
          (frame) =>
              ResultFrameSummary.fromJson(Map<String, dynamic>.from(frame)),
        )
        .toList(growable: false)
      ..sort((left, right) => left.frameId.compareTo(right.frameId));

    return ResultSessionSummary(
      sessionId: sessionId,
      frames: frames,
      capturedAt: _parseSessionTimestamp(sessionId),
    );
  }
}

class FrameResultDetail {
  final String sessionId;
  final int frameId;
  final Map<String, dynamic> payload;

  const FrameResultDetail({
    required this.sessionId,
    required this.frameId,
    required this.payload,
  });

  bool? get success => payload['success'] as bool?;

  int? get numDetections => _parseInt(payload['num_detections']);

  String? get poseOutputPath => payload['pose_output_path'] as String?;

  String? get errorMessage {
    final inferenceResult = payload['inference_result'];
    if (inferenceResult is Map) {
      return inferenceResult['error'] as String?;
    }
    return null;
  }

  String get prettyJson => const JsonEncoder.withIndent('  ').convert(payload);

  factory FrameResultDetail.fromJson(
    String sessionId,
    int frameId,
    Map<String, dynamic> json,
  ) {
    return FrameResultDetail(
      sessionId: sessionId,
      frameId: _parseInt(json['frame_id']) ?? frameId,
      payload: json,
    );
  }
}

class BackendResultsService {
  BackendResultsService({MockPoseTrackingService? settingsService})
    : _settingsService = settingsService ?? MockPoseTrackingService();

  final MockPoseTrackingService _settingsService;

  Future<List<ResultSessionSummary>> fetchSessions() async {
    final response = await _getJson('/api/results/sessions');
    final rawSessions =
        response['sessions'] as List<dynamic>? ?? const <dynamic>[];
    final sessionIds = rawSessions.whereType<String>().toList(growable: false);

    final sessions = <ResultSessionSummary>[];
    for (final sessionId in sessionIds) {
      sessions.add(await fetchSession(sessionId));
    }

    sessions.sort(_compareSessions);
    return sessions;
  }

  Future<ResultSessionSummary> fetchSession(String sessionId) async {
    final response = await _getJson('/api/results/$sessionId');
    return ResultSessionSummary.fromJson(response);
  }

  Future<FrameResultDetail> fetchFrameResult(
    String sessionId,
    int frameId,
  ) async {
    final response = await _getJson('/api/results/$sessionId/$frameId');
    return FrameResultDetail.fromJson(sessionId, frameId, response);
  }

  Future<String> getConfiguredServerLabel() async {
    final settings = await _settingsService.getSettings();
    return _normalizeBaseUrl(settings.serverAddress);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = await _buildUri(path);
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 750);

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendResultsException(
          _extractErrorMessage(response.statusCode, responseBody),
        );
      }

      if (responseBody.trim().isEmpty) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw const BackendResultsException(
        'The backend returned an unexpected response format.',
      );
    } on SocketException {
      throw const BackendResultsException(
        'Unable to reach the backend results API. Check the server IP, port, and Wi-Fi network.',
      );
    } on HttpException catch (error) {
      throw BackendResultsException(error.message);
    } on FormatException {
      throw const BackendResultsException(
        'The backend returned invalid JSON for this request.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Uri> _buildUri(String path) async {
    final settings = await _settingsService.getSettings();
    final baseUri = Uri.parse(_normalizeBaseUrl(settings.serverAddress));
    return baseUri.resolve(path);
  }

  String _normalizeBaseUrl(String rawAddress) {
    var value = rawAddress.trim();
    if (value.isEmpty) {
      value = '127.0.0.1:8002';
    }

    if (!value.contains('://')) {
      value = 'http://$value';
    }

    value = value.replaceFirst(RegExp(r'/$'), '');
    if (value.endsWith('/api')) {
      value = value.substring(0, value.length - 4);
    }

    return value;
  }
}

int _compareSessions(ResultSessionSummary left, ResultSessionSummary right) {
  final leftTime = left.capturedAt;
  final rightTime = right.capturedAt;

  if (leftTime != null && rightTime != null) {
    return rightTime.compareTo(leftTime);
  }

  return right.sessionId.compareTo(left.sessionId);
}

int? _parseInt(Object? value) {
  return switch (value) {
    int() => value,
    String() => int.tryParse(value),
    _ => null,
  };
}

DateTime? _parseSessionTimestamp(String sessionId) {
  final match = RegExp(r'(\d{8})_(\d{6})$').firstMatch(sessionId);
  if (match == null) {
    return null;
  }

  final datePart = match.group(1)!;
  final timePart = match.group(2)!;

  return DateTime(
    int.parse(datePart.substring(0, 4)),
    int.parse(datePart.substring(4, 6)),
    int.parse(datePart.substring(6, 8)),
    int.parse(timePart.substring(0, 2)),
    int.parse(timePart.substring(2, 4)),
    int.parse(timePart.substring(4, 6)),
  );
}

String extractBackendMessage(Object error) {
  if (error is BackendResultsException) {
    return error.message;
  }
  return error.toString();
}

String _extractErrorMessage(int statusCode, String responseBody) {
  if (responseBody.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }

        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      // Keep the generic HTTP message below if the response body is not JSON.
    }
  }

  return 'The backend returned HTTP $statusCode.';
}
