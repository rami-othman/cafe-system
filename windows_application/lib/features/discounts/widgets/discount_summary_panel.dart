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
    required this.active,
    required this.schedule,
    required this.requiresApproval,
    required this.allowsStacking,
    required this.auditEnabled,
  });

  final String value;
  final bool active;
  final String schedule;
  final bool requiresApproval;
  final bool allowsStacking;
  final bool auditEnabled;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Summary', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          _SummaryRow(label: 'Discount', value: value),
          const _SummaryRow(label: 'Scope', value: 'Entire Order'),
          const _SummaryRow(
            label: 'Branches',
            value: 'Downtown, Mall, Airport',
          ),
          _SummaryRow(label: 'Schedule', value: schedule),
          _SummaryRow(
            label: 'Approval',
            value: requiresApproval ? 'Manager required' : 'Not required',
          ),
          _SummaryRow(
            label: 'Stacking',
            value: allowsStacking ? 'Allowed' : 'Restricted',
          ),
          _SummaryRow(
            label: 'Reports',
            value: auditEnabled ? 'Audit enabled' : 'Limited tracking',
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: AppSpacing.allMd,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.discountGreenBadge
                  : AppColors.discountOrangeBadge,
              borderRadius: AppRadius.control,
              border: Border.all(
                color: active ? AppColors.success : AppColors.warning,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  active ? Icons.check_circle_outline : Icons.warning_amber,
                  size: 18,
                  color: active ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    active
                        ? 'Policy is ready for review before activation.'
                        : 'Enable the policy before activating this discount.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: active
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
