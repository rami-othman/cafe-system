import 'package:flutter/material.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../fixed_assets/data/fa_api.dart';
import '../../fixed_assets/widgets/fa_widgets.dart';
import '../../pos/models/branch.dart';

/// Charges the head office's expenses to the branches for a period (by revenue, equally or by
/// manual percentages) so each branch's result — and the investors' shares — carry their overhead.
class OverheadTab extends StatefulWidget {
  const OverheadTab({super.key, required this.branches});

  final List<Branch> branches;

  @override
  State<OverheadTab> createState() => _OverheadTabState();
}

class _OverheadTabState extends State<OverheadTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  List<Json> _list = const <Json>[];
  late String _from = isoDate(DateTime(DateTime.now().year, DateTime.now().month, 1));
  String _to = isoDate(DateTime.now());
  String _basis = 'revenue';
  final Set<int> _selected = <int>{};
  final Map<int, TextEditingController> _percents = <int, TextEditingController>{};
  Json? _preview;
  bool _busy = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    for (final Branch b in widget.branches) {
      _selected.add(b.id);
      _percents[b.id] = TextEditingController();
    }
    _loadList();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _percents.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadList() async {
    try {
      final List<Json> list = await _api.overheadAllocations();
      if (mounted) setState(() => _list = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Json get _payload {
    final Json data = <String, dynamic>{
      'periodFrom': _from,
      'periodTo': _to,
      'basis': _basis,
      'branchIds': _selected.toList(growable: false),
    };
    if (_basis == 'manual') {
      data['percents'] = <String, dynamic>{
        for (final int id in _selected) '$id': numOf(_percents[id]?.text),
      };
    }
    return data;
  }

  Future<void> _doPreview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Json p = await _api.previewOverhead(_payload);
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    if (!await confirmFa(context, 'ترحيل التوزيع', 'سيُرحَّل قيد يحمّل مصاريف الإدارة العامة على الفروع المحددة. متابعة؟', confirm: 'ترحيل')) return;
    setState(() => _busy = true);
    try {
      await _api.postOverhead(_payload);
      if (!mounted) return;
      showFaMessage(context, 'تم توزيع مصاريف الإدارة على الفروع.');
      setState(() => _preview = null);
      await _loadList();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reverse(Json a) async {
    if (!await confirmFa(context, 'عكس التوزيع', 'عكس التوزيع ${a['number']}؟', confirm: 'عكس')) return;
    try {
      await _api.reverseOverhead(intOf(a['id'])!);
      if (!mounted) return;
      showFaMessage(context, 'تم عكس التوزيع.');
      await _loadList();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  static String _basisLabel(String basis) => switch (basis) {
    'equal' => 'بالتساوي',
    'manual' => 'نسب يدوية',
    _ => 'حسب إيراد الفرع',
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Json? p = _preview;
    return ListView(
      children: <Widget>[
        FaSection(
          title: 'توزيع مصاريف الإدارة العامة',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'يُحمَّل صافي مصاريف الإدارة العامة (القيود بدون فرع) على الفروع المختارة. ما يُوزَّع مرة لا يُوزَّع ثانية.',
                style: FinanceText.small,
              ),
              const SizedBox(height: FinanceSpace.md),
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FaDateField(label: 'من', value: _from, width: 160, onChanged: (String? v) => setState(() {
                    _from = v ?? _from;
                    _preview = null;
                  })),
                  FaDateField(label: 'إلى', value: _to, width: 160, onChanged: (String? v) => setState(() {
                    _to = v ?? _to;
                    _preview = null;
                  })),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _basis,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'أساس التوزيع', isDense: true, border: OutlineInputBorder()),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'revenue', child: Text('حسب إيراد الفرع')),
                        DropdownMenuItem<String>(value: 'equal', child: Text('بالتساوي')),
                        DropdownMenuItem<String>(value: 'manual', child: Text('نسب يدوية')),
                      ],
                      onChanged: (String? v) => setState(() {
                        _basis = v ?? 'revenue';
                        _preview = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FinanceSpace.md),
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  for (final Branch b in widget.branches)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FilterChip(
                          label: Text(b.name),
                          selected: _selected.contains(b.id),
                          onSelected: (bool on) => setState(() {
                            on ? _selected.add(b.id) : _selected.remove(b.id);
                            _preview = null;
                          }),
                        ),
                        if (_basis == 'manual' && _selected.contains(b.id)) ...<Widget>[
                          const SizedBox(width: FinanceSpace.xs),
                          FaTextField(label: '%', controller: _percents[b.id]!, width: 80, numeric: true, onChanged: (_) => setState(() => _preview = null)),
                        ],
                      ],
                    ),
                ],
              ),
              const SizedBox(height: FinanceSpace.md),
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.md,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _busy || _selected.isEmpty ? null : _doPreview,
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('احسب'),
                  ),
                  FaBusyButton(label: 'ترحيل التوزيع', busy: _busy, onPressed: p == null || p['blocking'] == true ? null : _post),
                ],
              ),
              FaErrorText(_error),
              if (p != null) ...<Widget>[
                const SizedBox(height: FinanceSpace.md),
                for (final dynamic w in (p['warnings'] as List<dynamic>? ?? const <dynamic>[]))
                  Padding(
                    padding: const EdgeInsets.only(bottom: FinanceSpace.xs),
                    child: FinanceAlertBanner(message: '$w', tone: FinanceTone.warning),
                  ),
                FaStat(label: 'مصاريف الإدارة القابلة للتوزيع', value: money(p['total']), color: FinanceColors.primary),
                const SizedBox(height: FinanceSpace.md),
                FaTable(
                  minWidth: 600,
                  columns: const <String>['الفرع', 'النسبة', 'إيراد الفرع', 'الحصة'],
                  flex: const <int>[3, 1, 2, 2],
                  emptyMessage: 'لا يوجد توزيع.',
                  rows: asJsonList(p['branches'])
                      .map((Json b) => <Widget>[
                            faCell(str(b['branchName']), bold: true),
                            faCell('${numOf(b['percent']).toStringAsFixed(2)}%', ltr: true),
                            faMoneyCell(b['revenue']),
                            faMoneyCell(b['amount'], bold: true),
                          ])
                      .toList(growable: false),
                ),
                const SizedBox(height: FinanceSpace.md),
                FaTable(
                  minWidth: 600,
                  columns: const <String>['الحساب', 'المبلغ على الإدارة'],
                  flex: const <int>[4, 2],
                  rows: asJsonList(p['accounts'])
                      .map((Json a) => <Widget>[faCell('${a['code']} - ${a['name']}'), faMoneyCell(a['amount'], bold: true)])
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'التوزيعات السابقة',
          child: FaTable(
            minWidth: 900,
            columns: const <String>['الرقم', 'الفترة', 'الأساس', 'المبلغ', 'الحالة', ''],
            flex: const <int>[2, 3, 2, 2, 2, 1],
            emptyMessage: 'لا توجد توزيعات.',
            rows: _list
                .map((Json a) => <Widget>[
                      faCell(str(a['number']), ltr: true, bold: true),
                      faCell('${a['periodFrom']} → ${a['periodTo']}', ltr: true),
                      faCell(_basisLabel(str(a['basis']))),
                      faMoneyCell(a['total'], bold: true),
                      FaStatusPill(status: str(a['status']), label: a['status'] == 'posted' ? 'مرحّل' : 'معكوس'),
                      a['status'] == 'posted' ? TextButton(onPressed: () => _reverse(a), child: const Text('عكس')) : const SizedBox.shrink(),
                    ])
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
