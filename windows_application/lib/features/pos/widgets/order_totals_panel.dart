import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class OrderTotalsPanel extends StatelessWidget {
  const OrderTotalsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _TotalLine(label: 'Subtotal', value: r'$14.50'),
        const SizedBox(height: AppSpacing.xs),
        const _TotalLine(label: 'Tax (8%)', value: r'$1.16'),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Total',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  r'$15.66',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
