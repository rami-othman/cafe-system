import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
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
    this.onPrint,
    this.isPaymentEnabled = true,
    this.isPrintEnabled = false,
    this.isPrinting = false,
  });

  final double total;
  final VoidCallback? onCancel;
  final VoidCallback? onHold;
  final VoidCallback? onPay;
  final VoidCallback? onPrint;
  final bool isPaymentEnabled;
  final bool isPrintEnabled;
  final bool isPrinting;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _SecondaryActionButton(
                label: context.l10n.posHoldOrder,
                onPressed: onHold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SecondaryActionButton(
                label: context.l10n.posCancelOrder,
                foreground: AppColors.dangerStrong,
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SecondaryActionButton(
                label: context.l10n.posPrint,
                onPressed: isPrintEnabled && !isPrinting ? onPrint : null,
                child: isPrinting
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
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
            child: Text(
              total == 0
                  ? context.l10n.posCompleteOrder
                  : context.l10n.posPayAmount(CurrencyFormatter.format(total)),
            ),
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
    this.child,
  });

  final String label;
  final Color foreground;
  final VoidCallback? onPressed;
  final Widget? child;

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
        child:
            child ??
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
      ),
    );
  }
}
