import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import 'payment_summary_panel.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Current Order', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          const Expanded(
            child: AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              message: 'No items added yet',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const PaymentSummaryPanel(),
        ],
      ),
    );
  }
}
