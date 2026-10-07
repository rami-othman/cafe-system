import 'package:flutter/material.dart';

import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../data/fa_api.dart';
import '../widgets/fa_widgets.dart';

const Map<String, String> kAssetExpenseKinds = <String, String>{
  'maintenance': 'صيانة دورية',
  'repair': 'إصلاح',
  'other': 'أخرى',
};

const Map<String, String> _expenseStatusLabels = <String, String>{
  'draft': 'مسودة',
  'pending_approval': 'بانتظار الموافقة',
  'approved': 'معتمد',
  'paid': 'مدفوع',
};

const Map<String, String> _billingLabels = <String, String>{
  'monthly': 'شهري',
  'quarterly': 'ربع سنوي',
  'yearly': 'سنوي',
  'one_time': 'دفعة واحدة',
};

/// قسم «الصيانة والعقود» ببطاقة الأصل: المصروفات المربوطة بالأصل (تصنيف فقط — لا يغيّر القيود
/// ولا القيمة الدفترية) وعقود الصيانة مع تنبيه التجديد.
class AssetMaintenanceSection extends StatefulWidget {
  const AssetMaintenanceSection({super.key, required this.assetId});

  final int assetId;

  @override
  State<AssetMaintenanceSection> createState() => _AssetMaintenanceSectionState();
}

class _AssetMaintenanceSectionState extends State<AssetMaintenanceSection> {
  final FaApi _api = FaApi();
  Json? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AssetMaintenanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) _load();
  }

  Future<void> _load() async {
    try {
      final Json d = await _api.maintenanceSummary(widget.assetId);
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _act(Future<dynamic> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showFaMessage(context, done);
      await _load();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    final Map<String, dynamic>? picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext d) => _LinkExpenseDialog(api: _api),
    );
    if (picked == null) return;
    await _act(
      () => _api.linkExpense(widget.assetId, picked['id'] as int, picked['kind'] as String),
      'تم ربط المصروف بالأصل.',
    );
  }

  Future<void> _unlink(Json e) async {
    if (!await confirmFa(context, 'فك الربط', 'يُفك ربط المصروف ${e['number']} عن هذا الأصل (لا يتأثر القيد ولا المصروف نفسه). متابعة؟', confirm: 'فك الربط')) return;
    await _act(() => _api.unlinkExpense(widget.assetId, intOf(e['id'])!), 'تم فك الربط.');
  }

  Future<void> _editContract({Json? contract}) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => _ContractDialog(api: _api, assetId: widget.assetId, contract: contract),
    );
    if (ok == true) {
      if (mounted) showFaMessage(context, 'تم حفظ العقد.');
      await _load();
    }
  }

  Future<void> _deleteContract(Json c) async {
    if (!await confirmFa(context, 'حذف العقد', 'يُحذف العقد ${str(c['contractNo'], '')} نهائيًا. متابعة؟', confirm: 'حذف')) return;
    await _act(() => _api.deleteContract(widget.assetId, intOf(c['id'])!), 'تم حذف العقد.');
  }

  @override
  Widget build(BuildContext context) {
    final Json? d = _data;
    final Json totals = asJson(d?['totals']);
    final List<Json> expenses = asJsonList(d?['expenses']);
    final List<Json> contracts = asJsonList(d?['contracts']);
    return FaSection(
      title: 'الصيانة والعقود',
      actions: <Widget>[
        TextButton.icon(onPressed: _busy ? null : _link, icon: const Icon(Icons.link_rounded, size: 18), label: const Text('ربط مصروف موجود')),
        TextButton.icon(onPressed: _busy ? null : () => _editContract(), icon: const Icon(Icons.assignment_outlined, size: 18), label: const Text('عقد صيانة')),
      ],
      child: _error != null
          ? Row(children: <Widget>[Expanded(child: Text(_error!, style: FinanceText.body.copyWith(color: FinanceColors.danger))), TextButton(onPressed: _load, child: const Text('إعادة'))])
          : d == null
          ? const Padding(padding: EdgeInsets.all(FinanceSpace.md), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text('المصروف المربوط بالأصل تصنيف فقط: يبقى قيده على حساب فئته ولا يغيّر كلفة الأصل أو اهتلاكه.', style: FinanceText.subtitle),
                const SizedBox(height: FinanceSpace.md),
                Wrap(
                  spacing: FinanceSpace.md,
                  runSpacing: FinanceSpace.md,
                  children: <Widget>[
                    FaStat(label: 'صيانة دورية (مدفوع)', value: money(totals['maintenance']), width: 190),
                    FaStat(label: 'إصلاحات (مدفوع)', value: money(totals['repair']), width: 190),
                    FaStat(label: 'أخرى (مدفوع)', value: money(totals['other']), width: 190),
                    FaStat(label: 'إجمالي المدفوع', value: money(totals['paid']), color: FinanceColors.primary, width: 190),
                    FaStat(label: 'بانتظار الدفع', value: money(totals['pending']), color: FinanceColors.warning, width: 190),
                  ],
                ),
                const SizedBox(height: FinanceSpace.md),
                FaTable(
                  minWidth: 800,
                  columns: const <String>['التاريخ', 'الرقم', 'النوع', 'البيان', 'المبلغ', 'الحالة', ''],
                  flex: const <int>[2, 2, 2, 4, 2, 2, 2],
                  emptyMessage: 'لا توجد مصروفات مربوطة بهذا الأصل.',
                  rows: expenses
                      .map((Json e) => <Widget>[
                            faCell(str(e['date']), ltr: true),
                            faCell(str(e['number']), ltr: true),
                            faCell(str(e['kindLabel'])),
                            faCell(str(e['description'])),
                            faMoneyCell(e['amount'], bold: true),
                            faCell(_expenseStatusLabels[str(e['status'])] ?? str(e['status'])),
                            TextButton(onPressed: _busy ? null : () => _unlink(e), child: const Text('فك الربط')),
                          ])
                      .toList(growable: false),
                ),
                const SizedBox(height: FinanceSpace.lg),
                const Text('عقود الصيانة', style: FinanceText.label),
                const SizedBox(height: FinanceSpace.sm),
                FaTable(
                  minWidth: 900,
                  columns: const <String>['العقد', 'المورد', 'من', 'إلى', 'الكلفة السنوية', 'الدورة', 'الحالة', ''],
                  flex: const <int>[2, 3, 2, 2, 2, 2, 3, 3],
                  emptyMessage: 'لا توجد عقود صيانة.',
                  rows: contracts
                      .map((Json c) {
                        final bool due = c['renewalDue'] == true;
                        final bool expired = c['status'] == 'expired';
                        final String note = expired
                            ? 'منتهي منذ ${(intOf(c['daysLeft']) ?? 0).abs()} يومًا'
                            : due
                            ? 'يُجدَّد خلال ${c['daysLeft']} يومًا'
                            : str(c['statusLabel']);
                        return <Widget>[
                          faCell(str(c['contractNo'], '—'), bold: true),
                          faCell(str(c['supplierName'], '—')),
                          faCell(str(c['startDate']), ltr: true),
                          faCell(str(c['endDate']), ltr: true),
                          faMoneyCell(c['annualCost']),
                          faCell(str(c['billingLabel'])),
                          faCell(note, bold: due || expired, color: expired ? FinanceColors.danger : (due ? FinanceColors.warning : null)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(onPressed: _busy ? null : () => _editContract(contract: c), icon: const Icon(Icons.edit_outlined, size: 18), tooltip: 'تعديل'),
                              IconButton(onPressed: _busy ? null : () => _deleteContract(c), icon: const Icon(Icons.delete_outline, size: 18), tooltip: 'حذف'),
                            ],
                          ),
                        ];
                      })
                      .toList(growable: false),
                ),
              ],
            ),
    );
  }
}

/// اختيار مصروف موجود غير مربوط بأي أصل (بحث بالرقم أو البيان) مع نوع الربط.
class _LinkExpenseDialog extends StatefulWidget {
  const _LinkExpenseDialog({required this.api});

  final FaApi api;

  @override
  State<_LinkExpenseDialog> createState() => _LinkExpenseDialogState();
}

class _LinkExpenseDialogState extends State<_LinkExpenseDialog> {
  final TextEditingController _search = TextEditingController();
  List<Json> _rows = const <Json>[];
  String _kind = 'maintenance';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _find();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Json> rows = await widget.api.unlinkedExpenses(_search.text.trim());
      if (mounted) {
        setState(() => _rows = rows.where((Json r) => r['status'] != 'rejected' && r['status'] != 'reversed').toList(growable: false));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FaDialog(
      title: 'ربط مصروف موجود بالأصل',
      maxWidth: 720,
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: FaTextField(label: 'بحث برقم المصروف أو بيانه', controller: _search)),
              const SizedBox(width: FinanceSpace.sm),
              FilledButton.icon(onPressed: _loading ? null : _find, icon: const Icon(Icons.search_rounded, size: 18), label: const Text('بحث')),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'نوع المصروف', isDense: true, border: OutlineInputBorder()),
            items: kAssetExpenseKinds.entries.map((MapEntry<String, String> e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(growable: false),
            onChanged: (String? v) => setState(() => _kind = v ?? _kind),
          ),
          FaErrorText(_error),
          const SizedBox(height: FinanceSpace.md),
          SizedBox(
            height: 300,
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _rows.isEmpty
                ? const Center(child: Text('لا توجد مصروفات غير مربوطة مطابقة.', style: FinanceText.subtitle))
                : ListView.separated(
                    itemCount: _rows.length,
                    separatorBuilder: (BuildContext c, int i) => const Divider(height: 1),
                    itemBuilder: (BuildContext c, int i) {
                      final Json r = _rows[i];
                      return ListTile(
                        dense: true,
                        title: Text('${r['expenseNumber']} — ${r['description']}'),
                        subtitle: Text('${r['expenseDate']} · ${r['expenseCategoryName']} · ${_expenseStatusLabels[str(r['status'])] ?? str(r['status'])}'),
                        trailing: Directionality(textDirection: TextDirection.ltr, child: Text(money(r['totalAmount']), style: FinanceText.label)),
                        onTap: () => Navigator.pop(context, <String, dynamic>{'id': intOf(r['id']), 'kind': _kind}),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// إضافة/تعديل عقد صيانة.
class _ContractDialog extends StatefulWidget {
  const _ContractDialog({required this.api, required this.assetId, this.contract});

  final FaApi api;
  final int assetId;
  final Json? contract;

  @override
  State<_ContractDialog> createState() => _ContractDialogState();
}

class _ContractDialogState extends State<_ContractDialog> {
  late final TextEditingController _no = TextEditingController(text: str(widget.contract?['contractNo']));
  late final TextEditingController _cost = TextEditingController(text: widget.contract == null ? '' : str(widget.contract!['annualCost']));
  late final TextEditingController _notice = TextEditingController(text: str(widget.contract?['renewalNoticeDays'], '30'));
  late final TextEditingController _notes = TextEditingController(text: str(widget.contract?['notes']));
  late String _start = str(widget.contract?['startDate'], isoDate(DateTime.now()));
  late String _end = str(widget.contract?['endDate'], isoDate(DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day)));
  late String _billing = str(widget.contract?['billing'], 'yearly');
  int? _supplierId;
  List<Json> _suppliers = const <Json>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _supplierId = intOf(widget.contract?['supplierId']);
    _loadSuppliers();
  }

  @override
  void dispose() {
    _no.dispose();
    _cost.dispose();
    _notice.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      final List<Json> rows = await widget.api.suppliers();
      if (mounted) setState(() => _suppliers = rows);
    } catch (_) {
      // supplier is optional; the contract can be saved without it
    }
  }

  Future<void> _save() async {
    if (_end.compareTo(_start) < 0) {
      setState(() => _error = 'تاريخ نهاية العقد قبل بدايته.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.saveContract(
        widget.assetId,
        <String, dynamic>{
          'supplierId': _supplierId,
          'contractNo': _no.text.trim(),
          'startDate': _start,
          'endDate': _end,
          'annualCost': _cost.text.trim().isEmpty ? '0' : _cost.text.trim(),
          'billing': _billing,
          'renewalNoticeDays': int.tryParse(_notice.text.trim()) ?? 30,
          'notes': _notes.text.trim(),
        },
        id: intOf(widget.contract?['id']),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<int?>> supplierItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('بدون مورد')),
      ..._suppliers.map((Json s) => DropdownMenuItem<int?>(value: intOf(s['id']), child: Text(str(s['name'])))),
    ];
    final bool supplierKnown = _supplierId == null || _suppliers.any((Json s) => intOf(s['id']) == _supplierId);
    if (!supplierKnown) supplierItems.add(DropdownMenuItem<int?>(value: _supplierId, child: Text(str(widget.contract?['supplierName'], 'مورد #$_supplierId'))));
    return FaDialog(
      title: widget.contract == null ? 'عقد صيانة جديد' : 'تعديل عقد الصيانة',
      maxWidth: 640,
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FaBusyButton(label: 'حفظ', onPressed: _save, busy: _saving),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              FaTextField(label: 'رقم العقد', controller: _no, width: 180),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<int?>(
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المورد / شركة الصيانة', isDense: true, border: OutlineInputBorder()),
                  items: supplierItems,
                  onChanged: (int? v) => setState(() => _supplierId = v),
                ),
              ),
              FaDateField(label: 'بداية العقد', value: _start, width: 180, onChanged: (String? v) => setState(() => _start = v ?? _start)),
              FaDateField(label: 'نهاية العقد', value: _end, width: 180, onChanged: (String? v) => setState(() => _end = v ?? _end)),
              FaTextField(label: 'الكلفة السنوية', controller: _cost, numeric: true, width: 180),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _billing,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'دورة الدفع', isDense: true, border: OutlineInputBorder()),
                  items: _billingLabels.entries.map((MapEntry<String, String> e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(growable: false),
                  onChanged: (String? v) => setState(() => _billing = v ?? _billing),
                ),
              ),
              FaTextField(label: 'تنبيه التجديد قبل (يوم)', controller: _notice, integer: true, width: 180),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          FaTextField(label: 'ملاحظات', controller: _notes, maxLines: 2),
          FaErrorText(_error),
        ],
      ),
    );
  }
}
