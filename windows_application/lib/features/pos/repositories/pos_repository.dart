import 'package:flutter/material.dart';

import '../../../core/network/dio_api_client.dart';
import '../models/available_discount.dart';
import '../models/backend_order.dart';
import '../models/backend_product_detail.dart';
import '../models/branch.dart';
import '../models/create_order_request.dart';
import '../models/customer.dart';
import '../models/json_helpers.dart';
import '../models/order_receipt.dart';
import '../models/order_receipt_mapper.dart';
import '../models/payment_result.dart';
import '../models/payment_result_mapper.dart';
import '../models/payment_summary.dart';
import '../models/pos_product.dart';
import '../models/shift.dart';
import '../models/update_order_item_request.dart';

class PosRepository {
  PosRepository({this.apiClient});

  final DioApiClient? apiClient;
  final Map<int, String> _categoryNamesById = <int, String>{};

  bool get usesBackend => apiClient != null;

  bool get _usesBackend => usesBackend;

  Future<List<Branch>> getBranches() async {
    if (!_usesBackend) {
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
    return _mapList(response).map(Branch.fromJson).toList(growable: false);
  }

  Future<Shift?> getCurrentShift({required int branchId}) async {
    if (!_usesBackend) {
      return const Shift(id: 1, branchId: 1, userId: 1, status: 'open');
    }

    final dynamic response = await apiClient!.get(
      'shifts/current',
      queryParameters: <String, dynamic>{'branchId': branchId},
    );
    if (response == null) {
      return null;
    }

    return Shift.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<String>> getCategories({required int branchId}) async {
    if (!_usesBackend) {
      return _fakeCategories();
    }

    final dynamic response = await apiClient!.get(
      'menu/categories',
      queryParameters: <String, dynamic>{'branchId': branchId},
    );
    final List<Map<String, dynamic>> categories = _mapList(response);
    _categoryNamesById
      ..clear()
      ..addEntries(
        categories.map(
          (Map<String, dynamic> category) => MapEntry<int, String>(
            readInt(category['id']) ?? 0,
            readString(category['name']),
          ),
        ),
      );

    return categories
        .map((Map<String, dynamic> category) => readString(category['name']))
        .where((String name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<PosProduct>> getProducts({
    required int branchId,
    int? categoryId,
    String availability = 'all',
  }) async {
    if (!_usesBackend) {
      return _fakeProducts();
    }

    final Map<String, dynamic> query = <String, dynamic>{
      'branchId': branchId,
      'availability': availability,
    };
    if (categoryId != null) {
      query['categoryId'] = categoryId;
    }
    final dynamic response = await apiClient!.get(
      'menu/products',
      queryParameters: query,
    );
    return _mapList(response).map(_productFromJson).toList(growable: false);
  }

  Future<List<Customer>> getCustomers({String? search}) async {
    if (!_usesBackend) {
      return _fakeCustomers();
    }

    final Map<String, dynamic> query = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final dynamic response = await apiClient!.get(
      'customers',
      queryParameters: query,
    );
    return _mapList(response).map(_customerFromJson).toList(growable: false);
  }

  Future<Map<String, dynamic>> getPosState({required int branchId}) async {
    if (!_usesBackend) {
      return const <String, dynamic>{};
    }

    final dynamic response = await apiClient!.get(
      'pos/state',
      queryParameters: <String, dynamic>{'branchId': branchId},
    );
    return Map<String, dynamic>.from(response as Map? ?? <String, dynamic>{});
  }

  Future<BackendProductDetail> getProductDetail({
    required int productId,
    required int branchId,
  }) async {
    final dynamic response = await apiClient!.get(
      'menu/products/$productId',
      queryParameters: <String, dynamic>{'branchId': branchId},
    );
    return BackendProductDetail.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<BackendOrder> getOrder(int orderId) async {
    final dynamic response = await apiClient!.get('orders/$orderId');
    return BackendOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BackendOrder> createOrder(CreateOrderRequest request) async {
    final dynamic response = await apiClient!.post(
      'orders',
      data: request.toJson(),
    );
    return BackendOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BackendOrder> updateOrderContext({
    required int orderId,
    String? orderType,
    int? tableId,
    int? customerId,
    bool clearTable = false,
    bool clearCustomer = false,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (orderType != null) {
      data['orderType'] = orderType;
    }
    if (tableId != null || clearTable) {
      data['tableId'] = tableId;
    }
    if (customerId != null || clearCustomer) {
      data['customerId'] = customerId;
    }

    final dynamic response = await apiClient!.patch(
      'orders/$orderId',
      data: data,
    );
    return BackendOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BackendOrder> addOrderItem({
    required int orderId,
    required AddOrderItemRequest request,
  }) async {
    final dynamic response = await apiClient!.post(
      'orders/$orderId/items',
      data: request.toJson(),
    );
    return BackendOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BackendOrder> updateOrderItem({
    required int orderId,
    required int itemId,
    required UpdateOrderItemRequest request,
  }) async {
    final dynamic response = await apiClient!.patch(
      'orders/$orderId/items/$itemId',
      data: request.toJson(),
    );
    return BackendOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BackendOrder> removeOrderItem({
    required int orderId,
    required int itemId,
  }) async {
    final dynamic response = await apiClient!.delete(
      'orders/$orderId/items/$itemId',
    );
    return BackendOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BackendOrder> holdOrder(int orderId) async {
    final dynamic response = await apiClient!.post('orders/$orderId/hold');
    return BackendOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> cancelOrder(int orderId) async {
    await apiClient!.delete('orders/$orderId');
  }

  Future<List<AvailableDiscount>> getAvailableDiscounts(int orderId) async {
    final dynamic response = await apiClient!.get(
      'discounts/available',
      queryParameters: <String, dynamic>{'orderId': orderId},
    );
    return _mapList(response).map(_discountFromJson).toList(growable: false);
  }

  Future<BackendOrder> applyDiscount({
    required int orderId,
    String? code,
    int? discountId,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (code != null && code.trim().isNotEmpty) {
      data['code'] = code.trim();
    }
    if (discountId != null) {
      data['discountId'] = discountId;
    }

    await apiClient!.post('orders/$orderId/discounts/apply', data: data);
    return getOrder(orderId);
  }

  Future<BackendOrder> removeDiscount(int orderId) async {
    await apiClient!.delete('orders/$orderId/discounts');
    return getOrder(orderId);
  }

  Future<PaymentSummary> getPaymentSummary({
    required int orderId,
    double? amountReceived,
  }) async {
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
    final dynamic response = await apiClient!.get('orders/$orderId/receipt');
    return orderReceiptFromJson(Map<String, dynamic>.from(response as Map));
  }

  PosProduct _productFromJson(Map<String, dynamic> json) {
    final int id = readInt(json['id']) ?? 0;
    final String name = readString(json['name']);
    final int? categoryId = readInt(json['categoryId']);
    final String category = readString(
      json['categoryName'],
      fallback: readString(
        json['category'],
        fallback: categoryId == null
            ? 'MENU'
            : _categoryNamesById[categoryId] ?? 'MENU',
      ),
    );

    return PosProduct(
      id: id.toString(),
      backendId: id,
      categoryId: categoryId,
      name: name,
      category: category == 'MENU' ? 'MENU' : category,
      size: readString(json['unit'], fallback: '1 item'),
      price: readDouble(json['basePrice']),
      isAvailable: readBool(json['isAvailable'], fallback: true),
      icon: _iconForProduct(name: name, category: category),
    );
  }

  Customer _customerFromJson(Map<String, dynamic> json) {
    final int id = readInt(json['id']) ?? 0;
    return Customer(
      id: id.toString(),
      backendId: id,
      name: readString(json['name']),
      phone: readString(json['phone']),
      tier: readString(json['tier'], fallback: 'new').toUpperCase(),
      points: readInt(json['loyaltyPoints']) ?? 0,
    );
  }

  AvailableDiscount _discountFromJson(Map<String, dynamic> json) {
    final int id = readInt(json['id']) ?? 0;
    final String type = readString(json['type']);
    return AvailableDiscount(
      id: id.toString(),
      backendId: id,
      title: readString(json['name']),
      subtitle: readString(json['message']).isNotEmpty
          ? readString(json['message'])
          : readString(json['validUntil']).isNotEmpty
          ? 'Valid until ${readString(json['validUntil'])}'
          : 'Backend discount',
      badgeLabel: readString(json['badge']),
      type: switch (type) {
        'percentage' => AvailableDiscountType.percentage,
        'bogo' => AvailableDiscountType.bogo,
        _ => AvailableDiscountType.fixedAmount,
      },
      value: readDouble(json['value']),
      minimumSubtotal: readDouble(json['minimumOrderAmount']),
      couponCode: readString(json['code']).trim().isEmpty
          ? null
          : readString(json['code']).trim(),
      isEligible: readBool(json['eligible'], fallback: true),
      message: readString(json['message']).trim().isEmpty
          ? null
          : readString(json['message']).trim(),
    );
  }

  IconData _iconForProduct({required String name, required String category}) {
    final String value = '$category $name'.toLowerCase();

    if (value.contains('tea')) {
      return Icons.emoji_food_beverage_outlined;
    }
    if (value.contains('cold') ||
        value.contains('iced') ||
        value.contains('juice')) {
      return Icons.local_drink_outlined;
    }
    if (value.contains('dessert') ||
        value.contains('croissant') ||
        value.contains('cake') ||
        value.contains('pastry')) {
      return Icons.bakery_dining_outlined;
    }
    if (value.contains('sandwich')) {
      return Icons.lunch_dining_outlined;
    }

    return Icons.local_cafe_outlined;
  }

  List<Map<String, dynamic>> _mapList(dynamic response) {
    return readMapList(response);
  }

  List<String> _fakeCategories() {
    return const <String>[
      'COFFEE',
      'TEA',
      'COLD DRINKS',
      'DESSERTS',
      'SANDWICHES',
      'ADD-ONS',
    ];
  }

  List<PosProduct> _fakeProducts() {
    return const <PosProduct>[
      PosProduct(
        id: 'espresso',
        name: 'Espresso',
        category: 'COFFEE',
        size: '1.5 oz',
        price: 3.50,
        isAvailable: true,
        icon: Icons.local_cafe_outlined,
      ),
      PosProduct(
        id: 'cold-brew-reserve',
        name: 'Cold Brew Reserve',
        category: 'COFFEE',
        size: '16 oz',
        price: 5.50,
        isAvailable: false,
        icon: Icons.local_drink_outlined,
      ),
      PosProduct(
        id: 'cappuccino',
        name: 'Cappuccino',
        category: 'COFFEE',
        size: '8 oz',
        price: 4.50,
        isAvailable: true,
        icon: Icons.coffee_outlined,
      ),
      PosProduct(
        id: 'pour-over-v60',
        name: 'Pour Over V60',
        category: 'COFFEE',
        size: '10 oz',
        price: 6.00,
        isAvailable: true,
        icon: Icons.coffee_maker_outlined,
      ),
      PosProduct(
        id: 'americano',
        name: 'Americano',
        category: 'COFFEE',
        size: '12 oz',
        price: 3.75,
        isAvailable: true,
        icon: Icons.coffee_outlined,
      ),
      PosProduct(
        id: 'green-tea',
        name: 'Green Tea',
        category: 'TEA',
        size: '10 oz',
        price: 3.25,
        isAvailable: true,
        icon: Icons.emoji_food_beverage_outlined,
      ),
      PosProduct(
        id: 'iced-tea',
        name: 'Iced Tea',
        category: 'COLD DRINKS',
        size: '16 oz',
        price: 3.75,
        isAvailable: true,
        icon: Icons.local_drink_outlined,
      ),
      PosProduct(
        id: 'almond-croissant',
        name: 'Almond Croissant',
        category: 'DESSERTS',
        size: '1 pc',
        price: 4.50,
        isAvailable: true,
        icon: Icons.bakery_dining_outlined,
      ),
    ];
  }

  List<Customer> _fakeCustomers() {
    return const <Customer>[
      Customer(
        id: 'jane-doe',
        name: 'Jane Doe',
        phone: '+1 (555) 019-8234',
        tier: 'VIP',
        points: 1450,
      ),
      Customer(
        id: 'janet-smith',
        name: 'Janet Smith',
        phone: '+1 (555) 342-9901',
        tier: 'REGULAR',
        points: 320,
      ),
      Customer(
        id: 'jane-williams',
        name: 'Jane Williams',
        phone: '+1 (555) 781-2245',
        tier: 'NEW',
        points: 50,
      ),
    ];
  }
}
