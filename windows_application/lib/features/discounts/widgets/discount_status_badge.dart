import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/discount_list_item.dart';

class DiscountStatusBadge extends StatelessWidget {
  const DiscountStatusBadge({super.key, required this.status});

  final DiscountStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (status) {
      DiscountStatus.active => (
        AppColors.discountGreenBadge,
        AppColors.discountGreenText,
      ),
      DiscountStatus.scheduled => (
        AppColors.discountBlueBadge,
        AppColors.discountBlueText,
      ),
      DiscountStatus.expired => (
        AppColors.discountExpiredBadge,
        AppColors.discountExpiredText,
      ),
      DiscountStatus.inactive => (
        AppColors.discountOrangeBadge,
        AppColors.discountOrangeText,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: foreground,
          fontSize: 10,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
