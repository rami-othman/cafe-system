import 'package:flutter/material.dart';

import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/widgets/account_picker_field.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../pos/models/branch.dart';
import '../data/fa_api.dart';
import '../widgets/fa_widgets.dart';
import 'asset_split_widgets.dart';

/// Reference data every asset dialog needs, loaded once by the workspace / card.
class FaRefs {
  const FaRefs({
    required this.accounts,
    required this.branches,
    required this.categories,
    required this.locations,
  });

  final List<FinancialAccount> accounts;
  final List<Branch> branches;
  final List<Json> categories;
  final List<Json> locations;

  static Future<FaRefs> load(FaApi api) async {
    final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
      api.accounts(),
      api.branches(),
      api.categories(),
      api.locations(),
    ]);
    return FaRefs(
      accounts: r[0] as List<FinancialAccount>,
      branches: r[1] as List<Branch>,
      categories: r[2] as List<Json>,
      locations: r[3] as List<Json>,
    );
  }

  List<Json> locationsFor(String? branch) => locations
      .where((Json l) => (branch == null || branch == kCompanyBranch) ? l['branchId'] == null : '${l['branchId']}' == branch)
      .toList(growable: false);
}

String? _branchKey(dynamic id) => id == null ? kCompanyBranch : '$id';
int? _branchId(String? key) => key == null || key == kCompanyBranch ? null : int.tryParse(key);

// ============================================================================ asset form

/// Create a new asset, or edit one. For an active asset only descriptive fields
/// and the depreciation estimate (life, salvage, method) stay editable.
class AssetFormDialog extends StatefulWidget {
  const AssetFormDialog({super.key, required this.refs, this.asset});

  final FaRefs refs;
  final Json? asset;

  static Future<Json?> show(BuildContext context, FaRefs refs, {Json? asset}) =>
      showDialog<Json>(context: context, barrierDismissible: false, builder: (_) => AssetFormDialog(refs: refs, asset: asset));

  @override
  State<AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<AssetFormDialog> {
  final FaApi _api = FaApi();
  late final TextEditingController _name, _nameEn, _code, _cost, _salvage, _life, _barcode, _serial, _manufacturer, _notes, _openingAcc;
  int? _categoryId;
  String? _branch;
  int? _locationId;
  String _acquisitionDate = isoDate(DateTime.now());
  String? _startDate;
  String _method = 'straight_line';
  int? _fundingAccountId;
  String? _warrantyEnd;
  bool _isOpening = false;
  String? _openingUntil;
  bool _activate = true;
  bool _generateEntry = true;
  bool _customAccounts = false;
  bool _useItems = false;
  final GlobalKey<ComponentsEditorState> _itemsKey = GlobalKey<ComponentsEditorState>();
  final GlobalKey<PaymentsEditorState> _payKey = GlobalKey<PaymentsEditorState>();
  final Map<String, int?> _accounts = <String, int?>{'assetAccountId': null, 'accumulatedAccountId': null, 'expenseAccountId': null, 'gainAccountId': null, 'lossAccountId': null};
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.asset != null;
  bool get _isDraft => !_isEdit || widget.asset!['status'] == 'draft';

  @override
  void initState() {
    super.initState();
    final Json a = widget.asset ?? <String, dynamic>{};
    _name = TextEditingController(text: str(a['nameAr']));
    _nameEn = TextEditingController(text: str(a['nameEn']));
    _code = TextEditingController(text: str(a['code']));
    _cost = TextEditingController(text: a['acquisitionCost'] == null ? '' : str(a['acquisitionCost']));
    _salvage = TextEditingController(text: a['salvageValue'] == null ? '' : str(a['salvageValue']));
    _life = TextEditingController(text: a['usefulLifeMonths'] == null ? '' : str(a['usefulLifeMonths']));
    _barcode = TextEditingController(text: str(a['barcode']));
    _serial = TextEditingController(text: str(a['serialNumber']));
    _manufacturer = TextEditingController(text: str(a['manufacturer']));
    _notes = TextEditingController(text: str(a['notes']));
    _openingAcc = TextEditingController(text: a['openingAccumulated'] == null ? '' : str(a['openingAccumulated']));
    if (_isEdit) {
      _categoryId = intOf(a['categoryId']);
      _branch = _branchKey(a['branchId']);
      _locationId = intOf(a['locationId']);
      _acquisitionDate = str(a['acquisitionDate'], _acquisitionDate);
      _startDate = a['depreciationStartDate'] as String?;
      _method = str(a['method'], 'straight_line');
      _fundingAccountId = intOf(asJson(a['fundingAccount'])['id']);
      _warrantyEnd = a['warrantyEndDate'] as String?;
      _isOpening = a['isOpening'] == true;
      _openingUntil = a['depreciatedUntil'] as String?;
      _useItems = asJsonList(a['components']).isNotEmpty;
      final Json overrides = asJson(a['accountOverrides']);
      final Json accounts = asJson(a['accounts']);
      const Map<String, (String, String)> map = <String, (String, String)>{
        'assetAccountId': ('asset_account_id', 'asset'),
        'accumulatedAccountId': ('accumulated_account_id', 'accumulated'),
        'expenseAccountId': ('expense_account_id', 'expense'),
        'gainAccountId': ('gain_account_id', 'gain'),
        'lossAccountId': ('loss_account_id', 'loss'),
      };
      map.forEach((String key, (String, String) v) {
        if (overrides[v.$1] == true) {
          _accounts[key] = intOf(asJson(accounts[v.$2])['id']);
          _customAccounts = true;
        }
      });
    } else {
      _branch = widget.refs.branches.isNotEmpty ? '${widget.refs.branches.first.id}' : kCompanyBranch;
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_name, _nameEn, _code, _cost, _salvage, _life, _barcode, _serial, _manufacturer, _notes, _openingAcc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onCategory(int? id) {
    setState(() {
      _categoryId = id;
      final Json? c = widget.refs.categories.where((Json c) => c['id'] == id).firstOrNull;
      if (c != null && _isDraft) {
        _method = str(c['defaultMethod'], _method);
        if (_life.text.trim().isEmpty && c['defaultLifeMonths'] != null) _life.text = '${c['defaultLifeMonths']}';
      }
    });
  }

  Future<void> _save() async {
    final String cost = _cost.text.trim().isEmpty ? '0' : _cost.text.trim();
    if (_isDraft && _useItems) {
      final String? itemsError = _itemsKey.currentState?.validate();
      if (itemsError != null) {
        setState(() => _error = itemsError);
        return;
      }
    }
    final bool takesPayment = !_isEdit && _activate && _generateEntry && !_isOpening && numOf(cost) > 0;
    if (takesPayment && (_payKey.currentState?.isSplit ?? false)) {
      final String? payError = _payKey.currentState?.validate(cost);
      if (payError != null) {
        setState(() => _error = payError);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final Json data = <String, dynamic>{
      'nameAr': _name.text.trim(),
      'nameEn': _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
      'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      'serialNumber': _serial.text.trim().isEmpty ? null : _serial.text.trim(),
      'manufacturer': _manufacturer.text.trim().isEmpty ? null : _manufacturer.text.trim(),
      'warrantyEndDate': _warrantyEnd,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'usefulLifeMonths': int.tryParse(_life.text.trim()) ?? 0,
      'method': _method,
      'locationId': _locationId,
      if (_salvage.text.trim().isNotEmpty) 'salvageValue': _salvage.text.trim(),
    };
    if (_isDraft) {
      data.addAll(<String, dynamic>{
        if (_code.text.trim().isNotEmpty) 'code': _code.text.trim(),
        'categoryId': _categoryId,
        'branchId': _branchId(_branch),
        'acquisitionDate': _acquisitionDate,
        'depreciationStartDate': _startDate ?? _acquisitionDate,
        'acquisitionCost': _cost.text.trim().isEmpty ? '0' : _cost.text.trim(),
        'fundingAccountId': _fundingAccountId,
        'isOpening': _isOpening,
        'openingAccumulated': _isOpening ? (_openingAcc.text.trim().isEmpty ? '0' : _openingAcc.text.trim()) : '0',
        'openingDepreciatedUntil': _isOpening ? _openingUntil : null,
        ...(_customAccounts ? _accounts : <String, dynamic>{for (final String k in _accounts.keys) k: null}),
      });
      if (_useItems) {
        data['components'] = _itemsKey.currentState?.items() ?? <Json>[];
        data['componentsMode'] = _itemsKey.currentState?.mode ?? 'equal';
      } else if (_isEdit && asJsonList(widget.asset!['components']).isNotEmpty) {
        data['components'] = <Json>[]; // the user dropped the split into items
      }
      final PaymentsEditorState? pay = _payKey.currentState;
      if (pay != null && pay.isSplit && !_isEdit) {
        data['payments'] = pay.payments(cost);
        data['fundingAccountId'] = null;
      } else if (pay != null) {
        data['fundingAccountId'] = pay.singleAccountId;
      }
      if (!_isEdit) {
        data['activate'] = _activate;
        data['generateEntry'] = _generateEntry && !_isOpening;
      }
    }
    try {
      final Json result = _isEdit ? await _api.updateAsset(intOf(widget.asset!['id'])!, data) : await _api.createAsset(data);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool draft = _isDraft;
    final List<Json> locations = widget.refs.locationsFor(_branch);
    return FaDialog(
      title: _isEdit ? 'تعديل الأصل ${str(widget.asset!['code'])}' : 'أصل جديد',
      maxWidth: 860,
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FaBusyButton(label: _isEdit ? 'حفظ' : (_activate ? 'حفظ وتفعيل' : 'حفظ كمسودة'), busy: _busy, onPressed: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!draft)
            const Padding(
              padding: EdgeInsets.only(bottom: FinanceSpace.md),
              child: Text(
                'الأصل مفعّل: الصنف والفرع والكلفة والحسابات تتغير فقط عبر العمليات (إضافة، نقل، بيع). تعديل العمر أو الخردة يطبَّق على الاهتلاك القادم فقط.',
                style: FinanceText.subtitle,
              ),
            ),
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              FaTextField(label: 'اسم الأصل *', controller: _name, width: 380),
              FaTextField(label: 'الاسم اللاتيني', controller: _nameEn, width: 250),
              FaTextField(label: 'الرمز (تلقائي)', controller: _code, width: 140, enabled: draft),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<int?>(
                  initialValue: widget.refs.categories.any((Json c) => c['id'] == _categoryId) ? _categoryId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الصنف', isDense: true, border: OutlineInputBorder()),
                  items: widget.refs.categories
                      .where((Json c) => c['isActive'] != false)
                      .map((Json c) => DropdownMenuItem<int?>(value: intOf(c['id']), child: Text('${c['code']} - ${c['nameAr']}')))
                      .toList(growable: false),
                  onChanged: draft ? _onCategory : null,
                ),
              ),
              if (draft)
                FaBranchDropdown(
                  branches: widget.refs.branches,
                  value: _branch,
                  label: 'الفرع (موقع الأصل)',
                  onChanged: (String? v) => setState(() {
                    _branch = v;
                    _locationId = null;
                  }),
                ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey<String>('loc-$_branch'),
                  initialValue: locations.any((Json l) => l['id'] == _locationId) ? _locationId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الموقع الفرعي', isDense: true, border: OutlineInputBorder()),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(value: null, child: Text('—')),
                    ...locations.map((Json l) => DropdownMenuItem<int?>(value: intOf(l['id']), child: Text(str(l['name'])))),
                  ],
                  onChanged: (int? v) => setState(() => _locationId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          Text('الكلفة والاهتلاك', style: FinanceText.label),
          const SizedBox(height: FinanceSpace.sm),
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              if (draft) FaDateField(label: 'تاريخ الشراء', value: _acquisitionDate, onChanged: (String? v) => setState(() => _acquisitionDate = v ?? _acquisitionDate)),
              if (draft)
                FaDateField(
                  label: 'بدء الاهتلاك',
                  value: _startDate ?? _acquisitionDate,
                  onChanged: (String? v) => setState(() => _startDate = v),
                ),
              FaTextField(label: 'قيمة إدخال الأصل *', controller: _cost, width: 180, numeric: true, enabled: draft, onChanged: (_) => setState(() {})),
              FaTextField(label: 'قيمة الخردة', controller: _salvage, width: 150, numeric: true),
              FaTextField(
                label: 'العمر الإنتاجي (أشهر)',
                controller: _life,
                width: 170,
                integer: true,
                hint: '60 = 5 سنوات',
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'طريقة الاهتلاك', isDense: true, border: OutlineInputBorder()),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'straight_line', child: Text('القسط الثابت')),
                    DropdownMenuItem<String>(value: 'declining_balance', child: Text('القسط المتناقص (مضاعف)')),
                    DropdownMenuItem<String>(value: 'none', child: Text('بدون اهتلاك')),
                  ],
                  onChanged: (String? v) => setState(() => _method = v ?? 'straight_line'),
                ),
              ),
            ],
          ),
          if (draft) ...<Widget>[
            const SizedBox(height: FinanceSpace.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _isOpening,
              onChanged: (bool? v) => setState(() => _isOpening = v ?? false),
              title: const Text('رصيد افتتاحي (أصل منقول من نظام سابق — بدون قيد، رصيده موجود في الدفتر)'),
            ),
            if (_isOpening)
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.md,
                children: <Widget>[
                  FaTextField(label: 'مجمع الاهتلاك المسجّل', controller: _openingAcc, width: 200, numeric: true),
                  FaDateField(label: 'مهتلك حتى تاريخ', value: _openingUntil, onChanged: (String? v) => setState(() => _openingUntil = v), width: 200),
                ],
              )
            else
              PaymentsEditor(
                key: _payKey,
                label: 'حساب الإدخال (الصندوق / المورد / الشريك)',
                accounts: widget.refs.accounts,
                initialAccountId: _fundingAccountId,
                allowSplit: !_isEdit && _activate,
                total: () => numOf(_cost.text),
              ),
            const SizedBox(height: FinanceSpace.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _useItems,
              onChanged: (bool? v) => setState(() => _useItems = v ?? false),
              title: const Text('تقسيم الأصل إلى بنود (ما يتكوّن منه الأصل) وتوزيع الكلفة عليها'),
            ),
            if (_useItems)
              ComponentsEditor(
                key: _itemsKey,
                total: () => numOf(_cost.text),
                initial: _isEdit ? asJsonList(widget.asset!['components']) : const <Json>[],
              ),
          ],
          const SizedBox(height: FinanceSpace.lg),
          Text('معلومات إضافية', style: FinanceText.label),
          const SizedBox(height: FinanceSpace.sm),
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              FaTextField(label: 'الباركود', controller: _barcode, width: 180),
              FaTextField(label: 'الرقم التسلسلي', controller: _serial, width: 200),
              FaTextField(label: 'الشركة المصنّعة', controller: _manufacturer, width: 200),
              FaDateField(label: 'نهاية الكفالة', value: _warrantyEnd, allowClear: true, onChanged: (String? v) => setState(() => _warrantyEnd = v)),
              FaTextField(label: 'ملاحظات', controller: _notes, width: 600, maxLines: 2),
            ],
          ),
          if (draft) ...<Widget>[
            const SizedBox(height: FinanceSpace.md),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _customAccounts,
              onExpansionChanged: (bool open) => setState(() => _customAccounts = open),
              title: const Text('تخصيص الحسابات لهذا الأصل (الافتراضي من الصنف)'),
              children: <Widget>[
                for (final (String key, String label, List<String> groups) in <(String, String, List<String>)>[
                  ('assetAccountId', 'حساب الأصل', <String>['assets']),
                  ('accumulatedAccountId', 'مجمع الاهتلاك', <String>['assets']),
                  ('expenseAccountId', 'مصروف الاهتلاك', <String>['expenses', 'cost_of_sales']),
                  ('gainAccountId', 'أرباح رأسمالية', <String>['revenue']),
                  ('lossAccountId', 'خسائر رأسمالية', <String>['expenses']),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
                    child: AccountPickerField(
                      label: label,
                      accounts: widget.refs.accounts,
                      value: _accounts[key],
                      allowClear: true,
                      where: (FinancialAccount a) => groups.contains(a.accountGroup),
                      onChanged: (int? id) => setState(() => _accounts[key] = id),
                    ),
                  ),
              ],
            ),
          ],
          if (!_isEdit) ...<Widget>[
            const Divider(),
            Wrap(
              spacing: FinanceSpace.xl,
              children: <Widget>[
                _check('تفعيل الأصل مباشرة', _activate, (bool v) => setState(() => _activate = v)),
                if (!_isOpening) _check('توليد سند إدخال', _generateEntry, (bool v) => setState(() => _generateEntry = v)),
              ],
            ),
          ],
          FaErrorText(_error),
        ],
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Checkbox(value: value, onChanged: (bool? v) => onChanged(v ?? false)),
      Text(label),
    ],
  );
}

// ============================================================================ operations

enum AssetOperation { addition, maintenance, expense, disposal, transfer }

class AssetOperationDialog extends StatefulWidget {
  const AssetOperationDialog({super.key, required this.refs, required this.asset, required this.operation});

  final FaRefs refs;
  final Json asset;
  final AssetOperation operation;

  static Future<Json?> show(BuildContext context, FaRefs refs, Json asset, AssetOperation operation) => showDialog<Json>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AssetOperationDialog(refs: refs, asset: asset, operation: operation),
  );

  @override
  State<AssetOperationDialog> createState() => _AssetOperationDialogState();
}

class _AssetOperationDialogState extends State<AssetOperationDialog> {
  final FaApi _api = FaApi();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _life = TextEditingController();
  final TextEditingController _partial = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String _date = isoDate(DateTime.now());
  int? _counter;
  String _kind = 'sale';
  String? _toBranch;
  int? _toLocation;
  bool _busy = false;
  String? _error;
  final GlobalKey<PaymentsEditorState> _payKey = GlobalKey<PaymentsEditorState>();
  final GlobalKey<OutlayAllocationState> _allocKey = GlobalKey<OutlayAllocationState>();
  int? _expenseAccount;
  bool _capitalize = false;

  bool get _isOutlay =>
      widget.operation == AssetOperation.addition || widget.operation == AssetOperation.maintenance || widget.operation == AssetOperation.expense;

  @override
  void initState() {
    super.initState();
    _toBranch = _branchKey(widget.asset['branchId']);
  }

  @override
  void dispose() {
    _amount.dispose();
    _life.dispose();
    _partial.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _title => switch (widget.operation) {
    AssetOperation.addition => 'إضافة إلى الأصل',
    AssetOperation.maintenance => 'صيانة الأصل',
    AssetOperation.expense => 'مصروف على الأصل',
    AssetOperation.disposal => 'بيع / استبعاد الأصل',
    AssetOperation.transfer => 'نقل الأصل',
  };

  String get _amountLabel => switch (widget.operation) {
    AssetOperation.maintenance => 'قيمة الصيانة *',
    AssetOperation.expense => 'قيمة المصروف *',
    _ => 'قيمة الإضافة *',
  };

  String get _note => switch (widget.operation) {
    AssetOperation.transfer => 'يُهتلك الأصل تلقائيًا حتى اليوم السابق للنقل، ثم تنتقل الكلفة والمجمع للفرع الجديد (عبر جاري الفروع).',
    AssetOperation.disposal => 'يُهتلك الأصل تلقائيًا حتى تاريخ البيع، ثم يُسجَّل الربح أو الخسارة الرأسمالية.',
    AssetOperation.maintenance => 'الصيانة تُضاف إلى كلفة الأصل وتزيد عمره الإنتاجي، ثم تتوزع القيمة المتبقية على العمر الجديد.',
    AssetOperation.expense => 'المصروف لا يزيد عمر الأصل. الافتراضي: يُحمَّل على حساب المصروف مباشرة دون تغيير كلفة الأصل، أو فعّل الرسملة لإضافته إلى الكلفة.',
    AssetOperation.addition => 'يُهتلك الأصل تلقائيًا حتى اليوم السابق للإضافة، ثم تتوزع القيمة المتبقية على العمر المتبقي.',
  };

  /// Arabic message for the first problem found in an addition / maintenance / expense form.
  String? _outlayError() {
    final String amount = _amount.text.trim();
    if (numOf(amount) <= 0) return 'أدخل المبلغ (أكبر من صفر).';
    if (widget.operation == AssetOperation.maintenance && _life.text.trim().isEmpty) return 'أدخل زيادة العمر بالأشهر (0 إذا لا توجد زيادة).';
    if (widget.operation == AssetOperation.expense && !_capitalize && _expenseAccount == null) return 'حدد حساب المصروف.';
    return _payKey.currentState?.validate(amount) ?? _allocKey.currentState?.validate();
  }

  Json _outlayBody(String? description) {
    final String amount = _amount.text.trim();
    final bool expense = widget.operation == AssetOperation.expense;
    return <String, dynamic>{
      'date': _date,
      'amount': amount,
      'payments': _payKey.currentState?.payments(amount),
      'description': description,
      if (!expense) 'lifeExtensionMonths': int.tryParse(_life.text.trim()) ?? 0,
      if (expense) 'capitalize': _capitalize,
      if (expense && !_capitalize) 'expenseAccountId': _expenseAccount,
      ...?_allocKey.currentState?.toJson(),
    };
  }

  Future<void> _submit() async {
    if (_isOutlay) {
      final String? problem = _outlayError();
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final int id = intOf(widget.asset['id'])!;
    final String? description = _description.text.trim().isEmpty ? null : _description.text.trim();
    try {
      final Json result = switch (widget.operation) {
        AssetOperation.addition => await _api.addition(id, _outlayBody(description)),
        AssetOperation.maintenance => await _api.maintenance(id, _outlayBody(description)),
        AssetOperation.expense => await _api.expense(id, _outlayBody(description)),
        AssetOperation.disposal => await _api.disposal(id, <String, dynamic>{
          'date': _date,
          'kind': _kind,
          'proceeds': _kind == 'sale' ? (_amount.text.trim().isEmpty ? '0' : _amount.text.trim()) : '0',
          'counterAccountId': _kind == 'sale' ? _counter : null,
          if (_partial.text.trim().isNotEmpty) 'costAmount': _partial.text.trim(),
          'description': description,
        }),
        AssetOperation.transfer => await _api.transfer(id, <String, dynamic>{
          'date': _date,
          'toBranchId': _branchId(_toBranch),
          'toLocationId': _toLocation,
          'description': description,
        }),
      };
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double book = numOf(widget.asset['bookValue']);
    final double proceeds = numOf(_amount.text);
    final double cost = numOf(widget.asset['cost']);
    final double partial = _partial.text.trim().isEmpty ? cost : numOf(_partial.text);
    final double share = cost == 0 ? 0 : partial / cost;
    final double gain = (_kind == 'sale' ? proceeds : 0) - book * share;
    return FaDialog(
      title: '$_title — ${str(widget.asset['nameAr'])}',
      maxWidth: _isOutlay ? 780 : 640,
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FaBusyButton(label: 'ترحيل', busy: _busy, onPressed: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FaFacts(items: <(String, String)>[
            ('الكلفة الحالية', money(widget.asset['cost'])),
            ('مجمع الاهتلاك', money(widget.asset['accumulated'])),
            ('القيمة الدفترية', money(widget.asset['bookValue'])),
            ('مهتلك حتى', str(widget.asset['depreciatedUntil'], '—')),
          ], itemWidth: 130),
          const SizedBox(height: FinanceSpace.md),
          Text(_note, style: FinanceText.subtitle),
          const SizedBox(height: FinanceSpace.md),
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              FaDateField(label: 'التاريخ', value: _date, onChanged: (String? v) => setState(() => _date = v ?? _date)),
              if (widget.operation == AssetOperation.disposal)
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'sale', label: Text('بيع')),
                    ButtonSegment<String>(value: 'scrap', label: Text('إتلاف / استبعاد')),
                  ],
                  selected: <String>{_kind},
                  onSelectionChanged: (Set<String> s) => setState(() => _kind = s.first),
                ),
              if (_isOutlay) ...<Widget>[
                FaTextField(label: _amountLabel, controller: _amount, width: 180, numeric: true, onChanged: (_) => setState(() {})),
                if (widget.operation != AssetOperation.expense)
                  FaTextField(
                    label: widget.operation == AssetOperation.maintenance ? 'زيادة العمر (أشهر) *' : 'زيادة العمر (أشهر)',
                    controller: _life,
                    width: 190,
                    integer: true,
                  ),
              ],
              if (widget.operation == AssetOperation.disposal) ...<Widget>[
                if (_kind == 'sale') FaTextField(label: 'سعر البيع', controller: _amount, width: 170, numeric: true, onChanged: (_) => setState(() {})),
                FaTextField(label: 'كلفة جزئية (اتركه فارغًا للكامل)', controller: _partial, width: 240, numeric: true, onChanged: (_) => setState(() {})),
              ],
              if (widget.operation == AssetOperation.transfer) ...<Widget>[
                FaBranchDropdown(
                  branches: widget.refs.branches,
                  value: _toBranch,
                  label: 'إلى الفرع',
                  onChanged: (String? v) => setState(() {
                    _toBranch = v;
                    _toLocation = null;
                  }),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey<String>('to-loc-$_toBranch'),
                    initialValue: null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'إلى الموقع الفرعي', isDense: true, border: OutlineInputBorder()),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(value: null, child: Text('—')),
                      ...widget.refs.locationsFor(_toBranch).map((Json l) => DropdownMenuItem<int?>(value: intOf(l['id']), child: Text(str(l['name'])))),
                    ],
                    onChanged: (int? v) => setState(() => _toLocation = v),
                  ),
                ),
              ],
            ],
          ),
          if (widget.operation == AssetOperation.disposal && _kind == 'sale') ...<Widget>[
            const SizedBox(height: FinanceSpace.md),
            AccountPickerField(
              label: 'حساب قبض الثمن (الصندوق / العميل)',
              accounts: widget.refs.accounts,
              value: _counter,
              onChanged: (int? id) => setState(() => _counter = id),
            ),
          ],
          if (_isOutlay) ...<Widget>[
            if (widget.operation == AssetOperation.expense) ...<Widget>[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _capitalize,
                onChanged: (bool? v) => setState(() => _capitalize = v ?? false),
                title: const Text('رسملة المصروف (يُضاف إلى كلفة الأصل بدل تحميله على حساب المصروف)'),
              ),
              if (!_capitalize)
                Padding(
                  padding: const EdgeInsets.only(bottom: FinanceSpace.md),
                  child: AccountPickerField(
                    label: 'حساب المصروف *',
                    accounts: widget.refs.accounts,
                    value: _expenseAccount,
                    where: (FinancialAccount a) => a.accountGroup == 'expenses' || a.accountGroup == 'cost_of_sales',
                    onChanged: (int? id) => setState(() => _expenseAccount = id),
                  ),
                ),
            ],
            const SizedBox(height: FinanceSpace.md),
            PaymentsEditor(
              key: _payKey,
              label: 'حساب الدفع (الصندوق / المورد / الشريك)',
              accounts: widget.refs.accounts,
              total: () => numOf(_amount.text),
            ),
            const SizedBox(height: FinanceSpace.md),
            OutlayAllocation(
              key: _allocKey,
              components: asJsonList(widget.asset['components']),
              amount: () => numOf(_amount.text),
              allowNewItem: widget.operation != AssetOperation.expense || _capitalize,
            ),
          ],
          if (widget.operation == AssetOperation.disposal) ...<Widget>[
            const SizedBox(height: FinanceSpace.md),
            Text(
              'تقديريًا (قبل اهتلاك المدة المتبقية): ${gain >= 0 ? 'ربح' : 'خسارة'} رأسمالي ${money(gain.abs())}',
              style: FinanceText.body.copyWith(color: gain >= 0 ? FinanceColors.success : FinanceColors.danger, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: FinanceSpace.md),
          FaTextField(label: 'البيان', controller: _description),
          FaErrorText(_error),
        ],
      ),
    );
  }
}

// ============================================================================ category

class AssetCategoryDialog extends StatefulWidget {
  const AssetCategoryDialog({super.key, required this.refs, this.category});

  final FaRefs refs;
  final Json? category;

  static Future<bool?> show(BuildContext context, FaRefs refs, {Json? category}) =>
      showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => AssetCategoryDialog(refs: refs, category: category));

  @override
  State<AssetCategoryDialog> createState() => _AssetCategoryDialogState();
}

class _AssetCategoryDialogState extends State<AssetCategoryDialog> {
  final FaApi _api = FaApi();
  late final TextEditingController _code, _name, _life, _salvage;
  final Map<String, int?> _accounts = <String, int?>{};
  String _method = 'straight_line';
  int? _parentId;
  bool _active = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Json c = widget.category ?? <String, dynamic>{};
    _code = TextEditingController(text: str(c['code']));
    _name = TextEditingController(text: str(c['nameAr']));
    _life = TextEditingController(text: c['defaultLifeMonths'] == null ? '' : '${c['defaultLifeMonths']}');
    _salvage = TextEditingController(text: c['defaultSalvagePercent'] == null ? '' : str(c['defaultSalvagePercent']));
    _method = str(c['defaultMethod'], 'straight_line');
    _parentId = intOf(c['parentId']);
    _active = c['isActive'] != false;
    for (final (String key, String field) in <(String, String)>[
      ('assetAccountId', 'assetAccount'),
      ('accumulatedAccountId', 'accumulatedAccount'),
      ('expenseAccountId', 'expenseAccount'),
      ('gainAccountId', 'gainAccount'),
      ('lossAccountId', 'lossAccount'),
    ]) {
      _accounts[key] = intOf(asJson(c[field])['id']);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _life.dispose();
    _salvage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.saveCategory(<String, dynamic>{
        'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
        'nameAr': _name.text.trim(),
        'parentId': _parentId,
        'defaultMethod': _method,
        'defaultLifeMonths': int.tryParse(_life.text.trim()),
        'defaultSalvagePercent': _salvage.text.trim().isEmpty ? 0 : numOf(_salvage.text),
        'isActive': _active,
        ..._accounts,
      }, id: intOf(widget.category?['id']));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FaDialog(
    title: widget.category == null ? 'صنف أصول جديد' : 'تعديل الصنف',
    actions: <Widget>[
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FaBusyButton(label: 'حفظ', busy: _busy, onPressed: _save),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: FinanceSpace.md,
          runSpacing: FinanceSpace.md,
          children: <Widget>[
            FaTextField(label: 'الرمز (تلقائي)', controller: _code, width: 130),
            FaTextField(label: 'اسم الصنف *', controller: _name, width: 300),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<int?>(
                initialValue: widget.refs.categories.any((Json c) => c['id'] == _parentId) ? _parentId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الصنف الأب', isDense: true, border: OutlineInputBorder()),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(value: null, child: Text('—')),
                  ...widget.refs.categories
                      .where((Json c) => c['id'] != widget.category?['id'])
                      .map((Json c) => DropdownMenuItem<int?>(value: intOf(c['id']), child: Text(str(c['nameAr'])))),
                ],
                onChanged: (int? v) => setState(() => _parentId = v),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'طريقة الاهتلاك', isDense: true, border: OutlineInputBorder()),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'straight_line', child: Text('القسط الثابت')),
                  DropdownMenuItem<String>(value: 'declining_balance', child: Text('القسط المتناقص (مضاعف)')),
                  DropdownMenuItem<String>(value: 'none', child: Text('بدون اهتلاك')),
                ],
                onChanged: (String? v) => setState(() => _method = v ?? 'straight_line'),
              ),
            ),
            FaTextField(label: 'العمر الافتراضي (أشهر)', controller: _life, width: 190, integer: true),
            FaTextField(label: 'نسبة الخردة %', controller: _salvage, width: 140, numeric: true),
          ],
        ),
        const SizedBox(height: FinanceSpace.lg),
        for (final (String key, String label, List<String> groups) in <(String, String, List<String>)>[
          ('assetAccountId', 'حساب الأصل', <String>['assets']),
          ('accumulatedAccountId', 'حساب مجمع الاهتلاك', <String>['assets']),
          ('expenseAccountId', 'حساب مصروف الاهتلاك', <String>['expenses', 'cost_of_sales']),
          ('gainAccountId', 'حساب الأرباح الرأسمالية', <String>['revenue']),
          ('lossAccountId', 'حساب الخسائر الرأسمالية', <String>['expenses']),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
            child: AccountPickerField(
              label: label,
              accounts: widget.refs.accounts,
              value: _accounts[key],
              allowClear: true,
              where: (FinancialAccount a) => groups.contains(a.accountGroup),
              onChanged: (int? id) => setState(() => _accounts[key] = id),
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (bool? v) => setState(() => _active = v ?? true),
          title: const Text('فعّال'),
        ),
        FaErrorText(_error),
      ],
    ),
  );
}

// ============================================================================ location

class AssetLocationDialog extends StatefulWidget {
  const AssetLocationDialog({super.key, required this.refs, this.location});

  final FaRefs refs;
  final Json? location;

  static Future<bool?> show(BuildContext context, FaRefs refs, {Json? location}) =>
      showDialog<bool>(context: context, builder: (_) => AssetLocationDialog(refs: refs, location: location));

  @override
  State<AssetLocationDialog> createState() => _AssetLocationDialogState();
}

class _AssetLocationDialogState extends State<AssetLocationDialog> {
  final FaApi _api = FaApi();
  late final TextEditingController _name = TextEditingController(text: str(widget.location?['name']));
  late String? _branch = widget.location == null
      ? (widget.refs.branches.isNotEmpty ? '${widget.refs.branches.first.id}' : kCompanyBranch)
      : _branchKey(widget.location!['branchId']);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.saveLocation(<String, dynamic>{'name': _name.text.trim(), 'branchId': _branchId(_branch), 'isActive': true}, id: intOf(widget.location?['id']));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FaDialog(
    title: widget.location == null ? 'موقع فرعي جديد' : 'تعديل الموقع',
    maxWidth: 520,
    actions: <Widget>[
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FaBusyButton(label: 'حفظ', busy: _busy, onPressed: _save),
    ],
    child: Wrap(
      spacing: FinanceSpace.md,
      runSpacing: FinanceSpace.md,
      children: <Widget>[
        FaTextField(label: 'اسم الموقع (مثل: البار، الصالة، المستودع)', controller: _name, width: 440),
        FaBranchDropdown(branches: widget.refs.branches, value: _branch, onChanged: (String? v) => setState(() => _branch = v)),
        FaErrorText(_error),
      ],
    ),
  );
}

// ============================================================================ depreciation run

class DepreciationRunDialog extends StatefulWidget {
  const DepreciationRunDialog({super.key, required this.refs, required this.suggestedEnd});

  final FaRefs refs;
  final String suggestedEnd;

  static Future<Json?> show(BuildContext context, FaRefs refs, String suggestedEnd) => showDialog<Json>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DepreciationRunDialog(refs: refs, suggestedEnd: suggestedEnd),
  );

  @override
  State<DepreciationRunDialog> createState() => _DepreciationRunDialogState();
}

class _DepreciationRunDialogState extends State<DepreciationRunDialog> {
  final FaApi _api = FaApi();
  final TextEditingController _description = TextEditingController();
  late String _periodEnd = widget.suggestedEnd;
  String? _branch;
  int? _categoryId;
  Json? _preview;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Json get _filters => <String, dynamic>{
    'periodEnd': _periodEnd,
    'branchId': _branch,
    'categoryId': _categoryId,
    'description': _description.text.trim(),
  };

  Future<void> _doPreview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Json p = await _api.previewRun(_filters);
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Json run = await _api.postRun(_filters);
      if (mounted) Navigator.pop(context, run);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Json> lines = asJsonList(_preview?['lines']);
    return FaDialog(
      title: 'مذكرة اهتلاك جديدة',
      maxWidth: 1100,
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        OutlinedButton.icon(onPressed: _busy ? null : _doPreview, icon: const Icon(Icons.visibility_outlined, size: 18), label: const Text('معاينة')),
        FaBusyButton(label: 'ترحيل المذكرة', busy: _busy, onPressed: _preview == null || lines.isEmpty ? null : _post, icon: Icons.task_alt_rounded),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FaDateField(label: 'حتى تاريخ', value: _periodEnd, onChanged: (String? v) => setState(() {
                _periodEnd = v ?? _periodEnd;
                _preview = null;
              })),
              FaBranchDropdown(
                branches: widget.refs.branches,
                value: _branch,
                includeAll: true,
                onChanged: (String? v) => setState(() {
                  _branch = v;
                  _preview = null;
                }),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الصنف', isDense: true, border: OutlineInputBorder()),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(value: null, child: Text('كل الأصناف')),
                    ...widget.refs.categories.map((Json c) => DropdownMenuItem<int?>(value: intOf(c['id']), child: Text(str(c['nameAr'])))),
                  ],
                  onChanged: (int? v) => setState(() {
                    _categoryId = v;
                    _preview = null;
                  }),
                ),
              ),
              FaTextField(label: 'البيان', controller: _description, width: 320),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          if (_preview == null)
            const Text('اضغط «معاينة» لحساب الاهتلاك المستحق لكل أصل حتى التاريخ المحدد.', style: FinanceText.subtitle)
          else ...<Widget>[
            Wrap(
              spacing: FinanceSpace.md,
              children: <Widget>[
                FaStat(label: 'عدد الأصول', value: '${_preview!['assetsCount']}'),
                FaStat(label: 'إجمالي الاهتلاك', value: money(_preview!['total'])),
              ],
            ),
            const SizedBox(height: FinanceSpace.md),
            FaTable(
              minWidth: 1000,
              columns: const <String>['الأصل', 'الفرع', 'من', 'إلى', 'الأيام', 'الكلفة', 'المجمع السابق', 'قيمة الاهتلاك', 'القيمة الجديدة'],
              flex: const <int>[4, 2, 2, 2, 1, 2, 2, 2, 2],
              emptyMessage: 'لا يوجد اهتلاك مستحق حتى هذا التاريخ.',
              rows: lines
                  .map((Json l) => <Widget>[
                        faCell('${l['assetCode']} - ${l['assetName']}'),
                        faCell(str(l['branchName'])),
                        faCell(str(l['from']), ltr: true),
                        faCell(str(l['to']), ltr: true),
                        faCell(str(l['days'])),
                        faMoneyCell(l['cost']),
                        faMoneyCell(l['accumulatedBefore']),
                        faMoneyCell(l['amount'], bold: true),
                        faMoneyCell(l['bookValueAfter']),
                      ])
                  .toList(growable: false),
            ),
          ],
          FaErrorText(_error),
        ],
      ),
    );
  }
}
