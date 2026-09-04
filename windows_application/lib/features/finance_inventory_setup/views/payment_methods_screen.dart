import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_paginated_table.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});
  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsState();
}

class _PaymentMethodsState extends State<PaymentMethodsScreen> {
  List<PaymentMethodSetting> _rows = const [];
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
      final rows = await context
          .read<FinanceSetupCubit>()
          .repository
          .getPaymentMethods();
      if (mounted) setState(() => _rows = rows);
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
          title: 'طرق الدفع',
          subtitle:
              'تهيئة طرق الدفع ومطابقتها بحسابات الأستاذ دون ربط تلقائي مع نقاط البيع.',
          actions: <Widget>[
            AppButton(label: 'إضافة طريقة', icon: Icons.add, onPressed: _form),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ManagementMessage(message: _error!, error: true, onRetry: _load)
              : _rows.isEmpty
              ? const ManagementMessage(message: 'لا توجد طرق دفع مهيأة.')
              : ManagementTableShell(
                  minWidth: 880,
                  child: FinancePaginatedTable(
                    minWidth: 880,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('الرمز')),
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('حساب الأستاذ')),
                      DataColumn(label: Text('الوجهة المالية')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('إجراء')),
                    ],
                    rows: _rows
                        .map(
                          (x) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(x.name)),
                              DataCell(Text(x.code)),
                              DataCell(Text(x.type)),
                              DataCell(Text(x.financialAccountCode)),
                              DataCell(
                                Text(x.financialLocationName ?? 'غير مربوط'),
                              ),
                              DataCell(
                                ManagementBadge(
                                  label: x.isActive ? 'نشط' : 'غير نشط',
                                  tone: x.isActive
                                      ? ManagementTone.success
                                      : ManagementTone.neutral,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'تعديل',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _form(existing: x),
                                    ),
                                    IconButton(
                                      tooltip: x.isActive ? 'تعطيل' : 'تفعيل',
                                      icon: Icon(
                                        x.isActive
                                            ? Icons.toggle_on_outlined
                                            : Icons.toggle_off_outlined,
                                      ),
                                      onPressed: () => _toggle(x),
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
  Future<void> _form({PaymentMethodSetting? existing}) async {
    final cubit = context.read<FinanceSetupCubit>();
    await cubit.loadAccounts();
    final accounts = cubit.state.accounts.where((a) => a.isActive).toList();
    final List<dynamic> locationResults =
        await Future.wait<dynamic>(<Future<dynamic>>[
          cubit.repository.getFinancialLocations('cash'),
          cubit.repository.getFinancialLocations('bank'),
        ]);
    final List<FinancialLocation> locations = <FinancialLocation>[
      ...(locationResults[0] as List<FinancialLocation>),
      ...(locationResults[1] as List<FinancialLocation>),
    ].where((FinancialLocation location) => location.isActive).toList();
    if (!mounted || accounts.isEmpty) return;
    final code = TextEditingController(text: existing?.code ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    var account = accounts.any((a) => a.id == existing?.financialAccountId)
        ? existing!.financialAccountId
        : accounts.first.id;
    int? locationId =
        locations.any(
          (FinancialLocation location) =>
              location.id == existing?.financialLocationId,
        )
        ? existing!.financialLocationId
        : null;
    var type = existing?.type ?? 'cash';
    String? error;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(
            existing == null ? 'إضافة طريقة دفع' : 'تعديل طريقة الدفع',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
                  items:
                      const <String>[
                            'cash',
                            'card',
                            'bank_transfer',
                            'delivery_app',
                            'customer_credit',
                            'other',
                          ]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: (v) => set(() => type = v!),
                ),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: account,
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.code} - ${a.nameAr}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => set(() => account = v!),
                ),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: locationId,
                  decoration: const InputDecoration(
                    labelText: 'الوجهة النقدية أو البنكية',
                    helperText: 'اختياري؛ يجب أن تستخدم حساب الأستاذ نفسه.',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('غير مربوط بموقع مالي'),
                    ),
                    ...locations.map(
                      (FinancialLocation location) => DropdownMenuItem<int?>(
                        value: location.id,
                        child: Text('${location.code} — ${location.name}'),
                      ),
                    ),
                  ],
                  onChanged: (int? value) => set(() {
                    locationId = value;
                    if (value != null) {
                      account = locations
                          .firstWhere(
                            (FinancialLocation location) =>
                                location.id == value,
                          )
                          .financialAccountId;
                    }
                  }),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'حفظ',
              onPressed: () async {
                if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
                  set(() => error = 'الرمز والاسم مطلوبان.');
                  return;
                }
                try {
                  await cubit.repository.savePaymentMethod(<String, dynamic>{
                    'code': code.text.trim(),
                    'name': name.text.trim(),
                    'type': type,
                    'financialAccountId': account,
                    'financialLocationId': locationId,
                    'isActive': existing?.isActive ?? true,
                  }, id: existing?.id);
                  if (d.mounted) Navigator.pop(d);
                  await _load();
                } catch (e) {
                  if (d.mounted) set(() => error = e.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
  }

  Future<void> _toggle(PaymentMethodSetting item) async {
    final action = item.isActive ? 'تعطيل' : 'تفعيل';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('$action طريقة الدفع'),
        content: Text('هل تريد $action ${item.name}؟'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: action,
            onPressed: () => Navigator.pop(dialog, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<FinanceSetupCubit>().repository.setPaymentMethodStatus(
        item.id,
        !item.isActive,
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }
}
