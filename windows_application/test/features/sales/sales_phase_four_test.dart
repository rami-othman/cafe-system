import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/sales/controllers/sales_cubit.dart';
import 'package:windows_application/features/sales/models/sales_models.dart';
import 'package:windows_application/features/sales/repositories/sales_repository.dart';
import 'package:windows_application/features/sales/views/sales_credit_note_screens.dart';
import 'package:windows_application/features/sales/views/sales_screens.dart';

/// Phase 4 — Sales Credit Notes / Returns / Customer Refunds. Every request
/// is routed by path through one fake Dio, mirroring the real Finance API;
/// these tests verify Flutter parses the derived AR/credit fields correctly
/// and drives the create/preview/post/refund flow without touching a server.
void main() {
  group('models', () {
    test('SalesInvoice parses creditedAmount/creditStatus/creditNotes and exposes canCreateCreditNote', () {
      final SalesInvoice invoice = SalesInvoice.fromJson(<String, dynamic>{
        'id': 20, 'invoiceNumber': 'SI-2026-000020', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown',
        'invoiceDate': '2026-09-12', 'status': 'posted', 'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00',
        'allowedActions': <String, dynamic>{'canRegisterPayment': true, 'canCreateCreditNote': true},
        'paidAmount': '300.00', 'remainingAmount': '0.00', 'paymentStatus': 'paid', 'creditedAmount': '100.00', 'creditStatus': 'partially_credited',
        'creditNotes': <Map<String, dynamic>>[
          <String, dynamic>{'id': 5, 'creditNoteNumber': 'CN-2026-000005', 'creditDate': '2026-09-13', 'total': '100.00', 'arReductionAmount': '0.00', 'customerCreditAmount': '100.00', 'reason': 'تالف'},
        ],
      });
      expect(invoice.canCreateCreditNote, isTrue);
      expect(invoice.creditedAmount, '100.00');
      expect(invoice.creditStatus, 'partially_credited');
      expect(invoice.creditNotes, hasLength(1));
      expect(invoice.creditNotes.single.customerCreditAmount, '100.00');
    });

    test('ReturnableInvoiceLine parses original/already-returned/returnable quantities', () {
      final ReturnableInvoiceLine line = ReturnableInvoiceLine.fromJson(<String, dynamic>{
        'originalSalesInvoiceLineId': 7, 'productId': 4, 'productName': 'Cappuccino', 'productSku': 'CAP-1',
        'originalQuantity': '10.000', 'alreadyReturned': '2.000', 'returnable': '8.000', 'unitPrice': '10.00', 'taxRate': '0', 'isStockTracked': true,
      });
      expect(line.returnable, '8.000');
      expect(line.isStockTracked, isTrue);
    });

    test('SalesCreditNote exposes canPost/canCancel from allowedActions', () {
      final SalesCreditNote note = SalesCreditNote.fromJson(<String, dynamic>{
        'id': 5, 'creditNoteNumber': 'CN-2026-000005', 'branchId': 3, 'branchName': 'Downtown', 'customerId': 2, 'customerName': 'Damascus Tech',
        'originalSalesInvoiceId': 20, 'originalInvoiceNumber': 'SI-2026-000020', 'creditDate': '2026-09-13', 'status': 'draft',
        'subtotal': '100.00', 'taxTotal': '0.00', 'total': '100.00', 'allowedActions': <String, dynamic>{'canPost': true, 'canCancel': true},
      });
      expect(note.canPost, isTrue);
      expect(note.canCancel, isTrue);
    });

    test('CustomerCreditInfo parses available credit', () {
      final CustomerCreditInfo info = CustomerCreditInfo.fromJson(<String, dynamic>{
        'customer': <String, dynamic>{'id': 2, 'name': 'Damascus Tech'}, 'availableCredit': '100.00',
      });
      expect(info.availableCredit, '100.00');
    });
  });

  group('Sales Credit Notes list', () {
    testWidgets('shows credit note rows with original invoice and status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
        'data': <Map<String, dynamic>>[<String, dynamic>{
          'id': 5, 'creditNoteNumber': 'CN-2026-000005', 'branchId': 3, 'branchName': 'Downtown', 'customerId': 2, 'customerName': 'Damascus Tech',
          'originalSalesInvoiceId': 20, 'originalInvoiceNumber': 'SI-2026-000020', 'creditDate': '2026-09-13', 'status': 'posted',
          'subtotal': '100.00', 'taxTotal': '0.00', 'total': '100.00', 'allowedActions': <String, dynamic>{},
        }],
        'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 1},
      }))));
      final SalesCubit cubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: BlocProvider<SalesCubit>.value(value: cubit, child: const SalesCreditNotesScreen())))));
      await tester.pumpAndSettle();
      expect(find.text('CN-2026-000005'), findsOneWidget);
      expect(find.text('SI-2026-000020'), findsOneWidget);
      expect(find.text('مُرحّل'), findsOneWidget);
    });

    testWidgets('shows an empty state when there are no credit notes yet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
        'data': <Map<String, dynamic>>[], 'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 0},
      }))));
      final SalesCubit cubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: BlocProvider<SalesCubit>.value(value: cubit, child: const SalesCreditNotesScreen())))));
      await tester.pumpAndSettle();
      expect(find.textContaining('لا توجد إشعارات دائنة بعد'), findsOneWidget);
    });
  });

  group('Sales Invoice detail — Phase 4 fields', () {
    Widget buildDetail(Dio dio) {
      final SalesCubit salesCubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      final FinanceSetupCubit financeCubit = FinanceSetupCubit(repository: FinanceSetupRepository(DioApiClient(dio: dio)));
      return MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: MultiBlocProvider(providers: <BlocProvider<dynamic>>[
        BlocProvider<SalesCubit>.value(value: salesCubit),
        BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
      ], child: const SalesInvoiceDetailScreen(id: 20)))));
    }

    testWidgets('shows credited amount, credit status chip, credit note history and the create-return action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
        'data': <String, dynamic>{
          'id': 20, 'invoiceNumber': 'SI-2026-000020', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'invoiceDate': '2026-09-12', 'status': 'posted',
          'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00', 'paidAmount': '300.00', 'remainingAmount': '0.00', 'paymentStatus': 'paid',
          'creditedAmount': '100.00', 'creditStatus': 'partially_credited',
          'allowedActions': <String, dynamic>{'canView': true, 'canEdit': false, 'canCancel': false, 'canPost': false, 'canRegisterPayment': false, 'canCreateCreditNote': true},
          'lines': <Map<String, dynamic>>[], 'collections': <Map<String, dynamic>>[],
          'creditNotes': <Map<String, dynamic>>[<String, dynamic>{'id': 5, 'creditNoteNumber': 'CN-2026-000005', 'creditDate': '2026-09-13', 'total': '100.00', 'arReductionAmount': '0.00', 'customerCreditAmount': '100.00', 'reason': 'تالف'}],
        },
      }))));
      await tester.pumpWidget(buildDetail(dio));
      await tester.pumpAndSettle();
      expect(find.text('100.00'), findsWidgets);
      expect(find.text('مخصومة جزئياً'), findsOneWidget);
      expect(find.text('سجل الإشعارات الدائنة / المرتجعات'), findsOneWidget);
      expect(find.text('CN-2026-000005'), findsOneWidget);
      expect(find.text('+ إنشاء مرتجع / إشعار دائن'), findsOneWidget);
    });

    testWidgets('hides the create-return action when the permission/action flag is false', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
        'data': <String, dynamic>{
          'id': 20, 'invoiceNumber': 'SI-2026-000020', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'invoiceDate': '2026-09-12', 'status': 'posted',
          'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00', 'paidAmount': '300.00', 'remainingAmount': '0.00', 'paymentStatus': 'paid',
          'creditStatus': 'not_credited',
          'allowedActions': <String, dynamic>{'canRegisterPayment': false, 'canCreateCreditNote': false},
          'lines': <Map<String, dynamic>>[], 'collections': <Map<String, dynamic>>[],
        },
      }))));
      await tester.pumpWidget(buildDetail(dio));
      await tester.pumpAndSettle();
      expect(find.text('+ إنشاء مرتجع / إشعار دائن'), findsNothing);
      expect(find.text('بدون إشعارات'), findsOneWidget);
    });
  });

  group('CreateCreditNoteScreen', () {
    Widget buildScreen(Dio dio) {
      final SalesCubit salesCubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      return MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: BlocProvider<SalesCubit>.value(value: salesCubit, child: const CreateCreditNoteScreen(invoiceId: 20, customerName: 'Damascus Tech')))));
    }

    testWidgets('only offers lines with returnable > 0, defaults restock toggle to isStockTracked, and posts a draft', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      final List<RequestOptions> posted = <RequestOptions>[];
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == 'finance/sales-invoices/20/returnable-lines') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <Map<String, dynamic>>[
            <String, dynamic>{'originalSalesInvoiceLineId': 1, 'productId': 4, 'productName': 'Cappuccino', 'originalQuantity': '10.000', 'alreadyReturned': '0.000', 'returnable': '10.000', 'unitPrice': '10.00', 'taxRate': '0', 'isStockTracked': true},
            <String, dynamic>{'originalSalesInvoiceLineId': 2, 'productId': 9, 'productName': 'Meeting Room', 'originalQuantity': '1.000', 'alreadyReturned': '0.000', 'returnable': '0.000', 'unitPrice': '50.00', 'taxRate': '0', 'isStockTracked': false},
          ]}));
        }
        if (options.path == 'finance/sales-credit-notes' && options.method == 'POST') {
          posted.add(options);
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 201, data: <String, dynamic>{'data': <String, dynamic>{
            'id': 6, 'creditNoteNumber': 'CN-2026-000006', 'branchId': 3, 'branchName': 'Downtown', 'customerId': 2, 'customerName': 'Damascus Tech',
            'originalSalesInvoiceId': 20, 'originalInvoiceNumber': 'SI-2026-000020', 'creditDate': '2026-09-13', 'status': 'draft',
            'subtotal': '20.00', 'taxTotal': '0.00', 'total': '20.00', 'allowedActions': <String, dynamic>{},
          }}));
        }
        return handler.reject(DioException(requestOptions: options, message: 'unexpected path: ${options.path}'));
      }));
      await tester.pumpWidget(buildScreen(dio));
      await tester.pumpAndSettle();

      // The service line (returnable 0) is filtered out entirely.
      expect(find.text('Cappuccino'), findsOneWidget);
      expect(find.text('Meeting Room'), findsNothing);
      // Tracked product defaults restock ON.
      final Switch restockSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(restockSwitch.value, isTrue);

      await tester.enterText(find.byType(TextField).last, '2');
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنشاء كمسودة'));
      await tester.pumpAndSettle();

      expect(posted, hasLength(1));
      final Map<String, dynamic> body = Map<String, dynamic>.from(posted.single.data as Map);
      expect(body['originalSalesInvoiceId'], 20);
      final List<dynamic> lines = body['lines'] as List<dynamic>;
      expect(lines, hasLength(1));
      expect(lines.single['originalSalesInvoiceLineId'], 1);
      expect(lines.single['quantity'], '2');
      expect(lines.single['restock'], isTrue);
    });

    testWidgets('blocks submission when no line has a quantity entered', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == 'finance/sales-invoices/20/returnable-lines') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <Map<String, dynamic>>[
            <String, dynamic>{'originalSalesInvoiceLineId': 1, 'productId': 4, 'productName': 'Cappuccino', 'originalQuantity': '10.000', 'alreadyReturned': '0.000', 'returnable': '10.000', 'unitPrice': '10.00', 'taxRate': '0', 'isStockTracked': true},
          ]}));
        }
        return handler.reject(DioException(requestOptions: options, message: 'unexpected POST while no quantity was entered'));
      }));
      await tester.pumpWidget(buildScreen(dio));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إنشاء كمسودة'));
      await tester.pumpAndSettle();
      expect(find.text('حدد كمية لبند واحد على الأقل.'), findsOneWidget);
    });
  });

  group('SalesCreditNoteDetailScreen', () {
    testWidgets('a draft shows Post/Cancel; posting reveals AR reduction, customer credit and the refund action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      bool isPosted = false;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == 'finance/sales-credit-notes/6') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <String, dynamic>{
            'id': 6, 'creditNoteNumber': 'CN-2026-000006', 'branchId': 3, 'branchName': 'Downtown', 'customerId': 2, 'customerName': 'Damascus Tech',
            'originalSalesInvoiceId': 20, 'originalInvoiceNumber': 'SI-2026-000020', 'creditDate': '2026-09-13', 'status': isPosted ? 'posted' : 'draft',
            'subtotal': '100.00', 'taxTotal': '0.00', 'total': '100.00',
            if (isPosted) 'arReductionAmount': '0.00', if (isPosted) 'customerCreditAmount': '100.00',
            'allowedActions': <String, dynamic>{'canPost': !isPosted, 'canCancel': !isPosted},
            'lines': <Map<String, dynamic>>[<String, dynamic>{'id': 1, 'originalSalesInvoiceLineId': 1, 'productId': 4, 'productName': 'Cappuccino', 'quantity': '10.000', 'unitPrice': '10.00', 'subtotal': '100.00', 'taxTotal': '0.00', 'total': '100.00', 'restock': true}],
          }}));
        }
        if (options.path == 'finance/sales-credit-notes/6/posting-preview') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
            'creditNote': <String, dynamic>{'subtotal': '100.00', 'tax': '0.00', 'total': '100.00'},
            'invoiceImpact': <String, dynamic>{'arReduction': '0.00', 'customerCreditCreated': '100.00', 'outstandingBefore': '0.00'},
            'lines': <Map<String, dynamic>>[<String, dynamic>{'lineId': 1, 'productName': 'Cappuccino', 'quantity': '10.000', 'subtotal': '100.00', 'tax': '0.00', 'total': '100.00', 'restock': true, 'cogsReversal': '60.00'}],
          }));
        }
        if (options.path == 'finance/sales-credit-notes/6/post' && options.method == 'POST') {
          isPosted = true;
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <String, dynamic>{
            'id': 6, 'creditNoteNumber': 'CN-2026-000006', 'branchId': 3, 'branchName': 'Downtown', 'customerId': 2, 'customerName': 'Damascus Tech',
            'originalSalesInvoiceId': 20, 'originalInvoiceNumber': 'SI-2026-000020', 'creditDate': '2026-09-13', 'status': 'posted',
            'subtotal': '100.00', 'taxTotal': '0.00', 'total': '100.00', 'arReductionAmount': '0.00', 'customerCreditAmount': '100.00',
            'allowedActions': <String, dynamic>{},
          }}));
        }
        return handler.reject(DioException(requestOptions: options, message: 'unexpected path: ${options.path}'));
      }));
      final SalesCubit salesCubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      final FinanceSetupCubit financeCubit = FinanceSetupCubit(repository: FinanceSetupRepository(DioApiClient(dio: dio)));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: MultiBlocProvider(providers: <BlocProvider<dynamic>>[
        BlocProvider<SalesCubit>.value(value: salesCubit),
        BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
      ], child: const SalesCreditNoteDetailScreen(id: 6))))));
      await tester.pumpAndSettle();

      expect(find.text('ترحيل الإشعار'), findsOneWidget);
      expect(find.text('إلغاء المسودة'), findsOneWidget);
      expect(find.text('+ رد مبلغ للعميل'), findsNothing);

      await tester.tap(find.text('ترحيل الإشعار'));
      await tester.pumpAndSettle();
      expect(find.text('تأكيد ترحيل الإشعار الدائن'), findsOneWidget);
      await tester.tap(find.text('ترحيل'));
      await tester.pumpAndSettle();

      expect(find.text('تم ترحيل الإشعار الدائن بنجاح.'), findsOneWidget);
      expect(find.text('تخفيض الذمم المدينة'), findsOneWidget);
      expect(find.text('رصيد ائتماني للعميل'), findsOneWidget);
      expect(find.text('+ رد مبلغ للعميل'), findsOneWidget);
      expect(find.text('ترحيل الإشعار'), findsNothing);
    });
  });

  group('CustomerRefundDialog', () {
    testWidgets('shows available credit and posts a refund for the full amount', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      final List<RequestOptions> posted = <RequestOptions>[];
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == 'finance/payment-methods') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'code': 'CASH', 'name': 'نقدي', 'type': 'cash', 'financialAccountId': 9, 'financialAccountCode': '1010', 'isActive': true, 'financialLocationId': 7, 'financialLocationName': 'الصندوق'},
          ], 'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 1}}));
        }
        if (options.path == 'finance/customers/2/credit') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <String, dynamic>{
            'customer': <String, dynamic>{'id': 2, 'name': 'Damascus Tech'}, 'availableCredit': '100.00',
          }}));
        }
        if (options.path == 'finance/customer-refunds' && options.method == 'POST') {
          posted.add(options);
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 201, data: <String, dynamic>{'data': <String, dynamic>{
            'id': 1, 'refundNumber': 'RF-2026-000001', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown',
            'refundDate': '2026-09-14', 'amount': '100.00', 'paymentMethodName': 'نقدي', 'financialLocationName': 'الصندوق', 'status': 'posted',
          }}));
        }
        return handler.reject(DioException(requestOptions: options, message: 'unexpected path: ${options.path}'));
      }));
      final SalesRepository repository = SalesRepository(DioApiClient(dio: dio));
      final FinanceSetupRepository financeSetupRepository = FinanceSetupRepository(DioApiClient(dio: dio));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        onPressed: () => CustomerRefundDialog.show(context, api: repository, financeSetupRepository: financeSetupRepository, customerId: 2, customerName: 'Damascus Tech', branchId: 3),
        child: const Text('open'),
      ))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('رد مبلغ للعميل — Damascus Tech'), findsOneWidget);
      expect(find.textContaining('الرصيد الائتماني المتاح: 100.00'), findsOneWidget);

      await tester.tap(find.text('تسجيل الرد'));
      await tester.pumpAndSettle();

      expect(posted, hasLength(1));
      final Map<String, dynamic> body = Map<String, dynamic>.from(posted.single.data as Map);
      expect(body['customerId'], 2);
      expect(body['amount'], '100.00');
      expect(body['paymentMethodId'], 1);
      expect(body['financialLocationId'], 7);
      expect(find.text('رد مبلغ للعميل — Damascus Tech'), findsNothing);
    });

    testWidgets('rejects a zero/empty amount before posting', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == 'finance/payment-methods') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'code': 'CASH', 'name': 'نقدي', 'type': 'cash', 'financialAccountId': 9, 'financialAccountCode': '1010', 'isActive': true, 'financialLocationId': 7, 'financialLocationName': 'الصندوق'},
          ], 'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 1}}));
        }
        if (options.path == 'finance/customers/2/credit') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <String, dynamic>{
            'customer': <String, dynamic>{'id': 2, 'name': 'Damascus Tech'}, 'availableCredit': '100.00',
          }}));
        }
        return handler.reject(DioException(requestOptions: options, message: 'unexpected POST with an invalid amount'));
      }));
      final SalesRepository repository = SalesRepository(DioApiClient(dio: dio));
      final FinanceSetupRepository financeSetupRepository = FinanceSetupRepository(DioApiClient(dio: dio));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        onPressed: () => CustomerRefundDialog.show(context, api: repository, financeSetupRepository: financeSetupRepository, customerId: 2, customerName: 'Damascus Tech', branchId: 3),
        child: const Text('open'),
      ))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'المبلغ'), '0');
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل الرد'));
      await tester.pumpAndSettle();

      expect(find.text('أدخل مبلغاً صحيحاً أكبر من صفر.'), findsOneWidget);
      expect(find.text('رد مبلغ للعميل — Damascus Tech'), findsOneWidget);
    });
  });
}
