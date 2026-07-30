import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/tax_formatter.dart';
import '../models/applied_discount.dart';

class OrderTotalsPanel extends StatelessWidget {
  const OrderTotalsPanel({
    super.key,
    required this.subtotal,
    required this.discountTotal,
    required this.tax,
    required this.total,
    required this.taxRate,
    this.appliedDiscount,
    this.onRemoveDiscount,
  });

  final double subtotal;
  final double discountTotal;
  final double tax;
  final double total;
  final double taxRate;
  final AppliedDiscount? appliedDiscount;
  final VoidCallback? onRemoveDiscount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _TotalLine(
          label: 'Subtotal',
          value: CurrencyFormatter.format(subtotal),
        ),
        if (appliedDiscount != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _DiscountLine(
            label: 'Discount',
            value: '-${CurrencyFormatter.format(discountTotal)}',
            onRemoveDiscount: onRemoveDiscount,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        _TotalLine(
          label: TaxFormatter.taxLabel(taxRate),
          value: CurrencyFormatter.format(tax),
        ),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Total',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiscountLine extends StatelessWidget {
  const _DiscountLine({
    required this.label,
    required this.value,
    required this.onRemoveDiscount,
  });

  final String label;
  final String value;
  final VoidCallback? onRemoveDiscount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.dangerStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.dangerStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        InkWell(
          onTap: onRemoveDiscount,
          borderRadius: AppRadius.pillRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              'Remove',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
