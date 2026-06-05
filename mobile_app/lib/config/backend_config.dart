import 'package:flutter/foundation.dart' show kIsWeb;

class BackendConfig {
  const BackendConfig._();

  // Override khi build web cho Railway:
  // flutter build web --dart-define=POSETRACK_BACKEND_ADDRESS=https://posetrack-backend.railway.app
  //
  // Override khi build native local:
  // flutter run --dart-define=POSETRACK_BACKEND_ADDRESS=192.168.1.10:8002
  static const String _envServerAddress = String.fromEnvironment(
    'POSETRACK_BACKEND_ADDRESS',
    defaultValue: '',
  );

  /// Server address được dùng bởi ApiService.
  /// - Nếu có --dart-define POSETRACK_BACKEND_ADDRESS, dùng giá trị đó.
  /// - Nếu chạy trên web (PWA), fallback về cùng origin (relative) —
  ///   nghĩa là PWA và backend phải cùng host, hoặc user tự nhập trong Settings.
  /// - Nếu chạy native, fallback về địa chỉ LAN mặc định.
  static String get defaultServerAddress {
    if (_envServerAddress.isNotEmpty) return _envServerAddress;
    if (kIsWeb) {
      // Khi chạy PWA trên web: user sẽ nhập URL backend trong Settings screen.
      // Để trống để app hiển thị warning và yêu cầu nhập.
      return '';
    }
    return '192.168.1.10:8002';
  }

  // Raspberry Pi device code expected by the mobile app in MVP mode.
  static const String defaultPiDeviceCode = String.fromEnvironment(
    'POSETRACK_PI_DEVICE_CODE',
    defaultValue: 'pi-001',
  );

  // Demo frame directory used by the Pi agent replay flow.
  static const String defaultPiFramesDir = String.fromEnvironment(
    'POSETRACK_PI_FRAMES_DIR',
    defaultValue: '/home/pi/posetrack/frames',
  );

  // Matches the embedded Pi preview server default in backend/pi_agent/pi_agent.py.
  static const int defaultPiPreviewPort = int.fromEnvironment(
    'POSETRACK_PREVIEW_PORT',
    defaultValue: 8081,
  );

  static const int defaultPiPreviewSocketPort = int.fromEnvironment(
    'POSETRACK_PREVIEW_SOCKET_PORT',
    defaultValue: 8082,
  );

  static const int defaultZmqPort = int.fromEnvironment(
    'POSETRACK_ZMQ_PORT',
    defaultValue: 5555,
  );
}
