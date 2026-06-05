/// Metadata đi kèm mỗi preview frame từ Pi agent (qua TCP socket).
class PreviewFrameMetadata {
  final int? frameId;
  final double? timestamp;
  final String? sessionId;
  final String mode;

  const PreviewFrameMetadata({
    required this.frameId,
    required this.timestamp,
    required this.sessionId,
    required this.mode,
  });

  bool get isRecordingPreview => mode == 'recording_preview';

  factory PreviewFrameMetadata.fromJson(Map<String, dynamic> json) {
    return PreviewFrameMetadata(
      frameId: _parseInt(json['frame_id']),
      timestamp: _parseDouble(json['timestamp']),
      sessionId: json['session_id'] as String?,
      mode: json['mode'] as String? ?? 'unknown',
    );
  }
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
