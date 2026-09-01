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

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<ExpenseRecord> _expenses = const [];
  List<ExpenseCategory> _categories = const [];
  List<PaymentMethodSetting> _methods = const [];
  List<FinancialLocation> _locations = const [];
  List<Branch> _branches = const [];
  SetupStatus? _status;
  bool _loading = true;
  String? _error;

  String? _filterFrom;
  String? _filterTo;
  int? _filterBranchId;
  int? _filterCategoryId;
  String? _filterStatus;
  String? _filterPaymentStatus;
  int? _filterPaymentMethodId;

  static const Map<String, String> _statusLabels = <String, String>{
    'draft': 'مسودة',
    'pending_approval': 'بانتظار الاعتماد',
    'approved': 'معتمد',
    'paid': 'مدفوع',
    'rejected': 'مرفوض',
    'reversed': 'معكوس',
  };

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
        repo.getExpenses(filters: _filters()),
        repo.getExpenseCategories(),
        repo.getPaymentMethods(),
        repo.getFinancialLocations('cash'),
        repo.getFinancialLocations('bank'),
        repo.getBranches(),
        repo.getSetupStatus(),
      ]);
      if (mounted) {
        setState(() {
          _expenses = data[0] as List<ExpenseRecord>;
          _categories = data[1] as List<ExpenseCategory>;
          _methods = data[2] as List<PaymentMethodSetting>;
          _locations = [
            ...data[3] as List<FinancialLocation>,
            ...data[4] as List<FinancialLocation>,
          ];
          _branches = data[5] as List<Branch>;
          _status = data[6] as SetupStatus;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _filters() => <String, dynamic>{
    if (_filterFrom != null && _filterFrom!.isNotEmpty) 'from': _filterFrom,
    if (_filterTo != null && _filterTo!.isNotEmpty) 'to': _filterTo,
    if (_filterBranchId != null) 'branchId': _filterBranchId,
    if (_filterCategoryId != null) 'expenseCategoryId': _filterCategoryId,
    if (_filterStatus != null) 'status': _filterStatus,
    if (_filterPaymentStatus != null) 'paymentStatus': _filterPaymentStatus,
    if (_filterPaymentMethodId != null)
      'paymentMethodId': _filterPaymentMethodId,
  };

  void _clearFilters() {
    setState(() {
      _filterFrom = null;
      _filterTo = null;
      _filterBranchId = null;
      _filterCategoryId = null;
      _filterStatus = null;
      _filterPaymentStatus = null;
      _filterPaymentMethodId = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ManagementPageHeader(
          title: 'المصروفات',
          subtitle: 'سجل أعمال مستقل؛ لا ينشئ القيد إلا عند الدفع المعتمد.',
          actions: <Widget>[
            AppButton(
              label: 'إضافة مصروف',
              icon: Icons.add,
              onPressed: _categories.where((x) => x.isActive).isEmpty
                  ? null
                  : _edit,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_status != null) ...<Widget>[
          _kpis(_status!),
          const SizedBox(height: AppSpacing.lg),
        ],
        ManagementFilterBar(
          children: <Widget>[
            SizedBox(
              width: 130,
              child: TextField(
                onChanged: (v) => _filterFrom = v,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(hintText: 'من YYYY-MM-DD'),
              ),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                onChanged: (v) => _filterTo = v,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(hintText: 'إلى YYYY-MM-DD'),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<int?>(
                initialValue: _filterBranchId,
                isExpanded: true,
                hint: const Text('كل الفروع'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem(value: null, child: Text('كل الفروع')),
                  ..._branches.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _filterBranchId = v);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<int?>(
                initialValue: _filterCategoryId,
                isExpanded: true,
                hint: const Text('كل الفئات'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem(value: null, child: Text('كل الفئات')),
                  ..._categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _filterCategoryId = v);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String?>(
                initialValue: _filterStatus,
                isExpanded: true,
                hint: const Text('كل الحالات'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('كل الحالات'),
                  ),
                  ..._statusLabels.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _filterStatus = v);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String?>(
                initialValue: _filterPaymentStatus,
                isExpanded: true,
                hint: const Text('كل حالات الدفع'),
                items: const <DropdownMenuItem<String?>>[
                  DropdownMenuItem(value: null, child: Text('كل حالات الدفع')),
                  DropdownMenuItem(value: 'unpaid', child: Text('غير مدفوع')),
                  DropdownMenuItem(value: 'paid', child: Text('مدفوع')),
                ],
                onChanged: (v) {
                  setState(() => _filterPaymentStatus = v);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<int?>(
                initialValue: _filterPaymentMethodId,
                isExpanded: true,
                hint: const Text('كل طرق الدفع'),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem(
                    value: null,
                    child: Text('كل طرق الدفع'),
                  ),
                  ..._methods.map(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _filterPaymentMethodId = v);
                  _load();
                },
              ),
            ),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('مسح الفلاتر'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ManagementMessage(message: _error!, error: true, onRetry: _load)
              : _expenses.isEmpty
              ? ManagementMessage(
                  message: 'لا توجد مصروفات مسجلة بعد.',
                  onRetry: _load,
                )
              : ManagementTableShell(
                  minWidth: 1320,
                  child: FinancePaginatedTable(
                    minWidth: 1320,
                    columns: const <DataColumn>[
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('المرجع')),
                      DataColumn(label: Text('الفرع')),
                      DataColumn(label: Text('الفئة')),
                      DataColumn(label: Text('الوصف')),
                      DataColumn(label: Text('الإجمالي')),
                      DataColumn(label: Text('طريقة الدفع')),
                      DataColumn(label: Text('أنشئ بواسطة')),
                      DataColumn(label: Text('الدفع')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('إجراء')),
                    ],
                    rows: _expenses
                        .map(
                          (x) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(x.expenseDate)),
                              DataCell(Text(x.expenseNumber)),
                              DataCell(Text(x.branchName ?? 'عام')),
                              DataCell(Text(x.expenseCategoryName)),
                              DataCell(Text(x.description)),
                              DataCell(Text(x.totalAmount)),
                              DataCell(Text(x.paymentMethodName ?? '—')),
                              DataCell(Text(x.createdByName ?? '—')),
                              DataCell(
                                ManagementBadge(
                                  label: x.paymentStatus == 'paid'
                                      ? 'مدفوع'
                                      : 'غير مدفوع',
                                  tone: x.paymentStatus == 'paid'
                                      ? ManagementTone.success
                                      : ManagementTone.warning,
                                ),
                              ),
                              DataCell(
                                ManagementBadge(
                                  label: _statusLabels[x.status] ?? x.status,
                                  tone:
                                      x.status == 'rejected' ||
                                          x.status == 'reversed'
                                      ? ManagementTone.neutral
                                      : ManagementTone.info,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'عرض',
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      onPressed: () => _details(x),
                                    ),
                                    if (x.status == 'draft')
                                      IconButton(
                                        tooltip: 'تعديل',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _edit(existing: x),
                                      ),
                                    if (x.status == 'draft')
                                      IconButton(
                                        tooltip: 'إرسال للاعتماد',
                                        icon: const Icon(Icons.send_outlined),
                                        onPressed: () => _action(x, 'submit'),
                                      ),
                                    if (x.status == 'pending_approval')
                                      IconButton(
                                        tooltip: 'اعتماد',
                                        icon: const Icon(Icons.check_outlined),
                                        onPressed: () => _action(x, 'approve'),
                                      ),
                                    if (x.status == 'pending_approval')
                                      IconButton(
                                        tooltip: 'رفض',
                                        icon: const Icon(Icons.close_outlined),
                                        onPressed: () => _reject(x),
                                      ),
                                    if (x.status == 'approved')
                                      IconButton(
                                        tooltip: 'دفع',
                                        icon: const Icon(
                                          Icons.payments_outlined,
                                        ),
                                        onPressed: () => _pay(x),
                                      ),
                                    if (x.status == 'paid' &&
                                        x.reversalJournalEntryId == null)
                                      IconButton(
                                        tooltip: 'عكس',
                                        icon: const Icon(Icons.undo_outlined),
                                        onPressed: () => _confirmReverse(x),
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

  Widget _kpis(SetupStatus status) => LayoutBuilder(
    builder: (context, constraints) {
      final int columns = constraints.maxWidth < 720
          ? 1
          : constraints.maxWidth < 1080
          ? 2
          : 4;
      final List<Widget> cards = <Widget>[
        ManagementKpiCard(
          label: 'مصروفات اليوم',
          value: status.expensesToday,
          icon: Icons.today_outlined,
        ),
        ManagementKpiCard(
          label: 'مصروفات هذا الشهر',
          value: status.expensesThisMonth,
          icon: Icons.calendar_month_outlined,
        ),
        ManagementKpiCard(
          label: 'بانتظار الاعتماد',
          value: '${status.pendingExpenseCount}',
          icon: Icons.pending_actions_outlined,
        ),
        ManagementKpiCard(
          label: 'غير مدفوعة',
          value: '${status.unpaidExpenseCount}',
          icon: Icons.money_off_outlined,
        ),
      ];
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.6,
        children: cards,
      );
    },
  );

  Future<String?> _pickDate(String? initial) async {
    final DateTime seed = initial != null && initial.isNotEmpty
        ? DateTime.tryParse(initial) ?? DateTime.now()
        : DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    return picked?.toIso8601String().substring(0, 10);
  }

  Future<void> _edit({ExpenseRecord? existing}) async {
    final category = ValueNotifier<int>(
      existing?.expenseCategoryId ??
          _categories.firstWhere((x) => x.isActive).id,
    );
    final branch = ValueNotifier<int?>(existing?.branchId);
    final date = ValueNotifier<String>(
      existing?.expenseDate ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    final amount = TextEditingController(text: existing?.amount ?? '');
    final tax = TextEditingController(text: existing?.taxAmount ?? '0.00');
    final desc = TextEditingController(text: existing?.description ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    String? error;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, set) {
          final double total =
              (double.tryParse(amount.text.trim()) ?? 0) +
              (double.tryParse(tax.text.trim()) ?? 0);
          return AlertDialog(
            title: Text(existing == null ? 'إضافة مصروف' : 'تعديل مصروف'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<int>(
                      initialValue: category.value,
                      decoration: const InputDecoration(labelText: 'الفئة'),
                      items: _categories
                          .where((x) => x.isActive)
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.id,
                              child: Text('${x.code} - ${x.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => set(() => category.value = v!),
                    ),
                    DropdownButtonFormField<int?>(
                      initialValue: branch.value,
                      decoration: const InputDecoration(
                        labelText: 'الفرع (اختياري)',
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('عام (كل الفروع)'),
                        ),
                        ..._branches.map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => set(() => branch.value = v),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickDate(date.value);
                        if (picked != null) set(() => date.value = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'التاريخ'),
                        child: Text(date.value),
                      ),
                    ),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => set(() {}),
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                    ),
                    TextField(
                      controller: tax,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => set(() {}),
                      decoration: const InputDecoration(labelText: 'الضريبة'),
                    ),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'الإجمالي'),
                      child: Text(total.toStringAsFixed(2)),
                    ),
                    TextField(
                      controller: desc,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
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
                  if (!_money(amount.text) ||
                      !_money(tax.text) ||
                      desc.text.trim().isEmpty) {
                    set(() => error = 'أدخل مبلغاً صالحاً ووصفاً.');
                    return;
                  }
                  try {
                    await context
                        .read<FinanceSetupCubit>()
                        .repository
                        .saveExpense(<String, dynamic>{
                          'branchId': branch.value,
                          'expenseCategoryId': category.value,
                          'amount': amount.text,
                          'taxAmount': tax.text,
                          'expenseDate': date.value,
                          'description': desc.text.trim(),
                          'notes': notes.text.trim().isEmpty
                              ? null
                              : notes.text.trim(),
                          if (existing == null)
                            'idempotencyKey':
                                'expense-${DateTime.now().microsecondsSinceEpoch}',
                        }, id: existing?.id);
                    if (d.mounted) Navigator.pop(d);
                    await _load();
                  } catch (e) {
                    if (d.mounted) set(() => error = e.toString());
                  }
                },
              ),
            ],
          );
        },
      ),
    );
    amount.dispose();
    tax.dispose();
    desc.dispose();
    notes.dispose();
    category.dispose();
    branch.dispose();
    date.dispose();
  }

  Future<void> _action(ExpenseRecord item, String action) async {
    try {
      await context.read<FinanceSetupCubit>().repository.expenseAction(
        item.id,
        action,
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmReverse(ExpenseRecord item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('عكس المصروف'),
        content: Text(
          'سيتم إنشاء قيد عكسي لـ ${item.expenseNumber} واستعادة رصيد الحساب. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'تأكيد العكس',
            onPressed: () => Navigator.pop(d, true),
          ),
        ],
      ),
    );
    if (confirmed == true) await _action(item, 'reverse');
  }

  Future<void> _reject(ExpenseRecord item) async {
    final reason = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('رفض المصروف'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'رفض',
            onPressed: () async {
              if (reason.text.trim().isEmpty) return;
              await context.read<FinanceSetupCubit>().repository.expenseAction(
                item.id,
                'reject',
                <String, dynamic>{'rejectionReason': reason.text.trim()},
              );
              if (d.mounted) Navigator.pop(d);
              await _load();
            },
          ),
        ],
      ),
    );
    reason.dispose();
  }

  Future<void> _pay(ExpenseRecord item) async {
    final activeMethods = _methods.where((x) => x.isActive).toList();
    final activeLocations = _locations.where((x) => x.isActive).toList();
    if (activeMethods.isEmpty || activeLocations.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('تعذر فتح الدفع'),
          content: const Text(
            'لا توجد طريقة دفع أو حساب نقدي/بنكي نشط. أضف واحداً من إعدادات المالية أولاً.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }
    var method = activeMethods.first.id;
    var location = activeLocations.first.id;
    final date = ValueNotifier<String>(
      DateTime.now().toIso8601String().substring(0, 10),
    );
    final notes = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text('دفع ${item.expenseNumber} — ${item.totalAmount}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<int>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: activeMethods
                      .map(
                        (x) =>
                            DropdownMenuItem(value: x.id, child: Text(x.name)),
                      )
                      .toList(),
                  onChanged: (v) => set(() => method = v!),
                ),
                DropdownButtonFormField<int>(
                  initialValue: location,
                  decoration: const InputDecoration(
                    labelText: 'الحساب النقدي/البنكي',
                  ),
                  items: activeLocations
                      .map(
                        (x) =>
                            DropdownMenuItem(value: x.id, child: Text(x.name)),
                      )
                      .toList(),
                  onChanged: (v) => set(() => location = v!),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await _pickDate(date.value);
                    if (picked != null) set(() => date.value = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ الدفع'),
                    child: Text(date.value),
                  ),
                ),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                  ),
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
              label: 'ترحيل الدفع',
              onPressed: () async {
                try {
                  await context.read<FinanceSetupCubit>().repository.payExpense(
                    item.id,
                    <String, dynamic>{
                      'paymentMethodId': method,
                      'financialLocationId': location,
                      'paymentDate': date.value,
                      if (notes.text.trim().isNotEmpty)
                        'description': notes.text.trim(),
                      'idempotencyKey':
                          'expense-payment-${item.id}-${DateTime.now().microsecondsSinceEpoch}',
                    },
                  );
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
    notes.dispose();
    date.dispose();
  }

  Future<void> _details(ExpenseRecord item) => showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(item.expenseNumber),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ManagementBadge(
                    label: _statusLabels[item.status] ?? item.status,
                    tone: item.status == 'rejected' || item.status == 'reversed'
                        ? ManagementTone.neutral
                        : ManagementTone.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ManagementBadge(
                    label: item.paymentStatus == 'paid' ? 'مدفوع' : 'غير مدفوع',
                    tone: item.paymentStatus == 'paid'
                        ? ManagementTone.success
                        : ManagementTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _section('التفاصيل'),
              Text('الفئة: ${item.expenseCategoryName}'),
              Text('الفرع: ${item.branchName ?? 'عام'}'),
              Text('التاريخ: ${item.expenseDate}'),
              Text('الوصف: ${item.description}'),
              if (item.notes != null) Text('ملاحظات: ${item.notes}'),
              Text(
                'المبلغ: ${item.amount}   الضريبة: ${item.taxAmount}   الإجمالي: ${item.totalAmount}',
              ),
              const SizedBox(height: AppSpacing.md),
              _section('الاعتماد'),
              if (item.createdByName != null)
                Text('أنشئ بواسطة: ${item.createdByName}'),
              if (item.approvedAt != null)
                Text('اعتُمد في: ${item.approvedAt}'),
              if (item.rejectedAt != null) Text('رُفض في: ${item.rejectedAt}'),
              if (item.rejectionReason != null)
                Text('سبب الرفض: ${item.rejectionReason}'),
              const SizedBox(height: AppSpacing.md),
              _section('الدفع'),
              if (item.paymentMethodName != null)
                Text('طريقة الدفع: ${item.paymentMethodName}'),
              if (item.financialLocationName != null)
                Text('الحساب: ${item.financialLocationName}'),
              if (item.paidAt != null) Text('تاريخ الدفع: ${item.paidAt}'),
              if (item.status != 'paid' && item.status != 'reversed')
                const Text('لم يُدفع بعد.'),
              const SizedBox(height: AppSpacing.md),
              _section('المحاسبة'),
              if (item.journalEntryId != null)
                Text('القيد المُرحّل: JE-${item.journalEntryId}')
              else
                const Text('لا يوجد قيد مُرحّل بعد.'),
              if (item.reversalJournalEntryId != null)
                Text('قيد العكس: JE-${item.reversalJournalEntryId}'),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  bool _money(String value) =>
      RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value.trim());
}
