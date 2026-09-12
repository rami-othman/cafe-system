import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../finance_inventory_setup/controllers/finance_setup_cubit.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_pagination.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../../pos/models/branch.dart';
import '../controllers/purchasing_cubit.dart';
import '../models/purchasing_models.dart';
import '../widgets/purchase_type_label.dart';

/// المشتريات — the Purchasing Center (`/finance/purchases`). A filtered,
/// enriched read of the existing Supplier Invoice domain; it creates no new
/// source of truth. "الاستلامات" (Phase 2) is a real, working tab backed by
/// `finance/purchase-receipts` — an independent Goods Receipt domain with
/// zero GL impact. أوامر الشراء / المرتجعات remain disabled "قريباً" chips,
/// never clickable-but-empty tabs.
class PurchasingCenterScreen extends StatefulWidget {
  const PurchasingCenterScreen({super.key});
  @override
  State<PurchasingCenterScreen> createState() => _PurchasingCenterScreenState();
}

class _PurchasingCenterScreenState extends State<PurchasingCenterScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => FinanceShell(
    title: 'المشتريات',
    subtitle: 'كل فاتورة شراء هنا هي نفسها فاتورة المورد — لا يوجد سجل مالي مواز',
    actions: <Widget>[
      ElevatedButton.icon(
        onPressed: () => context.go(AppRoutes.financePurchasesNew),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 36),
          backgroundColor: FinanceColors.primary,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('فاتورة شراء'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TabsRow(selected: _tab, onSelected: (int i) => setState(() => _tab = i)),
        const SizedBox(height: FinanceSpace.lg),
        Expanded(
          child: switch (_tab) {
            0 => const _PurchasingOverviewTab(),
            1 => const _PurchasingInvoicesTab(),
            _ => const _PurchasingReceiptsTab(),
          },
        ),
      ],
    ),
  );
}

class _TabsRow extends StatelessWidget {
  const _TabsRow({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: FinanceSpace.sm,
    runSpacing: FinanceSpace.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      _TabChip(label: 'جميع المشتريات', selected: selected == 0, onTap: () => onSelected(0)),
      _TabChip(label: 'فواتير الشراء', selected: selected == 1, onTap: () => onSelected(1)),
      _TabChip(label: 'الاستلامات', selected: selected == 2, onTap: () => onSelected(2)),
      const SizedBox(width: FinanceSpace.sm),
      const _ComingSoonChip(label: 'أوامر الشراء'),
      const _ComingSoonChip(label: 'المرتجعات'),
    ],
  );
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? FinanceColors.primary : FinanceColors.card,
    borderRadius: BorderRadius.circular(FinanceRadius.pill),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FinanceRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FinanceRadius.pill),
          border: Border.all(color: selected ? FinanceColors.primary : FinanceColors.border),
        ),
        child: Text(
          label,
          style: FinanceText.body.copyWith(
            color: selected ? Colors.white : FinanceColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

/// A clearly non-operational placeholder for a later phase — disabled, and
/// labeled "قريباً" so it never reads as a working, empty feature.
class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.55,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FinanceColors.workspace,
        borderRadius: BorderRadius.circular(FinanceRadius.pill),
        border: Border.all(color: FinanceColors.border, style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: FinanceText.small.copyWith(color: FinanceColors.muted)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: FinanceColors.border,
              borderRadius: BorderRadius.circular(FinanceRadius.pill),
            ),
            child: Text(
              'قريباً',
              style: FinanceText.small.copyWith(fontSize: 10, color: FinanceColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PurchasingOverviewTab extends StatefulWidget {
  const _PurchasingOverviewTab();
  @override
  State<_PurchasingOverviewTab> createState() => _PurchasingOverviewTabState();
}

class _PurchasingOverviewTabState extends State<_PurchasingOverviewTab> {
  FinancePage<PurchaseInvoice>? _page;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  PurchasingCubit get _cubit => context.read<PurchasingCubit>();

  Future<void> _load() async {
    try {
      final FinancePage<PurchaseInvoice> page = await _cubit.repository
          .getPurchases(queryParameters: const <String, dynamic>{'perPage': 10});
      if (!mounted) return;
      setState(() {
        _page = page;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_page == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل المشتريات…');
    }
    if (_page == null) {
      return FinanceErrorState(message: 'تعذّر تحميل المشتريات.', onRetry: _load);
    }
    final List<PurchaseInvoice> rows = _page!.items;
    final double totalOutstanding = rows.fold<double>(
      0,
      (double sum, PurchaseInvoice p) => sum + (double.tryParse(p.remainingAmount) ?? 0),
    );
    final int unpaidCount = rows.where((PurchaseInvoice p) => p.paymentStatus != 'paid' && p.documentStatus == 'posted').length;
    final int draftCount = rows.where((PurchaseInvoice p) => p.documentStatus == 'draft').length;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FinanceKpiGrid(
            items: <FinanceKpiData>[
              FinanceKpiData(
                label: 'إجمالي المتبقي (آخر ١٠ فواتير)',
                value: totalOutstanding.toStringAsFixed(2),
                icon: Icons.account_balance_wallet_outlined,
              ),
              FinanceKpiData(
                label: 'فواتير غير مسددة بالكامل',
                value: '$unpaidCount',
                icon: Icons.pending_actions_outlined,
                tone: unpaidCount > 0 ? FinanceTone.warning : FinanceTone.neutral,
              ),
              FinanceKpiData(
                label: 'مسودات بانتظار الترحيل',
                value: '$draftCount',
                icon: Icons.edit_note_outlined,
              ),
              FinanceKpiData(
                label: 'إجمالي عدد المشتريات',
                value: '${_page!.meta.total}',
                icon: Icons.shopping_bag_outlined,
              ),
            ],
          ),
          const SizedBox(height: FinanceSpace.lg),
          Text('أحدث المشتريات', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.md),
          if (rows.isEmpty)
            const SizedBox(
              height: 160,
              child: FinanceEmptyState(message: 'لا توجد مشتريات مسجلة بعد'),
            )
          else
            _PurchasesTable(rows: rows, onOpen: _openInvoice),
        ],
      ),
    );
  }

  void _openInvoice(PurchaseInvoice p) => context.go('${AppRoutes.financePurchases}/${p.id}');
}

class _PurchasingInvoicesTab extends StatefulWidget {
  const _PurchasingInvoicesTab();
  @override
  State<_PurchasingInvoicesTab> createState() => _PurchasingInvoicesTabState();
}

class _PurchasingInvoicesTabState extends State<_PurchasingInvoicesTab> {
  String? _purchaseType;
  String? _documentStatus;
  String? _paymentStatus;
  String? _receiptStatus;
  int? _branchId;
  String _search = '';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int _requestId = 0;
  FinancePage<PurchaseInvoice>? _pageData;
  List<Branch> _branches = const <Branch>[];
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  PurchasingCubit get _cubit => context.read<PurchasingCubit>();

  Future<void> _loadBranches() async {
    try {
      final List<Branch> branches = await context
          .read<FinanceSetupCubit>()
          .repository
          .getBranches();
      if (mounted) setState(() => _branches = branches);
    } catch (_) {
      // Branch filter is a convenience; a failure here should not block the list itself.
    }
  }

  Map<String, dynamic> get _parameters => <String, dynamic>{
    if (_purchaseType != null) 'purchaseType': _purchaseType,
    if (_documentStatus != null) 'documentStatus': _documentStatus,
    if (_paymentStatus != null) 'paymentStatus': _paymentStatus,
    if (_receiptStatus != null) 'receiptStatus': _receiptStatus,
    if (_branchId != null) 'branchId': _branchId,
    if (_search.isNotEmpty) 'search': _search,
    if (_from != null) 'from': _from!.toIso8601String().split('T').first,
    if (_to != null) 'to': _to!.toIso8601String().split('T').first,
    'page': _page,
    'perPage': 20,
  };

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final FinancePage<PurchaseInvoice> page = await _cubit.repository
          .getPurchases(queryParameters: _parameters);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _pageData = page;
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

  void _applyFilter(void Function() mutate) {
    setState(() {
      mutate();
      _page = 1;
    });
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _applyFilter(() => _search = value.trim());
    });
  }

  bool get _hasFilters =>
      _purchaseType != null ||
      _documentStatus != null ||
      _paymentStatus != null ||
      _receiptStatus != null ||
      _branchId != null ||
      _search.isNotEmpty ||
      _from != null ||
      _to != null;

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _purchaseType = null;
      _documentStatus = null;
      _paymentStatus = null;
      _receiptStatus = null;
      _branchId = null;
      _search = '';
      _from = null;
      _to = null;
      _page = 1;
    });
    _load();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _applyFilter(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pageData == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل فواتير الشراء…');
    }
    if (_pageData == null) {
      return FinanceErrorState(message: 'تعذّر تحميل فواتير الشراء.', onRetry: _load);
    }
    final FinancePage<PurchaseInvoice> page = _pageData!;
    return SingleChildScrollView(
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FinanceFilterBar(
                onReset: _hasFilters ? _clearFilters : null,
                children: <Widget>[
                  _dropdown(
                    label: 'نوع الشراء',
                    value: _purchaseType,
                    items: purchaseTypeFilterOptions,
                    onChanged: (String? v) => _applyFilter(() => _purchaseType = v),
                  ),
                  _dropdown(
                    label: 'حالة المستند',
                    value: _documentStatus,
                    items: const <MapEntry<String, String>>[
                      MapEntry<String, String>('draft', 'مسودة'),
                      MapEntry<String, String>('posted', 'مرحّلة'),
                      MapEntry<String, String>('cancelled', 'ملغاة'),
                    ],
                    onChanged: (String? v) => _applyFilter(() => _documentStatus = v),
                  ),
                  _dropdown(
                    label: 'حالة الدفع',
                    value: _paymentStatus,
                    items: const <MapEntry<String, String>>[
                      MapEntry<String, String>('unpaid', 'غير مسددة'),
                      MapEntry<String, String>('partial', 'مسددة جزئياً'),
                      MapEntry<String, String>('paid', 'مسددة بالكامل'),
                    ],
                    onChanged: (String? v) => _applyFilter(() => _paymentStatus = v),
                  ),
                  _dropdown(
                    label: 'حالة الاستلام',
                    value: _receiptStatus,
                    items: receiptStatusFilterOptions,
                    onChanged: (String? v) => _applyFilter(() => _receiptStatus = v),
                  ),
                  if (_branches.isNotEmpty)
                    _dropdown(
                      label: 'الفرع',
                      value: _branchId?.toString(),
                      items: _branches
                          .map((Branch b) => MapEntry<String, String>('${b.id}', b.name))
                          .toList(growable: false),
                      onChanged: (String? v) =>
                          _applyFilter(() => _branchId = v == null ? null : int.tryParse(v)),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: true),
                    icon: const Icon(Icons.calendar_today_outlined, size: 15),
                    label: Text(_from == null ? 'من تاريخ' : _isoDate(_from!)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: false),
                    icon: const Icon(Icons.calendar_today_outlined, size: 15),
                    label: Text(_to == null ? 'إلى تاريخ' : _isoDate(_to!)),
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
                        hintText: 'رقم الفاتورة أو المورد…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: FinanceColors.workspace,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FinanceRadius.control),
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
                  message: 'تعذّر تحديث القائمة لهذه الفلاتر. تُعرض آخر بيانات محمّلة.',
                  action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                ),
                const SizedBox(height: FinanceSpace.md),
              ],
              if (page.items.isEmpty)
                SizedBox(
                  height: 220,
                  child: FinanceEmptyState(
                    message: _hasFilters
                        ? 'لا توجد فواتير شراء مطابقة للفلاتر المحددة'
                        : 'لا توجد فواتير شراء بعد',
                    action: _hasFilters
                        ? TextButton(onPressed: _clearFilters, child: const Text('إعادة تعيين الفلاتر'))
                        : null,
                  ),
                )
              else ...<Widget>[
                _PurchasesTable(
                  rows: page.items,
                  onOpen: (PurchaseInvoice p) => context.go('${AppRoutes.financePurchases}/${p.id}'),
                ),
                FinancePagination(
                  meta: page.meta,
                  onPageChanged: (int p) {
                    setState(() => _page = p);
                    _load();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<MapEntry<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) => Container(
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
          ...items.map(
            (MapEntry<String, String> e) =>
                DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
          ),
        ],
      ),
    ),
  );
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _PurchasesTable extends StatelessWidget {
  const _PurchasesTable({required this.rows, required this.onOpen});
  final List<PurchaseInvoice> rows;
  final ValueChanged<PurchaseInvoice> onOpen;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'رقم الفاتورة',
      'التاريخ',
      'المورد',
      'الفرع',
      'نوع الشراء',
      'الإجمالي',
      'المدفوع',
      'المتبقي',
      'حالة الدفع',
      'حالة الاستلام',
      'حالة المستند',
      'أنشأ بواسطة',
    ],
    minWidth: 1480,
    onRowTap: (int index) => onOpen(rows[index]),
    rows: rows
        .map(
          (PurchaseInvoice p) => <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  p.invoiceNumber,
                  style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                FinanceReference(reference: p.internalReference),
              ],
            ),
            Text(p.invoiceDate, style: FinanceText.small),
            Text(p.supplierName, style: FinanceText.body),
            Text(p.branchName ?? 'كل الفروع', style: FinanceText.small),
            PurchaseTypeBadge(purchaseType: p.purchaseType),
            FinanceAmount(value: p.totalAmount),
            FinanceAmount(value: p.paidAmount),
            FinanceAmount(
              value: p.remainingAmount,
              color: p.isOverdue ? FinanceColors.danger : null,
            ),
            p.paymentStatus == 'not_applicable'
                ? Text('—', style: FinanceText.small)
                : FinanceStatusBadge(status: p.paymentStatus),
            ReceiptStatusBadge(receiptStatus: p.receiptStatus),
            FinanceStatusBadge(status: p.documentStatus),
            Text(p.createdByName ?? '—', style: FinanceText.small),
          ],
        )
        .toList(growable: false),
  );
}

/// الاستلامات — a real, working list backed by `finance/purchase-receipts`
/// (Phase 2). Every row here is a posted or draft Goods Receipt; opening one
/// navigates to its own read-only detail screen.
class _PurchasingReceiptsTab extends StatefulWidget {
  const _PurchasingReceiptsTab();
  @override
  State<_PurchasingReceiptsTab> createState() => _PurchasingReceiptsTabState();
}

class _PurchasingReceiptsTabState extends State<_PurchasingReceiptsTab> {
  String? _status;
  String _invoiceNumber = '';
  String _receiptNumber = '';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _receiptController = TextEditingController();
  Timer? _debounce;

  int _requestId = 0;
  FinancePage<PurchaseReceipt>? _pageData;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _invoiceController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  PurchasingCubit get _cubit => context.read<PurchasingCubit>();

  Map<String, dynamic> get _parameters => <String, dynamic>{
    if (_status != null) 'status': _status,
    if (_invoiceNumber.isNotEmpty) 'invoiceNumber': _invoiceNumber,
    if (_receiptNumber.isNotEmpty) 'receiptNumber': _receiptNumber,
    if (_from != null) 'from': _isoDate(_from!),
    if (_to != null) 'to': _isoDate(_to!),
    'page': _page,
    'perPage': 20,
  };

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final FinancePage<PurchaseReceipt> page = await _cubit.repository
          .getReceipts(queryParameters: _parameters);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _pageData = page;
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

  void _applyFilter(void Function() mutate) {
    setState(() {
      mutate();
      _page = 1;
    });
    _load();
  }

  bool get _hasFilters =>
      _status != null ||
      _invoiceNumber.isNotEmpty ||
      _receiptNumber.isNotEmpty ||
      _from != null ||
      _to != null;

  void _clearFilters() {
    _debounce?.cancel();
    _invoiceController.clear();
    _receiptController.clear();
    setState(() {
      _status = null;
      _invoiceNumber = '';
      _receiptNumber = '';
      _from = null;
      _to = null;
      _page = 1;
    });
    _load();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _applyFilter(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _debounced(void Function() apply) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _applyFilter(apply);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pageData == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل الاستلامات…');
    }
    if (_pageData == null) {
      return FinanceErrorState(message: 'تعذّر تحميل الاستلامات.', onRetry: _load);
    }
    final FinancePage<PurchaseReceipt> page = _pageData!;
    return SingleChildScrollView(
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FinanceFilterBar(
                onReset: _hasFilters ? _clearFilters : null,
                children: <Widget>[
                  Container(
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
                        value: _status,
                        hint: const Text('الحالة: الكل', style: FinanceText.small),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                        style: FinanceText.body,
                        isDense: true,
                        onChanged: (String? v) => _applyFilter(() => _status = v),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(value: null, child: Text('الحالة: الكل')),
                          DropdownMenuItem<String>(value: 'draft', child: Text('مسودة')),
                          DropdownMenuItem<String>(value: 'posted', child: Text('مرحّل')),
                        ],
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: true),
                    icon: const Icon(Icons.calendar_today_outlined, size: 15),
                    label: Text(_from == null ? 'من تاريخ' : _isoDate(_from!)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: false),
                    icon: const Icon(Icons.calendar_today_outlined, size: 15),
                    label: Text(_to == null ? 'إلى تاريخ' : _isoDate(_to!)),
                  ),
                  SizedBox(
                    width: 200,
                    height: 34,
                    child: TextField(
                      controller: _invoiceController,
                      onChanged: (String v) => _debounced(() => _invoiceNumber = v.trim()),
                      style: FinanceText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'رقم الفاتورة',
                        filled: true,
                        fillColor: FinanceColors.workspace,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FinanceRadius.control),
                          borderSide: const BorderSide(color: FinanceColors.border),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    height: 34,
                    child: TextField(
                      controller: _receiptController,
                      onChanged: (String v) => _debounced(() => _receiptNumber = v.trim()),
                      style: FinanceText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'رقم الاستلام',
                        filled: true,
                        fillColor: FinanceColors.workspace,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FinanceRadius.control),
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
                  message: 'تعذّر تحديث القائمة لهذه الفلاتر. تُعرض آخر بيانات محمّلة.',
                  action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                ),
                const SizedBox(height: FinanceSpace.md),
              ],
              if (page.items.isEmpty)
                SizedBox(
                  height: 220,
                  child: FinanceEmptyState(
                    message: _hasFilters
                        ? 'لا توجد استلامات مطابقة للفلاتر المحددة'
                        : 'لا توجد استلامات مسجلة بعد',
                    action: _hasFilters
                        ? TextButton(onPressed: _clearFilters, child: const Text('إعادة تعيين الفلاتر'))
                        : null,
                  ),
                )
              else ...<Widget>[
                _ReceiptsCenterTable(
                  rows: page.items,
                  onOpen: (PurchaseReceipt r) =>
                      context.go('${AppRoutes.financePurchaseReceipts}/${r.id}'),
                ),
                FinancePagination(
                  meta: page.meta,
                  onPageChanged: (int p) {
                    setState(() => _page = p);
                    _load();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptsCenterTable extends StatelessWidget {
  const _ReceiptsCenterTable({required this.rows, required this.onOpen});
  final List<PurchaseReceipt> rows;
  final ValueChanged<PurchaseReceipt> onOpen;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'رقم الاستلام',
      'فاتورة الشراء',
      'المورد',
      'التاريخ',
      'الفرع',
      'عدد البنود',
      'الحالة',
      'أنشأ بواسطة',
    ],
    minWidth: 1180,
    onRowTap: (int index) => onOpen(rows[index]),
    rows: rows
        .map(
          (PurchaseReceipt r) => <Widget>[
            FinanceReference(reference: r.receiptNumber),
            Text(r.invoiceNumber, style: FinanceText.body),
            Text(r.supplierName, style: FinanceText.body),
            Text(r.receiptDate, style: FinanceText.small),
            Text(r.branchName ?? 'المستودع المركزي', style: FinanceText.small),
            Text('${r.lineCount}', style: FinanceText.body),
            GoodsReceiptStatusBadge(status: r.status),
            Text(r.createdByName ?? '—', style: FinanceText.small),
          ],
        )
        .toList(growable: false),
  );
}
