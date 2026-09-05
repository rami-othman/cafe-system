import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation is driven by the backend's `resourceKind` contract, not by
/// display labels. New source types remain safe: unavailable sources are shown
/// without an inert action, while known resource kinds reuse their feature.
class FinanceSourceNavigation {
  const FinanceSourceNavigation._();

  static String? destination(Map<String, dynamic> source) {
    if (source['available'] != true || source['id'] == null) return null;
    return switch (source['resourceKind']) {
      'order' || 'refund' => '/orders',
      'expense' => '/finance/expenses?expenseId=${source['id']}',
      'cash_transfer' => '/finance/cash-banks',
      'supplier_invoice' => '/finance/suppliers?invoiceId=${source['id']}',
      'supplier_payment' => '/finance/suppliers?paymentId=${source['id']}',
      'inventory_movement' => '/inventory/movements',
      'journal' => '/finance/journal-entries/${source['id']}',
      _ => null,
    };
  }

  static String? journalDestination(Map<String, dynamic> data) {
    final dynamic journal = data['journal'];
    if (journal is! Map || journal['id'] == null) return null;
    return '/finance/journal-entries/${journal['id']}';
  }

  static String? reversalDestination(Map<String, dynamic> data) {
    final dynamic reversal = data['reversal'];
    if (reversal is! Map) return null;
    final dynamic id = reversal['state'] == 'reversal_entry'
        ? reversal['originalJournalId']
        : reversal['reversalJournalId'];
    return id == null ? null : '/finance/journal-entries/$id';
  }
}

class FinanceSourceNavigationActions extends StatelessWidget {
  const FinanceSourceNavigationActions({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> source = data['source'] is Map
        ? Map<String, dynamic>.from(data['source'] as Map)
        : const <String, dynamic>{};
    final String? sourcePath = FinanceSourceNavigation.destination(source);
    final String? journalPath = FinanceSourceNavigation.journalDestination(
      data,
    );
    final String? reversalPath = FinanceSourceNavigation.reversalDestination(
      data,
    );
    if (sourcePath == null && journalPath == null && reversalPath == null) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (sourcePath != null)
          OutlinedButton.icon(
            onPressed: () => context.go(sourcePath),
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('عرض المصدر'),
          ),
        if (journalPath != null)
          OutlinedButton.icon(
            onPressed: () => context.go(journalPath),
            icon: const Icon(Icons.menu_book_outlined, size: 17),
            label: const Text('عرض القيد'),
          ),
        if (reversalPath != null)
          OutlinedButton.icon(
            onPressed: () => context.go(reversalPath),
            icon: const Icon(Icons.undo_outlined, size: 17),
            label: const Text('القيد المرتبط'),
          ),
      ],
    );
  }
}
