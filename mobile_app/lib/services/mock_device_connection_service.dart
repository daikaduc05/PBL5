enum DeviceEndpoint { raspberryPi, processingServer }

extension DeviceEndpointX on DeviceEndpoint {
  String get label => switch (this) {
    DeviceEndpoint.raspberryPi => 'Raspberry Pi',
    DeviceEndpoint.processingServer => 'Processing Server',
  };
}

enum DeviceLinkStatus { connected, disconnected, connecting }

class DeviceConnectionNode {
  final DeviceEndpoint endpoint;
  final String name;
  final String role;
  final String ipAddress;
  final DeviceLinkStatus status;
  final String transport;
  final String metricLabel;
  final String metricValue;
  final String lastSeen;
  final String statusDetail;

  const DeviceConnectionNode({
    required this.endpoint,
    required this.name,
    required this.role,
    required this.ipAddress,
    required this.status,
    required this.transport,
    required this.metricLabel,
    required this.metricValue,
    required this.lastSeen,
    required this.statusDetail,
  });

  DeviceConnectionNode copyWith({
    String? name,
    String? role,
    String? ipAddress,
    DeviceLinkStatus? status,
    String? transport,
    String? metricLabel,
    String? metricValue,
    String? lastSeen,
    String? statusDetail,
  }) {
    return DeviceConnectionNode(
      endpoint: endpoint,
      name: name ?? this.name,
      role: role ?? this.role,
      ipAddress: ipAddress ?? this.ipAddress,
      status: status ?? this.status,
      transport: transport ?? this.transport,
      metricLabel: metricLabel ?? this.metricLabel,
      metricValue: metricValue ?? this.metricValue,
      lastSeen: lastSeen ?? this.lastSeen,
      statusDetail: statusDetail ?? this.statusDetail,
    );
  }
}

class MockDeviceConnectionService {
  MockDeviceConnectionService._();

  static final MockDeviceConnectionService _instance =
      MockDeviceConnectionService._();

  factory MockDeviceConnectionService() => _instance;

  List<DeviceConnectionNode> _devices = const [
    DeviceConnectionNode(
      endpoint: DeviceEndpoint.raspberryPi,
      name: 'Raspberry Pi 4B',
      role: 'Edge Capture Node',
      ipAddress: '192.168.1.24',
      status: DeviceLinkStatus.disconnected,
      transport: 'Wi-Fi 6 / Camera CSI',
      metricLabel: 'Lens Sync',
      metricValue: 'Awaiting link',
      lastSeen: 'Last seen 3m ago',
      statusDetail:
          'Device discovered on the local network. Start a secure link before the next capture.',
    ),
    DeviceConnectionNode(
      endpoint: DeviceEndpoint.processingServer,
      name: 'Inference Server',
      role: 'Pose Processing Backend',
      ipAddress: '192.168.1.10',
      status: DeviceLinkStatus.connected,
      transport: 'Ethernet / REST API',
      metricLabel: 'Inference Queue',
      metricValue: '0 jobs',
      lastSeen: 'Heartbeat 6s ago',
      statusDetail:
          'PoseTrack API is online and ready to receive uploads from the mobile workflow.',
    ),
  ];

  Future<List<DeviceConnectionNode>> getDevices() async {
    await Future.delayed(const Duration(milliseconds: 180));
    return _cloneDevices();
  }

  Future<bool> allDevicesConnected() async {
    final devices = await getDevices();
    return devices.every((device) => device.status == DeviceLinkStatus.connected);
  }

  Future<List<DeviceConnectionNode>> scanDevices() async {
    await Future.delayed(const Duration(milliseconds: 900));

    _devices = _devices
        .map(
          (device) => switch (device.endpoint) {
            DeviceEndpoint.raspberryPi => device.copyWith(
              ipAddress: '192.168.1.24',
              lastSeen: 'Discovered just now',
              statusDetail: device.status == DeviceLinkStatus.connected
                  ? 'Raspberry Pi responded to the network sweep and the capture link is still healthy.'
                  : 'Raspberry Pi found on the subnet. Tap Connect to arm the mobile capture session.',
            ),
            DeviceEndpoint.processingServer => device.copyWith(
              ipAddress: '192.168.1.10',
              lastSeen: 'Heartbeat 2s ago',
              statusDetail: device.status == DeviceLinkStatus.connected
                  ? 'Processing server acknowledged the scan and the inference endpoint is healthy.'
                  : 'Processing server detected and waiting for a fresh secure session.',
            ),
          },
        )
        .toList(growable: false);

    return _cloneDevices();
  }

  Future<DeviceConnectionNode> connectDevice(DeviceEndpoint endpoint) async {
    await Future.delayed(const Duration(milliseconds: 1100));

    return switch (endpoint) {
      DeviceEndpoint.raspberryPi => _updateDevice(
        endpoint,
        status: DeviceLinkStatus.connected,
        metricValue: '42 FPS',
        lastSeen: 'Synced just now',
        statusDetail:
            'Capture node linked successfully. Camera stream and telemetry are ready for the next session.',
      ),
      DeviceEndpoint.processingServer => _updateDevice(
        endpoint,
        status: DeviceLinkStatus.connected,
        metricValue: 'Queue idle',
        lastSeen: 'Synced just now',
        statusDetail:
            'Processing server linked. Upload endpoint, pose engine, and result queue are ready.',
      ),
    };
  }

  Future<DeviceConnectionNode> reconnectDevice(DeviceEndpoint endpoint) async {
    await Future.delayed(const Duration(milliseconds: 850));

    return switch (endpoint) {
      DeviceEndpoint.raspberryPi => _updateDevice(
        endpoint,
        status: DeviceLinkStatus.connected,
        metricValue: '41 FPS',
        lastSeen: 'Heartbeat live',
        statusDetail:
            'Raspberry Pi session recovered. Frame sync and Wi-Fi heartbeat are stable again.',
      ),
      DeviceEndpoint.processingServer => _updateDevice(
        endpoint,
        status: DeviceLinkStatus.connected,
        metricValue: 'Model hot',
        lastSeen: 'Heartbeat live',
        statusDetail:
            'Server session refreshed. Inference API and background workers responded without delay.',
      ),
    };
  }

  DeviceConnectionNode _updateDevice(
    DeviceEndpoint endpoint, {
    required DeviceLinkStatus status,
    required String metricValue,
    required String lastSeen,
    required String statusDetail,
  }) {
    final index = _devices.indexWhere((device) => device.endpoint == endpoint);

    if (index == -1) {
      throw StateError('Unknown endpoint: $endpoint');
    }

    final updated = _devices[index].copyWith(
      status: status,
      metricValue: metricValue,
      lastSeen: lastSeen,
      statusDetail: statusDetail,
    );

    final next = List<DeviceConnectionNode>.from(_devices);
    next[index] = updated;
    _devices = List.unmodifiable(next);

    return updated.copyWith();
  }

  List<DeviceConnectionNode> _cloneDevices() {
    return _devices.map((device) => device.copyWith()).toList(growable: false);
  }
}
