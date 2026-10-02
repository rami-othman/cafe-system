import 'package:flutter/material.dart';

import '../models/purchasing_models.dart';

class PurchasePostingChoice {
  const PurchasePostingChoice(
    this.financialLocationId,
    this.paidAmount, {
    this.paymentMethodId,
    required this.paymentDate,
    required this.receiptDate,
  });

  final int? financialLocationId;
  final String paidAmount;

  /// Sham Cash purchases: the chosen Sham Cash method (each one is its own box).
  final int? paymentMethodId;

  /// Client decision 2026-09-28 (T7): a purchase's receipt and payment
  /// always land on the invoice's own accounting date — kept here (equal to
  /// [invoiceDate]) only for API-shape compatibility; the backend now
  /// ignores whatever it is sent and always uses the invoice date itself.
  final String paymentDate;
  final String receiptDate;
}

Future<PurchasePostingChoice?> showPurchasePostingDialog(
  BuildContext context, {
  required PurchasePostingPreview preview,
  required String branchName,
  required String invoiceDate,
  String? paidAmount,
}) {
  int? selected = preview.financialLocationId;
  final sham = preview.cashSourceMode == 'sham_cash';
  int? shamSelected = preview.shamCashMethods.isEmpty
      ? null
      : preview.shamCashMethods.first.id;
  final selectable = preview.cashSourceMode == 'selectable';
  final amountController = TextEditingController(
    text: paidAmount ?? preview.amount,
  );
  return showDialog<PurchasePostingChoice>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('ترحيل واستلام ودفع فاتورة الشراء'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي الفاتورة: ${preview.amount} SYP'),
                Text('الفرع: $branchName'),
                TextField(
                  controller: amountController,
                  readOnly: paidAmount != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'المدفوع الآن'),
                  onChanged: (_) => setState(() {}),
                ),
                Text(
                  'المتبقي: ${(double.tryParse(preview.amount) ?? 0) - (double.tryParse(amountController.text) ?? 0)} SYP',
                ),
                const SizedBox(height: 8),
                Text(
                  'التاريخ المحاسبي: $invoiceDate (الاستلام والدفع بنفس التاريخ)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (sham)
                  DropdownButtonFormField<int>(
                    initialValue: shamSelected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'صندوق شام كاش (يُدفع منه)',
                    ),
                    items: preview.shamCashMethods
                        .map(
                          (method) => DropdownMenuItem<int>(
                            value: method.id,
                            child: Text(
                              method.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => shamSelected = value),
                  )
                else if (selectable)
                  DropdownButtonFormField<int>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الصندوق'),
                    items: preview.allowedCashLocations
                        .map(
                          (location) => DropdownMenuItem<int>(
                            value: location.id,
                            child: Text(
                              location.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => selected = value),
                  )
                else
                  Text('الصندوق: ${preview.financialLocationName ?? 'غير محدد'}'),
                if (preview.shiftNumber != null)
                  Text('الوردية: ${preview.shiftNumber}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed:
                ((double.tryParse(amountController.text) ?? -1) < 0 ||
                    (double.tryParse(amountController.text) ?? 0) >
                        (double.tryParse(preview.amount) ?? 0) ||
                    (sham &&
                        shamSelected == null &&
                        (double.tryParse(amountController.text) ?? 0) > 0) ||
                    (selectable &&
                        selected == null &&
                        (double.tryParse(amountController.text) ?? 0) > 0))
                ? null
                : () => Navigator.pop(
                    dialog,
                    PurchasePostingChoice(
                      sham ? null : selected,
                      amountController.text,
                      paymentMethodId: sham ? shamSelected : null,
                      paymentDate: invoiceDate,
                      receiptDate: invoiceDate,
                    ),
                  ),
            child: const Text('ترحيل فاتورة الشراء'),
          ),
        ],
      ),
    ),
  );
}
