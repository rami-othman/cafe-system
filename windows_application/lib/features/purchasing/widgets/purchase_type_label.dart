import 'package:flutter/material.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';

/// Purchasing Phase 1 line-type universe: inventory | expense | asset |
/// other. Kept in one place so the create form, the line editor, and every
/// list/detail label agree on the same four values and Arabic labels.
const List<MapEntry<String, String>> purchaseTypeOptions = <MapEntry<String, String>>[
  MapEntry<String, String>('inventory', 'مخزون'),
  MapEntry<String, String>('expense', 'مصروف / خدمة'),
  MapEntry<String, String>('asset', 'أصل'),
  MapEntry<String, String>('other', 'أخرى'),
];

const List<MapEntry<String, String>> purchaseTypeFilterOptions = purchaseTypeOptions;

String purchaseTypeLabel(String value) => purchaseTypeOptions
    .firstWhere(
      (MapEntry<String, String> e) => e.key == value,
      orElse: () => MapEntry<String, String>(value, value),
    )
    .value;

class PurchaseTypeBadge extends StatelessWidget {
  const PurchaseTypeBadge({super.key, required this.purchaseType});
  final String purchaseType;

  FinanceTone get _tone => switch (purchaseType) {
    'inventory' => FinanceTone.success,
    'expense' => FinanceTone.warning,
    'asset' => FinanceTone.dark,
    _ => FinanceTone.neutral,
  };

  @override
  Widget build(BuildContext context) =>
      FinanceStatusBadgeCustom(label: purchaseTypeLabel(purchaseType), tone: _tone);
}

/// Purchasing Phase 2 receipt-status universe — completely independent from
/// payment status (never conflated, per the backend's two-dimension model).
const List<MapEntry<String, String>> receiptStatusFilterOptions = <MapEntry<String, String>>[
  MapEntry<String, String>('not_received', 'لم يتم الاستلام'),
  MapEntry<String, String>('partially_received', 'مستلم جزئياً'),
  MapEntry<String, String>('received', 'مستلم بالكامل'),
];

String receiptStatusLabel(String value) => receiptStatusFilterOptions
    .firstWhere(
      (MapEntry<String, String> e) => e.key == value,
      orElse: () => const MapEntry<String, String>('not_applicable', '—'),
    )
    .value;

class ReceiptStatusBadge extends StatelessWidget {
  const ReceiptStatusBadge({super.key, required this.receiptStatus});
  final String receiptStatus;

  FinanceTone get _tone => switch (receiptStatus) {
    'received' => FinanceTone.success,
    'partially_received' => FinanceTone.warning,
    'not_received' => FinanceTone.neutral,
    _ => FinanceTone.neutral,
  };

  @override
  Widget build(BuildContext context) => receiptStatus == 'not_applicable'
      ? Text('—', style: FinanceText.small)
      : FinanceStatusBadgeCustom(
          label: receiptStatusLabel(receiptStatus),
          tone: _tone,
        );
}

/// Goods Receipt document status — draft | posted.
class GoodsReceiptStatusBadge extends StatelessWidget {
  const GoodsReceiptStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => FinanceStatusBadgeCustom(
    label: status == 'posted' ? 'مرحّل' : 'مسودة',
    tone: status == 'posted' ? FinanceTone.success : FinanceTone.warning,
  );
}
