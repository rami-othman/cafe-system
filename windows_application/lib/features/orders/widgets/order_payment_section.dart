import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/order_detail.dart';
import '../models/order_payment_summary.dart';

class OrderPaymentSection extends StatelessWidget {
  const OrderPaymentSection({super.key, required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final OrderPaymentSummary payment = detail.payment;

    return _DetailSection(
      title: 'Payment',
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: AppColors.orderDetailsPaymentBackground,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppRadius.control,
              ),
              child: const Icon(
                Icons.credit_card_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    payment.methodLabel,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (payment.hasPayment) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${payment.statusLabel} - Auth: ${payment.authCode}',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (payment.hasPayment)
                  Text(
                    CurrencyFormatter.format(payment.amount),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                if (detail.hasRefund) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Refund ${CurrencyFormatter.format(detail.refundedAmount)}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.dangerStrong,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
