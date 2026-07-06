import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class MenuFilterBar extends StatelessWidget {
  const MenuFilterBar({super.key, required this.labels, this.onSelected});

  final List<String> labels;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final String label in labels)
          OutlinedButton.icon(
            onPressed: () => onSelected?.call(label),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              foregroundColor: AppColors.textSecondary,
              textStyle: AppTextStyles.bodySmall.copyWith(fontSize: 14),
              side: const BorderSide(color: AppColors.border),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.control,
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            label: Text(label),
          ),
      ],
    );
  }
}
