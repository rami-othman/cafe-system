import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../pos/models/branch.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_paginated_table.dart';

class SupplierProfileScreen extends StatefulWidget {
  const SupplierProfileScreen({
    super.key,
    required this.supplierId,
    this.initialTab = 0,
  });
  final int supplierId;
  final int initialTab;
  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  Supplier? _supplier;
  List<SupplierInvoice> _invoices = const [];
  List<SupplierPayment> _payments = const [];
  List<SupplierStatementLine> _statement = const [];
  List<ExpenseCategory> _categories = const [];
  List<FinancialAccount> _accounts = const [];
  List<PaymentMethodSetting> _methods = const [];
  List<FinancialLocation> _locations = const [];
  List<Branch> _branches = const [];
  bool _loading = true;
  String? _error;

  static const Map<String, String> _statusLabels = <String, String>{
    'draft': 'مسودة',
    'posted': 'مُرحّلة',
    'partially_paid': 'مدفوعة جزئياً',
    'paid': 'مدفوعة بالكامل',
    'cancelled': 'ملغاة',
  };

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<FinanceSetupCubit>().repository;
      final data = await Future.wait([
        repo.getSupplier(widget.supplierId),
        repo.getSupplierInvoices(
          filters: <String, dynamic>{'supplierId': widget.supplierId},
        ),
        repo.getSupplierPayments(
          filters: <String, dynamic>{'supplierId': widget.supplierId},
        ),
        repo.getSupplierStatement(widget.supplierId),
        repo.getExpenseCategories(),
        repo.getAccounts(status: 'active'),
        repo.getPaymentMethods(),
        repo.getFinancialLocations('cash'),
        repo.getFinancialLocations('bank'),
        repo.getBranches(),
      ]);
      if (mounted) {
        setState(() {
          _supplier = data[0] as Supplier;
          _invoices = data[1] as List<SupplierInvoice>;
          _payments = data[2] as List<SupplierPayment>;
          _statement = data[3] as List<SupplierStatementLine>;
          _categories = data[4] as List<ExpenseCategory>;
          _accounts = data[5] as List<FinancialAccount>;
          _methods = data[6] as List<PaymentMethodSetting>;
          _locations = [
            ...data[7] as List<FinancialLocation>,
            ...data[8] as List<FinancialLocation>,
          ];
          _branches = data[9] as List<Branch>;
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
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? ManagementMessage(message: _error!, error: true, onRetry: _load)
        : _supplier == null
        ? const ManagementMessage(message: 'تعذر إيجاد المورد.')
        : _content(_supplier!),
  );

  Widget _content(Supplier supplier) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      ManagementPageHeader(
        title: '${supplier.supplierNumber} — ${supplier.name}',
        subtitle: 'الرصيد مستمد من الفواتير والدفعات المُرحّلة فقط.',
        actions: <Widget>[
          AppButton(
            label: 'فاتورة جديدة',
            icon: Icons.receipt_long_outlined,
            onPressed: _newInvoice,
          ),
          AppButton(
            label: 'دفعة جديدة',
            icon: Icons.payments_outlined,
            variant: AppButtonVariant.outlined,
            onPressed: _openInvoices.isEmpty ? null : _newPayment,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.6,
        children: <Widget>[
          ManagementKpiCard(
            label: 'الرصيد المستحق',
            value: supplier.outstandingBalance,
            icon: Icons.account_balance_wallet_outlined,
          ),
          ManagementKpiCard(
            label: 'إجمالي الفواتير',
            value: supplier.totalInvoiced ?? '0.00',
            icon: Icons.description_outlined,
          ),
          ManagementKpiCard(
            label: 'إجمالي المدفوع',
            value: supplier.totalPaid ?? '0.00',
            icon: Icons.check_circle_outline,
          ),
          ManagementKpiCard(
            label: 'المتأخر',
            value: supplier.overdueBalance,
            icon: Icons.warning_amber_outlined,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: const <Widget>[
          Tab(text: 'الفواتير'),
          Tab(text: 'الدفعات'),
          Tab(text: 'كشف الحساب'),
          Tab(text: 'المشتريات'),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: <Widget>[
            _invoicesTab(),
            _paymentsTab(),
            _statementTab(),
            const ManagementMessage(message: 'وحدة المشتريات غير مطبقة بعد.'),
          ],
        ),
      ),
    ],
  );

  List<SupplierInvoice> get _openInvoices => _invoices
      .where((x) => x.status == 'posted' || x.status == 'partially_paid')
      .toList();

  Widget _invoicesTab() => _invoices.isEmpty
      ? const ManagementMessage(message: 'لا توجد فواتير لهذا المورد بعد.')
      : ManagementTableShell(
          minWidth: 1100,
          child: FinancePaginatedTable(
            minWidth: 1100,
            columns: const <DataColumn>[
              DataColumn(label: Text('المرجع')),
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('الاستحقاق')),
              DataColumn(label: Text('الإجمالي')),
              DataColumn(label: Text('المتبقي')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text('إجراء')),
            ],
            rows: _invoices
                .map(
                  (x) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(x.internalReference)),
                      DataCell(Text(x.invoiceDate)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(x.dueDate),
                            if (x.isOverdue) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs),
                              const ManagementBadge(
                                label: 'متأخر',
                                tone: ManagementTone.danger,
                              ),
                            ],
                          ],
                        ),
                      ),
                      DataCell(Text(x.totalAmount)),
                      DataCell(Text(x.remainingAmount)),
                      DataCell(
                        ManagementBadge(
                          label: _statusLabels[x.status] ?? x.status,
                          tone: x.status == 'paid'
                              ? ManagementTone.success
                              : x.status == 'cancelled'
                              ? ManagementTone.neutral
                              : x.status == 'partially_paid'
                              ? ManagementTone.warning
                              : ManagementTone.info,
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (x.status == 'draft')
                              IconButton(
                                tooltip: 'ترحيل',
                                icon: const Icon(Icons.upload_outlined),
                                onPressed: () => _postInvoice(x),
                              ),
                            if (x.status == 'posted')
                              IconButton(
                                tooltip: 'عكس',
                                icon: const Icon(Icons.undo_outlined),
                                onPressed: () => _reverseInvoice(x),
                              ),
                            if (x.journalEntryId != null)
                              IconButton(
                                tooltip: 'عرض القيد JE-${x.journalEntryId}',
                                icon: const Icon(Icons.menu_book_outlined),
                                onPressed: () => context.go(
                                  '/finance/journal-entries/${x.journalEntryId}',
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
        );

  Widget _paymentsTab() => _payments.isEmpty
      ? const ManagementMessage(message: 'لا توجد دفعات لهذا المورد بعد.')
      : ManagementTableShell(
          minWidth: 900,
          child: FinancePaginatedTable(
            minWidth: 900,
            columns: const <DataColumn>[
              DataColumn(label: Text('المرجع')),
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('المبلغ')),
              DataColumn(label: Text('طريقة الدفع')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text('إجراء')),
            ],
            rows: _payments
                .map(
                  (x) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(x.paymentNumber)),
                      DataCell(Text(x.paymentDate)),
                      DataCell(Text(x.amount)),
                      DataCell(Text(x.paymentMethodName)),
                      DataCell(
                        ManagementBadge(
                          label: x.status == 'posted' ? 'مُرحّلة' : 'معكوسة',
                          tone: x.status == 'posted'
                              ? ManagementTone.success
                              : ManagementTone.neutral,
                        ),
                      ),
                      DataCell(
                        x.status == 'posted' && x.journalEntryId == null
                            ? IconButton(
                                tooltip: 'عكس',
                                icon: const Icon(Icons.undo_outlined),
                                onPressed: () => _reversePayment(x),
                              )
                            : x.journalEntryId != null
                            ? IconButton(
                                tooltip: 'عرض القيد JE-${x.journalEntryId}',
                                icon: const Icon(Icons.menu_book_outlined),
                                onPressed: () => context.go(
                                  '/finance/journal-entries/${x.journalEntryId}',
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        );

  Widget _statementTab() => _statement.isEmpty
      ? const ManagementMessage(message: 'لا توجد حركات في كشف الحساب بعد.')
      : ManagementTableShell(
          minWidth: 800,
          child: FinancePaginatedTable(
            minWidth: 800,
            columns: const <DataColumn>[
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('النوع')),
              DataColumn(label: Text('المرجع')),
              DataColumn(label: Text('مدين')),
              DataColumn(label: Text('دائن')),
              DataColumn(label: Text('الرصيد التراكمي')),
            ],
            rows: _statement
                .map(
                  (x) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(x.date)),
                      DataCell(Text(x.type == 'invoice' ? 'فاتورة' : 'دفعة')),
                      DataCell(Text(x.reference)),
                      DataCell(Text(x.debit)),
                      DataCell(Text(x.credit)),
                      DataCell(Text(x.runningBalance)),
                    ],
                  ),
                )
                .toList(),
          ),
        );

  Future<void> _postInvoice(SupplierInvoice invoice) async {
    try {
      await context.read<FinanceSetupCubit>().repository.postSupplierInvoice(
        invoice.id,
        'invoice-post-${invoice.id}-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _reverseInvoice(SupplierInvoice invoice) async {
    final confirmed = await _confirm(
      'عكس الفاتورة',
      'سيتم إنشاء قيد عكسي للفاتورة ${invoice.internalReference}. هذا الإجراء لا يمكن التراجع عنه.',
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<FinanceSetupCubit>().repository.reverseSupplierInvoice(
        invoice.id,
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _reversePayment(SupplierPayment payment) async {
    final confirmed = await _confirm(
      'عكس الدفعة',
      'سيتم إنشاء قيد عكسي واستعادة أرصدة الفواتير المرتبطة بدفعة ${payment.paymentNumber}. هذا الإجراء لا يمكن التراجع عنه.',
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<FinanceSetupCubit>().repository.reverseSupplierPayment(
        payment.id,
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('إلغاء'),
        ),
        AppButton(label: 'تأكيد', onPressed: () => Navigator.pop(d, true)),
      ],
    ),
  );

  Future<void> _newInvoice() async {
    if (_categories.where((x) => x.isActive).isEmpty &&
        _validOtherAccounts.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('تعذر إنشاء فاتورة'),
          content: const Text(
            'أضف فئة مصروفات نشطة واحدة على الأقل من إعدادات المالية أولاً.',
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
    var type = 'expense';
    int? branchId;
    int? categoryId = _categories.where((x) => x.isActive).isNotEmpty
        ? _categories.firstWhere((x) => x.isActive).id
        : null;
    int? debitAccountId = _validOtherAccounts.isNotEmpty
        ? _validOtherAccounts.first.id
        : null;
    final number = TextEditingController();
    final date = ValueNotifier<String>(
      DateTime.now().toIso8601String().substring(0, 10),
    );
    final due = ValueNotifier<String>(
      DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String()
          .substring(0, 10),
    );
    final subtotal = TextEditingController();
    final tax = TextEditingController(text: '0.00');
    final description = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, set) {
          final double total =
              (double.tryParse(subtotal.text.trim()) ?? 0) +
              (double.tryParse(tax.text.trim()) ?? 0);
          return AlertDialog(
            title: const Text('فاتورة مورد جديدة'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<int?>(
                      initialValue: branchId,
                      decoration: const InputDecoration(
                        labelText: 'الفرع (اختياري)',
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem(value: null, child: Text('عام')),
                        ..._branches.map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => set(() => branchId = v),
                    ),
                    TextField(
                      controller: number,
                      decoration: const InputDecoration(
                        labelText: 'رقم فاتورة المورد',
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickDate(date.value);
                        if (picked != null) set(() => date.value = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الفاتورة',
                        ),
                        child: Text(date.value),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickDate(due.value);
                        if (picked != null) set(() => due.value = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الاستحقاق',
                        ),
                        child: Text(due.value),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'نوع الفاتورة',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'expense',
                          child: Text('مصروف'),
                        ),
                        DropdownMenuItem(
                          value: 'inventory',
                          child: Text(
                            'مخزون (التزام محاسبي فقط، لا يُنشئ كمية)',
                          ),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('أخرى')),
                      ],
                      onChanged: (v) => set(() => type = v!),
                    ),
                    if (type == 'expense')
                      DropdownButtonFormField<int?>(
                        initialValue: categoryId,
                        decoration: const InputDecoration(
                          labelText: 'فئة المصروف',
                        ),
                        items: _categories
                            .where((x) => x.isActive)
                            .map(
                              (x) => DropdownMenuItem(
                                value: x.id,
                                child: Text('${x.code} - ${x.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => set(() => categoryId = v),
                      ),
                    if (type == 'other')
                      DropdownButtonFormField<int?>(
                        initialValue: debitAccountId,
                        decoration: const InputDecoration(
                          labelText: 'الحساب المدين',
                        ),
                        items: _validOtherAccounts
                            .map(
                              (x) => DropdownMenuItem(
                                value: x.id,
                                child: Text('${x.code} - ${x.nameAr}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => set(() => debitAccountId = v),
                      ),
                    TextField(
                      controller: subtotal,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => set(() {}),
                      decoration: const InputDecoration(
                        labelText: 'الإجمالي الفرعي',
                      ),
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
                      controller: description,
                      decoration: const InputDecoration(labelText: 'الوصف'),
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
                label: 'حفظ كمسودة',
                onPressed: () async {
                  if (number.text.trim().isEmpty || !_money(subtotal.text)) {
                    set(() => error = 'أدخل رقم فاتورة ومبلغاً صالحاً.');
                    return;
                  }
                  try {
                    await context
                        .read<FinanceSetupCubit>()
                        .repository
                        .saveSupplierInvoice(<String, dynamic>{
                          'supplierId': widget.supplierId,
                          'branchId': branchId,
                          'invoiceNumber': number.text.trim(),
                          'invoiceDate': date.value,
                          'dueDate': due.value,
                          'invoiceType': type,
                          if (type == 'expense')
                            'expenseCategoryId': categoryId,
                          if (type == 'other') 'debitAccountId': debitAccountId,
                          'subtotal': subtotal.text.trim(),
                          'taxAmount': tax.text.trim().isEmpty
                              ? '0.00'
                              : tax.text.trim(),
                          'description': description.text.trim().isEmpty
                              ? null
                              : description.text.trim(),
                          'idempotencyKey':
                              'supplier-invoice-${DateTime.now().microsecondsSinceEpoch}',
                        });
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
    number.dispose();
    subtotal.dispose();
    tax.dispose();
    description.dispose();
    date.dispose();
    due.dispose();
  }

  List<FinancialAccount> get _validOtherAccounts => _accounts
      .where(
        (a) =>
            a.isActive &&
            <String>[
              'expenses',
              'assets',
              'cost_of_sales',
            ].contains(a.accountGroup) &&
            a.code != '1100',
      )
      .toList();

  Future<void> _newPayment() async {
    final open = _openInvoices;
    final activeMethods = _methods.where((x) => x.isActive).toList();
    final activeLocations = _locations.where((x) => x.isActive).toList();
    if (activeMethods.isEmpty || activeLocations.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('تعذر فتح الدفع'),
          content: const Text('لا توجد طريقة دفع أو حساب نقدي/بنكي نشط.'),
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
    final reference = TextEditingController();
    final allocationControllers = <int, TextEditingController>{
      for (final inv in open) inv.id: TextEditingController(),
    };
    String? error;

    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, set) {
          final double allocated = allocationControllers.values.fold(
            0,
            (sum, c) => sum + (double.tryParse(c.text.trim()) ?? 0),
          );
          return AlertDialog(
            title: const Text('دفعة مورد جديدة'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<int>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                      ),
                      items: activeMethods
                          .map(
                            (x) => DropdownMenuItem(
                              value: x.id,
                              child: Text(x.name),
                            ),
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
                            (x) => DropdownMenuItem(
                              value: x.id,
                              child: Text(x.name),
                            ),
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
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الدفع',
                        ),
                        child: Text(date.value),
                      ),
                    ),
                    TextField(
                      controller: reference,
                      decoration: const InputDecoration(
                        labelText: 'مرجع خارجي (اختياري)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'توزيع الدفعة على الفواتير المفتوحة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...open.map(
                      (inv) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${inv.internalReference} — متبقي ${inv.remainingAmount}',
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: allocationControllers[inv.id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => set(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'تخصيص',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Text(
                      'إجمالي الدفعة (يُحسب من التخصيصات): ${allocated.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                label: 'ترحيل الدفعة',
                onPressed: () async {
                  final allocations = allocationControllers.entries
                      .where(
                        (e) => (double.tryParse(e.value.text.trim()) ?? 0) > 0,
                      )
                      .map(
                        (e) => <String, dynamic>{
                          'invoiceId': e.key,
                          'amount': e.value.text.trim(),
                        },
                      )
                      .toList();
                  if (allocations.isEmpty || allocated <= 0) {
                    set(() => error = 'خصص مبلغاً لفاتورة واحدة على الأقل.');
                    return;
                  }
                  try {
                    await context
                        .read<FinanceSetupCubit>()
                        .repository
                        .paySupplierInvoices(<String, dynamic>{
                          'supplierId': widget.supplierId,
                          'paymentDate': date.value,
                          'amount': allocated.toStringAsFixed(2),
                          'paymentMethodId': method,
                          'financialLocationId': location,
                          'externalReference': reference.text.trim().isEmpty
                              ? null
                              : reference.text.trim(),
                          'idempotencyKey':
                              'supplier-payment-${DateTime.now().microsecondsSinceEpoch}',
                          'allocations': allocations,
                        });
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
    reference.dispose();
    date.dispose();
    for (final c in allocationControllers.values) {
      c.dispose();
    }
  }

  Future<String?> _pickDate(String? initial) async {
    final DateTime seed = initial != null && initial.isNotEmpty
        ? DateTime.tryParse(initial) ?? DateTime.now()
        : DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    return picked?.toIso8601String().substring(0, 10);
  }

  bool _money(String value) =>
      RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value.trim());
}
