import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/branding/brand_header.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/tax_formatter.dart';
import '../models/order_receipt.dart';
import '../models/payment_method.dart';
import '../models/receipt_line_item.dart';
import 'pos_localization.dart';

class ReceiptPreviewPaper extends StatelessWidget {
  const ReceiptPreviewPaper({super.key, required this.receipt});

  static const String _address = '123 ESPRESSO LANE, CITYVILLE';
  static const String _phone = '(555) 123-4567';

  final OrderReceipt receipt;

  TextStyle get _monoStyle {
    return const TextStyle(
      fontFamily: 'Consolas',
      fontSize: 11,
      height: 1.35,
      color: AppColors.receiptInk,
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle mono = _monoStyle;

    return Container(
      width: AppSizes.receiptPaperWidth,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: mono,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _ReceiptLogo(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'CAFE SYSTEM 618',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.receiptInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _CenteredText(receipt.branchName, style: mono),
            const _CenteredText(_address),
            const _CenteredText('TEL: $_phone'),
            const _ReceiptDivider(),
            _ReceiptInfoRow(
              label: context.l10n.posReceiptOrder,
              value: receipt.orderNumber,
            ),
            _ReceiptInfoRow(
              label: context.l10n.posReceiptCashier,
              value: receipt.cashierName,
            ),
            if (receipt.customerName != null)
              _ReceiptInfoRow(
                label: context.l10n.posReceiptCustomer,
                value: receipt.customerName!.toUpperCase(),
              ),
            _ReceiptInfoRow(
              label: context.l10n.posReceiptDate,
              value: DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(receipt.completedAt),
            ),
            _ReceiptInfoRow(
              label: context.l10n.posReceiptTime,
              value: DateFormat.jm(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(receipt.completedAt),
            ),
            const _ReceiptDivider(),
            for (final ReceiptLineItem item in receipt.items) ...<Widget>[
              _LineItemRow(item: item),
              for (final String modifier in item.modifiers)
                _IndentedLine('+ $modifier'),
              if (item.specialInstructions != null)
                _IndentedLine(
                  context.l10n.posReceiptNote(item.specialInstructions!),
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const _ReceiptDivider(),
            _AmountRow(
              label: context.l10n.posSubtotal,
              amount: receipt.subtotal,
            ),
            _AmountRow(
              label: context.l10n.posTax(
                TaxFormatter.percentLabel(receipt.taxRate),
              ),
              amount: receipt.tax,
            ),
            if (receipt.discountTotal > 0)
              _AmountRow(
                label: receipt.discountLabel ?? context.l10n.posDiscount,
                amount: -receipt.discountTotal,
              ),
            const SizedBox(height: AppSpacing.xs),
            _AmountRow(
              label: context.l10n.posTotal,
              amount: receipt.total,
              isStrong: true,
            ),
            const _ReceiptDivider(),
            _ReceiptInfoRow(
              label: context.l10n.posReceiptPaidVia,
              value: receipt.payment.method.localizedLabel(context.l10n),
            ),
            if (receipt.payment.method == PaymentMethod.card ||
                receipt.payment.method == PaymentMethod.wallet)
              _ReceiptInfoRow(
                label: context.l10n.posReceiptAuthorization,
                value: '${context.l10n.posReceiptApproved} 4092',
              ),
            if (receipt.payment.method == PaymentMethod.cash &&
                receipt.payment.changeDue > 0)
              _AmountRow(
                label: context.l10n.posReceiptChange,
                amount: receipt.payment.changeDue,
              ),
            const _ReceiptDivider(),
            Text(
              context.l10n.posReceiptThankYou,
              textAlign: TextAlign.center,
              style: mono.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'CAFESYSTEM618.COM/FEEDBACK',
              textAlign: TextAlign.center,
              style: mono,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLogo extends StatelessWidget {
  const _ReceiptLogo();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandLogo(size: 34));
  }
}

class _CenteredText extends StatelessWidget {
  const _CenteredText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: TextAlign.center, style: style);
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        '--------------------------------',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          fontFamily: 'Consolas',
          fontSize: 11,
          height: 1,
          color: AppColors.receiptInk,
        ),
      ),
    );
  }
}

class _ReceiptInfoRow extends StatelessWidget {
  const _ReceiptInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.item});

  final ReceiptLineItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 22, child: Text('${item.quantity}x')),
        Expanded(
          child: Text(
            item.name.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(CurrencyFormatter.format(item.lineTotal)),
      ],
    );
  }
}

class _IndentedLine extends StatelessWidget {
  const _IndentedLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, top: AppSpacing.xs),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.isStrong = false,
  });

  final String label;
  final double amount;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final FontWeight weight = isStrong ? FontWeight.w800 : FontWeight.w500;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(fontWeight: weight),
          ),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(fontWeight: weight),
        ),
      ],
    );
  }
}
