import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allXs,
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: <Widget>[
          const _QuantityButton(label: '-'),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: AppSpacing.lg,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const _QuantityButton(label: '+'),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.quantityButtonSize,
      height: AppSizes.quantityButtonSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm / 2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary),
      ),
    );
  }
}
