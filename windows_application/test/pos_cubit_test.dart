import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/applied_discount.dart';
import 'package:windows_application/features/pos/models/customer.dart';
import 'package:windows_application/features/pos/models/order_type.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/models/product_customization.dart';
import 'package:windows_application/features/pos/models/product_modifier.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  late PosCubit cubit;

  setUp(() {
    cubit = PosCubit(repository: PosRepository());
  });

  tearDown(() {
    cubit.close();
  });

  test('loads fake products and categories with coffee selected', () async {
    await cubit.loadInitialData();

    expect(cubit.state.products, hasLength(8));
    expect(cubit.state.customers, hasLength(3));
    expect(cubit.state.categories, contains('COFFEE'));
    expect(cubit.state.selectedCategory, 'COFFEE');
    expect(cubit.state.customerDisplayName, 'Walk-in Customer');
    expect(cubit.state.filteredProducts.map((product) => product.name), [
      'Espresso',
      'Cold Brew Reserve',
      'Cappuccino',
      'Pour Over V60',
      'Americano',
    ]);
  });

  test('selects and clears optional customer', () async {
    await cubit.loadInitialData();
    final Customer customer = cubit.state.customers.firstWhere(
      (Customer customer) => customer.name == 'Janet Smith',
    );

    cubit.selectCustomer(customer);

    expect(cubit.state.selectedCustomer, customer);
    expect(cubit.state.customerDisplayName, 'Janet Smith');

    cubit.clearSelectedCustomer();

    expect(cubit.state.selectedCustomer, isNull);
    expect(cubit.state.customerDisplayName, 'Walk-in Customer');
  });

  test('filters products by category and search query', () async {
    await cubit.loadInitialData();

    cubit.selectCategory('TEA');
    expect(cubit.state.filteredProducts.map((product) => product.name), [
      'Green Tea',
    ]);

    cubit.selectCategory('COFFEE');
    cubit.updateSearchQuery('cap');
    expect(cubit.state.filteredProducts.single.name, 'Cappuccino');
  });

  test('adds available products and increments existing cart item', () async {
    await cubit.loadInitialData();
    final cappuccino = cubit.state.products.firstWhere(
      (product) => product.name == 'Cappuccino',
    );

    cubit.addProductToCart(cappuccino);
    cubit.addProductToCart(cappuccino);

    expect(cubit.state.cartItems, hasLength(1));
    expect(cubit.state.cartItems.single.quantity, 2);
    expect(cubit.state.cartItems.single.modifiers, ['Oat Milk', 'Extra Shot']);
  });

  test('ignores unavailable products', () async {
    await cubit.loadInitialData();
    final coldBrew = cubit.state.products.firstWhere(
      (product) => product.name == 'Cold Brew Reserve',
    );

    cubit.addProductToCart(coldBrew);

    expect(cubit.state.cartItems, isEmpty);
  });

  test('decreases quantity and removes item at zero', () async {
    await cubit.loadInitialData();
    final espresso = cubit.state.products.firstWhere(
      (product) => product.name == 'Espresso',
    );

    cubit.addProductToCart(espresso);
    cubit.increaseQuantity(espresso.id);
    cubit.decreaseQuantity(espresso.id);
    expect(cubit.state.cartItems.single.quantity, 1);

    cubit.decreaseQuantity(espresso.id);
    expect(cubit.state.cartItems, isEmpty);
  });

  test('updates order type and calculates totals', () async {
    await cubit.loadInitialData();
    final cappuccino = cubit.state.products.firstWhere(
      (product) => product.name == 'Cappuccino',
    );
    final croissant = cubit.state.products.firstWhere(
      (product) => product.name == 'Almond Croissant',
    );

    cubit.addProductToCart(cappuccino);
    cubit.addProductToCart(croissant);
    cubit.addProductToCart(croissant);
    cubit.changeOrderType(OrderType.delivery);

    expect(cubit.state.orderType, OrderType.delivery);
    expect(cubit.state.subtotal, 13.5);
    expect(cubit.state.discountTotal, 0);
    expect(cubit.state.tax, closeTo(1.08, 0.001));
    expect(cubit.state.total, closeTo(14.58, 0.001));
    expect(cubit.state.totalItems, 3);
  });

  test('applying discount updates taxable total', () async {
    await cubit.loadInitialData();
    final cappuccino = cubit.state.products.firstWhere(
      (product) => product.name == 'Cappuccino',
    );
    final croissant = cubit.state.products.firstWhere(
      (product) => product.name == 'Almond Croissant',
    );

    cubit.addProductToCart(cappuccino);
    cubit.addProductToCart(croissant);
    cubit.addProductToCart(croissant);
    cubit.applyDiscount(
      const AppliedDiscount(
        id: 'vip-reward',
        title: 'VIP Reward',
        type: AppliedDiscountType.fixedAmount,
        value: 5,
        code: 'VIP5',
      ),
    );

    expect(cubit.state.subtotal, 13.5);
    expect(cubit.state.discountTotal, 5);
    expect(cubit.state.tax, closeTo(0.68, 0.001));
    expect(cubit.state.total, closeTo(9.18, 0.001));
  });

  test('clearing cart removes applied discount', () async {
    await cubit.loadInitialData();
    final cappuccino = cubit.state.products.firstWhere(
      (product) => product.name == 'Cappuccino',
    );

    cubit.addProductToCart(cappuccino);
    cubit.applyDiscount(
      const AppliedDiscount(
        id: 'vip-reward',
        title: 'VIP Reward',
        type: AppliedDiscountType.fixedAmount,
        value: 5,
      ),
    );

    cubit.clearCart();

    expect(cubit.state.cartItems, isEmpty);
    expect(cubit.state.appliedDiscount, isNull);
    expect(cubit.state.discountTotal, 0);
  });

  test('completing local payment clears cart and applied discount', () async {
    await cubit.loadInitialData();
    final cappuccino = cubit.state.products.firstWhere(
      (product) => product.name == 'Cappuccino',
    );

    cubit.addProductToCart(cappuccino);
    cubit.applyDiscount(
      const AppliedDiscount(
        id: 'vip-reward',
        title: 'VIP Reward',
        type: AppliedDiscountType.fixedAmount,
        value: 1,
      ),
    );
    cubit.completeLocalPayment(
      const PaymentResult(
        method: PaymentMethod.card,
        totalDue: 3.78,
        amountReceived: 3.78,
        changeDue: 0,
      ),
    );

    expect(cubit.state.cartItems, isEmpty);
    expect(cubit.state.appliedDiscount, isNull);
    expect(cubit.state.total, 0);
  });

  test(
    'completing local payment creates receipt before clearing cart',
    () async {
      await cubit.loadInitialData();
      final cappuccino = cubit.state.products.firstWhere(
        (product) => product.name == 'Cappuccino',
      );
      final croissant = cubit.state.products.firstWhere(
        (product) => product.name == 'Almond Croissant',
      );

      cubit.addProductToCart(cappuccino);
      cubit.addProductToCart(croissant);
      final double totalBeforePayment = cubit.state.total;

      cubit.completeLocalPayment(
        PaymentResult(
          method: PaymentMethod.cash,
          totalDue: totalBeforePayment,
          amountReceived: 20,
          changeDue: 20 - totalBeforePayment,
        ),
      );

      final receipt = cubit.state.lastReceipt;

      expect(receipt, isNotNull);
      expect(receipt!.items, hasLength(2));
      expect(receipt.items.first.name, 'Cappuccino');
      expect(receipt.items.first.quantity, 1);
      expect(receipt.items.first.modifiers, ['Oat Milk', 'Extra Shot']);
      expect(receipt.subtotal, 9);
      expect(receipt.tax, closeTo(0.72, 0.001));
      expect(receipt.total, closeTo(totalBeforePayment, 0.001));
      expect(receipt.payment.method, PaymentMethod.cash);
      expect(receipt.payment.amountReceived, 20);
      expect(cubit.state.cartItems, isEmpty);
      expect(cubit.state.appliedDiscount, isNull);
    },
  );

  test('local payment receipt keeps selected customer before reset', () async {
    await cubit.loadInitialData();
    final espresso = cubit.state.products.firstWhere(
      (product) => product.name == 'Espresso',
    );
    final Customer customer = cubit.state.customers.firstWhere(
      (Customer customer) => customer.name == 'Janet Smith',
    );

    cubit.selectCustomer(customer);
    cubit.addProductToCart(espresso);
    final double totalBeforePayment = cubit.state.total;

    cubit.completeLocalPayment(
      PaymentResult(
        method: PaymentMethod.card,
        totalDue: totalBeforePayment,
        amountReceived: totalBeforePayment,
        changeDue: 0,
      ),
    );

    expect(cubit.state.lastReceipt?.customerName, 'Janet Smith');
    expect(cubit.state.selectedCustomer, isNull);
    expect(cubit.state.customerDisplayName, 'Walk-in Customer');
  });

  test('local payment receipt includes applied discount', () async {
    await cubit.loadInitialData();
    final cappuccino = cubit.state.products.firstWhere(
      (product) => product.name == 'Cappuccino',
    );

    cubit.addProductToCart(cappuccino);
    cubit.applyDiscount(
      const AppliedDiscount(
        id: 'vip-reward',
        title: 'VIP Reward',
        type: AppliedDiscountType.fixedAmount,
        value: 1,
        code: 'VIP1',
      ),
    );
    final double totalBeforePayment = cubit.state.total;

    cubit.completeLocalPayment(
      PaymentResult(
        method: PaymentMethod.card,
        totalDue: totalBeforePayment,
        amountReceived: totalBeforePayment,
        changeDue: 0,
      ),
    );

    final receipt = cubit.state.lastReceipt;

    expect(receipt, isNotNull);
    expect(receipt!.discountTotal, 1);
    expect(receipt.discountLabel, 'VIP Reward');
    expect(receipt.total, closeTo(totalBeforePayment, 0.001));
    expect(cubit.state.cartItems, isEmpty);
    expect(cubit.state.appliedDiscount, isNull);
  });

  test('clearLastReceipt removes completed receipt without changing cart', () {
    cubit.clearLastReceipt();

    expect(cubit.state.lastReceipt, isNull);
    expect(cubit.state.cartItems, isEmpty);
  });

  test(
    'adds same customization by increasing the existing cart line',
    () async {
      await cubit.loadInitialData();
      final cappuccino = cubit.state.products.firstWhere(
        (product) => product.name == 'Cappuccino',
      );
      final customization = ProductCustomization(
        product: cappuccino,
        quantity: 2,
        temperature: 'Hot',
        size: const ProductModifierOption(id: 'medium', label: 'Medium (12oz)'),
        milkBase: const ProductModifierOption(
          id: 'oat',
          label: 'Oat Milk',
          priceDelta: 0.75,
        ),
        addOns: const <ProductModifierOption>[
          ProductModifierOption(
            id: 'extra-espresso',
            label: 'Extra Espresso Shot',
            priceDelta: 1,
          ),
        ],
        sweetness: '100%',
        specialInstructions: 'Extra hot',
      );

      cubit.addCustomizedProductToCart(customization);
      cubit.addCustomizedProductToCart(customization);

      expect(cubit.state.cartItems, hasLength(1));
      expect(cubit.state.cartItems.single.quantity, 4);
      expect(cubit.state.cartItems.single.unitPrice, 6.25);
      expect(cubit.state.cartItems.single.lineTotal, 25);
    },
  );

  test('adds different customizations as separate cart lines', () async {
    await cubit.loadInitialData();
    final cappuccino = cubit.state.products.firstWhere(
      (product) => product.name == 'Cappuccino',
    );

    cubit.addCustomizedProductToCart(
      ProductCustomization(
        product: cappuccino,
        quantity: 1,
        temperature: 'Hot',
        size: const ProductModifierOption(id: 'medium', label: 'Medium (12oz)'),
        milkBase: const ProductModifierOption(id: 'whole', label: 'Whole Milk'),
        addOns: const <ProductModifierOption>[],
        sweetness: '100%',
        specialInstructions: '',
      ),
    );
    cubit.addCustomizedProductToCart(
      ProductCustomization(
        product: cappuccino,
        quantity: 1,
        temperature: 'Iced',
        size: const ProductModifierOption(id: 'medium', label: 'Medium (12oz)'),
        milkBase: const ProductModifierOption(id: 'whole', label: 'Whole Milk'),
        addOns: const <ProductModifierOption>[],
        sweetness: '100%',
        specialInstructions: '',
      ),
    );

    expect(cubit.state.cartItems, hasLength(2));
    expect(cubit.state.cartItems.map((item) => item.modifiers.first), <String>[
      'Hot',
      'Iced',
    ]);
  });
}
