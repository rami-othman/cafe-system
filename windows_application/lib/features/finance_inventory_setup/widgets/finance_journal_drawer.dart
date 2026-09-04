import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import 'finance_components.dart';
import 'finance_design.dart';
import 'finance_source_navigation.dart';
import 'finance_transaction_type.dart';

typedef FinanceJournalDetailLoader = Future<Map<String, dynamic>> Function();
typedef FinanceReverseTransfer = Future<void> Function(int transferId);

/// Production Finance journal-inspection panel shared by every screen that
/// drills a transaction/movement row down to its accounting impact
/// (Financial Transactions in Phase 3; Cash & Banks in Phase 4). It renders
/// entirely from the lazily-loaded `GET finance/transactions/{id}` detail —
/// callers only need a journal id, never a hand-built row shape, and the
/// list endpoint that produced the row is never asked to return full
/// journal lines for every entry.
class FinanceJournalDrawerBody extends StatefulWidget {
  const FinanceJournalDrawerBody({
    super.key,
    required this.loader,
    required this.onNavigate,
    this.title = 'تفاصيل الحركة المالية',
    this.onReverseTransfer,
  });

  final FinanceJournalDetailLoader loader;
  final ValueChanged<String> onNavigate;
  final String title;

  /// When provided, a cash-transfer-sourced, posted, not-yet-reversed entry
  /// exposes an "عكس التحويل" action that calls this with the transfer id
  /// (the entry's `source.id`) — the specialized cash-transfer reversal
  /// endpoint, never a generic journal reversal.
  final FinanceReverseTransfer? onReverseTransfer;

  @override
  State<FinanceJournalDrawerBody> createState() =>
      _FinanceJournalDrawerBodyState();
}

class _FinanceJournalDrawerBodyState extends State<FinanceJournalDrawerBody> {
  late Future<Map<String, dynamic>> _future;
  bool _reversing = false;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _retry() => setState(() {
    _future = widget.loader();
  });

  Future<void> _confirmReverse(int transferId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('عكس التحويل؟'),
        content: const Text(
          'سيُنشأ قيد عكسي مرتبط بهذا التحويل ولن يكون بالإمكان التراجع عن ذلك.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('عكس التحويل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _reversing = true);
    try {
      await widget.onReverseTransfer!(transferId);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _reversing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(child: Text(widget.title, style: FinanceText.page)),
          IconButton(
            tooltip: 'إغلاق',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      const SizedBox(height: FinanceSpace.md),
      Expanded(
        child: SingleChildScrollView(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<Map<String, dynamic>> snapshot,
                ) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 220,
                      child: FinanceLoadingState(
                        label: 'جارٍ تحميل تفاصيل القيد…',
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return FinanceErrorState(
                      message: 'تعذّر تحميل تفاصيل القيد.',
                      onRetry: _retry,
                    );
                  }
                  final Map<String, dynamic> detail = snapshot.data!;
                  final Map<String, dynamic> source = _map(detail['source']);
                  final Map<String, dynamic> journal = _map(
                    detail['journal'],
                  );
                  final Map<String, dynamic> reversal = _map(
                    detail['reversal'],
                  );
                  final List<Map<String, dynamic>> lines = _list(
                    journal['lines'],
                  );
                  final bool canReverseTransfer =
                      widget.onReverseTransfer != null &&
                      source['normalizedType'] == 'cash_transfer' &&
                      '${journal['status']}' == 'posted' &&
                      '${reversal['state'] ?? 'none'}' == 'none' &&
                      source['id'] != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FinanceEntityHeader(
                        title: FinanceTransactionType.label(
                          source['normalizedType'] as String?,
                        ),
                        reference: '${detail['reference'] ?? ''}',
                        status: '${journal['status'] ?? 'draft'}',
                        actions: <Widget>[
                          if ('${reversal['state'] ?? 'none'}' != 'none')
                            FinanceReversalBadge(
                              state: '${reversal['state']}',
                            ),
                        ],
                      ),
                      const SizedBox(height: FinanceSpace.md),
                      FinanceInfoGrid(
                        items: <FinanceInfoItem>[
                          FinanceInfoItem(
                            'الوصف',
                            '${detail['description'] ?? '—'}',
                          ),
                          FinanceInfoItem(
                            'الفرع',
                            '${_map(detail['branch'])['name'] ?? '—'}',
                          ),
                          FinanceInfoItem(
                            'التاريخ',
                            '${detail['transactionDate'] ?? '—'}',
                          ),
                          FinanceInfoItem(
                            'الإجمالي',
                            _money(_map(detail['displayAmount'])['amount']),
                          ),
                        ],
                      ),
                      const SizedBox(height: FinanceSpace.md),
                      const Text('الأثر المحاسبي', style: FinanceText.label),
                      const SizedBox(height: FinanceSpace.sm),
                      if (lines.isEmpty)
                        const FinanceEmptyState(
                          message: 'لا توجد سطور قيد لعرضها',
                        )
                      else
                        FinanceTable(
                          headers: const <String>['الحساب', 'مدين', 'دائن'],
                          minWidth: 400,
                          rows: lines
                              .map(
                                (Map<String, dynamic> line) => <Widget>[
                                  Text(
                                    '${line['accountCode'] ?? ''} — ${line['accountNameAr'] ?? ''}',
                                    style: FinanceText.body,
                                  ),
                                  FinanceAmount(
                                    value: '${line['debit'] ?? '0.00'}',
                                  ),
                                  FinanceAmount(
                                    value: '${line['credit'] ?? '0.00'}',
                                  ),
                                ],
                              )
                              .toList(),
                        ),
                      const SizedBox(height: FinanceSpace.lg),
                      Wrap(
                        spacing: FinanceSpace.sm,
                        runSpacing: FinanceSpace.sm,
                        children: <Widget>[
                          if (FinanceSourceNavigation.destination(source) !=
                              null)
                            OutlinedButton.icon(
                              onPressed: () => widget.onNavigate(
                                FinanceSourceNavigation.destination(source)!,
                              ),
                              icon: const Icon(Icons.open_in_new, size: 17),
                              label: const Text('عرض المصدر'),
                            ),
                          if (FinanceSourceNavigation.journalDestination(
                                detail,
                              ) !=
                              null)
                            OutlinedButton.icon(
                              onPressed: () => widget.onNavigate(
                                FinanceSourceNavigation.journalDestination(
                                  detail,
                                )!,
                              ),
                              icon: const Icon(
                                Icons.menu_book_outlined,
                                size: 17,
                              ),
                              label: const Text('عرض القيد'),
                            ),
                          if (canReverseTransfer)
                            OutlinedButton.icon(
                              onPressed: _reversing
                                  ? null
                                  : () => _confirmReverse(
                                      source['id'] as int,
                                    ),
                              icon: _reversing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.undo_outlined, size: 17),
                              label: const Text('عكس التحويل'),
                            ),
                        ],
                      ),
                    ],
                  );
                },
          ),
        ),
      ),
    ],
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .toList(growable: false)
    : const <Map<String, dynamic>>[];
String _money(dynamic value) => CurrencyFormatter.format(
  value is num
      ? value.toDouble()
      : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0,
);
