import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/metric_pill.dart';
import '../components/screen_container.dart';
import '../components/section_title.dart';
import '../navigation/app_routes.dart';
import '../services/mock_device_connection_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  final MockDeviceConnectionService _service = MockDeviceConnectionService();

  List<DeviceConnectionNode> _devices = const [];
  Set<DeviceEndpoint> _busyEndpoints = <DeviceEndpoint>{};

  bool _isInitialLoad = true;
  bool _isScanning = false;
  DateTime? _lastScanAt;
  String _networkMessage =
      'Scan the local subnet to verify the Raspberry Pi and processing server before recording.';

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  bool get _allConnected =>
      _devices.isNotEmpty &&
      _devices.every((device) => device.status == DeviceLinkStatus.connected);

  int get _connectedCount => _devices
      .where((device) => device.status == DeviceLinkStatus.connected)
      .length;

  int get _connectingCount => _devices
      .where((device) => device.status == DeviceLinkStatus.connecting)
      .length;

  Future<void> _loadDevices() async {
    final devices = await _service.getDevices();

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      _isInitialLoad = false;
      _networkMessage = _defaultNetworkMessage(devices);
    });
  }

  Future<void> _scanNetwork({DeviceEndpoint? focus}) async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _networkMessage = focus == null
          ? 'Sweeping the local network for both PoseTrack endpoints...'
          : 'Refreshing ${focus.label} telemetry on the local subnet...';
    });

    final devices = await _service.scanDevices();

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = devices;
      _isScanning = false;
      _lastScanAt = DateTime.now();
      _networkMessage = focus == null
          ? _scanCompleteMessage(devices)
          : '${focus.label} refreshed. ${_readyCountLabel(devices)} ready for capture.';
    });
  }

  Future<void> _connectEndpoint(DeviceEndpoint endpoint) async {
    await _runEndpointAction(
      endpoint: endpoint,
      pendingMessage: 'Connecting to ${endpoint.label}...',
      pendingDetail:
          'Opening the secure PoseTrack link and validating telemetry packets.',
      action: _service.connectDevice,
      successMessage: '${endpoint.label} is linked and ready.',
      failureMessage:
          'PoseTrack could not link ${endpoint.label}. Scan and try again.',
    );
  }

  Future<void> _reconnectEndpoint(DeviceEndpoint endpoint) async {
    await _runEndpointAction(
      endpoint: endpoint,
      pendingMessage: 'Reconnecting ${endpoint.label}...',
      pendingDetail:
          'Refreshing the current session token and verifying the next heartbeat.',
      action: _service.reconnectDevice,
      successMessage: '${endpoint.label} session refreshed successfully.',
      failureMessage:
          'Reconnect failed for ${endpoint.label}. Try scanning the subnet again.',
    );
  }

  Future<void> _runEndpointAction({
    required DeviceEndpoint endpoint,
    required String pendingMessage,
    required String pendingDetail,
    required Future<DeviceConnectionNode> Function(DeviceEndpoint endpoint)
    action,
    required String successMessage,
    required String failureMessage,
  }) async {
    if (_busyEndpoints.contains(endpoint) || _isScanning) {
      return;
    }

    setState(() {
      final nextBusy = Set<DeviceEndpoint>.from(_busyEndpoints)..add(endpoint);
      _busyEndpoints = nextBusy;
      _updateLocalDevice(
        endpoint,
        status: DeviceLinkStatus.connecting,
        lastSeen: 'Negotiating now',
        statusDetail: pendingDetail,
      );
      _networkMessage = pendingMessage;
    });

    try {
      final updated = await action(endpoint);

      if (!mounted) {
        return;
      }

      setState(() {
        _replaceDevice(updated);
        final nextBusy = Set<DeviceEndpoint>.from(_busyEndpoints)
          ..remove(endpoint);
        _busyEndpoints = nextBusy;
        _networkMessage = successMessage;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        final nextBusy = Set<DeviceEndpoint>.from(_busyEndpoints)
          ..remove(endpoint);
        _busyEndpoints = nextBusy;
        _updateLocalDevice(
          endpoint,
          status: DeviceLinkStatus.disconnected,
          lastSeen: 'Retry needed',
          statusDetail: failureMessage,
        );
        _networkMessage = failureMessage;
      });
    }
  }

  void _updateLocalDevice(
    DeviceEndpoint endpoint, {
    DeviceLinkStatus? status,
    String? lastSeen,
    String? statusDetail,
  }) {
    _devices = _devices
        .map(
          (device) => device.endpoint == endpoint
              ? device.copyWith(
                  status: status,
                  lastSeen: lastSeen,
                  statusDetail: statusDetail,
                )
              : device,
        )
        .toList(growable: false);
  }

  void _replaceDevice(DeviceConnectionNode updated) {
    _devices = _devices
        .map((device) => device.endpoint == updated.endpoint ? updated : device)
        .toList(growable: false);
  }

  void _goHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  String _defaultNetworkMessage(List<DeviceConnectionNode> devices) {
    if (devices.isEmpty) {
      return 'Loading mock device telemetry...';
    }

    final connectedCount = devices
        .where((device) => device.status == DeviceLinkStatus.connected)
        .length;

    if (connectedCount == devices.length) {
      return 'Both endpoints are ready. Mobile capture can start immediately.';
    }

    if (connectedCount == 0) {
      return 'No endpoints are linked yet. Scan the network and connect both services.';
    }

    return '$connectedCount of ${devices.length} endpoints are ready. Finish the remaining link to continue.';
  }

  String _scanCompleteMessage(List<DeviceConnectionNode> devices) {
    final connectedCount = devices
        .where((device) => device.status == DeviceLinkStatus.connected)
        .length;

    return 'Scan complete. $connectedCount of ${devices.length} endpoints are reachable right now.';
  }

  String _readyCountLabel(List<DeviceConnectionNode> devices) {
    final connectedCount = devices
        .where((device) => device.status == DeviceLinkStatus.connected)
        .length;

    return '$connectedCount/${devices.length}';
  }

  String _formatScanTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: LayoutBuilder(
          builder: (context, viewportConstraints) {
            final minHeight = viewportConstraints.maxHeight > 40
                ? viewportConstraints.maxHeight - 40
                : 0.0;

            return Stack(
              children: [
                const Positioned(
                  top: -110,
                  right: -80,
                  child: _GlowOrb(size: 240, color: AppColors.primary),
                ),
                const Positioned(
                  left: -70,
                  bottom: 140,
                  child: _GlowOrb(size: 190, color: AppColors.accent),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: const _ConnectionGridPainter()),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ConnectionHeader(
                              isReady: _allConnected,
                              onBackPressed: _goHome,
                            ),
                            const SizedBox(height: 24),
                            _ConnectionOverviewCard(
                              connectedCount: _connectedCount,
                              connectingCount: _connectingCount,
                              totalCount: _devices.length,
                              lastScanLabel: _lastScanAt == null
                                  ? 'Pending'
                                  : _formatScanTime(_lastScanAt!),
                              message: _networkMessage,
                              isScanning: _isScanning,
                            ),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'Device Endpoints',
                              subtitle:
                                  'Link the Raspberry Pi and server before starting the capture pipeline.',
                            ),
                            const SizedBox(height: 16),
                            if (_isInitialLoad && _devices.isEmpty)
                              const _LoadingPanel()
                            else
                              ..._devices.map(
                                (device) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DeviceConnectionCard(
                                    device: device,
                                    isBusy: _busyEndpoints.contains(
                                      device.endpoint,
                                    ),
                                    isScanning: _isScanning,
                                    onScan: () =>
                                        _scanNetwork(focus: device.endpoint),
                                    onConnect: () =>
                                        _connectEndpoint(device.endpoint),
                                    onReconnect: () =>
                                        _reconnectEndpoint(device.endpoint),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            _ConnectionFooterHint(
                              isReady: _allConnected,
                              connectedCount: _connectedCount,
                              totalCount: _devices.length,
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final useTwoColumns =
                                    constraints.maxWidth >= 360 &&
                                    _allConnected;
                                final buttonWidth = useTwoColumns
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: buttonWidth,
                                      child: AppButton(
                                        text: 'Back Home',
                                        isSecondary: true,
                                        onPressed: _goHome,
                                      ),
                                    ),
                                    if (_allConnected)
                                      SizedBox(
                                        width: buttonWidth,
                                        child: AppButton(
                                          text: 'Continue to Capture',
                                          onPressed: () {
                                            Navigator.of(
                                              context,
                                            ).pushNamed(AppRoutes.capture);
                                          },
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectionHeader extends StatelessWidget {
  final bool isReady;
  final VoidCallback onBackPressed;

  const _ConnectionHeader({required this.isReady, required this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderIconButton(icon: Icons.arrow_back_rounded, onTap: onBackPressed),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Connection',
                style: AppTypography.h2.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                'Pair the edge capture node and processing backend from a clean mobile IoT control interface.',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  height: 1.24,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isReady
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isReady
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.26),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pipeline',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isReady ? 'READY' : 'SYNCING',
                style: AppTypography.bodyMedium.copyWith(
                  color: isReady ? AppColors.success : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionOverviewCard extends StatelessWidget {
  final int connectedCount;
  final int connectingCount;
  final int totalCount;
  final String lastScanLabel;
  final String message;
  final bool isScanning;

  const _ConnectionOverviewCard({
    required this.connectedCount,
    required this.connectingCount,
    required this.totalCount,
    required this.lastScanLabel,
    required this.message,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : connectedCount / totalCount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.surfaceElevated,
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IoT Link Matrix',
                        style: AppTypography.h2.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track mobile readiness, subnet discovery, and endpoint health before launching the next PoseTrack session.',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subnet',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '192.168.1.x',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 320;
                final tileWidth = useTwoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                final tiles = [
                  MetricPill(
                    label: 'Endpoints Ready',
                    value:
                        '$connectedCount / ${totalCount == 0 ? 2 : totalCount}',
                    icon: Icons.verified_rounded,
                    highlighted: connectedCount > 0,
                  ),
                  MetricPill(
                    label: 'Live Handshakes',
                    value: '$connectingCount',
                    icon: Icons.sync_rounded,
                    highlighted: connectingCount > 0,
                  ),
                  MetricPill(
                    label: 'Last Scan',
                    value: lastScanLabel,
                    icon: Icons.radar_rounded,
                  ),
                ];

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: tiles
                      .map((tile) => SizedBox(width: tileWidth, child: tile))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Connection Readiness',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.86),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.background.withValues(alpha: 0.45),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isScanning ? AppColors.accentSoft : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isScanning ? AppColors.accentSoft : AppColors.primary)
                      .withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isScanning)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accentSoft,
                        ),
                      ),
                    )
                  else
                    Icon(
                      connectedCount == totalCount && totalCount > 0
                          ? Icons.task_alt_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: connectedCount == totalCount && totalCount > 0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.86),
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceConnectionCard extends StatelessWidget {
  final DeviceConnectionNode device;
  final bool isBusy;
  final bool isScanning;
  final VoidCallback onScan;
  final VoidCallback onConnect;
  final VoidCallback onReconnect;

  const _DeviceConnectionCard({
    required this.device,
    required this.isBusy,
    required this.isScanning,
    required this.onScan,
    required this.onConnect,
    required this.onReconnect,
  });

  Color get _accent => switch (device.status) {
    DeviceLinkStatus.connected => AppColors.primary,
    DeviceLinkStatus.disconnected => AppColors.warning,
    DeviceLinkStatus.connecting => AppColors.accentSoft,
  };

  bool get _canConnect =>
      !isScanning && !isBusy && device.status != DeviceLinkStatus.connected;

  bool get _canReconnect => !isScanning && !isBusy;

  bool get _canScan => !isScanning && !isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _accent.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EndpointIconBadge(endpoint: device.endpoint, accent: _accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: AppTypography.h3.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.role,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ConnectionStateChip(status: device.status),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 320;
                final tileWidth = useTwoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: _DeviceStatTile(
                        label: 'IP Address',
                        value: device.ipAddress,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _DeviceStatTile(
                        label: 'Link',
                        value: device.transport,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _DeviceStatTile(
                        label: device.metricLabel,
                        value: device.metricValue,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _DeviceStatTile(
                        label: 'Last Pulse',
                        value: device.lastSeen,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (device.status) {
                      DeviceLinkStatus.connected => Icons.task_alt_rounded,
                      DeviceLinkStatus.disconnected => Icons.portable_wifi_off,
                      DeviceLinkStatus.connecting => Icons.sync_rounded,
                    },
                    size: 18,
                    color: _accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      device.statusDetail,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.86),
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isBusy) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: AppColors.backgroundSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentSoft,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InlineActionButton(
                  label: 'Scan',
                  icon: Icons.radar_rounded,
                  accent: AppColors.accentSoft,
                  onTap: _canScan ? onScan : null,
                ),
                _InlineActionButton(
                  label: 'Connect',
                  icon: Icons.link_rounded,
                  accent: AppColors.primary,
                  isPrimary: true,
                  onTap: _canConnect ? onConnect : null,
                ),
                _InlineActionButton(
                  label: 'Reconnect',
                  icon: Icons.refresh_rounded,
                  accent: AppColors.primary,
                  onTap: _canReconnect ? onReconnect : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionFooterHint extends StatelessWidget {
  final bool isReady;
  final int connectedCount;
  final int totalCount;

  const _ConnectionFooterHint({
    required this.isReady,
    required this.connectedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isReady ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.check_circle_outline_rounded : Icons.bolt_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isReady
                  ? 'Both endpoints are locked in. Continue to Capture to start the mobile recording flow.'
                  : '$connectedCount of ${totalCount == 0 ? 2 : totalCount} endpoints are connected. Finish both links to unlock capture.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Loading mock device telemetry and connection health...',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.86),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.68)),
          ),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _EndpointIconBadge extends StatelessWidget {
  final DeviceEndpoint endpoint;
  final Color accent;

  const _EndpointIconBadge({required this.endpoint, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 16),
        ],
      ),
      child: Icon(
        switch (endpoint) {
          DeviceEndpoint.raspberryPi => Icons.memory_rounded,
          DeviceEndpoint.processingServer => Icons.dns_rounded,
        },
        size: 22,
        color: accent,
      ),
    );
  }
}

class _ConnectionStateChip extends StatelessWidget {
  final DeviceLinkStatus status;

  const _ConnectionStateChip({required this.status});

  Color get _color => switch (status) {
    DeviceLinkStatus.connected => AppColors.success,
    DeviceLinkStatus.disconnected => AppColors.warning,
    DeviceLinkStatus.connecting => AppColors.primary,
  };

  String get _label => switch (status) {
    DeviceLinkStatus.connected => 'Connected',
    DeviceLinkStatus.disconnected => 'Offline',
    DeviceLinkStatus.connecting => 'Connecting',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: 0.42),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label.toUpperCase(),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatTile extends StatelessWidget {
  final String label;
  final String value;

  const _DeviceStatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _InlineActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isPrimary
                  ? accent.withValues(alpha: 0.16)
                  : AppColors.background.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isPrimary
                    ? accent.withValues(alpha: 0.36)
                    : AppColors.border.withValues(alpha: 0.62),
              ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.12),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isPrimary ? accent : AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isPrimary ? accent : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _ConnectionGridPainter extends CustomPainter {
  const _ConnectionGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const step = 42.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
