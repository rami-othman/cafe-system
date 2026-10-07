import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../data/fa_api.dart';
import '../widgets/fa_widgets.dart';
import 'asset_dialogs.dart';
import 'asset_maintenance_section.dart';

/// تقرير تكلفة الصيانة لكل أصل ضمن فترة: صيانة دورية / إصلاح / أخرى (المدفوع فقط) + بانتظار الدفع + كلفة العقود السارية.
class AssetMaintenanceReportTab extends StatefulWidget {
  const AssetMaintenanceReportTab({super.key, required this.refs});

  final FaRefs refs;

  @override
  State<AssetMaintenanceReportTab> createState() => _AssetMaintenanceReportTabState();
}

class _AssetMaintenanceReportTabState extends State<AssetMaintenanceReportTab> with AutomaticKeepAliveClientMixin {
  final FaApi _api = FaApi();
  String _from = isoDate(DateTime(DateTime.now().year, 1, 1));
  String _to = isoDate(DateTime.now());
  String? _kind;
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
      final Json d = await _api.maintenanceReport(<String, dynamic>{'dateFrom': _from, 'dateTo': _to, 'kind': _kind, 'branchId': _branch});
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
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع المصروف', isDense: true, border: OutlineInputBorder()),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(value: null, child: Text('كل الأنواع')),
                  ...kAssetExpenseKinds.entries.map((MapEntry<String, String> e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
                ],
                onChanged: (String? v) => setState(() => _kind = v),
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
            children: <Widget>[
              FaStat(label: 'صيانة دورية', value: money(totals['maintenance']), width: 170),
              FaStat(label: 'إصلاحات', value: money(totals['repair']), width: 170),
              FaStat(label: 'أخرى', value: money(totals['other']), width: 170),
              FaStat(label: 'إجمالي المدفوع', value: money(totals['paid']), color: FinanceColors.primary, width: 170),
              FaStat(label: 'بانتظار الدفع', value: money(totals['pending']), color: FinanceColors.warning, width: 170),
              FaStat(label: 'عقود سارية (سنوي)', value: money(totals['contracts']), width: 170),
            ],
          ),
        const SizedBox(height: FinanceSpace.md),
        Expanded(
          child: _error != null
              ? FinanceErrorState(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  child: FaTable(
                    minWidth: 1000,
                    columns: const <String>['الأصل', 'الفرع', 'صيانة دورية', 'إصلاحات', 'أخرى', 'المدفوع', 'بانتظار الدفع', 'عقود سارية (سنوي)'],
                    flex: const <int>[4, 2, 2, 2, 2, 2, 2, 2],
                    emptyMessage: 'لا توجد مصروفات صيانة مربوطة بأصول في هذه الفترة.',
                    onTap: (int i) => context.go('/finance/assets/${items[i]['assetId']}'),
                    rows: items
                        .map((Json t) => <Widget>[
                              faCell('${t['code']} - ${t['nameAr']}', bold: true),
                              faCell(str(t['branchName'])),
                              faMoneyCell(t['maintenance']),
                              faMoneyCell(t['repair']),
                              faMoneyCell(t['other']),
                              faMoneyCell(t['paid'], bold: true),
                              faMoneyCell(t['pending']),
                              faMoneyCell(t['activeContractsAnnual']),
                            ])
                        .toList(growable: false),
                  ),
                ),
        ),
      ],
    );
  }
}
