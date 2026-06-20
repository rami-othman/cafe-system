import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';

class PaymentQuickAmountButtons extends StatelessWidget {
  const PaymentQuickAmountButtons({
    super.key,
    required this.totalDue,
    required this.onAmountSelected,
  });

  final double totalDue;
  final ValueChanged<double> onAmountSelected;

  @override
  Widget build(BuildContext context) {
    final List<_QuickAmountOption> options = _quickAmountsFor(totalDue);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth < 360 ? 2 : 4;

        return GridView.builder(
          itemCount: options.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: AppSizes.paymentQuickAmountButtonHeight,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _QuickAmountOption option = options[index];

            return OutlinedButton(
              onPressed: () => onAmountSelected(option.amount),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.border),
                textStyle: AppTextStyles.buttonMedium,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.control,
                ),
              ),
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickAmountOption {
  const _QuickAmountOption({required this.label, required this.amount});

  final String label;
  final double amount;
}

List<_QuickAmountOption> _quickAmountsFor(double totalDue) {
  final double roundedToFive = (math.max(totalDue, 0) / 5).ceil() * 5;
  final double first = roundedToFive <= 0 ? totalDue : roundedToFive;
  final List<double> amounts = <double>[first, first + 5, first + 15];

  return <_QuickAmountOption>[
    for (final double amount in amounts)
      _QuickAmountOption(
        label: CurrencyFormatter.format(amount).replaceAll('.00', ''),
        amount: amount,
      ),
    _QuickAmountOption(label: 'Exact', amount: totalDue),
  ];
}
