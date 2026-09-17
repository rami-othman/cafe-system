import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_page.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_type.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';
import 'package:windows_application/features/pos/models/payment_method.dart';
import 'package:windows_application/features/pos/models/payment_summary.dart';

void main() {
  test(
    'maps the paginated summary envelope without deriving count from preview',
    () async {
      final List<Uri> requestedUris = <Uri>[];
      final OrdersRepository repository = OrdersRepository(
        apiClient: _clientFor((RequestOptions options) {
          requestedUris.add(options.uri);
          return Response<dynamic>(
            requestOptions: options,
            data: <String, dynamic>{
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 77,
                  'orderNumber': 'ORD-077',
                  'branchId': 4,
                  'orderType': 'takeaway',
                  'status': 'draft',
                  'paymentStatus': 'unpaid',
                  'customer': null,
                  'table': <String, dynamic>{'id': 9, 'name': 'Table 9'},
                  'itemCount': 7.5,
                  'itemPreview': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'quantity': 1.5,
                      'name': 'Latte',
                      'lineTotal': 4.5,
                    },
                  ],
                  'totals': <String, dynamic>{'total': 12.5},
                  'createdAt': '2026-09-14T10:00:00Z',
                },
              ],
              'meta': <String, dynamic>{
                'currentPage': 2,
                'lastPage': 4,
                'perPage': 25,
                'total': 88,
              },
            },
          );
        }),
      );

      final OrderPage page = await repository.getOrderPage(
        branchId: 4,
        filter: OrdersFilter.activeOrders,
        page: 2,
        perPage: 25,
      );

      expect(requestedUris.single.queryParameters, <String, String>{
        'branchId': '4',
        'status': 'draft',
        'page': '2',
        'perPage': '25',
      });
      expect(page.currentPage, 2);
      expect(page.lastPage, 4);
      expect(page.perPage, 25);
      expect(page.total, 88);
      expect(page.orders.single.backendId, 77);
      expect(page.orders.single.id, '77');
      expect(page.orders.single.displayNumber, '#ORD-077');
      expect(page.orders.single.itemCount, 7.5);
      expect(page.orders.single.items.single.quantity, 1.5);
      expect(page.orders.single.items.single.name, 'Latte');
    },
  );

  test('treats a timezone-less order timestamp as UTC', () async {
    final OrdersRepository repository = OrdersRepository(
      apiClient: _clientFor((RequestOptions options) {
        return Response<dynamic>(
          requestOptions: options,
          data: <String, dynamic>{
            'data': _summaryJson(
              id: 1,
              orderNumber: 'ORD-1',
              orderType: 'takeaway',
              status: 'draft',
              createdAt: '2026-08-27 07:30:00',
            ),
          },
        );
      }),
    );

    final detail = await repository.getOrderDetail(1);

    expect(detail.createdAt.toUtc(), DateTime.utc(2026, 8, 27, 7, 30));
  });

  test('handles missing or malformed pagination metadata safely', () async {
    final OrdersRepository repository = OrdersRepository(
      apiClient: _clientFor((RequestOptions options) {
        return Response<dynamic>(
          requestOptions: options,
          data: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'orderNumber': 'ORD-1',
                'branchId': 1,
                'orderType': 'takeaway',
                'status': 'draft',
                'itemCount': 3,
                'itemPreview': const <Map<String, dynamic>>[],
                'totals': <String, dynamic>{'total': 1},
                'createdAt': 'not-a-date',
              },
            ],
            'meta': <String, dynamic>{'currentPage': 'bad', 'total': -4},
          },
        );
      }),
    );

    final OrderPage page = await repository.getOrderPage(
      branchId: 1,
      page: 3,
      perPage: 10,
    );

    expect(page.currentPage, 3);
    expect(page.lastPage, 1);
    expect(page.perPage, 10);
    expect(page.total, 1);
  });

  test(
    'loads order summaries from backend with filter query parameters',
    () async {
      final List<Uri> requestedUris = <Uri>[];
      final OrdersRepository repository = OrdersRepository(
        apiClient: _clientFor((RequestOptions options) {
          requestedUris.add(options.uri);

          return Response<dynamic>(
            requestOptions: options,
            data: <String, dynamic>{
              'data': <Map<String, dynamic>>[
                _summaryJson(
                  id: 1,
                  orderNumber: '20260620-0001',
                  orderType: 'dine_in',
                  status: 'draft',
                ),
              ],
            },
          );
        }),
      );

      final OrderPage page = await repository.getOrders(
        branchId: 1,
        filter: OrdersFilter.dineIn,
      );

      expect(requestedUris.single.queryParameters, <String, String>{
        'branchId': '1',
        'orderType': 'dine_in',
        'page': '1',
        'perPage': '25',
      });
      expect(page.orders.single.id, '1');
      expect(page.orders.single.backendId, 1);
      expect(page.orders.single.displayNumber, '#20260620-0001');
      expect(page.orders.single.type, OrderSummaryType.dineIn);
      expect(page.orders.single.status, OrderStatus.preparing);
      expect(page.orders.single.customerName, 'Jane Doe');
      expect(page.orders.single.itemCount, 0);
      expect(page.orders.single.total, 15.66);
    },
  );

  test(
    'loads full order details with items payments refunds and timeline',
    () async {
      final List<Uri> requestedUris = <Uri>[];
      final OrdersRepository repository = OrdersRepository(
        apiClient: _clientFor((RequestOptions options) {
          requestedUris.add(options.uri);

          return Response<dynamic>(
            requestOptions: options,
            data: <String, dynamic>{
              'data': _summaryJson(
                id: 7,
                orderNumber: '20260620-0007',
                orderType: 'takeaway',
                status: 'paid',
                items: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 10,
                    'productId': 3,
                    'name': 'Cappuccino',
                    'quantity': 1,
                    'unitPrice': 4.5,
                    'lineTotal': 5.25,
                    'status': 'pending',
                    'modifiers': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'groupName': 'Milk',
                        'optionName': 'Oat Milk',
                        'priceDelta': 0.75,
                      },
                    ],
                    'note': 'Extra hot',
                  },
                ],
                payments: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 1,
                    'method': 'cash',
                    'amount': 15.66,
                    'status': 'completed',
                    'reference': 'CASH-1',
                    'paidAt': '2026-06-20T10:06:00Z',
                  },
                ],
                refunds: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 2,
                    'refundNumber': 'RF-1',
                    'type': 'partial',
                    'amount': 2.5,
                    'reason': 'Customer Request',
                    'status': 'completed',
                    'refundedAt': '2026-06-20T10:08:00Z',
                  },
                ],
                refundedAmount: 2.5,
                refundableAmount: 13.16,
                timeline: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'order_created',
                    'label': 'Order created',
                    'occurredAt': '2026-06-20T10:00:00Z',
                  },
                ],
              ),
            },
          );
        }),
      );

      final detail = await repository.getOrderDetail(7);

      expect(requestedUris.single.path, endsWith('/orders/7'));
      expect(detail.id, '7');
      expect(detail.displayNumber, '#20260620-0007');
      expect(detail.status, OrderStatus.paid);
      expect(detail.orderType, 'Takeaway');
      expect(detail.items.single.modifiers, <String>[
        'Milk: Oat Milk (+0.75 SYP)',
        'Note: Extra hot',
      ]);
      expect(detail.payment.methodLabel, 'Cash');
      expect(detail.payment.amount, 15.66);
      expect(detail.refundedAmount, 2.5);
      expect(detail.refundableAmount, 13.16);
      expect(detail.refunds.single.idempotencyKey, isNull);
      expect(detail.taxRate, 0.08);
      expect(detail.timeline.single.title, 'Order created');
    },
  );

  test(
    'cancels only through the authoritative DELETE order endpoint',
    () async {
      final List<RequestOptions> requests = <RequestOptions>[];
      final OrdersRepository repository = OrdersRepository(
        apiClient: _clientFor((RequestOptions options) {
          requests.add(options);
          return Response<dynamic>(
            requestOptions: options,
            statusCode: 204,
            data: null,
          );
        }),
      );

      await repository.cancelOrder(27);

      expect(requests.single.method, 'DELETE');
      expect(requests.single.path, 'orders/27');
    },
  );

  test(
    'uses the authoritative payment summary, pay, and receipt endpoints',
    () async {
      final List<RequestOptions> requests = <RequestOptions>[];
      final OrdersRepository repository = OrdersRepository(
        apiClient: _clientFor((RequestOptions options) {
          requests.add(options);
          if (options.path.endsWith('/payment-summary')) {
            return Response<dynamic>(
              requestOptions: options,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'orderId': 7,
                  'orderNumber': 'ORD-7',
                  'totalDue': 99,
                  'outstandingAmount': 7,
                  'itemCount': 2,
                  'amountReceived': 7,
                  'changeDue': 0,
                  'methods': <String>['cash', 'card'],
                  'quickAmounts': <double>[7],
                  'orderStatus': 'draft',
                  'paymentStatus': 'unpaid',
                  'canPay': true,
                  'blockerCode': 'WAREHOUSE_NOT_CONFIGURED',
                },
              },
            );
          }
          if (options.path.endsWith('/pay')) {
            return Response<dynamic>(
              requestOptions: options,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'orderId': 7,
                  'changeDue': 3,
                  'payment': <String, dynamic>{
                    'id': 41,
                    'method': 'cash',
                    'amount': 7,
                    'status': 'completed',
                    'reference': 'cash-7',
                  },
                },
              },
            );
          }
          return Response<dynamic>(
            requestOptions: options,
            data: <String, dynamic>{
              'data': <String, dynamic>{
                'orderNumber': 'ORD-7',
                'branchName': 'Downtown',
                'cashierName': 'Cashier',
                'date': '2026-09-14T10:00:00Z',
                'subtotal': 7,
                'discountTotal': 0,
                'taxTotal': 0,
                'total': 7,
                'paymentStatus': 'completed',
                'items': const <Map<String, dynamic>>[],
                'payment': <String, dynamic>{
                  'id': 41,
                  'method': 'cash',
                  'amount': 7,
                  'status': 'completed',
                  'reference': 'cash-7',
                },
              },
            },
          );
        }),
      );

      final PaymentSummary summary = await repository.getPaymentSummary(
        orderId: 7,
      );
      final payment = await repository.payOrder(
        orderId: 7,
        method: PaymentMethod.cash.apiValue,
        amount: 7,
        idempotencyKey: 'payment-key-7',
        reference: 'cash-7',
        totalDue: summary.amountDue,
      );
      final receipt = await repository.getReceipt(7);

      expect(summary.totalDue, 99);
      expect(summary.amountDue, 7);
      expect(summary.paymentStatus, 'unpaid');
      expect(summary.canPay, isTrue);
      expect(summary.blockerCode, 'WAREHOUSE_NOT_CONFIGURED');
      expect(payment.paymentId, 41);
      expect(payment.reference, 'cash-7');
      expect(receipt.payment.paymentId, 41);
      expect(requests.map((RequestOptions request) => request.path), <String>[
        'orders/7/payment-summary',
        'orders/7/pay',
        'orders/7/receipt',
      ]);
      expect(requests[1].data, <String, dynamic>{
        'method': 'cash',
        'amount': 7,
        'reference': 'cash-7',
        'idempotencyKey': 'payment-key-7',
      });
    },
  );
}

DioApiClient _clientFor(Response<dynamic> Function(RequestOptions) responder) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        handler.resolve(responder(options));
      },
    ),
  );

  return DioApiClient(dio: dio);
}

Map<String, dynamic> _summaryJson({
  required int id,
  required String orderNumber,
  required String orderType,
  required String status,
  List<Map<String, dynamic>> items = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> payments = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> refunds = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> timeline = const <Map<String, dynamic>>[],
  double? refundedAmount,
  double? refundableAmount,
  String createdAt = '2026-06-20T10:00:00Z',
}) {
  return <String, dynamic>{
    'id': id,
    'orderNumber': orderNumber,
    'branchId': 1,
    'shiftId': 1,
    'orderType': orderType,
    'status': status,
    'paymentStatus': status == 'paid' ? 'paid' : 'unpaid',
    'table': <String, dynamic>{'id': 1, 'name': 'Table 12', 'code': 'T12'},
    'customer': <String, dynamic>{
      'id': 1,
      'name': 'Jane Doe',
      'phone': '+1 555 0100',
    },
    'items': items,
    'discount': null,
    'payments': payments,
    'refunds': refunds,
    'timeline': timeline,
    'refundedAmount': refundedAmount,
    'refundableAmount': refundableAmount,
    'totals': <String, dynamic>{
      'subtotal': 14.5,
      'discountTotal': 0,
      'taxRate': 0.08,
      'taxTotal': 1.16,
      'serviceTotal': 0,
      'total': 15.66,
    },
    'note': null,
    'createdAt': createdAt,
    'updatedAt': '2026-06-20T10:05:00Z',
  };
}
