import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../controllers/purchasing_cubit.dart';
import '../models/purchasing_models.dart';
import '../widgets/purchase_type_label.dart';

/// Purchase Invoice detail (`/finance/purchases/:id`). This is the same
/// Supplier Invoice record shown at `/finance/suppliers/:id` — just a
/// Purchasing-flavored presentation of it, with lines and (Phase 2) a real
/// receiving workflow: "استلام مخزون" opens the Goods Receipt screen, and
/// "سجل الاستلامات" shows every receipt already posted against this invoice.
class PurchaseInvoiceDetailScreen extends StatefulWidget {
  const PurchaseInvoiceDetailScreen({super.key, required this.purchaseId});
  final int purchaseId;

  @override
  State<PurchaseInvoiceDetailScreen> createState() => _PurchaseInvoiceDetailScreenState();
}

class _PurchaseInvoiceDetailScreenState extends State<PurchaseInvoiceDetailScreen> {
  PurchaseInvoice? _purchase;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  PurchasingCubit get _cubit => context.read<PurchasingCubit>();

  Future<void> _load() async {
    try {
      final PurchaseInvoice purchase = await _cubit.repository.getPurchase(widget.purchaseId);
      if (!mounted) return;
      setState(() {
        _purchase = purchase;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _post() async {
    setState(() => _busy = true);
    try {
      final PurchaseInvoice updated = await _cubit.repository.postPurchase(
        widget.purchaseId,
        'purchase-post-${widget.purchaseId}-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() {
        _purchase = updated;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(error);
    }
  }

  Future<void> _reverse() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('إلغاء ترحيل الفاتورة'),
        content: const Text('سيتم إنشاء قيد عكسي متوازن. لا يمكن التراجع عن هذا الإجراء.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.danger, foregroundColor: Colors.white),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final PurchaseInvoice updated = await _cubit.repository.reversePurchase(widget.purchaseId);
      if (!mounted) return;
      setState(() {
        _purchase = updated;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  @override
  Widget build(BuildContext context) {
    if (_purchase == null && _error == null) {
      return const FinanceShell(title: 'المشتريات', child: FinanceLoadingState(label: 'جارٍ تحميل الفاتورة…'));
    }
    if (_purchase == null) {
      return FinanceShell(
        title: 'المشتريات',
        child: FinanceErrorState(message: 'تعذّر تحميل فاتورة الشراء.', onRetry: _load),
      );
    }
    final PurchaseInvoice p = _purchase!;
    return FinanceShell(
      title: p.invoiceNumber,
      subtitle: p.internalReference,
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.financePurchases),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('كل المشتريات'),
        ),
        if (p.allowedActions.contains('edit')) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          OutlinedButton.icon(
            onPressed: () => context.go('${AppRoutes.financePurchases}/${p.id}/edit'),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('تعديل'),
          ),
        ],
        if (p.allowedActions.contains('post')) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          ElevatedButton.icon(
            onPressed: _busy ? null : _post,
            style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.primary, foregroundColor: Colors.white),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('ترحيل'),
          ),
        ],
        if (p.allowedActions.contains('reverse')) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _reverse,
            style: OutlinedButton.styleFrom(foregroundColor: FinanceColors.danger),
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('إلغاء الترحيل'),
          ),
        ],
        if (p.canReceive) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          ElevatedButton.icon(
            onPressed: _busy
                ? null
                : () => context.go('${AppRoutes.financePurchases}/${p.id}/receive'),
            style: ElevatedButton.styleFrom(backgroundColor: FinanceColors.success, foregroundColor: Colors.white),
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const Text('استلام مخزون'),
          ),
        ],
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FinanceEntityHeader(
              title: p.supplierName,
              reference: p.invoiceNumber,
              status: p.documentStatus,
              actions: <Widget>[PurchaseTypeBadge(purchaseType: p.purchaseType)],
            ),
            const SizedBox(height: FinanceSpace.lg),
            FinanceInfoGrid(
              items: <FinanceInfoItem>[
                FinanceInfoItem('الفرع', p.branchName ?? 'كل الفروع'),
                FinanceInfoItem('تاريخ الفاتورة', p.invoiceDate),
                FinanceInfoItem('تاريخ الاستحقاق', p.dueDate),
                FinanceInfoItem('الحساب', '${p.debitAccountCode ?? ''} ${p.debitAccountName ?? ''}'.trim()),
                FinanceInfoItem('أنشأ بواسطة', p.createdByName ?? '—'),
                FinanceInfoItem('تاريخ الترحيل', p.postedAt ?? '—'),
                if (p.hasInventoryLines)
                  FinanceInfoItem('حالة الاستلام', receiptStatusLabel(p.receiptStatus)),
              ],
            ),
            const SizedBox(height: FinanceSpace.lg),
            Text('بنود الفاتورة', style: FinanceText.page),
            const SizedBox(height: FinanceSpace.md),
            if (p.lines.isEmpty)
              Container(
                padding: const EdgeInsets.all(FinanceSpace.lg),
                decoration: BoxDecoration(
                  color: FinanceColors.card,
                  border: Border.all(color: FinanceColors.border),
                  borderRadius: BorderRadius.circular(FinanceRadius.card),
                ),
                child: Text(
                  'هذه فاتورة إجمالية بدون بنود تفصيلية (تم إنشاؤها قبل تفعيل بنود المشتريات).',
                  style: FinanceText.body,
                ),
              )
            else
              _LinesTable(lines: p.lines),
            if (p.hasInventoryLines) ...<Widget>[
              const SizedBox(height: FinanceSpace.lg),
              Text('سجل الاستلامات', style: FinanceText.page),
              const SizedBox(height: FinanceSpace.md),
              if (p.receipts.isEmpty)
                const SizedBox(
                  height: 100,
                  child: FinanceEmptyState(message: 'لم يتم إنشاء أي استلام مخزون بعد لهذه الفاتورة'),
                )
              else
                _ReceiptsTable(receipts: p.receipts),
            ],
            const SizedBox(height: FinanceSpace.lg),
            _TotalsPanel(purchase: p),
            const SizedBox(height: FinanceSpace.lg),
            Text('الدفعات المرتبطة', style: FinanceText.page),
            const SizedBox(height: FinanceSpace.md),
            if (p.payments.isEmpty)
              const SizedBox(
                height: 120,
                child: FinanceEmptyState(message: 'لا توجد دفعات مسجلة على هذه الفاتورة'),
              )
            else
              _PaymentsTable(payments: p.payments),
          ],
        ),
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines});
  final List<PurchaseInvoiceLine> lines;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>[
      'البيان',
      'الصنف / النوع',
      'الوحدة',
      'الكمية',
      'سعر الوحدة',
      'الخصم',
      'الضريبة',
      'الإجمالي',
      'حالة الاستلام',
    ],
    minWidth: 980,
    rows: lines
        .map(
          (PurchaseInvoiceLine l) => <Widget>[
            Text(l.description, style: FinanceText.body),
            PurchaseTypeBadge(purchaseType: l.lineType),
            Text(l.purchaseUnit ?? l.baseUnit ?? '—', style: FinanceText.small),
            Text(l.quantity, style: FinanceText.body),
            FinanceAmount(value: l.unitPrice),
            FinanceAmount(value: l.discountAmount),
            FinanceAmount(value: l.taxAmount),
            FinanceAmount(value: l.lineTotal),
            l.isInventory
                ? Text(
                    '${l.receivedQuantity} / ${l.baseQuantity ?? l.quantity} — متبقي ${l.remainingQuantity ?? '—'}',
                    style: FinanceText.small.copyWith(
                      color: l.hasRemainingToReceive ? FinanceColors.warning : FinanceColors.success,
                    ),
                  )
                : Text('—', style: FinanceText.small),
          ],
        )
        .toList(growable: false),
  );
}

class _ReceiptsTable extends StatelessWidget {
  const _ReceiptsTable({required this.receipts});
  final List<PurchaseReceiptSummary> receipts;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>['رقم الاستلام', 'التاريخ', 'الفرع', 'عدد البنود', 'أنشأ بواسطة', 'الحالة'],
    minWidth: 760,
    onRowTap: (int index) => context.go(
      '${AppRoutes.financePurchaseReceipts}/${receipts[index].id}',
    ),
    rows: receipts
        .map(
          (PurchaseReceiptSummary r) => <Widget>[
            FinanceReference(reference: r.receiptNumber),
            Text(r.receiptDate, style: FinanceText.small),
            Text(r.branchName, style: FinanceText.small),
            Text('${r.lineCount}', style: FinanceText.body),
            Text(r.createdByName ?? '—', style: FinanceText.small),
            GoodsReceiptStatusBadge(status: r.status),
          ],
        )
        .toList(growable: false),
  );
}

class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({required this.purchase});
  final PurchaseInvoice purchase;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _totalsRow('المجموع الفرعي', purchase.subtotal),
        _totalsRow('الضريبة', purchase.taxAmount),
        const Divider(height: FinanceSpace.lg),
        _totalsRow('الإجمالي', purchase.totalAmount, emphasize: true),
        _totalsRow('المدفوع', purchase.paidAmount),
        _totalsRow('المتبقي', purchase.remainingAmount, danger: purchase.isOverdue),
        const SizedBox(height: FinanceSpace.sm),
        Wrap(
          spacing: FinanceSpace.sm,
          children: <Widget>[
            FinanceStatusBadge(status: purchase.documentStatus),
            if (purchase.paymentStatus != 'not_applicable')
              FinanceStatusBadge(status: purchase.paymentStatus),
          ],
        ),
      ],
    ),
  );

  Widget _totalsRow(String label, String value, {bool emphasize = false, bool danger = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: emphasize ? FinanceText.page : FinanceText.label,
        ),
        const SizedBox(width: FinanceSpace.lg),
        FinanceAmount(
          value: value,
          color: danger ? FinanceColors.danger : null,
        ),
      ],
    ),
  );
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.payments});
  final List<PurchasePayment> payments;

  @override
  Widget build(BuildContext context) => FinanceTable(
    headers: const <String>['رقم الدفعة', 'التاريخ', 'الحالة', 'المبلغ'],
    minWidth: 640,
    rows: payments
        .map(
          (PurchasePayment pay) => <Widget>[
            FinanceReference(reference: pay.paymentNumber),
            Text(pay.paymentDate, style: FinanceText.small),
            FinanceStatusBadge(status: pay.status),
            FinanceAmount(value: pay.amount),
          ],
        )
        .toList(growable: false),
  );
}
