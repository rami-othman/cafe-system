import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class DiscountChipSelector extends StatelessWidget {
  const DiscountChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.multiSelect = true,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final String option in options)
          ChoiceChip(
            label: Text(option),
            selected: selected.contains(option),
            onSelected: (_) => onSelected(option),
            labelStyle: AppTextStyles.labelSmall.copyWith(
              color: selected.contains(option)
                  ? AppColors.textInverse
                  : AppColors.secondary,
              letterSpacing: 0,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.tertiary,
            side: BorderSide(
              color: selected.contains(option)
                  ? AppColors.tertiary
                  : AppColors.border,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.pillRadius,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}
