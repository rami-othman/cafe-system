class SalesDraftLineInput {
  const SalesDraftLineInput({required this.quantity, required this.unitPrice, this.discountType, this.discountValue = 0});
  final double quantity;
  final double unitPrice;
  final String? discountType;
  final double discountValue;
}

/// Display only. The backend recalculates and validates every posted amount.
class SalesDraftPreview {
  SalesDraftPreview({required List<SalesDraftLineInput> lines, required this.invoiceDiscountType, required this.invoiceDiscountValue, required this.charges, required this.taxRate})
      : gross = lines.fold(0, (sum, line) => sum + line.quantity * line.unitPrice),
        lineDiscount = lines.fold(0, (sum, line) {
          final gross = line.quantity * line.unitPrice;
          return sum + (line.discountType == 'percent' ? gross * line.discountValue / 100 : line.discountType == 'fixed' ? line.discountValue : 0);
        });

  final double gross;
  final double lineDiscount;
  final double charges;
  final double taxRate;
  final String? invoiceDiscountType;
  final double invoiceDiscountValue;

  double get invoiceDiscount {
    final net = gross - lineDiscount;
    return invoiceDiscountType == 'percent' ? net * invoiceDiscountValue / 100 : invoiceDiscountType == 'fixed' ? invoiceDiscountValue : 0;
  }
  double get tax => (gross - lineDiscount - invoiceDiscount + charges) * taxRate;
  double get total => gross - lineDiscount - invoiceDiscount + charges + tax;
}
