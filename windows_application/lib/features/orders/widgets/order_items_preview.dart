import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/order_summary.dart';
import '../models/order_summary_item.dart';

class OrderItemsPreview extends StatelessWidget {
  const OrderItemsPreview({super.key, required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final List<OrderSummaryItem> previewItems = order.items
        .take(3)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.contentBackground,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: AppRadius.control,
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < previewItems.length; index++) ...<Widget>[
            _OrderItemLine(item: previewItems[index]),
            if (index != previewItems.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
          if (previewItems.isEmpty)
            Text(
              'No line items',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Text(
                'Total',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                CurrencyFormatter.format(order.total),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemLine extends StatelessWidget {
  const _OrderItemLine({required this.item});

  final OrderSummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            '${item.quantity}x ${item.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          CurrencyFormatter.format(item.total),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
