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

  testWidgets('all branches show branch warehouses in the receipt selector', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _FakeBackend(withWarehouses: true));
    final selector = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<int> &&
          widget.decoration.labelText == 'مخزن الاستلام',
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('Main Warehouse'), findsWidgets);
    expect(find.text('Downtown Warehouse'), findsWidgets);
  });

  testWidgets(
    'preselects the supplier passed in from the Supplier Profile screen',
    (WidgetTester tester) async {
      await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

      expect(find.text('Demo Bean Roasters'), findsOneWidget);
    },
  );

  testWidgets(
    'validates an inventory line requires a selected item before saving',
    (WidgetTester tester) async {
      await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

      await tester.tap(find.text('حفظ كمسودة'));
      await tester.pumpAndSettle();

      expect(find.text('اختر صنف المخزون لكل بند.'), findsOneWidget);
    },
  );

  testWidgets(
    'switching purchase type to service hides the inventory item picker',
    (WidgetTester tester) async {
      await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

      expect(find.text('الصنف'), findsOneWidget);

      await tester.tap(find.text('مصروف / خدمة'));
      await tester.pumpAndSettle();

      expect(find.text('الصنف'), findsNothing);
      expect(find.text('فئة المصروف'), findsOneWidget);
    },
  );

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

  testWidgets(
    'saving a valid service line posts the line total, not a unit cost',
    (WidgetTester tester) async {
      final _FakeBackend backend = _FakeBackend();
      await _pump(tester, backend, preselectedSupplierId: 1);

      await tester.tap(find.text('مصروف / خدمة'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'البيان'),
        'صيانة آلة الإسبريسو',
      );
      // The default input is the line's total ("إجمالي البند"), matching
      // what the supplier invoice actually shows — never a manually
      // computed unit cost.
      await tester.enterText(
        find.widgetWithText(TextField, 'إجمالي البند'),
        '60',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ كمسودة'));
      await tester.pumpAndSettle();

      // Blocked first by the required expense category, proving client-side
      // validation runs before any network call.
      expect(find.text('اختر فئة المصروف.'), findsOneWidget);
      expect(backend.lastCreatePayload, isNull);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('purchase-expense-category-dropdown'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Utilities').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ كمسودة'));
      await tester.pumpAndSettle();

      expect(backend.lastCreatePayload, isNotNull);
      expect(backend.lastCreatePayload!['invoiceType'], 'expense');
      expect(backend.lastCreatePayload!['expenseCategoryId'], 4);
      expect(backend.lastCreatePayload!['lines'], hasLength(1));
      final Map<String, dynamic> line =
          backend.lastCreatePayload!['lines'][0] as Map<String, dynamic>;
      expect(line['lineType'], 'expense');
      expect(line['description'], 'صيانة آلة الإسبريسو');
      expect(line['lineGrossAmount'], '60');
      expect(line.containsKey('unitCost'), isFalse);
      expect(backend.lastCreatePayload!.containsKey('invoiceNumber'), isFalse);
    },
  );

  testWidgets(
    'toggling to manual unit-cost mode sends unitCost instead of lineGrossAmount',
    (WidgetTester tester) async {
      final _FakeBackend backend = _FakeBackend();
      await _pump(tester, backend, preselectedSupplierId: 1);

      await tester.tap(find.text('مصروف / خدمة'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'البيان'),
        'Fixed unit price item',
      );
      // Switch the cost field from total-entry to manual unit-cost entry.
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'تكلفة الوحدة'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'تكلفة الوحدة'),
        '15',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('purchase-expense-category-dropdown'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Utilities').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ كمسودة'));
      await tester.pumpAndSettle();

      final Map<String, dynamic> line =
          backend.lastCreatePayload!['lines'][0] as Map<String, dynamic>;
      expect(line['unitCost'], '15');
      expect(line.containsKey('lineGrossAmount'), isFalse);
    },
  );

  testWidgets(
    'entering quantity 1850 and total 350 shows the line total unchanged, not a recomputed value',
    (WidgetTester tester) async {
      await _pump(tester, _FakeBackend(), preselectedSupplierId: 1);

      await tester.enterText(find.widgetWithText(TextField, 'الكمية'), '1850');
      await tester.enterText(
        find.widgetWithText(TextField, 'إجمالي البند'),
        '350',
      );
      await tester.pump();

      final Finder grossField = find.byWidgetPredicate(
        (Widget widget) =>
            widget is InputDecorator &&
            widget.decoration.labelText == 'إجمالي الصنف',
      );
      // The gross preview is exactly the typed total — never a lossy
      // quantity*derived-unit-cost recomputation of the repeating decimal.
      expect(
        find.descendant(of: grossField, matching: find.text('350.00')),
        findsOneWidget,
      );
    },
  );

  for (final Size size in <Size>[const Size(1280, 800), const Size(500, 800)]) {
    testWidgets('purchase lines remain overflow-free in RTL at ${size.width}', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _FakeBackend(),
        preselectedSupplierId: 1,
        surfaceSize: size,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('إجمالي الصنف'), findsOneWidget);
      expect(find.text('إجمالي البند'), findsOneWidget);
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeBackend backend, {
  int? preselectedSupplierId,
  Size surfaceSize = const Size(1600, 1200),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
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
  _FakeBackend({this.withWarehouses = false});
  final bool withWarehouses;
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
        meta: <String, dynamic>{
          'currentPage': 1,
          'perPage': 200,
          'total': 1,
          'lastPage': 1,
        },
      );
    }
    if (path == 'branches') {
      return _ok(options, <Map<String, dynamic>>[]);
    }
    if (path == 'warehouses') {
      return _ok(
        options,
        withWarehouses
            ? <Map<String, dynamic>>[
                {
                  'id': 1,
                  'branchId': 1,
                  'name': 'Main Warehouse',
                  'displayName': 'Main Warehouse',
                  'code': 'MAIN',
                  'type': 'warehouse',
                  'isActive': true,
                },
                {
                  'id': 2,
                  'branchId': 2,
                  'name': 'Downtown Warehouse',
                  'displayName': 'Downtown Warehouse',
                  'code': 'DOWN',
                  'type': 'warehouse',
                  'isActive': true,
                },
              ]
            : <Map<String, dynamic>>[],
      );
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
        'internalReference': 'PI-2026-000055',
        'invoiceNumber': 'PI-2026-000055',
        'supplierInvoiceNumber': lastCreatePayload!['supplierInvoiceNumber'],
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
