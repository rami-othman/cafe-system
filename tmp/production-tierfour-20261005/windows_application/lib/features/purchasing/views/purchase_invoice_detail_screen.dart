import 'package:flutter/material.dart';
import '../../manufacturing/widgets/factory_currency_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../app/purchase_route_scope.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../controllers/purchasing_cubit.dart';
import '../models/purchasing_models.dart';
import '../widgets/purchase_error_messages.dart';
import '../widgets/purchase_type_label.dart';
import '../widgets/purchase_posting_dialog.dart';
import '../widgets/purchase_payment_dialog.dart';

/// Purchase Invoice detail (`/finance/purchases/:id`). This is the same
/// Supplier Invoice record shown at `/finance/suppliers/:id` — just a
/// Purchasing-flavored presentation of it, with lines and (Phase 2) a real
/// receiving workflow: "استلام مخزون" opens the Goods Receipt screen, and
/// "سجل الاستلامات" shows every receipt already posted against this invoice.
class PurchaseInvoiceDetailScreen extends StatefulWidget {
  const PurchaseInvoiceDetailScreen({super.key, required this.purchaseId});
  final int purchaseId;

  @override
  State<PurchaseInvoiceDetailScreen> createState() =>
      _PurchaseInvoiceDetailScreenState();
}

class _PurchaseInvoiceDetailScreenState
    extends State<PurchaseInvoiceDetailScreen> {
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
      final PurchaseInvoice purchase = await _cubit.repository.getPurchase(
        widget.purchaseId,
      );
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
    PurchasePostingPreview preview;
    try {
      preview = await _cubit.repository.getPostingPreview(widget.purchaseId);
    } catch (error) {
      _showError(error);
      return;
    }
    if (!mounted) return;
    final choice = await showPurchasePostingDialog(
      context,
      preview: preview,
      branchName: _purchase?.branchName ?? "—",
      invoiceDate: _purchase?.invoiceDate ?? '—',
    );
    if (choice == null) return;
    setState(() => _busy = true);
    try {
      final (PurchaseInvoice updated, List<Map<String, dynamic>> warnings) =
          await _cubit.repository.postPurchase(
        widget.purchaseId,
        'purchase-post-${widget.purchaseId}-${DateTime.now().millisecondsSinceEpoch}',
        financialLocationId: choice.financialLocationId,
        paymentMethodId: choice.paymentMethodId,
        paidAmount: choice.paidAmount,
        paymentDate: choice.paymentDate,
        receiptDate: choice.receiptDate,
      );
      if (!mounted) return;
      setState(() {
        _purchase = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ترحيل فاتورة الشراء واستلام المواد ودفع ${updated.paidAmount} SYP بنجاح.',
          ),
        ),
      );
      for (final Map<String, dynamic> warning in warnings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text('${warning['message'] ?? ''}'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(error);
    }
  }

  Future<void> _pay() async {
    final PurchaseInvoice? current = _purchase;
    if (current == null) return;
    final bool? paid = await showPurchasePaymentDialog(context, purchase: current);
    if (paid != true || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل دفعة للمورد على هذه الفاتورة.')),
    );
  }

  Future<void> _reverse() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('إلغاء ترحيل الفاتورة'),
        content: const Text(
          'سيتم إنشاء قيد عكسي متوازن. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinanceColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final PurchaseInvoice updated = await _cubit.repository.reversePurchase(
        widget.purchaseId,
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

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(purchaseLineErrorMessage(error))));
  }

  @override
  Widget build(BuildContext context) {
    if (_purchase == null && _error == null) {
      return const FinanceShell(
        title: 'المشتريات',
        child: FinanceLoadingState(label: 'جارٍ تحميل الفاتورة…'),
      );
    }
    if (_purchase == null) {
      return FinanceShell(
        title: 'المشتريات',
        child: FinanceErrorState(
          message: 'تعذّر تحميل فاتورة الشراء.',
          onRetry: _load,
        ),
      );
    }
    final PurchaseInvoice p = _purchase!;
    return FinanceShell(
      title: p.invoiceNumber,
      subtitle: p.internalReference,
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => context.go(PurchaseRouteScope.of(context).listPath),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('كل المشتريات'),
        ),
        if (p.allowedActions.contains('edit')) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          OutlinedButton.icon(
            onPressed: () => context.go(
              '${PurchaseRouteScope.of(context).listPath}/${p.id}/edit',
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('تعديل'),
          ),
        ],
        if (p.allowedActions.contains('post')) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          ElevatedButton.icon(
            onPressed: _busy ? null : _post,
            style: ElevatedButton.styleFrom(
              backgroundColor: FinanceColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('ترحيل'),
          ),
        ],
        if (p.allowedActions.contains('pay') &&
            p.branchType != 'factory' &&
            (double.tryParse(p.remainingAmount.replaceAll(',', '')) ?? 0) > 0) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          ElevatedButton.icon(
            onPressed: _busy ? null : _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor: FinanceColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.payments_outlined, size: 16),
            label: const Text('دفع للمورد'),
          ),
        ],
        if (p.allowedActions.contains('reverse')) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _reverse,
            style: OutlinedButton.styleFrom(
              foregroundColor: FinanceColors.danger,
            ),
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('إلغاء الترحيل'),
          ),
        ],
        if (p.canReceive) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          ElevatedButton.icon(
            onPressed: _busy
                ? null
                : () => context.go(
                    '${PurchaseRouteScope.of(context).listPath}/${p.id}/receive',
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinanceColors.success,
              foregroundColor: Colors.white,
            ),
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
              actions: <Widget>[
                PurchaseTypeBadge(purchaseType: p.purchaseType),
              ],
            ),
            FactoryCurrencyDocument(
              snapshot: p.factoryCurrency,
              baseAmount: p.totalAmount,
            ),
            const SizedBox(height: FinanceSpace.lg),
            _SummaryArea(purchase: p),
            const SizedBox(height: FinanceSpace.xl),
            _SectionTitle(
              'بنود الفاتورة',
              count: p.lines.isEmpty ? null : p.lines.length,
            ),
            if (p.lines.isEmpty)
              Container(
                width: double.infinity,
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
            const SizedBox(height: FinanceSpace.xl),
            _ReceiptsAndPayments(purchase: p),
            const SizedBox(height: FinanceSpace.xl),
          ],
        ),
      ),
    );
  }
}

/// Section heading used across the page: title + optional count chip.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.count});
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FinanceSpace.md),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: FinanceText.page),
        if (count != null) ...<Widget>[
          const SizedBox(width: FinanceSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: FinanceColors.card,
              border: Border.all(color: FinanceColors.border),
              borderRadius: BorderRadius.circular(FinanceRadius.pill),
            ),
            child: Text('$count', style: FinanceText.small),
          ),
        ],
      ],
    ),
  );
}

/// Titled card holding label / value rows (one row per fact).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.items,
    this.footer,
  });
  final String title;
  final IconData icon;
  final List<FinanceInfoItem> items;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(FinanceSpace.lg),
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
            Icon(icon, size: 18, color: FinanceColors.primary),
            const SizedBox(width: FinanceSpace.sm),
            Text(title, style: FinanceText.page.copyWith(fontSize: 15.5)),
          ],
        ),
        const Divider(height: FinanceSpace.xl),
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == items.length - 1 ? 0 : FinanceSpace.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 120,
                  child: Text(items[i].label, style: FinanceText.label),
                ),
                Expanded(child: Text(items[i].value, style: FinanceText.body)),
              ],
            ),
          ),
        if (footer != null) ...<Widget>[
          const SizedBox(height: FinanceSpace.md),
          footer!,
        ],
      ],
    ),
  );
}

/// Top of the page: document facts + payment/receiving cards on the right,
/// totals panel on the left (stacked on narrow windows).
class _SummaryArea extends StatelessWidget {
  const _SummaryArea({required this.purchase});
  final PurchaseInvoice purchase;

  @override
  Widget build(BuildContext context) {
    final PurchaseInvoice p = purchase;
    final Widget documentCard = _InfoCard(
      title: 'بيانات المستند',
      icon: Icons.description_outlined,
      items: <FinanceInfoItem>[
        FinanceInfoItem('حالة المستند', switch (p.documentStatus) {
          'posted' => 'مُرحّل',
          'cancelled' => 'ملغي',
          _ => 'مسودة',
        }),
        FinanceInfoItem('الفرع', p.branchName ?? 'كل الفروع'),
        if (p.hasInventoryLines)
          FinanceInfoItem('المخزن', p.warehouseName ?? '—'),
        FinanceInfoItem(
          'تاريخ الفاتورة',
          p.isBackdated ? '${p.invoiceDate} (بتاريخ سابق)' : p.invoiceDate,
        ),
        if (p.isBackdated)
          FinanceInfoItem('سبب التاريخ السابق', p.backdateReason ?? '—'),
        FinanceInfoItem(
          'الحساب',
          '${p.debitAccountCode ?? ''} ${p.debitAccountName ?? ''}'.trim(),
        ),
        FinanceInfoItem('أنشأ بواسطة', p.createdByName ?? '—'),
        FinanceInfoItem('تاريخ الإنشاء', p.createdAt ?? '—'),
        FinanceInfoItem('تاريخ الترحيل', p.postedAt ?? '—'),
      ],
    );
    final Widget paymentCard = _InfoCard(
      title: 'الدفع',
      icon: Icons.payments_outlined,
      items: <FinanceInfoItem>[
        FinanceInfoItem('طريقة الدفع', switch (p.paymentTerms) {
          'cash' => 'كاش',
          'sham_cash' => 'شام كاش',
          _ => 'أجل',
        }),
        FinanceInfoItem('حالة الدفع', switch (p.paymentStatus) {
          'paid' => 'مدفوع بالكامل',
          'partial' => 'مدفوع جزئياً',
          'unpaid' => 'غير مدفوع',
          _ => 'لا ينطبق',
        }),
        if (p.paymentTerms == 'sham_cash')
          FinanceInfoItem('رقم عملية شام كاش', p.paymentReference ?? '—'),
        if (p.isCreditTerms) FinanceInfoItem('تاريخ الاستحقاق', p.dueDate),
      ],
    );
    final Widget? receivingCard = p.hasInventoryLines
        ? _InfoCard(
            title: 'استلام المخزون',
            icon: Icons.inventory_2_outlined,
            items: <FinanceInfoItem>[
              FinanceInfoItem(
                'حالة الاستلام',
                receiptStatusLabel(p.receiptStatus),
              ),
              if (p.receiptStatus == 'received')
                FinanceInfoItem(
                  'تم استلام',
                  p.lines
                      .where((PurchaseInvoiceLine line) => line.isInventory)
                      .map(
                        (PurchaseInvoiceLine line) =>
                            '${line.receivedQuantity} ${line.baseUnit ?? line.purchaseUnit ?? ''} ${line.inventoryItemName ?? line.description}',
                      )
                      .join('\n'),
                ),
            ],
            footer: p.receiptStatus == 'received' && p.documentStatus == 'posted'
                ? const Text(
                    'لا يمكن إلغاء الفاتورة بعد استلام المخزون. يجب إرجاع حركة المخزون أولاً.',
                    style: FinanceText.small,
                  )
                : null,
          )
        : null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool wide = box.maxWidth >= 1000;
        final Widget totals = _TotalsPanel(purchase: p);
        final Widget right = Column(
          children: <Widget>[
            paymentCard,
            if (receivingCard != null) ...<Widget>[
              const SizedBox(height: FinanceSpace.lg),
              receivingCard,
            ],
          ],
        );
        if (!wide) {
          return Column(
            children: <Widget>[
              totals,
              const SizedBox(height: FinanceSpace.lg),
              documentCard,
              const SizedBox(height: FinanceSpace.lg),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 5, child: documentCard),
            const SizedBox(width: FinanceSpace.lg),
            Expanded(flex: 4, child: right),
            const SizedBox(width: FinanceSpace.lg),
            SizedBox(width: 320, child: totals),
          ],
        );
      },
    );
  }
}

/// Receipts log and linked payments, side by side on wide windows.
class _ReceiptsAndPayments extends StatelessWidget {
  const _ReceiptsAndPayments({required this.purchase});
  final PurchaseInvoice purchase;

  @override
  Widget build(BuildContext context) {
    final PurchaseInvoice p = purchase;
    final Widget receipts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(
          'سجل الاستلامات',
          count: p.receipts.isEmpty ? null : p.receipts.length,
        ),
        if (p.receipts.isEmpty)
          const SizedBox(
            height: 110,
            child: FinanceEmptyState(
              message: 'لم يتم إنشاء أي استلام مخزون بعد لهذه الفاتورة',
            ),
          )
        else
          _ReceiptsTable(receipts: p.receipts),
      ],
    );
    final Widget payments = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(
          'الدفعات المرتبطة',
          count: p.payments.isEmpty ? null : p.payments.length,
        ),
        if (p.payments.isEmpty)
          const SizedBox(
            height: 110,
            child: FinanceEmptyState(
              message: 'لا توجد دفعات مسجلة على هذه الفاتورة',
            ),
          )
        else
          _PaymentsTable(payments: p.payments),
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        if (!p.hasInventoryLines) return payments;
        if (box.maxWidth < 1100) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              receipts,
              const SizedBox(height: FinanceSpace.xl),
              payments,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: receipts),
            const SizedBox(width: FinanceSpace.lg),
            Expanded(child: payments),
          ],
        );
      },
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
                      color: l.hasRemainingToReceive
                          ? FinanceColors.warning
                          : FinanceColors.success,
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
    headers: const <String>[
      'رقم الاستلام',
      'التاريخ',
      'الفرع',
      'عدد البنود',
      'أنشأ بواسطة',
      'الحالة',
    ],
    minWidth: 600,
    onRowTap: (int index) => context.go(
      '${PurchaseRouteScope.of(context).receiptsPath}/${receipts[index].id}',
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
    width: double.infinity,
    padding: const EdgeInsets.all(FinanceSpace.lg),
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
            const Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: FinanceColors.primary,
            ),
            const SizedBox(width: FinanceSpace.sm),
            Text('الإجماليات', style: FinanceText.page.copyWith(fontSize: 15.5)),
          ],
        ),
        const Divider(height: FinanceSpace.xl),
        _totalsRow('المجموع الفرعي', purchase.subtotal),
        _totalsRow('الضريبة', purchase.taxAmount),
        const Divider(height: FinanceSpace.xl),
        _totalsRow('الإجمالي', purchase.totalAmount, emphasize: true),
        const SizedBox(height: FinanceSpace.xs),
        _totalsRow('المدفوع', purchase.paidAmount),
        _totalsRow(
          'المتبقي',
          purchase.remainingAmount,
          danger: purchase.isOverdue,
        ),
        const SizedBox(height: FinanceSpace.md),
        Wrap(
          spacing: FinanceSpace.sm,
          runSpacing: FinanceSpace.sm,
          children: <Widget>[
            FinanceStatusBadge(status: purchase.documentStatus),
            if (purchase.paymentStatus != 'not_applicable')
              FinanceStatusBadge(status: purchase.paymentStatus),
          ],
        ),
      ],
    ),
  );

  Widget _totalsRow(
    String label,
    String value, {
    bool emphasize = false,
    bool danger = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: emphasize
              ? FinanceText.page.copyWith(fontSize: 16)
              : FinanceText.label,
        ),
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
    headers: const <String>[
      'رقم الدفعة',
      'سند الدفع',
      'التاريخ',
      'الحالة',
      'المبلغ',
    ],
    minWidth: 520,
    rows: payments
        .map(
          (PurchasePayment pay) => <Widget>[
            FinanceReference(reference: pay.paymentNumber),
            pay.voucherId == null
                ? const Text('—')
                : InkWell(
                    onTap: () => context.go(
                      '${AppRoutes.financeVouchers}/${pay.voucherId}',
                    ),
                    child: FinanceReference(
                      reference: pay.voucherNumber ?? 'سند الدفع',
                    ),
                  ),
            Text(pay.paymentDate, style: FinanceText.small),
            FinanceStatusBadge(status: pay.status),
            FinanceAmount(value: pay.amount),
          ],
        )
        .toList(growable: false),
  );
}
