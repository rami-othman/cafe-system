import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/applied_discount.dart';

void main() {
  group('AppliedDiscount', () {
    test('calculates percentage discount from subtotal', () {
      const discount = AppliedDiscount(
        id: 'morning-rush',
        title: 'Morning Rush',
        type: AppliedDiscountType.percentage,
        value: 15,
      );

      expect(discount.calculateAmount(40), 6);
    });

    test('calculates fixed discount amount', () {
      const discount = AppliedDiscount(
        id: 'vip-reward',
        title: 'VIP Reward',
        type: AppliedDiscountType.fixedAmount,
        value: 5,
      );

      expect(discount.calculateAmount(14.5), 5);
    });

    test('clamps discount so it never exceeds subtotal', () {
      const discount = AppliedDiscount(
        id: 'vip-reward',
        title: 'VIP Reward',
        type: AppliedDiscountType.fixedAmount,
        value: 5,
      );

      expect(discount.calculateAmount(3), 3);
    });
  });
}
