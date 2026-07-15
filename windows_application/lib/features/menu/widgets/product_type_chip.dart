import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/menu_enums.dart';

class ProductTypeChip extends StatelessWidget {
  const ProductTypeChip({super.key, required this.type});

  final ProductType type;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, String label) = switch (type) {
      ProductType.simple => (
        AppColors.primarySoft,
        AppColors.textSecondary,
        'Simple',
      ),
      ProductType.variant => (
        AppColors.discountBlueBadge,
        AppColors.discountBlueText,
        'Variant',
      ),
      ProductType.combo => (
        AppColors.orderHeldBadge,
        AppColors.orderHeldText,
        'Combo',
      ),
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
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
