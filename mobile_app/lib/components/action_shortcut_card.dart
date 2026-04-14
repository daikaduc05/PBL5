import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ActionShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const ActionShortcutCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isPrimary
        ? AppColors.primary.withValues(alpha: 0.34)
        : AppColors.border.withValues(alpha: 0.85);

    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPrimary
              ? [
                  AppColors.primary.withValues(alpha: 0.16),
                  AppColors.surfaceElevated,
                  AppColors.surface,
                ]
              : [AppColors.surfaceElevated, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: (isPrimary ? AppColors.primary : AppColors.accent)
                .withValues(alpha: 0.06),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: isPrimary
                            ? AppColors.primary
                            : AppColors.accentSoft,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(title, style: AppTypography.h3.copyWith(fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    height: 1.2,
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
