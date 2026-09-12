import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../controllers/purchasing_cubit.dart';
import '../models/purchasing_models.dart';
import '../widgets/purchase_type_label.dart';

/// Read-only Goods Receipt detail (`/finance/purchase-receipts/:receiptId`).
/// A posted receipt is immutable — this screen never offers an edit action.
class GoodsReceiptDetailScreen extends StatefulWidget {
  const GoodsReceiptDetailScreen({super.key, required this.receiptId});
  final int receiptId;

  @override
  State<GoodsReceiptDetailScreen> createState() => _GoodsReceiptDetailScreenState();
}

class _GoodsReceiptDetailScreenState extends State<GoodsReceiptDetailScreen> {
  PurchaseReceipt? _receipt;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final PurchaseReceipt receipt =
          await context.read<PurchasingCubit>().repository.getReceipt(widget.receiptId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_receipt == null && _error == null) {
      return const FinanceShell(title: 'الاستلام', child: FinanceLoadingState());
    }
    if (_receipt == null) {
      return FinanceShell(
        title: 'الاستلام',
        child: FinanceErrorState(message: 'تعذّر تحميل بيانات الاستلام.', onRetry: _load),
      );
    }
    final PurchaseReceipt r = _receipt!;
    return FinanceShell(
      title: r.receiptNumber,
      subtitle: 'فاتورة ${r.invoiceNumber}',
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => context.go('/finance/purchases/${r.supplierInvoiceId}'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('فاتورة الشراء'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FinanceEntityHeader(
              title: r.supplierName,
              reference: r.receiptNumber,
              status: r.status,
              actions: <Widget>[GoodsReceiptStatusBadge(status: r.status)],
            ),
            const SizedBox(height: FinanceSpace.lg),
            FinanceInfoGrid(
              items: <FinanceInfoItem>[
                FinanceInfoItem('فاتورة الشراء', r.invoiceNumber),
                FinanceInfoItem('الفرع', r.branchName ?? 'المستودع المركزي'),
                FinanceInfoItem('تاريخ الاستلام', r.receiptDate),
                FinanceInfoItem('المرجع', r.reference ?? '—'),
                FinanceInfoItem('أنشأ بواسطة', r.createdByName ?? '—'),
                FinanceInfoItem('تاريخ الترحيل', r.postedAt ?? '—'),
              ],
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...<Widget>[
              const SizedBox(height: FinanceSpace.md),
              Text(r.notes!, style: FinanceText.body),
            ],
            const SizedBox(height: FinanceSpace.lg),
            Text('بنود الاستلام', style: FinanceText.page),
            const SizedBox(height: FinanceSpace.md),
            if (r.lines.isEmpty)
              const SizedBox(
                height: 100,
                child: FinanceEmptyState(message: 'لا توجد بنود'),
              )
            else
              FinanceTable(
                headers: const <String>['الصنف', 'المستودع', 'الكمية المستلمة', 'الكمية الأساسية', 'تكلفة الوحدة'],
                minWidth: 760,
                rows: r.lines
                    .map(
                      (PurchaseReceiptLine l) => <Widget>[
                        Text(l.itemName, style: FinanceText.body),
                        Text(l.warehouseName, style: FinanceText.small),
                        Text('${l.receivedQuantity} ${l.receivedUnit}', style: FinanceText.body),
                        Text('${l.baseQuantity} ${l.baseUnit}', style: FinanceText.small),
                        FinanceAmount(value: l.unitCost),
                      ],
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}
