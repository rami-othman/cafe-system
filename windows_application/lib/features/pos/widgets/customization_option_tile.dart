import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';

class CustomizationOptionTile extends StatelessWidget {
  const CustomizationOptionTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.helperLabel,
    this.icon,
    this.priceDelta = 0,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? helperLabel;
  final IconData? icon;
  final double priceDelta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: AppRadius.control,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.control,
        child: Container(
          height: AppSizes.customizationOptionHeight,
          padding: AppSpacing.horizontalMd,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.tertiary : AppColors.border,
              width: isSelected ? 1.4 : 1,
            ),
            borderRadius: AppRadius.control,
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (helperLabel != null || priceDelta != 0)
                      Text(
                        helperLabel ?? _formatDelta(priceDelta),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDelta(double amount) {
    if (amount == 0) {
      return CurrencyFormatter.format(0);
    }

    final String formatted = CurrencyFormatter.format(amount.abs());
    return amount > 0 ? '+$formatted' : '-$formatted';
  }
}
