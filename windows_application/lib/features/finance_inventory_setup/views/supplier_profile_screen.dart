import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../pos/models/branch.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_journal_drawer.dart';
import '../widgets/finance_shell.dart';
import 'suppliers_screen.dart' show SupplierActiveBadge;

/// Supplier Profile (`/finance/suppliers/:id`) — Phase 6.
/// Invoice/payment lifecycle and every balance shown here are computed by
/// the backend (`SupplierPayableQueryService`); this screen never derives
/// AP totals itself. `allowedActions` on each record — not client-derived
/// status checks — decides which buttons render, matching the Phase 5
/// Expenses precedent.
class SupplierProfileScreen extends StatefulWidget {
  const SupplierProfileScreen({
    super.key,
    required this.supplierId,
    this.initialTab = 0,
    this.openInvoiceId,
    this.openPaymentId,
  });
  final int supplierId;
  final int initialTab;
  final int? openInvoiceId;
  final int? openPaymentId;

  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 2),
  );
  Supplier? _supplier;
  List<SupplierInvoice> _invoices = const <SupplierInvoice>[];
  List<SupplierPayment> _payments = const <SupplierPayment>[];
  List<SupplierStatementLine> _statement = const <SupplierStatementLine>[];
  bool _loading = true;
  Object? _error;
  bool _deepLinkOpened = false;

  FinanceSetupRepository get _repository =>
      context.read<FinanceSetupCubit>().repository;

  @override
  void initState() {
    super.initState();
    _load();
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
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getSupplier(widget.supplierId),
        _repository.getSupplierInvoices(
          filters: <String, dynamic>{'supplierId': widget.supplierId},
        ),
        _repository.getSupplierPayments(
          filters: <String, dynamic>{'supplierId': widget.supplierId},
        ),
        _repository.getSupplierStatement(widget.supplierId),
      ]);
      if (!mounted) return;
      setState(() {
        _supplier = results[0] as Supplier;
        _invoices = results[1] as List<SupplierInvoice>;
        _payments = results[2] as List<SupplierPayment>;
        _statement = results[3] as List<SupplierStatementLine>;
        _loading = false;
      });
      await _maybeOpenDeepLink();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _maybeOpenDeepLink() async {
    if (_deepLinkOpened) return;
    _deepLinkOpened = true;
    if (widget.openInvoiceId != null) {
      final SupplierInvoice? invoice = _invoices
          .where((SupplierInvoice x) => x.id == widget.openInvoiceId)
          .firstOrNull;
      if (invoice != null) await _openInvoiceDetail(invoice);
    } else if (widget.openPaymentId != null) {
      final SupplierPayment? payment = _payments
          .where((SupplierPayment x) => x.id == widget.openPaymentId)
          .firstOrNull;
      if (payment != null) await _openPaymentDetail(payment);
    }
  }

  List<SupplierInvoice> get _eligibleForPayment => _invoices
      .where(
        (SupplierInvoice x) =>
            (x.status == 'posted' || x.status == 'partially_paid') &&
            _amount(x.remainingAmount) > 0,
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'الموردون والمستحقات',
        title: 'الموردون والمستحقات',
        subtitle: 'ملف المورد وحركاته المالية',
        showContext: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'العودة إلى الموردين',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => context.go(AppRoutes.financeSuppliers),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_loading) {
      return const FinanceLoadingState(label: 'جارٍ تحميل ملف المورد…');
    }
    if (_error != null) {
      return FinanceErrorState(message: 'تعذّر تحميل ملف المورد. $_error', onRetry: _load);
    }
    final Supplier? supplier = _supplier;
    if (supplier == null) {
      return const FinanceErrorState(message: 'تعذّر إيجاد المورد المطلوب.');
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FinanceEntityHeader(
            title: supplier.name,
            reference: '${supplier.supplierNumber} · مهلة السداد ${supplier.paymentTermsDays} يوم',
            actions: <Widget>[
              SupplierActiveBadge(active: supplier.isActive),
              const SizedBox(width: FinanceSpace.sm),
              OutlinedButton(
                onPressed: () => _tabs.animateTo(2),
                child: const Text('كشف حساب المورد'),
              ),
              const SizedBox(width: FinanceSpace.sm),
              OutlinedButton(
                onPressed: () => _openInvoiceForm(),
                child: const Text('فاتورة جديدة'),
              ),
              const SizedBox(width: FinanceSpace.sm),
              ElevatedButton(
                onPressed: _eligibleForPayment.isEmpty ? null : _openPaymentForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinanceColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('دفعة جديدة'),
              ),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          FinanceKpiGrid(
            items: <FinanceKpiData>[
              FinanceKpiData(
                label: 'الرصيد المستحق',
                value: _money(supplier.outstandingBalance),
                icon: Icons.account_balance_wallet_outlined,
              ),
              FinanceKpiData(
                label: 'إجمالي الفواتير',
                value: _money(supplier.totalInvoiced ?? '0.00'),
                icon: Icons.description_outlined,
              ),
              FinanceKpiData(
                label: 'إجمالي المدفوع',
                value: _money(supplier.totalPaid ?? '0.00'),
                icon: Icons.check_circle_outline,
              ),
              FinanceKpiData(
                label: 'المتأخر',
                value: _money(supplier.overdueBalance),
                icon: Icons.warning_amber_outlined,
                tone: FinanceTone.danger,
              ),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: FinanceColors.primary,
            tabs: const <Widget>[
              Tab(text: 'الفواتير'),
              Tab(text: 'الدفعات'),
              Tab(text: 'كشف الحساب'),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          SizedBox(
            height: 560,
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[_invoicesTab(), _paymentsTab(), _statementTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoicesTab() {
    if (_invoices.isEmpty) {
      return const FinanceEmptyState(message: 'لا توجد فواتير لهذا المورد بعد');
    }
    return SingleChildScrollView(
      child: FinanceTable(
        minWidth: 1100,
        headers: const <String>['المرجع', 'التاريخ', 'الاستحقاق', 'الإجمالي', 'المتبقي', 'الحالة', ''],
        onRowTap: (int index) => _openInvoiceDetail(_invoices[index]),
        rows: _invoices.map((SupplierInvoice x) {
          return <Widget>[
            FinanceReference(reference: x.internalReference),
            Text(x.invoiceDate, style: FinanceText.body),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: FinanceSpace.xs,
              runSpacing: 2,
              children: <Widget>[
                Text(x.dueDate, style: FinanceText.body),
                if (x.isOverdue) const _OverdueBadge(),
              ],
            ),
            FinanceAmount(value: x.totalAmount),
            FinanceAmount(value: x.remainingAmount),
            FinanceStatusBadge(status: x.status),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: x.journalEntryId != null
                  ? IconButton(
                      tooltip: 'عرض القيد',
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      onPressed: () => _openJournalDrawer(x.journalEntryId!),
                    )
                  : const SizedBox.shrink(),
            ),
          ];
        }).toList(),
      ),
    );
  }

  Widget _paymentsTab() {
    if (_payments.isEmpty) {
      return const FinanceEmptyState(message: 'لا توجد دفعات لهذا المورد بعد');
    }
    return SingleChildScrollView(
      child: FinanceTable(
        minWidth: 1000,
        headers: const <String>['المرجع', 'التاريخ', 'المبلغ', 'طريقة الدفع', 'الحالة', ''],
        onRowTap: (int index) => _openPaymentDetail(_payments[index]),
        rows: _payments.map((SupplierPayment x) {
          return <Widget>[
            FinanceReference(reference: x.paymentNumber),
            Text(x.paymentDate, style: FinanceText.body),
            FinanceAmount(value: x.amount),
            Text(x.paymentMethodName, style: FinanceText.body),
            FinanceStatusBadge(status: x.status),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: x.journalEntryId != null
                  ? IconButton(
                      tooltip: 'عرض القيد',
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      onPressed: () => _openJournalDrawer(x.journalEntryId!),
                    )
                  : const SizedBox.shrink(),
            ),
          ];
        }).toList(),
      ),
    );
  }

  Widget _statementTab() {
    if (_statement.isEmpty) {
      return const FinanceEmptyState(message: 'لا توجد حركات في كشف الحساب بعد');
    }
    final double totalInvoices = _statement.fold<double>(
      0,
      (double sum, SupplierStatementLine l) => sum + _amount(l.credit),
    );
    final double totalPayments = _statement.fold<double>(
      0,
      (double sum, SupplierStatementLine l) => sum + _amount(l.debit),
    );
    final String closing = _statement.last.runningBalance;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FinanceKpiGrid(
            items: <FinanceKpiData>[
              const FinanceKpiData(label: 'الرصيد الافتتاحي', value: '0.00'),
              FinanceKpiData(label: 'الرصيد الختامي', value: _money(closing)),
              FinanceKpiData(label: 'إجمالي الفواتير', value: _money(totalInvoices)),
              FinanceKpiData(label: 'إجمالي المدفوعات', value: _money(totalPayments)),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          FinanceTable(
            minWidth: 900,
            headers: const <String>['التاريخ', 'النوع', 'المرجع', 'فاتورة', 'دفعة', 'الرصيد التراكمي'],
            onRowTap: (int index) => _openStatementLine(_statement[index]),
            rows: _statement.map((SupplierStatementLine x) {
              return <Widget>[
                Text(x.date, style: FinanceText.body),
                Text(x.type == 'invoice' ? 'فاتورة' : 'دفعة', style: FinanceText.body),
                FinanceReference(reference: x.reference),
                Text(x.credit == '0.00' ? '—' : x.credit, style: FinanceText.body),
                Text(x.debit == '0.00' ? '—' : x.debit, style: FinanceText.body),
                Text(x.runningBalance, style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _openStatementLine(SupplierStatementLine line) async {
    if (line.type == 'invoice') {
      final SupplierInvoice? invoice = _invoices
          .where((SupplierInvoice x) => x.id == line.id)
          .firstOrNull;
      if (invoice != null) {
        await _openInvoiceDetail(invoice);
      } else {
        await _openInvoiceDetail(await _repository.getSupplierInvoice(line.id));
      }
    } else {
      final SupplierPayment? payment = _payments
          .where((SupplierPayment x) => x.id == line.id)
          .firstOrNull;
      if (payment != null) {
        await _openPaymentDetail(payment);
      } else {
        await _openPaymentDetail(await _repository.getSupplierPayment(line.id));
      }
    }
  }

  void _openJournalDrawer(int journalEntryId) {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'إغلاق',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (BuildContext dialogContext, _, _) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FinanceJournalDrawer(
          child: FinanceJournalDrawerBody(
            loader: () => _repository.getFinanceMap('finance/transactions/$journalEntryId'),
            onNavigate: (String path) {
              Navigator.of(dialogContext).pop();
              context.go(path);
            },
          ),
        ),
      ),
      transitionBuilder: (BuildContext context, Animation<double> animation, _, Widget child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
    );
  }

  Future<void> _openInvoiceForm([SupplierInvoice? current]) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _InvoiceFormDialog(
        supplierId: widget.supplierId,
        current: current,
        repository: _repository,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openInvoiceDetail(SupplierInvoice invoice) async {
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext dialog) => _InvoiceDetailDialog(invoice: invoice),
    );
    if (action == 'edit') {
      await _openInvoiceForm(invoice);
      return;
    }
    if (action == 'post') {
      try {
        await _repository.postSupplierInvoice(
          invoice.id,
          'invoice-post-${invoice.id}-${DateTime.now().microsecondsSinceEpoch}',
        );
        await _load();
      } catch (error) {
        if (mounted) _showError('تعذّر ترحيل الفاتورة: $error');
      }
      return;
    }
    if (action == 'reverse') {
      final bool? confirmed = await _confirm(
        'عكس الفاتورة',
        'سيتم إنشاء قيد عكسي للفاتورة ${invoice.internalReference}. هذا الإجراء لا يمكن التراجع عنه.',
      );
      if (confirmed == true) {
        try {
          await _repository.reverseSupplierInvoice(invoice.id);
          await _load();
        } catch (error) {
          if (mounted) _showError('تعذّر عكس الفاتورة: $error');
        }
      }
      return;
    }
    if (action == 'journal' && invoice.journalEntryId != null) {
      _openJournalDrawer(invoice.journalEntryId!);
    }
  }

  Future<void> _openPaymentDetail(SupplierPayment payment) async {
    final Object? action = await showDialog<Object>(
      context: context,
      builder: (BuildContext dialog) => _PaymentDetailDialog(payment: payment, invoices: _invoices),
    );
    if (action == 'reverse') {
      final bool? confirmed = await _confirm(
        'عكس الدفعة',
        'سيتم إنشاء قيد عكسي واستعادة أرصدة الفواتير المرتبطة بدفعة ${payment.paymentNumber}. هذا الإجراء لا يمكن التراجع عنه.',
      );
      if (confirmed == true) {
        try {
          await _repository.reverseSupplierPayment(payment.id);
          await _load();
        } catch (error) {
          if (mounted) _showError('تعذّر عكس الدفعة: $error');
        }
      }
      return;
    }
    if (action == 'journal' && payment.journalEntryId != null) {
      _openJournalDrawer(payment.journalEntryId!);
      return;
    }
    if (action is SupplierInvoice) {
      await _openInvoiceDetail(action);
    }
  }

  Future<void> _openPaymentForm() async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _PaymentFormDialog(
        supplierId: widget.supplierId,
        eligibleInvoices: _eligibleForPayment,
        repository: _repository,
      ),
    );
    if (saved == true) await _load();
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialog, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: FinanceColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _InvoiceFormDialog extends StatefulWidget {
  const _InvoiceFormDialog({required this.supplierId, required this.current, required this.repository});
  final int supplierId;
  final SupplierInvoice? current;
  final FinanceSetupRepository repository;

  @override
  State<_InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends State<_InvoiceFormDialog> {
  bool _loadingOptions = true;
  List<ExpenseCategory> _categories = const <ExpenseCategory>[];
  List<FinancialAccount> _accounts = const <FinancialAccount>[];
  List<Branch> _branches = const <Branch>[];

  late String _type;
  int? _branchId;
  int? _categoryId;
  int? _debitAccountId;
  late final TextEditingController _number;
  late String _invoiceDate;
  late String _dueDate;
  late final TextEditingController _subtotal;
  late final TextEditingController _tax;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  String? _error;
  bool _submitting = false;

  bool get _editingLocked => widget.current != null && widget.current!.status != 'draft';

  @override
  void initState() {
    super.initState();
    final SupplierInvoice? current = widget.current;
    _type = current?.invoiceType ?? 'expense';
    _branchId = current?.branchId;
    _categoryId = current?.expenseCategoryId;
    _debitAccountId = current?.debitAccountId;
    _number = TextEditingController(text: current?.invoiceNumber);
    _invoiceDate = current?.invoiceDate ?? DateTime.now().toIso8601String().substring(0, 10);
    _dueDate = current?.dueDate ??
        DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);
    _subtotal = TextEditingController(text: current?.subtotal);
    _tax = TextEditingController(text: current?.taxAmount ?? '0.00');
    _description = TextEditingController(text: current?.description);
    _notes = TextEditingController(text: current?.notes);
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.repository.getExpenseCategories(),
        widget.repository.getAccounts(status: 'active'),
        widget.repository.getBranches(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = (results[0] as List<ExpenseCategory>)
            .where((ExpenseCategory c) => c.isActive)
            .toList(growable: false);
        _accounts = (results[1] as List<FinancialAccount>)
            .where(
              (FinancialAccount a) =>
                  a.isActive &&
                  <String>['expenses', 'assets', 'cost_of_sales'].contains(a.accountGroup) &&
                  a.code != '1100',
            )
            .toList(growable: false);
        _branches = results[2] as List<Branch>;
        _categoryId ??= _categories.isEmpty ? null : _categories.first.id;
        _debitAccountId ??= _accounts.isEmpty ? null : _accounts.first.id;
        _loadingOptions = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loadingOptions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _subtotal.dispose();
    _tax.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDue) async {
    final DateTime seed = DateTime.tryParse(isDue ? _dueDate : _invoiceDate) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      final String value = picked.toIso8601String().substring(0, 10);
      if (isDue) {
        _dueDate = value;
      } else {
        _invoiceDate = value;
      }
    });
  }

  Future<void> _submit() async {
    if (_number.text.trim().isEmpty || !_isMoney(_subtotal.text)) {
      setState(() => _error = 'أدخل رقم فاتورة ومبلغاً فرعياً صالحاً.');
      return;
    }
    if (_type == 'expense' && _categoryId == null) {
      setState(() => _error = 'اختر فئة مصروف.');
      return;
    }
    if (_type == 'other' && _debitAccountId == null) {
      setState(() => _error = 'اختر الحساب المدين.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.saveSupplierInvoice(<String, dynamic>{
        'supplierId': widget.supplierId,
        'branchId': _branchId,
        'invoiceNumber': _number.text.trim(),
        'invoiceDate': _invoiceDate,
        'dueDate': _dueDate,
        'invoiceType': _type,
        if (_type == 'expense') 'expenseCategoryId': _categoryId,
        if (_type == 'other') 'debitAccountId': _debitAccountId,
        'subtotal': _subtotal.text.trim(),
        'taxAmount': _tax.text.trim().isEmpty ? '0.00' : _tax.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        if (widget.current == null)
          'idempotencyKey': 'supplier-invoice-${DateTime.now().microsecondsSinceEpoch}',
      }, id: widget.current?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  bool _isMoney(String value) => RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value.trim());

  @override
  Widget build(BuildContext context) {
    if (_editingLocked) {
      return FinanceDialogShell(
        title: 'فاتورة ${widget.current!.internalReference}',
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
        child: const FinanceAlertBanner(
          message: 'الفاتورة مُرحّلة ولا يمكن تعديلها. استخدم إجراء العكس إن لزم.',
          tone: FinanceTone.warning,
        ),
      );
    }
    final double total = (double.tryParse(_subtotal.text.trim()) ?? 0) +
        (double.tryParse(_tax.text.trim()) ?? 0);
    return FinanceDialogShell(
      title: widget.current == null ? 'فاتورة مورد جديدة' : 'تعديل فاتورة ${widget.current!.internalReference}',
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submitting || _loadingOptions ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('حفظ كمسودة'),
        ),
      ],
      child: _loadingOptions
          ? const SizedBox(height: 160, child: FinanceLoadingState(label: 'جارٍ تحميل الخيارات…'))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DropdownButtonFormField<int?>(
                    initialValue: _branchId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الفرع (اختياري)'),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(value: null, child: Text('عام')),
                      ..._branches.map(
                        (Branch b) => DropdownMenuItem<int?>(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (int? v) => setState(() => _branchId = v),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  TextField(
                    controller: _number,
                    decoration: const InputDecoration(labelText: 'رقم فاتورة المورد'),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  InkWell(
                    onTap: () => _pickDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'تاريخ الفاتورة'),
                      child: Text(_invoiceDate),
                    ),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'تاريخ الاستحقاق'),
                      child: Text(_dueDate),
                    ),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'نوع الفاتورة'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'expense', child: Text('مصروف')),
                      DropdownMenuItem<String>(
                        value: 'inventory',
                        child: Text(
                          'مخزون (التزام محاسبي فقط، لا يُنشئ كمية)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<String>(value: 'other', child: Text('أخرى')),
                    ],
                    onChanged: (String? v) => setState(() => _type = v!),
                  ),
                  if (_type == 'expense') ...<Widget>[
                    const SizedBox(height: FinanceSpace.md),
                    DropdownButtonFormField<int?>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'فئة المصروف'),
                      items: _categories
                          .map(
                            (ExpenseCategory c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text('${c.code} - ${c.name}', overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) => setState(() => _categoryId = v),
                    ),
                  ],
                  if (_type == 'other') ...<Widget>[
                    const SizedBox(height: FinanceSpace.md),
                    DropdownButtonFormField<int?>(
                      initialValue: _debitAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الحساب المدين'),
                      items: _accounts
                          .map(
                            (FinancialAccount a) => DropdownMenuItem<int?>(
                              value: a.id,
                              child: Text('${a.code} - ${a.nameAr}', overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) => setState(() => _debitAccountId = v),
                    ),
                  ],
                  const SizedBox(height: FinanceSpace.md),
                  TextField(
                    controller: _subtotal,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'الإجمالي الفرعي'),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  TextField(
                    controller: _tax,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'الضريبة'),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'الإجمالي'),
                    child: Text(total.toStringAsFixed(2)),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                  ),
                  const SizedBox(height: FinanceSpace.md),
                  TextField(controller: _notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: FinanceSpace.sm),
                    Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _InvoiceDetailDialog extends StatelessWidget {
  const _InvoiceDetailDialog({required this.invoice});
  final SupplierInvoice invoice;

  @override
  Widget build(BuildContext context) => FinanceDialogShell(
    title: 'فاتورة مورد',
    actions: <Widget>[
      if (invoice.journalEntryId != null)
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'journal'),
          child: const Text('عرض القيد'),
        ),
      if (invoice.allowedActions.contains('edit'))
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'edit'),
          child: const Text('تعديل'),
        ),
      if (invoice.allowedActions.contains('post'))
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'post'),
          style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
          child: const Text('ترحيل'),
        ),
      if (invoice.allowedActions.contains('reverse'))
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'reverse'),
          style: OutlinedButton.styleFrom(foregroundColor: FinanceColors.danger),
          child: const Text('عكس'),
        ),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
    ],
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FinanceEntityHeader(
            title: invoice.internalReference,
            reference: invoice.invoiceNumber,
            status: invoice.status,
          ),
          const SizedBox(height: FinanceSpace.md),
          FinanceInfoGrid(
            items: <FinanceInfoItem>[
              FinanceInfoItem('المورد', invoice.supplierName),
              FinanceInfoItem('الفرع', invoice.branchName ?? 'عام'),
              FinanceInfoItem('تاريخ الفاتورة', invoice.invoiceDate),
              FinanceInfoItem('تاريخ الاستحقاق', invoice.dueDate),
              FinanceInfoItem(
                'الحساب المدين',
                invoice.debitAccountCode == null
                    ? '—'
                    : '${invoice.debitAccountCode} — ${invoice.debitAccountName ?? ''}',
              ),
              if (invoice.expenseCategoryName != null)
                FinanceInfoItem('فئة المصروف', invoice.expenseCategoryName!),
              FinanceInfoItem('الإجمالي الفرعي', invoice.subtotal),
              FinanceInfoItem('الضريبة', invoice.taxAmount),
              FinanceInfoItem('الإجمالي', invoice.totalAmount),
              FinanceInfoItem('المتبقي', invoice.remainingAmount),
              if (invoice.description != null) FinanceInfoItem('الوصف', invoice.description!),
              if (invoice.notes != null) FinanceInfoItem('ملاحظات', invoice.notes!),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PaymentDetailDialog extends StatelessWidget {
  const _PaymentDetailDialog({required this.payment, required this.invoices});
  final SupplierPayment payment;
  final List<SupplierInvoice> invoices;

  @override
  Widget build(BuildContext context) => FinanceDialogShell(
    title: 'دفعة مورد',
    actions: <Widget>[
      if (payment.journalEntryId != null)
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'journal'),
          child: const Text('عرض القيد'),
        ),
      if (payment.allowedActions.contains('reverse'))
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'reverse'),
          style: OutlinedButton.styleFrom(foregroundColor: FinanceColors.danger),
          child: const Text('عكس'),
        ),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
    ],
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FinanceEntityHeader(
            title: payment.paymentNumber,
            reference: payment.supplierName,
            status: payment.status,
          ),
          const SizedBox(height: FinanceSpace.md),
          FinanceInfoGrid(
            items: <FinanceInfoItem>[
              FinanceInfoItem('تاريخ الدفع', payment.paymentDate),
              FinanceInfoItem('المبلغ', payment.amount),
              FinanceInfoItem('طريقة الدفع', payment.paymentMethodName),
              FinanceInfoItem('الحساب النقدي/البنكي', payment.financialLocationName),
              if (payment.externalReference != null)
                FinanceInfoItem('مرجع خارجي', payment.externalReference!),
              if (payment.notes != null) FinanceInfoItem('ملاحظات', payment.notes!),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          Text('توزيع الدفعة على الفواتير', style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: FinanceSpace.sm),
          FinanceTable(
            minWidth: 400,
            headers: const <String>['الفاتورة', 'المبلغ'],
            onRowTap: (int index) {
              final PaymentAllocationLine line = payment.allocations[index];
              final SupplierInvoice? invoice = invoices
                  .where((SupplierInvoice x) => x.id == line.invoiceId)
                  .firstOrNull;
              Navigator.pop(context, invoice);
            },
            rows: payment.allocations
                .map(
                  (PaymentAllocationLine line) => <Widget>[
                    FinanceReference(reference: line.invoiceReference),
                    FinanceAmount(value: line.amount),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}

class _PaymentFormDialog extends StatefulWidget {
  const _PaymentFormDialog({
    required this.supplierId,
    required this.eligibleInvoices,
    required this.repository,
  });
  final int supplierId;
  final List<SupplierInvoice> eligibleInvoices;
  final FinanceSetupRepository repository;

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  bool _loadingOptions = true;
  List<PaymentMethodSetting> _methods = const <PaymentMethodSetting>[];
  List<FinancialLocation> _locations = const <FinancialLocation>[];
  int? _methodId;
  int? _locationId;
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  late final Map<int, TextEditingController> _allocations = <int, TextEditingController>{
    for (final SupplierInvoice inv in widget.eligibleInvoices) inv.id: TextEditingController(),
  };
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.repository.getPaymentMethods(),
        widget.repository.getFinancialLocations('cash'),
        widget.repository.getFinancialLocations('bank'),
      ]);
      if (!mounted) return;
      setState(() {
        _methods = (results[0] as List<PaymentMethodSetting>)
            .where((PaymentMethodSetting m) => m.isActive)
            .toList(growable: false);
        _locations = <FinancialLocation>[
          ...results[1] as List<FinancialLocation>,
          ...results[2] as List<FinancialLocation>,
        ].where((FinancialLocation l) => l.isActive).toList(growable: false);
        _methodId = _methods.isEmpty ? null : _methods.first.id;
        _locationId = _locations.isEmpty ? null : _locations.first.id;
        _loadingOptions = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loadingOptions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final TextEditingController c in _allocations.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _paymentAmount => double.tryParse(_amount.text.trim()) ?? 0;
  double get _allocatedAmount => _allocations.values.fold<double>(
    0,
    (double sum, TextEditingController c) => sum + (double.tryParse(c.text.trim()) ?? 0),
  );
  double get _remainingUnallocated => _paymentAmount - _allocatedAmount;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked.toIso8601String().substring(0, 10));
  }

  Future<void> _submit() async {
    if (_methodId == null || _locationId == null) {
      setState(() => _error = 'اختر طريقة دفع وحساباً نقدياً أو بنكياً نشطاً.');
      return;
    }
    if (_paymentAmount <= 0) {
      setState(() => _error = 'أدخل مبلغ دفعة صالحاً أكبر من صفر.');
      return;
    }
    final List<MapEntry<int, double>> allocations = _allocations.entries
        .map((MapEntry<int, TextEditingController> e) => MapEntry<int, double>(
              e.key,
              double.tryParse(e.value.text.trim()) ?? 0,
            ))
        .where((MapEntry<int, double> e) => e.value > 0)
        .toList();
    if (allocations.isEmpty) {
      setState(() => _error = 'خصص مبلغاً لفاتورة واحدة على الأقل.');
      return;
    }
    for (final MapEntry<int, double> a in allocations) {
      final SupplierInvoice invoice = widget.eligibleInvoices.firstWhere((SupplierInvoice x) => x.id == a.key);
      if (a.value > _amount2(invoice.remainingAmount) + 0.0001) {
        setState(() => _error = 'تخصيص ${invoice.internalReference} يتجاوز المتبقي عليها.');
        return;
      }
    }
    if ((_remainingUnallocated).abs() > 0.0001) {
      setState(() => _error = 'يجب أن يساوي إجمالي التخصيصات مبلغ الدفعة تماماً. المتبقي غير المخصص: ${_remainingUnallocated.toStringAsFixed(2)}');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.paySupplierInvoices(<String, dynamic>{
        'supplierId': widget.supplierId,
        'paymentDate': _date,
        'amount': _paymentAmount.toStringAsFixed(2),
        'paymentMethodId': _methodId,
        'financialLocationId': _locationId,
        'externalReference': _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'idempotencyKey': 'supplier-payment-${DateTime.now().microsecondsSinceEpoch}',
        'allocations': allocations
            .map((MapEntry<int, double> a) => <String, dynamic>{
                  'invoiceId': a.key,
                  'amount': a.value.toStringAsFixed(2),
                })
            .toList(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  double _amount2(String v) => double.tryParse(v.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final FinancialLocation? location =
        _locationId == null ? null : _locations.where((FinancialLocation l) => l.id == _locationId).firstOrNull;
    return FinanceDialogShell(
      title: 'دفعة مورد جديدة',
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submitting || _loadingOptions ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('ترحيل الدفعة'),
        ),
      ],
      child: _loadingOptions
          ? const SizedBox(height: 160, child: FinanceLoadingState(label: 'جارٍ تحميل خيارات الدفع…'))
          : (_methods.isEmpty || _locations.isEmpty)
          ? const FinanceAlertBanner(
              message: 'لا توجد طريقة دفع أو حساب نقدي/بنكي نشط. أضف واحداً من إعدادات المالية أولاً.',
              tone: FinanceTone.warning,
            )
          : SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<int>(
                      initialValue: _methodId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                      items: _methods
                          .map(
                            (PaymentMethodSetting m) => DropdownMenuItem<int>(
                              value: m.id,
                              child: Text(m.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) => setState(() => _methodId = v),
                    ),
                    const SizedBox(height: FinanceSpace.md),
                    DropdownButtonFormField<int>(
                      initialValue: _locationId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الحساب النقدي/البنكي (المصدر)'),
                      items: _locations
                          .map(
                            (FinancialLocation l) => DropdownMenuItem<int>(
                              value: l.id,
                              child: Text(l.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (int? v) => setState(() => _locationId = v),
                    ),
                    const SizedBox(height: FinanceSpace.md),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'تاريخ الدفع'),
                        child: Text(_date),
                      ),
                    ),
                    const SizedBox(height: FinanceSpace.md),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'مبلغ الدفعة'),
                    ),
                    const SizedBox(height: FinanceSpace.md),
                    TextField(
                      controller: _reference,
                      decoration: const InputDecoration(labelText: 'مرجع خارجي (اختياري)'),
                    ),
                    const SizedBox(height: FinanceSpace.md),
                    TextField(controller: _notes, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
                    const SizedBox(height: FinanceSpace.lg),
                    Text('توزيع الدفعة على الفواتير المفتوحة', style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: FinanceSpace.sm),
                    ...widget.eligibleInvoices.map(
                      (SupplierInvoice inv) => Padding(
                        padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${inv.internalReference} — متبقي ${inv.remainingAmount}',
                                style: FinanceText.body,
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _allocations[inv.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(labelText: 'تخصيص'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    _AllocationSummaryRow(label: 'مبلغ الدفعة', value: _paymentAmount),
                    _AllocationSummaryRow(label: 'المبلغ المخصص', value: _allocatedAmount),
                    _AllocationSummaryRow(
                      label: 'المتبقي غير المخصص',
                      value: _remainingUnallocated,
                      danger: _remainingUnallocated.abs() > 0.0001,
                    ),
                    if (location != null && _paymentAmount > 0) ...<Widget>[
                      const SizedBox(height: FinanceSpace.lg),
                      FinanceAccountImpactPreview(
                        toLabel: 'حسابات الموردين الدائنة',
                        fromLabel: location.name,
                        amount: _paymentAmount.toStringAsFixed(2),
                      ),
                    ],
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: FinanceSpace.sm),
                      Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// `FinanceStatusBadge`'s `overdue` case is grouped with rejected/cancelled
/// and renders "مرفوض" (rejected) — the wrong label for an overdue-but-open
/// invoice. This renders the dedicated "متأخر" pill instead.
class _OverdueBadge extends StatelessWidget {
  const _OverdueBadge();
  @override
  Widget build(BuildContext context) {
    final colors = financeTone(FinanceTone.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.pill),
      ),
      child: Text(
        'متأخر',
        style: FinanceText.small.copyWith(color: colors.foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AllocationSummaryRow extends StatelessWidget {
  const _AllocationSummaryRow({required this.label, required this.value, this.danger = false});
  final String label;
  final double value;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: FinanceText.body),
        Text(
          value.toStringAsFixed(2),
          style: FinanceText.body.copyWith(
            fontWeight: FontWeight.w700,
            color: danger ? FinanceColors.danger : FinanceColors.ink,
          ),
        ),
      ],
    ),
  );
}

double _amount(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
String _money(dynamic value) => _amount(value).toStringAsFixed(2);
