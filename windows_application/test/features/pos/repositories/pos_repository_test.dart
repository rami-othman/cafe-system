import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/pos/models/create_order_request.dart';
import 'package:windows_application/features/pos/models/pos_quick_create_customer_request.dart';
import 'package:windows_application/features/pos/models/order_type.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  test(
    'maps products to category names when product payload has categoryId',
    () async {
      final PosRepository repository = PosRepository(
        apiClient: _FakePosApiClient(),
      );

      final List<String> categories = await repository.getCategories(
        branchId: 1,
      );
      final products = await repository.getProducts(branchId: 1);

      expect(categories, contains('Coffee'));
      expect(products.single.name, 'Espresso');
      expect(products.single.category, 'Coffee');
    },
  );

  test('POS order payload never allows the cashier to choose a warehouse', () {
    const CreateOrderRequest request = CreateOrderRequest(
      branchId: 7,
      shiftId: 11,
      orderType: OrderType.takeaway,
      items: <AddOrderItemRequest>[
        AddOrderItemRequest(productId: 3, quantity: 1),
      ],
    );

    expect(request.toJson(), isNot(contains('warehouseId')));
  });

  test('zero-balance payment omits the tender method', () async {
    final _FakePosApiClient api = _FakePosApiClient();
    final PosRepository repository = PosRepository(apiClient: api);

    await repository.payOrder(
      orderId: 5,
      method: 'cash',
      amount: 0,
      totalDue: 0,
      idempotencyKey: 'zero-balance',
    );

    expect(api.paymentPayload, isNot(contains('method')));
    expect(api.paymentPayload!['amount'], 0);
  });

  test(
    'backend customer search trims the query and never uses fake data',
    () async {
      final _FakePosApiClient api = _FakePosApiClient();
      final PosRepository repository = PosRepository(apiClient: api);

      final customers = await repository.getCustomers(search: '  Alice  ');

      expect(api.customerQuery, 'Alice');
      expect(customers.single.backendId, 41);
      expect(customers.single.name, 'Alice Backend');
    },
  );

  test(
    'backend customer failures are propagated instead of returning fake data',
    () async {
      final PosRepository repository = PosRepository(
        apiClient: _FakePosApiClient(failCustomers: true),
      );

      expect(repository.getCustomers(), throwsA(isA<ApiException>()));
    },
  );

  test('customer groups use a bounded authoritative envelope', () async {
    final _FakePosApiClient api = _FakePosApiClient();
    final PosRepository repository = PosRepository(apiClient: api);

    final groups = await repository.getCustomerGroups(perPage: 9999);

    expect(api.groupQuery, <String, dynamic>{'perPage': 100});
    expect(groups.single.id, 7);
    expect(groups.single.name, 'VIP');
  });

  test(
    'quick create sends only operational fields and parses the authoritative customer',
    () async {
      final _FakePosApiClient api = _FakePosApiClient();
      final PosRepository repository = PosRepository(apiClient: api);
      const PosQuickCreateCustomerRequest request =
          PosQuickCreateCustomerRequest(
            name: '  New Customer ',
            phone: ' 091234567 ',
            notes: '  note ',
            groupIds: <int>{4, 1},
          );

      final customer = await repository.quickCreateCustomer(request);

      expect(api.quickCreatePayload, <String, dynamic>{
        'name': 'New Customer',
        'phone': '091234567',
        'notes': 'note',
        'groupIds': <int>[1, 4],
      });
      expect(customer.backendId, 88);
      expect(customer.name, 'Authoritative Customer');
      expect(customer.phone, '091234567');
      expect(customer.tier, isNull);
      expect(customer.points, isNull);
    },
  );
}

class _FakePosApiClient extends DioApiClient {
  _FakePosApiClient({this.failCustomers = false}) : super(dio: Dio());

  final bool failCustomers;
  String? customerQuery;
  Map<String, dynamic>? groupQuery;
  Map<String, dynamic>? paymentPayload;
  Map<String, dynamic>? quickCreatePayload;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool suppressAuthenticationFailure = false,
    bool debugMenuScheduleSave = false,
  }) async {
    if (path == 'customers') {
      if (failCustomers) {
        throw const ApiException(
          message: 'network failure',
          type: ApiErrorType.networkUnavailable,
        );
      }
      customerQuery = queryParameters?['search'] as String?;
      return <Map<String, Object?>>[
        <String, Object?>{
          'id': 41,
          'name': 'Alice Backend',
          'phone': '091234567',
          'tier': 'VIP',
          'loyaltyPoints': 100,
        },
      ];
    }
    return switch (path) {
      'menu/categories' => <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Coffee'},
      ],
      'menu/products' => <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'categoryId': 1,
          'name': 'Espresso',
          'basePrice': 3.5,
          'isAvailable': true,
        },
      ],
      _ => throw StateError('Unexpected path $path'),
    };
  }

  @override
  Future<dynamic> getEnvelope(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path != 'customer-groups') {
      throw StateError('Unexpected envelope path $path');
    }
    groupQuery = queryParameters;
    return <String, Object?>{
      'data': <Map<String, Object?>>[
        <String, Object?>{'id': 7, 'name': 'VIP'},
      ],
      'meta': <String, Object?>{
        'currentPage': 1,
        'lastPage': 1,
        'perPage': 100,
        'total': 1,
      },
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path.startsWith('orders/') && path.endsWith('/pay')) {
      paymentPayload = Map<String, dynamic>.from(data! as Map);
      return <String, Object?>{
        'payment': <String, Object?>{
          'id': 5,
          'method': 'zero_balance',
          'amount': 0,
          'status': 'completed',
        },
        'changeDue': 0,
      };
    }
    if (path != 'customers/quick-create') {
      throw StateError('Unexpected post path $path');
    }
    quickCreatePayload = Map<String, dynamic>.from(data! as Map);
    return <String, Object?>{
      'id': 88,
      'name': 'Authoritative Customer',
      'notes': 'note',
      'phones': <Map<String, Object?>>[
        <String, Object?>{
          'rawNumber': '091234567',
          'isPrimary': true,
          'type': 'mobile',
        },
      ],
      'groups': const <Map<String, Object?>>[],
    };
  }
}
