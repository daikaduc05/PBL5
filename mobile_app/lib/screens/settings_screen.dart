import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/glass_panel.dart';
import '../components/option_chip.dart';
import '../components/pose_track_screen_frame.dart';
import '../components/screen_container.dart';
import '../components/screen_header_bar.dart';
import '../components/status_badge.dart';
import '../navigation/app_routes.dart';
import '../services/mock_pose_tracking_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final MockPoseTrackingService _poseService = MockPoseTrackingService();
  final TextEditingController _raspberryPiController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();

  CaptureMode _defaultMode = CaptureMode.video;
  int _defaultDuration = 10;
  bool _autoUpload = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _raspberryPiController.addListener(_refresh);
    _serverController.addListener(_refresh);
    _loadSettings();
  }

  @override
  void dispose() {
    _raspberryPiController.removeListener(_refresh);
    _serverController.removeListener(_refresh);
    _raspberryPiController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _piValue {
    final value = _raspberryPiController.text.trim();
    return value.isEmpty ? 'Not configured' : value;
  }

  String get _serverValue {
    final value = _serverController.text.trim();
    return value.isEmpty ? 'Not configured' : value;
  }

  String get _durationValue {
    return _defaultMode == CaptureMode.image
        ? 'Single frame'
        : '${_defaultDuration}s clip';
  }

  Future<void> _loadSettings() async {
    final settings = await _poseService.getSettings();

    if (!mounted) {
      return;
    }

    _raspberryPiController.text = settings.raspberryPiIp;
    _serverController.text = settings.serverAddress;

    setState(() {
      _defaultMode = settings.defaultMode;
      _defaultDuration = settings.defaultDurationSeconds;
      _autoUpload = settings.autoUpload;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    await _poseService.saveSettings(
      PoseTrackSettings(
        raspberryPiIp: _raspberryPiController.text.trim(),
        serverAddress: _serverController.text.trim(),
        defaultMode: _defaultMode,
        defaultDurationSeconds: _defaultDuration,
        autoUpload: _autoUpload,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          'PoseTrack settings saved successfully.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final syncColor = _autoUpload ? AppColors.success : AppColors.warning;

    return ScreenContainer(
      padding: EdgeInsets.zero,
      child: PoseTrackScreenFrame(
        builder: (context, minHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeaderBar(
                title: 'Settings',
                subtitle:
                    'Configure the mobile control screen, network endpoints, and capture defaults for the PoseTrack AI pipeline.',
                onBackPressed: _goHome,
                trailing: StatusBadge(
                  label: _autoUpload ? 'Auto Sync' : 'Manual Sync',
                  color: syncColor,
                  icon: _autoUpload
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                GlassPanel(
                  highlighted: true,
                  child: SizedBox(
                    height: 320,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Loading device preferences...',
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Fetching the Raspberry Pi, server, and capture settings.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _LoadedSettingsView(
                  raspberryPiController: _raspberryPiController,
                  serverController: _serverController,
                  defaultMode: _defaultMode,
                  defaultDuration: _defaultDuration,
                  autoUpload: _autoUpload,
                  piValue: _piValue,
                  serverValue: _serverValue,
                  durationValue: _durationValue,
                  syncColor: syncColor,
                  isSaving: _isSaving,
                  onModeSelected: (value) {
                    setState(() {
                      _defaultMode = value;
                    });
                  },
                  onDurationSelected: (value) {
                    setState(() {
                      _defaultDuration = value;
                    });
                  },
                  onAutoUploadChanged: (value) {
                    setState(() {
                      _autoUpload = value;
                    });
                  },
                  onSave: _saveSettings,
                  onBackHome: _goHome,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadedSettingsView extends StatelessWidget {
  final TextEditingController raspberryPiController;
  final TextEditingController serverController;
  final CaptureMode defaultMode;
  final int defaultDuration;
  final bool autoUpload;
  final String piValue;
  final String serverValue;
  final String durationValue;
  final Color syncColor;
  final bool isSaving;
  final ValueChanged<CaptureMode> onModeSelected;
  final ValueChanged<int> onDurationSelected;
  final ValueChanged<bool> onAutoUploadChanged;
  final VoidCallback onSave;
  final VoidCallback onBackHome;

  const _LoadedSettingsView({
    required this.raspberryPiController,
    required this.serverController,
    required this.defaultMode,
    required this.defaultDuration,
    required this.autoUpload,
    required this.piValue,
    required this.serverValue,
    required this.durationValue,
    required this.syncColor,
    required this.isSaving,
    required this.onModeSelected,
    required this.onDurationSelected,
    required this.onAutoUploadChanged,
    required this.onSave,
    required this.onBackHome,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          highlighted: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 360;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      'MOBILE CONFIG PROFILE',
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
                    'Control Center Defaults',
                    style: AppTypography.h2.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Keep the Raspberry Pi edge node, processing server, and capture flow aligned before the next demo run.',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SummaryChip(
                        icon: Icons.memory_rounded,
                        label: 'Pi Node',
                        value: piValue,
                      ),
                      _SummaryChip(
                        icon: Icons.dns_rounded,
                        label: 'Server',
                        value: serverValue,
                      ),
                      _SummaryChip(
                        icon: defaultMode == CaptureMode.video
                            ? Icons.videocam_rounded
                            : Icons.photo_camera_rounded,
                        label: 'Mode',
                        value: defaultMode.label,
                      ),
                      _SummaryChip(
                        icon: Icons.cloud_upload_rounded,
                        label: 'Upload',
                        value: autoUpload ? 'Automatic' : 'Manual',
                      ),
                    ],
                  ),
                ],
              );

              final profileCard = _ProfileCard(
                defaultMode: defaultMode,
                durationValue: durationValue,
                autoUpload: autoUpload,
                syncColor: syncColor,
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: 18),
                    Center(child: profileCard),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  profileCard,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.router_rounded,
                title: 'Connection Endpoints',
                description:
                    'Addresses used by the mobile app to reach the Raspberry Pi capture node and the server inference API.',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 360;
                  final itemWidth = wide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _MetricTile(
                          label: 'Raspberry Pi',
                          value: piValue,
                          icon: Icons.memory_rounded,
                          accent: AppColors.primary,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _MetricTile(
                          label: 'Processing Server',
                          value: serverValue,
                          icon: Icons.cloud_queue_rounded,
                          accent: AppColors.accentSoft,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _SettingsField(
                controller: raspberryPiController,
                label: 'Raspberry Pi IP Address',
                hint: '192.168.1.24',
                helper:
                    'Used for device ping, capture coordination, and edge status checks.',
                icon: Icons.memory_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _SettingsField(
                controller: serverController,
                label: 'Server Address',
                hint: '192.168.1.10:8000',
                helper:
                    'Used for media upload, pose estimation requests, and result retrieval.',
                icon: Icons.dns_rounded,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.tune_rounded,
                title: 'Capture Defaults',
                description:
                    'Choose the recording profile that should be preloaded whenever a new PoseTrack capture session starts.',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 360;
                  final itemWidth = wide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _MetricTile(
                          label: 'Default Mode',
                          value: defaultMode.label,
                          icon: defaultMode == CaptureMode.video
                              ? Icons.videocam_rounded
                              : Icons.photo_camera_rounded,
                          accent: AppColors.primary,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _MetricTile(
                          label: 'Recording Duration',
                          value: durationValue,
                          icon: Icons.timer_rounded,
                          accent: AppColors.accentSoft,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Default Capture Mode',
                style: AppTypography.h3.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Set whether the mobile capture screen opens in image or video mode.',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OptionChip<CaptureMode>(
                    value: CaptureMode.image,
                    selectedValue: defaultMode,
                    label: 'Image',
                    icon: Icons.photo_camera_rounded,
                    onSelected: onModeSelected,
                  ),
                  OptionChip<CaptureMode>(
                    value: CaptureMode.video,
                    selectedValue: defaultMode,
                    label: 'Video',
                    icon: Icons.videocam_rounded,
                    onSelected: onModeSelected,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Recording Duration',
                style: AppTypography.h3.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'This clip length is applied whenever video capture is selected.',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [5, 10, 15]
                    .map(
                      (duration) => OptionChip<int>(
                        value: duration,
                        selectedValue: defaultDuration,
                        label: '${duration}s',
                        icon: Icons.timer_rounded,
                        onSelected: onDurationSelected,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          accent: syncColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: const _SectionHeader(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Auto Upload',
                      description:
                          'Choose whether PoseTrack forwards a capture to the server immediately or waits for a manual upload.',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch.adaptive(
                    value: autoUpload,
                    activeThumbColor: AppColors.background,
                    activeTrackColor: AppColors.success,
                    inactiveThumbColor: AppColors.textMuted,
                    inactiveTrackColor: AppColors.surfaceElevated,
                    onChanged: onAutoUploadChanged,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 360;
                  final itemWidth = wide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _MetricTile(
                          label: 'Upload Policy',
                          value: autoUpload
                              ? 'Immediate transfer after capture'
                              : 'Store locally until triggered',
                          icon: Icons.cloud_upload_rounded,
                          accent: syncColor,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _MetricTile(
                          label: 'Pipeline Start',
                          value: autoUpload
                              ? 'Server processing starts automatically'
                              : 'Operator confirms the upload manually',
                          icon: Icons.play_circle_outline_rounded,
                          accent: syncColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.accentSoft,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Saved changes apply to future capture sessions and can be swapped to persistent storage later without changing this UI.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.88),
                    fontSize: 13.5,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: 'Save Settings',
            onPressed: onSave,
            isLoading: isSaving,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: 'Back to Home',
            onPressed: onBackHome,
            isSecondary: true,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h3.copyWith(fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final CaptureMode defaultMode;
  final String durationValue;
  final bool autoUpload;
  final Color syncColor;

  const _ProfileCard({
    required this.defaultMode,
    required this.durationValue,
    required this.autoUpload,
    required this.syncColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.background.withValues(alpha: 0.3),
            AppColors.surfaceElevated,
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              defaultMode == CaptureMode.video
                  ? Icons.videocam_rounded
                  : Icons.photo_camera_rounded,
              color: AppColors.background,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Default Profile',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            defaultMode.label,
            style: AppTypography.h3.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          _MetricTile(
            label: 'Length',
            value: durationValue,
            icon: Icons.timer_rounded,
            accent: AppColors.accentSoft,
            compact: true,
          ),
          const SizedBox(height: 8),
          _MetricTile(
            label: 'Upload',
            value: autoUpload ? 'Enabled' : 'Manual',
            icon: Icons.cloud_sync_rounded,
            accent: syncColor,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool compact;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(compact ? 16 : 22),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(compact ? 10 : 14),
            ),
            child: Icon(icon, color: accent, size: compact ? 16 : 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: compact ? 12.5 : 14,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
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

class _SettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String helper;
  final IconData icon;
  final TextInputAction textInputAction;

  const _SettingsField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.helper,
    required this.icon,
    required this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          textInputAction: textInputAction,
          autocorrect: false,
          enableSuggestions: false,
          cursorColor: AppColors.primary,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.3),
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            helperStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.72),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.62),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
