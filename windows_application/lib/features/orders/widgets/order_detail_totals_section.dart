import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/tax_formatter.dart';
import '../models/order_detail.dart';

class OrderDetailTotalsSection extends StatelessWidget {
  const OrderDetailTotalsSection({super.key, required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: 'Totals',
      child: Column(
        children: <Widget>[
          _TotalRow(label: 'Subtotal', amount: detail.subtotal),
          const SizedBox(height: AppSpacing.sm),
          _TotalRow(
            label: TaxFormatter.taxLabel(detail.taxRate),
            amount: detail.tax,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TotalRow(label: 'Tip (15%)', amount: detail.tip),
          if (detail.hasRefund) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _TotalRow(
              label: 'Refunded',
              amount: -detail.refundedAmount,
              isDanger: true,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _TotalRow(label: 'Total', amount: detail.total, isStrong: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.isStrong = false,
    this.isDanger = false,
  });

  final String label;
  final double amount;
  final bool isStrong;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = isStrong
        ? AppTextStyles.titleMedium.copyWith(color: AppColors.primary)
        : AppTextStyles.bodySmall.copyWith(
            color: isDanger ? AppColors.dangerStrong : AppColors.textMuted,
          );

    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: style)),
        Text(CurrencyFormatter.format(amount), style: style),
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
