import 'package:flutter/material.dart';

import 'finance_design.dart';

/// Centralized backend source/type mapper: `source.normalizedType` (from
/// [FinancialTransactionSourceResolver] on the backend) → Arabic label →
/// badge tone. Raw backend codes (`pos_order`, `expense`, …) must never be
/// shown to the user; every Finance screen that renders a transaction's type
/// goes through this mapper so a new backend source type stays safe (falls
/// back to a neutral generic label) instead of leaking a raw code or crashing.
class FinanceTransactionType {
  const FinanceTransactionType._();

  /// Accepts both `source.normalizedType` (sale, refund, manual_journal, …)
  /// and the raw backend `source_type` column (pos_order, payment_refund,
  /// manual, inventory_movement, …) — some backend queries (e.g. the
  /// per-account ledger) only return the raw column, not the normalized one.
  static String label(String? sourceType) => switch (sourceType) {
    'sale' || 'pos_order' => 'مبيعات',
    'refund' || 'payment_refund' => 'استرجاع',
    'expense' => 'مصروف',
    'cash_transfer' => 'تحويل نقدي',
    'supplier_invoice' => 'فاتورة مورد',
    'supplier_payment' => 'دفعة مورد',
    'inventory_waste' => 'هدر مخزون',
    'stock_count_variance' => 'فرق جرد',
    'inventory_movement' => 'حركة مخزون',
    'manual_journal' || 'manual' => 'قيد يدوي',
    'journal_reversal' => 'قيد عكسي',
    _ => 'قيد محاسبي',
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
        FinanceTransactionType.label(normalizedType),
        style: FinanceText.small.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Renders the reversal linkage backend state (`reversal.state`) — never a
/// fabricated status. `original_reversed` marks an entry another entry has
/// reversed; `reversal_entry` marks the reversing entry itself; `none`
/// renders nothing.
class FinanceReversalBadge extends StatelessWidget {
  const FinanceReversalBadge({super.key, required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    if (state != 'original_reversed' && state != 'reversal_entry') {
      return const SizedBox.shrink();
    }
    final colors = financeTone(FinanceTone.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.pill),
      ),
      child: Text(
        state == 'reversal_entry' ? 'قيد عكسي' : 'معكوس',
        style: FinanceText.small.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
