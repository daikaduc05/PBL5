import '../config/backend_config.dart';
import 'api_service.dart';
import 'mock_pose_tracking_service.dart';

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

class DeviceConnectionService {
  DeviceConnectionService({
    MockPoseTrackingService? settingsService,
    ApiService? api,
  }) : _settingsService = settingsService ?? MockPoseTrackingService(),
       _api = api ?? ApiService(settingsService: settingsService);

  final MockPoseTrackingService _settingsService;
  final ApiService _api;

  Future<List<DeviceConnectionNode>> getDevices() => _loadNodes();

  Future<bool> allDevicesConnected() async {
    final devices = await _loadNodes();
    return devices.isNotEmpty &&
        devices.every((device) => device.status == DeviceLinkStatus.connected);
  }

  Future<List<DeviceConnectionNode>> scanDevices() => _loadNodes();

  Future<DeviceConnectionNode> connectDevice(DeviceEndpoint endpoint) async {
    return _loadNodeForEndpoint(endpoint);
  }

  Future<DeviceConnectionNode> reconnectDevice(DeviceEndpoint endpoint) async {
    return _loadNodeForEndpoint(endpoint);
  }

  Future<DeviceConnectionNode> _loadNodeForEndpoint(DeviceEndpoint endpoint) async {
    final nodes = await _loadNodes();
    return nodes.firstWhere((item) => item.endpoint == endpoint);
  }

  Future<List<DeviceConnectionNode>> _loadNodes() async {
    final settings = await _settingsService.getSettings();
    final backendHealthy = await _api.checkHealth();

    List<DeviceInfo> devices = const [];
    String? deviceErrorMessage;
    if (backendHealthy) {
      try {
        devices = await _api.getDevices();
      } catch (error) {
        deviceErrorMessage = extractApiError(error);
      }
    }

    final serverNode = _buildServerNode(
      serverAddress: settings.serverAddress,
      backendHealthy: backendHealthy,
      errorMessage: deviceErrorMessage,
    );
    final piNode = _buildPiNode(
      raspberryPiIp: settings.raspberryPiIp,
      devices: devices,
      backendHealthy: backendHealthy,
      errorMessage: deviceErrorMessage,
    );

    return [piNode, serverNode];
  }

  DeviceConnectionNode _buildServerNode({
    required String serverAddress,
    required bool backendHealthy,
    required String? errorMessage,
  }) {
    final endpoint = _normalizeBaseUrl(serverAddress);
    final serverUri = Uri.parse(endpoint);
    final ipAddress = serverUri.hasPort
        ? '${serverUri.host}:${serverUri.port}'
        : serverUri.host;

    return DeviceConnectionNode(
      endpoint: DeviceEndpoint.processingServer,
      name: 'Inference Server',
      role: 'Pose Processing Backend',
      ipAddress: ipAddress,
      status: backendHealthy
          ? DeviceLinkStatus.connected
          : DeviceLinkStatus.disconnected,
      transport: 'HTTP / FastAPI REST',
      metricLabel: 'Health',
      metricValue: backendHealthy ? 'Healthy' : 'Offline',
      lastSeen: backendHealthy ? 'Reachable just now' : 'No response yet',
      statusDetail: backendHealthy
          ? 'FastAPI backend is reachable and ready to accept mobile requests.'
          : (errorMessage ??
                'Cannot reach the FastAPI backend. Check the server IP, port, and Wi-Fi network.'),
    );
  }

  DeviceConnectionNode _buildPiNode({
    required String raspberryPiIp,
    required List<DeviceInfo> devices,
    required bool backendHealthy,
    required String? errorMessage,
  }) {
    if (!backendHealthy) {
      return DeviceConnectionNode(
        endpoint: DeviceEndpoint.raspberryPi,
        name: 'Raspberry Pi',
        role: 'Edge Capture Node',
        ipAddress: raspberryPiIp,
        status: DeviceLinkStatus.disconnected,
        transport: 'Wi-Fi / ZeroMQ',
        metricLabel: 'Device Code',
        metricValue: BackendConfig.defaultPiDeviceCode,
        lastSeen: 'Backend unavailable',
        statusDetail:
            'The backend is offline, so the app cannot confirm Raspberry Pi heartbeat yet.',
      );
    }

    final preferredDevice = _pickPreferredDevice(devices);
    if (preferredDevice == null) {
      return DeviceConnectionNode(
        endpoint: DeviceEndpoint.raspberryPi,
        name: 'Raspberry Pi',
        role: 'Edge Capture Node',
        ipAddress: raspberryPiIp,
        status: DeviceLinkStatus.disconnected,
        transport: 'Wi-Fi / ZeroMQ',
        metricLabel: 'Device Code',
        metricValue: BackendConfig.defaultPiDeviceCode,
        lastSeen: 'Waiting for registration',
        statusDetail:
            errorMessage ??
            'No Raspberry Pi device is registered on the backend yet. Start the Pi agent and wait for heartbeat.',
      );
    }

    final backendStatus = preferredDevice.status.toLowerCase();
    final isConnected =
        backendStatus != 'offline' && backendStatus != 'error';

    return DeviceConnectionNode(
      endpoint: DeviceEndpoint.raspberryPi,
      name: preferredDevice.deviceName,
      role: 'Edge Capture Node',
      ipAddress: raspberryPiIp,
      status: isConnected
          ? DeviceLinkStatus.connected
          : DeviceLinkStatus.disconnected,
      transport: 'Wi-Fi / ZeroMQ',
      metricLabel: 'Backend State',
      metricValue: backendStatus.toUpperCase(),
      lastSeen: _formatLastSeen(preferredDevice.lastSeen),
      statusDetail: isConnected
          ? 'Pi agent is registered with the backend and ready for the next capture command.'
          : 'The Raspberry Pi is registered but currently offline. Check the Pi agent process and heartbeat.',
    );
  }

  DeviceInfo? _pickPreferredDevice(List<DeviceInfo> devices) {
    if (devices.isEmpty) {
      return null;
    }

    for (final device in devices) {
      if (device.deviceCode == BackendConfig.defaultPiDeviceCode) {
        return device;
      }
    }

    return devices.first;
  }

  String _normalizeBaseUrl(String rawAddress) {
    var value = rawAddress.trim();
    if (value.isEmpty) {
      value = BackendConfig.defaultServerAddress;
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

  String _formatLastSeen(DateTime? value) {
    if (value == null) {
      return 'No heartbeat timestamp';
    }

    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inSeconds < 10) {
      return 'Heartbeat just now';
    }
    if (difference.inMinutes < 1) {
      return 'Heartbeat ${difference.inSeconds}s ago';
    }
    if (difference.inHours < 1) {
      return 'Heartbeat ${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return 'Heartbeat ${difference.inHours}h ago';
    }

    final year = value.toLocal().year.toString().padLeft(4, '0');
    final month = value.toLocal().month.toString().padLeft(2, '0');
    final day = value.toLocal().day.toString().padLeft(2, '0');
    return 'Heartbeat $year/$month/$day';
  }
}
