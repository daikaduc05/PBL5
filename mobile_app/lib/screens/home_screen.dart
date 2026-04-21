import 'package:flutter/material.dart';

import '../components/action_shortcut_card.dart';
import '../components/app_button.dart';
import '../components/metric_pill.dart';
import '../components/screen_container.dart';
import '../components/section_title.dart';
import '../components/session_summary_card.dart';
import '../components/status_card.dart';
import '../navigation/app_routes.dart';
import '../services/api_service.dart';
import '../services/mock_device_connection_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<_DashboardAction> _actions = [
    _DashboardAction(
      title: 'Connect Device',
      subtitle: 'Refresh backend and Pi status',
      icon: Icons.usb_rounded,
      route: AppRoutes.deviceConnection,
      isPrimary: true,
    ),
    _DashboardAction(
      title: 'Start Capture',
      subtitle: 'Launch image or video capture',
      icon: Icons.play_circle_fill_rounded,
      route: AppRoutes.capture,
      isPrimary: true,
    ),
    _DashboardAction(
      title: 'View Results',
      subtitle: 'Browse processed backend sessions',
      icon: Icons.analytics_rounded,
      route: AppRoutes.resultSessions,
    ),
    _DashboardAction(
      title: 'History',
      subtitle: 'Review canonical capture runs',
      icon: Icons.history_rounded,
      route: AppRoutes.history,
    ),
    _DashboardAction(
      title: 'Settings',
      subtitle: 'Tune network and defaults',
      icon: Icons.settings_suggest_rounded,
      route: AppRoutes.settings,
      isWide: true,
    ),
  ];

  final ApiService _api = ApiService();
  final DeviceConnectionService _connectionService = DeviceConnectionService();

  _DashboardSnapshot? _snapshot;
  bool _isLoading = true;
  String? _loadErrorMessage;
  String? _historyWarningMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
      _historyWarningMessage = null;
    });

    try {
      final devices = await _connectionService.getDevices();
      List<HistoryItem> history = const [];
      String? historyWarningMessage;

      try {
        history = await _api.getHistory();
      } catch (error) {
        historyWarningMessage = extractApiError(error);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _DashboardSnapshot(
          devices: devices,
          history: history,
          loadedAt: DateTime.now(),
        );
        _historyWarningMessage = historyWarningMessage;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = null;
        _loadErrorMessage = extractApiError(error);
        _isLoading = false;
      });
    }
  }

  void _openRoute(String route) {
    Navigator.of(context).pushNamed(route);
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
                  top: -100,
                  right: -70,
                  child: _GlowOrb(size: 240, color: AppColors.primary),
                ),
                const Positioned(
                  left: -80,
                  bottom: 120,
                  child: _GlowOrb(size: 190, color: AppColors.accent),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: const _DashboardGridPainter()),
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
                            _DashboardHeader(
                              snapshot: _snapshot,
                              isLoading: _isLoading,
                              loadErrorMessage: _loadErrorMessage,
                              historyWarningMessage: _historyWarningMessage,
                            ),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'System Overview',
                              subtitle:
                                  'Live runtime status for the AI pose pipeline before the next capture.',
                            ),
                            const SizedBox(height: 16),
                            if (_isLoading && _snapshot == null)
                              const _LoadingCard(
                                title: 'Loading dashboard',
                                message:
                                    'Refreshing backend health, device status, and recent run history.',
                              )
                            else if (_loadErrorMessage != null)
                              _MessageCard(
                                title: 'Dashboard unavailable',
                                message: _loadErrorMessage!,
                                accent: AppColors.warning,
                              )
                            else if (_snapshot != null)
                              _OverviewCard(
                                snapshot: _snapshot!,
                                historyWarningMessage: _historyWarningMessage,
                                onRefresh: _loadDashboard,
                                isRefreshing: _isLoading,
                              ),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'Live Services',
                              subtitle:
                                  'Resolved backend and Raspberry Pi status using the current configured addresses.',
                            ),
                            const SizedBox(height: 16),
                            if (_snapshot == null)
                              const _MessageCard(
                                title: 'No live service data',
                                message:
                                    'Dashboard data is still unavailable. Refresh after the backend becomes reachable.',
                              )
                            else ...[
                              _ServiceStatusCard(
                                node: _snapshot!.nodeFor(
                                  DeviceEndpoint.raspberryPi,
                                ),
                                fallbackTitle: 'Raspberry Pi',
                                fallbackSubtitle: 'Edge Capture Node',
                                fallbackFooter:
                                    'The app has not resolved Raspberry Pi status yet.',
                              ),
                              const SizedBox(height: 12),
                              _ServiceStatusCard(
                                node: _snapshot!.nodeFor(
                                  DeviceEndpoint.processingServer,
                                ),
                                fallbackTitle: 'Processing Server',
                                fallbackSubtitle: 'Pose Processing Backend',
                                fallbackFooter:
                                    'The app has not resolved backend status yet.',
                              ),
                            ],
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'Recent Run',
                              subtitle:
                                  'Most recent canonical capture run recorded by the backend history API.',
                            ),
                            const SizedBox(height: 16),
                            _LatestRunCard(
                              run: _snapshot?.latestRun,
                              historyWarningMessage: _historyWarningMessage,
                            ),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'Quick Actions',
                              subtitle:
                                  'Primary actions for the current backend-driven PoseTrack flow.',
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final useTwoColumns =
                                    constraints.maxWidth >= 360;
                                final cardWidth = useTwoColumns
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth;

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: _actions
                                      .map(
                                        (action) => SizedBox(
                                          width: action.isWide
                                              ? constraints.maxWidth
                                              : cardWidth,
                                          child: ActionShortcutCard(
                                            title: action.title,
                                            subtitle: action.subtitle,
                                            icon: action.icon,
                                            isPrimary: action.isPrimary,
                                            onTap: () => _openRoute(action.route),
                                          ),
                                        ),
                                      )
                                      .toList(),
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

class _DashboardHeader extends StatelessWidget {
  final _DashboardSnapshot? snapshot;
  final bool isLoading;
  final String? loadErrorMessage;
  final String? historyWarningMessage;

  const _DashboardHeader({
    required this.snapshot,
    required this.isLoading,
    required this.loadErrorMessage,
    required this.historyWarningMessage,
  });

  @override
  Widget build(BuildContext context) {
    final readyCount = snapshot?.connectedCount ?? 0;
    final totalCount = snapshot?.totalCount ?? 2;
    final chipTwoLabel = historyWarningMessage == null
        ? '${snapshot?.history.length ?? 0} runs tracked'
        : 'history limited';
    final bannerText = _buildBannerText();
    final bannerAccent = loadErrorMessage != null
        ? AppColors.warning
        : (snapshot?.allConnected ?? false)
        ? AppColors.success
        : AppColors.primary;

    return Column(
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
                    'PoseTrack',
                    style: AppTypography.h1.copyWith(
                      fontSize: 30,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Human pose estimation dashboard for Raspberry Pi capture, backend processing, and result review.',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderChip(
                        icon: Icons.sensors_rounded,
                        label: '$readyCount/$totalCount endpoints ready',
                      ),
                      _HeaderChip(
                        icon: Icons.auto_graph_rounded,
                        label: chipTwoLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.accessibility_new_rounded,
                color: AppColors.background,
                size: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: bannerAccent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(
                loadErrorMessage != null
                    ? Icons.error_outline_rounded
                    : isLoading
                    ? Icons.sync_rounded
                    : Icons.bolt_rounded,
                size: 18,
                color: bannerAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bannerText,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.88),
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bannerAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: bannerAccent.withValues(alpha: 0.34),
                  ),
                ),
                child: Text(
                  _buildBannerBadge(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: bannerAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildBannerText() {
    if (loadErrorMessage != null) {
      return 'Dashboard data is unavailable right now. Check the configured server address and refresh again.';
    }

    if (isLoading && snapshot == null) {
      return 'Refreshing live backend status, Raspberry Pi heartbeat, and recent run history.';
    }

    if (snapshot == null) {
      return 'Dashboard data has not loaded yet.';
    }

    if (snapshot!.allConnected) {
      return 'Backend and Raspberry Pi are both ready for the next capture run.';
    }

    if (snapshot!.connectedCount == 0) {
      return 'Neither endpoint is currently ready. Use Connect to inspect the backend and Pi status.';
    }

    return '${snapshot!.connectedCount} of ${snapshot!.totalCount} endpoints are ready. Refresh the remaining service before capture.';
  }

  String _buildBannerBadge() {
    if (loadErrorMessage != null) {
      return 'CHECK';
    }
    if (isLoading && snapshot == null) {
      return 'LOADING';
    }
    if (snapshot?.allConnected ?? false) {
      return 'READY';
    }
    return 'LIVE';
  }
}

class _OverviewCard extends StatelessWidget {
  final _DashboardSnapshot snapshot;
  final String? historyWarningMessage;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  const _OverviewCard({
    required this.snapshot,
    required this.historyWarningMessage,
    required this.onRefresh,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final readinessPercent = (snapshot.readiness * 100).round();

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
            blurRadius: 26,
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
                        'Mission Control',
                        style: AppTypography.h2.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This dashboard now reflects live backend-driven status instead of a fixed demo snapshot.',
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
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Readiness',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$readinessPercent%',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
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
                    label: 'Devices Online',
                    value: '${snapshot.connectedCount}/${snapshot.totalCount}',
                    icon: Icons.router_rounded,
                    highlighted: true,
                  ),
                  MetricPill(
                    label: 'In Flight',
                    value: '${snapshot.activeRuns}',
                    icon: Icons.sync_rounded,
                  ),
                  MetricPill(
                    label: 'Captures Today',
                    value: '${snapshot.runsToday}',
                    icon: Icons.videocam_rounded,
                  ),
                  MetricPill(
                    label: 'Failed Runs',
                    value: '${snapshot.failedRuns}',
                    icon: Icons.warning_amber_rounded,
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
              'Pipeline Sync',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.86),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: snapshot.readiness,
                minHeight: 8,
                backgroundColor: AppColors.background.withValues(alpha: 0.45),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MessageCard(
              title: historyWarningMessage == null ? null : 'History warning',
              message: historyWarningMessage ??
                  'Last refresh completed at ${formatShortDateTime(snapshot.loadedAt)}. Use Connect for endpoint-level checks or History for detailed runs.',
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Refresh Dashboard',
              onPressed: () {
                onRefresh();
              },
              isLoading: isRefreshing,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceStatusCard extends StatelessWidget {
  final DeviceConnectionNode? node;
  final String fallbackTitle;
  final String fallbackSubtitle;
  final String fallbackFooter;

  const _ServiceStatusCard({
    required this.node,
    required this.fallbackTitle,
    required this.fallbackSubtitle,
    required this.fallbackFooter,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedNode = node;
    if (resolvedNode == null) {
      return StatusCard(
        title: fallbackTitle,
        subtitle: fallbackSubtitle,
        icon: Icons.device_unknown_rounded,
        isConnected: false,
        statusLabel: 'Unknown',
        highlights: const [
          StatusHighlight(label: 'Address', value: 'Unavailable'),
          StatusHighlight(label: 'Link', value: 'Unavailable'),
          StatusHighlight(label: 'Status', value: 'Unknown'),
          StatusHighlight(label: 'Last Seen', value: 'Unknown'),
        ],
        footer: fallbackFooter,
      );
    }

    return StatusCard(
      title: resolvedNode.name,
      subtitle: resolvedNode.role,
      icon: resolvedNode.endpoint == DeviceEndpoint.raspberryPi
          ? Icons.memory_rounded
          : Icons.cloud_done_rounded,
      isConnected: resolvedNode.status == DeviceLinkStatus.connected,
      statusLabel: switch (resolvedNode.status) {
        DeviceLinkStatus.connected => 'Ready',
        DeviceLinkStatus.disconnected => 'Offline',
        DeviceLinkStatus.connecting => 'Refreshing',
      },
      highlights: [
        StatusHighlight(label: 'Address', value: resolvedNode.ipAddress),
        StatusHighlight(label: 'Link', value: resolvedNode.transport),
        StatusHighlight(
          label: resolvedNode.metricLabel,
          value: resolvedNode.metricValue,
        ),
        StatusHighlight(label: 'Last Seen', value: resolvedNode.lastSeen),
      ],
      footer: resolvedNode.statusDetail,
    );
  }
}

class _LatestRunCard extends StatelessWidget {
  final HistoryItem? run;
  final String? historyWarningMessage;

  const _LatestRunCard({
    required this.run,
    required this.historyWarningMessage,
  });

  @override
  Widget build(BuildContext context) {
    final latestRun = run;
    if (latestRun == null) {
      return _MessageCard(
        title: 'No backend runs yet',
        message: historyWarningMessage ??
            'The history API returned no capture runs yet. Start a capture from the app, then refresh the dashboard.',
      );
    }

    return SessionSummaryCard(
      sessionId: latestRun.sessionKey,
      title: _runTitle(latestRun),
      summary: _runSummary(latestRun),
      confidenceLabel: 'Status',
      confidence: _displayStatus(latestRun.status),
      keypointsLabel: 'Command',
      keypoints: _displayCommand(latestRun.commandType),
      durationLabel: 'Progress',
      duration: '${latestRun.progress}%',
      timestamp: formatSessionTimestamp(latestRun.createdAt.toLocal()),
      badgeLabel: 'LATEST RUN',
    );
  }

  String _runTitle(HistoryItem item) {
    return switch (item.commandType) {
      'capture_photo' => 'Single Frame Pose Run',
      'start_recording' => 'Motion Capture Pose Run',
      _ => 'Capture Pipeline Run',
    };
  }

  String _runSummary(HistoryItem item) {
    return switch (item.status) {
      'done' =>
        'The backend has finished packaging this run and the processed result session is ready to open.',
      'processing' =>
        'This run is still moving through the command and result pipeline. Open History for more detail.',
      'failed' =>
        'This run did not complete cleanly. Check the device heartbeat, backend logs, and generated result files.',
      _ =>
        'This run is queued and waiting for the Raspberry Pi agent to continue the capture pipeline.',
    };
  }

  String _displayStatus(String status) {
    return switch (status) {
      'done' => 'DONE',
      'processing' => 'PROCESSING',
      'failed' => 'FAILED',
      'queued' => 'QUEUED',
      _ => status.toUpperCase(),
    };
  }

  String _displayCommand(String commandType) {
    return switch (commandType) {
      'capture_photo' => 'Photo',
      'start_recording' => 'Video',
      _ => commandType,
    };
  }
}

class _LoadingCard extends StatelessWidget {
  final String title;
  final String message;

  const _LoadingCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.84),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String? title;
  final String message;
  final Color accent;

  const _MessageCard({
    this.title,
    required this.message,
    this.accent = AppColors.accentSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            title == null ? Icons.sync_rounded : Icons.info_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.84),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.62)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.88),
              fontSize: 13,
            ),
          ),
        ],
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

class _DashboardGridPainter extends CustomPainter {
  const _DashboardGridPainter();

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

class _DashboardAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool isPrimary;
  final bool isWide;

  const _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.isPrimary = false,
    this.isWide = false,
  });
}

class _DashboardSnapshot {
  final List<DeviceConnectionNode> devices;
  final List<HistoryItem> history;
  final DateTime loadedAt;

  const _DashboardSnapshot({
    required this.devices,
    required this.history,
    required this.loadedAt,
  });

  int get totalCount => devices.isEmpty ? 2 : devices.length;

  int get connectedCount => devices
      .where((device) => device.status == DeviceLinkStatus.connected)
      .length;

  bool get allConnected =>
      devices.isNotEmpty &&
      devices.every((device) => device.status == DeviceLinkStatus.connected);

  double get readiness {
    if (devices.isEmpty) {
      return 0;
    }
    return connectedCount / devices.length;
  }

  int get activeRuns => history
      .where((item) => item.status == 'queued' || item.status == 'processing')
      .length;

  int get failedRuns =>
      history.where((item) => item.status == 'failed').length;

  int get runsToday => history
      .where((item) => _isSameDay(item.createdAt.toLocal(), loadedAt.toLocal()))
      .length;

  HistoryItem? get latestRun => history.isEmpty ? null : history.first;

  DeviceConnectionNode? nodeFor(DeviceEndpoint endpoint) {
    for (final device in devices) {
      if (device.endpoint == endpoint) {
        return device;
      }
    }
    return null;
  }
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
