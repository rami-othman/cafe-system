import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/backend_order.dart';
import 'package:windows_application/features/pos/models/backend_order_item.dart';
import 'package:windows_application/features/pos/models/backend_order_totals.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/create_order_request.dart';
import 'package:windows_application/features/pos/models/customer.dart';
import 'package:windows_application/features/pos/models/order_type.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/product_customization.dart';
import 'package:windows_application/features/pos/models/product_modifier.dart';
import 'package:windows_application/features/pos/models/selected_modifier.dart';
import 'package:windows_application/features/pos/models/shift.dart';
import 'package:windows_application/features/pos/models/update_order_item_request.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  late _BackendCartRepository repository;
  late PosCubit cubit;

  setUp(() async {
    repository = _BackendCartRepository();
    cubit = PosCubit(repository: repository);
    await cubit.loadInitialData();
  });

  tearDown(() => cubit.close());

  test(
    'exact backend configuration PATCHes quantity instead of POSTing item',
    () async {
      final ProductCustomization item = _customization();

      await cubit.addCustomizedProductToCart(item);
      await cubit.addCustomizedProductToCart(item);

      expect(repository.createCalls, 1);
      expect(repository.addCalls, 0);
      expect(repository.updateCalls, 1);
      expect(cubit.state.cartItems.single.quantity, 2);
      expect(cubit.state.cartItems.single.backendItemId, 10);
      expect(
        cubit.state.cartItems.single.selectedModifiers,
        item.selectedModifiers,
      );
    },
  );

  test('different modifier or note POSTs a separate backend item', () async {
    await cubit.addCustomizedProductToCart(_customization());
    await cubit.addCustomizedProductToCart(
      _customization(
        modifiers: const <SelectedModifier>[
          SelectedModifier(groupId: 1, optionId: 3),
        ],
      ),
    );
    await cubit.addCustomizedProductToCart(_customization(note: 'Extra hot'));

    expect(repository.addCalls, 2);
    expect(repository.updateCalls, 0);
  });

  test('rapid identical adds are serialized into create then PATCH', () async {
    final ProductCustomization item = _customization();

    await Future.wait<bool>(<Future<bool>>[
      cubit.addCustomizedProductToCart(item),
      cubit.addCustomizedProductToCart(item),
    ]);

    expect(repository.createCalls, 1);
    expect(repository.addCalls, 0);
    expect(repository.updateCalls, 1);
    expect(cubit.state.cartItems.single.quantity, 2);
    expect(cubit.state.isCartMutationInProgress, isFalse);
  });

  test('failed mutation keeps confirmed cart and clears busy state', () async {
    await cubit.addCustomizedProductToCart(_customization());
    repository.failUpdate = true;

    final bool succeeded = await cubit.addCustomizedProductToCart(
      _customization(),
    );

    expect(succeeded, isFalse);
    expect(cubit.state.cartItems.single.quantity, 1);
    expect(cubit.state.isCartMutationInProgress, isFalse);
    expect(cubit.state.cartMutationError, 'Quantity is unavailable.');
  });
}

ProductCustomization _customization({
  List<SelectedModifier> modifiers = const <SelectedModifier>[
    SelectedModifier(groupId: 1, optionId: 2),
  ],
  String note = '',
}) {
  return ProductCustomization(
    product: const PosProduct(
      id: '4',
      backendId: 4,
      name: 'Americano',
      category: 'COFFEE',
      size: '12 oz',
      price: 3.75,
      isAvailable: true,
    ),
    quantity: 1,
    temperature: 'Hot',
    size: const ProductModifierOption(id: 'medium', label: 'Medium'),
    milkBase: const ProductModifierOption(id: 'whole', label: 'Whole'),
    addOns: const <ProductModifierOption>[],
    sweetness: '100%',
    specialInstructions: note,
    selectedModifiers: modifiers,
  );
}

class _BackendCartRepository extends PosRepository {
  _BackendCartRepository() : super();

  int createCalls = 0;
  int addCalls = 0;
  int updateCalls = 0;
  bool failUpdate = false;
  List<BackendOrderItem> _items = const <BackendOrderItem>[];

  @override
  bool get usesBackend => true;

  @override
  Future<List<Branch>> getBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Main',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];

  @override
  Future<Shift?> getCurrentShift({required int branchId}) async =>
      const Shift(id: 1, branchId: 1, userId: 1, status: 'open');

  @override
  Future<List<String>> getCategories({required int branchId}) async =>
      const <String>['COFFEE'];

  @override
  Future<List<PosProduct>> getProducts({
    required int branchId,
    int? categoryId,
    String availability = 'all',
  }) async => const <PosProduct>[];

  @override
  Future<List<Customer>> getCustomers({String? search}) async =>
      const <Customer>[];

  @override
  Future<Map<String, dynamic>> getPosState({required int branchId}) async =>
      const <String, dynamic>{};

  @override
  Future<BackendOrder> createOrder(CreateOrderRequest request) async {
    createCalls += 1;
    _items = <BackendOrderItem>[_item(id: 10, request: request.items.single)];
    return _order();
  }

  @override
  Future<BackendOrder> addOrderItem({
    required int orderId,
    required AddOrderItemRequest request,
  }) async {
    addCalls += 1;
    _items = <BackendOrderItem>[
      ..._items,
      _item(id: 10 + _items.length, request: request),
    ];
    return _order();
  }

  @override
  Future<BackendOrder> updateOrderItem({
    required int orderId,
    required int itemId,
    required UpdateOrderItemRequest request,
  }) async {
    updateCalls += 1;
    if (failUpdate) {
      throw const ApiException(message: 'Quantity is unavailable.');
    }
    _items = _items
        .map((BackendOrderItem item) {
          return item.id == itemId
              ? BackendOrderItem(
                  id: item.id,
                  productId: item.productId,
                  name: item.name,
                  quantity: request.quantity ?? item.quantity,
                  unitPrice: item.unitPrice,
                  lineTotal:
                      item.unitPrice * (request.quantity ?? item.quantity),
                  modifiers: item.modifiers,
                  note: item.note,
                )
              : item;
        })
        .toList(growable: false);
    return _order();
  }

  BackendOrderItem _item({
    required int id,
    required AddOrderItemRequest request,
  }) {
    return BackendOrderItem(
      id: id,
      productId: request.productId,
      name: 'Americano',
      quantity: request.quantity,
      unitPrice: 3.75,
      lineTotal: 3.75 * request.quantity,
      modifiers: request.modifiers
          .map(
            (SelectedModifier modifier) => BackendOrderItemModifier(
              groupId: modifier.groupId,
              optionId: modifier.optionId,
              optionName: 'Option ${modifier.optionId}',
              priceDelta: 0,
            ),
          )
          .toList(growable: false),
      note: request.note?.trim().isEmpty ?? true ? null : request.note!.trim(),
    );
  }

  BackendOrder _order() => BackendOrder(
    id: 5,
    orderNumber: '20260712-0001',
    branchId: 1,
    shiftId: 1,
    orderType: OrderType.dineIn.apiValue,
    status: 'draft',
    paymentStatus: 'unpaid',
    items: _items,
    totals: BackendOrderTotals(
      subtotal: _items.fold<double>(
        0,
        (double sum, BackendOrderItem item) => sum + item.lineTotal,
      ),
      discountTotal: 0,
      taxTotal: 0,
      total: _items.fold<double>(
        0,
        (double sum, BackendOrderItem item) => sum + item.lineTotal,
      ),
    ),
  );
}
