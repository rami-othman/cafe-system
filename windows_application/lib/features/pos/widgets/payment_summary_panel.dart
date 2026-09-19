import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_button.dart';

class PaymentSummaryPanel extends StatelessWidget {
  const PaymentSummaryPanel({
    super.key,
    this.totalDue = 0,
    this.itemCount = 0,
    this.onViewDetails,
  });

  final double totalDue;
  final int itemCount;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    if (totalDue <= 0 && itemCount == 0) {
      return Column(
        children: <Widget>[
          _SummaryRow(
            label: context.l10n.posSubtotal,
            value: CurrencyFormatter.format(0),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: context.l10n.posTotal,
            value: CurrencyFormatter.format(0),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: context.l10n.posCheckout,
            icon: Icons.payment_outlined,
            onPressed: null,
            isExpanded: true,
          ),
        ],
      );
    }

    return Container(
      padding: AppSpacing.allXl,
      decoration: const BoxDecoration(
        color: AppColors.shellBackground,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.posTotalDue,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(totalDue),
                    maxLines: 1,
                    style: AppTextStyles.displayMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Text(
                  context.l10n.posItemCount(itemCount),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onViewDetails,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.posViewDetails,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
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
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}
