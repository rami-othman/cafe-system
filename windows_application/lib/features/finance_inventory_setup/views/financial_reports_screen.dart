import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_locator.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_source_navigation.dart';
import '../widgets/finance_paginated_table.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({
    super.key,
    this.accountId,
    this.supplierId,
    this.reportType,
  });
  final int? accountId;
  final int? supplierId;
  final String? reportType;
  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  late final FinanceSetupRepository _repo;
  late Future<List<dynamic>> _setup;
  Future<Map<String, dynamic>>? _report;
  String _type = 'profit-loss';
  int? _accountId;
  int? _supplierId;
  int? _branchId;
  String _from = '';
  String _to = '';
  static const List<(String, String)> _types = <(String, String)>[
    ('profit-loss', 'الأرباح والخسائر'),
    ('balance-sheet', 'المركز المالي'),
    ('cash-flow', 'التدفقات النقدية'),
    ('trial-balance', 'ميزان المراجعة'),
    ('general-ledger', 'دفتر الأستاذ'),
    ('supplier-aging', 'أعمار الموردين'),
    ('supplier-statement', 'كشف حساب مورد'),
  ];
  @override
  void initState() {
    super.initState();
    _repo = serviceLocator<FinanceSetupRepository>();
    _accountId = widget.accountId;
    _supplierId = widget.supplierId;
    _type = widget.reportType ?? _type;
    _setup = Future.wait<dynamic>(<Future<dynamic>>[
      _repo.getAccounts(status: 'active'),
      _repo.getBranches(),
      _repo.getSuppliers(),
    ]);
    _load();
  }

  void _load() {
    if ((_type == 'general-ledger' && _accountId == null) ||
        (_type == 'supplier-statement' && _supplierId == null)) {
      setState(() => _report = null);
      return;
    }
    setState(
      () => _report = _repo.getFinanceMap(
        'finance/reports/$_type',
        queryParameters: <String, dynamic>{
          if (_from.isNotEmpty) 'dateFrom': _from,
          if (_to.isNotEmpty) 'dateTo': _to,
          if (_branchId != null) 'branchId': _branchId,
          if (_type == 'general-ledger') 'accountId': _accountId,
          if (_type == 'supplier-statement') 'supplierId': _supplierId,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      child: FutureBuilder<List<dynamic>>(
        future: _setup,
        builder: (BuildContext context, AsyncSnapshot<List<dynamic>> setup) {
          if (!setup.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<dynamic> accounts = setup.data![0] as List<dynamic>;
          final List<dynamic> branches = setup.data![1] as List<dynamic>;
          final List<dynamic> suppliers = setup.data![2] as List<dynamic>;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'التقارير المالية',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: _types
                    .map(
                      ((String, String) t) => ChoiceChip(
                        label: Text(t.$2),
                        selected: _type == t.$1,
                        onSelected: (_) {
                          setState(() => _type = t.$1);
                          _load();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  if (_type == 'general-ledger')
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        initialValue: _accountId,
                        hint: const Text('الحساب'),
                        items: accounts
                            .map(
                              (dynamic a) => DropdownMenuItem<int>(
                                value: a.id as int,
                                child: Text('${a.code} — ${a.nameAr}'),
                              ),
                            )
                            .toList(),
                        onChanged: (int? value) {
                          setState(() => _accountId = value);
                          _load();
                        },
                      ),
                    ),
                  if (_type == 'supplier-statement')
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<int>(
                        initialValue: _supplierId,
                        hint: const Text('المورد'),
                        items: suppliers
                            .map(
                              (dynamic s) => DropdownMenuItem<int>(
                                value: s.id as int,
                                child: Text('${s.supplierNumber} — ${s.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (int? value) {
                          setState(() => _supplierId = value);
                          _load();
                        },
                      ),
                    ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      onChanged: (String value) => _from = value,
                      decoration: const InputDecoration(
                        labelText: 'من YYYY-MM-DD',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      onChanged: (String value) => _to = value,
                      decoration: const InputDecoration(
                        labelText: 'إلى YYYY-MM-DD',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _branchId,
                      hint: const Text('كل الفروع'),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('كل الفروع'),
                        ),
                        ...branches.map(
                          (dynamic b) => DropdownMenuItem<int?>(
                            value: b.id as int,
                            child: Text(b.name as String),
                          ),
                        ),
                      ],
                      onChanged: (int? value) =>
                          setState(() => _branchId = value),
                    ),
                  ),
                  ElevatedButton(onPressed: _load, child: const Text('تطبيق')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _body()),
            ],
          );
        },
      ),
    ),
  );
  Widget _body() {
    if (_report == null) {
      return const Center(child: Text('اختر حساباً لعرض دفتر الأستاذ.'));
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _report,
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final Map<String, dynamic> data = snapshot.data!;
        final List<Map<String, dynamic>> rows = _rows(data);
        return ListView(
          children: <Widget>[
            if (_type == 'supplier-statement' && _supplierId != null)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/finance/suppliers/$_supplierId'),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('ملف المورد'),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(_summary(data)),
              ),
            ),
            if (rows.isNotEmpty)
              Card(
                child: FinancePaginatedTable(
                  minWidth: 900,
                  columns: const <DataColumn>[
                    DataColumn(label: Text('التاريخ')),
                    DataColumn(label: Text('المرجع')),
                    DataColumn(label: Text('المصدر')),
                    DataColumn(label: Text('الوصف')),
                    DataColumn(label: Text('مدين')),
                    DataColumn(label: Text('دائن')),
                    DataColumn(label: Text('الرصيد')),
                  ],
                  rows: rows
                      .map(
                        (Map<String, dynamic> row) => DataRow(
                          onSelectChanged: (_) => _drill(row),
                          cells: <DataCell>[
                            DataCell(
                              Text('${row['date'] ?? row['entryDate'] ?? '—'}'),
                            ),
                            DataCell(
                              Text(
                                '${row['journalReference'] ?? row['reference'] ?? '—'}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '${row['source']?['reference'] ?? row['sourceType'] ?? '—'}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '${row['description'] ?? row['accountName'] ?? '—'}',
                              ),
                            ),
                            DataCell(Text('${row['debit'] ?? '—'}')),
                            DataCell(Text('${row['credit'] ?? '—'}')),
                            DataCell(Text('${row['runningBalance'] ?? '—'}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  void _drill(Map<String, dynamic> row) {
    final int? account = row['accountId'] as int?;
    final int? journal =
        row['journalEntryId'] as int? ?? row['journal']?['id'] as int?;
    if ((_type == 'profit-loss' || _type == 'trial-balance') &&
        account != null) {
      context.go('/finance/reports/general-ledger?accountId=$account');
      return;
    }
    final Map<String, dynamic> supplier = row['supplier'] is Map
        ? Map<String, dynamic>.from(row['supplier'] as Map)
        : const <String, dynamic>{};
    if (_type == 'supplier-aging' && supplier['id'] != null) {
      context.go(
        '/finance/reports/general-ledger?type=supplier-statement&supplierId=${supplier['id']}',
      );
      return;
    }
    final Map<String, dynamic> drill = row['drillDown'] is Map
        ? Map<String, dynamic>.from(row['drillDown'] as Map)
        : const <String, dynamic>{};
    if (_type == 'supplier-statement' && drill['id'] != null) {
      final String tab = drill['resourceKind'] == 'supplier_payment'
          ? 'payments'
          : 'invoices';
      context.go('/finance/suppliers/$_supplierId?tab=$tab');
      return;
    }
    if (journal != null) {
      context.go('/finance/journal-entries/$journal');
      return;
    }
    final Map<String, dynamic> source = row['source'] is Map
        ? Map<String, dynamic>.from(row['source'] as Map)
        : const <String, dynamic>{};
    final path = FinanceSourceNavigation.destination(source);
    if (path != null) context.go(path);
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> output = <Map<String, dynamic>>[];
    void collect(dynamic value) {
      if (value is List) {
        for (final dynamic v in value) {
          collect(v);
        }
      }
      if (value is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(value);
        if (map.containsKey('debit') ||
            map.containsKey('accountId') ||
            map.containsKey('journalEntryId') ||
            map.containsKey('supplier') ||
            map.containsKey('drillDown')) {
          output.add(map);
        }
        for (final dynamic v in map.values) {
          if (v is List) collect(v);
        }
      }
    }

    data.values.forEach(collect);
    return output;
  }

  String _summary(Map<String, dynamic> data) => data.entries
      .where(
        (MapEntry<String, dynamic> e) => e.value is! List && e.value is! Map,
      )
      .map((MapEntry<String, dynamic> e) => '${e.key}: ${e.value}')
      .join('   •   ');
}
