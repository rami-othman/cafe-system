import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/applied_discount.dart';
import 'package:windows_application/features/pos/models/backend_order.dart';
import 'package:windows_application/features/pos/models/backend_order_item.dart';
import 'package:windows_application/features/pos/models/backend_order_totals.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/create_order_request.dart';
import 'package:windows_application/features/pos/models/customer.dart';
import 'package:windows_application/features/pos/models/order_receipt.dart';
import 'package:windows_application/features/pos/models/order_type.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/product_customization.dart';
import 'package:windows_application/features/pos/models/product_modifier.dart';
import 'package:windows_application/features/pos/models/receipt_line_item.dart';
import 'package:windows_application/features/pos/models/shift.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  late _BackendPaymentRepository repository;
  late PosCubit cubit;

  setUp(() async {
    repository = _BackendPaymentRepository();
    cubit = PosCubit(repository: repository);
    await cubit.loadInitialData();
    cubit.selectCustomer(
      const Customer(
        id: 'customer-1',
        name: 'Ada Cashier',
        phone: '123',
        tier: 'REGULAR',
        points: 0,
      ),
    );
    await cubit.addCustomizedProductToCart(_customization());
  });

  tearDown(() => cubit.close());

  test(
    'double confirmation sends one pay request and exposes submitting state',
    () async {
      repository.payCompleter = Completer<PaymentResult>();

      final Future<PaymentCompletionStatus> first = cubit
          .completeBackendPayment(_payment());
      final Future<PaymentCompletionStatus> second = cubit
          .completeBackendPayment(_payment());

      expect(repository.payCalls, 1);
      expect(cubit.state.isPaymentSubmitting, isTrue);
      expect(await second, PaymentCompletionStatus.uncertain);

      repository.payCompleter!.complete(_payment());
      expect(await first, PaymentCompletionStatus.completed);
      expect(cubit.state.isPaymentSubmitting, isFalse);
    },
  );

  test('definite payment failure keeps the order and allows retry', () async {
    repository.payError = const ApiException(
      message: 'Amount received is invalid.',
      statusCode: 422,
    );

    final PaymentCompletionStatus status = await cubit.completeBackendPayment(
      _payment(),
    );

    expect(status, PaymentCompletionStatus.retryableFailure);
    expect(cubit.state.currentOrderId, 42);
    expect(cubit.state.cartItems, isNotEmpty);
    expect(cubit.state.isPaymentSubmitting, isFalse);
    expect(cubit.state.paymentErrorMessage, 'Amount received is invalid.');
    final String? keyFromFirstAttempt = repository.lastIdempotencyKey;
    expect(keyFromFirstAttempt, isNotNull);

    repository.payError = null;
    expect(
      await cubit.completeBackendPayment(_payment()),
      PaymentCompletionStatus.completed,
    );
    expect(repository.payCalls, 2);
    // Retrying payment for the same order must reuse the same idempotency
    // key — the backend dedupes a replayed /pay request by this key, so a
    // different value on retry would defeat the double-charge protection.
    expect(repository.lastIdempotencyKey, keyFromFirstAttempt);
  });

  test(
    'confirmed payment clears active order before receipt recovery',
    () async {
      repository.receiptError = StateError('Receipt unavailable');
      await cubit.applyDiscount(
        const AppliedDiscount(
          id: 'vip',
          title: 'VIP',
          type: AppliedDiscountType.fixedAmount,
          value: 1,
          code: 'VIP1',
        ),
      );

      expect(
        await cubit.completeBackendPayment(_payment()),
        PaymentCompletionStatus.completed,
      );

      expect(cubit.state.lastPaidOrderId, 42);
      expect(cubit.state.currentOrderId, isNull);
      expect(cubit.state.cartItems, isEmpty);
      expect(cubit.state.appliedDiscount, isNull);
      expect(cubit.state.selectedCustomer, isNull);
      expect(cubit.state.pendingReceiptOrderId, 42);
      expect(
        cubit.state.receiptErrorMessage,
        'Payment completed, but the receipt could not be loaded.',
      );
    },
  );

  test(
    'receipt retry keeps the cart cleared and resolves the pending receipt',
    () async {
      repository.receiptError = StateError('Receipt unavailable');
      await cubit.completeBackendPayment(_payment());
      repository.receiptError = null;

      await cubit.retryPendingReceipt();

      expect(repository.receiptCalls, 2);
      expect(cubit.state.currentOrderId, isNull);
      expect(cubit.state.cartItems, isEmpty);
      expect(cubit.state.pendingReceiptOrderId, isNull);
      expect(cubit.state.lastReceipt, isNotNull);
      expect(cubit.state.receiptErrorMessage, isNull);
    },
  );

  test(
    'failed receipt retry keeps the completed order out of the cart',
    () async {
      repository.receiptError = StateError('Receipt unavailable');
      await cubit.completeBackendPayment(_payment());

      await cubit.retryPendingReceipt();

      expect(repository.receiptCalls, 2);
      expect(cubit.state.currentOrderId, isNull);
      expect(cubit.state.cartItems, isEmpty);
      expect(cubit.state.pendingReceiptOrderId, 42);
      expect(cubit.state.lastReceipt, isNull);
    },
  );

  test(
    'uncertain pay response verifies a paid order without resubmitting',
    () async {
      repository.payError = const ApiException(message: 'Network lost');
      repository.verifiedOrderPaid = true;

      expect(
        await cubit.completeBackendPayment(_payment()),
        PaymentCompletionStatus.completed,
      );

      expect(repository.payCalls, 1);
      expect(repository.getOrderCalls, 1);
      expect(cubit.state.currentOrderId, isNull);
      expect(cubit.state.lastPaidOrderId, 42);
    },
  );

  test(
    'uncertain pay response retains an unpaid order for an explicit retry',
    () async {
      repository.payError = const ApiException(message: 'Network lost');

      expect(
        await cubit.completeBackendPayment(_payment()),
        PaymentCompletionStatus.retryableFailure,
      );

      expect(repository.payCalls, 1);
      expect(repository.getOrderCalls, 1);
      expect(cubit.state.currentOrderId, 42);
      expect(cubit.state.cartItems, isNotEmpty);
      expect(cubit.state.uncertainPaymentOrderId, isNull);
    },
  );

  test(
    'failed verification blocks another pay request until status is checked',
    () async {
      repository.payError = const ApiException(message: 'Network lost');
      repository.getOrderError = StateError('Still offline');

      expect(
        await cubit.completeBackendPayment(_payment()),
        PaymentCompletionStatus.uncertain,
      );
      expect(cubit.state.currentOrderId, 42);
      expect(cubit.state.uncertainPaymentOrderId, 42);
      expect(
        cubit.state.uncertainPaymentMessage,
        'Payment status could not be confirmed. Check the Orders screen before retrying.',
      );

      await cubit.completeBackendPayment(_payment());
      expect(repository.payCalls, 1);
    },
  );
}

PaymentResult _payment() => const PaymentResult(
  method: PaymentMethod.card,
  totalDue: 10,
  amountReceived: 10,
  changeDue: 0,
  status: 'paid',
  paymentId: 7,
);

ProductCustomization _customization() => ProductCustomization(
  product: const PosProduct(
    id: '8',
    backendId: 8,
    name: 'Latte',
    category: 'COFFEE',
    size: '12 oz',
    price: 10,
    isAvailable: true,
  ),
  quantity: 1,
  temperature: 'Hot',
  size: const ProductModifierOption(id: 'regular', label: 'Regular'),
  milkBase: const ProductModifierOption(id: 'whole', label: 'Whole'),
  addOns: const <ProductModifierOption>[],
  sweetness: '100%',
  specialInstructions: '',
);

class _BackendPaymentRepository extends PosRepository {
  _BackendPaymentRepository() : super();

  int payCalls = 0;
  int receiptCalls = 0;
  int getOrderCalls = 0;
  Object? payError;
  Object? receiptError;
  Object? getOrderError;
  String? lastIdempotencyKey;
  bool verifiedOrderPaid = false;
  Completer<PaymentResult>? payCompleter;
  BackendOrder? _order;

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
    _order = _buildOrder();
    return _order!;
  }

  @override
  Future<BackendOrder> applyDiscount({
    required int orderId,
    String? code,
    int? discountId,
  }) async => _buildOrder(discounted: true);

  @override
  Future<PaymentResult> payOrder({
    required int orderId,
    required String method,
    required double amount,
    required String idempotencyKey,
    String? reference,
    required double totalDue,
    String? idempotencyKey,
  }) async {
    payCalls += 1;
    lastIdempotencyKey = idempotencyKey;
    if (payCompleter != null) return payCompleter!.future;
    if (payError != null) throw payError!;
    return _payment();
  }

  @override
  Future<BackendOrder> getOrder(int orderId) async {
    getOrderCalls += 1;
    if (getOrderError != null) throw getOrderError!;
    return _buildOrder(paid: verifiedOrderPaid);
  }

  @override
  Future<OrderReceipt> getReceipt(int orderId) async {
    receiptCalls += 1;
    if (receiptError != null) throw receiptError!;
    return OrderReceipt(
      orderNumber: '618-42',
      branchName: 'Main',
      cashierName: 'Ada',
      completedAt: DateTime(2026, 7, 12),
      items: const <ReceiptLineItem>[
        ReceiptLineItem(
          name: 'Latte',
          quantity: 1,
          unitPrice: 10,
          lineTotal: 10,
          modifiers: <String>[],
        ),
      ],
      subtotal: 10,
      discountTotal: 0,
      discountLabel: null,
      tax: 0,
      total: 10,
      payment: _payment(),
    );
  }

  BackendOrder _buildOrder({bool paid = false, bool discounted = false}) =>
      BackendOrder(
        id: 42,
        orderNumber: '618-42',
        branchId: 1,
        shiftId: 1,
        orderType: OrderType.dineIn.apiValue,
        status: paid ? 'paid' : 'draft',
        paymentStatus: paid ? 'paid' : 'unpaid',
        items: const <BackendOrderItem>[
          BackendOrderItem(
            id: 1,
            productId: 8,
            name: 'Latte',
            quantity: 1,
            unitPrice: 10,
            lineTotal: 10,
            modifiers: <BackendOrderItemModifier>[],
          ),
        ],
        totals: const BackendOrderTotals(
          subtotal: 10,
          discountTotal: 0,
          taxTotal: 0,
          total: 10,
        ),
        discountName: discounted ? 'VIP' : null,
        discountType: discounted ? 'fixed' : null,
        discountValue: discounted ? 1 : null,
        discountAmount: discounted ? 1 : null,
      );
}
