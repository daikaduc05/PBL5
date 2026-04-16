import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../navigation/app_routes.dart';
import '../services/mock_pose_tracking_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MockPoseTrackingService _poseService = MockPoseTrackingService();

  List<PoseHistorySession> _sessions = const [];
  bool _isLoading = true;
  _HistoryFilter _selectedFilter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final sessions = await _poseService.getHistory();

    if (!mounted) {
      return;
    }

    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _openSession(PoseHistorySession session) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.results, arguments: session.toResult());
  }

  int _countForFilter(_HistoryFilter filter) {
    if (filter == _HistoryFilter.all) {
      return _sessions.length;
    }

    return _sessions.where((session) => filter.matches(session)).length;
  }

  List<PoseHistorySession> get _visibleSessions {
    if (_selectedFilter == _HistoryFilter.all) {
      return _sessions;
    }

    return _sessions
        .where((session) => _selectedFilter.matches(session))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleSessions = _visibleSessions;
    final latestSession = _sessions.isNotEmpty ? _sessions.first : null;
    final statusColor = _isLoading ? AppColors.primary : AppColors.success;
    final statusLabel = _isLoading ? 'Syncing Archive' : 'Archive Live';

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'History',
                subtitle:
                    'Review previous PoseTrack mobile sessions with status, timestamps, and quick result notes.',
                onBackPressed: _goHome,
                trailing: StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  icon: Icons.history_toggle_off_rounded,
                ),
              ),
              const SizedBox(height: 24),
              _HistoryOverviewPanel(
                isLoading: _isLoading,
                selectedFilter: _selectedFilter,
                latestSession: latestSession,
                totalCount: _sessions.length,
                completedCount: _countForFilter(_HistoryFilter.completed),
                processingCount: _countForFilter(_HistoryFilter.processing),
                failedCount: _countForFilter(_HistoryFilter.failed),
                onFilterSelected: (filter) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
              const SizedBox(height: 18),
              _HistorySectionHeader(
                activeFilter: _selectedFilter,
                visibleCount: visibleSessions.length,
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 90),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                )
              else if (visibleSessions.isEmpty)
                _EmptyHistoryState(selectedFilter: _selectedFilter)
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Column(
                    key: ValueKey(_selectedFilter),
                    children: visibleSessions
                        .map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _HistoryCard(
                              session: session,
                              onTap: () => _openSession(session),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Back to Home',
                  onPressed: _goHome,
                  isSecondary: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _HistoryFilter {
  all,
  completed,
  processing,
  failed;

  String get label => switch (this) {
    _HistoryFilter.all => 'All Sessions',
    _HistoryFilter.completed => 'Completed',
    _HistoryFilter.processing => 'Processing',
    _HistoryFilter.failed => 'Failed',
  };

  String get shortLabel => switch (this) {
    _HistoryFilter.all => 'All',
    _HistoryFilter.completed => 'Done',
    _HistoryFilter.processing => 'Live',
    _HistoryFilter.failed => 'Retry',
  };

  String get emptyLabel => switch (this) {
    _HistoryFilter.all => 'No history sessions yet.',
    _HistoryFilter.completed => 'No completed sessions available.',
    _HistoryFilter.processing => 'No sessions are currently processing.',
    _HistoryFilter.failed => 'No failed sessions to review.',
  };

  String get description => switch (this) {
    _HistoryFilter.all =>
      'Newest captures first with quick visibility into completed, active, and failed runs.',
    _HistoryFilter.completed =>
      'Completed sessions with stable pose estimation results and archived summaries.',
    _HistoryFilter.processing =>
      'Sessions still moving through upload, server processing, or inference packaging.',
    _HistoryFilter.failed =>
      'Sessions that need a re-capture because lighting, framing, or movement reduced quality.',
  };

  Color get accent => switch (this) {
    _HistoryFilter.all => AppColors.primary,
    _HistoryFilter.completed => AppColors.success,
    _HistoryFilter.processing => AppColors.primary,
    _HistoryFilter.failed => AppColors.error,
  };

  bool matches(PoseHistorySession session) {
    return switch (this) {
      _HistoryFilter.all => true,
      _HistoryFilter.completed => session.state == SessionState.completed,
      _HistoryFilter.processing => session.state == SessionState.processing,
      _HistoryFilter.failed => session.state == SessionState.failed,
    };
  }
}

class _HistoryOverviewPanel extends StatelessWidget {
  final bool isLoading;
  final _HistoryFilter selectedFilter;
  final PoseHistorySession? latestSession;
  final int totalCount;
  final int completedCount;
  final int processingCount;
  final int failedCount;
  final ValueChanged<_HistoryFilter> onFilterSelected;

  const _HistoryOverviewPanel({
    required this.isLoading,
    required this.selectedFilter,
    required this.latestSession,
    required this.totalCount,
    required this.completedCount,
    required this.processingCount,
    required this.failedCount,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumnLayout = constraints.maxWidth < 360;

              final archiveBubble = _ArchiveHeroBubble(
                value: totalCount.toString().padLeft(2, '0'),
                label: 'Stored Sessions',
                accent: AppColors.primary,
              );

              if (useColumnLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OverviewCopy(
                      latestSession: latestSession,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 18),
                    Center(child: archiveBubble),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _OverviewCopy(
                      latestSession: latestSession,
                      isLoading: isLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  archiveBubble,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ArchiveMetricTile(
                  label: 'Completed',
                  value: completedCount.toString(),
                  accent: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ArchiveMetricTile(
                  label: 'Processing',
                  value: processingCount.toString(),
                  accent: AppColors.primary,
                  icon: Icons.motion_photos_on_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ArchiveMetricTile(
                  label: 'Failed',
                  value: failedCount.toString(),
                  accent: AppColors.error,
                  icon: Icons.error_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Filter Sessions',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _HistoryFilter.values
                .map(
                  (filter) => _HistoryFilterChip(
                    label: filter.shortLabel,
                    count: switch (filter) {
                      _HistoryFilter.all => totalCount,
                      _HistoryFilter.completed => completedCount,
                      _HistoryFilter.processing => processingCount,
                      _HistoryFilter.failed => failedCount,
                    },
                    accent: filter.accent,
                    isSelected: filter == selectedFilter,
                    onTap: () => onFilterSelected(filter),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _OverviewCopy extends StatelessWidget {
  final PoseHistorySession? latestSession;
  final bool isLoading;

  const _OverviewCopy({
    required this.latestSession,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final latestLabel = latestSession == null
        ? 'Waiting for the first session capture'
        : 'Latest capture ${formatShortDateTime(latestSession!.capturedAt)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Text(
            'SESSION ARCHIVE',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Scrollable mobile history for previous pose estimation runs.',
          style: AppTypography.h2.copyWith(fontSize: 24, height: 1.08),
        ),
        const SizedBox(height: 8),
        Text(
          'Each session card keeps a thumbnail preview, capture time, processing state, and a short AI summary ready for demo walkthroughs.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _OverviewInfoPill(
              icon: Icons.schedule_rounded,
              label: latestLabel,
            ),
            _OverviewInfoPill(
              icon: Icons.swap_vert_rounded,
              label: isLoading ? 'Refreshing archive' : 'Newest first order',
            ),
          ],
        ),
      ],
    );
  }
}

class _ArchiveHeroBubble extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;

  const _ArchiveHeroBubble({
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withValues(alpha: 0.9),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTypography.h1.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  const _ArchiveMetricTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverviewInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _HistoryFilterChip({
    required this.label,
    required this.count,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.16)
                : AppColors.background.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.36)
                  : AppColors.border.withValues(alpha: 0.72),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySectionHeader extends StatelessWidget {
  final _HistoryFilter activeFilter;
  final int visibleCount;

  const _HistorySectionHeader({
    required this.activeFilter,
    required this.visibleCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeFilter.label,
                style: AppTypography.h3.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 4),
              Text(
                activeFilter.description,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  height: 1.24,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: activeFilter.accent.withValues(alpha: 0.26),
            ),
          ),
          child: Text(
            '$visibleCount shown',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final _HistoryFilter selectedFilter;

  const _EmptyHistoryState({required this.selectedFilter});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectedFilter.accent.withValues(alpha: 0.12),
                border: Border.all(
                  color: selectedFilter.accent.withValues(alpha: 0.24),
                ),
              ),
              child: Icon(
                Icons.history_rounded,
                color: selectedFilter.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              selectedFilter.emptyLabel,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Change the filter or create a new capture session to populate this mobile archive.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PoseHistorySession session;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.session,
    required this.onTap,
  });

  Color get _accent => switch (session.state) {
    SessionState.completed => AppColors.success,
    SessionState.processing => AppColors.primary,
    SessionState.failed => AppColors.error,
  };

  String get _statusLabel => switch (session.state) {
    SessionState.completed => 'Completed',
    SessionState.processing => 'Processing',
    SessionState.failed => 'Failed',
  };

  IconData get _statusIcon => switch (session.state) {
    SessionState.completed => Icons.check_circle_outline_rounded,
    SessionState.processing => Icons.motion_photos_on_rounded,
    SessionState.failed => Icons.error_outline_rounded,
  };

  String get _captureTypeLabel => switch (session.mode) {
    CaptureMode.image => 'Single frame',
    CaptureMode.video => '${session.durationSeconds}s clip',
  };

  String get _metricLabel => switch (session.state) {
    SessionState.completed =>
      '${session.keypointsDetected}/${session.keypointsTotal} keypoints',
    SessionState.processing => 'Server pipeline active',
    SessionState.failed => 'Re-capture recommended',
  };

  String get _footerLabel => switch (session.state) {
    SessionState.completed => 'Tap to reopen the processed mobile result.',
    SessionState.processing =>
      'Tap to inspect the latest status snapshot for this session.',
    SessionState.failed =>
      'Tap to review the failed output and explain the retry case in the demo.',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accent.withValues(alpha: 0.12),
                AppColors.surfaceElevated,
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _accent.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: _accent.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HistoryThumbnail(
                      session: session,
                      accent: _accent,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
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
                                      formatShortDate(session.capturedAt),
                                      style:
                                          AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textMuted,
                                            fontSize: 12.5,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      session.title,
                                      style: AppTypography.h3.copyWith(
                                        fontSize: 18,
                                        height: 1.12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              StatusBadge(
                                label: _statusLabel,
                                color: _accent,
                                icon: _statusIcon,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SessionTag(
                                icon: Icons.schedule_rounded,
                                label: _formatTime(session.capturedAt),
                              ),
                              _SessionTag(
                                icon: session.mode == CaptureMode.video
                                    ? Icons.videocam_rounded
                                    : Icons.image_rounded,
                                label: session.mode.label,
                              ),
                              _SessionTag(
                                icon: Icons.badge_rounded,
                                label: session.sessionId,
                                highlight: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            session.summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.9,
                              ),
                              fontSize: 14.5,
                              height: 1.22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _CardDetailPill(
                      icon: Icons.tune_rounded,
                      label: 'Capture',
                      value: _captureTypeLabel,
                    ),
                    _CardDetailPill(
                      icon: Icons.auto_graph_rounded,
                      label: 'Confidence',
                      value:
                          '${(session.confidence * 100).toStringAsFixed(1)}%',
                    ),
                    _CardDetailPill(
                      icon: Icons.accessibility_new_rounded,
                      label: 'Summary',
                      value: _metricLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusIcon,
                        size: 18,
                        color: _accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _footerLabel,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                            height: 1.18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
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

class _SessionTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _SessionTag({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.background.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.26)
              : AppColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? AppColors.primary : AppColors.accentSoft,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CardDetailPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.68)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 12.5,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryThumbnail extends StatelessWidget {
  final PoseHistorySession session;
  final Color accent;

  const _HistoryThumbnail({
    required this.session,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            AppColors.backgroundSecondary,
            AppColors.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HistoryThumbnailPainter(
                  session: session,
                  accent: accent,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.46),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Text(
                  session.mode.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryThumbnailPainter extends CustomPainter {
  final PoseHistorySession session;
  final Color accent;

  const _HistoryThumbnailPainter({
    required this.session,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scanPaint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (double y = 8; y <= size.height - 22; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    final framePaint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 34),
      const Radius.circular(16),
    );
    canvas.drawRRect(frame, framePaint);

    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.78)
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    final nodePaint = Paint()..color = accent;

    final points = _posePoints(size);

    canvas.drawLine(points.head, points.neck, linePaint);
    canvas.drawLine(points.neck, points.leftShoulder, linePaint);
    canvas.drawLine(points.neck, points.rightShoulder, linePaint);
    canvas.drawLine(points.leftShoulder, points.leftHand, linePaint);
    canvas.drawLine(points.rightShoulder, points.rightHand, linePaint);
    canvas.drawLine(points.neck, points.hip, linePaint);
    canvas.drawLine(points.hip, points.leftKnee, linePaint);
    canvas.drawLine(points.hip, points.rightKnee, linePaint);
    canvas.drawLine(points.leftKnee, points.leftFoot, linePaint);
    canvas.drawLine(points.rightKnee, points.rightFoot, linePaint);

    for (final point in points.values) {
      canvas.drawCircle(point, 3.1, nodePaint);
    }
  }

  _PosePoints _posePoints(Size size) {
    return switch (session.state) {
      SessionState.completed => _PosePoints(
        head: Offset(size.width * 0.53, size.height * 0.2),
        neck: Offset(size.width * 0.53, size.height * 0.33),
        leftShoulder: Offset(size.width * 0.38, size.height * 0.39),
        rightShoulder: Offset(size.width * 0.67, size.height * 0.38),
        leftHand: Offset(size.width * 0.29, size.height * 0.56),
        rightHand: Offset(size.width * 0.74, size.height * 0.52),
        hip: Offset(size.width * 0.53, size.height * 0.58),
        leftKnee: Offset(size.width * 0.43, size.height * 0.73),
        rightKnee: Offset(size.width * 0.61, size.height * 0.72),
        leftFoot: Offset(size.width * 0.39, size.height * 0.88),
        rightFoot: Offset(size.width * 0.64, size.height * 0.87),
      ),
      SessionState.processing => _PosePoints(
        head: Offset(size.width * 0.52, size.height * 0.2),
        neck: Offset(size.width * 0.52, size.height * 0.33),
        leftShoulder: Offset(size.width * 0.4, size.height * 0.41),
        rightShoulder: Offset(size.width * 0.63, size.height * 0.34),
        leftHand: Offset(size.width * 0.28, size.height * 0.62),
        rightHand: Offset(size.width * 0.76, size.height * 0.24),
        hip: Offset(size.width * 0.52, size.height * 0.58),
        leftKnee: Offset(size.width * 0.43, size.height * 0.73),
        rightKnee: Offset(size.width * 0.62, size.height * 0.74),
        leftFoot: Offset(size.width * 0.39, size.height * 0.88),
        rightFoot: Offset(size.width * 0.66, size.height * 0.87),
      ),
      SessionState.failed => _PosePoints(
        head: Offset(size.width * 0.47, size.height * 0.21),
        neck: Offset(size.width * 0.5, size.height * 0.34),
        leftShoulder: Offset(size.width * 0.36, size.height * 0.43),
        rightShoulder: Offset(size.width * 0.64, size.height * 0.4),
        leftHand: Offset(size.width * 0.22, size.height * 0.63),
        rightHand: Offset(size.width * 0.74, size.height * 0.56),
        hip: Offset(size.width * 0.52, size.height * 0.59),
        leftKnee: Offset(size.width * 0.44, size.height * 0.72),
        rightKnee: Offset(size.width * 0.58, size.height * 0.76),
        leftFoot: Offset(size.width * 0.33, size.height * 0.86),
        rightFoot: Offset(size.width * 0.63, size.height * 0.9),
      ),
    };
  }

  @override
  bool shouldRepaint(covariant _HistoryThumbnailPainter oldDelegate) {
    return oldDelegate.session != session || oldDelegate.accent != accent;
  }
}

class _PosePoints {
  final Offset head;
  final Offset neck;
  final Offset leftShoulder;
  final Offset rightShoulder;
  final Offset leftHand;
  final Offset rightHand;
  final Offset hip;
  final Offset leftKnee;
  final Offset rightKnee;
  final Offset leftFoot;
  final Offset rightFoot;

  const _PosePoints({
    required this.head,
    required this.neck,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHand,
    required this.rightHand,
    required this.hip,
    required this.leftKnee,
    required this.rightKnee,
    required this.leftFoot,
    required this.rightFoot,
  });

  List<Offset> get values => [
    head,
    neck,
    leftShoulder,
    rightShoulder,
    leftHand,
    rightHand,
    hip,
    leftKnee,
    rightKnee,
    leftFoot,
    rightFoot,
  ];
}

String _formatTime(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
