import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_button.dart';

class PaymentSummaryPanel extends StatelessWidget {
  const PaymentSummaryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _SummaryRow(label: 'Subtotal', value: CurrencyFormatter.format(0)),
        const SizedBox(height: AppSpacing.sm),
        _SummaryRow(label: 'Total', value: CurrencyFormatter.format(0)),
        const SizedBox(height: AppSpacing.lg),
        const AppButton(
          label: 'Checkout',
          icon: Icons.payment_outlined,
          onPressed: null,
          isExpanded: true,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
