import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/sales/models/sales_models.dart';
import 'package:windows_application/features/sales/models/sales_draft_preview.dart';

void main() {
  test('sales material exposes only the units returned for that item', () {
    final material = SalesMaterial.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'بن خام',
      'baseUnit': 'kilogram',
      'units': <String>['kilogram', 'gram'],
    });
    expect(material.baseUnit, 'kilogram');
    expect(material.units, <String>['kilogram', 'gram']);
  });

  test('invoice detail retains the selected material and selling unit', () {
    final line = SalesInvoiceLine.fromJson(<String, dynamic>{
      'productId': null,
      'inventoryItemId': 7,
      'unitCode': 'gram',
      'productName': 'بن خام',
      'quantity': '250.000',
      'unitPrice': '0.04',
      'taxTotal': '0.00',
      'total': '10.00',
    });
    expect(line.inventoryItemId, 7);
    expect(line.unitCode, 'gram');
    expect(line.quantity, '250.000');
  });

  test('draft preview applies line and invoice discounts once', () {
    final preview = SalesDraftPreview(
      lines: const <SalesDraftLineInput>[SalesDraftLineInput(quantity: 2, unitPrice: 50, discountType: 'fixed', discountValue: 5)],
      invoiceDiscountType: 'fixed', invoiceDiscountValue: 10, charges: 0, taxRate: 0.05,
    );
    expect(preview.gross, 100);
    expect(preview.lineDiscount, 5);
    expect(preview.invoiceDiscount, 10);
    expect(preview.tax, 4.25);
    expect(preview.total, 89.25);
  });
}
