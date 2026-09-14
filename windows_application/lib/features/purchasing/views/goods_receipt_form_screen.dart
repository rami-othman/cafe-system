import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/services/service_locator.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../../inventory/models/inventory_models.dart';
import '../../inventory/repositories/inventory_repository.dart';
import '../controllers/purchasing_cubit.dart';
import '../models/purchasing_models.dart';

/// استلام مخزون (`/finance/purchases/:purchaseId/receive`) — Purchasing
/// Phase 2. Creates a Goods Receipt against a posted Supplier Invoice's
/// inventory lines and immediately posts it (two real backend calls: create
/// the draft, then post it — see PurchasingRepository). The invoice's own AP
/// journal is never touched here; this screen only ever moves physical
/// stock through the backend's existing stock_in pathway.
class GoodsReceiptFormScreen extends StatefulWidget {
  const GoodsReceiptFormScreen({super.key, required this.purchaseId});
  final int purchaseId;

  @override
  State<GoodsReceiptFormScreen> createState() => _GoodsReceiptFormScreenState();
}

class _ReceiptLineDraft {
  _ReceiptLineDraft(this.invoiceLine, {this.warehouseId});
  final PurchaseInvoiceLine invoiceLine;
  final TextEditingController quantity = TextEditingController();
  int? warehouseId;

  void dispose() => quantity.dispose();
}

class _GoodsReceiptFormScreenState extends State<GoodsReceiptFormScreen> {
  PurchaseInvoice? _purchase;
  List<WarehouseLocation> _warehouses = const <WarehouseLocation>[];
  final Map<int, InventoryBalance> _balanceCache = <int, InventoryBalance>{};
  final List<_ReceiptLineDraft> _lines = <_ReceiptLineDraft>[];
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  DateTime _receiptDate = DateTime.now();

  bool _loading = true;
  bool _saving = false;
  Object? _loadError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    for (final _ReceiptLineDraft l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  PurchasingCubit get _cubit => context.read<PurchasingCubit>();
  InventoryRepository get _inventory => serviceLocator<InventoryRepository>();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _cubit.repository.getPurchase(widget.purchaseId),
        _inventory.warehouses(),
      ]);
      if (!mounted) return;
      final PurchaseInvoice purchase = results[0] as PurchaseInvoice;
      setState(() {
        _purchase = purchase;
        _warehouses = results[1] as List<WarehouseLocation>;
        for (final _ReceiptLineDraft l in _lines) {
          l.dispose();
        }
        _lines
          ..clear()
          ..addAll(
            purchase.lines
                .where((PurchaseInvoiceLine l) => l.hasRemainingToReceive)
                .map(
                  (PurchaseInvoiceLine l) => _ReceiptLineDraft(
                    l,
                    warehouseId: l.warehouseId,
                  )..quantity.text = l.remainingQuantity ?? '0',
                ),
          );
        _loading = false;
      });
      unawaited(_refreshBalancePreviews());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _refreshBalancePreviews() async {
    final Set<int> warehouseIds = _lines
        .map((_ReceiptLineDraft l) => l.warehouseId)
        .whereType<int>()
        .toSet();
    for (final int warehouseId in warehouseIds) {
      try {
        final List<InventoryBalance> balances = await _inventory.balances(
          warehouseId: warehouseId,
        );
        if (!mounted) return;
        setState(() {
          for (final InventoryBalance b in balances) {
            _balanceCache['$warehouseId:${b.itemId}'.hashCode] = b;
          }
        });
      } catch (_) {
        // The preview is a convenience only; the backend recomputes the
        // real effect on posting regardless of whether this lookup succeeds.
      }
    }
  }

  InventoryBalance? _balanceFor(int warehouseId, int itemId) =>
      _balanceCache['$warehouseId:$itemId'.hashCode];

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _receiptDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _receiptDate = picked);
  }

  String? _validate() {
    if (_lines.isEmpty) return 'لا توجد بنود مخزون قابلة للاستلام في هذه الفاتورة.';
    for (final _ReceiptLineDraft line in _lines) {
      final double qty = double.tryParse(line.quantity.text.trim()) ?? 0;
      final double remaining =
          double.tryParse(line.invoiceLine.remainingQuantity ?? '0') ?? 0;
      if (qty <= 0) return 'الكمية المستلمة يجب أن تكون أكبر من صفر لكل بند.';
      if (qty > remaining + 0.0005) {
        return 'الكمية المستلمة لا يمكن أن تتجاوز الكمية المتبقية (${line.invoiceLine.remainingQuantity}).';
      }
      if (line.warehouseId == null) return 'اختر مستودعاً لكل بند.';
    }
    return null;
  }

  Future<void> _submit() async {
    final String? error = _validate();
    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final int stamp = DateTime.now().microsecondsSinceEpoch;
      final PurchaseReceipt draft = await _cubit.repository.createReceipt(
        widget.purchaseId,
        <String, dynamic>{
          'receiptDate': _isoDate(_receiptDate),
          if (_reference.text.trim().isNotEmpty) 'reference': _reference.text.trim(),
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
          'idempotencyKey': 'grn-create-$stamp',
          'lines': _lines
              .map(
                (_ReceiptLineDraft l) => <String, dynamic>{
                  'supplierInvoiceLineId': l.invoiceLine.id,
                  'quantity': l.quantity.text.trim(),
                  'warehouseId': l.warehouseId,
                },
              )
              .toList(growable: false),
        },
      );
      final PurchaseReceipt posted = await _cubit.repository.postReceipt(
        draft.id,
        'grn-post-$stamp',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم ترحيل الاستلام رقم ${posted.receiptNumber} بنجاح.')),
      );
      context.go('${AppRoutes.financePurchases}/${widget.purchaseId}');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const FinanceShell(title: 'استلام مخزون', child: FinanceLoadingState());
    }
    if (_loadError != null || _purchase == null) {
      return FinanceShell(
        title: 'استلام مخزون',
        child: FinanceErrorState(message: 'تعذّر تحميل بيانات الفاتورة.', onRetry: _load),
      );
    }
    final PurchaseInvoice purchase = _purchase!;
    return FinanceShell(
      title: 'استلام مخزون',
      subtitle: 'فاتورة ${purchase.invoiceNumber} — ${purchase.supplierName}',
      actions: <Widget>[
        TextButton(
          onPressed: _saving
              ? null
              : () => context.go('${AppRoutes.financePurchases}/${widget.purchaseId}'),
          child: const Text('إلغاء'),
        ),
        const SizedBox(width: FinanceSpace.sm),
        ElevatedButton.icon(
          onPressed: _saving || _lines.isEmpty ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.inventory_2_outlined, size: 16),
          label: const Text('ترحيل الاستلام'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_formError != null) ...<Widget>[
              FinanceAlertBanner(message: _formError!, tone: FinanceTone.danger),
              const SizedBox(height: FinanceSpace.md),
            ],
            FinanceInfoGrid(
              items: <FinanceInfoItem>[
                FinanceInfoItem('فاتورة الشراء', purchase.invoiceNumber),
                FinanceInfoItem('المورد', purchase.supplierName),
                FinanceInfoItem('الفرع', purchase.branchName ?? 'كل الفروع'),
              ],
            ),
            const SizedBox(height: FinanceSpace.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('تاريخ الاستلام: ${_isoDate(_receiptDate)}'),
                  ),
                ),
                const SizedBox(width: FinanceSpace.md),
                Expanded(
                  child: TextField(
                    controller: _reference,
                    decoration: const InputDecoration(labelText: 'مرجع'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: FinanceSpace.lg),
            Text('بنود الاستلام', style: FinanceText.page),
            const SizedBox(height: FinanceSpace.sm),
            if (_lines.isEmpty)
              const FinanceAlertBanner(
                message: 'لا توجد بنود مخزون متبقية للاستلام في هذه الفاتورة.',
              )
            else
              ...List<Widget>.generate(
                _lines.length,
                (int index) => Padding(
                  padding: const EdgeInsets.only(bottom: FinanceSpace.md),
                  child: _ReceiptLineCard(
                    draft: _lines[index],
                    warehouses: _warehouses,
                    balanceLookup: _balanceFor,
                    onChanged: () {
                      setState(() {});
                      unawaited(_refreshBalancePreviews());
                    },
                  ),
                ),
              ),
            const SizedBox(height: FinanceSpace.xl),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLineCard extends StatelessWidget {
  const _ReceiptLineCard({
    required this.draft,
    required this.warehouses,
    required this.balanceLookup,
    required this.onChanged,
  });

  final _ReceiptLineDraft draft;
  final List<WarehouseLocation> warehouses;
  final InventoryBalance? Function(int warehouseId, int itemId) balanceLookup;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final PurchaseInvoiceLine line = draft.invoiceLine;
    final InventoryBalance? balance = draft.warehouseId != null && line.inventoryItemId != null
        ? balanceLookup(draft.warehouseId!, line.inventoryItemId!)
        : null;
    final double enteredQuantity = double.tryParse(draft.quantity.text.trim()) ?? 0;
    final double? preview = balance == null || enteredQuantity <= 0
        ? null
        : _estimatedNewWac(
            currentQuantity: double.tryParse(balance.quantity) ?? 0,
            currentCost: double.tryParse(balance.cost) ?? 0,
            incomingQuantity: enteredQuantity,
            incomingCost: _estimatedUnitCost(line),
          );

    return Container(
      padding: const EdgeInsets.all(FinanceSpace.md),
      decoration: BoxDecoration(
        color: FinanceColors.card,
        border: Border.all(color: FinanceColors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  line.inventoryItemName ?? line.description,
                  style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'المتبقي: ${line.remainingQuantity ?? '0'} ${line.purchaseUnit ?? line.baseUnit ?? ''}',
                style: FinanceText.small,
              ),
            ],
          ),
          const SizedBox(height: FinanceSpace.sm),
          Wrap(
            spacing: FinanceSpace.md,
            runSpacing: FinanceSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 160,
                child: TextField(
                  controller: draft.quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'الكمية المستلمة الآن (${line.purchaseUnit ?? line.baseUnit ?? ''})',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int>(
                  initialValue: draft.warehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المستودع'),
                  items: warehouses
                      .map(
                        (WarehouseLocation w) =>
                            DropdownMenuItem<int>(value: w.id, child: Text(w.displayName)),
                      )
                      .toList(growable: false),
                  onChanged: (int? v) {
                    draft.warehouseId = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          if (balance != null) ...<Widget>[
            const SizedBox(height: FinanceSpace.sm),
            Container(
              padding: const EdgeInsets.all(FinanceSpace.sm),
              decoration: BoxDecoration(
                color: FinanceColors.workspace,
                borderRadius: BorderRadius.circular(FinanceRadius.control),
              ),
              child: Text(
                'المخزون الحالي: ${balance.quantity} — بعد الاستلام: '
                '${(double.tryParse(balance.quantity) ?? 0) + enteredQuantity}\n'
                'متوسط التكلفة الحالي: ${balance.cost}'
                '${preview == null ? '' : ' — المتوسط التقديري بعد الاستلام: ${preview.toStringAsFixed(4)}'}'
                ' (معاينة تقديرية فقط، يُعاد احتسابها فعلياً عند الترحيل)',
                style: FinanceText.small.copyWith(color: FinanceColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Client-side preview only — mirrors the backend's own formula (unit
  /// price ÷ conversion factor) so the estimate is meaningful, but the
  /// server always recomputes this for real inside the posting transaction.
  double _estimatedUnitCost(PurchaseInvoiceLine line) {
    final double price = double.tryParse(line.unitPrice) ?? 0;
    final double factor = double.tryParse(line.conversionFactor ?? '1') ?? 1;
    return factor <= 0 ? price : price / factor;
  }

  double _estimatedNewWac({
    required double currentQuantity,
    required double currentCost,
    required double incomingQuantity,
    required double incomingCost,
  }) {
    final double totalQuantity = currentQuantity + incomingQuantity;
    if (totalQuantity <= 0) return incomingCost;
    return ((currentQuantity * currentCost) + (incomingQuantity * incomingCost)) /
        totalQuantity;
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
