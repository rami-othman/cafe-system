import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
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
          Text(
            context.l10n.posCurrentOrder,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              message: context.l10n.posNoCartItems,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const PaymentSummaryPanel(),
        ],
      ),
    );
  }
}
