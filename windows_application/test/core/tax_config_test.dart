import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/utils/tax_formatter.dart';
import 'package:windows_application/features/discounts/widgets/discount_pos_preview_card.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/order_receipt_mapper.dart';
import 'package:windows_application/features/pos/widgets/order_totals_panel.dart';

void main() {
  test('branch parses the backend tax rate and falls back when absent', () {
    expect(
      Branch.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Main',
        'taxRate': 0.075,
      }).taxRate,
      0.075,
    );
    expect(
      Branch.fromJson(<String, dynamic>{'id': 1, 'name': 'Main'}).taxRate,
      0.08,
    );
  });

  test('receipt parses its immutable backend tax rate', () {
    final receipt = orderReceiptFromJson(<String, dynamic>{
      'orderNumber': '618-1',
      'taxRate': 0.075,
      'date': '2026-07-29T10:00:00Z',
      'subtotal': 10,
      'discountTotal': 0,
      'taxTotal': 0.75,
      'total': 10.75,
      'items': <Object>[],
      'payment': <String, dynamic>{'method': 'cash', 'amount': 10.75},
    });
    expect(receipt.taxRate, 0.075);
  });

  testWidgets('POS totals and discount preview generate dynamic tax labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: <Widget>[
            const OrderTotalsPanel(
              subtotal: 10,
              discountTotal: 0,
              tax: 0.75,
              total: 10.75,
              taxRate: 0.075,
            ),
            const DiscountPosPreviewCard(discountPercent: 10, taxRate: 0.075),
          ],
        ),
      ),
    );

    expect(find.text(TaxFormatter.taxLabel(0.075)), findsNWidgets(2));
  });
}
