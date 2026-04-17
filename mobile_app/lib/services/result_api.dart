import 'dart:convert';
import 'dart:io';

import '../config/backend_config.dart';
import '../models/result_models.dart';
import 'mock_pose_tracking_service.dart';

class ResultApiException implements Exception {
  final String message;

  const ResultApiException(this.message);

  @override
  String toString() => message;
}

class ResultApi {
  ResultApi({MockPoseTrackingService? settingsService})
    : _settingsService = settingsService ?? MockPoseTrackingService();

  final MockPoseTrackingService _settingsService;

  Future<List<ResultSession>> getResultSessions() async {
    final response = await _getJson('/api/results/sessions');
    final rawSessions = response['sessions'] as List<dynamic>? ?? const <dynamic>[];
    final sessions = rawSessions
        .whereType<String>()
        .map(ResultSession.fromSessionId)
        .toList(growable: false)
      ..sort(compareResultSessions);
    return sessions;
  }

  Future<ResultSessionDetail> getResultSessionDetail(String sessionId) async {
    final baseUri = await _getBaseUri();
    final response = await _getJson('/api/results/$sessionId');

    return ResultSessionDetail.fromJson(
      response,
      resolveImageUrl: (rawPath) => _resolveBackendUrl(baseUri, rawPath),
    );
  }

  Future<FrameResultDetail> getFrameResult(String sessionId, int frameId) async {
    final response = await _getJson('/api/results/$sessionId/$frameId');
    return FrameResultDetail.fromJson(sessionId, frameId, response);
  }

  Future<String> getConfiguredBaseUrl() async {
    final baseUri = await _getBaseUri();
    return _trimTrailingSlash(baseUri.toString());
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = await _buildUri(path);
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1200);

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ResultApiException(
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

      throw const ResultApiException(
        'The backend returned an unexpected response format.',
      );
    } on SocketException {
      throw const ResultApiException(
        'Unable to reach the backend results API. Check the server IP, port, and Wi-Fi network.',
      );
    } on HttpException catch (error) {
      throw ResultApiException(error.message);
    } on FormatException {
      throw const ResultApiException(
        'The backend returned invalid JSON for this request.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Uri> _buildUri(String path) async {
    final baseUri = await _getBaseUri();
    return baseUri.resolve(path);
  }

  Future<Uri> _getBaseUri() async {
    final settings = await _settingsService.getSettings();
    return Uri.parse(_normalizeBaseUrl(settings.serverAddress));
  }

  String _normalizeBaseUrl(String rawAddress) {
    var value = rawAddress.trim();
    if (value.isEmpty) {
      value = BackendConfig.defaultServerAddress;
    }

    if (!value.contains('://')) {
      value = 'http://$value';
    }

    value = _trimTrailingSlash(value);
    if (value.endsWith('/api')) {
      value = value.substring(0, value.length - 4);
    }

    return value;
  }

  String? _resolveBackendUrl(Uri baseUri, String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(rawPath);
    if (parsed != null && parsed.hasScheme) {
      return rawPath;
    }

    return baseUri.resolve(rawPath).toString();
  }
}

String extractResultApiMessage(Object error) {
  if (error is ResultApiException) {
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

String _trimTrailingSlash(String value) {
  return value.replaceFirst(RegExp(r'/$'), '');
}
