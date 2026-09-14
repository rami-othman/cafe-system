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
import 'package:windows_application/features/sales/views/sales_screens.dart';

/// Phase 3 — Customer Payments / AR. Every request is routed by path through
/// one fake Dio, mirroring how the real Finance API responds; these tests
/// verify Flutter parses and renders the derived payment fields correctly
/// and drives the registration/allocation flow without touching a server.
void main() {
  group('models', () {
    test('SalesInvoice parses derived paid/remaining/overdue/collections', () {
      final SalesInvoice invoice = SalesInvoice.fromJson(<String, dynamic>{
        'id': 10, 'invoiceNumber': 'SI-2026-000010', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown',
        'invoiceDate': '2026-09-12', 'status': 'posted', 'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00',
        'allowedActions': <String, dynamic>{'canView': true, 'canEdit': false, 'canCancel': false, 'canPost': false, 'canRegisterPayment': true},
        'paidAmount': '100.00', 'remainingAmount': '200.00', 'paymentStatus': 'partial', 'isOverdue': false,
        'collections': <Map<String, dynamic>>[
          <String, dynamic>{'paymentId': 5, 'paymentNumber': 'CR-2026-000001', 'paymentDate': '2026-09-13', 'paymentMethodName': 'Cash', 'amount': '100.00'},
        ],
      });
      expect(invoice.canRegisterPayment, isTrue);
      expect(invoice.paidAmount, '100.00');
      expect(invoice.remainingAmount, '200.00');
      expect(invoice.paymentStatus, 'partial');
      expect(invoice.collections, hasLength(1));
      expect(invoice.collections.single.paymentNumber, 'CR-2026-000001');
    });

    test('a fully paid invoice disables further payment registration', () {
      final SalesInvoice invoice = SalesInvoice.fromJson(<String, dynamic>{
        'id': 11, 'invoiceNumber': 'SI-2026-000011', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown',
        'invoiceDate': '2026-09-12', 'status': 'posted', 'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00',
        'allowedActions': <String, dynamic>{'canRegisterPayment': false},
        'paidAmount': '300.00', 'remainingAmount': '0.00', 'paymentStatus': 'paid',
      });
      expect(invoice.canRegisterPayment, isFalse);
    });

    test('CustomerReceivablesSummary orders open invoices as the server sent them (oldest-due-first)', () {
      final CustomerReceivablesSummary summary = CustomerReceivablesSummary.fromJson(<String, dynamic>{
        'customer': <String, dynamic>{'id': 2, 'name': 'Damascus Tech'},
        'outstanding': '225.00',
        'openInvoices': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'invoiceNumber': 'SI-1', 'invoiceDate': '2026-01-01', 'dueDate': '2026-01-01', 'total': '50.00', 'paid': '0.00', 'remaining': '50.00', 'isOverdue': true},
          <String, dynamic>{'id': 2, 'invoiceNumber': 'SI-2', 'invoiceDate': '2026-01-01', 'dueDate': '2026-06-01', 'total': '75.00', 'paid': '0.00', 'remaining': '75.00', 'isOverdue': true},
          <String, dynamic>{'id': 3, 'invoiceNumber': 'SI-3', 'invoiceDate': '2026-01-01', 'dueDate': '2026-12-01', 'total': '100.00', 'paid': '0.00', 'remaining': '100.00', 'isOverdue': false},
        ],
      });
      expect(summary.outstanding, '225.00');
      expect(summary.openInvoices.map((i) => i.id).toList(), <int>[1, 2, 3]);
    });
  });

  group('Sales Center list', () {
    testWidgets('shows paid/remaining/payment-status columns and a Register Payment action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
        'data': <Map<String, dynamic>>[<String, dynamic>{
          'id': 10, 'invoiceNumber': 'SI-2026-000010', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'invoiceDate': '2026-09-12', 'status': 'posted',
          'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00', 'paidAmount': '100.00', 'remainingAmount': '200.00', 'paymentStatus': 'partial',
          'allowedActions': <String, dynamic>{'canView': true, 'canEdit': false, 'canCancel': false, 'canPost': false, 'canRegisterPayment': true},
        }],
        'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 1}, 'summary': <String, dynamic>{'draftInvoiceCount': 0, 'draftInvoiceTotal': '0.00'},
      }))));
      final SalesCubit cubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: BlocProvider<SalesCubit>.value(value: cubit, child: const SalesCenterScreen())))));
      await tester.pumpAndSettle();
      expect(find.text('100.00'), findsOneWidget);
      expect(find.text('200.00'), findsOneWidget);
      expect(find.text('مدفوعة جزئياً'), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsOneWidget);
    });
  });

  group('Sales Invoice detail', () {
    Widget buildDetail(Dio dio) {
      final SalesCubit salesCubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      final FinanceSetupCubit financeCubit = FinanceSetupCubit(repository: FinanceSetupRepository(DioApiClient(dio: dio)));
      return MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: MultiBlocProvider(providers: <BlocProvider<dynamic>>[
        BlocProvider<SalesCubit>.value(value: salesCubit),
        BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
      ], child: const SalesInvoiceDetailScreen(id: 10)))));
    }

    testWidgets('shows invoice total/paid/remaining/status and collection history, with Register Payment visible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
        'data': <String, dynamic>{
          'id': 10, 'invoiceNumber': 'SI-2026-000010', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'invoiceDate': '2026-09-12', 'status': 'posted',
          'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00', 'paidAmount': '100.00', 'remainingAmount': '200.00', 'paymentStatus': 'partial',
          'allowedActions': <String, dynamic>{'canView': true, 'canEdit': false, 'canCancel': false, 'canPost': false, 'canRegisterPayment': true},
          'lines': <Map<String, dynamic>>[],
          'collections': <Map<String, dynamic>>[<String, dynamic>{'paymentId': 5, 'paymentNumber': 'CR-2026-000001', 'paymentDate': '2026-09-13', 'paymentMethodName': 'Cash', 'amount': '100.00'}],
        },
      }))));
      await tester.pumpWidget(buildDetail(dio));
      await tester.pumpAndSettle();
      expect(find.text('مدفوعة جزئياً'), findsOneWidget);
      expect(find.text('سجل التحصيلات'), findsOneWidget);
      expect(find.text('CR-2026-000001'), findsOneWidget);
      expect(find.text('+ تسجيل دفعة'), findsOneWidget);
      expect(find.text('ترحيل الفاتورة'), findsNothing);
      expect(find.text('ترحيل وتسجيل دفعة'), findsNothing);
    });

    testWidgets('a draft invoice shows Post and Post-and-Collect but no Register Payment', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
        'data': <String, dynamic>{
          'id': 10, 'invoiceNumber': 'SI-2026-000010', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'invoiceDate': '2026-09-12', 'status': 'draft',
          'subtotal': '300.00', 'taxTotal': '0.00', 'total': '300.00',
          'allowedActions': <String, dynamic>{'canView': true, 'canEdit': true, 'canCancel': true, 'canPost': true, 'canRegisterPayment': false},
          'lines': <Map<String, dynamic>>[], 'collections': <Map<String, dynamic>>[],
        },
      }))));
      await tester.pumpWidget(buildDetail(dio));
      await tester.pumpAndSettle();
      expect(find.text('ترحيل الفاتورة'), findsOneWidget);
      expect(find.text('ترحيل وتسجيل دفعة'), findsOneWidget);
      expect(find.text('+ تسجيل دفعة'), findsNothing);
      expect(find.text('سجل التحصيلات'), findsNothing);
    });
  });

  group('CustomerPaymentDialog', () {
    testWidgets('auto-allocates oldest-due-first and posts a balanced allocation', (tester) async {
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
        if (options.path == 'finance/customers/2/receivables') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <String, dynamic>{
            'customer': <String, dynamic>{'id': 2, 'name': 'Damascus Tech'}, 'outstanding': '225.00',
            'openInvoices': <Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'invoiceNumber': 'SI-1', 'invoiceDate': '2026-01-01', 'dueDate': '2026-01-01', 'total': '50.00', 'paid': '0.00', 'remaining': '50.00', 'isOverdue': true},
              <String, dynamic>{'id': 2, 'invoiceNumber': 'SI-2', 'invoiceDate': '2026-01-01', 'dueDate': '2026-06-01', 'total': '175.00', 'paid': '0.00', 'remaining': '175.00', 'isOverdue': false},
            ],
          }}));
        }
        if (options.path == 'finance/customer-payments' && options.method == 'POST') {
          posted.add(options);
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 201, data: <String, dynamic>{'data': <String, dynamic>{
            'id': 99, 'paymentNumber': 'CR-2026-000099', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'paymentDate': '2026-09-12',
            'amount': '150.00', 'paymentMethodName': 'نقدي', 'financialLocationName': 'الصندوق', 'status': 'posted',
          }}));
        }
        return handler.reject(DioException(requestOptions: options, message: 'unexpected path: ${options.path}'));
      }));

      final SalesCubit salesCubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      final FinanceSetupCubit financeCubit = FinanceSetupCubit(repository: FinanceSetupRepository(DioApiClient(dio: dio)));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: MultiBlocProvider(providers: <BlocProvider<dynamic>>[
        BlocProvider<SalesCubit>.value(value: salesCubit),
        BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
      ], child: Builder(builder: (context) => ElevatedButton(
        onPressed: () => CustomerPaymentDialog.show(context, salesRepository: salesCubit.repository, financeSetupRepository: financeCubit.repository, customerId: 2, customerName: 'Damascus Tech', branchId: 3),
        child: const Text('open'),
      )))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('تسجيل دفعة من العميل — Damascus Tech'), findsOneWidget);
      expect(find.text('SI-1'), findsOneWidget);
      expect(find.text('SI-2'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('customerPaymentAmountField')), '150.00');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('autoAllocateButton')));
      await tester.pumpAndSettle();

      // Oldest due (SI-1, 50.00) filled first, then the remaining 100.00 into SI-2.
      expect(tester.widget<TextField>(find.byKey(const Key('allocationField-1'))).controller!.text, '50.00');
      expect(tester.widget<TextField>(find.byKey(const Key('allocationField-2'))).controller!.text, '100.00');
      expect(find.textContaining('المتبقي غير الموزع: 0.00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('customerPaymentSubmit')));
      await tester.pumpAndSettle();

      expect(posted, hasLength(1));
      final Map<String, dynamic> body = Map<String, dynamic>.from(posted.single.data as Map);
      expect(body['amount'], '150.00');
      expect(body['paymentMethodId'], 1);
      expect(body['financialLocationId'], 7);
      final List<dynamic> allocations = body['allocations'] as List<dynamic>;
      expect(allocations, hasLength(2));
      // Dialog closes and reports success once posted.
      expect(find.text('تسجيل دفعة من العميل — Damascus Tech'), findsNothing);
    });

    testWidgets('blocks posting while any amount is left unallocated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == 'finance/payment-methods') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'code': 'CASH', 'name': 'نقدي', 'type': 'cash', 'financialAccountId': 9, 'financialAccountCode': '1010', 'isActive': true, 'financialLocationId': 7, 'financialLocationName': 'الصندوق'},
          ], 'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 1}}));
        }
        if (options.path == 'finance/customers/2/receivables') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <String, dynamic>{
            'customer': <String, dynamic>{'id': 2, 'name': 'Damascus Tech'}, 'outstanding': '300.00',
            'openInvoices': <Map<String, dynamic>>[<String, dynamic>{'id': 1, 'invoiceNumber': 'SI-1', 'invoiceDate': '2026-01-01', 'dueDate': '2026-01-01', 'total': '300.00', 'paid': '0.00', 'remaining': '300.00', 'isOverdue': false}],
          }}));
        }
        return handler.reject(DioException(requestOptions: options, message: 'unexpected POST during unallocated-amount test'));
      }));
      final SalesCubit salesCubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      final FinanceSetupCubit financeCubit = FinanceSetupCubit(repository: FinanceSetupRepository(DioApiClient(dio: dio)));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: MultiBlocProvider(providers: <BlocProvider<dynamic>>[
        BlocProvider<SalesCubit>.value(value: salesCubit),
        BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
      ], child: Builder(builder: (context) => ElevatedButton(
        onPressed: () => CustomerPaymentDialog.show(context, salesRepository: salesCubit.repository, financeSetupRepository: financeCubit.repository, customerId: 2, customerName: 'Damascus Tech', branchId: 3),
        child: const Text('open'),
      )))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('customerPaymentAmountField')), '300.00');
      await tester.enterText(find.byKey(const Key('allocationField-1')), '100.00');
      await tester.pumpAndSettle();
      expect(find.textContaining('المتبقي غير الموزع: 200.00'), findsOneWidget);

      await tester.tap(find.byKey(const Key('customerPaymentSubmit')));
      await tester.pumpAndSettle();

      // Still open — no POST was attempted (the interceptor would have rejected it and surfaced an error snackbar instead).
      expect(find.text('تسجيل دفعة من العميل — Damascus Tech'), findsOneWidget);
      expect(find.text('يجب توزيع كامل مبلغ الدفعة على الفواتير قبل الترحيل.'), findsOneWidget);
    });
  });
}
