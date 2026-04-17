import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../models/result_models.dart';
import '../navigation/app_routes.dart';
import '../services/result_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_formatters.dart';

class ResultSessionsScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const ResultSessionsScreen({
    super.key,
    this.title = 'Result Sessions',
    this.subtitle =
        'Read processed pose-estimation sessions from FastAPI and open a session to inspect its frames.',
  });

  @override
  State<ResultSessionsScreen> createState() => _ResultSessionsScreenState();
}

class _ResultSessionsScreenState extends State<ResultSessionsScreen> {
  final ResultApi _resultApi = ResultApi();

  List<ResultSession> _sessions = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _baseUrl;

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
      final baseUrl = await _resultApi.getConfiguredBaseUrl();
      final sessions = await _resultApi.getResultSessions();

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
        _baseUrl = baseUrl;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = const [];
        _baseUrl = null;
        _errorMessage = extractResultApiMessage(error);
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

  void _openSession(ResultSession session) {
    Navigator.of(context).pushNamed(
      AppRoutes.resultSessionDetail,
      arguments: ResultSessionDetailArgs(sessionId: session.sessionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _errorMessage == null
        ? (_isLoading ? AppColors.primary : AppColors.success)
        : AppColors.warning;
    final statusLabel = _errorMessage == null
        ? (_isLoading ? 'Loading API' : 'Sessions Ready')
        : 'Check Backend';

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: widget.title,
                subtitle: widget.subtitle,
                onBackPressed: _goHome,
                trailing: StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                  icon: Icons.folder_open_rounded,
                ),
              ),
              const SizedBox(height: 24),
              _SessionsHero(
                sessionCount: _sessions.length,
                baseUrl: _baseUrl,
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const _LoadingState(message: 'Loading result sessions...')
              else if (_errorMessage != null)
                _ErrorState(
                  title: 'Unable to load result sessions',
                  message: _errorMessage!,
                  actionLabel: 'Retry Loading Sessions',
                  onRetry: _loadSessions,
                )
              else if (_sessions.isEmpty)
                _EmptyState(
                  title: 'No processed sessions yet',
                  description:
                      'The backend returned an empty `/api/results/sessions` list. Process a session first, then refresh this screen.',
                  actionLabel: 'Refresh Sessions',
                  onAction: _loadSessions,
                )
              else
                Column(
                  children: _sessions
                      .map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _SessionCard(
                            session: session,
                            onTap: () => _openSession(session),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Refresh Sessions',
                      onPressed: _loadSessions,
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

class _SessionsHero extends StatelessWidget {
  final int sessionCount;
  final String? baseUrl;

  const _SessionsHero({
    required this.sessionCount,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FastAPI Results Browser',
            style: AppTypography.h2.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'This screen only reads already-processed results from the backend. No Raspberry Pi control, realtime polling, or WebSocket flow is used here.',
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
                icon: Icons.folder_copy_rounded,
                label: '$sessionCount sessions',
              ),
              _InfoChip(
                icon: Icons.cloud_queue_rounded,
                label: baseUrl ?? 'Backend host pending',
                compact: false,
              ),
              const _InfoChip(
                icon: Icons.http_rounded,
                label: 'GET /api/results/sessions',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ResultSession session;
  final VoidCallback onTap;

  const _SessionCard({
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
                color: Colors.black.withValues(alpha: 0.18),
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
                  const StatusBadge(
                    label: 'Open Session',
                    color: AppColors.success,
                    icon: Icons.chevron_right_rounded,
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
                      Icons.analytics_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap to call `/api/results/${session.sessionId}` and browse its processed frames.',
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

class _LoadingState extends StatelessWidget {
  final String message;

  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h3.copyWith(fontSize: 20)),
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
            text: actionLabel,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _EmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h3.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: actionLabel,
            onPressed: onAction,
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
