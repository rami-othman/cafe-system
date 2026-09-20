import 'package:flutter/material.dart';

import '../models/purchasing_models.dart';

class PurchasePostingChoice {
  const PurchasePostingChoice(this.financialLocationId, this.paidAmount);

  final int? financialLocationId;
  final String paidAmount;
}

Future<PurchasePostingChoice?> showPurchasePostingDialog(
  BuildContext context, {
  required PurchasePostingPreview preview,
  required String branchName,
  String? paidAmount,
}) {
  int? selected = preview.financialLocationId;
  final selectable = preview.cashSourceMode == 'selectable';
  final amountController = TextEditingController(text: paidAmount ?? preview.amount);
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المدفوع الآن'),
                  onChanged: (_) => setState(() {}),
                ),
                Text('المتبقي: ${(double.tryParse(preview.amount) ?? 0) - (double.tryParse(amountController.text) ?? 0)} SYP'),
                if (selectable)
                  DropdownButtonFormField<int>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الصندوق'),
                    items: preview.allowedCashLocations
                        .map((location) => DropdownMenuItem<int>(
                              value: location.id,
                              child: Text(location.name, overflow: TextOverflow.ellipsis),
                            ))
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
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: ((double.tryParse(amountController.text) ?? -1) < 0 ||
                        (double.tryParse(amountController.text) ?? 0) > (double.tryParse(preview.amount) ?? 0) ||
                        (selectable && selected == null && (double.tryParse(amountController.text) ?? 0) > 0))
                ? null
                : () => Navigator.pop(dialog, PurchasePostingChoice(selected, amountController.text)),
            child: const Text('ترحيل فاتورة الشراء'),
          ),
        ],
      ),
    ),
  );
}
