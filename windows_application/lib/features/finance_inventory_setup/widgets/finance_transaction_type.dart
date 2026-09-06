import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'finance_design.dart';

/// Maps backend transaction-type codes to the shared Finance localization.
/// Backend codes remain stable technical identifiers and are never rendered.
class FinanceTransactionType {
  const FinanceTransactionType._();

  static String label(AppLocalizations l10n, String? sourceType) =>
      switch (sourceType) {
        'sale' || 'pos_order' => l10n.financeTransactionSale,
        'refund' || 'payment_refund' => l10n.financeTransactionRefund,
        'expense' => l10n.financeTransactionExpense,
        'cash_transfer' => l10n.financeTransactionCashTransfer,
        'supplier_invoice' => l10n.financeTransactionSupplierInvoice,
        'supplier_payment' => l10n.financeTransactionSupplierPayment,
        'inventory_waste' => l10n.financeTransactionInventoryWaste,
        'stock_count_variance' => l10n.financeTransactionStockCountVariance,
        'inventory_movement' => l10n.financeTransactionInventoryMovement,
        'manual_journal' || 'manual' => l10n.financeTransactionManualJournal,
        'journal_reversal' => l10n.financeTransactionReversalJournal,
        _ => l10n.financeTransactionJournalEntry,
      };

  static FinanceTone badgeTone(String? sourceType) => switch (sourceType) {
    'sale' || 'pos_order' => FinanceTone.success,
    'refund' || 'payment_refund' => FinanceTone.danger,
    'expense' => FinanceTone.warning,
    'inventory_waste' || 'stock_count_variance' || 'inventory_movement' =>
      FinanceTone.danger,
    'journal_reversal' => FinanceTone.warning,
    _ => FinanceTone.neutral,
  };
}

class FinanceTransactionTypeBadge extends StatelessWidget {
  const FinanceTransactionTypeBadge({super.key, required this.normalizedType});

  final String? normalizedType;

  @override
  Widget build(BuildContext context) {
    final colors = financeTone(FinanceTransactionType.badgeTone(normalizedType));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.pill),
      ),
      child: Text(
        FinanceTransactionType.label(AppLocalizations.of(context), normalizedType),
        style: FinanceText.small.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class FinanceReversalBadge extends StatelessWidget {
  const FinanceReversalBadge({super.key, required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    if (state != 'original_reversed' && state != 'reversal_entry') {
      return const SizedBox.shrink();
    }
    final colors = financeTone(FinanceTone.warning);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.pill),
      ),
      child: Text(
        state == 'reversal_entry'
            ? l10n.financeTransactionReversalJournal
            : l10n.financeStatusReversed,
        style: FinanceText.small.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
