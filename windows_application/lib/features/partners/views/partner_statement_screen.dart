import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../fixed_assets/data/fa_api.dart';
import '../../fixed_assets/widgets/fa_widgets.dart';
import '../../pos/models/branch.dart';

/// كشف حساب شريك: حركات رأس المال والحساب الجاري والمسحوبات، لكل الفروع أو لفرع واحد،
/// مع حصصه من التوزيعات.
class PartnerStatementScreen extends StatefulWidget {
  const PartnerStatementScreen({super.key, required this.partnerId});

  final int partnerId;

  @override
  State<PartnerStatementScreen> createState() => _PartnerStatementScreenState();
}

class _PartnerStatementScreenState extends State<PartnerStatementScreen> {
  final FaApi _api = FaApi();
  List<Branch> _branches = const <Branch>[];
  String _from = isoDate(DateTime(DateTime.now().year, 1, 1));
  String _to = isoDate(DateTime.now());
  String? _branch;
  Json? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _load();
  }

  Future<void> _loadBranches() async {
    try {
      final List<Branch> b = await _api.branches();
      if (mounted) setState(() => _branches = b);
    } catch (_) {
      // the branch filter simply stays empty
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Json d = await _api.statement(widget.partnerId, <String, dynamic>{'dateFrom': _from, 'dateTo': _to, 'branchId': _branch});
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Json partner = asJson(_data?['partner']);
    final Json opening = asJson(_data?['opening']);
    final Json closing = asJson(_data?['closing']);
    const Map<String, String> accountLabel = <String, String>{'capital': 'رأس المال', 'current': 'جاري', 'drawings': 'مسحوبات'};
    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(onPressed: () => context.go('/finance/partners'), icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'الشركاء'),
            Expanded(child: Text('كشف حساب شريك — ${partner['name'] ?? ''}', style: FinanceText.page)),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        FinanceFilterBar(
          children: <Widget>[
            FaDateField(label: 'من', value: _from, width: 160, onChanged: (String? v) => setState(() => _from = v ?? _from)),
            FaDateField(label: 'إلى', value: _to, width: 160, onChanged: (String? v) => setState(() => _to = v ?? _to)),
            FaBranchDropdown(branches: _branches, value: _branch, includeAll: true, onChanged: (String? v) => setState(() => _branch = v)),
            FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.search_rounded, size: 18), label: const Text('عرض')),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        if (_error != null) FinanceErrorState(message: _error!, onRetry: _load),
        if (_loading && _data == null) const SizedBox(height: 200, child: FinanceLoadingState()),
        if (_data != null) ...<Widget>[
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              FaStat(label: 'رصيد أول المدة', value: money(opening['total'])),
              FaStat(label: 'رأس المال (نهاية)', value: money(closing['capital'])),
              FaStat(label: 'الجاري (نهاية)', value: money(closing['current'])),
              FaStat(label: 'المسحوبات (نهاية)', value: money(closing['drawings'])),
              FaStat(label: 'صافي المركز', value: money(closing['total']), color: FinanceColors.primary),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          FaSection(
            title: 'الحركات',
            child: FaTable(
              minWidth: 1100,
              columns: const <String>['التاريخ', 'القيد', 'الحساب', 'الفرع', 'البيان', 'مدين', 'دائن', 'الرصيد'],
              flex: const <int>[2, 2, 1, 2, 5, 2, 2, 2],
              emptyMessage: 'لا توجد حركات في هذه الفترة.',
              rows: asJsonList(_data!['lines'])
                  .map((Json l) => <Widget>[
                        faCell(str(l['date']), ltr: true),
                        faCell(str(l['journalNumber']), ltr: true),
                        faCell(accountLabel[l['account']] ?? str(l['account'])),
                        faCell(str(l['branchName'])),
                        faCell(str(l['description'])),
                        faMoneyCell(l['debit']),
                        faMoneyCell(l['credit']),
                        faMoneyCell(l['balance'], bold: true),
                      ])
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: FinanceSpace.md),
          FaSection(
            title: 'حصص التوزيعات',
            child: FaTable(
              minWidth: 800,
              columns: const <String>['التوزيع', 'الفرع', 'الفترة', 'البند', 'النسبة', 'المبلغ'],
              flex: const <int>[2, 2, 3, 2, 1, 2],
              emptyMessage: 'لا توجد توزيعات.',
              rows: asJsonList(_data!['distributions'])
                  .map((Json d) => <Widget>[
                        faCell(str(d['number']), ltr: true),
                        faCell(str(d['branchName'])),
                        faCell('${d['periodFrom']} → ${d['periodTo']}', ltr: true),
                        faCell(d['kind'] == 'management_fee' ? 'أتعاب إدارة' : 'حصة'),
                        faCell('${d['sharePercent']}%'),
                        faMoneyCell(d['amount'], bold: true),
                      ])
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }
}
