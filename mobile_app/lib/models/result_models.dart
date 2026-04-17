import 'dart:convert';

class ResultSession {
  final String sessionId;
  final DateTime? capturedAt;

  const ResultSession({
    required this.sessionId,
    required this.capturedAt,
  });

  factory ResultSession.fromSessionId(String sessionId) {
    return ResultSession(
      sessionId: sessionId,
      capturedAt: _parseSessionTimestamp(sessionId),
    );
  }
}

class ResultSessionDetail {
  final String sessionId;
  final DateTime? capturedAt;
  final List<ResultFrameItem> frames;

  const ResultSessionDetail({
    required this.sessionId,
    required this.capturedAt,
    required this.frames,
  });

  int get frameCount => frames.length;

  int get poseReadyCount => frames.where((frame) => frame.hasPoseImage).length;

  int get resultReadyCount => frames.where((frame) => frame.hasResultJson).length;

  int? get latestFrameId => frames.isEmpty ? null : frames.last.frameId;

  ResultFrameItem? findFrame(int frameId) {
    for (final frame in frames) {
      if (frame.frameId == frameId) {
        return frame;
      }
    }
    return null;
  }

  factory ResultSessionDetail.fromJson(
    Map<String, dynamic> json, {
    required String? Function(String?) resolveImageUrl,
  }) {
    final sessionId = json['session_id'] as String? ?? 'unknown_session';
    final rawFrames = json['frames'] as List<dynamic>? ?? const <dynamic>[];
    final frames = rawFrames
        .whereType<Map>()
        .map(
          (frame) => ResultFrameItem.fromJson(
            Map<String, dynamic>.from(frame),
            resolveImageUrl: resolveImageUrl,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.frameId.compareTo(right.frameId));

    return ResultSessionDetail(
      sessionId: sessionId,
      capturedAt: _parseSessionTimestamp(sessionId),
      frames: frames,
    );
  }
}

class ResultFrameItem {
  final int frameId;
  final String? poseImageUrl;
  final String? poseImagePath;
  final String? resultJsonPath;

  const ResultFrameItem({
    required this.frameId,
    required this.poseImageUrl,
    required this.poseImagePath,
    required this.resultJsonPath,
  });

  bool get hasPoseImage => poseImageUrl != null && poseImageUrl!.isNotEmpty;

  bool get hasResultJson => resultJsonPath != null && resultJsonPath!.isNotEmpty;

  factory ResultFrameItem.fromJson(
    Map<String, dynamic> json, {
    required String? Function(String?) resolveImageUrl,
  }) {
    return ResultFrameItem(
      frameId: _parseInt(json['frame_id']) ?? 0,
      poseImageUrl: resolveImageUrl(json['pose_image_url'] as String?),
      poseImagePath: json['pose_image_path'] as String?,
      resultJsonPath: json['result_json_path'] as String?,
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

  Iterable<MapEntry<String, dynamic>> get metadataEntries {
    return payload.entries.where(
      (entry) => !_reservedFrameResultKeys.contains(entry.key),
    );
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

class ResultSessionDetailArgs {
  final String sessionId;

  const ResultSessionDetailArgs({required this.sessionId});
}

class ResultFrameDetailArgs {
  final String sessionId;
  final int frameId;
  final String? poseImageUrl;

  const ResultFrameDetailArgs({
    required this.sessionId,
    required this.frameId,
    this.poseImageUrl,
  });
}

const Set<String> _reservedFrameResultKeys = <String>{
  'frame_id',
  'success',
  'num_detections',
  'pose_output_path',
};

int compareResultSessions(ResultSession left, ResultSession right) {
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
