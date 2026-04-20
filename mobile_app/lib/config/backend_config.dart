class BackendConfig {
  const BackendConfig._();

  // Override with:
  // flutter run --dart-define=POSETRACK_BACKEND_ADDRESS=192.168.1.10:8002
  static const String defaultServerAddress = String.fromEnvironment(
    'POSETRACK_BACKEND_ADDRESS',
    defaultValue: '192.168.1.10:8002',
  );

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

  static const int defaultZmqPort = int.fromEnvironment(
    'POSETRACK_ZMQ_PORT',
    defaultValue: 5555,
  );
}
