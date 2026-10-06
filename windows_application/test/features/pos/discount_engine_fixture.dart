import 'dart:async';
import 'package:windows_application/features/pos/models/backend_order.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/create_order_request.dart';
import 'package:windows_application/features/pos/models/customer.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/features/pos/models/order_receipt.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_result.dart';
import 'package:windows_application/features/pos/models/payment_summary.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/product_customization.dart';
import 'package:windows_application/features/pos/models/product_modifier.dart';
import 'package:windows_application/features/pos/models/shift.dart';
import 'package:windows_application/features/pos/models/update_order_item_request.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

Map<String, dynamic> totalsJson({String total = '7.56'}) => {
  'subtotal': '10.00',
  'discountTotal': '3.00',
  'taxTotal': '0.56',
  'total': total,
};
Map<String, dynamic> discountJson(
  int id,
  String amount, {
  String? source = 'automatic',
}) => {
  'id': id,
  'discountId': id,
  'name': 'Saved $id',
  'source': source,
  'stage': source == null ? null : 'items',
  'type': 'fixed',
  'value': '1.00',
  'amount': amount,
  'settingsVersion': source == null ? null : 2,
  'allocations': source == null
      ? []
      : [
          {'orderItemId': id, 'amount': amount},
        ],
};
Map<String, dynamic> savedJson({
  Map<String, dynamic>? intent,
  List<dynamic> suppressions = const [],
}) => {
  'orderId': 42,
  'explicitIntent': intent,
  'discounts': [discountJson(1, '1.00'), discountJson(2, '2.00')],
  'requiresDiscountBreakdown': true,
  'discountContractVersion': 2,
  'totals': totalsJson(),
  'suppressions': suppressions,
};
Map<String, dynamic> resolutionJson({String total = '7.56'}) => {
  ...savedJson(),
  'fingerprint': 'fingerprint',
  'settingsVersion': 2,
  'provisional': false,
  'reasons': [],
  'totals': totalsJson(total: total),
};
ProductCustomization publishedItem() => const ProductCustomization(
  product: PosProduct(
    id: '4',
    backendId: 4,
    name: 'Pinned',
    category: 'Tea',
    size: '',
    price: 10,
    isAvailable: true,
    publishedMenuVersionId: 12,
    placementId: 40,
  ),
  quantity: 1,
  temperature: '',
  size: ProductModifierOption(id: 'p', label: ''),
  milkBase: ProductModifierOption(id: 'p', label: ''),
  addOns: [],
  sweetness: '',
  specialInstructions: 'Pinned note',
  publishedVariantId: 30,
  publishedModifierOptionIds: [71],
  publishedUnitPrice: 10,
);

class EngineFake extends PosRepository {
  @override
  bool get usesBackend => true;
  DiscountCapabilities caps = const DiscountCapabilities(
    contractVersion: 2,
    supportsDiscountReview: true,
    supportsPaymentQuote: true,
    requiresPaymentQuote: true,
    canSuppressAutomatic: true,
  );
  Map<String, dynamic> saved = savedJson();
  int creates = 0,
      previews = 0,
      operations = 0,
      pays = 0,
      quotes = 0,
      recoveries = 0,
      quantity = 1;
  String status = 'draft', paymentStatus = 'unpaid';
  List<CreateOrderRequest> createRequests = [];
  List<(String, String)> operationRequests = [];
  List<(String, String, int?)> paymentRequests = [];
  List<OrderPaymentIdentity> payments = [];
  Object? createError, previewError, operationError, payError, savedError;
  Completer<BackendOrder>? createGate;
  Completer<DiscountReview>? previewGate;
  Completer<PaymentResult>? paymentGate;
  DiscountOperationResult recovery = const DiscountOperationResult(
    operationId: 'id',
    completed: false,
  );
  DiscountReviewRequest? lastReview;
  bool provisional = false;
  String quotedTotal = '7.56';
  @override
  Future<DiscountCapabilities> getDiscountCapabilities() async => caps;
  @override
  Future<List<Branch>> getBranches() async => const [
    Branch(
      id: 1,
      name: 'Main',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];
  @override
  Future<Shift?> getCurrentShift({required int branchId}) async => currentShift;
  Shift? currentShift = const Shift(
    id: 1,
    branchId: 1,
    userId: 1,
    status: 'open',
  );
  @override
  Future<List<Customer>> getCustomers({String? search}) async => [];
  @override
  Future<Map<String, dynamic>> getPosState({required int branchId}) async => {};
  BackendOrder order() => BackendOrder.fromJson({
    'id': 42,
    'orderNumber': '42',
    'branchId': 1,
    'shiftId': 1,
    'orderType': 'dine_in',
    'status': status,
    'paymentStatus': paymentStatus,
    'publishedMenuVersionId': 12,
    'items': [
      {
        'id': 10,
        'productId': 4,
        'name': 'Pinned',
        'quantity': quantity,
        'unitPrice': 10,
        'lineTotal': 10 * quantity,
        'variantId': 30,
        'placementId': 40,
        'note': 'Pinned note',
        'modifiers': [],
      },
    ],
    'totals': {
      'subtotal': 10,
      'discountTotal': 3,
      'taxTotal': 0.56,
      'total': 7.56,
    },
    'discounts': saved['discounts'],
    'payments': payments
        .map(
          (p) => {
            'id': p.id,
            'status': p.status,
            'idempotencyKey': p.idempotencyKey,
          },
        )
        .toList(),
  });
  @override
  Future<BackendOrder> createOrder(CreateOrderRequest request) async {
    creates++;
    createRequests.add(request);
    if (createError != null) throw createError!;
    return createGate?.future ?? order();
  }

  @override
  Future<BackendOrder> getOrder(int id) async => order();
  @override
  Future<BackendOrder> addOrderItem({
    required int orderId,
    required AddOrderItemRequest request,
  }) async {
    quantity += request.quantity;
    return order();
  }

  @override
  Future<BackendOrder> updateOrderItem({
    required int orderId,
    required int itemId,
    required UpdateOrderItemRequest request,
  }) async {
    quantity = request.quantity!;
    return order();
  }

  @override
  Future<BackendOrder> updateOrderContext({
    required int orderId,
    String? orderType,
    int? tableId,
    int? customerId,
    bool clearTable = false,
    bool clearCustomer = false,
  }) async => order();
  @override
  Future<BackendOrder> holdOrder(int orderId) async {
    status = 'held';
    return order();
  }

  @override
  Future<BackendOrder> resumeOrder(int orderId) async {
    status = 'draft';
    return order();
  }

  @override
  Future<void> cancelOrder(int id) async {
    status = 'cancelled';
  }

  @override
  Future<SavedDiscountState> getDiscountState(int id) async {
    if (savedError != null) throw savedError!;
    return SavedDiscountState.fromJson(saved);
  }

  @override
  Future<DiscountReview> previewDiscount(
    int id,
    DiscountReviewRequest request, {
    int? paymentMethodId,
  }) async {
    previews++;
    lastReview = request;
    if (previewError != null) throw previewError!;
    return previewGate?.future ??
        DiscountReview.fromJson({
          ...resolutionJson(),
          'reviewId': 'review-$previews',
          'before': totalsJson(),
          'after': totalsJson(),
          'removals': saved['discounts'],
          'additions': saved['discounts'],
        });
  }

  @override
  Future<SavedDiscountState> submitDiscountOperation(
    int id,
    String identity,
    String reviewId,
  ) async {
    operations++;
    operationRequests.add((identity, reviewId));
    if (operationError != null) throw operationError!;
    return SavedDiscountState.fromJson(saved);
  }

  @override
  Future<DiscountOperationResult> recoverDiscountOperation(
    int id,
    String identity,
  ) async {
    recoveries++;
    return recovery;
  }

  @override
  Future<PaymentSummary> getPaymentSummary({
    required int orderId,
    double? amountReceived,
  }) async => PaymentSummary(
    orderId: 42,
    orderNumber: '42',
    totalDue: 7.56,
    itemCount: 1,
    amountReceived: 0,
    changeDue: 0,
    methods: ['cash', 'card'],
    quickAmounts: [],
    paymentMethods: const [
      OperationalPaymentMethod(id: 7, name: 'Till cash', type: 'cash'),
      OperationalPaymentMethod(id: 9, name: 'Bank card', type: 'card'),
    ],
    discountCapabilities: caps,
  );
  @override
  Future<PaymentQuote> quotePayment(int orderId, int? method) async {
    quotes++;
    return PaymentQuote.fromJson({
      ...resolutionJson(total: quotedTotal),
      'quoteId': 'quote-$quotes',
      'paymentMethodId': method,
      'method': method == null
          ? null
          : method == 7
          ? 'cash'
          : 'card',
      'expiresInSeconds': 300,
      'provisional': provisional,
    });
  }

  @override
  Future<PaymentResult> payQuotedOrder({
    required int orderId,
    required PaymentQuote quote,
    required String amount,
    required String idempotencyKey,
  }) async {
    pays++;
    paymentRequests.add((idempotencyKey, amount, quote.paymentMethodId));
    if (payError != null) throw payError!;
    return paymentGate?.future ??
        const PaymentResult(
          method: PaymentMethod.cash,
          totalDue: 7.56,
          amountReceived: 10,
          changeDue: 2.44,
          status: 'paid',
          paymentId: 1,
        );
  }

  @override
  Future<OrderReceipt> getReceipt(int id) async =>
      throw StateError('Receipt unavailable');
}
