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

  int? get latestResultFrameId {
    for (final frame in frames.reversed) {
      if (frame.hasResultJson) {
        return frame.frameId;
      }
    }
    return latestFrameId;
  }

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

  PoseOverlayData? get poseOverlay => PoseOverlayData.fromPayload(payload);

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

class PoseOverlayData {
  final int? imageWidth;
  final int? imageHeight;
  final List<List<int>> skeletonEdges;
  final List<PoseDetection> detections;

  const PoseOverlayData({
    required this.imageWidth,
    required this.imageHeight,
    required this.skeletonEdges,
    required this.detections,
  });

  bool get hasDetections => detections.isNotEmpty;

  static PoseOverlayData? fromPayload(Map<String, dynamic> payload) {
    final inferenceResult = payload['inference_result'];
    if (inferenceResult is! Map) {
      return null;
    }

    final inferenceMap = Map<String, dynamic>.from(inferenceResult);
    final imageSize = inferenceMap['image_size'];
    final detectionsRaw = inferenceMap['detections'] as List<dynamic>? ?? const <dynamic>[];
    final skeletonRaw = inferenceMap['skeleton_edges'] as List<dynamic>? ?? const <dynamic>[];

    final detections = detectionsRaw
        .whereType<Map>()
        .map((item) => PoseDetection.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);

    final skeletonEdges = skeletonRaw
        .whereType<List>()
        .map((edge) {
          final values = edge.map(_parseInt).whereType<int>().toList(growable: false);
          return values.length == 2 ? values : null;
        })
        .whereType<List<int>>()
        .toList(growable: false);

    if (detections.isEmpty && skeletonEdges.isEmpty) {
      return null;
    }

    return PoseOverlayData(
      imageWidth: imageSize is Map ? _parseInt(imageSize['width']) : null,
      imageHeight: imageSize is Map ? _parseInt(imageSize['height']) : null,
      skeletonEdges: skeletonEdges,
      detections: detections,
    );
  }
}

class PoseDetection {
  final PoseBoundingBox? bboxNormalized;
  final List<PosePoint> normalizedKeypoints;
  final Map<String, double> angles;

  const PoseDetection({
    required this.bboxNormalized,
    required this.normalizedKeypoints,
    required this.angles,
  });

  factory PoseDetection.fromJson(Map<String, dynamic> json) {
    final bbox = json['bbox_normalized'];
    final keypoints = (json['keypoints_normalized'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<List>()
        .map(PosePoint.fromList)
        .toList(growable: false);

    final anglesRaw = json['angles'];
    final angles = <String, double>{};
    if (anglesRaw is Map) {
      for (final entry in anglesRaw.entries) {
        final value = _parseDouble(entry.value);
        if (value != null) {
          angles[entry.key.toString()] = value;
        }
      }
    }

    return PoseDetection(
      bboxNormalized: bbox is Map ? PoseBoundingBox.fromJson(Map<String, dynamic>.from(bbox)) : null,
      normalizedKeypoints: keypoints,
      angles: angles,
    );
  }
}

class PoseBoundingBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const PoseBoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory PoseBoundingBox.fromJson(Map<String, dynamic> json) {
    return PoseBoundingBox(
      x1: _parseDouble(json['x1']) ?? 0,
      y1: _parseDouble(json['y1']) ?? 0,
      x2: _parseDouble(json['x2']) ?? 0,
      y2: _parseDouble(json['y2']) ?? 0,
    );
  }
}

class PosePoint {
  final double x;
  final double y;

  const PosePoint({
    required this.x,
    required this.y,
  });

  factory PosePoint.fromList(List<dynamic> values) {
    return PosePoint(
      x: values.isNotEmpty ? (_parseDouble(values[0]) ?? 0) : 0,
      y: values.length > 1 ? (_parseDouble(values[1]) ?? 0) : 0,
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

class ResultScreenArgs {
  final String sessionId;
  final int? initialFrameId;

  const ResultScreenArgs({
    required this.sessionId,
    this.initialFrameId,
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

double? _parseDouble(Object? value) {
  return switch (value) {
    double() => value,
    int() => value.toDouble(),
    String() => double.tryParse(value),
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
