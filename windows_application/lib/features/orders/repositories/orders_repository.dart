import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/config/tax_config.dart';
import '../../../core/network/dio_api_client.dart';
import '../../../core/utils/backend_datetime.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../pos/models/branch.dart';
import '../../pos/models/json_helpers.dart';
import '../controllers/orders_state.dart';
import '../models/order_detail.dart';
import '../models/order_page.dart';
import '../models/order_payment_summary.dart';
import '../models/order_refund.dart';
import '../models/order_status.dart';
import '../models/order_summary.dart';
import '../models/order_summary_item.dart';
import '../models/order_timeline_event.dart';
import '../models/order_type.dart';
import '../models/refund_result.dart';
import '../models/refund_type.dart';
import '../../pos/models/order_receipt.dart';
import '../../pos/models/order_receipt_mapper.dart';
import '../../pos/models/payment_method.dart';
import '../../pos/models/payment_result.dart';
import '../../pos/models/payment_result_mapper.dart';
import '../../pos/models/payment_summary.dart';

class OrdersRepository {
  const OrdersRepository({this.apiClient});

  final DioApiClient? apiClient;

  bool get usesBackend => apiClient != null;

  Future<List<Branch>> getBranches() async {
    if (!usesBackend) {
      return const <Branch>[
        Branch(
          id: 1,
          name: 'Downtown',
          currency: 'SYP',
          timezone: 'Asia/Damascus',
          isActive: true,
        ),
      ];
    }

    final dynamic response = await apiClient!.get('branches');
    return readMapList(response).map(Branch.fromJson).toList(growable: false);
  }

  Future<OrderPage> getOrders({
    required int branchId,
    OrdersFilter? filter,
    int page = 1,
    int perPage = 25,
  }) async {
    final int safeRequestedPage = page > 0 ? page : 1;
    final int safeRequestedPerPage = perPage.clamp(1, 100).toInt();
    if (!usesBackend) {
      return OrderPage.fromOrders(
        _fakeOrders(filter),
        page: safeRequestedPage,
        perPage: safeRequestedPerPage,
      );
    }

    final Map<String, dynamic> query = _queryForFilter(
      branchId: branchId,
      filter: filter,
      page: safeRequestedPage,
      perPage: safeRequestedPerPage,
    );
    _debugLog('GET /orders $query');

    final dynamic response = await apiClient!.getEnvelope(
      'orders',
      queryParameters: query,
    );
    final Map<String, dynamic> envelope = _mapFromJson(response);
    final List<OrderSummary> orders = readMapList(
      envelope['data'],
    ).map(_summaryFromJson).toList(growable: false);
    final Map<String, dynamic> meta = _mapFromJson(envelope['meta']);
    final int safePage = _positiveInt(
      meta['currentPage'],
      fallback: safeRequestedPage,
    );
    final int safePerPage = _positiveInt(
      meta['perPage'],
      fallback: safeRequestedPerPage,
    ).clamp(1, 100).toInt();
    final int safeTotal = _nonNegativeInt(
      meta['total'],
      fallback: orders.length,
    );
    final int calculatedLastPage = safeTotal == 0
        ? 1
        : ((safeTotal + safePerPage - 1) ~/ safePerPage);
    final int safeLastPage = _positiveInt(
      meta['lastPage'],
      fallback: calculatedLastPage,
    );

    _debugLog('Loaded ${orders.length} orders for filter $filter');
    return OrderPage(
      orders: orders,
      currentPage: safePage,
      lastPage: safeLastPage,
      perPage: safePerPage,
      total: safeTotal,
    );
  }

  Future<OrderPage> getOrderPage({
    required int branchId,
    OrdersFilter? filter,
    int page = 1,
    int perPage = 25,
  }) => getOrders(
    branchId: branchId,
    filter: filter,
    page: page,
    perPage: perPage,
  );

  Future<OrderDetail> getOrderDetail(int orderId) async {
    if (!usesBackend) {
      return _fakeOrderDetail(orderId.toString());
    }

    _debugLog('GET /orders/$orderId');
    final dynamic response = await apiClient!.get('orders/$orderId');
    final OrderDetail detail = _detailFromJson(
      Map<String, dynamic>.from(response as Map),
    );
    _debugLog('Loaded order $orderId detail with ${detail.items.length} items');

    return detail;
  }

  Future<void> cancelOrder(int orderId) async {
    if (!usesBackend) {
      throw StateError('Order cancellation requires a backend connection.');
    }

    _debugLog('DELETE /orders/$orderId');
    await apiClient!.delete('orders/$orderId');
  }

  Future<PaymentSummary> getPaymentSummary({
    required int orderId,
    double? amountReceived,
  }) async {
    if (!usesBackend) {
      final OrderDetail detail = await _fakeOrderDetail(orderId.toString());
      final double received = amountReceived ?? detail.total;
      return PaymentSummary(
        orderId: orderId,
        orderNumber: detail.displayNumber,
        totalDue: detail.total,
        itemCount: detail.items.fold<int>(
          0,
          (int count, OrderDetailItem item) => count + item.quantity,
        ),
        amountReceived: received,
        changeDue: max(0, received - detail.total),
        methods: const <String>['cash', 'card'],
        quickAmounts: <double>[detail.total],
        outstandingAmount: detail.total,
        orderStatus: _backendStatusFor(detail.status),
        paymentStatus: detail.paymentStatus,
        canPay: detail.canPay,
        blockedReason: detail.canPay
            ? null
            : 'This order cannot be paid in its current state.',
      );
    }

    final Map<String, dynamic> query = <String, dynamic>{};
    if (amountReceived != null) {
      query['amountReceived'] = amountReceived;
    }
    final dynamic response = await apiClient!.get(
      'orders/$orderId/payment-summary',
      queryParameters: query,
    );
    return PaymentSummary.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<PaymentResult> payOrder({
    required int orderId,
    required String method,
    required double amount,
    required String idempotencyKey,
    String? reference,
    required double totalDue,
  }) async {
    if (!usesBackend) {
      return PaymentResult(
        method: paymentMethodFromApi(method),
        totalDue: totalDue,
        amountReceived: amount,
        changeDue: max(0, amount - totalDue),
        status: 'completed',
      );
    }

    final dynamic response = await apiClient!.post(
      'orders/$orderId/pay',
      data: <String, dynamic>{
        'method': method,
        'amount': amount,
        'reference': reference,
        'idempotencyKey': idempotencyKey,
      },
    );
    return paymentResultFromJson(
      Map<String, dynamic>.from(response as Map),
      totalDue: totalDue,
    );
  }

  Future<OrderReceipt> getReceipt(int orderId) async {
    if (!usesBackend) {
      throw StateError('Receipts are available only in backend mode.');
    }

    final dynamic response = await apiClient!.get('orders/$orderId/receipt');
    return orderReceiptFromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<RefundResult> submitRefund({
    required RefundResult request,
    required String idempotencyKey,
  }) async {
    if (!usesBackend) {
      return request;
    }
    final dynamic response = await apiClient!.post(
      'orders/${request.orderId}/refunds',
      data: <String, dynamic>{
        'type': request.type == RefundType.full ? 'full' : 'partial',
        'amount': request.amount,
        'reason': request.reason,
        'managerNotes': request.managerNotes,
        'idempotencyKey': idempotencyKey,
      },
    );
    final Map<String, dynamic> json = Map<String, dynamic>.from(
      response as Map,
    );
    return RefundResult(
      orderId: readString(json['orderId'], fallback: request.orderId),
      type: readString(json['type']) == 'full'
          ? RefundType.full
          : RefundType.partial,
      amount: readDouble(json['amount'], fallback: request.amount),
      reason: readString(json['reason'], fallback: request.reason),
      managerNotes: request.managerNotes,
      refundedAt:
          DateTime.tryParse(readString(json['refundedAt'])) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _queryForFilter({
    required int branchId,
    OrdersFilter? filter,
    required int page,
    required int perPage,
  }) {
    final Map<String, dynamic> query = <String, dynamic>{
      'branchId': branchId,
      'page': page,
      'perPage': perPage,
    };

    switch (filter) {
      case OrdersFilter.activeOrders:
        query['status'] = 'draft';
      case OrdersFilter.heldOrders:
        query['status'] = 'held';
      case OrdersFilter.dineIn:
        query['orderType'] = 'dine_in';
      case OrdersFilter.takeaway:
        query['orderType'] = 'takeaway';
      case null:
        break;
    }

    return query;
  }

  OrderSummary _summaryFromJson(Map<String, dynamic> json) {
    final int backendId = readInt(json['id']) ?? 0;
    final List<OrderSummaryItem> items = readMapList(
      json['itemPreview'],
    ).map(_summaryItemFromJson).toList(growable: false);

    return OrderSummary(
      id: backendId.toString(),
      backendId: backendId,
      displayNumber:
          '#${readString(json['orderNumber'], fallback: backendId.toString())}',
      type: _typeFromBackend(readString(json['orderType'])),
      customerName: _titleForOrder(json),
      status: _statusFromBackend(readString(json['status'])),
      paymentStatus: readString(json['paymentStatus'], fallback: 'unpaid'),
      itemCount: readDouble(json['itemCount']),
      timeAgo: _timeLabel(readString(json['createdAt'])),
      items: items,
      total: _totalFromJson(json, 'total'),
    );
  }

  OrderSummaryItem _summaryItemFromJson(Map<String, dynamic> json) {
    return OrderSummaryItem(
      quantity: readDouble(json['quantity']),
      name: readString(json['name'], fallback: 'Item'),
      total: readDouble(json['lineTotal'], fallback: readDouble(json['total'])),
    );
  }

  OrderDetail _detailFromJson(Map<String, dynamic> json) {
    final int backendId = readInt(json['id']) ?? 0;
    final List<OrderDetailItem> items = readMapList(
      json['items'],
    ).map(_detailItemFromJson).toList(growable: false);
    final List<Map<String, dynamic>> refunds = readMapList(json['refunds']);
    final List<OrderRefund> refundRecords = refunds
        .map(_refundFromJson)
        .toList(growable: false);
    final double refundedAmount = readDouble(
      json['refundedAmount'],
      fallback: refunds.fold<double>(0, (
        double total,
        Map<String, dynamic> refund,
      ) {
        return readString(refund['status']).toLowerCase() == 'completed'
            ? total + readDouble(refund['amount'])
            : total;
      }),
    );

    return OrderDetail(
      id: backendId.toString(),
      displayNumber:
          '#${readString(json['orderNumber'], fallback: backendId.toString())}',
      status: _statusFromBackend(readString(json['status'])),
      paymentStatus: readString(json['paymentStatus'], fallback: 'unpaid'),
      orderType: _typeFromBackend(readString(json['orderType'])).label,
      createdAt: _dateFromBackend(readString(json['createdAt'])),
      customerName: readString(
        _mapFromJson(json['customer'])['name'],
        fallback: _titleForOrder(json),
      ),
      customerPhone: readString(_mapFromJson(json['customer'])['phone']),
      customerEmail: readString(_mapFromJson(json['customer'])['email']),
      items: items,
      subtotal: _totalFromJson(json, 'subtotal'),
      tax: _totalFromJson(json, 'taxTotal'),
      taxRate: readDouble(
        _mapFromJson(json['totals'])['taxRate'],
        fallback: TaxConfig.defaultTaxRate,
      ),
      tip: _totalFromJson(json, 'serviceTotal'),
      total: _totalFromJson(json, 'total'),
      payments: readMapList(
        json['payments'],
      ).map(_paymentRecordFromJson).toList(growable: false),
      payment: _paymentFromJson(readMapList(json['payments'])),
      timeline: _timelineFromJson(readMapList(json['timeline'])),
      isRefunded:
          _statusFromBackend(readString(json['status'])) ==
          OrderStatus.refunded,
      refundedAmount: refundedAmount,
      refundedAt: _latestRefundedAt(refunds),
      refundableAmount: readDouble(json['refundableAmount']),
      refunds: refundRecords,
      branchId: readInt(json['branchId']),
      publishedMenuVersionId: readInt(json['publishedMenuVersionId']),
      serverCanResume: json.containsKey('canResume')
          ? readBool(json['canResume'])
          : null,
      resumeBlockerCode: json.containsKey('resumeBlockerCode')
          ? readString(json['resumeBlockerCode']).trim()
          : null,
      resumeBlockedReason: json.containsKey('resumeBlockedReason')
          ? readString(json['resumeBlockedReason']).trim()
          : null,
    );
  }

  OrderRefund _refundFromJson(Map<String, dynamic> json) {
    return OrderRefund(
      id: readString(json['id']),
      type: readString(json['type']).toLowerCase() == 'full'
          ? RefundType.full
          : RefundType.partial,
      amount: readDouble(json['amount']),
      reason: readString(json['reason']),
      managerNotes: readString(json['managerNotes']),
      status: readString(json['status']),
      refundedAt: _dateFromBackend(readString(json['refundedAt'])),
      idempotencyKey: json.containsKey('idempotencyKey')
          ? readString(json['idempotencyKey'])
          : null,
    );
  }

  OrderDetailItem _detailItemFromJson(Map<String, dynamic> json) {
    final List<String> modifiers = readMapList(json['modifiers'])
        .map(_modifierLabel)
        .where((String label) => label.isNotEmpty)
        .toList(growable: true);
    final String note = readString(json['note']).trim();
    if (note.isNotEmpty) {
      modifiers.add('Note: $note');
    }

    return OrderDetailItem(
      quantity: readInt(json['quantity']) ?? 0,
      name: readString(json['name'], fallback: 'Item'),
      modifiers: modifiers,
      total: readDouble(json['lineTotal'], fallback: readDouble(json['total'])),
    );
  }

  OrderPaymentSummary _paymentFromJson(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) {
      return const OrderPaymentSummary(
        methodLabel: 'No payment recorded yet.',
        statusLabel: '',
        authCode: '',
        amount: 0,
        hasPayment: false,
      );
    }

    final Map<String, dynamic> payment = payments.last;
    return OrderPaymentSummary(
      method: readString(payment['method']).trim().toLowerCase(),
      methodLabel: _titleCase(
        readString(payment['method'], fallback: 'Payment'),
      ),
      statusLabel: _titleCase(
        readString(payment['status'], fallback: 'Pending'),
      ),
      authCode: readString(payment['reference'], fallback: '-'),
      amount: readDouble(payment['amount']),
      status: readString(
        payment['status'],
        fallback: 'pending',
      ).trim().toLowerCase(),
      paymentId: readInt(payment['id']),
      idempotencyKey: readString(payment['idempotencyKey']).trim().isEmpty
          ? null
          : readString(payment['idempotencyKey']).trim(),
    );
  }

  OrderPaymentSummary _paymentRecordFromJson(Map<String, dynamic> json) {
    return _paymentFromJson(<Map<String, dynamic>>[json]);
  }

  List<OrderTimelineEvent> _timelineFromJson(
    List<Map<String, dynamic>> events,
  ) {
    if (events.isEmpty) {
      return const <OrderTimelineEvent>[];
    }

    return events
        .map(
          (Map<String, dynamic> event) => OrderTimelineEvent(
            title: readString(
              event['label'],
              fallback: _titleCase(readString(event['type'])),
            ),
            subtitle: 'Backend event',
            time: _dateFromBackend(readString(event['occurredAt'])),
          ),
        )
        .toList(growable: false);
  }

  String _modifierLabel(Map<String, dynamic> json) {
    final String groupName = readString(json['groupName']).trim();
    final String optionName = readString(json['optionName']).trim();
    final double priceDelta = readDouble(json['priceDelta']);
    final String price = priceDelta == 0
        ? ''
        : ' (${priceDelta > 0 ? '+' : '-'}${CurrencyFormatter.format(priceDelta.abs())})';

    if (groupName.isEmpty && optionName.isEmpty) {
      return '';
    }
    if (groupName.isEmpty) {
      return '$optionName$price';
    }
    if (optionName.isEmpty) {
      return groupName;
    }

    return '$groupName: $optionName$price';
  }

  OrderSummaryType _typeFromBackend(String value) {
    return switch (value.toLowerCase()) {
      'dine_in' => OrderSummaryType.dineIn,
      'delivery' => OrderSummaryType.delivery,
      _ => OrderSummaryType.takeaway,
    };
  }

  String _backendStatusFor(OrderStatus status) {
    return switch (status) {
      OrderStatus.preparing => 'draft',
      OrderStatus.held => 'held',
      OrderStatus.ready => 'ready',
      OrderStatus.paid => 'paid',
      OrderStatus.completed => 'paid',
      OrderStatus.cancelled => 'cancelled',
      OrderStatus.refunded => 'refunded',
      OrderStatus.partiallyRefunded => 'partially_refunded',
    };
  }

  OrderStatus _statusFromBackend(String value) {
    return switch (value.toLowerCase()) {
      'held' => OrderStatus.held,
      'ready' => OrderStatus.ready,
      'paid' || 'completed' => OrderStatus.paid,
      'refunded' => OrderStatus.refunded,
      'partially_refunded' => OrderStatus.partiallyRefunded,
      'cancelled' || 'canceled' => OrderStatus.cancelled,
      _ => OrderStatus.preparing,
    };
  }

  bool _matchesFilter(OrderSummary order, OrdersFilter? filter) {
    return switch (filter) {
      OrdersFilter.heldOrders => order.status == OrderStatus.held,
      OrdersFilter.dineIn => order.type == OrderSummaryType.dineIn,
      OrdersFilter.takeaway => order.type == OrderSummaryType.takeaway,
      OrdersFilter.activeOrders =>
        order.status == OrderStatus.preparing ||
            order.status == OrderStatus.ready,
      null => true,
    };
  }

  String _titleForOrder(Map<String, dynamic> json) {
    final Map<String, dynamic> customer = _mapFromJson(json['customer']);
    final String customerName = readString(customer['name']).trim();
    if (customerName.isNotEmpty) {
      return customerName;
    }

    final Map<String, dynamic> table = _mapFromJson(json['table']);
    final String tableName = readString(table['name']).trim();
    if (tableName.isNotEmpty) {
      return tableName;
    }

    return 'Walk-in';
  }

  double _totalFromJson(Map<String, dynamic> json, String key) {
    return readDouble(_mapFromJson(json['totals'])[key]);
  }

  Map<String, dynamic> _mapFromJson(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  int _positiveInt(dynamic value, {required int fallback}) {
    final int? parsed = readInt(value);
    return parsed != null && parsed > 0
        ? parsed
        : (fallback > 0 ? fallback : 1);
  }

  int _nonNegativeInt(dynamic value, {required int fallback}) {
    final int? parsed = readInt(value);
    return parsed != null && parsed >= 0
        ? parsed
        : fallback.clamp(0, 1 << 31).toInt();
  }

  DateTime _dateFromBackend(String value) {
    return parseBackendDateTime(value) ?? DateTime.now();
  }

  DateTime? _latestRefundedAt(List<Map<String, dynamic>> refunds) {
    DateTime? latest;
    for (final Map<String, dynamic> refund in refunds) {
      final DateTime? refundedAt = parseBackendDateTime(
        readString(refund['refundedAt']),
      );
      if (refundedAt == null) {
        continue;
      }
      if (latest == null || refundedAt.isAfter(latest)) {
        latest = refundedAt;
      }
    }

    return latest;
  }

  String _timeLabel(String value) {
    final DateTime? createdAt = parseBackendDateTime(value);
    if (createdAt == null) {
      return 'Just now';
    }

    final Duration age = DateTime.now().difference(createdAt);
    if (age.inMinutes < 1) {
      return 'Just now';
    }
    if (age.inHours < 1) {
      return '${age.inMinutes}m ago';
    }
    if (age.inDays < 1) {
      return '${age.inHours}h ago';
    }

    return '${age.inDays}d ago';
  }

  String _titleCase(String value) {
    final String cleanValue = value.replaceAll('_', ' ').trim();
    if (cleanValue.isEmpty) {
      return '';
    }

    return cleanValue
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .map((String part) {
          final String lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[OrdersRepository] $message');
    }
  }

  Future<OrderDetail> _fakeOrderDetail(String orderId) async {
    final OrderSummary summary = (await getOrders(branchId: 1)).orders
        .firstWhere(
          (OrderSummary order) => order.id == orderId,
          orElse: () => throw StateError('Order not found.'),
        );

    final List<OrderDetailItem> items = switch (orderId) {
      '1042' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 2,
          name: 'Oat Flat White',
          modifiers: <String>['Size: Large (+0.50 SYP)', 'Milk: Oat Milk'],
          total: 11,
        ),
        OrderDetailItem(
          quantity: 1,
          name: 'Almond Croissant',
          modifiers: <String>['Warmed', 'Butter on side'],
          total: 5.50,
        ),
      ],
      '1043' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 1,
          name: 'Batch Brew',
          modifiers: <String>['Medium roast', 'No room'],
          total: 4,
        ),
      ],
      '1041' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 2,
          name: 'Iced Latte',
          modifiers: <String>['Size: Large (+0.50 SYP)', 'Vanilla (+0.75 SYP)'],
          total: 12,
        ),
        OrderDetailItem(
          quantity: 2,
          name: 'Ham & Cheese Toastie',
          modifiers: <String>['Extra toasted', 'Dijon on side'],
          total: 18,
        ),
      ],
      '1044' => const <OrderDetailItem>[
        OrderDetailItem(
          quantity: 3,
          name: 'Cortado',
          modifiers: <String>['Ceramic cup', 'Extra hot'],
          total: 13.50,
        ),
        OrderDetailItem(
          quantity: 2,
          name: 'Avo Toast',
          modifiers: <String>['Add Poached Egg (+1.50 SYP)', 'Chili Flakes'],
          total: 28,
        ),
      ],
      _ =>
        summary.items
            .map(
              (OrderSummaryItem item) => OrderDetailItem(
                quantity: item.quantity.toInt(),
                name: item.name,
                modifiers: const <String>[],
                total: item.total,
              ),
            )
            .toList(growable: false),
    };

    final double subtotal = items.fold<double>(
      0,
      (double total, OrderDetailItem item) => total + item.total,
    );
    final double tax = _roundCurrency(subtotal * TaxConfig.defaultTaxRate);
    final double tip = _roundCurrency(subtotal * 0.15);
    final double total = _roundCurrency(subtotal + tax + tip);
    final DateTime createdAt = DateTime(2023, 10, 24, 10, 42);

    return OrderDetail(
      id: summary.id,
      displayNumber: summary.displayNumber,
      status: summary.status,
      paymentStatus: summary.paymentStatus,
      orderType: summary.type.label,
      createdAt: createdAt,
      customerName: _customerNameFor(summary),
      customerPhone: _customerPhoneFor(summary),
      customerEmail: _customerEmailFor(summary),
      items: items,
      subtotal: subtotal,
      tax: tax,
      taxRate: TaxConfig.defaultTaxRate,
      tip: tip,
      total: total,
      payment: OrderPaymentSummary(
        method: 'card',
        methodLabel: 'Visa ending in 4242',
        statusLabel: summary.status == OrderStatus.held
            ? 'Pending'
            : 'Approved',
        authCode: summary.status == OrderStatus.held ? '-' : '098765',
        amount: total,
        status: summary.status == OrderStatus.held ? 'pending' : 'completed',
      ),
      timeline: _fakeTimelineFor(createdAt, summary.status),
      refundableAmount: summary.status == OrderStatus.held ? 0 : total,
    );
  }

  List<OrderSummary> _fakeOrders(OrdersFilter? filter) {
    final List<OrderSummary> orders = const <OrderSummary>[
      OrderSummary(
        id: '1042',
        backendId: 1042,
        displayNumber: '#ORD-1042',
        type: OrderSummaryType.dineIn,
        customerName: 'Sarah Jenkins',
        status: OrderStatus.preparing,
        itemCount: 3,
        timeAgo: '8m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 2, name: 'Oat Flat White', total: 11),
          OrderSummaryItem(quantity: 1, name: 'Almond Croissant', total: 5.50),
        ],
        total: 16.50,
      ),
      OrderSummary(
        id: '1043',
        backendId: 1043,
        displayNumber: '#ORD-1043',
        type: OrderSummaryType.takeaway,
        customerName: 'Walk-in 4',
        status: OrderStatus.held,
        itemCount: 1,
        timeAgo: '12m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 1, name: 'Batch Brew', total: 4),
        ],
        total: 4,
      ),
      OrderSummary(
        id: '1041',
        backendId: 1041,
        displayNumber: '#ORD-1041',
        type: OrderSummaryType.takeaway,
        customerName: 'Marcus T.',
        status: OrderStatus.ready,
        itemCount: 4,
        timeAgo: '21m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 2, name: 'Iced Latte', total: 12),
          OrderSummaryItem(
            quantity: 2,
            name: 'Ham & Cheese Toastie',
            total: 18,
          ),
        ],
        total: 30,
      ),
      OrderSummary(
        id: '1044',
        backendId: 1044,
        displayNumber: '#ORD-1044',
        type: OrderSummaryType.dineIn,
        customerName: 'Table 12',
        status: OrderStatus.preparing,
        itemCount: 5,
        timeAgo: '5m ago',
        items: <OrderSummaryItem>[
          OrderSummaryItem(quantity: 3, name: 'Cortado', total: 13.50),
          OrderSummaryItem(quantity: 2, name: 'Avo Toast', total: 28),
        ],
        total: 41.50,
      ),
    ];

    return orders
        .where((OrderSummary order) => _matchesFilter(order, filter))
        .toList(growable: false);
  }

  double _roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  String _customerNameFor(OrderSummary order) {
    if (order.customerName.startsWith('Walk-in') ||
        order.customerName.startsWith('Table')) {
      return '';
    }

    return order.customerName;
  }

  String _customerPhoneFor(OrderSummary order) {
    return switch (order.id) {
      '1041' => '(555) 222-0141',
      '1042' => '(555) 123-4567',
      _ => '',
    };
  }

  String _customerEmailFor(OrderSummary order) {
    return switch (order.id) {
      '1041' => 'marcus@example.com',
      '1042' => 'sarah@example.com',
      _ => '',
    };
  }

  List<OrderTimelineEvent> _fakeTimelineFor(
    DateTime createdAt,
    OrderStatus status,
  ) {
    final List<OrderTimelineEvent> events = <OrderTimelineEvent>[
      OrderTimelineEvent(
        title: 'Order Created',
        subtitle: 'POS Register 2',
        time: createdAt,
      ),
      OrderTimelineEvent(
        title: 'Payment Received',
        subtitle: 'Terminal 1',
        time: createdAt.add(const Duration(minutes: 3)),
      ),
    ];

    if (status == OrderStatus.completed ||
        status == OrderStatus.paid ||
        status == OrderStatus.ready) {
      events.insert(
        0,
        OrderTimelineEvent(
          title: status == OrderStatus.paid
              ? 'Payment Received'
              : status == OrderStatus.completed
              ? 'Order Completed'
              : 'Order Ready',
          subtitle: 'Verified by Barista Sarah',
          time: createdAt.add(const Duration(minutes: 6)),
        ),
      );
    } else if (status == OrderStatus.held) {
      events.insert(
        0,
        OrderTimelineEvent(
          title: 'Order Held',
          subtitle: 'Waiting for customer confirmation',
          time: createdAt.add(const Duration(minutes: 4)),
        ),
      );
    } else {
      events.insert(
        0,
        OrderTimelineEvent(
          title: 'Order Preparing',
          subtitle: 'Kitchen display station',
          time: createdAt.add(const Duration(minutes: 4)),
        ),
      );
    }

    return events;
  }
}
