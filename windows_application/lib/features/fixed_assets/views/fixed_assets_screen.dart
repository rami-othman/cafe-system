import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../data/fa_api.dart';
import '../widgets/fa_widgets.dart';
import 'asset_alerts_banner.dart';
import 'asset_count_tab.dart';
import 'asset_dialogs.dart';

/// الأصول الثابتة: سجل الأصول، مذكرات الاهتلاك، الأصناف، المواقع، تقرير
/// العمليات والإعدادات — في مساحة عمل واحدة بتبويبات.
class FixedAssetsScreen extends StatefulWidget {
  const FixedAssetsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FixedAssetsScreen> createState() => _FixedAssetsScreenState();
}

class _FixedAssetsScreenState extends State<FixedAssetsScreen> {
  final FaApi _api = FaApi();
  FaRefs? _refs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    setState(() => _error = null);
    try {
      final FaRefs refs = await FaRefs.load(_api);
      if (mounted) setState(() => _refs = refs);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return FinanceErrorState(message: _error!, onRetry: _loadRefs);
    if (_refs == null) return const FinanceLoadingState();
    return DefaultTabController(
      length: 7,
      initialIndex: widget.initialTab.clamp(0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const FinancePageHeader(
            title: 'الأصول الثابتة',
            subtitle: 'بطاقات الأصول، الاهتلاك، الإضافة والبيع والنقل بين الفروع — كل عملية ترحّل قيدها تلقائيًا.',
          ),
          const SizedBox(height: FinanceSpace.md),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: FinanceColors.primary,
            indicatorColor: FinanceColors.accent,
            tabs: <Tab>[
              Tab(text: 'سجل الأصول'),
              Tab(text: 'مذكرات الاهتلاك'),
              Tab(text: 'أصناف الأصول'),
              Tab(text: 'المواقع'),
              Tab(text: 'تقرير العمليات'),
              Tab(text: 'الإعدادات'),
              Tab(text: 'الجرد الفعلي'),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                _RegisterTab(refs: _refs!, onRefsChanged: _loadRefs),
                _RunsTab(refs: _refs!),
                _CategoriesTab(refs: _refs!, onChanged: _loadRefs),
                _LocationsTab(refs: _refs!, onChanged: _loadRefs),
                _OperationsTab(refs: _refs!),
                const _SettingsTab(),
                AssetCountTab(refs: _refs!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================ register

class _RegisterTab extends StatefulWidget {
  const _RegisterTab({required this.refs, required this.onRefsChanged});

  final FaRefs refs;
  final VoidCallback onRefsChanged;

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  final TextEditingController _search = TextEditingController();
  String? _status;
  int? _categoryId;
  String? _branch;
  String? _asOf;
  bool _includeDisposed = false;
  Json? _data;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Json data = await _api.register(<String, dynamic>{
        'q': _search.text.trim(),
        'status': _status,
        'categoryId': _categoryId,
        'branchId': _branch,
        'asOf': _asOf,
        'includeDisposed': _includeDisposed ? 1 : null,
      });
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final Json? created = await AssetFormDialog.show(context, widget.refs);
    if (created != null && mounted) context.go('/finance/assets/${created['id']}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final List<Json> items = asJsonList(_data?['items']);
    final Json totals = asJson(_data?['totals']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FinanceFilterBar(
          children: <Widget>[
            SizedBox(
              width: 260,
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(
                  labelText: 'بحث بالاسم، الرمز، الباركود',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
            ),
            FaBranchDropdown(branches: widget.refs.branches, value: _branch, includeAll: true, onChanged: (String? v) {
              setState(() => _branch = v);
              _load();
            }),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الصنف', isDense: true, border: OutlineInputBorder()),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(value: null, child: Text('كل الأصناف')),
                  ...widget.refs.categories.map((Json c) => DropdownMenuItem<int?>(value: intOf(c['id']), child: Text(str(c['nameAr'])))),
                ],
                onChanged: (int? v) {
                  setState(() => _categoryId = v);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String?>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الحالة', isDense: true, border: OutlineInputBorder()),
                items: const <DropdownMenuItem<String?>>[
                  DropdownMenuItem<String?>(value: null, child: Text('الكل (عدا المستبعد)')),
                  DropdownMenuItem<String?>(value: 'active', child: Text('فعّال')),
                  DropdownMenuItem<String?>(value: 'draft', child: Text('مسودة')),
                  DropdownMenuItem<String?>(value: 'fully_depreciated', child: Text('مهتلك بالكامل')),
                  DropdownMenuItem<String?>(value: 'disposed', child: Text('مستبعد')),
                ],
                onChanged: (String? v) {
                  setState(() => _status = v);
                  _load();
                },
              ),
            ),
            FaDateField(label: 'القيم حتى تاريخ', value: _asOf, allowClear: true, width: 170, onChanged: (String? v) {
              setState(() => _asOf = v);
              _load();
            }),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Checkbox(value: _includeDisposed, onChanged: (bool? v) {
                  setState(() => _includeDisposed = v ?? false);
                  _load();
                }),
                const Text('إظهار المستبعد'),
              ],
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
            FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('أصل جديد')),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        const AssetAlertsBanner(),
        if (_data != null)
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: <Widget>[
              FaStat(label: 'عدد الأصول', value: '${_data!['count']}'),
              FaStat(label: 'إجمالي الكلفة', value: money(totals['cost'])),
              FaStat(label: 'مجمع الاهتلاك', value: money(totals['accumulated']), color: FinanceColors.brown),
              FaStat(label: 'القيمة الدفترية', value: money(totals['bookValue']), color: FinanceColors.success),
            ],
          ),
        const SizedBox(height: FinanceSpace.md),
        Expanded(
          child: _loading && _data == null
              ? const FinanceLoadingState()
              : _error != null
              ? FinanceErrorState(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  child: FaTable(
                    minWidth: 1100,
                    columns: const <String>['الرمز', 'اسم الأصل', 'الصنف', 'الفرع / الموقع', 'تاريخ الشراء', 'الكلفة', 'مجمع الاهتلاك', 'القيمة الحالية', 'الحالة'],
                    flex: const <int>[1, 4, 2, 2, 2, 2, 2, 2, 2],
                    emptyMessage: 'لا توجد أصول. أضف أصلًا جديدًا أو غيّر الفلاتر.',
                    onTap: (int i) => context.go('/finance/assets/${items[i]['id']}'),
                    rows: items
                        .map((Json a) => <Widget>[
                              faCell(str(a['code']), ltr: true),
                              faCell(str(a['nameAr']), bold: true),
                              faCell(str(a['categoryName'], '—')),
                              faCell('${a['branchName']}${a['locationName'] != null ? ' / ${a['locationName']}' : ''}'),
                              faCell(str(a['acquisitionDate']), ltr: true),
                              faMoneyCell(a['cost']),
                              faMoneyCell(a['accumulated']),
                              faMoneyCell(a['bookValue'], bold: true),
                              FaStatusPill(status: str(a['status']), label: str(a['statusLabel'])),
                            ])
                        .toList(growable: false),
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================================ runs

class _RunsTab extends StatefulWidget {
  const _RunsTab({required this.refs});

  final FaRefs refs;

  @override
  State<_RunsTab> createState() => _RunsTabState();
}

class _RunsTabState extends State<_RunsTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  List<Json> _runs = const <Json>[];
  Json _settings = const <String, dynamic>{};
  bool _loading = true;
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
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[_api.runs(), _api.settings()]);
      if (mounted) {
        setState(() {
          _runs = r[0] as List<Json>;
          _settings = r[1] as Json;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _new() async {
    final Json? run = await DepreciationRunDialog.show(context, widget.refs, str(_settings['suggestedPeriodEnd'], isoDate(DateTime.now())));
    if (run != null && mounted) {
      showFaMessage(context, 'تم ترحيل المذكرة ${run['runNumber']} بقيمة ${money(run['total'])}.');
      _load();
    }
  }

  Future<void> _open(Json run) async {
    final Json detail = await _api.run(intOf(run['id'])!);
    if (!mounted) return;
    final bool? reversed = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => FaDialog(
        title: 'مذكرة اهتلاك ${detail['runNumber']} — حتى ${detail['periodEnd']}',
        maxWidth: 1000,
        actions: <Widget>[
          if (detail['status'] == 'posted')
            TextButton.icon(
              onPressed: () async {
                if (!await confirmFa(d, 'عكس المذكرة', 'يُعكس قيد المذكرة ويعود كل أصل لتاريخ اهتلاكه السابق. متابعة؟', confirm: 'عكس')) return;
                try {
                  await _api.reverseRun(intOf(detail['id'])!);
                  if (d.mounted) Navigator.pop(d, true);
                } catch (e) {
                  if (d.mounted) showFaMessage(d, '$e', error: true);
                }
              },
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('عكس المذكرة'),
            ),
          FilledButton(onPressed: () => Navigator.pop(d, false), child: const Text('إغلاق')),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FaFacts(items: <(String, String)>[
              ('الحالة', detail['status'] == 'posted' ? 'مرحّلة' : 'معكوسة'),
              ('الإجمالي', money(detail['total'])),
              ('عدد الأصول', str(detail['assetsCount'])),
              ('القيد', str(detail['journalNumber'])),
              ('البيان', str(detail['description'])),
            ], itemWidth: 170),
            const SizedBox(height: FinanceSpace.md),
            FaTable(
              minWidth: 800,
              columns: const <String>['الأصل', 'الفرع', 'من', 'إلى', 'القيمة'],
              flex: const <int>[4, 2, 2, 2, 2],
              rows: asJsonList(detail['lines'])
                  .map((Json l) => <Widget>[
                        faCell('${l['assetCode']} - ${l['assetName']}'),
                        faCell(str(l['branchName'])),
                        faCell(str(l['from']), ltr: true),
                        faCell(str(l['to']), ltr: true),
                        faMoneyCell(l['amount'], bold: true),
                      ])
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
    if (reversed == true && mounted) {
      showFaMessage(context, 'تم عكس المذكرة.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _runs.isEmpty) return const FinanceLoadingState();
    if (_error != null) return FinanceErrorState(message: _error!, onRetry: _load);
    const Map<String, String> frequency = <String, String>{'monthly': 'شهري', 'quarterly': 'ربع سنوي', 'semiannual': 'نصف سنوي', 'annual': 'سنوي'};
    const Map<String, String> trigger = <String, String>{'manual': 'يدوية', 'addition': 'قبل إضافة', 'disposal': 'قبل بيع', 'transfer': 'قبل نقل'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'دورية الاهتلاك: ${frequency[_settings['depreciationFrequency']] ?? 'شهري'} · آخر مذكرة حتى ${_settings['lastRunPeriodEnd'] ?? '—'} · المقترح حتى ${_settings['suggestedPeriodEnd'] ?? '—'}',
                style: FinanceText.subtitle,
              ),
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            FilledButton.icon(onPressed: _new, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('مذكرة اهتلاك جديدة')),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        Expanded(
          child: SingleChildScrollView(
            child: FaTable(
              minWidth: 900,
              columns: const <String>['الرقم', 'حتى تاريخ', 'النوع', 'عدد الأصول', 'الإجمالي', 'القيد', 'الحالة'],
              flex: const <int>[2, 2, 2, 1, 2, 2, 2],
              emptyMessage: 'لا توجد مذكرات بعد.',
              onTap: (int i) => _open(_runs[i]),
              rows: _runs
                  .map((Json r) => <Widget>[
                        faCell(str(r['runNumber']), ltr: true, bold: true),
                        faCell(str(r['periodEnd']), ltr: true),
                        faCell(trigger[r['trigger']] ?? str(r['trigger'])),
                        faCell(str(r['assetsCount'])),
                        faMoneyCell(r['total'], bold: true),
                        faCell(str(r['journalNumber']), ltr: true),
                        FaStatusPill(status: str(r['status']), label: r['status'] == 'posted' ? 'مرحّلة' : 'معكوسة'),
                      ])
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================ categories

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.refs, required this.onChanged});

  final FaRefs refs;
  final VoidCallback onChanged;

  String _acc(dynamic value) {
    final Json a = asJson(value);
    return a.isEmpty ? '—' : '${a['code']} ${a['name']}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(
            child: Text('كل صنف يحمل حسابات الأصل والمجمع والمصروف وسياسة الاهتلاك الافتراضية، والأصل يرثها.', style: FinanceText.subtitle),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await FaApi().seedCategories();
                onChanged();
              } catch (e) {
                if (context.mounted) showFaMessage(context, '$e', error: true);
              }
            },
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text('إنشاء من دليل الحسابات'),
          ),
          const SizedBox(width: FinanceSpace.sm),
          FilledButton.icon(
            onPressed: () async {
              if (await AssetCategoryDialog.show(context, refs) == true) onChanged();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('صنف جديد'),
          ),
        ],
      ),
      const SizedBox(height: FinanceSpace.md),
      Expanded(
        child: SingleChildScrollView(
          child: FaTable(
            minWidth: 1200,
            columns: const <String>['الرمز', 'الصنف', 'حساب الأصل', 'مجمع الاهتلاك', 'مصروف الاهتلاك', 'الطريقة', 'العمر', 'الأصول', ''],
            flex: const <int>[1, 3, 3, 3, 3, 2, 1, 1, 1],
            emptyMessage: 'لا توجد أصناف. أنشئها من دليل الحسابات أو أضف صنفًا.',
            onTap: (int i) async {
              if (await AssetCategoryDialog.show(context, refs, category: refs.categories[i]) == true) onChanged();
            },
            rows: refs.categories
                .map((Json c) => <Widget>[
                      faCell(str(c['code']), ltr: true),
                      faCell(str(c['nameAr']), bold: true, color: c['isActive'] == false ? FinanceColors.muted : null),
                      faCell(_acc(c['assetAccount'])),
                      faCell(_acc(c['accumulatedAccount'])),
                      faCell(_acc(c['expenseAccount'])),
                      faCell(switch (c['defaultMethod']) { 'none' => 'بدون', 'declining_balance' => 'قسط متناقص', _ => 'قسط ثابت' }),
                      faCell(c['defaultLifeMonths'] == null ? '—' : '${c['defaultLifeMonths']} ش'),
                      faCell(str(c['assetsCount'])),
                      intOf(c['assetsCount']) == 0
                          ? IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () async {
                                if (!await confirmFa(context, 'حذف الصنف', 'حذف «${c['nameAr']}»؟', confirm: 'حذف')) return;
                                try {
                                  await FaApi().deleteCategory(intOf(c['id'])!);
                                  onChanged();
                                } catch (e) {
                                  if (context.mounted) showFaMessage(context, '$e', error: true);
                                }
                              },
                            )
                          : const SizedBox.shrink(),
                    ])
                .toList(growable: false),
          ),
        ),
      ),
    ],
  );
}

// ============================================================================ locations

class _LocationsTab extends StatelessWidget {
  const _LocationsTab({required this.refs, required this.onChanged});

  final FaRefs refs;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(
            child: Text('موقع الأصل الرئيسي هو الفرع. المواقع الفرعية اختيارية (البار، الصالة، المطبخ، المستودع…).', style: FinanceText.subtitle),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (await AssetLocationDialog.show(context, refs) == true) onChanged();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('موقع جديد'),
          ),
        ],
      ),
      const SizedBox(height: FinanceSpace.md),
      Expanded(
        child: SingleChildScrollView(
          child: FaTable(
            minWidth: 600,
            columns: const <String>['الفرع', 'الموقع', 'عدد الأصول'],
            flex: const <int>[3, 3, 1],
            emptyMessage: 'لا توجد مواقع فرعية.',
            onTap: (int i) async {
              if (await AssetLocationDialog.show(context, refs, location: refs.locations[i]) == true) onChanged();
            },
            rows: refs.locations
                .map((Json l) => <Widget>[faCell(str(l['branchName'])), faCell(str(l['name']), bold: true), faCell(str(l['assetsCount']))])
                .toList(growable: false),
          ),
        ),
      ),
    ],
  );
}

// ============================================================================ operations report

class _OperationsTab extends StatefulWidget {
  const _OperationsTab({required this.refs});

  final FaRefs refs;

  @override
  State<_OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<_OperationsTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  String _from = isoDate(DateTime(DateTime.now().year, 1, 1));
  String _to = isoDate(DateTime.now());
  String? _type;
  String? _branch;
  Json? _data;
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
      final Json d = await _api.operations(<String, dynamic>{'dateFrom': _from, 'dateTo': _to, 'type': _type, 'branchId': _branch});
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final List<Json> items = asJsonList(_data?['items']);
    final Json totals = asJson(_data?['totals']);
    const Map<String, String> labels = <String, String>{
      'opening': 'رصيد افتتاحي',
      'acquisition': 'إدخال',
      'addition': 'إضافة',
      'maintenance': 'صيانة',
      'expense': 'مصروف',
      'depreciation': 'اهتلاك',
      'disposal': 'بيع/استبعاد',
      'transfer': 'نقل',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FinanceFilterBar(
          children: <Widget>[
            FaDateField(label: 'من', value: _from, width: 160, onChanged: (String? v) => setState(() => _from = v ?? _from)),
            FaDateField(label: 'إلى', value: _to, width: 160, onChanged: (String? v) => setState(() => _to = v ?? _to)),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String?>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'العملية', isDense: true, border: OutlineInputBorder()),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('كل العمليات')),
                  ...labels.entries.map((MapEntry<String, String> e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
                ],
                onChanged: (String? v) => setState(() => _type = v),
              ),
            ),
            FaBranchDropdown(branches: widget.refs.branches, value: _branch, includeAll: true, onChanged: (String? v) => setState(() => _branch = v)),
            FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.search_rounded, size: 18), label: const Text('عرض')),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        if (totals.isNotEmpty)
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.md,
            children: totals.entries.map((MapEntry<String, dynamic> e) => FaStat(label: labels[e.key] ?? e.key, value: money(e.value), width: 170)).toList(growable: false),
          ),
        const SizedBox(height: FinanceSpace.md),
        Expanded(
          child: _error != null
              ? FinanceErrorState(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  child: FaTable(
                    minWidth: 1100,
                    columns: const <String>['التاريخ', 'الأصل', 'العملية', 'الفرع', 'الكلفة', 'الاهتلاك', 'سعر البيع', 'ربح/خسارة', 'البيان'],
                    flex: const <int>[2, 4, 2, 3, 2, 2, 2, 2, 3],
                    onTap: (int i) => context.go('/finance/assets/${items[i]['assetId']}'),
                    rows: items
                        .map((Json t) => <Widget>[
                              faCell(str(t['date']), ltr: true),
                              faCell('${t['assetCode']} - ${t['assetName']}', bold: true),
                              faCell(str(t['typeLabel'])),
                              faCell(t['type'] == 'transfer' ? '${t['branchName']} ← ${t['toBranchName']}' : str(t['branchName'])),
                              faMoneyCell(t['costAmount']),
                              faMoneyCell(t['depreciationAmount']),
                              t['proceeds'] == null ? faCell('') : faMoneyCell(t['proceeds']),
                              t['gainLoss'] == null ? faCell('') : faMoneyCell(t['gainLoss']),
                              faCell(str(t['description'])),
                            ])
                        .toList(growable: false),
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================================ settings

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final FaApi _api = FaApi();
  String _frequency = 'monthly';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final Json s = await _api.settings();
      if (mounted) setState(() => _frequency = str(s['depreciationFrequency'], 'monthly'));
    } catch (_) {
      // keep the default
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.saveSettings(<String, dynamic>{'depreciationFrequency': _frequency});
      if (mounted) showFaMessage(context, 'تم حفظ الإعدادات.');
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const FinanceLoadingState();
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: 620,
        child: FaSection(
          title: 'دورية الاهتلاك',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'يحددها مدير التطبيق. الاهتلاك يُحسب يوميًا بدقة مهما كانت الدورية؛ الدورية تحدد التاريخ المقترح لكل مذكرة جديدة.',
                style: FinanceText.subtitle,
              ),
              const SizedBox(height: FinanceSpace.md),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'monthly', label: Text('شهري')),
                  ButtonSegment<String>(value: 'quarterly', label: Text('ربع سنوي')),
                  ButtonSegment<String>(value: 'semiannual', label: Text('نصف سنوي')),
                  ButtonSegment<String>(value: 'annual', label: Text('سنوي')),
                ],
                selected: <String>{_frequency},
                onSelectionChanged: (Set<String> s) => setState(() => _frequency = s.first),
              ),
              const SizedBox(height: FinanceSpace.lg),
              FaBusyButton(label: 'حفظ', busy: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
