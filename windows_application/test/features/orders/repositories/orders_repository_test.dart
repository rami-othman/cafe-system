import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/orders/controllers/orders_state.dart';
import 'package:windows_application/features/orders/models/order_status.dart';
import 'package:windows_application/features/orders/models/order_type.dart';
import 'package:windows_application/features/orders/repositories/orders_repository.dart';

void main() {
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

      final orders = await repository.getOrders(
        branchId: 1,
        filter: OrdersFilter.dineIn,
      );

      expect(requestedUris.single.queryParameters, <String, String>{
        'branchId': '1',
        'orderType': 'dine_in',
      });
      expect(orders.single.id, '1');
      expect(orders.single.backendId, 1);
      expect(orders.single.displayNumber, '#20260620-0001');
      expect(orders.single.type, OrderSummaryType.dineIn);
      expect(orders.single.status, OrderStatus.preparing);
      expect(orders.single.customerName, 'Jane Doe');
      expect(orders.single.itemCount, 0);
      expect(orders.single.total, 15.66);
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
      expect(detail.status, OrderStatus.completed);
      expect(detail.orderType, 'Takeaway');
      expect(detail.items.single.modifiers, <String>[
        'Milk: Oat Milk (+\$0.75)',
        'Note: Extra hot',
      ]);
      expect(detail.payment.methodLabel, 'Cash');
      expect(detail.payment.amount, 15.66);
      expect(detail.refundedAmount, 2.5);
      expect(detail.timeline.single.title, 'Order created');
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
    'totals': <String, dynamic>{
      'subtotal': 14.5,
      'discountTotal': 0,
      'taxRate': 0.08,
      'taxTotal': 1.16,
      'serviceTotal': 0,
      'total': 15.66,
    },
    'note': null,
    'createdAt': '2026-06-20T10:00:00Z',
    'updatedAt': '2026-06-20T10:05:00Z',
  };
}
