import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/widgets/account_picker_field.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../fixed_assets/data/fa_api.dart';
import '../../fixed_assets/widgets/fa_widgets.dart';
import '../../pos/models/branch.dart';
import 'overhead_tab.dart';

/// الشركاء والمستثمرون: الشركة الأم شريك، ولكل فرع نسب ملكية مؤرخة، وتوزيع
/// نتيجة الفرع على الشركاء بعد أتعاب الإدارة (اختيارية لكل فرع).
class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersRefs {
  const _PartnersRefs(this.accounts, this.branches, this.partners);

  final List<FinancialAccount> accounts;
  final List<Branch> branches;
  final List<Json> partners;
}

class _PartnersScreenState extends State<PartnersScreen> {
  final FaApi _api = FaApi();
  _PartnersRefs? _refs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[_api.accounts(), _api.branches(), _api.partners()]);
      if (mounted) setState(() => _refs = _PartnersRefs(r[0] as List<FinancialAccount>, r[1] as List<Branch>, r[2] as List<Json>));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return FinanceErrorState(message: _error!, onRetry: _load);
    if (_refs == null) return const FinanceLoadingState();
    return DefaultTabController(
      length: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const FinancePageHeader(
            title: 'الشركاء والمستثمرون',
            subtitle: 'ملكية كل فرع (الشركة + المستثمرون)، رأس المال والحسابات الجارية، وتوزيع نتيجة الفرع على الشركاء.',
          ),
          const SizedBox(height: FinanceSpace.md),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: FinanceColors.primary,
            indicatorColor: FinanceColors.accent,
            tabs: <Tab>[
              Tab(text: 'نتائج الفروع'),
              Tab(text: 'الشركاء'),
              Tab(text: 'ملكية الفروع'),
              Tab(text: 'توزيع الأرباح'),
              Tab(text: 'مصاريف الإدارة'),
              Tab(text: 'حركات الشركاء'),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                _OverviewTab(refs: _refs!),
                _PartnersTab(refs: _refs!, onChanged: _load),
                _OwnershipTab(refs: _refs!),
                _DistributionsTab(refs: _refs!, onChanged: _load),
                OverheadTab(branches: _refs!.branches),
                _MovementsTab(refs: _refs!, onChanged: _load),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _monthStart() => isoDate(DateTime(DateTime.now().year, DateTime.now().month, 1));

// ============================================================================ overview

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.refs});

  final _PartnersRefs refs;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  String _from = _monthStart();
  String _to = isoDate(DateTime.now());
  List<Json>? _rows;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Json> rows = await _api.overview(_from, _to);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final List<Json> rows = _rows ?? const <Json>[];
    double sum(String key) => rows.fold<double>(0, (double s, Json r) => s + numOf(r[key]));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FinanceFilterBar(
          children: <Widget>[
            FaDateField(label: 'من', value: _from, width: 160, onChanged: (String? v) => setState(() => _from = v ?? _from)),
            FaDateField(label: 'إلى', value: _to, width: 160, onChanged: (String? v) => setState(() => _to = v ?? _to)),
            FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.search_rounded, size: 18), label: const Text('عرض')),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        Expanded(
          child: _error != null
              ? FinanceErrorState(message: _error!, onRetry: _load)
              : _rows == null
              ? const FinanceLoadingState()
              : SingleChildScrollView(
                  child: FaTable(
                    minWidth: 1100,
                    columns: const <String>['الفرع', 'الإيرادات', 'تكلفة المبيعات', 'المصاريف', 'صافي النتيجة', 'الملكية الحالية', 'آخر توزيع'],
                    flex: const <int>[2, 2, 2, 2, 2, 4, 2],
                    rows: rows
                        .map((Json r) => <Widget>[
                              faCell(str(r['branchName']), bold: true),
                              faMoneyCell(r['revenue']),
                              faMoneyCell(r['costOfSales']),
                              faMoneyCell(r['operatingExpenses']),
                              faMoneyCell(r['netProfit'], bold: true, color: numOf(r['netProfit']) >= 0 ? FinanceColors.success : FinanceColors.danger),
                              faCell(
                                asJsonList(r['owners']).isEmpty
                                    ? 'الشركة 100%'
                                    : asJsonList(r['owners']).map((Json o) => '${o['partnerName']} ${o['sharePercent']}%').join(' · '),
                              ),
                              faCell(str(r['lastDistributionTo'], '—'), ltr: true),
                            ])
                        .toList(growable: false),
                    footer: <Widget>[
                      faCell('الإجمالي', bold: true),
                      faMoneyCell(sum('revenue'), bold: true),
                      faMoneyCell(sum('costOfSales'), bold: true),
                      faMoneyCell(sum('operatingExpenses'), bold: true),
                      faMoneyCell(sum('netProfit'), bold: true),
                      const SizedBox.shrink(),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================================ partners

class _PartnersTab extends StatelessWidget {
  const _PartnersTab({required this.refs, required this.onChanged});

  final _PartnersRefs refs;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context, {Json? partner}) async {
    final bool? ok = await showDialog<bool>(context: context, builder: (_) => _PartnerDialog(refs: refs, partner: partner));
    if (ok == true) onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'لكل شريك ثلاثة حسابات تُنشأ تلقائيًا: رأس المال، الحساب الجاري (تُرحَّل إليه حصص الأرباح)، والمسحوبات. الشركة نفسها شريك في كل فرع.',
              style: FinanceText.subtitle,
            ),
          ),
          FilledButton.icon(onPressed: () => _edit(context), icon: const Icon(Icons.person_add_alt_1_outlined, size: 18), label: const Text('مستثمر جديد')),
        ],
      ),
      const SizedBox(height: FinanceSpace.md),
      Expanded(
        child: SingleChildScrollView(
          child: FaTable(
            minWidth: 1150,
            columns: const <String>['الشريك', 'النوع', 'الفروع والنسب', 'رأس المال', 'الحساب الجاري', 'المسحوبات', 'صافي المركز', ''],
            flex: const <int>[3, 1, 4, 2, 2, 2, 2, 2],
            rows: refs.partners
                .map((Json p) => <Widget>[
                      faCell(str(p['name']), bold: true),
                      faCell(p['kind'] == 'company' ? 'الشركة' : 'مستثمر'),
                      faCell(asJsonList(p['branches']).map((Json b) => '${b['branchName']} ${b['sharePercent']}%').join(' · ')),
                      faMoneyCell(asJson(p['capitalAccount'])['balance']),
                      faMoneyCell(asJson(p['currentAccount'])['balance']),
                      faMoneyCell(asJson(p['drawingsAccount'])['balance']),
                      faMoneyCell(p['netPosition'], bold: true),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'كشف الحساب',
                            icon: const Icon(Icons.receipt_long_outlined, size: 18),
                            onPressed: () => context.go('/finance/partners/${p['id']}'),
                          ),
                          IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _edit(context, partner: p)),
                        ],
                      ),
                    ])
                .toList(growable: false),
          ),
        ),
      ),
    ],
  );
}

class _PartnerDialog extends StatefulWidget {
  const _PartnerDialog({required this.refs, this.partner});

  final _PartnersRefs refs;
  final Json? partner;

  @override
  State<_PartnerDialog> createState() => _PartnerDialogState();
}

class _PartnerDialogState extends State<_PartnerDialog> {
  late final TextEditingController _name = TextEditingController(text: str(widget.partner?['name']));
  late final TextEditingController _phone = TextEditingController(text: str(widget.partner?['phone']));
  late final TextEditingController _notes = TextEditingController(text: str(widget.partner?['notes']));
  int? _capital;
  int? _current;
  int? _drawings;
  int? _userId;
  List<Json> _users = const <Json>[];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userId = intOf(widget.partner?['userId']);
    FaApi().linkableUsers().then((List<Json> list) {
      if (mounted) setState(() => _users = list);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FaApi().savePartner(<String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'notes': _notes.text.trim(),
        'userId': _userId,
        if (widget.partner == null) ...<String, dynamic>{
          'kind': 'investor',
          'capitalAccountId': _capital,
          'currentAccountId': _current,
          'drawingsAccountId': _drawings,
        },
      }, id: intOf(widget.partner?['id']));
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
    title: widget.partner == null ? 'مستثمر جديد' : 'تعديل ${widget.partner!['name']}',
    maxWidth: 620,
    actions: <Widget>[
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FaBusyButton(label: 'حفظ', busy: _busy, onPressed: _save),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FaTextField(label: 'الاسم *', controller: _name),
        const SizedBox(height: FinanceSpace.md),
        FaTextField(label: 'الهاتف', controller: _phone),
        const SizedBox(height: FinanceSpace.md),
        FaTextField(label: 'ملاحظات', controller: _notes, maxLines: 2),
        const SizedBox(height: FinanceSpace.md),
        DropdownButtonFormField<int?>(
          initialValue: _users.any((Json u) => intOf(u['id']) == _userId) ? _userId : null,
          key: ValueKey<int>(_users.length),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'ربط بمستخدم (بوابة المستثمر)',
            helperText: 'المستخدم يرى حصصه وكشف حسابه فقط — امنحه صلاحية «بوابة المستثمر» من أدوار المالية.',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(value: null, child: Text('— بدون —')),
            ..._users.map((Json u) => DropdownMenuItem<int?>(
              value: intOf(u['id']),
              child: Text('${u['name']} (${u['email']})${u['linkedPartner'] != null && intOf(u['id']) != intOf(widget.partner?['userId']) ? ' — مرتبط بـ ${u['linkedPartner']}' : ''}'),
            )),
          ],
          onChanged: (int? v) => setState(() => _userId = v),
        ),
        if (widget.partner == null) ...<Widget>[
          const SizedBox(height: FinanceSpace.lg),
          const Text('اختياري: اربط حسابات موجودة (مثل «رأس مال عبدالله» في الدليل). اتركها فارغة لإنشاء حسابات جديدة.', style: FinanceText.subtitle),
          const SizedBox(height: FinanceSpace.sm),
          AccountPickerField(
            label: 'حساب رأس المال',
            accounts: widget.refs.accounts,
            value: _capital,
            allowClear: true,
            where: (FinancialAccount a) => a.accountGroup == 'equity',
            onChanged: (int? v) => setState(() => _capital = v),
          ),
          const SizedBox(height: FinanceSpace.sm),
          AccountPickerField(
            label: 'الحساب الجاري',
            accounts: widget.refs.accounts,
            value: _current,
            allowClear: true,
            where: (FinancialAccount a) => a.accountGroup == 'liabilities',
            onChanged: (int? v) => setState(() => _current = v),
          ),
          const SizedBox(height: FinanceSpace.sm),
          AccountPickerField(
            label: 'حساب المسحوبات',
            accounts: widget.refs.accounts,
            value: _drawings,
            allowClear: true,
            onChanged: (int? v) => setState(() => _drawings = v),
          ),
        ],
        FaErrorText(_error),
      ],
    ),
  );
}

// ============================================================================ ownership

class _OwnershipTab extends StatefulWidget {
  const _OwnershipTab({required this.refs});

  final _PartnersRefs refs;

  @override
  State<_OwnershipTab> createState() => _OwnershipTabState();
}

class _ShareRow {
  _ShareRow(this.partnerId, String percent) : percent = TextEditingController(text: percent);

  int? partnerId;
  final TextEditingController percent;
}

class _OwnershipTabState extends State<_OwnershipTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  int? _branchId;
  Json? _data;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String _effectiveFrom = _monthStart();
  final List<_ShareRow> _rows = <_ShareRow>[];
  String _feeType = 'none';
  final TextEditingController _feePercent = TextEditingController();
  int? _feePartner;
  bool _carry = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.refs.branches.isNotEmpty) {
      _branchId = widget.refs.branches.first.id;
      _load();
    }
  }

  @override
  void dispose() {
    for (final _ShareRow r in _rows) {
      r.percent.dispose();
    }
    _feePercent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_branchId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Json d = await _api.ownership(_branchId!);
      if (!mounted) return;
      setState(() {
        _data = d;
        for (final _ShareRow r in _rows) {
          r.percent.dispose();
        }
        _rows.clear();
        final List<Json> current = asJsonList(d['current']);
        if (current.isEmpty) {
          final Json? company = widget.refs.partners.where((Json p) => p['kind'] == 'company').firstOrNull;
          _rows.add(_ShareRow(intOf(company?['id']), '100'));
        } else {
          for (final Json s in current) {
            _rows.add(_ShareRow(intOf(s['partnerId']), str(s['sharePercent'])));
          }
        }
        final Json settings = asJson(d['settings']);
        _feeType = str(settings['managementFeeType'], 'none');
        _feePercent.text = str(settings['managementFeePercent'], '0');
        _feePartner = intOf(settings['managementFeePartnerId']);
        _carry = settings['carryForwardLosses'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _total => _rows.fold<double>(0, (double s, _ShareRow r) => s + numOf(r.percent.text));

  Json get _settingsPayload => <String, dynamic>{
    'managementFeeType': _feeType,
    'managementFeePercent': _feeType == 'none' ? 0 : numOf(_feePercent.text),
    'managementFeePartnerId': _feePartner,
    'carryForwardLosses': _carry,
  };

  Future<void> _saveShares() async {
    setState(() => _saving = true);
    try {
      final Json d = await _api.setOwnership(_branchId!, <String, dynamic>{
        'effectiveFrom': _effectiveFrom,
        'shares': _rows
            .where((_ShareRow r) => r.partnerId != null)
            .map((_ShareRow r) => <String, dynamic>{'partnerId': r.partnerId, 'sharePercent': numOf(r.percent.text)})
            .toList(growable: false),
        'settings': _settingsPayload,
      });
      if (mounted) {
        setState(() => _data = d);
        showFaMessage(context, 'تم حفظ نسب الملكية اعتبارًا من $_effectiveFrom.');
      }
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final Json d = await _api.saveBranchSettings(_branchId!, _settingsPayload);
      if (mounted) {
        setState(() => _data = d);
        showFaMessage(context, 'تم حفظ إعدادات التوزيع.');
      }
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.refs.branches.isEmpty) return const FinanceEmptyState(message: 'لا توجد فروع.');
    final List<Json> partners = widget.refs.partners;
    final double total = _total;
    return ListView(
      children: <Widget>[
        Wrap(
          spacing: FinanceSpace.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FaBranchDropdown(
              branches: widget.refs.branches,
              value: _branchId == null ? null : '$_branchId',
              includeCompany: false,
              onChanged: (String? v) {
                setState(() => _branchId = int.tryParse(v ?? ''));
                _load();
              },
            ),
            if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            if (_data?['lastDistributionTo'] != null) Text('آخر توزيع حتى ${_data!['lastDistributionTo']}', style: FinanceText.subtitle),
          ],
        ),
        if (_error != null) FinanceErrorState(message: _error!, onRetry: _load),
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'نسب الملكية',
          actions: <Widget>[
            Text('المجموع ${money(total)}%', style: FinanceText.body.copyWith(color: (total - 100).abs() < 0.0001 ? FinanceColors.success : FinanceColors.danger, fontWeight: FontWeight.w700)),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ..._rows.map(
                (_ShareRow r) => Padding(
                  padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<int?>(
                          initialValue: partners.any((Json p) => p['id'] == r.partnerId) ? r.partnerId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'الشريك', isDense: true, border: OutlineInputBorder()),
                          items: partners
                              .map((Json p) => DropdownMenuItem<int?>(value: intOf(p['id']), child: Text('${p['name']}${p['kind'] == 'company' ? ' (الشركة)' : ''}')))
                              .toList(growable: false),
                          onChanged: (int? v) => setState(() => r.partnerId = v),
                        ),
                      ),
                      const SizedBox(width: FinanceSpace.sm),
                      FaTextField(label: 'النسبة %', controller: r.percent, width: 120, numeric: true, onChanged: (_) => setState(() {})),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: _rows.length <= 1
                            ? null
                            : () => setState(() {
                                _rows.remove(r);
                                r.percent.dispose();
                              }),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_ShareRow(null, ''))),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة شريك'),
              ),
              const SizedBox(height: FinanceSpace.sm),
              Row(
                children: <Widget>[
                  FaDateField(label: 'سارية اعتبارًا من', value: _effectiveFrom, onChanged: (String? v) => setState(() => _effectiveFrom = v ?? _effectiveFrom)),
                  const SizedBox(width: FinanceSpace.md),
                  FaBusyButton(label: 'حفظ النسب', busy: _saving, onPressed: _branchId == null ? null : _saveShares),
                ],
              ),
              const SizedBox(height: FinanceSpace.xs),
              const Text('تغيير النسب ينشئ فترة ملكية جديدة من التاريخ المحدد؛ الفترات السابقة والتوزيعات تبقى كما هي.', style: FinanceText.small),
            ],
          ),
        ),
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'إعدادات توزيع الأرباح لهذا الفرع',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('fee-$_branchId-$_feeType'),
                      initialValue: _feeType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'أتعاب إدارة للشركة', isDense: true, border: OutlineInputBorder()),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'none', child: Text('بدون')),
                        DropdownMenuItem<String>(value: 'profit_percent', child: Text('نسبة من صافي الربح')),
                        DropdownMenuItem<String>(value: 'revenue_percent', child: Text('نسبة من الإيرادات')),
                      ],
                      onChanged: (String? v) => setState(() => _feeType = v ?? 'none'),
                    ),
                  ),
                  if (_feeType != 'none') FaTextField(label: 'النسبة %', controller: _feePercent, width: 120, numeric: true),
                  if (_feeType != 'none')
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey<String>('feep-$_branchId-$_feePartner'),
                        initialValue: partners.any((Json p) => p['id'] == _feePartner) ? _feePartner : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'تُحوَّل الأتعاب إلى', isDense: true, border: OutlineInputBorder()),
                        items: partners.map((Json p) => DropdownMenuItem<int?>(value: intOf(p['id']), child: Text(str(p['name'])))).toList(growable: false),
                        onChanged: (int? v) => setState(() => _feePartner = v),
                      ),
                    ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _carry,
                onChanged: (bool? v) => setState(() => _carry = v ?? false),
                title: const Text('ترحيل الخسارة للفترات القادمة بدل توزيعها (الافتراضي: المستثمر يتحمل الخسارة بنسبته)'),
              ),
              FaBusyButton(label: 'حفظ الإعدادات', busy: _saving, onPressed: _branchId == null ? null : _saveSettings),
            ],
          ),
        ),
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'سجل الملكية',
          child: FaTable(
            minWidth: 700,
            columns: const <String>['من', 'إلى', 'الشركاء'],
            flex: const <int>[1, 1, 4],
            emptyMessage: 'لم تُحدَّد نسب بعد — الفرع ملك الشركة 100%.',
            rows: asJsonList(_data?['history'])
                .map((Json h) => <Widget>[
                      faCell(str(h['effectiveFrom']), ltr: true),
                      faCell(str(h['effectiveTo'], 'مستمر'), ltr: true),
                      faCell(asJsonList(h['shares']).map((Json s) => '${s['partnerName']} ${s['sharePercent']}%').join(' · ')),
                    ])
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

// ============================================================================ distributions

class _DistributionsTab extends StatefulWidget {
  const _DistributionsTab({required this.refs, required this.onChanged});

  final _PartnersRefs refs;
  final VoidCallback onChanged;

  @override
  State<_DistributionsTab> createState() => _DistributionsTabState();
}

class _DistributionsTabState extends State<_DistributionsTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  List<Json> _list = const <Json>[];
  int? _branchId;
  late String _from = _monthStart();
  String _to = isoDate(DateTime.now());
  Json? _preview;
  bool _busy = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.refs.branches.isNotEmpty) _branchId = widget.refs.branches.first.id;
    _loadList();
  }

  Future<void> _loadList() async {
    try {
      final List<Json> list = await _api.distributions();
      if (mounted) setState(() => _list = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Json get _payload => <String, dynamic>{'branchId': _branchId, 'periodFrom': _from, 'periodTo': _to};

  Future<void> _doPreview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Json p = await _api.previewDistribution(_payload);
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    if (!await confirmFa(context, 'ترحيل التوزيع', 'سيُرحَّل قيد توزيع نتيجة الفرع على الحسابات الجارية للشركاء. متابعة؟', confirm: 'ترحيل')) return;
    setState(() => _busy = true);
    try {
      await _api.postDistribution(_payload);
      if (!mounted) return;
      showFaMessage(context, 'تم ترحيل التوزيع.');
      setState(() => _preview = null);
      await _loadList();
      widget.onChanged();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reverse(Json d) async {
    if (!await confirmFa(context, 'عكس التوزيع', 'عكس التوزيع ${d['number']}؟', confirm: 'عكس')) return;
    try {
      await _api.reverseDistribution(intOf(d['id'])!);
      if (!mounted) return;
      showFaMessage(context, 'تم عكس التوزيع.');
      await _loadList();
      widget.onChanged();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Json? p = _preview;
    return ListView(
      children: <Widget>[
        FaSection(
          title: 'توزيع جديد',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FaBranchDropdown(
                    branches: widget.refs.branches,
                    value: _branchId == null ? null : '$_branchId',
                    includeCompany: false,
                    onChanged: (String? v) => setState(() {
                      _branchId = int.tryParse(v ?? '');
                      _preview = null;
                    }),
                  ),
                  FaDateField(label: 'من', value: _from, width: 160, onChanged: (String? v) => setState(() {
                    _from = v ?? _from;
                    _preview = null;
                  })),
                  FaDateField(label: 'إلى', value: _to, width: 160, onChanged: (String? v) => setState(() {
                    _to = v ?? _to;
                    _preview = null;
                  })),
                  OutlinedButton.icon(onPressed: _busy || _branchId == null ? null : _doPreview, icon: const Icon(Icons.calculate_outlined, size: 18), label: const Text('احسب')),
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
                Wrap(
                  spacing: FinanceSpace.md,
                  runSpacing: FinanceSpace.md,
                  children: <Widget>[
                    FaStat(label: 'الإيرادات', value: money(p['revenue'])),
                    FaStat(label: 'صافي نتيجة الفرع', value: money(p['netProfit']), color: numOf(p['netProfit']) >= 0 ? FinanceColors.success : FinanceColors.danger),
                    if (numOf(p['carriedLoss']) != 0) FaStat(label: 'خسائر مرحّلة مخصومة', value: money(p['carriedLoss'])),
                    FaStat(label: 'أتعاب الإدارة', value: money(p['managementFee'])),
                    FaStat(label: 'القابل للتوزيع', value: money(p['distributable']), color: FinanceColors.primary),
                  ],
                ),
                const SizedBox(height: FinanceSpace.md),
                FaTable(
                  minWidth: 700,
                  columns: const <String>['الشريك', 'البند', 'النسبة', 'المبلغ'],
                  flex: const <int>[3, 2, 1, 2],
                  rows: asJsonList(p['lines'])
                      .map((Json l) => <Widget>[
                            faCell(str(l['partnerName']), bold: true),
                            faCell(l['kind'] == 'management_fee' ? 'أتعاب إدارة' : 'حصة من النتيجة'),
                            faCell('${l['sharePercent']}%'),
                            faMoneyCell(l['amount'], bold: true),
                          ])
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
            minWidth: 1100,
            columns: const <String>['الرقم', 'الفرع', 'الفترة', 'صافي النتيجة', 'أتعاب الإدارة', 'الموزَّع', 'الحالة', ''],
            flex: const <int>[2, 2, 3, 2, 2, 2, 2, 1],
            emptyMessage: 'لا توجد توزيعات.',
            rows: _list
                .map((Json d) => <Widget>[
                      faCell(str(d['number']), ltr: true, bold: true),
                      faCell(str(d['branchName'])),
                      faCell('${d['periodFrom']} → ${d['periodTo']}', ltr: true),
                      faMoneyCell(d['netProfit']),
                      faMoneyCell(d['managementFee']),
                      faMoneyCell(d['distributable'], bold: true),
                      FaStatusPill(status: str(d['status']), label: d['status'] == 'posted' ? 'مرحّل' : 'معكوس'),
                      d['status'] == 'posted' ? TextButton(onPressed: () => _reverse(d), child: const Text('عكس')) : const SizedBox.shrink(),
                    ])
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

// ============================================================================ movements

class _MovementsTab extends StatefulWidget {
  const _MovementsTab({required this.refs, required this.onChanged});

  final _PartnersRefs refs;
  final VoidCallback onChanged;

  @override
  State<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<_MovementsTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  List<Json> _rows = const <Json>[];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final List<Json> rows = await _api.partnerTransactions();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _new() async {
    final bool? ok = await showDialog<bool>(context: context, builder: (_) => _PartnerTransactionDialog(refs: widget.refs));
    if (ok == true) {
      await _load();
      widget.onChanged();
    }
  }

  Future<void> _reverse(Json t) async {
    if (!await confirmFa(context, 'عكس العملية', 'عكس «${t['typeLabel']}» لـ ${t['partnerName']} بمبلغ ${money(t['amount'])}؟', confirm: 'عكس')) return;
    try {
      await _api.reversePartnerTransaction(intOf(t['id'])!);
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: Text('إيداع وسحب رأس المال، المسحوبات الشخصية، وصرف الأرباح من الحساب الجاري.', style: FinanceText.subtitle)),
            FilledButton.icon(onPressed: _new, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('عملية جديدة')),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        Expanded(
          child: _loading && _rows.isEmpty
              ? const FinanceLoadingState()
              : SingleChildScrollView(
                  child: FaTable(
                    minWidth: 1100,
                    columns: const <String>['التاريخ', 'الشريك', 'العملية', 'الفرع', 'المبلغ', 'الحساب المقابل', 'البيان', ''],
                    flex: const <int>[2, 3, 3, 2, 2, 3, 3, 1],
                    emptyMessage: 'لا توجد حركات.',
                    rowColor: (int i) => _rows[i]['reversed'] == true ? FinanceColors.dangerBg : null,
                    rows: _rows
                        .map((Json t) => <Widget>[
                              faCell(str(t['date']), ltr: true),
                              faCell(str(t['partnerName']), bold: true),
                              faCell('${t['typeLabel']}${t['reversed'] == true ? ' (معكوسة)' : ''}'),
                              faCell(str(t['branchName'])),
                              faMoneyCell(t['amount'], bold: true),
                              faCell(str(t['counterAccount'])),
                              faCell(str(t['description'])),
                              t['reversed'] == true ? const SizedBox.shrink() : TextButton(onPressed: () => _reverse(t), child: const Text('عكس')),
                            ])
                        .toList(growable: false),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PartnerTransactionDialog extends StatefulWidget {
  const _PartnerTransactionDialog({required this.refs});

  final _PartnersRefs refs;

  @override
  State<_PartnerTransactionDialog> createState() => _PartnerTransactionDialogState();
}

class _PartnerTransactionDialogState extends State<_PartnerTransactionDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  int? _partnerId;
  String _type = 'capital_in';
  String _date = isoDate(DateTime.now());
  String? _branch;
  int? _counter;
  bool _busy = false;
  String? _error;

  static const Map<String, String> _types = <String, String>{
    'capital_in': 'إيداع رأس مال',
    'capital_out': 'سحب من رأس المال',
    'withdrawal': 'مسحوبات شخصية',
    'payout': 'صرف أرباح من الحساب الجاري',
    'deposit': 'إيداع في الحساب الجاري',
  };

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_partnerId == null) {
      setState(() => _error = 'اختر الشريك.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FaApi().partnerTransaction(_partnerId!, <String, dynamic>{
        'type': _type,
        'date': _date,
        'amount': _amount.text.trim(),
        'counterAccountId': _counter,
        'branchId': _branch == null || _branch == kCompanyBranch ? null : int.tryParse(_branch!),
        'description': _description.text.trim(),
      });
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
  Widget build(BuildContext context) {
    final bool inflow = _type == 'capital_in' || _type == 'deposit';
    return FaDialog(
      title: 'عملية شريك',
      maxWidth: 640,
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FaBusyButton(label: 'ترحيل', busy: _busy, onPressed: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<int?>(
                  initialValue: _partnerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الشريك', isDense: true, border: OutlineInputBorder()),
                  items: widget.refs.partners.map((Json p) => DropdownMenuItem<int?>(value: intOf(p['id']), child: Text(str(p['name'])))).toList(growable: false),
                  onChanged: (int? v) => setState(() => _partnerId = v),
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'العملية', isDense: true, border: OutlineInputBorder()),
                  items: _types.entries.map((MapEntry<String, String> e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(growable: false),
                  onChanged: (String? v) => setState(() => _type = v ?? 'capital_in'),
                ),
              ),
              FaDateField(label: 'التاريخ', value: _date, onChanged: (String? v) => setState(() => _date = v ?? _date)),
              FaTextField(label: 'المبلغ *', controller: _amount, width: 180, numeric: true),
              FaBranchDropdown(branches: widget.refs.branches, value: _branch, label: 'الفرع (اختياري)', onChanged: (String? v) => setState(() => _branch = v)),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          AccountPickerField(
            label: inflow ? 'الحساب المستلم (الصندوق / البنك)' : 'الحساب الدافع (الصندوق / البنك)',
            accounts: widget.refs.accounts,
            value: _counter,
            onChanged: (int? v) => setState(() => _counter = v),
          ),
          const SizedBox(height: FinanceSpace.md),
          FaTextField(label: 'البيان', controller: _description),
          FaErrorText(_error),
        ],
      ),
    );
  }
}
