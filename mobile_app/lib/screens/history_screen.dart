import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../navigation/app_routes.dart';
import '../services/backend_results_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final BackendResultsService _resultsService = BackendResultsService();

  List<ResultSessionSummary> _sessions = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _serverLabel;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serverLabel = await _resultsService.getConfiguredServerLabel();
      final sessions = await _resultsService.fetchSessions();

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
        _serverLabel = serverLabel;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _serverLabel = null;
        _sessions = const [];
        _errorMessage = extractBackendMessage(error);
        _isLoading = false;
      });
    }
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _openSession(ResultSessionSummary session) {
    Navigator.of(context).pushNamed(
      AppRoutes.results,
      arguments: ResultScreenArgs(
        sessionId: session.sessionId,
        initialFrameId: session.latestFrameId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _errorMessage == null
        ? (_isLoading ? AppColors.primary : AppColors.success)
        : AppColors.warning;
    final statusLabel = _errorMessage == null
        ? (_isLoading ? 'Loading API' : 'Backend Ready')
        : 'Check Backend';

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
                    'Browse processed backend sessions before wiring in live refresh or realtime updates.',
                onBackPressed: _goHome,
                trailing: StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  icon: Icons.history_rounded,
                ),
              ),
              const SizedBox(height: 24),
              _ArchiveHeroPanel(
                sessionCount: _sessions.length,
                totalFrames: _sessions.fold<int>(
                  0,
                  (total, session) => total + session.frameCount,
                ),
                readyJsonCount: _sessions.fold<int>(
                  0,
                  (total, session) => total + session.resultReadyCount,
                ),
                serverLabel: _serverLabel,
              ),
              const SizedBox(height: 18),
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
              else if (_errorMessage != null)
                _HistoryErrorState(
                  message: _errorMessage!,
                  onRetry: _loadSessions,
                )
              else if (_sessions.isEmpty)
                _EmptyHistoryState(onRefresh: _loadSessions)
              else
                Column(
                  children: _sessions
                      .map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _HistorySessionCard(
                            session: session,
                            onTap: () => _openSession(session),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Refresh Sessions',
                      onPressed: () {
                        _loadSessions();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'Back to Home',
                      onPressed: _goHome,
                      isSecondary: true,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArchiveHeroPanel extends StatelessWidget {
  final int sessionCount;
  final int totalFrames;
  final int readyJsonCount;
  final String? serverLabel;

  const _ArchiveHeroPanel({
    required this.sessionCount,
    required this.totalFrames,
    required this.readyJsonCount,
    required this.serverLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backend Session Browser',
            style: AppTypography.h2.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'The mobile app now reads processed sessions from FastAPI instead of relying on only local mock history.',
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
              _InfoChip(
                icon: Icons.folder_open_rounded,
                label: '$sessionCount sessions',
              ),
              _InfoChip(
                icon: Icons.movie_filter_rounded,
                label: '$totalFrames frames indexed',
              ),
              _InfoChip(
                icon: Icons.data_object_rounded,
                label: '$readyJsonCount JSON files ready',
              ),
              _InfoChip(
                icon: Icons.cloud_queue_rounded,
                label: serverLabel ?? 'Server endpoint pending',
                compact: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistorySessionCard extends StatelessWidget {
  final ResultSessionSummary session;
  final VoidCallback onTap;

  const _HistorySessionCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final capturedLabel = session.capturedAt == null
        ? 'Capture time unavailable'
        : formatShortDateTime(session.capturedAt!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.surfaceElevated,
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
                          capturedLabel,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.sessionId,
                          style: AppTypography.h3.copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(
                    label:
                        session.resultReadyCount > 0 ? 'JSON Ready' : 'Pose Only',
                    color: session.resultReadyCount > 0
                        ? AppColors.success
                        : AppColors.warning,
                    icon: session.resultReadyCount > 0
                        ? Icons.check_circle_outline_rounded
                        : Icons.image_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoChip(
                    icon: Icons.filter_frames_rounded,
                    label: '${session.frameCount} indexed frames',
                  ),
                  _InfoChip(
                    icon: Icons.image_rounded,
                    label: '${session.poseReadyCount} pose images',
                  ),
                  _InfoChip(
                    icon: Icons.data_object_rounded,
                    label: '${session.resultReadyCount} JSON details',
                  ),
                  _InfoChip(
                    icon: Icons.flag_rounded,
                    label: session.latestFrameId == null
                        ? 'No frames yet'
                        : 'Latest frame ${session.latestFrameId}',
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
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.72),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Open this session to choose a frame, view the pose image, and inspect the JSON metadata.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _HistoryErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load backend sessions',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Retry Loading Sessions',
            onPressed: () {
              onRetry();
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyHistoryState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No processed sessions yet',
            style: AppTypography.h3.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'The backend did not return any folders inside workers/results. Process a session first, then refresh this screen.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Check Again',
            onPressed: () {
              onRefresh();
            },
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: compact ? null : const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
