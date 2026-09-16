import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

class DiscountSummaryPanel extends StatelessWidget {
  const DiscountSummaryPanel({
    super.key,
    required this.value,
    required this.isReady,
    required this.schedule,
    required this.scope,
    required this.branches,
  });

  final String value;
  final bool isReady;
  final String schedule;
  final String scope;
  final String branches;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Summary', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          _SummaryRow(label: 'Discount', value: value),
          _SummaryRow(label: 'Scope', value: scope),
          _SummaryRow(label: 'Branches', value: branches),
          _SummaryRow(label: 'Schedule', value: schedule),
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
                        ? 'Policy is ready for review before activation.'
                        : 'Complete the required fields before activating this discount.',
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
