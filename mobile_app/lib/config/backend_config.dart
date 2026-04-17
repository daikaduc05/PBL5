class BackendConfig {
  const BackendConfig._();

  // Override with:
  // flutter run --dart-define=POSETRACK_BACKEND_ADDRESS=192.168.1.10:8000
  static const String defaultServerAddress = String.fromEnvironment(
    'POSETRACK_BACKEND_ADDRESS',
    defaultValue: '192.168.1.10:8000',
  );
}
