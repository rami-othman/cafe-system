import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../repositories/finance_setup_repository.dart';

/// API-owned operational workspaces. Values, readiness and completion rules are
/// presented exactly as Laravel returns them; Flutter never derives balances.
class FinanceOperationScreen extends StatefulWidget {
  const FinanceOperationScreen({super.key, required this.kind, this.id});
  final FinanceOperationKind kind;
  final int? id;

  @override
  State<FinanceOperationScreen> createState() => _FinanceOperationScreenState();
}

enum FinanceOperationKind { reconciliation, closing, period }

class _FinanceOperationScreenState extends State<FinanceOperationScreen> {
  late final FinanceSetupRepository _repo;
  late Future<dynamic> _future;
  int? _statementLineId;
  int? _journalEntryId;
  String _matchAmount = '';

  @override
  void initState() {
    super.initState();
    _repo = serviceLocator<FinanceSetupRepository>();
    _future = _load();
  }

  Future<dynamic> _load() {
    if (widget.id == null) {
      return _repo.getFinanceList(
        _listPath,
        queryParameters: const <String, dynamic>{'perPage': 50},
      );
    }
    return switch (widget.kind) {
      FinanceOperationKind.reconciliation =>
        Future.wait<dynamic>(<Future<dynamic>>[
          _repo.getReconciliation(widget.id!),
          _repo.getReconciliationTransactions(widget.id!),
          _repo.getReconciliationSuggestions(widget.id!),
        ]),
      FinanceOperationKind.closing => _repo.getDailyClosing(widget.id!),
      FinanceOperationKind.period => _repo.getAccountingPeriod(widget.id!),
    };
  }

  String get _listPath => switch (widget.kind) {
    FinanceOperationKind.reconciliation => 'finance/reconciliations',
    FinanceOperationKind.closing => 'finance/daily-closings',
    FinanceOperationKind.period => 'finance/accounting-periods',
  };

  void _refresh() => setState(() => _future = _load());
  String get _title => switch (widget.kind) {
    FinanceOperationKind.reconciliation => 'التسويات',
    FinanceOperationKind.closing => 'الإغلاق اليومي',
    FinanceOperationKind.period => 'الفترات المحاسبية',
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      child: FutureBuilder<dynamic>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Failure(
              message: snapshot.error.toString(),
              retry: _refresh,
            );
          }
          return widget.id == null
              ? _list(snapshot.data as List<Map<String, dynamic>>)
              : _detail(snapshot.data);
        },
      ),
    ),
  );

  Widget _list(List<Map<String, dynamic>> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _Title(title: _title, onRefresh: _refresh),
      const SizedBox(height: AppSpacing.lg),
      if (rows.isEmpty)
        const _Empty()
      else
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, int index) {
              final row = rows[index];
              return InkWell(
                onTap: () => context.go('$_routeBase/${row['id']}'),
                child: _Card(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${row['reference'] ?? row['name'] ?? '—'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${row['businessDate'] ?? row['startDate'] ?? row['period']?['to'] ?? '—'}',
                        ),
                      ),
                      _Badge('${row['status'] ?? '—'}'),
                      const Icon(Icons.chevron_left),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
    ],
  );

  String get _routeBase => switch (widget.kind) {
    FinanceOperationKind.reconciliation => '/finance/reconciliations',
    FinanceOperationKind.closing => '/finance/daily-closings',
    FinanceOperationKind.period => '/finance/accounting-periods',
  };

  Widget _detail(dynamic raw) => switch (widget.kind) {
    FinanceOperationKind.reconciliation => _reconciliation(
      raw as List<dynamic>,
    ),
    FinanceOperationKind.closing => _closing(raw as Map<String, dynamic>),
    FinanceOperationKind.period => _period(raw as Map<String, dynamic>),
  };

  Widget _reconciliation(List<dynamic> payload) {
    final Map<String, dynamic> detail = payload[0] as Map<String, dynamic>;
    final List<Map<String, dynamic>> transactions =
        payload[1] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> suggestions =
        payload[2] as List<Map<String, dynamic>>;
    final bool readOnly = detail['status'] == 'completed';
    final List<Map<String, dynamic>> lines = _maps(detail['statementLines']);
    final List<Map<String, dynamic>> matches = _maps(detail['matches']);
    final Map<String, dynamic> balances = _map(detail['balances']);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Title(
            title: '$_title — ${detail['reference']}',
            onRefresh: _refresh,
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Wrap(
              spacing: 28,
              runSpacing: 12,
              children: <Widget>[
                _Value('رصيد الدفتر', '${balances['bookClosing'] ?? '—'}'),
                _Value(
                  detail['type'] == 'cash' ? 'النقد الفعلي' : 'الرصيد الخارجي',
                  '${balances[detail['type'] == 'cash' ? 'actualCash' : 'externalClosing'] ?? '—'}',
                ),
                _Value('الفرق', '${balances['difference'] ?? '—'}'),
                _Value(
                  'الجاهزية',
                  detail['canComplete'] == true ? 'جاهز' : 'محجوب',
                ),
              ],
            ),
          ),
          if (_maps(detail['blockingReasons']).isNotEmpty ||
              detail['blockingReasons'] is List) ...<Widget>[
            const SizedBox(height: 12),
            _Notice(
              title: 'معوقات الإكمال',
              values: (detail['blockingReasons'] as List? ?? const <dynamic>[])
                  .map((dynamic e) => '$e')
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (detail['type'] == 'cash')
            _cashReconciliation(detail, readOnly)
          else
            _bankReconciliation(
              detail,
              lines,
              transactions,
              suggestions,
              matches,
              readOnly,
            ),
        ],
      ),
    );
  }

  Widget _cashReconciliation(Map<String, dynamic> detail, bool readOnly) =>
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'جرد النقد والحركات',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (!readOnly)
              OutlinedButton.icon(
                onPressed: () =>
                    _updateReconciliation(detail, actualCash: true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تحديث النقد الفعلي'),
              ),
            const SizedBox(height: 8),
            _actions(detail, readOnly),
          ],
        ),
      );

  Widget _bankReconciliation(
    Map<String, dynamic> detail,
    List<Map<String, dynamic>> lines,
    List<Map<String, dynamic>> transactions,
    List<Map<String, dynamic>> suggestions,
    List<Map<String, dynamic>> matches,
    bool readOnly,
  ) => Column(
    children: <Widget>[
      if (!readOnly)
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _addLine(detail),
                icon: const Icon(Icons.add),
                label: const Text('إضافة سطر كشف'),
              ),
              OutlinedButton.icon(
                onPressed: () => _updateReconciliation(detail),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تحديث الرصيد الخارجي'),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      _twoPanels(
        'حركات النظام',
        transactions,
        'سطور الكشف',
        lines,
        (Map<String, dynamic> row, bool system) {
          if (readOnly) return;
          setState(() {
            if (system) {
              _journalEntryId = row['journalEntryId'] as int?;
            } else {
              _statementLineId = row['id'] as int?;
            }
          });
        },
        selectedSystem: _journalEntryId,
        selectedLine: _statementLineId,
      ),
      if (!readOnly) ...<Widget>[
        const SizedBox(height: 12),
        _Card(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 140,
                child: TextField(
                  onChanged: (String value) => _matchAmount = value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'مبلغ المطابقة'),
                ),
              ),
              ElevatedButton(
                onPressed: _statementLineId == null || _journalEntryId == null
                    ? null
                    : () => _match(detail),
                child: const Text('مطابقة الاختيارين'),
              ),
            ],
          ),
        ),
      ],
      if (suggestions.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'اقتراحات المطابقة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...suggestions.map((Map<String, dynamic> suggestion) {
                final List<Map<String, dynamic>> candidates = _maps(
                  suggestion['candidates'],
                );
                return ListTile(
                  title: Text(
                    'سطر كشف ${suggestion['statementLineId']} — ${suggestion['confidence'] ?? 'بدون اقتراح'}',
                  ),
                  subtitle: Text(
                    candidates
                        .map(
                          (Map<String, dynamic> c) =>
                              '${c['reference']} (${c['amount']})',
                        )
                        .join('، '),
                  ),
                  trailing: candidates.length == 1 && !readOnly
                      ? TextButton(
                          onPressed: () => _acceptSuggestion(
                            detail,
                            suggestion,
                            candidates.first,
                          ),
                          child: const Text('قبول'),
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ],
      if (matches.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'مطابقات مسجلة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...matches.map(
                (Map<String, dynamic> match) => ListTile(
                  title: Text(
                    '${match['journalReference']} — ${match['amount']}',
                  ),
                  subtitle: Text('سطر كشف ${match['statementLineId']}'),
                  trailing: readOnly
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.link_off),
                          onPressed: () => _unmatch(detail, match),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      _actions(detail, readOnly),
    ],
  );

  Widget _closing(Map<String, dynamic> detail) {
    final bool readOnly = detail['status'] == 'closed';
    final Map<String, dynamic> sales = _map(detail['sales']);
    final Map<String, dynamic> cash = _map(detail['cash']);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Title(
            title: '$_title — ${detail['businessDate']}',
            onRefresh: _refresh,
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: <Widget>[
                _Value('إجمالي المبيعات', '${sales['grossSales'] ?? '—'}'),
                _Value('الخصومات', '${sales['discounts'] ?? '—'}'),
                _Value('المرتجعات', '${detail['refunds']?['total'] ?? '—'}'),
                _Value('صافي المبيعات', '${sales['netSales'] ?? '—'}'),
                _Value('النقد المتوقع', '${cash['expectedCash'] ?? '—'}'),
                _Value('النقد الفعلي', '${cash['actualCash'] ?? '—'}'),
                _Value('الفرق', '${cash['difference'] ?? '—'}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Structured(detail),
          if (!readOnly) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => _updateClosing(detail),
                  child: const Text('تحديث النقد الفعلي'),
                ),
                ElevatedButton(
                  onPressed: detail['canClose'] == true
                      ? () => _closeClosing(detail)
                      : null,
                  child: const Text('إقفال اليوم'),
                ),
              ],
            ),
          ],
          if (readOnly)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _Notice(
                title: 'مغلق',
                values: <String>['هذه اللقطة مجمّدة للقراءة فقط.'],
              ),
            ),
        ],
      ),
    );
  }

  Widget _period(Map<String, dynamic> detail) {
    final List<String> blockers = _maps(detail['readiness']).isNotEmpty
        ? const <String>[]
        : (detail['readiness'] is Map
              ? _maps(
                  _map(detail['readiness'])['blockers'],
                ).map((Map<String, dynamic> e) => '$e').toList()
              : const <String>[]);
    final List<dynamic> actions =
        detail['allowedActions'] as List? ?? const <dynamic>[];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Title(title: '$_title — ${detail['name']}', onRefresh: _refresh),
          const SizedBox(height: AppSpacing.md),
          _Structured(detail),
          if (blockers.isNotEmpty) _Notice(title: 'معوقات', values: blockers),
          const SizedBox(height: 12),
          if (actions.contains('close'))
            ElevatedButton(
              onPressed: () => _periodAction(detail, 'close'),
              child: const Text('إغلاق الفترة'),
            ),
          if (actions.contains('lock'))
            ElevatedButton(
              onPressed: () => _periodAction(detail, 'lock'),
              child: const Text('قفل الفترة'),
            ),
          if (actions.isEmpty)
            const _Notice(
              title: 'للقراءة فقط',
              values: <String>['يحدد الخادم حالة الفترة وإتاحة الإجراءات.'],
            ),
        ],
      ),
    );
  }

  Widget _actions(Map<String, dynamic> detail, bool readOnly) => readOnly
      ? const _Notice(
          title: 'مكتملة',
          values: <String>['التسوية المكتملة للقراءة فقط.'],
        )
      : ElevatedButton(
          onPressed: detail['canComplete'] == true
              ? () => _complete(detail)
              : null,
          child: const Text('إكمال التسوية'),
        );

  Future<void> _match(Map<String, dynamic> detail) async {
    await _mutate(
      () => _repo.matchReconciliation(widget.id!, <String, dynamic>{
        'statementLineId': _statementLineId,
        'journalEntryId': _journalEntryId,
        'amount': _matchAmount.trim(),
        'idempotencyKey':
            'reconciliation-${DateTime.now().microsecondsSinceEpoch}',
      }),
    );
  }

  Future<void> _acceptSuggestion(
    Map<String, dynamic> detail,
    Map<String, dynamic> suggestion,
    Map<String, dynamic> candidate,
  ) async {
    await _mutate(
      () => _repo.matchReconciliation(widget.id!, <String, dynamic>{
        'statementLineId': suggestion['statementLineId'],
        'journalEntryId': candidate['journalEntryId'],
        'amount': candidate['amount'],
        'idempotencyKey': 'suggestion-${DateTime.now().microsecondsSinceEpoch}',
      }),
    );
  }

  Future<void> _unmatch(
    Map<String, dynamic> detail,
    Map<String, dynamic> match,
  ) async {
    await _mutate(
      () => _repo.unmatchReconciliation(widget.id!, match['id'] as int),
    );
  }

  Future<void> _complete(Map<String, dynamic> detail) async {
    if (await _confirm('إكمال التسوية؟') == true) {
      await _mutate(() => _repo.completeReconciliation(widget.id!));
    }
  }

  Future<void> _periodAction(Map<String, dynamic> detail, String action) async {
    if (await _confirm(action == 'close' ? 'إغلاق الفترة؟' : 'قفل الفترة؟') ==
        true) {
      await _mutate(
        () => action == 'close'
            ? _repo.closeAccountingPeriod(widget.id!)
            : _repo.lockAccountingPeriod(widget.id!),
      );
    }
  }

  Future<void> _updateReconciliation(
    Map<String, dynamic> detail, {
    bool actualCash = false,
  }) async {
    final value = await _moneyDialog(
      actualCash ? 'النقد الفعلي' : 'الرصيد الخارجي',
    );
    if (value != null) {
      await _mutate(
        () => _repo.updateReconciliation(widget.id!, <String, dynamic>{
          actualCash ? 'actualCashCount' : 'externalClosingBalance': value,
        }),
      );
    }
  }

  Future<void> _updateClosing(Map<String, dynamic> detail) async {
    final value = await _moneyDialog('النقد الفعلي');
    if (value != null) {
      await _mutate(
        () => _repo.updateDailyClosing(widget.id!, <String, dynamic>{
          'actualCash': value,
        }),
      );
    }
  }

  Future<void> _closeClosing(Map<String, dynamic> detail) async {
    if (await _confirm('إقفال اليوم؟ لا يمكن تعديل اللقطة بعد الإقفال.') ==
        true) {
      await _mutate(() => _repo.closeDailyClosing(widget.id!));
    }
  }

  Future<void> _addLine(Map<String, dynamic> detail) async {
    final result = await _lineDialog();
    if (result != null) {
      await _mutate(
        () => _repo.addReconciliationStatementLine(widget.id!, result),
      );
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<bool?> _confirm(String text) => showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: Text(text),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  Future<String?> _moneyDialog(String label) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialog, c.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
    return result?.isEmpty == true ? null : result;
  }

  Future<Map<String, dynamic>?> _lineDialog() async {
    final amount = TextEditingController();
    final description = TextEditingController();
    String direction = 'outflow';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialog) => AlertDialog(
          title: const Text('سطر كشف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              DropdownButtonFormField<String>(
                initialValue: direction,
                items: const <String>['inflow', 'outflow']
                    .map(
                      (String x) => DropdownMenuItem(
                        value: x,
                        child: Text(x == 'inflow' ? 'وارد' : 'صادر'),
                      ),
                    )
                    .toList(),
                onChanged: (String? x) => setDialog(() => direction = x!),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialog, <String, dynamic>{
                'transactionDate': DateTime.now().toIso8601String().substring(
                  0,
                  10,
                ),
                'description': description.text.trim(),
                'amount': amount.text.trim(),
                'direction': direction,
              }),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    description.dispose();
    return result;
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, required this.onRefresh});
  final String title;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        onPressed: () => context.go('/finance?tab=overview'),
        icon: const Icon(Icons.home_outlined),
      ),
      IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffE7E2DA)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xffF4E7D3),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(value),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.values});
  final String title;
  final List<String> values;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ...values.map((String value) => Text(value)),
      ],
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message),
        TextButton(onPressed: retry, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('لا توجد بيانات ضمن السياق المحدد.'));
}

class _Structured extends StatelessWidget {
  const _Structured(this.data);
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => _Card(
    child: SelectableText(
      data.entries
          .where((MapEntry<String, dynamic> e) => e.value is! List)
          .map((MapEntry<String, dynamic> e) => '${e.key}: ${e.value}')
          .join('\n'),
    ),
  );
}

List<Map<String, dynamic>> _maps(dynamic value) =>
    (value as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
Widget _twoPanels(
  String leftTitle,
  List<Map<String, dynamic>> left,
  String rightTitle,
  List<Map<String, dynamic>> right,
  void Function(Map<String, dynamic>, bool) onTap, {
  int? selectedSystem,
  int? selectedLine,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    Expanded(
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              leftTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            ...left.map(
              (Map<String, dynamic> r) => ListTile(
                selected: r['journalEntryId'] == selectedSystem,
                onTap: () => onTap(r, true),
                title: Text('${r['reference'] ?? '—'}  ${r['amount'] ?? '—'}'),
                subtitle: Text('${r['description'] ?? ''}'),
              ),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              rightTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            ...right.map(
              (Map<String, dynamic> r) => ListTile(
                selected: r['id'] == selectedLine,
                onTap: () => onTap(r, false),
                title: Text('${r['reference'] ?? '—'}  ${r['amount'] ?? '—'}'),
                subtitle: Text('${r['description'] ?? ''}'),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);
