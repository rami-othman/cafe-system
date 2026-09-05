import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_paginated_table.dart';

class ExpenseCategoriesScreen extends StatefulWidget {
  const ExpenseCategoriesScreen({super.key});
  @override
  State<ExpenseCategoriesScreen> createState() =>
      _ExpenseCategoriesScreenState();
}

class _ExpenseCategoriesScreenState extends State<ExpenseCategoriesScreen> {
  List<ExpenseCategory> _rows = const [];
  List<FinancialAccount> _accounts = const [];
  bool _loading = true;
  String? _error;
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
      final data = await Future.wait([
        repo.getExpenseCategories(),
        repo.getAccounts(group: 'expenses', status: 'active'),
      ]);
      if (mounted) {
        setState(() {
          _rows = data[0] as List<ExpenseCategory>;
          _accounts = data[1] as List<FinancialAccount>;
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
          title: 'فئات المصروفات',
          subtitle: 'كل فئة مرتبطة بحساب مصروف فعّال في دليل الحسابات.',
          actions: <Widget>[
            AppButton(
              label: 'إضافة فئة',
              icon: Icons.add,
              onPressed: _accounts.isEmpty ? null : _form,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ManagementMessage(message: _error!, error: true, onRetry: _load)
              : _rows.isEmpty
              ? const ManagementMessage(message: 'لا توجد فئات مصروفات مهيأة.')
              : ManagementTableShell(
                  minWidth: 700,
                  child: FinancePaginatedTable(
                    minWidth: 700,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('الرمز')),
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('حساب المصروف')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('إجراء')),
                    ],
                    rows: _rows
                        .map(
                          (x) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(x.code)),
                              DataCell(Text(x.name)),
                              DataCell(Text(x.financialAccountCode)),
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
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _form(existing: x),
                                    ),
                                    IconButton(
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
  Future<void> _form({ExpenseCategory? existing}) async {
    final code = TextEditingController(text: existing?.code ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final sortOrder = TextEditingController(
      text: '${existing?.sortOrder ?? 0}',
    );
    var account = _accounts.any((x) => x.id == existing?.financialAccountId)
        ? existing!.financialAccountId
        : _accounts.first.id;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(existing == null ? 'إضافة فئة' : 'تعديل فئة'),
          content: Column(
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
              DropdownButtonFormField<int>(
                initialValue: account,
                decoration: const InputDecoration(labelText: 'حساب المصروف'),
                items: _accounts
                    .map(
                      (x) => DropdownMenuItem(
                        value: x.id,
                        child: Text('${x.code} - ${x.nameAr}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => set(() => account = v!),
              ),
              TextField(
                controller: sortOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ترتيب العرض (اختياري)',
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
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
                  set(() => error = 'أدخل رمزاً واسماً صالحين.');
                  return;
                }
                try {
                  await context
                      .read<FinanceSetupCubit>()
                      .repository
                      .saveExpenseCategory(<String, dynamic>{
                        'code': code.text.trim(),
                        'name': name.text.trim(),
                        'financialAccountId': account,
                        'isActive': existing?.isActive ?? true,
                        'sortOrder': int.tryParse(sortOrder.text.trim()) ?? 0,
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
    sortOrder.dispose();
  }

  Future<void> _toggle(ExpenseCategory item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(item.isActive ? 'تعطيل الفئة' : 'تفعيل الفئة'),
        content: Text(
          item.isActive
              ? 'هل تريد تعطيل فئة "${item.name}"؟ لن تظهر بعد ذلك عند إنشاء مصروف جديد.'
              : 'هل تريد تفعيل فئة "${item.name}"؟',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: item.isActive ? 'تعطيل' : 'تفعيل',
            onPressed: () => Navigator.pop(d, true),
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
          .setExpenseCategoryStatus(item.id, !item.isActive);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }
}
