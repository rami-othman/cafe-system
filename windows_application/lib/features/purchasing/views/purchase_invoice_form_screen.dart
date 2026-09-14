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
import '../widgets/purchase_type_label.dart';

/// Create/edit a purchase invoice (`/finance/purchases/new`,
/// `/finance/purchases/:id/edit`). This posts to the exact same
/// `finance/supplier-invoices` endpoint the legacy total-only dialog on the
/// Supplier Profile screen uses — there is only one way to create a Supplier
/// Invoice, this screen just adds a real line editor in front of it. Phase 1
/// enforces one line type per invoice, matching the backend exactly; mixed
/// invoices are deferred, not half-built.
class PurchaseInvoiceFormScreen extends StatefulWidget {
  const PurchaseInvoiceFormScreen({super.key, this.editId, this.preselectedSupplierId});
  final int? editId;
  final int? preselectedSupplierId;

  @override
  State<PurchaseInvoiceFormScreen> createState() => _PurchaseInvoiceFormScreenState();
}

class _LineDraft {
  _LineDraft(this.lineType);
  final String lineType;
  InventoryItem? item;
  final TextEditingController description = TextEditingController();
  final TextEditingController purchaseUnit = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController unitPrice = TextEditingController(text: '0');
  final TextEditingController discount = TextEditingController(text: '0');
  final TextEditingController tax = TextEditingController(text: '0');
  int? warehouseId;

  double _num0(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  double get lineTotal {
    final double gross = _num0(quantity) * _num0(unitPrice);
    return (gross - _num0(discount) + _num0(tax)).clamp(0, double.infinity);
  }

  void dispose() {
    description.dispose();
    purchaseUnit.dispose();
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
    tax.dispose();
  }
}

class _PurchaseInvoiceFormScreenState extends State<PurchaseInvoiceFormScreen> {
  final TextEditingController _invoiceNumber = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  int? _supplierId;
  int? _branchId;
  String _purchaseType = 'inventory';
  int? _expenseCategoryId;
  int? _assetAccountId;
  final List<_LineDraft> _lines = <_LineDraft>[];

  List<Supplier> _suppliers = const <Supplier>[];
  List<Branch> _branches = const <Branch>[];
  List<InventoryItem> _items = const <InventoryItem>[];
  List<ExpenseCategory> _expenseCategories = const <ExpenseCategory>[];
  List<FinancialAccount> _accounts = const <FinancialAccount>[];
  PurchaseInvoice? _editing;

  bool _loadingReferenceData = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editId != null;

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
    for (final _LineDraft line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  PurchasingCubit get _cubit => context.read<PurchasingCubit>();
  FinanceSetupCubit get _financeCubit => context.read<FinanceSetupCubit>();

  Future<void> _loadReferenceData() async {
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _financeCubit.repository.getFinancePage('finance/suppliers', queryParameters: const <String, dynamic>{'perPage': 200}),
        _financeCubit.repository.getBranches(),
        serviceLocator<InventoryRepository>().items(activeOnly: true),
        _financeCubit.repository.getExpenseCategories(),
        _financeCubit.repository.getAccounts(),
        if (_isEdit) _cubit.repository.getPurchase(widget.editId!),
      ]);
      if (!mounted) return;
      final dynamic suppliersPage = results[0];
      setState(() {
        _suppliers = (suppliersPage.items as List<dynamic>)
            .map((dynamic j) => Supplier.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList(growable: false);
        _branches = results[1] as List<Branch>;
        _items = results[2] as List<InventoryItem>;
        _expenseCategories = results[3] as List<ExpenseCategory>;
        _accounts = (results[4] as List<FinancialAccount>)
            .where((FinancialAccount a) => a.accountGroup == 'assets' && a.code != '1100')
            .toList(growable: false);
        if (_isEdit) {
          _editing = results[5] as PurchaseInvoice;
          _applyEditingData(_editing!);
        }
        _loadingReferenceData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loadingReferenceData = false;
      });
    }
  }

  void _applyEditingData(PurchaseInvoice p) {
    _invoiceNumber.text = p.invoiceNumber;
    _notes.text = p.notes ?? '';
    _invoiceDate = DateTime.tryParse(p.invoiceDate) ?? _invoiceDate;
    _dueDate = DateTime.tryParse(p.dueDate) ?? _dueDate;
    _supplierId = p.supplierId;
    _branchId = p.branchId;
    _expenseCategoryId = p.purchaseType == 'expense' ? null : null;
    _assetAccountId = (p.purchaseType == 'asset' || p.purchaseType == 'other') ? p.debitAccountId : null;
    _purchaseType = p.purchaseType == 'other' && p.lines.isEmpty ? 'other' : p.purchaseType;
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
                draft.unitPrice.text = l.unitPrice;
                draft.discount.text = l.discountAmount;
                draft.tax.text = l.taxAmount;
                draft.warehouseId = l.warehouseId;
                if (l.inventoryItemId != null) {
                  final Iterable<InventoryItem> match =
                      _items.where((InventoryItem i) => i.id == l.inventoryItemId);
                  draft.item = match.isEmpty ? null : match.first;
                }
                return draft;
              }),
      );
  }

  void _addLine() => setState(() => _lines.add(_LineDraft(_purchaseType)));
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

  double get _totalPreview => _lines.fold<double>(0, (double sum, _LineDraft l) => sum + l.lineTotal);

  String? _validate() {
    if (_supplierId == null) return 'اختر المورد.';
    if (_purchaseType == 'expense' && _expenseCategoryId == null) return 'اختر فئة المصروف.';
    if ((_purchaseType == 'asset' || _purchaseType == 'other') && _assetAccountId == null) {
      return _purchaseType == 'asset' ? 'اختر حساب الأصل الثابت.' : 'اختر الحساب المحاسبي.';
    }
    if (_lines.isEmpty) return 'أضف بنداً واحداً على الأقل.';
    for (final _LineDraft line in _lines) {
      if (line.lineType == 'inventory' && line.item == null) return 'اختر صنف المخزون لكل بند.';
      if (line.lineType != 'inventory' && line.description.text.trim().isEmpty) return 'أدخل بيان كل بند.';
      if ((double.tryParse(line.quantity.text.trim()) ?? 0) <= 0) return 'الكمية يجب أن تكون أكبر من صفر.';
      if ((double.tryParse(line.unitPrice.text.trim()) ?? 0) <= 0) return 'سعر الوحدة يجب أن يكون أكبر من صفر.';
    }
    return null;
  }

  Future<void> _save() async {
    final String? validationError = _validate();
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
        if (_branchId != null) 'branchId': _branchId,
        'invoiceNumber': _invoiceNumber.text.trim(),
        'invoiceDate': _isoDate(_invoiceDate),
        'dueDate': _isoDate(_dueDate),
        'invoiceType': _purchaseType == 'inventory'
            ? 'inventory'
            : _purchaseType == 'expense'
            ? 'expense'
            : 'other',
        if (_purchaseType == 'expense') 'expenseCategoryId': _expenseCategoryId,
        if (_purchaseType == 'asset' || _purchaseType == 'other') 'debitAccountId': _assetAccountId,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'lines': _lines
            .map(
              (_LineDraft l) => <String, dynamic>{
                'lineType': l.lineType,
                'description': l.lineType == 'inventory'
                    ? (l.item?.name ?? '')
                    : l.description.text.trim(),
                if (l.lineType == 'inventory') 'inventoryItemId': l.item!.id,
                if (l.lineType == 'inventory' && l.purchaseUnit.text.trim().isNotEmpty)
                  'purchaseUnit': l.purchaseUnit.text.trim(),
                'quantity': l.quantity.text.trim(),
                'unitPrice': l.unitPrice.text.trim(),
                'discountAmount': l.discount.text.trim().isEmpty ? '0' : l.discount.text.trim(),
                'taxAmount': l.tax.text.trim().isEmpty ? '0' : l.tax.text.trim(),
              },
            )
            .toList(growable: false),
        if (!_isEdit)
          'idempotencyKey': 'purchase-create-${DateTime.now().microsecondsSinceEpoch}',
      };
      final PurchaseInvoice saved = await _cubit.repository.savePurchase(payload, id: widget.editId);
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
      return const FinanceShell(title: 'فاتورة شراء جديدة', child: FinanceLoadingState());
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
          onRetry: () => context.go('${AppRoutes.financePurchases}/${widget.editId}'),
        ),
      );
    }
    return FinanceShell(
      title: _isEdit ? 'تعديل فاتورة شراء' : 'فاتورة شراء جديدة',
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => context.go(AppRoutes.financePurchases),
          child: const Text('إلغاء'),
        ),
        const SizedBox(width: FinanceSpace.sm),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_outlined, size: 16),
          label: const Text('حفظ'),
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
              suppliers: _suppliers,
              branches: _branches,
              supplierId: _supplierId,
              branchId: _branchId,
              invoiceNumber: _invoiceNumber,
              invoiceDate: _invoiceDate,
              dueDate: _dueDate,
              notes: _notes,
              onSupplierChanged: (int? v) => setState(() => _supplierId = v),
              onBranchChanged: (int? v) => setState(() => _branchId = v),
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
            if (_purchaseType == 'asset' || _purchaseType == 'other') ...<Widget>[
              const SizedBox(height: FinanceSpace.md),
              _accountDropdown(),
            ],
            const SizedBox(height: FinanceSpace.lg),
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
                padding: const EdgeInsets.only(bottom: FinanceSpace.sm),
                child: _LineEditorRow(
                  draft: _lines[index],
                  items: _items,
                  onRemove: _lines.length > 1 ? () => _removeLine(index) : null,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
            const SizedBox(height: FinanceSpace.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                'الإجمالي التقديري: ${_totalPreview.toStringAsFixed(2)}',
                style: FinanceText.page,
              ),
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
        .map((ExpenseCategory c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
        .toList(growable: false),
    onChanged: (int? v) => setState(() => _expenseCategoryId = v),
  );

  Widget _accountDropdown() => DropdownButtonFormField<int>(
    key: const ValueKey<String>('purchase-asset-account-dropdown'),
    initialValue: _assetAccountId,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: _purchaseType == 'asset' ? 'حساب الأصل الثابت' : 'الحساب المحاسبي',
    ),
    items: _accounts
        .map(
          (FinancialAccount a) =>
              DropdownMenuItem<int>(value: a.id, child: Text('${a.code} — ${a.nameAr}')),
        )
        .toList(growable: false),
    onChanged: (int? v) => setState(() => _assetAccountId = v),
  );
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.suppliers,
    required this.branches,
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
          width: 260,
          child: DropdownButtonFormField<int>(
            initialValue: supplierId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المورد'),
            items: suppliers
                .map((Supplier s) => DropdownMenuItem<int>(value: s.id, child: Text(s.name)))
                .toList(growable: false),
            onChanged: onSupplierChanged,
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int>(
            initialValue: branchId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الفرع (اختياري: كل الفروع)'),
            items: branches
                .map((Branch b) => DropdownMenuItem<int>(value: b.id, child: Text(b.name)))
                .toList(growable: false),
            onChanged: onBranchChanged,
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: invoiceNumber,
            decoration: const InputDecoration(labelText: 'رقم فاتورة المورد'),
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
    required this.items,
    required this.onRemove,
    required this.onChanged,
  });
  final _LineDraft draft;
  final List<InventoryItem> items;
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
            width: 220,
            child: DropdownButtonFormField<InventoryItem>(
              initialValue: draft.item,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الصنف', isDense: true),
              items: items
                  .map(
                    (InventoryItem i) => DropdownMenuItem<InventoryItem>(
                      value: i,
                      child: Text(i.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (InventoryItem? i) {
                draft.item = i;
                if (i != null && draft.purchaseUnit.text.trim().isEmpty) {
                  draft.purchaseUnit.text = i.purchaseUnit.isNotEmpty ? i.purchaseUnit : i.unit;
                }
                onChanged();
              },
            ),
          )
        else
          SizedBox(
            width: 260,
            child: TextField(
              controller: draft.description,
              decoration: const InputDecoration(labelText: 'البيان', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
        if (draft.lineType == 'inventory')
          SizedBox(
            width: 100,
            child: TextField(
              controller: draft.purchaseUnit,
              decoration: const InputDecoration(labelText: 'الوحدة', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
        SizedBox(width: 90, child: _numberField('الكمية', draft.quantity, onChanged)),
        SizedBox(width: 110, child: _numberField('سعر الوحدة', draft.unitPrice, onChanged)),
        SizedBox(width: 90, child: _numberField('الخصم', draft.discount, onChanged)),
        SizedBox(width: 90, child: _numberField('الضريبة', draft.tax, onChanged)),
        SizedBox(
          width: 120,
          child: Text(
            'الإجمالي: ${draft.lineTotal.toStringAsFixed(2)}',
            style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (onRemove != null)
          IconButton(
            tooltip: 'حذف البند',
            icon: const Icon(Icons.delete_outline, size: 18, color: FinanceColors.danger),
            onPressed: onRemove,
          ),
      ],
    ),
  );

  Widget _numberField(String label, TextEditingController controller, VoidCallback onChanged) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (_) => onChanged(),
      );
}
