import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/customer.dart';

class CustomerListTile extends StatelessWidget {
  const CustomerListTile({
    super.key,
    required this.customer,
    required this.isSelected,
    required this.onTap,
  });

  final Customer customer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _TierColors tierColors = _tierColorsFor(customer.tier);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.control,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(
            minHeight: AppSizes.customerTileMinHeight,
          ),
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.paymentSelectedBackground
                : AppColors.white,
            border: Border.all(
              color: isSelected ? AppColors.tertiary : AppColors.border,
            ),
            borderRadius: AppRadius.control,
          ),
          child: Row(
            children: <Widget>[
              _CustomerAvatar(customer: customer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _TierBadge(
                          label: customer.tier,
                          background: tierColors.background,
                          foreground: tierColors.foreground,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      customer.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${NumberFormat.decimalPattern().format(customer.points)} pts',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: isSelected ? 1 : 0,
                    child: const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.customerAvatarSize,
      height: AppSizes.customerAvatarSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
      ),
      child: Text(
        customer.initials,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TierColors {
  const _TierColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

_TierColors _tierColorsFor(String tier) {
  return switch (tier.toUpperCase()) {
    'VIP' => const _TierColors(
      background: AppColors.customerVipBadge,
      foreground: AppColors.customerVipText,
    ),
    'REGULAR' => const _TierColors(
      background: AppColors.customerRegularBadge,
      foreground: AppColors.customerRegularText,
    ),
    _ => const _TierColors(
      background: AppColors.customerNewBadge,
      foreground: AppColors.customerNewText,
    ),
  };
}
