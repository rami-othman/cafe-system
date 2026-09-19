import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../l10n/app_localizations.dart';

class DiscountSummaryPanel extends StatelessWidget {
  const DiscountSummaryPanel({
    super.key,
    required this.value,
    required this.isReady,
    required this.schedule,
    required this.scope,
    required this.branches,
    this.customers,
    this.package,
    this.channels,
    this.usage,
    this.coupon,
  });

  final String value;
  final bool isReady;
  final String schedule;
  final String scope;
  final String branches;
  final String? customers;
  final String? package;
  final String? channels;
  final String? usage;
  final String? coupon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.discountFormSummary, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          _SummaryRow(label: l10n.discountFormDiscount, value: value),
          _SummaryRow(label: l10n.discountFormScope, value: scope),
          _SummaryRow(label: l10n.discountFormBranches, value: branches),
          _SummaryRow(label: l10n.discountFormScheduleLabel, value: schedule),
          if (customers != null)
            _SummaryRow(label: l10n.discountFormCustomers, value: customers!),
          if (package != null)
            _SummaryRow(label: l10n.discountFormPackage, value: package!),
          if (channels != null)
            _SummaryRow(label: l10n.discountV2Channels, value: channels!),
          if (usage != null)
            _SummaryRow(label: l10n.discountFormUsage, value: usage!),
          if (coupon != null)
            _SummaryRow(label: l10n.discountCoupon, value: coupon!),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: isReady
                  ? AppColors.discountGreenBadge
                  : AppColors.discountOrangeBadge,
              borderRadius: AppRadius.control,
              border: Border.all(
                color: isReady ? AppColors.success : AppColors.warning,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  isReady ? Icons.check_circle_outline : Icons.warning_amber,
                  size: 18,
                  color: isReady ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isReady
                        ? l10n.discountFormReady
                        : l10n.discountFormNotReady,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isReady
                          ? AppColors.discountGreenText
                          : AppColors.discountOrangeText,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 15, color: AppColors.tertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
