import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../pos/models/branch.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_paginated_table.dart';

class CashBanksScreen extends StatefulWidget {
  const CashBanksScreen({super.key});
  @override
  State<CashBanksScreen> createState() => _CashBanksState();
}

class _CashBanksState extends State<CashBanksScreen> {
  List<FinancialLocation> _locations = const [];
  List<FinancialAccount> _accounts = const [];
  List<Branch> _branches = const [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceSetupCubit>().repository;
      final results = await Future.wait([
        repo.getFinancialLocations('cash'),
        repo.getFinancialLocations('bank'),
        repo.getAccounts(status: 'active'),
        repo.getBranches(),
      ]);
      if (mounted) {
        setState(() {
          _locations = [
            ...results[0] as List<FinancialLocation>,
            ...results[1] as List<FinancialLocation>,
          ];
          _accounts = results[2] as List<FinancialAccount>;
          _branches = results[3] as List<Branch>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ManagementPageHeader(
          title: 'النقد والبنوك',
          subtitle: 'الأرصدة والحركات مستمدة حصراً من القيود المُرحّلة.',
          actions: <Widget>[
            AppButton(
              label: 'إضافة حساب',
              icon: Icons.add,
              onPressed: _editLocation,
            ),
            AppButton(
              label: 'تحويل نقدي',
              icon: Icons.swap_horiz,
              onPressed: _locations.length < 2 ? null : _transfer,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ManagementMessage(message: _error!, error: true, onRetry: _load)
              : _locations.isEmpty
              ? const ManagementMessage(
                  message: 'لا توجد حسابات نقدية أو بنكية مُهيأة.',
                )
              : ManagementTableShell(
                  minWidth: 980,
                  child: FinancePaginatedTable(
                    minWidth: 980,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('الحساب')),
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('الفرع')),
                      DataColumn(label: Text('حساب الأستاذ')),
                      DataColumn(label: Text('الرصيد')),
                      DataColumn(label: Text('وارد اليوم')),
                      DataColumn(label: Text('صادر اليوم')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('')),
                    ],
                    rows: _locations
                        .map(
                          (item) => DataRow(
                            cells: <DataCell>[
                              DataCell(
                                Text(item.name),
                                onTap: () => _details(item),
                              ),
                              DataCell(Text(item.type)),
                              DataCell(Text(item.branchName ?? 'عام')),
                              DataCell(Text(item.financialAccountCode)),
                              DataCell(Text(item.balance)),
                              DataCell(Text(item.todayIncoming)),
                              DataCell(Text(item.todayOutgoing)),
                              DataCell(
                                ManagementBadge(
                                  label: item.isActive ? 'نشط' : 'غير نشط',
                                  tone: item.isActive
                                      ? ManagementTone.success
                                      : ManagementTone.neutral,
                                ),
                              ),
                              DataCell(
                                PopupMenuButton<String>(
                                  onSelected: (String action) {
                                    if (action == 'details') _details(item);
                                    if (action == 'edit') _editLocation(item);
                                    if (action == 'status') _changeStatus(item);
                                  },
                                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Text('التفاصيل والحركات'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('تعديل الحساب'),
                                    ),
                                    PopupMenuItem(
                                      value: 'status',
                                      child: Text(
                                        item.isActive
                                            ? 'تعطيل الحساب'
                                            : 'تفعيل الحساب',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    ),
  );
  Future<void> _transfer() async {
    var from = _locations.first.id;
    var to = _locations[1].id;
    final amount = TextEditingController();
    final note = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('تحويل نقدي'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<int>(
                  initialValue: from,
                  items: _locations
                      .map(
                        (x) =>
                            DropdownMenuItem(value: x.id, child: Text(x.name)),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => from = v!),
                ),
                DropdownButtonFormField<int>(
                  initialValue: to,
                  items: _locations
                      .map(
                        (x) =>
                            DropdownMenuItem(value: x.id, child: Text(x.name)),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => to = v!),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'ترحيل التحويل',
              onPressed: () async {
                if (from == to || !_isPositiveMoney(amount.text)) {
                  setDialog(
                    () => error = 'اختر حسابين مختلفين وأدخل مبلغاً موجباً.',
                  );
                  return;
                }
                try {
                  await context
                      .read<FinanceSetupCubit>()
                      .repository
                      .createCashTransfer(<String, dynamic>{
                        'fromFinancialLocationId': from,
                        'toFinancialLocationId': to,
                        'amount': amount.text,
                        'transferDate': DateTime.now()
                            .toIso8601String()
                            .substring(0, 10),
                        'description': note.text.trim().isEmpty
                            ? null
                            : note.text.trim(),
                        'idempotencyKey':
                            'cash-transfer-${DateTime.now().microsecondsSinceEpoch}',
                      });
                  if (dialog.mounted) Navigator.pop(dialog);
                  await _load();
                } catch (e) {
                  if (dialog.mounted) setDialog(() => error = e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    note.dispose();
  }

  Future<void> _changeStatus(FinancialLocation item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(item.isActive ? 'تعطيل الحساب؟' : 'تفعيل الحساب؟'),
        content: const Text(
          'لن يتغير الرصيد؛ يؤثر هذا فقط على إتاحة الحساب للحركات الجديدة.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: item.isActive ? 'تعطيل' : 'تفعيل',
            onPressed: () => Navigator.pop(dialog, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context
          .read<FinanceSetupCubit>()
          .repository
          .setFinancialLocationStatus(item.kind, item.id, !item.isActive);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _details(FinancialLocation item) async {
    final repo = context.read<FinanceSetupCubit>().repository;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text('${item.code} — ${item.name}'),
        content: SizedBox(
          width: 820,
          child: FutureBuilder<List<dynamic>>(
            future: Future.wait<dynamic>(<Future<dynamic>>[
              repo.getFinancialLocation(item.kind, item.id),
              repo.getFinancialLocationTransactions(item.kind, item.id),
            ]),
            builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) return Text(snapshot.error.toString());
              final Map<String, dynamic> detail =
                  snapshot.data![0] as Map<String, dynamic>;
              final List<Map<String, dynamic>> transactions =
                  snapshot.data![1] as List<Map<String, dynamic>>;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: <Widget>[
                        _detail(
                          'الرصيد',
                          '${detail['balance'] ?? item.balance}',
                        ),
                        _detail(
                          'الوارد اليوم',
                          '${detail['todayIncoming'] ?? item.todayIncoming}',
                        ),
                        _detail(
                          'الصادر اليوم',
                          '${detail['todayOutgoing'] ?? item.todayOutgoing}',
                        ),
                        _detail(
                          'حساب الأستاذ',
                          '${detail['financialAccountCode'] ?? item.financialAccountCode}',
                        ),
                        _detail(
                          'الفرع',
                          '${detail['branchName'] ?? item.branchName ?? 'عام'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'الحركات',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (transactions.isEmpty)
                      const Text('لا توجد حركات ضمن السياق المحدد.')
                    else
                      FinancePaginatedTable(
                        minWidth: 680,
                        columns: const <DataColumn>[
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('المرجع')),
                          DataColumn(label: Text('الوصف')),
                          DataColumn(label: Text('مدين')),
                          DataColumn(label: Text('دائن')),
                        ],
                        rows: transactions
                            .map(
                              (Map<String, dynamic> row) => DataRow(
                                cells: <DataCell>[
                                  DataCell(
                                    Text(
                                      '${row['date'] ?? row['entryDate'] ?? '—'}',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${row['reference'] ?? row['entryNumber'] ?? '—'}',
                                    ),
                                  ),
                                  DataCell(
                                    Text('${row['description'] ?? '—'}'),
                                  ),
                                  DataCell(Text('${row['debit'] ?? '—'}')),
                                  DataCell(Text('${row['credit'] ?? '—'}')),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => SizedBox(
    width: 140,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Future<void> _editLocation([FinancialLocation? current]) async {
    final TextEditingController code = TextEditingController(
      text: current?.code,
    );
    final TextEditingController name = TextEditingController(
      text: current?.name,
    );
    final TextEditingController bankName = TextEditingController(
      text: current?.bankName,
    );
    final TextEditingController reference = TextEditingController();
    String kind = current?.kind ?? 'cash';
    String type = current?.type ?? 'cash_drawer';
    int? accountId =
        current?.financialAccountId ??
        (_accounts.isEmpty ? null : _accounts.first.id);
    int? branchId;
    bool active = current?.isActive ?? true;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialog) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialog) => AlertDialog(
          title: Text(
            current == null ? 'إضافة حساب نقدي أو بنكي' : 'تعديل الحساب',
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (current == null)
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      decoration: const InputDecoration(
                        labelText: 'نوع الحساب',
                      ),
                      items: const <String>['cash', 'bank']
                          .map(
                            (String v) => DropdownMenuItem(
                              value: v,
                              child: Text(v == 'cash' ? 'نقدي' : 'بنكي'),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) => setDialog(() {
                        kind = v!;
                        type = kind == 'cash' ? 'cash_drawer' : 'bank';
                      }),
                    ),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'الرمز'),
                  ),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'التصنيف'),
                    items:
                        (kind == 'cash'
                                ? const <String>[
                                    'cash_drawer',
                                    'main_safe',
                                    'petty_cash',
                                  ]
                                : const <String>['bank'])
                            .map(
                              (String v) =>
                                  DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (String? v) => setDialog(() => type = v!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: accountId,
                    decoration: const InputDecoration(
                      labelText: 'حساب الأستاذ',
                    ),
                    items: _accounts
                        .map(
                          (FinancialAccount a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.code} — ${a.nameAr}'),
                          ),
                        )
                        .toList(),
                    onChanged: (int? v) => setDialog(() => accountId = v),
                  ),
                  DropdownButtonFormField<int?>(
                    initialValue: branchId,
                    decoration: const InputDecoration(
                      labelText: 'الفرع (اختياري)',
                    ),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem(value: null, child: Text('عام')),
                      ..._branches.map(
                        (Branch b) =>
                            DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ),
                    ],
                    onChanged: (int? v) => setDialog(() => branchId = v),
                  ),
                  if (kind == 'bank')
                    TextField(
                      controller: bankName,
                      decoration: const InputDecoration(labelText: 'اسم البنك'),
                    ),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'مرجع/رقم مخفي (اختياري)',
                    ),
                  ),
                  SwitchListTile(
                    value: active,
                    title: const Text('الحساب نشط'),
                    onChanged: (bool v) => setDialog(() => active = v),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'حفظ',
              onPressed: () async {
                if (code.text.trim().isEmpty ||
                    name.text.trim().isEmpty ||
                    accountId == null ||
                    (kind == 'bank' && bankName.text.trim().isEmpty)) {
                  setDialog(() => error = 'أكمل الحقول المطلوبة.');
                  return;
                }
                try {
                  await context
                      .read<FinanceSetupCubit>()
                      .repository
                      .saveFinancialLocation(kind, <String, dynamic>{
                        'code': code.text.trim(),
                        'name': name.text.trim(),
                        'type': type,
                        'branchId': branchId,
                        'financialAccountId': accountId,
                        'bankName': kind == 'bank'
                            ? bankName.text.trim()
                            : null,
                        'maskedReference': reference.text.trim().isEmpty
                            ? null
                            : reference.text.trim(),
                        'isActive': active,
                      }, id: current?.id);
                  if (dialog.mounted) Navigator.pop(dialog);
                  await _load();
                } catch (e) {
                  if (dialog.mounted) setDialog(() => error = e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    bankName.dispose();
    reference.dispose();
  }

  bool _isPositiveMoney(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
    if (match == null) return false;
    return int.parse(match.group(1)!) * 100 +
            int.parse((match.group(2) ?? '').padRight(2, '0')) >
        0;
  }
}
