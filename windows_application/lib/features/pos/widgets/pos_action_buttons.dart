import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';

class PosActionButtons extends StatelessWidget {
  const PosActionButtons({
    super.key,
    required this.total,
    this.onCancel,
    this.onHold,
    this.onPay,
    this.isPaymentEnabled = true,
  });

  final double total;
  final VoidCallback? onCancel;
  final VoidCallback? onHold;
  final VoidCallback? onPay;
  final bool isPaymentEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _SecondaryActionButton(label: 'HOLD', onPressed: onHold),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SecondaryActionButton(
                label: 'CANCEL',
                foreground: AppColors.dangerStrong,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SecondaryActionButton(label: 'PRINT', onPressed: () {}),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: AppSizes.payButtonHeight,
          child: FilledButton(
            onPressed: isPaymentEnabled ? onPay : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.tertiary,
              disabledBackgroundColor: AppColors.paymentDisabledBackground,
              foregroundColor: AppColors.textInverse,
              disabledForegroundColor: AppColors.textMuted,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.control,
              ),
              textStyle: AppTextStyles.titleMedium.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
              ),
            ),
            child: Text('PAY ${CurrencyFormatter.format(total)}'),
          ),
        ),
      ],
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    this.foreground = AppColors.textMuted,
    this.onPressed,
  });

  final String label;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.cartControlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: foreground,
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
          textStyle: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
