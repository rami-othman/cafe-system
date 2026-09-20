import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/services/service_locator.dart';
import '../../finance_inventory_setup/controllers/finance_setup_cubit.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../../inventory/models/inventory_models.dart';
import '../../inventory/repositories/inventory_repository.dart';
import '../../pos/models/branch.dart';
import '../controllers/purchasing_cubit.dart';
import '../models/purchasing_models.dart';
import '../widgets/inventory_item_search_field.dart';
import '../widgets/purchase_type_label.dart';
import '../widgets/purchase_posting_dialog.dart';

/// Create/edit a purchase invoice (`/finance/purchases/new`,
/// `/finance/purchases/:id/edit`). This posts to the exact same
/// `finance/supplier-invoices` endpoint the legacy total-only dialog on the
/// Supplier Profile screen uses — there is only one way to create a Supplier
/// Invoice, this screen just adds a real line editor in front of it. Phase 1
/// enforces one line type per invoice, matching the backend exactly; mixed
/// invoices are deferred, not half-built.
class PurchaseInvoiceFormScreen extends StatefulWidget {
  const PurchaseInvoiceFormScreen({
    super.key,
    this.editId,
    this.preselectedSupplierId,
  });
  final int? editId;
  final int? preselectedSupplierId;

  @override
  State<PurchaseInvoiceFormScreen> createState() =>
      _PurchaseInvoiceFormScreenState();
}

class _LineDraft {
  _LineDraft(this.lineType);
  final String lineType;
  InventoryItem? item;
  int? pendingInventoryItemId;
  final TextEditingController description = TextEditingController();
  final TextEditingController purchaseUnit = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController unitCost = TextEditingController(text: '0');
  String discountType = 'fixed'; // 'fixed' | 'percentage'
  final TextEditingController discountValue = TextEditingController(text: '0');
  final TextEditingController tax = TextEditingController(text: '0');
  int? warehouseId;

  double _num0(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  double get grossAmount => _num0(quantity) * _num0(unitCost);
  double get taxValue => _num0(tax);

  double get discountAmount {
    final double gross = grossAmount;
    final double value = _num0(discountValue);
    if (discountType == 'percentage') {
      return gross * (value.clamp(0, 100) / 100);
    }
    return value;
  }

  double get netAmount =>
      (grossAmount - discountAmount).clamp(0, double.infinity);

  double get lineTotal => netAmount + _num0(tax);

  void dispose() {
    description.dispose();
    purchaseUnit.dispose();
    quantity.dispose();
    unitCost.dispose();
    discountValue.dispose();
    tax.dispose();
  }
}

const List<String> kQuickChargeTypes = <String>[
  'نقل',
  'توصيل',
  'شحن',
  'تحميل وتنزيل',
  'ضيافة',
  'إكرامية',
  'تغليف',
  'رسوم',
  'خدمة',
  'أخرى',
];

class _ChargeDraft {
  _ChargeDraft();
  final TextEditingController description = TextEditingController();
  String treatment = 'expense'; // 'capitalize' | 'expense'
  int? expenseCategoryId;
  final TextEditingController amount = TextEditingController(text: '0');
  final TextEditingController tax = TextEditingController(text: '0');

  double _num0(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  double get amountValue => _num0(amount);
  double get taxValue => _num0(tax);
  double get total => amountValue + taxValue;

  void dispose() {
    description.dispose();
    amount.dispose();
    tax.dispose();
  }
}

class _PurchaseInvoiceFormScreenState extends State<PurchaseInvoiceFormScreen> {
  final TextEditingController _invoiceNumber = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _paidNow = TextEditingController(text: '0');
  String _receiptMode = 'immediate';
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  int? _supplierId;
  int? _branchId;
  int? _destinationWarehouseId;
  String _purchaseType = 'inventory';
  int? _expenseCategoryId;
  int? _assetAccountId;
  final List<_LineDraft> _lines = <_LineDraft>[];
  final List<_ChargeDraft> _charges = <_ChargeDraft>[];
  String _invoiceDiscountType = 'fixed'; // 'fixed' | 'percentage'
  final TextEditingController _invoiceDiscountValue = TextEditingController(
    text: '0',
  );

  List<Supplier> _suppliers = const <Supplier>[];
  List<Branch> _branches = const <Branch>[];
  List<WarehouseLocation> _warehouses = const <WarehouseLocation>[];
  List<ExpenseCategory> _expenseCategories = const <ExpenseCategory>[];
  List<FinancialAccount> _accounts = const <FinancialAccount>[];
  PurchaseInvoice? _editing;

  bool _loadingReferenceData = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editId != null;

  String get _selectedBranchName {
    for (final Branch branch in _branches) {
      if (branch.id == _branchId) return branch.name;
    }
    return '—';
  }

  @override
  void initState() {
    super.initState();
    _supplierId = widget.preselectedSupplierId;
    _lines.add(_LineDraft(_purchaseType));
    _loadReferenceData();
  }

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _notes.dispose();
    _paidNow.dispose();
    _invoiceDiscountValue.dispose();
    for (final _LineDraft line in _lines) {
      line.dispose();
    }
    for (final _ChargeDraft charge in _charges) {
      charge.dispose();
    }
    super.dispose();
  }

  void _addCharge() => setState(() => _charges.add(_ChargeDraft()));
  void _removeCharge(int index) => setState(() {
    _charges[index].dispose();
    _charges.removeAt(index);
  });

  double get _linesNetTotal =>
      _lines.fold<double>(0, (double s, _LineDraft l) => s + l.netAmount);
  double get _linesTaxTotal =>
      _lines.fold<double>(0, (double s, _LineDraft l) => s + l.taxValue);
  double get _invoiceDiscountPreview {
    final double value =
        double.tryParse(_invoiceDiscountValue.text.trim()) ?? 0;
    if (_invoiceDiscountType == 'percentage') {
      return _linesNetTotal * (value.clamp(0, 100) / 100);
    }
    return value.clamp(0, _linesNetTotal);
  }

  double get _netAfterInvoiceDiscount =>
      (_linesNetTotal - _invoiceDiscountPreview).clamp(0, double.infinity);
  double get _chargesAmountTotal =>
      _charges.fold<double>(0, (double s, _ChargeDraft c) => s + c.amountValue);
  double get _chargesTaxTotal =>
      _charges.fold<double>(0, (double s, _ChargeDraft c) => s + c.taxValue);
  double get _grandTotalPreview =>
      _netAfterInvoiceDiscount +
      _linesTaxTotal +
      _chargesAmountTotal +
      _chargesTaxTotal;

  PurchasingCubit get _cubit => context.read<PurchasingCubit>();
  FinanceSetupCubit get _financeCubit => context.read<FinanceSetupCubit>();

  Future<void> _loadReferenceData() async {
    try {
      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _financeCubit.repository.getFinancePage(
            'finance/suppliers',
            queryParameters: const <String, dynamic>{'perPage': 200},
          ),
          _financeCubit.repository.getBranches(),
          // Cashiers are not allowed to browse Finance Settings or the chart
          // of accounts. Inventory purchase lines do not require either list;
          // leave non-inventory account/category selection unavailable rather
          // than failing the entire permitted purchasing workflow with 403.
          _optionalReferenceData<List<ExpenseCategory>>(
            _financeCubit.repository.getExpenseCategories(),
            const <ExpenseCategory>[],
          ),
          _optionalReferenceData<List<FinancialAccount>>(
            _financeCubit.repository.getAccounts(),
            const <FinancialAccount>[],
          ),
          serviceLocator<InventoryRepository>().warehouses(),
          if (_isEdit) _cubit.repository.getPurchase(widget.editId!),
        ],
      );
      if (!mounted) return;
      final dynamic suppliersPage = results[0];
      if (!mounted) return;
      setState(() {
        _suppliers = (suppliersPage.items as List<dynamic>)
            .map(
              (dynamic j) =>
                  Supplier.fromJson(Map<String, dynamic>.from(j as Map)),
            )
            .toList(growable: false);
        _branches = results[1] as List<Branch>;
        _expenseCategories = results[2] as List<ExpenseCategory>;
        _accounts = (results[3] as List<FinancialAccount>)
            .where(
              (FinancialAccount a) =>
                  a.accountGroup == 'assets' && a.code != '1100',
            )
            .toList(growable: false);
        _warehouses = results[4] as List<WarehouseLocation>;
        if (_isEdit) {
          _editing = results[5] as PurchaseInvoice;
          _applyEditingData(_editing!);
        }
        _loadingReferenceData = false;
      });
      if (_isEdit) {
        await _resolveEditingLineItems();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loadingReferenceData = false;
      });
    }
  }

  Future<T> _optionalReferenceData<T>(Future<T> request, T fallback) async {
    try {
      return await request;
    } catch (_) {
      return fallback;
    }
  }

  void _applyEditingData(PurchaseInvoice p) {
    _invoiceNumber.text = p.supplierInvoiceNumber ?? '';
    _notes.text = p.notes ?? '';
    _invoiceDate = DateTime.tryParse(p.invoiceDate) ?? _invoiceDate;
    _dueDate = DateTime.tryParse(p.dueDate) ?? _dueDate;
    _supplierId = p.supplierId;
    _branchId = p.branchId;
    _receiptMode = p.receiptMode ?? 'receive_later';
    _expenseCategoryId = p.purchaseType == 'expense' ? null : null;
    _assetAccountId = (p.purchaseType == 'asset' || p.purchaseType == 'other')
        ? p.debitAccountId
        : null;
    _purchaseType = p.purchaseType == 'other' && p.lines.isEmpty
        ? 'other'
        : p.purchaseType;
    _lines
      ..clear()
      ..addAll(
        p.lines.isEmpty
            ? <_LineDraft>[_LineDraft(_purchaseType)]
            : p.lines.map((PurchaseInvoiceLine l) {
                final _LineDraft draft = _LineDraft(l.lineType);
                draft.description.text = l.description;
                draft.purchaseUnit.text = l.purchaseUnit ?? '';
                draft.quantity.text = l.quantity;
                final double quantity = double.tryParse(l.quantity) ?? 0;
                final double gross =
                    double.tryParse(l.lineGrossAmount ?? '') ?? 0;
                draft.unitCost.text = quantity > 0
                    ? (gross / quantity).toStringAsFixed(4)
                    : l.unitPrice;
                draft.discountType = l.discountType;
                draft.discountValue.text = l.discountType == 'percentage'
                    ? (l.discountValue ?? '0')
                    : l.discountAmount;
                draft.tax.text = l.taxAmount;
                draft.warehouseId = l.warehouseId;
                draft.pendingInventoryItemId = l.inventoryItemId;
                return draft;
              }),
      );
    _destinationWarehouseId = p.lines.isEmpty ? null : p.lines.first.warehouseId;
    _invoiceDiscountType = p.discountType;
    _invoiceDiscountValue.text = p.discountType == 'percentage'
        ? (p.discountValue ?? '0')
        : p.discountAmount;
    _charges
      ..clear()
      ..addAll(
        p.charges.map((PurchaseInvoiceCharge c) {
          final _ChargeDraft draft = _ChargeDraft();
          draft.description.text = c.description;
          draft.treatment = c.treatment;
          draft.expenseCategoryId = c.expenseCategoryId;
          draft.amount.text = c.amount;
          draft.tax.text = c.taxAmount;
          return draft;
        }),
      );
  }

  /// Edit mode only: the item search field shows nothing until the user
  /// types, so an existing line's already-selected item (which may sit
  /// anywhere in the catalog, not just the first page) is fetched directly
  /// by id instead of relying on a preloaded, capped item list.
  Future<void> _resolveEditingLineItems() async {
    final InventoryRepository repository =
        serviceLocator<InventoryRepository>();
    await Future.wait(
      _lines.map((_LineDraft draft) async {
        final int? itemId = draft.pendingInventoryItemId;
        if (itemId == null) return;
        try {
          final InventoryItem item = await repository.item(itemId);
          if (mounted) setState(() => draft.item = item);
        } catch (_) {
          // Item may have been deleted since the invoice was created; leave unresolved.
        }
      }),
    );
  }

  void _addLine() => setState(() {
    final line = _LineDraft(_purchaseType);
    if (_purchaseType == 'inventory' && _receiptMode == 'immediate') {
      line.warehouseId = _destinationWarehouseId;
    }
    _lines.add(line);
  });
  void _removeLine(int index) => setState(() {
    _lines[index].dispose();
    _lines.removeAt(index);
  });

  void _changePurchaseType(String? type) {
    if (type == null) return;
    setState(() {
      _purchaseType = type;
      for (final _LineDraft line in _lines) {
        line.dispose();
      }
      _lines
        ..clear()
        ..add(_LineDraft(type));
      _expenseCategoryId = null;
      _assetAccountId = null;
    });
  }

  Future<void> _pickDate({required bool isInvoiceDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInvoiceDate ? _invoiceDate : _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isInvoiceDate) {
        _invoiceDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  String? _validate({bool forPosting = false}) {
    if (forPosting && ((double.tryParse(_paidNow.text.trim()) ?? -1) < 0 ||
        (double.tryParse(_paidNow.text.trim()) ?? 0) > _grandTotalPreview + 0.001)) {
      return 'المبلغ المدفوع الآن يجب أن يكون بين صفر وإجمالي الفاتورة.';
    }
    if (_supplierId == null) {
      return 'اختر المورد.';
    }
    if (forPosting && _branchId == null) {
      return 'اختر الفرع قبل الترحيل.';
    }
    if (_purchaseType == 'expense' && _expenseCategoryId == null) {
      return 'اختر فئة المصروف.';
    }
    if ((_purchaseType == 'asset' || _purchaseType == 'other') &&
        _assetAccountId == null) {
      return _purchaseType == 'asset'
          ? 'اختر حساب الأصل الثابت.'
          : 'اختر الحساب المحاسبي.';
    }
    if (_lines.isEmpty) {
      return 'أضف بنداً واحداً على الأقل.';
    }
    for (final _LineDraft line in _lines) {
      if (line.lineType == 'inventory' && line.item == null) {
        return 'اختر صنف المخزون لكل بند.';
      }
      if (forPosting && _receiptMode == 'immediate' &&
          line.lineType == 'inventory' &&
          line.warehouseId == null) {
        return 'اختر مخزن الاستلام لكل بند مخزون.';
      }
      if (line.lineType != 'inventory' &&
          line.description.text.trim().isEmpty) {
        return 'أدخل بيان كل بند.';
      }
      if ((double.tryParse(line.quantity.text.trim()) ?? 0) <= 0) {
        return 'الكمية يجب أن تكون أكبر من صفر.';
      }
      if ((double.tryParse(line.unitCost.text.trim()) ?? 0) <= 0) {
        return 'تكلفة الوحدة يجب أن تكون أكبر من صفر.';
      }
      if (line.discountType == 'percentage') {
        final double percent =
            double.tryParse(line.discountValue.text.trim()) ?? 0;
        if (percent < 0 || percent > 100) {
          return 'نسبة الخصم يجب أن تكون بين 0 و100.';
        }
      }
    }
    if (_invoiceDiscountType == 'percentage') {
      final double percent =
          double.tryParse(_invoiceDiscountValue.text.trim()) ?? 0;
      if (percent < 0 || percent > 100) {
        return 'نسبة خصم الفاتورة يجب أن تكون بين 0 و100.';
      }
    }
    for (final _ChargeDraft charge in _charges) {
      if (charge.description.text.trim().isEmpty) {
        return 'أدخل وصف كل تكلفة إضافية.';
      }
      if (charge.amountValue <= 0) {
        return 'مبلغ التكلفة الإضافية يجب أن يكون أكبر من صفر.';
      }
      if (charge.treatment == 'capitalize' && _purchaseType != 'inventory') {
        return 'إضافة التكلفة للمخزون متاحة فقط لفواتير المخزون.';
      }
      if (charge.treatment == 'expense' && charge.expenseCategoryId == null) {
        return 'اختر فئة المصروف لكل تكلفة إضافية مستقلة.';
      }
    }
    return null;
  }

  Future<void> _save({bool postAfterSave = false}) async {
    final String? validationError = _validate(forPosting: postAfterSave);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'supplierId': _supplierId,
        'receiptMode': _purchaseType == 'inventory' ? _receiptMode : 'receive_later',
        if (_branchId != null) 'branchId': _branchId,
        if (_invoiceNumber.text.trim().isNotEmpty)
          'supplierInvoiceNumber': _invoiceNumber.text.trim(),
        'invoiceDate': _isoDate(_invoiceDate),
        'dueDate': _isoDate(_dueDate),
        'invoiceType': _purchaseType == 'inventory'
            ? 'inventory'
            : _purchaseType == 'expense'
            ? 'expense'
            : 'other',
        if (_purchaseType == 'expense') 'expenseCategoryId': _expenseCategoryId,
        if (_purchaseType == 'asset' || _purchaseType == 'other')
          'debitAccountId': _assetAccountId,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'discountType': _invoiceDiscountType,
        'discountValue': _invoiceDiscountValue.text.trim().isEmpty
            ? '0'
            : _invoiceDiscountValue.text.trim(),
        'charges': _charges
            .map(
              (_ChargeDraft c) => <String, dynamic>{
                'description': c.description.text.trim(),
                'treatment': c.treatment,
                if (c.treatment == 'expense')
                  'expenseCategoryId': c.expenseCategoryId,
                'amount': c.amount.text.trim(),
                'taxAmount': c.tax.text.trim().isEmpty
                    ? '0'
                    : c.tax.text.trim(),
              },
            )
            .toList(growable: false),
        'lines': _lines
            .map(
              (_LineDraft l) => <String, dynamic>{
                'lineType': l.lineType,
                'description': l.lineType == 'inventory'
                    ? (l.item?.name ?? '')
                    : l.description.text.trim(),
                if (l.lineType == 'inventory') 'inventoryItemId': l.item!.id,
                if (l.lineType == 'inventory' &&
                    l.purchaseUnit.text.trim().isNotEmpty)
                  'purchaseUnit': l.purchaseUnit.text.trim(),
                'quantity': l.quantity.text.trim(),
                'unitCost': l.unitCost.text.trim(),
                'discountType': l.discountType,
                'discountValue': l.discountValue.text.trim().isEmpty
                    ? '0'
                    : l.discountValue.text.trim(),
                'taxAmount': l.tax.text.trim().isEmpty
                    ? '0'
                    : l.tax.text.trim(),
                if (l.lineType == 'inventory') 'warehouseId': l.warehouseId,
              },
            )
            .toList(growable: false),
        if (!_isEdit)
          'idempotencyKey':
              'purchase-create-${DateTime.now().microsecondsSinceEpoch}',
      };
      final PurchaseInvoice saved = await _cubit.repository.savePurchase(
        payload,
        id: widget.editId,
      );
      if (!mounted) return;
      if (postAfterSave) {
        final String paidAmount = _paidNow.text.trim();
        final bool hasPayment = (double.tryParse(paidAmount) ?? 0) > 0;
        PurchasePostingChoice? choice;
        if (hasPayment) {
          final PurchasePostingPreview preview = await _cubit.repository.getPostingPreview(saved.id);
          if (!mounted) return;
          choice = await showPurchasePostingDialog(context, preview: preview, branchName: _selectedBranchName, paidAmount: paidAmount);
        }
        if (!hasPayment || choice != null) {
          final PurchaseInvoice posted = await _cubit.repository.postPurchase(
            saved.id,
            'purchase-post-${saved.id}-${DateTime.now().microsecondsSinceEpoch}',
            financialLocationId: choice?.financialLocationId,
            paidAmount: paidAmount,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم ترحيل فاتورة الشراء. المدفوع: ${posted.paidAmount} SYP.',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      context.go('${AppRoutes.financePurchases}/${saved.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingReferenceData) {
      return const FinanceShell(
        title: 'فاتورة شراء جديدة',
        child: FinanceLoadingState(),
      );
    }
    if (_error != null && _suppliers.isEmpty) {
      return FinanceShell(
        title: 'فاتورة شراء',
        child: FinanceErrorState(
          message: 'تعذّر تحميل بيانات الفاتورة: $_error',
          onRetry: () {
            setState(() {
              _loadingReferenceData = true;
              _error = null;
            });
            _loadReferenceData();
          },
        ),
      );
    }
    if (_isEdit && _editing != null && !_editing!.isDraft) {
      return FinanceShell(
        title: 'فاتورة شراء',
        child: FinanceErrorState(
          message: 'لا يمكن تعديل فاتورة مُرحّلة. عرض الفاتورة فقط.',
          onRetry: () =>
              context.go('${AppRoutes.financePurchases}/${widget.editId}'),
        ),
      );
    }
    return FinanceShell(
      title: _isEdit ? 'تعديل فاتورة شراء' : 'فاتورة شراء جديدة',
      actions: <Widget>[
        ElevatedButton.icon(
          onPressed: _saving ? null : () => _save(postAfterSave: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: FinanceColors.success,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('ترحيل فاتورة الشراء'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_error != null) ...<Widget>[
              FinanceAlertBanner(message: _error!, tone: FinanceTone.danger),
              const SizedBox(height: FinanceSpace.md),
            ],
            _HeaderSection(
              internalReference: _editing?.internalReference,
              supplierInternalReference: _editing?.supplierInternalReference,
              supplierLocked: _isEdit,
              suppliers: _suppliers,
              branches: _branches,
              supplierId: _supplierId,
              branchId: _branchId,
              invoiceNumber: _invoiceNumber,
              invoiceDate: _invoiceDate,
              dueDate: _dueDate,
              notes: _notes,
              onSupplierChanged: (int? v) => setState(() => _supplierId = v),
              onBranchChanged: (int? v) => setState(() {
                _branchId = v;
                for (final _LineDraft line in _lines) {
                  if (line.warehouseId != null &&
                      !_warehouses.any(
                        (WarehouseLocation warehouse) =>
                            warehouse.id == line.warehouseId &&
                            (v == null ||
                                warehouse.branchId == null ||
                                warehouse.branchId == v),
                      )) {
                    line.warehouseId = null;
                  }
                }
                if (!_warehouses.any((w) => w.id == _destinationWarehouseId &&
                    (v == null || w.branchId == null || w.branchId == v))) {
                  _destinationWarehouseId = null;
                }
              }),
              onPickInvoiceDate: () => _pickDate(isInvoiceDate: true),
              onPickDueDate: () => _pickDate(isInvoiceDate: false),
            ),
            const SizedBox(height: FinanceSpace.lg),
            Text('نوع الشراء', style: FinanceText.page),
            const SizedBox(height: FinanceSpace.sm),
            Wrap(
              spacing: FinanceSpace.sm,
              children: purchaseTypeOptions
                  .map(
                    (MapEntry<String, String> e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _purchaseType == e.key,
                      onSelected: (_) => _changePurchaseType(e.key),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (_purchaseType == 'expense') ...<Widget>[
              const SizedBox(height: FinanceSpace.md),
              _categoryDropdown(),
            ],
            if (_purchaseType == 'asset' ||
                _purchaseType == 'other') ...<Widget>[
              const SizedBox(height: FinanceSpace.md),
              _accountDropdown(),
            ],
            const SizedBox(height: FinanceSpace.lg),
            if (_purchaseType == 'inventory' && _receiptMode == 'immediate') ...<Widget>[
              Text('وجهة المخزون', style: FinanceText.page),
              const SizedBox(height: FinanceSpace.sm),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('direct-purchase-warehouse'),
                  initialValue: _destinationWarehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'مخزن الاستلام'),
                  items: _warehouses.where((w) => _branchId == null || w.branchId == null || w.branchId == _branchId)
                      .map((w) => DropdownMenuItem<int>(value: w.id, child: Text(w.name))).toList(growable: false),
                  onChanged: (warehouseId) => setState(() {
                    _destinationWarehouseId = warehouseId;
                    for (final line in _lines) {
                      line.warehouseId = warehouseId;
                    }
                  }),
                ),
              ),
              const SizedBox(height: FinanceSpace.lg),
            ],
            Row(
              children: <Widget>[
                Expanded(child: Text('بنود الفاتورة', style: FinanceText.page)),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة بند'),
                ),
              ],
            ),
            const SizedBox(height: FinanceSpace.sm),
            ...List<Widget>.generate(
              _lines.length,
              (int index) => Padding(
                key: ObjectKey(_lines[index]),
                padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
                child: _LineEditorRow(
                  draft: _lines[index],
                  warehouses: _warehouses
                      .where(
                        (WarehouseLocation w) =>
                            _branchId == null ||
                            w.branchId == null ||
                            w.branchId == _branchId,
                      )
                      .toList(growable: false),
                  showWarehouse: _receiptMode == 'receive_later',
                  onRemove: _lines.length > 1 ? () => _removeLine(index) : null,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
            const SizedBox(height: FinanceSpace.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('تكاليف ورسوم إضافية', style: FinanceText.page),
                ),
                TextButton.icon(
                  onPressed: _addCharge,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة تكلفة'),
                ),
              ],
            ),
            const SizedBox(height: FinanceSpace.sm),
            ...List<Widget>.generate(
              _charges.length,
              (int index) => Padding(
                padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
                child: _ChargeEditorRow(
                  draft: _charges[index],
                  expenseCategories: _expenseCategories,
                  allowCapitalize: _purchaseType == 'inventory',
                  onRemove: () => _removeCharge(index),
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
            const SizedBox(height: FinanceSpace.lg),
            _InvoiceSummaryCard(
              linesNetTotal: _linesNetTotal,
              discountType: _invoiceDiscountType,
              discountValueController: _invoiceDiscountValue,
              onDiscountTypeChanged: (String type) =>
                  setState(() => _invoiceDiscountType = type),
              onDiscountChanged: () => setState(() {}),
              invoiceDiscountAmount: _invoiceDiscountPreview,
              netAfterDiscount: _netAfterInvoiceDiscount,
              charges: _charges,
              chargesAmountTotal: _chargesAmountTotal,
              chargesTaxTotal: _chargesTaxTotal,
              linesTaxTotal: _linesTaxTotal,
              grandTotal: _grandTotalPreview,
            ),
            const SizedBox(height: FinanceSpace.lg),
            if (_purchaseType == 'inventory') ...<Widget>[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('استلام البضاعة لاحقاً'),
                value: _receiptMode == 'receive_later',
                onChanged: (receiveLater) => setState(() {
                  _receiptMode = receiveLater == true ? 'receive_later' : 'immediate';
                  if (_receiptMode == 'immediate') {
                    _destinationWarehouseId ??= _lines.first.warehouseId;
                    for (final line in _lines) {
                      line.warehouseId = _destinationWarehouseId;
                    }
                  }
                }),
              ),
            ],
            Text('المدفوع الآن', style: FinanceText.page),
            SizedBox(
              width: 260,
              child: TextField(
                controller: _paidNow,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ المدفوع الآن'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Text('المتبقي: ${(_grandTotalPreview - (double.tryParse(_paidNow.text) ?? 0)).clamp(0, double.infinity).toStringAsFixed(2)} SYP'),
            const SizedBox(height: FinanceSpace.md),
            Wrap(
              spacing: FinanceSpace.sm,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ كمسودة'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => context.go(AppRoutes.financePurchases),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
            const SizedBox(height: FinanceSpace.xl),
          ],
        ),
      ),
    );
  }

  Widget _categoryDropdown() => DropdownButtonFormField<int>(
    key: const ValueKey<String>('purchase-expense-category-dropdown'),
    initialValue: _expenseCategoryId,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'فئة المصروف'),
    items: _expenseCategories
        .map(
          (ExpenseCategory c) =>
              DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
        )
        .toList(growable: false),
    onChanged: (int? v) => setState(() => _expenseCategoryId = v),
  );

  Widget _accountDropdown() => DropdownButtonFormField<int>(
    key: const ValueKey<String>('purchase-asset-account-dropdown'),
    initialValue: _assetAccountId,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: _purchaseType == 'asset'
          ? 'حساب الأصل الثابت'
          : 'الحساب المحاسبي',
    ),
    items: _accounts
        .map(
          (FinancialAccount a) => DropdownMenuItem<int>(
            value: a.id,
            child: Text('${a.code} — ${a.nameAr}'),
          ),
        )
        .toList(growable: false),
    onChanged: (int? v) => setState(() => _assetAccountId = v),
  );
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.internalReference,
    required this.suppliers,
    required this.branches,
    required this.supplierInternalReference,
    required this.supplierLocked,
    required this.supplierId,
    required this.branchId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.notes,
    required this.onSupplierChanged,
    required this.onBranchChanged,
    required this.onPickInvoiceDate,
    required this.onPickDueDate,
  });

  /// System-generated (e.g. PI-2026-000001) — read-only, assigned by the backend on save.
  final String? internalReference;
  final String? supplierInternalReference;
  final bool supplierLocked;
  final List<Supplier> suppliers;
  final List<Branch> branches;
  final int? supplierId;
  final int? branchId;
  final TextEditingController invoiceNumber;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final TextEditingController notes;
  final ValueChanged<int?> onSupplierChanged;
  final ValueChanged<int?> onBranchChanged;
  final VoidCallback onPickInvoiceDate;
  final VoidCallback onPickDueDate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Wrap(
      spacing: FinanceSpace.lg,
      runSpacing: FinanceSpace.md,
      children: <Widget>[
        SizedBox(
          width: 200,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'رقم الفاتورة'),
            child: Text(
              internalReference ?? 'سيتم إنشاؤه تلقائيًا عند الحفظ',
              style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<int>(
            initialValue: supplierId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المورد'),
            items: suppliers
                .map(
                  (Supplier s) =>
                      DropdownMenuItem<int>(value: s.id, child: Text(s.name)),
                )
                .toList(growable: false),
            onChanged: supplierLocked ? null : onSupplierChanged,
          ),
        ),
        SizedBox(
          width: 200,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'الرقم الداخلي للمورد'),
            child: Text(
              supplierInternalReference ?? 'يتم إنشاؤه تلقائيًا عند الحفظ',
              style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int>(
            initialValue: branchId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'الفرع (اختياري: كل الفروع)',
            ),
            items: branches
                .map(
                  (Branch b) =>
                      DropdownMenuItem<int>(value: b.id, child: Text(b.name)),
                )
                .toList(growable: false),
            onChanged: onBranchChanged,
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: invoiceNumber,
            decoration: const InputDecoration(labelText: 'مرجع فاتورة المورد الأصلية (اختياري)'),
          ),
        ),
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: onPickInvoiceDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 15),
            label: Text('تاريخ الفاتورة: ${_isoDate(invoiceDate)}'),
          ),
        ),
        SizedBox(
          width: 200,
          child: OutlinedButton.icon(
            onPressed: onPickDueDate,
            icon: const Icon(Icons.event_outlined, size: 15),
            label: Text('تاريخ الاستحقاق: ${_isoDate(dueDate)}'),
          ),
        ),
        SizedBox(
          width: 320,
          child: TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'البيان / ملاحظات'),
          ),
        ),
      ],
    ),
  );
}

class _LineEditorRow extends StatelessWidget {
  const _LineEditorRow({
    required this.draft,
    required this.warehouses,
    required this.showWarehouse,
    required this.onRemove,
    required this.onChanged,
  });
  final _LineDraft draft;
  final List<WarehouseLocation> warehouses;
  final bool showWarehouse;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.md),
    decoration: BoxDecoration(
      color: FinanceColors.workspace,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
    ),
    child: Wrap(
      spacing: FinanceSpace.sm,
      runSpacing: FinanceSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (draft.lineType == 'inventory')
          SizedBox(
            width: 240,
            child: InventoryItemSearchField(
              repository: serviceLocator<InventoryRepository>(),
              selected: draft.item,
              width: 240,
              onSelected: (InventoryItem? i) {
                if (draft.item?.id != i?.id) {
                  draft.purchaseUnit.text = i == null
                      ? ''
                      : (i.purchaseUnit.isNotEmpty ? i.purchaseUnit : i.unit);
                }
                draft.item = i;
                onChanged();
              },
            ),
          )
        else
          SizedBox(
            width: 260,
            child: TextField(
              controller: draft.description,
              decoration: const InputDecoration(
                labelText: 'البيان',
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        if (draft.lineType == 'inventory' && showWarehouse)
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue:
                  warehouses.any(
                    (WarehouseLocation w) => w.id == draft.warehouseId,
                  )
                  ? draft.warehouseId
                  : null,
              decoration: const InputDecoration(
                labelText: 'مخزن الاستلام',
                isDense: true,
              ),
              items: warehouses
                  .map(
                    (WarehouseLocation w) => DropdownMenuItem<int>(
                      value: w.id,
                      child: Text(
                        w.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? value) {
                draft.warehouseId = value;
                onChanged();
              },
            ),
          ),
        if (draft.lineType == 'inventory')
          SizedBox(
            width: 130,
            child: _PurchaseUnitField(
              item: draft.item,
              controller: draft.purchaseUnit,
              onChanged: onChanged,
            ),
          ),
        SizedBox(
          width: 90,
          child: _numberField('الكمية', draft.quantity, onChanged),
        ),
        SizedBox(
          width: 120,
          child: _numberField('تكلفة الوحدة', draft.unitCost, onChanged),
        ),
        SizedBox(
          width: 150,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: _numberField('الخصم', draft.discountValue, onChanged),
              ),
              const SizedBox(width: 4),
              _DiscountTypeToggle(
                discountType: draft.discountType,
                onChanged: (String type) {
                  draft.discountType = type;
                  onChanged();
                },
              ),
            ],
          ),
        ),
        SizedBox(
          width: 90,
          child: _numberField('الضريبة', draft.tax, onChanged),
        ),
        SizedBox(
          width: 120,
          child: _ReadOnlyAmount(
            label: 'إجمالي الصنف',
            value: draft.grossAmount,
            emphasize: true,
          ),
        ),
        SizedBox(
          width: 120,
          child: _ReadOnlyAmount(
            label: 'الإجمالي الصافي',
            value: draft.lineTotal,
            emphasize: true,
          ),
        ),
        if (onRemove != null)
          IconButton(
            tooltip: 'حذف البند',
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: FinanceColors.danger,
            ),
            onPressed: onRemove,
          ),
      ],
    ),
  );

  Widget _numberField(
    String label,
    TextEditingController controller,
    VoidCallback onChanged,
  ) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: (_) => onChanged(),
  );
}

/// Purchase unit as a select instead of free text: the base unit plus any
/// unit conversions configured for the selected item (e.g. "carton" when a
/// carton→bottle conversion exists) — never an arbitrary typed string.
class _PurchaseUnitField extends StatefulWidget {
  const _PurchaseUnitField({
    required this.item,
    required this.controller,
    required this.onChanged,
  });
  final InventoryItem? item;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  State<_PurchaseUnitField> createState() => _PurchaseUnitFieldState();
}

class _PurchaseUnitFieldState extends State<_PurchaseUnitField> {
  List<String> _options = const <String>[];
  int? _loadedForItemId;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant _PurchaseUnitField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoad();
  }

  void _maybeLoad() {
    final InventoryItem? item = widget.item;
    if (item == null) {
      if (_loadedForItemId != null) {
        setState(() {
          _options = const <String>[];
          _loadedForItemId = null;
        });
      }
      return;
    }
    if (_loadedForItemId == item.id) return;
    _loadedForItemId = item.id;
    if (widget.controller.text.trim().isEmpty) {
      widget.controller.text = item.purchaseUnit.isNotEmpty
          ? item.purchaseUnit
          : item.unit;
    }
    setState(() => _options = <String>[item.unit]);
    serviceLocator<InventoryRepository>()
        .unitConversions(item.id)
        .then((List<InventoryItemUnitConversion> conversions) {
          if (!mounted || _loadedForItemId != item.id) return;
          final Set<String> units = <String>{item.unit};
          for (final InventoryItemUnitConversion c in conversions) {
            if (c.active) units.add(c.sourceUnit);
          }
          setState(() => _options = units.toList(growable: false));
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final String current = widget.controller.text.trim();
    final List<String> options = current.isEmpty || _options.contains(current)
        ? _options
        : <String>[current, ..._options];

    return DropdownButtonFormField<String>(
      key: ValueKey<String>('purchase-unit-${widget.item?.id}-$current'),
      initialValue: options.contains(current)
          ? current
          : (options.isEmpty ? null : options.first),
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'الوحدة', isDense: true),
      items: options
          .map((String u) => DropdownMenuItem<String>(value: u, child: Text(u)))
          .toList(growable: false),
      onChanged: options.isEmpty
          ? null
          : (String? value) {
              if (value == null) return;
              widget.controller.text = value;
              widget.onChanged();
            },
    );
  }
}

class _DiscountTypeToggle extends StatelessWidget {
  const _DiscountTypeToggle({
    required this.discountType,
    required this.onChanged,
  });
  final String discountType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ToggleButtons(
    isSelected: <bool>[discountType == 'fixed', discountType == 'percentage'],
    onPressed: (int index) => onChanged(index == 0 ? 'fixed' : 'percentage'),
    borderRadius: BorderRadius.circular(FinanceRadius.control),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
    children: const <Widget>[
      Tooltip(message: 'مبلغ ثابت', child: Icon(Icons.attach_money, size: 16)),
      Tooltip(message: 'نسبة مئوية', child: Icon(Icons.percent, size: 16)),
    ],
  );
}

class _ReadOnlyAmount extends StatelessWidget {
  const _ReadOnlyAmount({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label, isDense: true),
    child: Text(
      value.toStringAsFixed(2),
      style: emphasize
          ? FinanceText.body.copyWith(fontWeight: FontWeight.w700)
          : FinanceText.body,
    ),
  );
}

class _ChargeEditorRow extends StatelessWidget {
  const _ChargeEditorRow({
    required this.draft,
    required this.expenseCategories,
    required this.allowCapitalize,
    required this.onRemove,
    required this.onChanged,
  });
  final _ChargeDraft draft;
  final List<ExpenseCategory> expenseCategories;
  final bool allowCapitalize;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.md),
    decoration: BoxDecoration(
      color: FinanceColors.workspace,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
    ),
    child: Wrap(
      spacing: FinanceSpace.sm,
      runSpacing: FinanceSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 220,
          child: TextField(
            controller: draft.description,
            decoration: InputDecoration(
              labelText: 'نوع / الوصف',
              isDense: true,
              suffixIcon: PopupMenuButton<String>(
                tooltip: 'أنواع سريعة',
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                onSelected: (String value) {
                  draft.description.text = value;
                  onChanged();
                },
                itemBuilder: (BuildContext context) => kQuickChargeTypes
                    .map(
                      (String type) =>
                          PopupMenuItem<String>(value: type, child: Text(type)),
                    )
                    .toList(growable: false),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        SizedBox(
          width: 150,
          child: ToggleButtons(
            isSelected: <bool>[
              draft.treatment == 'capitalize',
              draft.treatment == 'expense',
            ],
            onPressed: (int index) {
              if (index == 0 && !allowCapitalize) return;
              draft.treatment = index == 0 ? 'capitalize' : 'expense';
              onChanged();
            },
            borderRadius: BorderRadius.circular(FinanceRadius.control),
            constraints: const BoxConstraints(minWidth: 70, minHeight: 40),
            children: <Widget>[
              Opacity(
                opacity: allowCapitalize ? 1 : 0.4,
                child: const Tooltip(
                  message: 'إضافة إلى تكلفة المخزون',
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('للمخزون', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              const Tooltip(
                message: 'مصروف مستقل',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('مصروف', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
        if (draft.treatment == 'expense')
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<int>(
              initialValue: draft.expenseCategoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'فئة المصروف',
                isDense: true,
              ),
              items: expenseCategories
                  .map(
                    (ExpenseCategory c) => DropdownMenuItem<int>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? v) {
                draft.expenseCategoryId = v;
                onChanged();
              },
            ),
          ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: draft.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ',
              isDense: true,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: draft.tax,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'الضريبة',
              isDense: true,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        IconButton(
          tooltip: 'حذف التكلفة',
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
            color: FinanceColors.danger,
          ),
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

class _InvoiceSummaryCard extends StatelessWidget {
  const _InvoiceSummaryCard({
    required this.linesNetTotal,
    required this.discountType,
    required this.discountValueController,
    required this.onDiscountTypeChanged,
    required this.onDiscountChanged,
    required this.invoiceDiscountAmount,
    required this.netAfterDiscount,
    required this.charges,
    required this.chargesAmountTotal,
    required this.chargesTaxTotal,
    required this.linesTaxTotal,
    required this.grandTotal,
  });
  final double linesNetTotal;
  final String discountType;
  final TextEditingController discountValueController;
  final ValueChanged<String> onDiscountTypeChanged;
  final VoidCallback onDiscountChanged;
  final double invoiceDiscountAmount;
  final double netAfterDiscount;
  final List<_ChargeDraft> charges;
  final double chargesAmountTotal;
  final double chargesTaxTotal;
  final double linesTaxTotal;
  final double grandTotal;

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 130,
              child: TextField(
                controller: discountValueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'خصم الفاتورة',
                  isDense: true,
                ),
                onChanged: (_) => onDiscountChanged(),
              ),
            ),
            const SizedBox(width: FinanceSpace.sm),
            _DiscountTypeToggle(
              discountType: discountType,
              onChanged: onDiscountTypeChanged,
            ),
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        const Divider(),
        _summaryRow('إجمالي البنود بعد خصومات البند', _fmt(linesNetTotal)),
        _summaryRow('خصم الفاتورة', '-${_fmt(invoiceDiscountAmount)}'),
        _summaryRow('صافي البنود', _fmt(netAfterDiscount), emphasize: true),
        if (charges.isNotEmpty) ...<Widget>[
          const SizedBox(height: FinanceSpace.sm),
          Text(
            'تكاليف إضافية:',
            style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          ...charges.map(
            (_ChargeDraft c) => _summaryRow(
              c.description.text.trim().isEmpty
                  ? '—'
                  : c.description.text.trim(),
              _fmt(c.amountValue),
            ),
          ),
          _summaryRow('إجمالي التكاليف الإضافية', _fmt(chargesAmountTotal)),
        ],
        _summaryRow('الضريبة', _fmt(linesTaxTotal + chargesTaxTotal)),
        const Divider(),
        _summaryRow(
          'الإجمالي النهائي',
          _fmt(grandTotal),
          emphasize: true,
          big: true,
        ),
      ],
    ),
  );

  Widget _summaryRow(
    String label,
    String value, {
    bool emphasize = false,
    bool big = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: emphasize
                ? FinanceText.body.copyWith(fontWeight: FontWeight.w700)
                : FinanceText.body,
          ),
        ),
        Text(
          value,
          style: big
              ? FinanceText.page.copyWith(fontWeight: FontWeight.w800)
              : (emphasize
                    ? FinanceText.body.copyWith(fontWeight: FontWeight.w700)
                    : FinanceText.body),
        ),
      ],
    ),
  );
}
