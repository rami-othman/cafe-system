import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/order_detail.dart';
import 'orders_localizations.dart';

class RefundSummaryCard extends StatelessWidget {
  const RefundSummaryCard({super.key, required this.orderDetail});

  final OrderDetail orderDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.orderDetailsPaymentBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Column(
        children: <Widget>[
          _SummaryRow(
            label: context.ordersL10n.ordersRefundOrderTotal,
            value: CurrencyFormatter.format(orderDetail.total),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: context.ordersL10n.ordersRefundPaidVia,
            value: ordersPaymentMethodLabel(
              context.ordersL10n,
              orderDetail.payment,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
