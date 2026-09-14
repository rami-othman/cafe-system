import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/purchasing/controllers/purchasing_cubit.dart';
import 'package:windows_application/features/purchasing/repositories/purchasing_repository.dart';
import 'package:windows_application/features/purchasing/views/purchase_invoice_form_screen.dart';

void main() {
  setUp(() {
    if (serviceLocator.isRegistered<InventoryRepository>()) {
      serviceLocator.unregister<InventoryRepository>();
    }
  });

  testWidgets('preselects the supplier passed in from the Supplier Profile screen', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

    expect(find.text('Demo Bean Roasters'), findsOneWidget);
  });

  testWidgets('validates an inventory line requires a selected item before saving', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('اختر صنف المخزون لكل بند.'), findsOneWidget);
  });

  testWidgets('switching purchase type to service hides the inventory item picker', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

    expect(find.text('الصنف'), findsOneWidget);

    await tester.tap(find.text('مصروف / خدمة'));
    await tester.pumpAndSettle();

    expect(find.text('الصنف'), findsNothing);
    expect(find.text('فئة المصروف'), findsOneWidget);
  });

  testWidgets('adding and removing a second line updates the row count', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(find.text('إضافة بند'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('saving a valid service line posts to the supplier-invoices endpoint with lines', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend, preselectedSupplierId: 1);

    await tester.tap(find.text('مصروف / خدمة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'البيان'), 'صيانة آلة الإسبريسو');
    await tester.enterText(find.widgetWithText(TextField, 'سعر الوحدة'), '60');
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    // Blocked first by the required expense category, proving client-side
    // validation runs before any network call.
    expect(find.text('اختر فئة المصروف.'), findsOneWidget);
    expect(backend.lastCreatePayload, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('purchase-expense-category-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utilities').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(backend.lastCreatePayload, isNotNull);
    expect(backend.lastCreatePayload!['invoiceType'], 'expense');
    expect(backend.lastCreatePayload!['expenseCategoryId'], 4);
    expect(backend.lastCreatePayload!['lines'], hasLength(1));
    final Map<String, dynamic> line =
        backend.lastCreatePayload!['lines'][0] as Map<String, dynamic>;
    expect(line['lineType'], 'expense');
    expect(line['description'], 'صيانة آلة الإسبريسو');
    expect(line['unitPrice'], '60');
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeBackend backend, {
  int? preselectedSupplierId,
}) async {
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
  final FinanceSetupCubit financeCubit = FinanceSetupCubit(
    repository: FinanceSetupRepository(client),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<PurchasingCubit>.value(value: purchasingCubit),
              BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
            ],
            child: PurchaseInvoiceFormScreen(
              preselectedSupplierId: preselectedSupplierId,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBackend {
  Map<String, dynamic>? lastCreatePayload;

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;

    if (path == 'finance/suppliers' && options.method == 'GET') {
      return _ok(
        options,
        <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'supplierNumber': 'SUP-00001',
            'name': 'Demo Bean Roasters',
            'isActive': true,
            'paymentTermsDays': 30,
            'outstandingBalance': '0.00',
            'overdueBalance': '0.00',
            'openInvoiceCount': 0,
            'allowedActions': <String>[],
          },
        ],
        meta: <String, dynamic>{'currentPage': 1, 'perPage': 200, 'total': 1, 'lastPage': 1},
      );
    }
    if (path == 'branches') {
      return _ok(options, <Map<String, dynamic>>[]);
    }
    if (path == 'inventory/items') {
      return _ok(options, <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 9,
            'name': 'Arabica beans',
            'sku': 'DEMO-BEANS',
            'unit': 'kg',
            'itemType': 'raw_material',
            'category': 'ingredients',
            'quantity': '0.000',
            'availableQuantity': '0.000',
            'cost': '0.0000',
            'reorderLevel': '0.000',
            'minimumStock': '0.000',
            'active': true,
            'purchaseUnit': 'kg',
          },
        ],
        'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 1},
      });
    }
    if (path == 'finance/expense-categories') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 4,
          'code': 'UTIL',
          'name': 'Utilities',
          'financialAccountId': 12,
          'financialAccountCode': '6120',
          'isActive': true,
        },
      ]);
    }
    if (path == 'finance/accounts') {
      return _ok(options, <Map<String, dynamic>>[]);
    }
    if (path == 'finance/supplier-invoices' && options.method == 'POST') {
      lastCreatePayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, <String, dynamic>{
        'id': 55,
        'internalReference': 'AP-000055',
        'invoiceNumber': lastCreatePayload!['invoiceNumber'],
        'supplierId': 1,
        'supplierName': 'Demo Bean Roasters',
        'invoiceDate': lastCreatePayload!['invoiceDate'],
        'dueDate': lastCreatePayload!['dueDate'],
        'purchaseType': 'inventory',
        'subtotal': '80.00',
        'taxAmount': '0.00',
        'totalAmount': '80.00',
        'paidAmount': '0.00',
        'remainingAmount': '80.00',
        'documentStatus': 'draft',
        'paymentStatus': 'not_applicable',
        'status': 'draft',
        'isOverdue': false,
        'allowedActions': <String>['edit', 'post'],
      }, status: 201);
    }
    if (path == 'finance/purchases/55') {
      return _ok(options, <String, dynamic>{
        'id': 55,
        'internalReference': 'AP-000055',
        'invoiceNumber': 'x',
        'supplierId': 1,
        'supplierName': 'Demo Bean Roasters',
        'invoiceDate': '2026-09-01',
        'dueDate': '2026-10-01',
        'purchaseType': 'inventory',
        'subtotal': '80.00',
        'taxAmount': '0.00',
        'totalAmount': '80.00',
        'paidAmount': '0.00',
        'remainingAmount': '80.00',
        'documentStatus': 'draft',
        'paymentStatus': 'not_applicable',
        'status': 'draft',
        'isOverdue': false,
        'allowedActions': <String>['edit', 'post'],
        'lines': <Map<String, dynamic>>[],
        'payments': <Map<String, dynamic>>[],
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
