import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_pagination.dart';

/// API-owned operational workspaces. Values, readiness and completion rules are
/// presented exactly as Laravel returns them; Flutter never derives balances.
class FinanceOperationScreen extends StatefulWidget {
  const FinanceOperationScreen({super.key, required this.kind, this.id});
  final FinanceOperationKind kind;
  final int? id;

  @override
  State<FinanceOperationScreen> createState() => _FinanceOperationScreenState();
}

enum FinanceOperationKind { period }

class _FinanceOperationScreenState extends State<FinanceOperationScreen> {
  late final FinanceSetupRepository _repo;
  late Future<dynamic> _future;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _repo = serviceLocator<FinanceSetupRepository>();
    _future = _load();
  }

  Future<dynamic> _load() {
    if (widget.id == null) {
      return _repo.getFinancePage(
        _listPath,
        queryParameters: <String, dynamic>{'page': _page, 'perPage': 10},
      );
    }
    return switch (widget.kind) {
      FinanceOperationKind.period => _repo.getAccountingPeriod(widget.id!),
    };
  }

  String get _listPath => switch (widget.kind) {
    FinanceOperationKind.period => 'finance/accounting-periods',
  };

  void _refresh() => setState(() => _future = _load());
  String get _title => switch (widget.kind) {
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
              ? _list(snapshot.data as FinancePage<Map<String, dynamic>>)
              : _detail(snapshot.data);
        },
      ),
    ),
  );

  Widget _list(FinancePage<Map<String, dynamic>> page) {
    final List<Map<String, dynamic>> rows = page.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Title(title: _title, onRefresh: _refresh),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: rows.isEmpty
              ? const _Empty()
              : ListView.separated(
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                row['startDate'] == null
                                    ? '${row['businessDate'] ?? row['period']?['to'] ?? '—'}'
                                    : '${row['startDate']} — ${row['endDate']}',
                              ),
                            ),
                            _PeriodBadge('${row['status'] ?? '—'}'),
                            const Icon(Icons.chevron_left),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        FinancePagination(
          meta: page.meta,
          onPageChanged: (int nextPage) {
            if (nextPage == _page) return;
            setState(() {
              _page = nextPage;
              _future = _load();
            });
          },
        ),
      ],
    );
  }

  String get _routeBase => switch (widget.kind) {
    FinanceOperationKind.period => '/finance/accounting-periods',
  };

  Widget _detail(dynamic raw) => switch (widget.kind) {
    FinanceOperationKind.period => _period(raw as Map<String, dynamic>),
  };

  Widget _period(Map<String, dynamic> detail) {
    final Map<String, dynamic> readiness = _map(detail['readiness']);
    final List<Map<String, dynamic>> blockers = _maps(readiness['blockers']);
    final List<Map<String, dynamic>> warnings = _maps(readiness['warnings']);
    final List<dynamic> actions =
        detail['allowedActions'] as List? ?? const <dynamic>[];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Title(title: '$_title — ${detail['name']}', onRefresh: _refresh),
          const SizedBox(height: AppSpacing.md),
          _PeriodSummary(detail),
          const SizedBox(height: AppSpacing.md),
          _ReadinessPanel(
            canClose: readiness['canClose'] == true,
            blockers: blockers,
            warnings: warnings,
          ),
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
          if (detail['status'] == 'locked' || actions.isEmpty)
            const _Notice(
              title: 'للقراءة فقط',
              values: <String>['يحدد الخادم حالة الفترة وإتاحة الإجراءات.'],
            ),
        ],
      ),
    );
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

class _PeriodBadge extends StatelessWidget {
  const _PeriodBadge(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final Color color = switch (value) {
      'open' => const Color(0xffDCEFE4),
      'closed' => const Color(0xffF4E7D3),
      'locked' => const Color(0xffE9E0EC),
      _ => const Color(0xffF2F2F2),
    };
    final String label = switch (value) {
      'open' => 'مفتوحة',
      'closed' => 'مغلقة',
      'locked' => 'مقفلة نهائياً',
      _ => value,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label),
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary(this.detail);
  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context) => _Card(
    child: Wrap(
      spacing: 36,
      runSpacing: 16,
      children: <Widget>[
        _field('من', '${detail['startDate'] ?? '—'}'),
        _field('إلى', '${detail['endDate'] ?? '—'}'),
        _field('الحالة', _PeriodBadge('${detail['status'] ?? '—'}')),
        if (detail['closedAt'] != null)
          _field('أغلق في', '${detail['closedAt']}'),
        if (detail['lockedAt'] != null)
          _field('قفل في', '${detail['lockedAt']}'),
        if (detail['notes'] != null && '${detail['notes']}'.isNotEmpty)
          _field('ملاحظات', '${detail['notes']}'),
      ],
    ),
  );

  Widget _field(String label, Object value) => SizedBox(
    width: 210,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        value is Widget ? value : SelectableText('$value'),
      ],
    ),
  );
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({
    required this.canClose,
    required this.blockers,
    required this.warnings,
  });
  final bool canClose;
  final List<Map<String, dynamic>> blockers;
  final List<Map<String, dynamic>> warnings;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              canClose ? Icons.check_circle_outline : Icons.block_outlined,
              color: canClose
                  ? const Color(0xff2D8A59)
                  : const Color(0xffB95050),
            ),
            const SizedBox(width: 8),
            Text(
              canClose ? 'جاهزة للإغلاق' : 'الإغلاق محجوب',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (blockers.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text('المعوقات', style: TextStyle(fontWeight: FontWeight.w700)),
          ...blockers.map((Map<String, dynamic> item) => _IssueRow(item: item)),
        ],
        if (warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text(
            'التحذيرات',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          ...warnings.map((Map<String, dynamic> item) => _IssueRow(item: item)),
        ],
      ],
    ),
  );
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final String code = '${item['code'] ?? 'ISSUE'}';
    final int? count = item['count'] is int ? item['count'] as int : null;
    final String? destination = switch (code) {
      'DRAFT_JOURNALS' ||
      'UNBALANCED_POSTED_JOURNALS' => '/finance/journal-entries',
      'OPEN_DAILY_CLOSINGS' => '/finance/daily-closings',
      'FAILED_MANDATORY_FINANCIAL_POSTINGS' => '/inventory/movements',
      'LATE_FINANCIAL_ACTIVITY' => '/finance/journal-entries',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(count == null ? code : '$code ($count)')),
          if (destination != null)
            TextButton.icon(
              onPressed: () => context.go(destination),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('عرض'),
            ),
        ],
      ),
    );
  }
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

List<Map<String, dynamic>> _maps(dynamic value) =>
    (value as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
