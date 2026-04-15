import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class OptionChip<T> extends StatelessWidget {
  final T value;
  final T selectedValue;
  final String label;
  final IconData icon;
  final ValueChanged<T> onSelected;

  const OptionChip({
    super.key,
    required this.value,
    required this.selectedValue,
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  bool get _isSelected => value == selectedValue;

  @override
  Widget build(BuildContext context) {
    final accent = _isSelected ? AppColors.primary : AppColors.accentSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onSelected(value),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _isSelected
                ? accent.withValues(alpha: 0.14)
                : AppColors.background.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isSelected
                  ? accent.withValues(alpha: 0.34)
                  : AppColors.border.withValues(alpha: 0.72),
            ),
            boxShadow: _isSelected
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
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: _isSelected ? AppColors.textPrimary : accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
