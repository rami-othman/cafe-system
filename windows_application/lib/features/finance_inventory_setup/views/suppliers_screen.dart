import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_shell.dart';

/// Canonical Suppliers & Accounts Payable list (`/finance/suppliers`).
/// Laravel supplies every balance, overdue amount, and allowed-action list;
/// this widget only presents that already-authorized payload — it never
/// derives a payable balance itself. Suppliers are tenant-wide master data
/// (no branch column), and the list endpoint supports no date/branch filter,
/// so — unlike Transactions/Expenses — this screen intentionally shows no
/// global period/branch context bar rather than a decorative one with
/// nothing to wire it to.
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String? _status;
  String _search = '';
  int _page = 1;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int _requestId = 0;
  FinancePage<Supplier>? _pageData;
  Object? _error;
  bool _loading = false;
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeResolveDeepLink();
  }

  /// Journal-drawer "عرض المصدر" for a supplier invoice/payment lands here
  /// (see FinanceSourceNavigation) because the source payload only carries
  /// the invoice/payment id, not its supplier. Resolve the record once to
  /// find its supplier, then hand off to the Profile screen to open it.
  Future<void> _maybeResolveDeepLink() async {
    if (_deepLinkHandled || GoRouter.maybeOf(context) == null) return;
    final Map<String, String> params = GoRouterState.of(context).uri.queryParameters;
    final String? invoiceId = params['invoiceId'];
    final String? paymentId = params['paymentId'];
    if (invoiceId == null && paymentId == null) return;
    _deepLinkHandled = true;
    try {
      if (invoiceId != null) {
        final SupplierInvoice invoice = await _repository.getSupplierInvoice(
          int.parse(invoiceId),
        );
        if (!mounted) return;
        context.go(
          '${AppRoutes.financeSuppliers}/${invoice.supplierId}?openInvoice=$invoiceId',
        );
      } else if (paymentId != null) {
        final SupplierPayment payment = await _repository.getSupplierPayment(
          int.parse(paymentId),
        );
        if (!mounted) return;
        context.go(
          '${AppRoutes.financeSuppliers}/${payment.supplierId}?openPayment=$paymentId',
        );
      }
    } catch (_) {
      // Source record no longer resolvable (deleted/inaccessible); stay on the list.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  FinanceSetupRepository get _repository =>
      context.read<FinanceSetupCubit>().repository;

  Map<String, dynamic> get _parameters => <String, dynamic>{
    if (_status != null) 'status': _status,
    if (_search.isNotEmpty) 'search': _search,
    'page': _page,
    'perPage': 10,
  };

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final FinancePage<Map<String, dynamic>> raw = await _repository
          .getFinancePage('finance/suppliers', queryParameters: _parameters);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _pageData = FinancePage<Supplier>(
          items: raw.items.map(Supplier.fromJson).toList(growable: false),
          meta: raw.meta,
        );
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _applyStatus(String? status) {
    setState(() {
      _status = status;
      _page = 1;
    });
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim();
        _page = 1;
      });
      _load();
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _status = null;
      _search = '';
      _page = 1;
    });
    _load();
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _openForm([Supplier? current]) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _SupplierFormDialog(
        current: current,
        onSubmit: (Map<String, dynamic> payload) =>
            _repository.saveSupplier(payload, id: current?.id),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'الموردون والمستحقات',
        title: 'الموردون والمستحقات',
        subtitle: 'رصيد المورد مستمد حصراً من الفواتير والدفعات المُرحّلة',
        showContext: false,
        actions: <Widget>[
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              backgroundColor: FinanceColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة مورد'),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_pageData == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل الموردين…');
    }
    if (_pageData == null) {
      return FinanceErrorState(
        message: 'تعذّر تحميل الموردين. لم يتم اعتبار الخطأ صفراً.',
        onRetry: _load,
      );
    }
    final FinancePage<Supplier> page = _pageData!;
    final bool hasFilters = _status != null || _search.isNotEmpty;
    return SingleChildScrollView(
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SummaryGrid(suppliers: page),
              const SizedBox(height: FinanceSpace.lg),
              FinanceFilterBar(
                onReset: hasFilters ? _clearFilters : null,
                children: <Widget>[
                  _FilterDropdown(
                    label: 'الحالة',
                    value: _status,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'active', child: Text('نشط')),
                      DropdownMenuItem<String>(
                        value: 'inactive',
                        child: Text('غير نشط'),
                      ),
                    ],
                    onChanged: _applyStatus,
                  ),
                  SizedBox(
                    width: 240,
                    height: 34,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: FinanceText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'اسم المورد أو الرمز…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: FinanceColors.workspace,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            FinanceRadius.control,
                          ),
                          borderSide: const BorderSide(color: FinanceColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FinanceSpace.lg),
              if (_error != null) ...<Widget>[
                FinanceAlertBanner(
                  message: 'تعذّر تحديث الموردين لهذه الفلاتر. تُعرض آخر بيانات محمّلة.',
                  tone: FinanceTone.warning,
                  action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                ),
                const SizedBox(height: FinanceSpace.md),
              ],
              if (page.items.isEmpty)
                SizedBox(
                  height: 220,
                  child: FinanceEmptyState(
                    message: hasFilters
                        ? 'لا يوجد موردون مطابقون للفلاتر المحددة'
                        : 'لا يوجد موردون مسجلون بعد',
                    action: hasFilters
                        ? TextButton(
                            onPressed: _clearFilters,
                            child: const Text('إعادة تعيين الفلاتر'),
                          )
                        : null,
                  ),
                )
              else ...<Widget>[
                _SuppliersTable(
                  rows: page.items,
                  onOpen: (Supplier s) =>
                      context.go('${AppRoutes.financeSuppliers}/${s.id}'),
                  onEdit: _openForm,
                ),
                FinancePagination(meta: page.meta, onPageChanged: _changePage),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.suppliers});
  final FinancePage<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    final double totalOutstanding = suppliers.items.fold<double>(
      0,
      (double sum, Supplier s) => sum + _amount(s.outstandingBalance),
    );
    final double totalOverdue = suppliers.items.fold<double>(
      0,
      (double sum, Supplier s) => sum + _amount(s.overdueBalance),
    );
    final int activeCount = suppliers.items
        .where((Supplier s) => s.isActive)
        .length;
    // Payment-terms average is only meaningful when every supplier is
    // actually loaded (never a partial page's approximation).
    final bool hasCompleteSet =
        suppliers.meta.total <= suppliers.items.length;
    final double? averageTerms = hasCompleteSet && suppliers.items.isNotEmpty
        ? suppliers.items.fold<int>(
                0,
                (int sum, Supplier s) => sum + s.paymentTermsDays,
              ) /
              suppliers.items.length
        : null;
    return FinanceKpiGrid(
      items: <FinanceKpiData>[
        FinanceKpiData(
          label: 'إجمالي المستحقات',
          value: _money(totalOutstanding),
          icon: Icons.account_balance_wallet_outlined,
        ),
        FinanceKpiData(
          label: 'متأخر السداد',
          value: _money(totalOverdue),
          icon: Icons.warning_amber_outlined,
          tone: FinanceTone.danger,
        ),
        FinanceKpiData(
          label: 'الموردون النشطون',
          value: '$activeCount',
          icon: Icons.storefront_outlined,
        ),
        FinanceKpiData(
          label: 'متوسط مهلة السداد',
          value: averageTerms == null ? '—' : '${averageTerms.round()} يوم',
          icon: Icons.schedule_outlined,
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsetsDirectional.only(start: FinanceSpace.sm),
    decoration: BoxDecoration(
      color: FinanceColors.workspace,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Text(label, style: FinanceText.small),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        style: FinanceText.body,
        isDense: true,
        onChanged: onChanged,
        items: <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: null, child: Text('$label: الكل')),
          ...items,
        ],
      ),
    ),
  );
}

class _SuppliersTable extends StatelessWidget {
  const _SuppliersTable({
    required this.rows,
    required this.onOpen,
    required this.onEdit,
  });
  final List<Supplier> rows;
  final ValueChanged<Supplier> onOpen;
  final ValueChanged<Supplier> onEdit;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'المورد',
      'الرصيد المستحق',
      'المتأخر',
      'فواتير مفتوحة',
      'آخر فاتورة',
      'الحالة',
      '',
    ],
    minWidth: 1120,
    onRowTap: (int index) => onOpen(rows[index]),
    rows: rows.map((Supplier s) {
      final bool overdue = _amount(s.overdueBalance) > 0;
      return <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(s.name, style: FinanceText.body.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            FinanceReference(reference: s.supplierNumber),
          ],
        ),
        FinanceAmount(value: s.outstandingBalance),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            s.overdueBalance,
            style: FinanceText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: overdue ? FinanceColors.danger : FinanceColors.ink,
            ),
          ),
        ),
        Text('${s.openInvoiceCount}', style: FinanceText.body),
        Text(s.lastInvoiceDate ?? '—', style: FinanceText.small),
        SupplierActiveBadge(active: s.isActive),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => onEdit(s),
          ),
        ),
      ];
    }).toList(),
  );
}

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({required this.current, required this.onSubmit});
  final Supplier? current;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _contact;
  late final TextEditingController _taxNumber;
  late final TextEditingController _terms;
  late final TextEditingController _notes;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Supplier? current = widget.current;
    _name = TextEditingController(text: current?.name);
    _phone = TextEditingController(text: current?.phone);
    _email = TextEditingController(text: current?.email);
    _address = TextEditingController(text: current?.address);
    _contact = TextEditingController(text: current?.contactPerson);
    _taxNumber = TextEditingController(text: current?.taxNumber);
    _terms = TextEditingController(text: '${current?.paymentTermsDays ?? 0}');
    _notes = TextEditingController(text: current?.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _contact.dispose();
    _taxNumber.dispose();
    _terms.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم المورد.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(<String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'contactPerson': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        'taxNumber': _taxNumber.text.trim().isEmpty ? null : _taxNumber.text.trim(),
        'paymentTermsDays': int.tryParse(_terms.text.trim()) ?? 0,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FinanceDialogShell(
    title: widget.current == null ? 'إضافة مورد' : 'تعديل مورد',
    actions: <Widget>[
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('إلغاء'),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: FinanceColors.primary,
          foregroundColor: Colors.white,
        ),
        child: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('حفظ'),
      ),
    ],
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: FinanceSpace.md),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'الهاتف')),
          const SizedBox(height: FinanceSpace.md),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
          ),
          const SizedBox(height: FinanceSpace.md),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان')),
          const SizedBox(height: FinanceSpace.md),
          TextField(
            controller: _contact,
            decoration: const InputDecoration(labelText: 'جهة الاتصال'),
          ),
          const SizedBox(height: FinanceSpace.md),
          TextField(
            controller: _taxNumber,
            decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
          ),
          const SizedBox(height: FinanceSpace.md),
          TextField(
            controller: _terms,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'مهلة السداد (أيام)'),
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

/// Supplier active/inactive is not a workflow status — `FinanceStatusBadge`'s
/// `active` case maps to "مكتمل" (completed), which is the wrong label here.
/// Mirrors the Cash & Banks `_ActiveBadge` fix (Phase 4) for the same reason.
class SupplierActiveBadge extends StatelessWidget {
  const SupplierActiveBadge({super.key, required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: active ? FinanceColors.successBg : const Color(0xffF0EDED),
      borderRadius: BorderRadius.circular(FinanceRadius.pill),
    ),
    child: Text(
      active ? 'نشط' : 'غير مفعّل',
      style: FinanceText.small.copyWith(
        color: active ? FinanceColors.success : FinanceColors.muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

double _amount(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
String _money(dynamic value) {
  final double n = _amount(value);
  return n.toStringAsFixed(2);
}
