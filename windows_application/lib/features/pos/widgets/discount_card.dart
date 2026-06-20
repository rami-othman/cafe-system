import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/available_discount.dart';

class DiscountCard extends StatelessWidget {
  const DiscountCard({
    super.key,
    required this.discount,
    required this.onApply,
  });

  final AvailableDiscount discount;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final _DiscountVisual visual = _visualFor(discount.type);

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.control,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onApply,
        borderRadius: AppRadius.control,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.discountCardMinHeight,
          ),
          child: Padding(
            padding: AppSpacing.allMd,
            child: Row(
              children: <Widget>[
                Container(
                  width: AppSizes.discountIconContainerSize,
                  height: AppSizes.discountIconContainerSize,
                  decoration: const BoxDecoration(
                    color: AppColors.discountIconBackground,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Icon(visual.icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        discount.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        discount.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _DiscountBadge(
                      label: discount.badgeLabel,
                      backgroundColor: visual.badgeColor,
                      textColor: visual.badgeTextColor,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Apply',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DiscountVisual {
  const _DiscountVisual({
    required this.icon,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  final IconData icon;
  final Color badgeColor;
  final Color badgeTextColor;
}

_DiscountVisual _visualFor(AvailableDiscountType type) {
  return switch (type) {
    AvailableDiscountType.percentage => const _DiscountVisual(
      icon: Icons.percent,
      badgeColor: AppColors.discountOrangeBadge,
      badgeTextColor: AppColors.discountOrangeText,
    ),
    AvailableDiscountType.fixedAmount => const _DiscountVisual(
      icon: Icons.star_border_rounded,
      badgeColor: AppColors.discountBlueBadge,
      badgeTextColor: AppColors.discountBlueText,
    ),
    AvailableDiscountType.bogo => const _DiscountVisual(
      icon: Icons.local_offer_outlined,
      badgeColor: AppColors.discountGreenBadge,
      badgeTextColor: AppColors.discountGreenText,
    ),
  };
}
