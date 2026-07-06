import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

enum MenuStatusTone { success, warning, neutral }

class MenuStatusChip extends StatelessWidget {
  const MenuStatusChip({
    super.key,
    required this.label,
    this.tone = MenuStatusTone.success,
  });

  final String label;
  final MenuStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (tone) {
      MenuStatusTone.success => (
        AppColors.menuAppliedBadge,
        AppColors.menuAppliedText,
      ),
      MenuStatusTone.warning => (
        const Color(0x1AC2410C),
        const Color(0xFFC2410C),
      ),
      MenuStatusTone.neutral => (AppColors.surfaceAlt, AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
