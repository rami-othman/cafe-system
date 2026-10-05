import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_print_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_menu_sync_cubit.dart';
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
import 'package:windows_application/features/pos/repositories/pos_menu_sync_cache_models.dart';
import 'package:windows_application/features/pos/repositories/pos_menu_sync_repository.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/pos/views/pos_screen.dart';
import 'package:windows_application/features/pos/widgets/pos_cart_panel.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/repositories/device_printer_settings_store.dart';
import 'package:windows_application/features/printer/services/printer_service.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  late _HoldRepository repository;
  late PosCubit cubit;

  setUp(() async {
    repository = _HoldRepository();
    cubit = PosCubit(repository: repository);
    await cubit.loadInitialData();
  });

  tearDown(() => cubit.close());

  test(
    'published local cart creates, holds, and clears authoritatively',
    () async {
      await cubit.selectCustomer(repository.customer);
      await cubit.changeOrderType(OrderType.takeaway);
      await cubit.addCustomizedProductToCart(_publishedCustomization());
      repository.holdCompleter = Completer<BackendOrder>();

      final Future<void> hold = cubit.holdCurrentOrder();
      await Future<void>.delayed(Duration.zero);

      expect(repository.createCalls, 1);
      expect(repository.holdCalls, 1);
      expect(repository.lastHeldOrderId, 5);
      expect(cubit.state.currentOrderId, 5);
      expect(cubit.state.cartItems, isNotEmpty);
      expect(repository.lastCreateRequest.branchId, 1);
      expect(repository.lastCreateRequest.shiftId, 1);
      expect(repository.lastCreateRequest.orderType, OrderType.takeaway);
      expect(repository.lastCreateRequest.customerId, 7);
      expect(repository.lastCreateRequest.publishedMenuVersionId, 12);
      final AddOrderItemRequest item =
          repository.lastCreateRequest.items.single;
      expect(item.productId, 4);
      expect(item.placementId, 40);
      expect(item.variantId, 30);
      expect(item.modifierOptionIds, <int>[71]);
      expect(item.modifiers, const <SelectedModifier>[
        SelectedModifier(groupId: 1, optionId: 71),
      ]);
      expect(item.quantity, 2);
      expect(item.note, 'No ice');

      repository.holdCompleter!.complete(repository.heldOrder());
      await hold;

      expect(cubit.state.currentOrderId, isNull);
      expect(cubit.state.cartItems, isEmpty);
      expect(cubit.state.holdSuccessMessage, PosCubit.holdSucceededMessage);
    },
  );

  test(
    'rapid duplicate hold presses make one create and one hold request',
    () async {
      await cubit.addCustomizedProductToCart(_publishedCustomization());
      repository.holdCompleter = Completer<BackendOrder>();

      final Future<void> first = cubit.holdCurrentOrder();
      final Future<void> second = cubit.holdCurrentOrder();
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(repository.createCalls, 1);
      expect(repository.holdCalls, 1);

      repository.holdCompleter!.complete(repository.heldOrder());
      await Future.wait(<Future<void>>[first, second]);
    },
  );

  test('create failure keeps the local cart and does not call hold', () async {
    await cubit.addCustomizedProductToCart(_publishedCustomization());
    repository.createError = const ApiException(
      message: 'server detail must not reach the UI',
      statusCode: 422,
    );

    await cubit.holdCurrentOrder();

    expect(repository.holdCalls, 0);
    expect(cubit.state.currentOrderId, isNull);
    expect(cubit.state.cartItems, hasLength(1));
    expect(cubit.state.cartMutationError, PosCubit.holdRetryableMessage);
  });

  test(
    'hold failure retains the created draft and retry does not create again',
    () async {
      await cubit.addCustomizedProductToCart(_publishedCustomization());
      repository.holdError = const ApiException(
        message: 'hold rejected',
        statusCode: 422,
      );

      await cubit.holdCurrentOrder();
      expect(repository.createCalls, 1);
      expect(repository.holdCalls, 1);
      expect(cubit.state.currentOrderId, 5);
      expect(cubit.state.cartItems, isNotEmpty);

      repository.holdError = null;
      await cubit.holdCurrentOrder();

      expect(repository.createCalls, 1);
      expect(repository.holdCalls, 2);
      expect(cubit.state.currentOrderId, isNull);
    },
  );

  test('hold timeout is confirmed by GET without repeating hold', () async {
    await cubit.addCustomizedProductToCart(_publishedCustomization());
    repository.holdError = const ApiException(
      message: 'response timed out',
      type: ApiErrorType.receiveTimeout,
    );
    repository.verificationOrder = repository.heldOrder();

    await cubit.holdCurrentOrder();

    expect(repository.holdCalls, 1);
    expect(repository.getOrderCalls, 1);
    expect(cubit.state.cartItems, isEmpty);
    expect(cubit.state.currentOrderId, isNull);
  });

  test(
    'uncertain hold retains context and does not retry automatically',
    () async {
      await cubit.addCustomizedProductToCart(_publishedCustomization());
      repository.holdError = const ApiException(
        message: 'response timed out',
        type: ApiErrorType.receiveTimeout,
      );
      repository.getOrderError = StateError('verification unavailable');

      await cubit.holdCurrentOrder();

      expect(repository.holdCalls, 1);
      expect(repository.getOrderCalls, 1);
      expect(cubit.state.currentOrderId, 5);
      expect(cubit.state.cartItems, isNotEmpty);
      expect(cubit.state.uncertainHoldMessage, PosCubit.holdUncertainMessage);
    },
  );

  test(
    'unchanged local-cart retry reuses creation key, changed payload does not',
    () async {
      await cubit.addCustomizedProductToCart(_publishedCustomization());
      repository.persistCreateOnError = false;
      repository.createError = const ApiException(
        message: 'creation response timed out',
        type: ApiErrorType.receiveTimeout,
      );

      await cubit.holdCurrentOrder();
      final String firstKey = repository.createRequests.single.idempotencyKey!;

      await cubit.holdCurrentOrder();
      final String secondKey = repository.createRequests[1].idempotencyKey!;
      expect(secondKey, firstKey);

      await cubit.increaseQuantity(cubit.state.cartItems.single.id);
      await cubit.holdCurrentOrder();
      final String changedKey = repository.createRequests[2].idempotencyKey!;
      expect(changedKey, isNot(firstKey));
    },
  );

  test('already-held resumed order cannot be held again', () async {
    repository.existingOrder = repository.heldOrder();
    expect(await cubit.loadExistingOrder(5), isTrue);

    expect(cubit.state.currentOrderStatus, 'held');
    expect(cubit.state.currentOrderPaymentStatus, 'unpaid');
    expect(cubit.state.canHoldCurrentOrder, isFalse);
    await cubit.holdCurrentOrder();
    expect(repository.holdCalls, 0);
  });

  test(
    'request serialization retains hold creation context and item details',
    () {
      const CreateOrderRequest request = CreateOrderRequest(
        branchId: 3,
        shiftId: 8,
        orderType: OrderType.dineIn,
        tableId: 14,
        customerId: 22,
        note: 'Window seat',
        publishedMenuVersionId: 19,
        idempotencyKey: 'hold-create-1',
        items: <AddOrderItemRequest>[
          AddOrderItemRequest(
            productId: 4,
            placementId: 40,
            variantId: 30,
            modifierOptionIds: <int>[71, 72],
            modifiers: <SelectedModifier>[
              SelectedModifier(groupId: 1, optionId: 71),
            ],
            quantity: 2,
            note: 'No ice',
          ),
        ],
      );

      expect(request.toJson(), <String, dynamic>{
        'branchId': 3,
        'shiftId': 8,
        'orderType': 'dine_in',
        'tableId': 14,
        'customerId': 22,
        'idempotencyKey': 'hold-create-1',
        'publishedMenuVersionId': 19,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'productId': 4,
            'quantity': 2,
            'modifiers': <Map<String, int>>[
              <String, int>{'groupId': 1, 'optionId': 71},
            ],
            'placementId': 40,
            'variantId': 30,
            'modifierOptionIds': <int>[71, 72],
            'note': 'No ice',
          },
        ],
        'note': 'Window seat',
      });
    },
  );

  testWidgets(
    'hold is enabled for a local cart and disabled while submitting',
    (WidgetTester tester) async {
      await cubit.addCustomizedProductToCart(_publishedCustomization());
      repository.holdCompleter = Completer<BackendOrder>();
      final PosPrintCubit printCubit = PosPrintCubit(
        repository: PosRepository(),
        branchSettingsProvider: (_) async =>
            const PosPrintBranchSettings(printerConfig: PrinterConfig()),
        deviceSettingsStore: _NoOpPrinterSettingsStore(),
        printerService: NetworkEscPosPrinterService(),
        tenantId: 1,
      );
      addTearDown(printCubit.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 900,
              child: MultiBlocProvider(
                providers: <BlocProvider<dynamic>>[
                  BlocProvider<PosCubit>.value(value: cubit),
                  BlocProvider<PosPrintCubit>.value(value: printCubit),
                ],
                child: const PosCartPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder holdButton = find.text('Hold order');
      expect(holdButton, findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.ancestor(
                of: holdButton,
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(holdButton);
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.ancestor(
                of: holdButton,
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      repository.holdCompleter!.complete(repository.heldOrder());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('confirmed hold displays localized success feedback', (
    WidgetTester tester,
  ) async {
    final PosCubit localCubit = PosCubit(repository: PosRepository());
    final PosMenuSyncCubit menuCubit = PosMenuSyncCubit(
      repository: PosMenuSyncRepository(
        apiClient: DioApiClient(dio: Dio()),
        cache: MemoryPosMenuSyncCache(),
      ),
    );
    addTearDown(localCubit.close);
    addTearDown(menuCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<PosCubit>.value(value: localCubit),
              BlocProvider<PosMenuSyncCubit>.value(value: menuCubit),
            ],
            child: const PosScreen(),
          ),
        ),
      ),
    );
    localCubit.emit(
      localCubit.state.copyWith(
        holdSuccessMessage: PosCubit.holdSucceededMessage,
      ),
    );
    await tester.pump();

    expect(find.text('Order held successfully.'), findsOneWidget);
  });
}

class _NoOpPrinterSettingsStore implements DevicePrinterSettingsStore {
  @override
  Future<DevicePrinterSettings> read({required int tenantId}) async =>
      const DevicePrinterSettings();

  @override
  Future<void> write({
    required int tenantId,
    required DevicePrinterSettings settings,
  }) async {}
}

ProductCustomization _publishedCustomization() => ProductCustomization(
  product: const PosProduct(
    id: 'published-12-40',
    backendId: 4,
    name: 'Published Americano',
    category: '',
    size: 'Regular',
    price: 4,
    isAvailable: true,
    publishedMenuVersionId: 12,
    placementId: 40,
  ),
  quantity: 2,
  temperature: '',
  size: const ProductModifierOption(id: 'published', label: ''),
  milkBase: const ProductModifierOption(id: 'published', label: ''),
  addOns: const <ProductModifierOption>[],
  sweetness: '',
  specialInstructions: 'No ice',
  selectedModifiers: const <SelectedModifier>[
    SelectedModifier(groupId: 1, optionId: 71),
  ],
  publishedVariantId: 30,
  publishedModifierOptionIds: const <int>[71],
  publishedUnitPrice: 4.5,
);

class _HoldRepository extends PosRepository {
  _HoldRepository() : super();

  final Customer customer = const Customer(
    id: '7',
    backendId: 7,
    name: 'Ada Cash',
    phone: '555',
  );
  final List<CreateOrderRequest> createRequests = <CreateOrderRequest>[];
  final Map<String, BackendOrder> _ordersByKey = <String, BackendOrder>{};
  BackendOrder? existingOrder;
  BackendOrder? verificationOrder;
  Object? createError;
  bool persistCreateOnError = true;
  Object? holdError;
  Object? getOrderError;
  Completer<BackendOrder>? holdCompleter;
  int createCalls = 0;
  int holdCalls = 0;
  int getOrderCalls = 0;
  int? lastHeldOrderId;

  CreateOrderRequest get lastCreateRequest => createRequests.last;

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
      const <String>[];

  @override
  Future<List<PosProduct>> getProducts({
    required int branchId,
    int? categoryId,
    String availability = 'all',
  }) async => const <PosProduct>[];

  @override
  Future<List<Customer>> getCustomers({String? search}) async => <Customer>[
    customer,
  ];

  @override
  Future<Map<String, dynamic>> getPosState({required int branchId}) async =>
      const <String, dynamic>{};

  @override
  Future<BackendOrder> createOrder(CreateOrderRequest request) async {
    createCalls += 1;
    createRequests.add(request);
    final String key = request.idempotencyKey ?? 'request-$createCalls';
    final BackendOrder? existing = _ordersByKey[key];
    if (existing != null) return existing;
    final BackendOrder order = _orderFromRequest(request);
    if (createError != null && !persistCreateOnError) throw createError!;
    _ordersByKey[key] = order;
    if (createError != null) throw createError!;
    return order;
  }

  @override
  Future<BackendOrder> holdOrder(int orderId) async {
    holdCalls += 1;
    lastHeldOrderId = orderId;
    if (holdError != null) throw holdError!;
    if (holdCompleter != null) return holdCompleter!.future;
    return heldOrder();
  }

  @override
  Future<BackendOrder> getOrder(int orderId) async {
    getOrderCalls += 1;
    if (getOrderError != null) throw getOrderError!;
    if (verificationOrder != null) return verificationOrder!;
    if (existingOrder != null) return existingOrder!;
    return _orderFromRequest(lastCreateRequest);
  }

  BackendOrder heldOrder() {
    return _orderFromRequest(
      createRequests.isEmpty ? _defaultRequest() : lastCreateRequest,
      status: 'held',
    );
  }

  CreateOrderRequest _defaultRequest() => const CreateOrderRequest(
    branchId: 1,
    shiftId: 1,
    orderType: OrderType.dineIn,
    publishedMenuVersionId: 12,
    items: <AddOrderItemRequest>[
      AddOrderItemRequest(
        productId: 4,
        placementId: 40,
        variantId: 30,
        quantity: 1,
      ),
    ],
  );

  BackendOrder _orderFromRequest(
    CreateOrderRequest request, {
    String status = 'draft',
  }) {
    return BackendOrder(
      id: 5,
      orderNumber: '618-5',
      branchId: request.branchId,
      shiftId: request.shiftId,
      orderType: request.orderType.apiValue,
      status: status,
      paymentStatus: 'unpaid',
      customerId: request.customerId,
      tableId: request.tableId,
      note: request.note,
      publishedMenuVersionId: request.publishedMenuVersionId,
      items: request.items
          .asMap()
          .entries
          .map(
            (MapEntry<int, AddOrderItemRequest> entry) => BackendOrderItem(
              id: 10 + entry.key,
              productId: entry.value.productId,
              name: 'Published Americano',
              quantity: entry.value.quantity,
              unitPrice: 4.5,
              lineTotal: 4.5 * entry.value.quantity,
              modifiers: entry.value.modifiers
                  .map(
                    (SelectedModifier modifier) => BackendOrderItemModifier(
                      groupId: modifier.groupId,
                      optionId: modifier.optionId,
                      optionName: 'Option ${modifier.optionId}',
                      priceDelta: 0,
                    ),
                  )
                  .toList(growable: false),
              note: entry.value.note,
              variantId: entry.value.variantId,
              placementId: entry.value.placementId,
            ),
          )
          .toList(growable: false),
      totals: BackendOrderTotals(
        subtotal: request.items.fold<double>(
          0,
          (double total, AddOrderItemRequest item) =>
              total + 4.5 * item.quantity,
        ),
        discountTotal: 0,
        taxTotal: 0,
        total: request.items.fold<double>(
          0,
          (double total, AddOrderItemRequest item) =>
              total + 4.5 * item.quantity,
        ),
      ),
    );
  }
}
