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
    _loadSettings();
  }

  @override
  void dispose() {
    _raspberryPiController.dispose();
    _serverController.dispose();
    super.dispose();
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
      const SnackBar(content: Text('PoseTrack settings saved successfully.')),
    );
  }

  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
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
                    'Tune connection endpoints and default capture preferences for the mobile demo workflow.',
                onBackPressed: _goHome,
                trailing: const StatusBadge(
                  label: 'Config',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                )
              else ...[
                GlassPanel(
                  highlighted: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Network Endpoints',
                        style: AppTypography.h2.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These addresses mirror the Raspberry Pi capture node and server processing API used by the project.',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SettingsField(
                        controller: _raspberryPiController,
                        label: 'Raspberry Pi IP Address',
                        hint: '192.168.1.24',
                        icon: Icons.memory_rounded,
                      ),
                      const SizedBox(height: 14),
                      _SettingsField(
                        controller: _serverController,
                        label: 'Server Address',
                        hint: '192.168.1.10:8000',
                        icon: Icons.dns_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Capture Mode',
                        style: AppTypography.h3.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OptionChip<CaptureMode>(
                            value: CaptureMode.image,
                            selectedValue: _defaultMode,
                            label: 'Image',
                            icon: Icons.photo_camera_rounded,
                            onSelected: (value) {
                              setState(() {
                                _defaultMode = value;
                              });
                            },
                          ),
                          OptionChip<CaptureMode>(
                            value: CaptureMode.video,
                            selectedValue: _defaultMode,
                            label: 'Video',
                            icon: Icons.videocam_rounded,
                            onSelected: (value) {
                              setState(() {
                                _defaultMode = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Default Recording Duration',
                        style: AppTypography.h3.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [5, 10, 15]
                            .map(
                              (duration) => OptionChip<int>(
                                value: duration,
                                selectedValue: _defaultDuration,
                                label: '${duration}s',
                                icon: Icons.timer_rounded,
                                onSelected: (value) {
                                  setState(() {
                                    _defaultDuration = value;
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto Upload',
                              style: AppTypography.h3.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Automatically send captured media to the server as soon as recording stops or an image is taken.',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 14,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Switch(
                        value: _autoUpload,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) {
                          setState(() {
                            _autoUpload = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Save Settings',
                    onPressed: () {
                      _saveSettings();
                    },
                    isLoading: _isSaving,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Back to Home',
                    onPressed: _goHome,
                    isSecondary: true,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _SettingsField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
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
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.28),
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
