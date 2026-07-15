import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class AssignedProductChips extends StatelessWidget {
  const AssignedProductChips({
    super.key,
    required this.productNames,
    required this.totalCount,
    required this.onRemove,
  });

  final List<String> productNames;
  final int totalCount;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final int remaining = totalCount - productNames.length;
    return Container(
      width: double.infinity,
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.contentBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.card,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          ...productNames.map(
            (String name) => Chip(
              label: Text(name),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => onRemove(name),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              labelStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillRadius,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (remaining > 0)
            Chip(
              label: Text('+$remaining more'),
              backgroundColor: AppColors.surfaceAlt,
              side: BorderSide.none,
              labelStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillRadius,
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
