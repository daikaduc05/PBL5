import 'package:flutter/material.dart';
import '../components/action_shortcut_card.dart';
import '../components/metric_pill.dart';
import '../components/screen_container.dart';
import '../components/section_title.dart';
import '../components/session_summary_card.dart';
import '../components/status_card.dart';
import '../navigation/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_DashboardAction> _actions = [
    _DashboardAction(
      title: 'Connect Device',
      subtitle: 'Pair Raspberry Pi and server',
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
      subtitle: 'Inspect recent pose outputs',
      icon: Icons.analytics_rounded,
      route: AppRoutes.results,
    ),
    _DashboardAction(
      title: 'History',
      subtitle: 'Browse previous sessions',
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
                            const _DashboardHeader(),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'System Overview',
                              subtitle:
                                  'Futuristic mobile control center for the AI pose pipeline.',
                            ),
                            const SizedBox(height: 16),
                            const _OverviewCard(),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'Live Services',
                              subtitle:
                                  'Edge device and server health before the next capture.',
                            ),
                            const SizedBox(height: 16),
                            const StatusCard(
                              title: 'Raspberry Pi 4',
                              subtitle:
                                  'Edge capture node is synced and streaming telemetry cleanly.',
                              icon: Icons.memory_rounded,
                              isConnected: true,
                              statusLabel: 'Linked',
                              highlights: [
                                StatusHighlight(
                                  label: 'IP Address',
                                  value: '192.168.1.24',
                                ),
                                StatusHighlight(
                                  label: 'Stream Rate',
                                  value: '42 FPS',
                                ),
                                StatusHighlight(
                                  label: 'Temperature',
                                  value: '47 C',
                                ),
                                StatusHighlight(
                                  label: 'Uptime',
                                  value: '08h 42m',
                                ),
                              ],
                              footer:
                                  'Heartbeat received 8 seconds ago with stable Wi-Fi and camera sync.',
                            ),
                            const SizedBox(height: 12),
                            const StatusCard(
                              title: 'Processing Server',
                              subtitle:
                                  'Inference backend is healthy and ready to analyze new sessions.',
                              icon: Icons.cloud_done_rounded,
                              isConnected: true,
                              statusLabel: 'Online',
                              highlights: [
                                StatusHighlight(
                                  label: 'API',
                                  value: 'FastAPI v1',
                                ),
                                StatusHighlight(
                                  label: 'Latency',
                                  value: '41 ms',
                                ),
                                StatusHighlight(
                                  label: 'Queue',
                                  value: '0 Jobs',
                                ),
                                StatusHighlight(
                                  label: 'Model',
                                  value: 'YOLOv8 Pose',
                                ),
                              ],
                              footer:
                                  'Pose engine loaded, queue is clear, and result serialization is available.',
                            ),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'Recent Session',
                              subtitle:
                                  'Quick summary of the latest processed capture.',
                            ),
                            const SizedBox(height: 16),
                            const SessionSummaryCard(
                              sessionId: 'PT-240414-08',
                              title: 'Standing Pose Calibration',
                              summary:
                                  'Pose detected successfully. Skeleton landmarks and confidence metrics are ready for review.',
                              confidence: '98.4%',
                              keypoints: '17/17',
                              duration: '12 s',
                              timestamp: 'Apr 14, 2026 - 14:26',
                            ),
                            const SizedBox(height: 24),
                            const SectionTitle(
                              title: 'Quick Actions',
                              subtitle:
                                  'Primary mobile actions for the engineering project demo.',
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
                                            onTap: () {
                                              Navigator.of(
                                                context,
                                              ).pushNamed(action.route);
                                            },
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
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
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
                    'Human pose estimation dashboard for Raspberry Pi, server processing, and AI capture control.',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _HeaderChip(
                        icon: Icons.sensors_rounded,
                        label: '2 systems synced',
                      ),
                      _HeaderChip(
                        icon: Icons.auto_graph_rounded,
                        label: 'demo mode ready',
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
            border: Border.all(color: AppColors.border.withValues(alpha: 0.68)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'System ready for capture and inference.',
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
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.34),
                  ),
                ),
                child: Text(
                  'READY',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.success,
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
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
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
                        'All core services are aligned for a polished mobile capture demo with edge streaming and server-side pose estimation.',
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
                        '96%',
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
                const tiles = [
                  MetricPill(
                    label: 'Devices Online',
                    value: '02 / 02',
                    icon: Icons.router_rounded,
                    highlighted: true,
                  ),
                  MetricPill(
                    label: 'Avg Latency',
                    value: '41 ms',
                    icon: Icons.speed_rounded,
                  ),
                  MetricPill(
                    label: 'Captures Today',
                    value: '08',
                    icon: Icons.videocam_rounded,
                  ),
                  MetricPill(
                    label: 'Model Status',
                    value: 'Loaded',
                    icon: Icons.psychology_alt_rounded,
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
                value: 0.96,
                minHeight: 8,
                backgroundColor: AppColors.background.withValues(alpha: 0.45),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.65),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_rounded,
                    size: 18,
                    color: AppColors.accentSoft,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edge stream locked, result queue clear, and server heartbeat stable.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.84),
                        fontSize: 13,
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
