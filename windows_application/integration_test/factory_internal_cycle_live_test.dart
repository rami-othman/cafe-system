import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('live production, factory sale, cafe purchase and independent settlements', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Factory cycle validation'))));
    final factory = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1/'));
    final owner = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1/'));
    Future<dynamic> get(Dio api, String path, [Map<String, dynamic>? query]) async => (await api.get<Map<String, dynamic>>(path, queryParameters: query)).data!['data'];
    Future<Map<String, dynamic>> post(Dio api, String path, Map<String, dynamic> data) async {
      try { return Map<String, dynamic>.from((await api.post<Map<String, dynamic>>(path, data: data)).data!['data'] as Map); }
      on DioException catch (e) { throw StateError('$path: ${e.response?.statusCode} ${e.response?.data}'); }
    }
    Future<void> login(Dio api, String email, String password) async { final session = await post(api, 'auth/login', {'email': email, 'password': password}); api.options.headers['Authorization'] = 'Bearer ${session['accessToken']}'; }
    await login(factory, 'factory.demo@cafe618.test', 'FactoryDemo123');
    await login(owner, 'owner@cafe618.local', 'owner-local-dev');
    final branches = (await get(owner, 'branches') as List).cast<Map>();
    final factoryBranch = branches.firstWhere((b) => b['branchType'] == 'factory');
    final cafe = branches.firstWhere((b) => b['branchType'] == 'cafe');
    if (cafe['defaultWarehouseId'] == null) {
      final warehouses = (await get(owner, 'warehouses', {'branchId': cafe['id']}) as List).cast<Map>();
      final eligible = warehouses.where((w) => w['branchId'] == cafe['id'] && w['isActive'] == true).toList();
      cafe['defaultWarehouseId'] = eligible.isNotEmpty ? eligible.first['id'] : (await post(owner, 'warehouses', {'branchId': cafe['id'], 'name': 'مخزن قبول المعمل', 'code': 'FACTORY-ACCEPTANCE-CAFE', 'type': 'bar', 'isActive': true}))['id'];
    }
    final factoryId = factoryBranch['id'] as int; final cafeId = cafe['id'] as int;
    factory.options.queryParameters['scopeBranchId'] = factoryId;
    final initialReconciliation = (await get(owner, 'finance/reports/internal-reconciliation') as List).cast<Map>();
    final initialDifference = initialReconciliation.firstWhere((r) => r['factoryBranchId'] == factoryId && r['cafeBranchId'] == cafeId)['difference'];
    final stamp = DateTime.now().microsecondsSinceEpoch.toString(); final date = DateTime.now().toIso8601String().substring(0, 10);
    final recipes = (await get(factory, 'manufacturing/recipes') as List).cast<Map>();
    final recipeRow = recipes.firstWhere((r) => r['name'] == 'كرواسون زبدة');
    final recipe = await get(factory, 'manufacturing/recipes/${recipeRow['id']}') as Map;
    final draft = await post(factory, 'manufacturing/production/drafts', {'recipeId': recipe['id'], 'qty': recipe['yield'], 'warehouseId': factoryBranch['defaultWarehouseId'], 'idempotencyKey': 'live-prod-$stamp'});
    await post(factory, 'manufacturing/production/drafts/${draft['id']}/complete', {'actualQty': recipe['yield'], 'idempotencyKey': 'live-complete-$stamp'});
    final customers = (await get(factory, 'finance/customers', {'perPage': 100}) as List).cast<Map>();
    final customer = customers.firstWhere((c) => c['isInternal'] == true && c['internalBranchId'] == cafeId);
    final sale = await post(factory, 'finance/sales-invoices', {'customerId': customer['id'], 'invoiceDate': date, 'lines': [{'inventoryItemId': recipe['productItemId'], 'quantity': '1', 'unitPrice': '100.00'}]});
    await post(factory, 'finance/sales-invoices/${sale['id']}/post', {'idempotencyKey': 'live-sale-$stamp'});
    final factoryItem = await get(factory, 'inventory/items/${recipe['productItemId']}') as Map;
    final suppliers = (await get(owner, 'finance/suppliers', {'perPage': 100}) as List).cast<Map>();
    final supplier = suppliers.firstWhere((s) => s['isInternal'] == true && s['internalBranchId'] == factoryId);
    final item = await post(owner, 'inventory/items', {'nameAr': 'كيك اختبار حي $stamp', 'nameEn': 'Live cafe cake $stamp', 'sku': 'LIVE-CAFE-$stamp', 'itemType': 'finished_good', 'unit': 'piece', 'isActive': true, 'minimumStock': '0', 'reorderLevel': '0', 'warehouseIds': [cafe['defaultWarehouseId']]});
    final purchase = await post(owner, 'finance/supplier-invoices', {'branchId': cafeId, 'supplierId': supplier['id'], 'invoiceNumber': 'LIVE-PURCHASE-$stamp', 'invoiceDate': date, 'dueDate': date, 'invoiceType': 'inventory', 'receiptMode': 'immediate', 'lines': [{'lineType': 'inventory', 'description': 'Live cafe purchase', 'inventoryItemId': item['id'], 'warehouseId': cafe['defaultWarehouseId'], 'quantity': '1', 'lineGrossAmount': sale['total']}]});
    await post(owner, 'finance/purchases/${purchase['id']}/post', {'idempotencyKey': 'live-purchase-$stamp', 'paidAmount': '0.00'});
    final cafeItem = await get(owner, 'inventory/items/${item['id']}') as Map;
    expect(double.parse(cafeItem['totalQuantity'].toString()), 1);
    final unchanged = await get(factory, 'inventory/items/${recipe['productItemId']}') as Map;
    expect(unchanged['totalQuantity'], factoryItem['totalQuantity']);
    final methods = (await get(owner, 'finance/payment-methods') as List).cast<Map>(); final cash = methods.firstWhere((m) => m['type'] == 'cash');
    final locations = (await get(owner, 'finance/cash-accounts') as List).cast<Map>(); final drawer = locations.firstWhere((l) => l['branchId'] == cafeId && l['isActive'] == true);
    await post(owner, 'finance/supplier-payments', {'branchId': cafeId, 'supplierId': supplier['id'], 'paymentDate': date, 'amount': sale['total'], 'paymentMethodId': cash['id'], 'financialLocationId': drawer['id'], 'idempotencyKey': 'live-ap-$stamp', 'allocations': [{'invoiceId': purchase['id'], 'amount': sale['total']}]});
    await post(factory, 'finance/customer-payments', {'customerId': customer['id'], 'paymentDate': date, 'amount': sale['total'], 'paymentMethodId': cash['id'], 'idempotencyKey': 'live-ar-$stamp', 'allocations': [{'invoiceId': sale['id'], 'amount': sale['total']}]});
    final postedSale = await get(factory, 'finance/sales-invoices/${sale['id']}') as Map;
    expect(postedSale['remainingAmount'], '0.00');
    final postedPurchase = await get(owner, 'finance/supplier-invoices/${purchase['id']}') as Map;
    expect(postedPurchase['remainingAmount'], '0.00');
    final reconciliation = (await get(owner, 'finance/reports/internal-reconciliation') as List).cast<Map>();
    expect(reconciliation.firstWhere((r) => r['factoryBranchId'] == factoryId && r['cafeBranchId'] == cafeId)['difference'], initialDifference);
    factory.close(); owner.close();
  });
}
