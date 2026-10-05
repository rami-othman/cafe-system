import 'dart:async';

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
import 'package:windows_application/features/pos/models/pos_customer_create_result.dart';
import 'package:windows_application/features/pos/models/pos_quick_create_customer_request.dart';
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

  test(
    'quick-create selects a new customer and attaches its backend ID',
    () async {
      await cubit.addCustomizedProductToCart(_customization());
      final PosCustomerCreateResult result = await cubit.quickCreateCustomer(
        const PosQuickCreateCustomerRequest(
          name: 'Created at till',
          phone: '091234567',
        ),
      );

      expect(result.attachmentFailed, isFalse);
      expect(result.attachedToOrder, isTrue);
      expect(repository.contextRequests.last.customerId, 99);
      expect(cubit.state.selectedCustomer?.backendId, 99);
      expect(
        cubit.state.customers.where((Customer item) => item.backendId == 99),
        hasLength(1),
      );
    },
  );

  test('quick-create keeps the customer when order attachment fails', () async {
    await cubit.addCustomizedProductToCart(_customization());
    repository.contextError = const ApiException(message: 'attachment failed');

    final PosCustomerCreateResult result = await cubit.quickCreateCustomer(
      const PosQuickCreateCustomerRequest(
        name: 'Created but detached',
        phone: '091234567',
      ),
    );

    expect(result.attachmentFailed, isTrue);
    expect(result.attachedToOrder, isFalse);
    expect(cubit.state.selectedCustomer, isNull);
    expect(
      cubit.state.customers.where((Customer item) => item.backendId == 99),
      hasLength(1),
    );
    expect(
      cubit.state.cartMutationError,
      PosCubit.customerAttachmentFailedMessage,
    );
  });

  test(
    'quick-create before an order is created is sent with the new order',
    () async {
      final PosCustomerCreateResult result = await cubit.quickCreateCustomer(
        const PosQuickCreateCustomerRequest(
          name: 'Pending customer',
          phone: '091234567',
        ),
      );

      await cubit.addCustomizedProductToCart(_customization());

      expect(result.attachedToOrder, isFalse);
      expect(repository.createRequest?.customerId, 99);
      expect(cubit.state.selectedCustomer?.backendId, 99);
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

  test(
    'loads one authoritative held order and preserves its backend context',
    () async {
      repository.existingOrder = _heldOrder();

      final bool loaded = await cubit.loadExistingOrder(42);

      expect(loaded, isTrue);
      expect(repository.getOrderCalls, 1);
      expect(cubit.state.currentOrderId, 42);
      expect(cubit.state.publishedMenuVersionId, 19);
      expect(cubit.state.cartItems.single.backendItemId, 77);
      expect(cubit.state.cartItems.single.publishedMenuVersionId, 19);
      expect(cubit.state.cartItems.single.quantity, 2);
      expect(cubit.state.backendTotal, 8.5);
      expect(cubit.state.tableId, 12);
      expect(cubit.state.tableName, 'Table 12');
      expect(cubit.state.tableCode, 'T12');
      expect(cubit.state.orderNote, 'Extra hot');
      expect(cubit.state.isCartMutationInProgress, isFalse);
    },
  );

  test('duplicate existing-order loads coalesce to one GET', () async {
    repository.existingOrder = _heldOrder();
    final Completer<BackendOrder> pending = Completer<BackendOrder>();
    repository.existingOrderFuture = pending.future;

    final Future<bool> first = cubit.loadExistingOrder(42);
    final Future<bool> duplicate = cubit.loadExistingOrder(42);

    expect(identical(first, duplicate), isTrue);
    expect(repository.getOrderCalls, 1);
    expect(repository.createRequest, isNull);
    pending.complete(_heldOrder());
    expect(await first, isTrue);
  });

  test(
    'does not overwrite a non-empty cart without explicit replacement',
    () async {
      cubit.addProductToCart(_customization().product);
      repository.existingOrder = _heldOrder();

      expect(await cubit.loadExistingOrder(42), isFalse);
      expect(repository.getOrderCalls, 0);
      expect(cubit.state.currentOrderId, isNull);
      expect(cubit.state.cartItems, hasLength(1));

      expect(await cubit.loadExistingOrder(42, allowReplace: true), isTrue);
      expect(cubit.state.currentOrderId, 42);
    },
  );

  test('stale existing-order response cannot replace a changed cart', () async {
    repository.existingOrder = _heldOrder();
    final Completer<BackendOrder> pending = Completer<BackendOrder>();
    repository.existingOrderFuture = pending.future;

    final Future<bool> load = cubit.loadExistingOrder(42);
    cubit.addProductToCart(_customization().product);
    pending.complete(_heldOrder());

    expect(await load, isFalse);
    expect(cubit.state.currentOrderId, isNull);
    expect(cubit.state.cartItems, hasLength(1));
  });

  test('paid or non-held backend orders cannot be loaded into POS', () async {
    repository.existingOrder = _heldOrder().copyWithForTest(
      status: 'draft',
      paymentStatus: 'unpaid',
    );
    expect(await cubit.loadExistingOrder(42), isFalse);
    expect(cubit.state.currentOrderId, isNull);

    repository.existingOrder = _heldOrder().copyWithForTest(
      status: 'held',
      paymentStatus: 'paid',
    );
    expect(await cubit.loadExistingOrder(42), isFalse);
    expect(cubit.state.currentOrderId, isNull);
  });

  test(
    'unsupported published snapshot fails without opening an editable cart',
    () async {
      repository.existingOrder = _heldOrder().copyWithForTest(
        canResume: false,
        resumeBlockerCode: 'UNSUPPORTED_MENU_SNAPSHOT_SCHEMA',
        resumeBlockedReason:
            'This historical order cannot be resumed because its pinned menu snapshot is unsupported.',
      );

      expect(await cubit.loadExistingOrder(42), isFalse);
      expect(cubit.state.currentOrderId, isNull);
      expect(cubit.state.cartItems, isEmpty);
      expect(cubit.state.cartMutationError, contains('snapshot is unsupported'));
      expect(repository.getOrderCalls, 1);
    },
  );

  test('confirmed cancellation clears the matching POS order context', () async {
    repository.existingOrder = _heldOrder();
    expect(await cubit.loadExistingOrder(42), isTrue);

    cubit.clearCancelledOrderContext(42);

    expect(cubit.state.currentOrderId, isNull);
    expect(cubit.state.cartItems, isEmpty);
  });

  test('cancellation does not clear a different newer POS order context', () async {
    repository.existingOrder = _heldOrder();
    expect(await cubit.loadExistingOrder(42), isTrue);

    cubit.clearCancelledOrderContext(99);

    expect(cubit.state.currentOrderId, 42);
    expect(cubit.state.cartItems, isNotEmpty);
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

  final List<Customer> customers = <Customer>[
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
  Object? existingOrderError;
  BackendOrder? existingOrder;
  Future<BackendOrder>? existingOrderFuture;
  int getOrderCalls = 0;
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
  Future<Customer> quickCreateCustomer(
    PosQuickCreateCustomerRequest request,
  ) async {
    const Customer customer = Customer(
      id: '99',
      backendId: 99,
      name: 'Created at till',
      phone: '091234567',
    );
    customers.add(customer);
    return customer;
  }

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
  Future<BackendOrder> getOrder(int orderId) async {
    getOrderCalls++;
    if (existingOrderError != null) {
      throw existingOrderError!;
    }
    if (existingOrderFuture != null) {
      return existingOrderFuture!;
    }
    if (existingOrder == null) {
      throw const ApiException(message: 'Order not found.');
    }
    return existingOrder!;
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
      note: null,
    );
  }
}

BackendOrder _heldOrder() => BackendOrder(
  id: 42,
  orderNumber: '618-42',
  branchId: 1,
  shiftId: 1,
  orderType: 'takeaway',
  status: 'held',
  paymentStatus: 'unpaid',
  publishedMenuVersionId: 19,
  items: const <BackendOrderItem>[
    BackendOrderItem(
      id: 77,
      productId: 4,
      name: 'Americano',
      quantity: 2,
      unitPrice: 4.25,
      lineTotal: 8.5,
      modifiers: <BackendOrderItemModifier>[],
    ),
  ],
  totals: const BackendOrderTotals(
    subtotal: 8.5,
    discountTotal: 0,
    taxTotal: 0,
    total: 8.5,
  ),
  tableId: 12,
  tableName: 'Table 12',
  tableCode: 'T12',
  note: 'Extra hot',
);

extension on BackendOrder {
  BackendOrder copyWithForTest({
    String? status,
    String? paymentStatus,
    bool? canResume,
    String? resumeBlockerCode,
    String? resumeBlockedReason,
  }) {
    return BackendOrder(
      id: id,
      orderNumber: orderNumber,
      branchId: branchId,
      shiftId: shiftId,
      orderType: orderType,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      items: items,
      totals: totals,
      discountName: discountName,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      tableId: tableId,
      tableName: tableName,
      tableCode: tableCode,
      note: note,
      publishedMenuVersionId: publishedMenuVersionId,
      canResume: canResume ?? this.canResume,
      resumeBlockerCode: resumeBlockerCode ?? this.resumeBlockerCode,
      resumeBlockedReason: resumeBlockedReason ?? this.resumeBlockedReason,
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
