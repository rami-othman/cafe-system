import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import 'quantity_stepper.dart';

class CustomizationQuantityPanel extends StatelessWidget {
  const CustomizationQuantityPanel({
    super.key,
    required this.quantity,
    required this.total,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final double total;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Total',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.format(total),
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Quantity',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              QuantityStepper(
                quantity: quantity,
                onDecrease: onDecrease,
                onIncrease: onIncrease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
