import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

class DiscountPosPreviewCard extends StatelessWidget {
  const DiscountPosPreviewCard({super.key, required this.discountPercent});

  final int discountPercent;

  @override
  Widget build(BuildContext context) {
    const double subtotal = 50;
    final double discount = subtotal * discountPercent / 100;
    final double taxable = subtotal - discount;
    final double tax = taxable * 0.15;
    final double total = taxable + tax;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: AppSpacing.allLg,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.point_of_sale_outlined,
                  color: AppColors.textInverse,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'POS Preview',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textInverse,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.allLg,
            child: Column(
              children: <Widget>[
                _ReceiptRow(label: 'Subtotal', value: subtotal),
                const SizedBox(height: AppSpacing.md),
                _ReceiptRow(
                  label: 'Discount ($discountPercent%)',
                  value: -discount,
                  color: AppColors.success,
                ),
                const Padding(padding: AppSpacing.verticalMd, child: Divider()),
                _ReceiptRow(label: 'Tax / VAT (15%)', value: tax),
                const SizedBox(height: AppSpacing.md),
                _ReceiptRow(label: 'Total', value: total, emphasized: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = emphasized
        ? AppTextStyles.titleMedium
        : AppTextStyles.bodySmall;
    final String sign = value < 0 ? '-' : '';

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: style.copyWith(color: color)),
        ),
        Text(
          '$sign SAR ${value.abs().toStringAsFixed(2)}',
          style: style.copyWith(color: color),
        ),
      ],
    );
  }
}
