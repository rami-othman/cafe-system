import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_card.dart';

class DiscountPosPreviewCard extends StatelessWidget {
  const DiscountPosPreviewCard({
    super.key,
    required this.discountValue,
    required this.isPercentage,
    required this.taxRate,
  });

  final double discountValue;
  final bool isPercentage;
  final double taxRate;

  @override
  Widget build(BuildContext context) {
    const double subtotal = 50;
    final double discount = isPercentage
        ? subtotal * discountValue / 100
        : discountValue.clamp(0, subtotal).toDouble();
    final double taxable = subtotal - discount;
    final double tax = taxable * taxRate;
    final double total = taxable + tax;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: AppSpacing.allLg,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.point_of_sale_outlined,
                  color: AppColors.textInverse,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.discountPosPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textInverse,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.allLg,
            child: Column(
              children: <Widget>[
                _ReceiptRow(label: l10n.discountSubtotal, value: subtotal),
                const SizedBox(height: AppSpacing.md),
                _ReceiptRow(
                  label: isPercentage
                      ? l10n.discountPercentOff(_decimal(discountValue))
                      : l10n.discountFormDiscount,
                  value: -discount,
                  color: AppColors.success,
                ),
                const Padding(padding: AppSpacing.verticalMd, child: Divider()),
                _ReceiptRow(
                  label: l10n.discountTax(_decimal(taxRate * 100)),
                  value: tax,
                ),
                const SizedBox(height: AppSpacing.md),
                _ReceiptRow(
                  label: l10n.discountTotal,
                  value: total,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _decimal(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = emphasized
        ? AppTextStyles.titleMedium
        : AppTextStyles.bodySmall;
    final String sign = value < 0 ? '-' : '';

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: style.copyWith(color: color)),
        ),
        Text(
          '$sign${CurrencyFormatter.formatForContext(context, value.abs())}',
          style: style.copyWith(color: color),
        ),
      ],
    );
  }
}
