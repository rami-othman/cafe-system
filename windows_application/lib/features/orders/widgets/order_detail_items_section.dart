import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/order_detail.dart';

class OrderDetailItemsSection extends StatelessWidget {
  const OrderDetailItemsSection({super.key, required this.items});

  final List<OrderDetailItem> items;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Order Items',
      child: Column(
        children: <Widget>[
          for (int index = 0; index < items.length; index++) ...<Widget>[
            _OrderDetailItemRow(item: items[index]),
            if (index != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1, color: AppColors.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _OrderDetailItemRow extends StatelessWidget {
  const _OrderDetailItemRow({required this.item});

  final OrderDetailItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: AppSizes.orderDetailsQuantityBoxSize,
          height: AppSizes.orderDetailsQuantityBoxSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadius.control,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '${item.quantity}',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.name,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              for (final String modifier in item.modifiers) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '- $modifier',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          CurrencyFormatter.format(item.total),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}
