import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/supplier_profile_screen.dart';

void main() {
  testWidgets('renders supplier KPIs, tabs, an overdue invoice badge, and the deferred Purchases tab', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.textContaining('SUP-00003'), findsWidgets);
    expect(find.text('الرصيد المستحق'), findsOneWidget);
    expect(find.text('800.00'), findsWidgets);
    expect(find.text('AP-000010'), findsOneWidget);
    expect(find.text('متأخر'), findsOneWidget);

    await tester.tap(find.text('الدفعات'));
    await tester.pumpAndSettle();
    expect(find.text('SPAY-000005'), findsOneWidget);

    await tester.tap(find.text('كشف الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('1500.00'), findsWidgets);

    await tester.tap(find.text('المشتريات'));
    await tester.pumpAndSettle();
    expect(find.text('وحدة المشتريات غير مطبقة بعد.'), findsOneWidget);
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        try {
          handler.resolve(_respond(options));
        } on DioException catch (error) {
          handler.reject(error);
        }
      },
    ),
  );
  final FinanceSetupRepository repository = FinanceSetupRepository(
    DioApiClient(dio: dio),
  );
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BlocProvider<FinanceSetupCubit>.value(
            value: cubit,
            child: const SupplierProfileScreen(supplierId: 3),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Response<dynamic> _respond(RequestOptions options) {
  final String path = options.path;

  if (path == 'finance/suppliers/3') {
    return _ok(options, <String, dynamic>{
      'id': 3,
      'supplierNumber': 'SUP-00003',
      'name': 'Acme Roasters',
      'isActive': true,
      'outstandingBalance': '800.00',
      'overdueBalance': '300.00',
      'openInvoiceCount': 1,
      'totalInvoiced': '1500.00',
      'totalPaid': '700.00',
    });
  }
  if (path == 'finance/supplier-invoices') {
    return _ok(options, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 10,
        'internalReference': 'AP-000010',
        'invoiceNumber': 'INV-777',
        'supplierId': 3,
        'supplierName': 'Acme Roasters',
        'invoiceDate': '2026-08-01',
        'dueDate': '2020-01-01',
        'invoiceType': 'expense',
        'subtotal': '800.00',
        'taxAmount': '0.00',
        'totalAmount': '800.00',
        'remainingAmount': '800.00',
        'status': 'posted',
        'isOverdue': true,
      },
    ]);
  }
  if (path == 'finance/supplier-payments') {
    return _ok(options, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 5,
        'paymentNumber': 'SPAY-000005',
        'supplierId': 3,
        'supplierName': 'Acme Roasters',
        'paymentDate': '2026-08-15',
        'amount': '700.00',
        'paymentMethodName': 'Cash',
        'financialLocationName': 'Cash Drawer',
        'status': 'posted',
      },
    ]);
  }
  if (path == 'finance/suppliers/3/statement') {
    return _ok(options, <String, dynamic>{
      'supplier': <String, dynamic>{'id': 3},
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2026-08-01',
          'type': 'invoice',
          'reference': 'AP-000010',
          'debit': '0.00',
          'credit': '1500.00',
          'runningBalance': '1500.00',
        },
        <String, dynamic>{
          'date': '2026-08-15',
          'type': 'payment',
          'reference': 'SPAY-000005',
          'debit': '700.00',
          'credit': '0.00',
          'runningBalance': '800.00',
        },
      ],
    });
  }
  if (path == 'finance/expense-categories') {
    return _ok(options, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 4,
        'code': 'RENT',
        'name': 'Rent',
        'financialAccountId': 12,
        'financialAccountCode': '6100',
        'isActive': true,
        'sortOrder': 0,
      },
    ]);
  }
  if (path == 'finance/accounts') {
    return _ok(options, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 12,
        'code': '6100',
        'nameAr': 'مصروف إيجار',
        'nameEn': 'Rent Expense',
        'accountGroup': 'expenses',
        'normalBalance': 'debit',
        'isActive': true,
        'isSystemProtected': false,
      },
    ]);
  }
  if (path == 'finance/payment-methods') {
    return _ok(options, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'code': 'CASH',
        'name': 'Cash',
        'type': 'cash',
        'financialAccountId': 2,
        'financialAccountCode': '1010',
        'isActive': true,
      },
    ]);
  }
  if (path == 'finance/cash-accounts' || path == 'finance/bank-accounts') {
    return _ok(options, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 3,
        'code': 'CASH-DRAWER',
        'name': 'Cash Drawer',
        'kind': 'cash',
        'type': 'cash_drawer',
        'financialAccountId': 2,
        'financialAccountCode': '1010',
        'isActive': true,
        'balance': '500.00',
        'todayIncoming': '0.00',
        'todayOutgoing': '0.00',
      },
    ]);
  }
  if (path == 'branches') {
    return _ok(options, <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': 'Main Branch',
        'currency': 'SYP',
        'timezone': 'Asia/Damascus',
        'isActive': true,
      },
    ]);
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

Response<dynamic> _ok(RequestOptions options, dynamic data) => Response<dynamic>(
  requestOptions: options,
  statusCode: 200,
  data: <String, dynamic>{'data': data},
);
