import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/purchasing/controllers/purchasing_cubit.dart';
import 'package:windows_application/features/purchasing/repositories/purchasing_repository.dart';
import 'package:windows_application/features/purchasing/views/goods_receipt_form_screen.dart';

void main() {
  setUp(() {
    if (serviceLocator.isRegistered<InventoryRepository>()) {
      serviceLocator.unregister<InventoryRepository>();
    }
  });

  testWidgets('renders the invoice line with its remaining quantity and a warehouse picker', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend());

    expect(find.text('استلام مخزون'), findsWidgets);
    expect(find.text('Arabica beans'), findsOneWidget);
    expect(find.textContaining('المتبقي: 10.000'), findsOneWidget);
    expect(find.text('المستودع'), findsOneWidget);
  });

  testWidgets('rejects a quantity greater than the remaining quantity before posting anything', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.enterText(
      find.widgetWithText(TextField, 'الكمية المستلمة الآن (kg)'),
      '999',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ترحيل الاستلام'));
    await tester.pumpAndSettle();

    expect(find.textContaining('لا يمكن أن تتجاوز الكمية المتبقية'), findsOneWidget);
    expect(backend.lastReceiptPayload, isNull);
  });

  testWidgets('a valid receive creates then posts the Goods Receipt in one action', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central Warehouse').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ترحيل الاستلام'));
    await tester.pumpAndSettle();

    expect(backend.lastReceiptPayload, isNotNull);
    expect(backend.lastReceiptPayload!['lines'], hasLength(1));
    final Map<String, dynamic> line =
        backend.lastReceiptPayload!['lines'][0] as Map<String, dynamic>;
    expect(line['supplierInvoiceLineId'], 1);
    expect(line['quantity'], '10.000');
    expect(line['warehouseId'], 3);
    expect(backend.postedReceiptId, 7);
  });
}

Future<void> _pump(WidgetTester tester, _FakeBackend backend) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        try {
          handler.resolve(backend.respond(options));
        } on DioException catch (error) {
          handler.reject(error);
        }
      },
    ),
  );
  final DioApiClient client = DioApiClient(dio: dio);
  serviceLocator.registerLazySingleton<InventoryRepository>(
    () => InventoryRepository(client),
  );
  final PurchasingCubit purchasingCubit = PurchasingCubit(
    repository: PurchasingRepository(client),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BlocProvider<PurchasingCubit>.value(
            value: purchasingCubit,
            child: const GoodsReceiptFormScreen(purchaseId: 1),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBackend {
  Map<String, dynamic>? lastReceiptPayload;
  int? postedReceiptId;

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;

    if (path == 'finance/purchases/1' && options.method == 'GET') {
      return _ok(options, <String, dynamic>{
        'id': 1,
        'internalReference': 'AP-000001',
        'invoiceNumber': 'DEMO-BEANS-001',
        'supplierId': 1,
        'supplierName': 'Demo Bean Roasters',
        'branchName': null,
        'invoiceDate': '2026-08-15',
        'dueDate': '2026-09-14',
        'purchaseType': 'inventory',
        'subtotal': '175.00',
        'taxAmount': '0.00',
        'totalAmount': '175.00',
        'paidAmount': '0.00',
        'remainingAmount': '175.00',
        'documentStatus': 'posted',
        'paymentStatus': 'unpaid',
        'receiptStatus': 'not_received',
        'status': 'posted',
        'isOverdue': false,
        'allowedActions': <String>['reverse', 'receive'],
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'lineNumber': 1,
            'lineType': 'inventory',
            'description': 'Arabica beans',
            'inventoryItemId': 9,
            'inventoryItemName': 'Arabica beans',
            'purchaseUnit': 'kg',
            'baseUnit': 'kg',
            'quantity': '10.000',
            'unitPrice': '17.5000',
            'discountAmount': '0.00',
            'taxAmount': '0.00',
            'lineTotal': '175.00',
            'warehouseId': null,
            'receivedQuantity': '0.000',
            'remainingQuantity': '10.000',
          },
        ],
        'payments': <Map<String, dynamic>>[],
        'receipts': <Map<String, dynamic>>[],
      });
    }
    if (path == 'warehouses' && options.method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 3,
          'branchId': null,
          'branchName': null,
          'name': 'Central Warehouse',
          'displayName': 'Central Warehouse',
          'code': 'CENTRAL-01',
          'type': 'central',
          'typeLabel': 'Central',
          'isActive': true,
          'isLegacy': false,
        },
      ]);
    }
    if (path == 'inventory/balances' && options.method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[]);
    }
    if (path == 'finance/purchases/1/receipts' && options.method == 'POST') {
      lastReceiptPayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, <String, dynamic>{
        'id': 7,
        'receiptNumber': 'GRN-2026-000001',
        'receiptDate': lastReceiptPayload!['receiptDate'],
        'status': 'draft',
        'supplierInvoiceId': 1,
        'invoiceNumber': 'DEMO-BEANS-001',
        'supplierId': 1,
        'supplierName': 'Demo Bean Roasters',
        'lineCount': 1,
        'allowedActions': <String>['edit', 'post'],
      }, status: 201);
    }
    if (path == 'finance/purchase-receipts/7/post' && options.method == 'POST') {
      postedReceiptId = 7;
      return _ok(options, <String, dynamic>{
        'id': 7,
        'receiptNumber': 'GRN-2026-000001',
        'receiptDate': '2026-09-13',
        'status': 'posted',
        'supplierInvoiceId': 1,
        'invoiceNumber': 'DEMO-BEANS-001',
        'supplierId': 1,
        'supplierName': 'Demo Bean Roasters',
        'lineCount': 1,
        'allowedActions': <String>[],
      });
    }

    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{'message': 'Unhandled test route: $path'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  Response<dynamic> _ok(
    RequestOptions options,
    dynamic data, {
    Map<String, dynamic>? meta,
    int status = 200,
  }) => Response<dynamic>(
    requestOptions: options,
    statusCode: status,
    data: <String, dynamic>{
      'data': data,
      ...?meta == null ? null : <String, dynamic>{'meta': meta},
    },
  );
}
