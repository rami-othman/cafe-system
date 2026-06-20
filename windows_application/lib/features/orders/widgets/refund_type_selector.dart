import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/refund_type.dart';

class RefundTypeSelector extends StatelessWidget {
  const RefundTypeSelector({
    super.key,
    required this.selectedType,
    required this.orderTotal,
    required this.onChanged,
  });

  final RefundType selectedType;
  final double orderTotal;
  final ValueChanged<RefundType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _RefundTypeCard(
            type: RefundType.full,
            isSelected: selectedType == RefundType.full,
            subtitle: CurrencyFormatter.format(orderTotal),
            onTap: () => onChanged(RefundType.full),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _RefundTypeCard(
            type: RefundType.partial,
            isSelected: selectedType == RefundType.partial,
            subtitle: 'Custom amount',
            onTap: () => onChanged(RefundType.partial),
          ),
        ),
      ],
    );
  }
}

class _RefundTypeCard extends StatelessWidget {
  const _RefundTypeCard({
    required this.type,
    required this.isSelected,
    required this.subtitle,
    required this.onTap,
  });

  final RefundType type;
  final bool isSelected;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.paymentSelectedBackground : AppColors.white,
      borderRadius: AppRadius.control,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.control,
        child: Container(
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.tertiary : AppColors.border,
            ),
            borderRadius: AppRadius.control,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      type.label,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.tertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
