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
import 'package:windows_application/features/pos/models/shift.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  late _OrderContextRepository repository;
  late PosCubit cubit;

  setUp(() async {
    repository = _OrderContextRepository();
    cubit = PosCubit(repository: repository);
    await cubit.loadInitialData();
  });

  tearDown(() => cubit.close());

  test(
    'new orders use a null table for every order type and keep customer context',
    () async {
      await cubit.selectCustomer(repository.customers.single);

      await cubit.addCustomizedProductToCart(_customization());

      expect(repository.createRequest?.tableId, isNull);
      expect(
        repository.createRequest?.customerId,
        repository.customers.single.backendId,
      );
      expect(repository.createRequest?.orderType, OrderType.dineIn);
      expect(cubit.state.selectedCustomer, repository.customers.single);
    },
  );

  test('dine-in, takeaway, and delivery all create without a table', () async {
    for (final OrderType orderType in OrderType.values) {
      final _OrderContextRepository typeRepository = _OrderContextRepository();
      final PosCubit typeCubit = PosCubit(repository: typeRepository);
      await typeCubit.loadInitialData();
      await typeCubit.changeOrderType(orderType);
      await typeCubit.addCustomizedProductToCart(_customization());

      expect(typeRepository.createRequest?.orderType, orderType);
      expect(typeRepository.createRequest?.tableId, isNull);
      await typeCubit.close();
    }
  });

  test(
    'active context updates PATCH customer and clears table on order type change',
    () async {
      await cubit.addCustomizedProductToCart(_customization());

      await cubit.selectCustomer(repository.customers.single);
      expect(repository.contextRequests.last.customerId, 7);
      expect(cubit.state.selectedCustomer, repository.customers.single);

      await cubit.changeOrderType(OrderType.takeaway);
      final _ContextRequest typeRequest = repository.contextRequests.last;
      expect(typeRequest.orderType, 'takeaway');
      expect(typeRequest.clearTable, isTrue);
      expect(typeRequest.tableId, isNull);
      expect(cubit.state.orderType, OrderType.takeaway);
    },
  );

  test('walking in and failed updates retain confirmed context', () async {
    await cubit.addCustomizedProductToCart(_customization());
    await cubit.selectCustomer(repository.customers.single);

    await cubit.clearSelectedCustomer();
    expect(repository.contextRequests.last.clearCustomer, isTrue);
    expect(cubit.state.selectedCustomer, isNull);

    final OrderType confirmedType = cubit.state.orderType;
    repository.contextError = const ApiException(message: 'Type unavailable.');
    final bool updated = await cubit.changeOrderType(OrderType.delivery);

    expect(updated, isFalse);
    expect(cubit.state.orderType, confirmedType);
    expect(cubit.state.isCartMutationInProgress, isFalse);
    expect(cubit.state.cartMutationError, 'Type unavailable.');
  });
}

ProductCustomization _customization() => ProductCustomization(
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
  specialInstructions: '',
);

class _OrderContextRepository extends PosRepository {
  _OrderContextRepository() : super();

  final List<Customer> customers = const <Customer>[
    Customer(
      id: '7',
      backendId: 7,
      name: 'Ada Lovelace',
      phone: '555',
      tier: 'VIP',
      points: 12,
    ),
  ];
  CreateOrderRequest? createRequest;
  final List<_ContextRequest> contextRequests = <_ContextRequest>[];
  Object? contextError;
  int? _customerId;
  String _orderType = 'dine_in';

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
  Future<List<Customer>> getCustomers({String? search}) async => customers;

  @override
  Future<Map<String, dynamic>> getPosState({required int branchId}) async =>
      const <String, dynamic>{};

  @override
  Future<BackendOrder> createOrder(CreateOrderRequest request) async {
    createRequest = request;
    _customerId = request.customerId;
    _orderType = request.orderType.apiValue;
    return _order();
  }

  @override
  Future<BackendOrder> updateOrderContext({
    required int orderId,
    String? orderType,
    int? tableId,
    int? customerId,
    bool clearTable = false,
    bool clearCustomer = false,
  }) async {
    contextRequests.add(
      _ContextRequest(
        orderType: orderType,
        tableId: tableId,
        customerId: customerId,
        clearTable: clearTable,
        clearCustomer: clearCustomer,
      ),
    );
    if (contextError != null) throw contextError!;
    _orderType = orderType ?? _orderType;
    if (clearCustomer || customerId != null) _customerId = customerId;
    return _order();
  }

  BackendOrder _order() {
    final Customer? customer = customers
        .where((Customer customer) => customer.backendId == _customerId)
        .cast<Customer?>()
        .firstOrNull;
    return BackendOrder(
      id: 42,
      orderNumber: '618-42',
      branchId: 1,
      shiftId: 1,
      orderType: _orderType,
      status: 'draft',
      paymentStatus: 'unpaid',
      items: const <BackendOrderItem>[
        BackendOrderItem(
          id: 1,
          productId: 4,
          name: 'Americano',
          quantity: 1,
          unitPrice: 3.75,
          lineTotal: 3.75,
          modifiers: <BackendOrderItemModifier>[],
        ),
      ],
      totals: const BackendOrderTotals(
        subtotal: 3.75,
        discountTotal: 0,
        taxTotal: 0,
        total: 3.75,
      ),
      customerId: customer?.backendId,
      customerName: customer?.name,
      customerPhone: customer?.phone,
      tableId: null,
    );
  }
}

class _ContextRequest {
  const _ContextRequest({
    this.orderType,
    this.tableId,
    this.customerId,
    required this.clearTable,
    required this.clearCustomer,
  });

  final String? orderType;
  final int? tableId;
  final int? customerId;
  final bool clearTable;
  final bool clearCustomer;
}
