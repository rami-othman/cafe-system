import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/backend_order.dart';

void main() {
  test('maps backend order totals and items from Laravel response', () {
    final order = BackendOrder.fromJson(<String, Object?>{
      'id': 17,
      'orderNumber': '20260620-0001',
      'branchId': 1,
      'shiftId': 3,
      'orderType': 'dine_in',
      'status': 'draft',
      'paymentStatus': 'unpaid',
      'items': <Object?>[
        <String, Object?>{
          'id': 91,
          'productId': 5,
          'name': 'Cappuccino',
          'quantity': 2.0,
          'unitPrice': 4.75,
          'lineTotal': 9.5,
          'modifiers': <Object?>[
            <String, Object?>{
              'groupId': 1,
              'optionId': 2,
              'optionName': 'Oat Milk',
              'priceDelta': 0.75,
            },
          ],
          'note': 'Extra hot',
        },
      ],
      'totals': <String, Object?>{
        'subtotal': 9.5,
        'discountTotal': 1.0,
        'taxTotal': 0.68,
        'total': 9.18,
      },
    });

    expect(order.id, 17);
    expect(order.shiftId, 3);
    expect(order.items.single.id, 91);
    expect(order.items.single.productId, 5);
    expect(order.items.single.modifierLabels, <String>['Oat Milk']);
    expect(order.totals.subtotal, 9.5);
    expect(order.totals.discountTotal, 1.0);
    expect(order.totals.taxTotal, 0.68);
    expect(order.totals.total, 9.18);
  });
}
