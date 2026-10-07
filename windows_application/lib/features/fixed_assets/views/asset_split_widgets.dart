import 'package:flutter/material.dart';

import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/widgets/account_picker_field.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../data/fa_api.dart';
import '../widgets/fa_widgets.dart';

/// Rounds like the backend (cents) so "remaining" labels never show 0.0000001.
double _r2(double v) => (v * 100).roundToDouble() / 100;

// ============================================================================ payments

class _PayRow {
  _PayRow({this.accountId});

  int? accountId;
  final TextEditingController amount = TextEditingController();
}

/// الدفع من حساب واحد، أو تقسيمه على عدة حسابات (مجموعها = المبلغ).
/// الشاشة الأم تقرأ النتيجة عبر `GlobalKey<PaymentsEditorState>`.
class PaymentsEditor extends StatefulWidget {
  const PaymentsEditor({
    super.key,
    required this.accounts,
    this.label = 'حساب الدفع (الصندوق / المورد / الشريك)',
    this.initialAccountId,
    this.allowSplit = true,
    this.total,
  });

  final List<FinancialAccount> accounts;
  final String label;
  final int? initialAccountId;

  /// When false the editor only offers one account (e.g. a draft that is not activated yet).
  final bool allowSplit;

  /// Amount to be split; used only to show the remaining difference live.
  final double Function()? total;

  @override
  State<PaymentsEditor> createState() => PaymentsEditorState();
}

class PaymentsEditorState extends State<PaymentsEditor> {
  bool _split = false;
  int? _single;
  final List<_PayRow> _rows = <_PayRow>[];

  @override
  void initState() {
    super.initState();
    _single = widget.initialAccountId;
  }

  @override
  void didUpdateWidget(covariant PaymentsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.allowSplit && _split) {
      _split = false;
    }
  }

  @override
  void dispose() {
    for (final _PayRow r in _rows) {
      r.amount.dispose();
    }
    super.dispose();
  }

  /// The single account when not splitting (null when none is chosen).
  int? get singleAccountId => _split ? null : _single;

  bool get isSplit => _split;

  void _startSplit() {
    final double total = widget.total?.call() ?? 0;
    for (final _PayRow r in _rows) {
      r.amount.dispose();
    }
    _rows
      ..clear()
      ..add(_PayRow(accountId: _single)..amount.text = total > 0 ? total.toStringAsFixed(2) : '')
      ..add(_PayRow());
    setState(() => _split = true);
  }

  void _endSplit() {
    setState(() {
      _single = _rows.isNotEmpty ? _rows.first.accountId : _single;
      _split = false;
    });
  }

  /// null → no account chosen yet. Otherwise ready to send as `payments`.
  List<Json>? payments(String total) {
    if (!_split) {
      return _single == null
          ? null
          : <Json>[
              <String, dynamic>{'accountId': _single, 'amount': total},
            ];
    }
    return _rows
        .where((_PayRow r) => r.accountId != null || r.amount.text.trim().isNotEmpty)
        .map((_PayRow r) => <String, dynamic>{'accountId': r.accountId, 'amount': r.amount.text.trim()})
        .toList(growable: false);
  }

  /// Arabic error text, or null when the payments are complete and add up to [total].
  String? validate(String total) {
    final double amount = numOf(total);
    if (!_split) return _single == null ? 'حدد حساب الدفع.' : null;
    double sum = 0;
    final Set<int> seen = <int>{};
    for (final _PayRow r in _rows) {
      if (r.accountId == null && r.amount.text.trim().isEmpty) continue;
      if (r.accountId == null) return 'حدد الحساب لكل دفعة.';
      if (numOf(r.amount.text) <= 0) return 'مبلغ كل دفعة يجب أن يكون أكبر من صفر.';
      seen.add(r.accountId!);
      sum += numOf(r.amount.text);
    }
    if (seen.isEmpty) return 'أضف دفعة واحدة على الأقل.';
    if (_r2(sum) != _r2(amount)) return 'مجموع الدفعات (${money(_r2(sum))}) لا يساوي المبلغ (${money(_r2(amount))}).';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_split) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: AccountPickerField(
              label: widget.label,
              accounts: widget.accounts,
              value: _single,
              allowClear: true,
              onChanged: (int? id) => setState(() => _single = id),
            ),
          ),
          if (widget.allowSplit)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: FinanceSpace.sm),
              child: TextButton.icon(onPressed: _startSplit, icon: const Icon(Icons.call_split_rounded, size: 18), label: const Text('تقسيم الدفع')),
            ),
        ],
      );
    }
    final double total = widget.total?.call() ?? 0;
    final double sum = _rows.fold<double>(0, (double s, _PayRow r) => s + numOf(r.amount.text));
    final double rest = _r2(total - sum);
    return Container(
      padding: const EdgeInsets.all(FinanceSpace.md),
      decoration: BoxDecoration(border: Border.all(color: FinanceColors.border), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('الدفع من عدة حسابات', style: FinanceText.label)),
              TextButton(onPressed: _endSplit, child: const Text('حساب واحد')),
            ],
          ),
          for (int i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AccountPickerField(
                      label: 'الحساب ${i + 1}',
                      accounts: widget.accounts,
                      value: _rows[i].accountId,
                      allowClear: true,
                      onChanged: (int? id) => setState(() => _rows[i].accountId = id),
                    ),
                  ),
                  const SizedBox(width: FinanceSpace.sm),
                  FaTextField(label: 'المبلغ', controller: _rows[i].amount, width: 150, numeric: true, onChanged: (_) => setState(() {})),
                  IconButton(
                    tooltip: 'حذف الدفعة',
                    onPressed: _rows.length <= 1
                        ? null
                        : () => setState(() {
                            final _PayRow removed = _rows.removeAt(i);
                            removed.amount.dispose();
                          }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_PayRow()..amount.text = rest > 0 ? rest.toStringAsFixed(2) : '')),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة دفعة'),
              ),
              const Spacer(),
              if (total > 0)
                Text(
                  rest == 0 ? 'الدفعات مطابقة للمبلغ' : (rest > 0 ? 'المتبقي: ${money(rest)}' : 'زيادة: ${money(rest.abs())}'),
                  style: FinanceText.body.copyWith(color: rest == 0 ? FinanceColors.success : FinanceColors.danger, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================ items of the asset card

class _ItemRow {
  _ItemRow({String name = '', String cost = ''})
    : name = TextEditingController(text: name),
      cost = TextEditingController(text: cost);

  final TextEditingController name;
  final TextEditingController cost;
}

/// بنود الأصل (ما يتكوّن منه): تُوزَّع كلفة الأصل عليها يدويًا لكل بند، أو بالتساوي.
class ComponentsEditor extends StatefulWidget {
  const ComponentsEditor({super.key, required this.total, this.initial = const <Json>[]});

  /// Card cost to be split (read live).
  final double Function() total;

  /// Existing items (card JSON `components`) when editing a draft.
  final List<Json> initial;

  @override
  State<ComponentsEditor> createState() => ComponentsEditorState();
}

class ComponentsEditorState extends State<ComponentsEditor> {
  late String _mode;
  final List<_ItemRow> _rows = <_ItemRow>[];

  @override
  void initState() {
    super.initState();
    if (widget.initial.isEmpty) {
      _mode = 'equal';
      _rows
        ..add(_ItemRow())
        ..add(_ItemRow());
    } else {
      _mode = 'manual';
      for (final Json c in widget.initial) {
        _rows.add(_ItemRow(name: str(c['name']), cost: str(c['baseCost'])));
      }
    }
  }

  @override
  void dispose() {
    for (final _ItemRow r in _rows) {
      r.name.dispose();
      r.cost.dispose();
    }
    super.dispose();
  }

  String get mode => _mode;

  /// Items to send: names always, costs only in manual mode.
  List<Json> items() => _rows
      .where((_ItemRow r) => r.name.text.trim().isNotEmpty)
      .map((_ItemRow r) => <String, dynamic>{'name': r.name.text.trim(), if (_mode == 'manual') 'cost': r.cost.text.trim().isEmpty ? '0' : r.cost.text.trim()})
      .toList(growable: false);

  String? validate() {
    final List<Json> list = items();
    if (list.isEmpty) return 'أضف بندًا واحدًا على الأقل أو ألغِ «تقسيم الأصل إلى بنود».';
    if (_mode == 'manual') {
      final double sum = _rows.where((_ItemRow r) => r.name.text.trim().isNotEmpty).fold<double>(0, (double s, _ItemRow r) => s + numOf(r.cost.text));
      if (_r2(sum) != _r2(widget.total())) return 'مجموع كلف البنود (${money(_r2(sum))}) لا يساوي كلفة الأصل (${money(_r2(widget.total()))}).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final int named = _rows.where((_ItemRow r) => r.name.text.trim().isNotEmpty).length;
    final double total = widget.total();
    final double equalShare = named == 0 ? 0 : _r2(total / named);
    final double sum = _rows.where((_ItemRow r) => r.name.text.trim().isNotEmpty).fold<double>(0, (double s, _ItemRow r) => s + numOf(r.cost.text));
    final double rest = _r2(total - sum);
    return Container(
      padding: const EdgeInsets.all(FinanceSpace.md),
      decoration: BoxDecoration(border: Border.all(color: FinanceColors.border), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('بنود الأصل', style: FinanceText.label),
              const SizedBox(width: FinanceSpace.md),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'equal', label: Text('توزيع بالتساوي')),
                  ButtonSegment<String>(value: 'manual', label: Text('توزيع يدوي')),
                ],
                selected: <String>{_mode},
                onSelectionChanged: (Set<String> s) => setState(() => _mode = s.first),
              ),
            ],
          ),
          const SizedBox(height: FinanceSpace.sm),
          for (int i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
              child: Row(
                children: <Widget>[
                  Expanded(child: FaTextField(label: 'اسم البند ${i + 1}', controller: _rows[i].name, onChanged: (_) => setState(() {}))),
                  const SizedBox(width: FinanceSpace.sm),
                  if (_mode == 'manual')
                    FaTextField(label: 'الكلفة', controller: _rows[i].cost, width: 150, numeric: true, onChanged: (_) => setState(() {}))
                  else
                    SizedBox(
                      width: 150,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'الحصة', isDense: true, border: OutlineInputBorder()),
                        child: Text(_rows[i].name.text.trim().isEmpty ? '—' : money(equalShare)),
                      ),
                    ),
                  IconButton(
                    tooltip: 'حذف البند',
                    onPressed: _rows.length <= 1
                        ? null
                        : () => setState(() {
                            final _ItemRow removed = _rows.removeAt(i);
                            removed.name.dispose();
                            removed.cost.dispose();
                          }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              TextButton.icon(onPressed: () => setState(() => _rows.add(_ItemRow())), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('إضافة بند')),
              const Spacer(),
              if (_mode == 'manual' && total > 0)
                Text(
                  rest == 0 ? 'مطابقة لكلفة الأصل' : (rest > 0 ? 'المتبقي للتوزيع: ${money(rest)}' : 'زيادة: ${money(rest.abs())}'),
                  style: FinanceText.body.copyWith(color: rest == 0 ? FinanceColors.success : FinanceColors.danger, fontWeight: FontWeight.w700),
                ),
              if (_mode == 'equal') Text('كلفة الأصل ${money(total)} ÷ $named', style: FinanceText.subtitle),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================ outlay allocation

/// أين تذهب الإضافة / الصيانة / المصروف: على الأصل كاملًا (بالتساوي على البنود أو يدويًا)،
/// أو كبند جديد داخل الأصل.
class OutlayAllocation extends StatefulWidget {
  const OutlayAllocation({super.key, required this.components, required this.amount, this.allowNewItem = true});

  /// Current items of the asset (card JSON `components`).
  final List<Json> components;
  final double Function() amount;
  final bool allowNewItem;

  @override
  State<OutlayAllocation> createState() => OutlayAllocationState();
}

class OutlayAllocationState extends State<OutlayAllocation> {
  String _scope = 'asset';
  String _distribution = 'equal';
  final TextEditingController _newName = TextEditingController();
  late final List<TextEditingController> _manual = widget.components.map((Json _) => TextEditingController()).toList(growable: false);

  @override
  void didUpdateWidget(covariant OutlayAllocation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.allowNewItem && _scope == 'new_component') _scope = 'asset';
  }

  @override
  void dispose() {
    _newName.dispose();
    for (final TextEditingController c in _manual) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasItems => widget.components.isNotEmpty;

  /// Fields to merge into the request body.
  Json toJson() {
    if (_scope == 'new_component') {
      return <String, dynamic>{'scope': 'new_component', 'componentName': _newName.text.trim()};
    }
    if (!_hasItems) return <String, dynamic>{'scope': 'asset'};
    if (_distribution == 'equal') return <String, dynamic>{'scope': 'asset', 'distribution': 'equal'};
    return <String, dynamic>{
      'scope': 'asset',
      'distribution': 'manual',
      'allocations': <Json>[
        for (int i = 0; i < widget.components.length; i++)
          if (numOf(_manual[i].text) > 0) <String, dynamic>{'componentId': intOf(widget.components[i]['id']), 'amount': _manual[i].text.trim()},
      ],
    };
  }

  String? validate() {
    if (_scope == 'new_component') return _newName.text.trim().isEmpty ? 'اسم البند الجديد مطلوب.' : null;
    if (_hasItems && _distribution == 'manual') {
      final double sum = _manual.fold<double>(0, (double s, TextEditingController c) => s + numOf(c.text));
      if (_r2(sum) != _r2(widget.amount())) return 'مجموع التوزيع على البنود (${money(_r2(sum))}) لا يساوي المبلغ (${money(_r2(widget.amount()))}).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final double amount = widget.amount();
    final double sum = _manual.fold<double>(0, (double s, TextEditingController c) => s + numOf(c.text));
    final double rest = _r2(amount - sum);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('التوزيع على بنود الأصل', style: FinanceText.label),
            const SizedBox(width: FinanceSpace.md),
            if (widget.allowNewItem)
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'asset', label: Text('على الأصل كاملًا')),
                  ButtonSegment<String>(value: 'new_component', label: Text('بند جديد')),
                ],
                selected: <String>{_scope},
                onSelectionChanged: (Set<String> s) => setState(() => _scope = s.first),
              ),
          ],
        ),
        const SizedBox(height: FinanceSpace.sm),
        if (_scope == 'new_component')
          FaTextField(label: 'اسم البند الجديد *', controller: _newName, width: 320)
        else if (!_hasItems)
          const Text('الأصل بلا بنود: تُضاف القيمة على الأصل مباشرة.', style: FinanceText.subtitle)
        else ...<Widget>[
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'equal', label: Text('بالتساوي على البنود')),
              ButtonSegment<String>(value: 'manual', label: Text('يدويًا لكل بند')),
            ],
            selected: <String>{_distribution},
            onSelectionChanged: (Set<String> s) => setState(() => _distribution = s.first),
          ),
          if (_distribution == 'manual') ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            Wrap(
              spacing: FinanceSpace.md,
              runSpacing: FinanceSpace.sm,
              children: <Widget>[
                for (int i = 0; i < widget.components.length; i++)
                  FaTextField(
                    label: '${widget.components[i]['name']} (${money(widget.components[i]['cost'])})',
                    controller: _manual[i],
                    width: 220,
                    numeric: true,
                    onChanged: (_) => setState(() {}),
                  ),
              ],
            ),
            const SizedBox(height: FinanceSpace.xs),
            Text(
              rest == 0 ? 'التوزيع مطابق للمبلغ' : (rest > 0 ? 'المتبقي للتوزيع: ${money(rest)}' : 'زيادة: ${money(rest.abs())}'),
              style: FinanceText.body.copyWith(color: rest == 0 ? FinanceColors.success : FinanceColors.danger, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ],
    );
  }
}
