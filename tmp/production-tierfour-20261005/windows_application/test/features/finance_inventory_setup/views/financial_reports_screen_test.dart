import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/financial_reports_screen.dart';

void main() {
  testWidgets('report center loads with the selector and the default P&L report', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    expect(find.text('قائمة الدخل'), findsOneWidget);
    expect(find.text('الميزانية العمومية'), findsOneWidget);
    expect(find.text('كشف حساب المورد'), findsOneWidget);
    expect(find.text('صافي الإيرادات'), findsWidgets);
    expect(find.text('1000.00'), findsOneWidget); // KPI card value (no currency suffix)
    expect(find.text('1000.00 SYP'), findsWidgets); // table rows (account + total, via FinanceAmount)
  });

  testWidgets('shows an error with retry when a report fails to load', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend()..failProfitLoss = true;
    await _pump(tester, backend);

    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('P&L renders the real COGS integrity banner and drills an account into the General Ledger', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    expect(find.textContaining('يوجد 2 حركة مخزون بلا ترحيل محاسبي'), findsOneWidget);

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();

    expect(find.text('دفتر الأستاذ العام'), findsOneWidget);
    expect(find.text('400.00'), findsOneWidget); // opening balance KPI
    expect(backend.lastGeneralLedgerAccountId, 1);
  });

  testWidgets('switching reports preserves the selected branch filter', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.byType(DropdownButton<int?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفرع: Main Branch').last);
    await tester.pumpAndSettle();
    expect(backend.lastBranchId, 1);

    await tester.tap(find.text('الميزانية العمومية'));
    await tester.pumpAndSettle();

    expect(backend.lastBranchId, 1);
  });

  testWidgets('Balance Sheet renders groups/totals and drills an account into the General Ledger', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.text('الميزانية العمومية'));
    await tester.pumpAndSettle();

    expect(find.text('الأصول'), findsOneWidget);
    expect(find.text('الالتزامات'), findsOneWidget);
    expect(find.text('حقوق الملكية'), findsOneWidget);
    expect(find.textContaining('الأصول = الالتزامات + حقوق الملكية'), findsOneWidget);

    await tester.tap(find.text('Cash Drawer'));
    await tester.pumpAndSettle();
    expect(find.text('دفتر الأستاذ العام'), findsOneWidget);
    expect(backend.lastGeneralLedgerAccountId, 1);
  });

  testWidgets('Cash Flow renders its sections and opens the journal drawer for a transaction', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.text('التدفقات النقدية'));
    await tester.pumpAndSettle();

    expect(find.text('النقد الافتتاحي'), findsOneWidget);
    await tester.tap(find.textContaining('JE-010'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
  });

  testWidgets('Trial Balance toggles zero-balance accounts via a real backend refetch', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.text('ميزان المراجعة'));
    await tester.pumpAndSettle();

    expect(find.text('Cash Drawer'), findsOneWidget);
    expect(find.text('Zero Balance Account'), findsNothing);

    await tester.tap(find.text('إظهار الحسابات ذات الرصيد صفر'));
    await tester.pumpAndSettle();

    expect(backend.lastIncludeZero, isTrue);
    expect(find.text('Zero Balance Account'), findsOneWidget);

    await tester.tap(find.text('Cash Drawer'));
    await tester.pumpAndSettle();
    expect(find.text('دفتر الأستاذ العام'), findsOneWidget);
  });

  testWidgets('General Ledger renders an account picker, balances, and a journal drill-down', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.text('دفتر الأستاذ العام'));
    await tester.pumpAndSettle();

    expect(find.text('الحساب:'), findsOneWidget);
    expect(find.text('400.00'), findsOneWidget); // opening balance KPI
    expect(find.text('450.00 SYP'), findsWidgets); // running balance cell (via FinanceAmount)

    await tester.tap(find.text('POS sale'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الحركة المالية'), findsOneWidget);
  });

  testWidgets('Supplier Aging renders buckets and navigates into the Supplier Statement', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.text('أعمار ذمم الموردين'));
    await tester.pumpAndSettle();

    expect(find.text('Eastern Mills'), findsOneWidget);
    expect(find.text('80.00 SYP'), findsWidgets);

    await tester.tap(find.text('Eastern Mills'));
    await tester.pumpAndSettle();

    expect(find.text('كشف حساب المورد'), findsOneWidget);
    expect(backend.lastSupplierStatementId, 5);
  });

  testWidgets('Supplier Statement renders the summary and drills invoice/payment rows into the supplier', (
    WidgetTester tester,
  ) async {
    final _FakeBackend backend = _FakeBackend();
    await _pump(tester, backend);

    await tester.tap(find.text('كشف حساب المورد'));
    await tester.pumpAndSettle();

    expect(find.text('المورد:'), findsOneWidget);
    expect(find.text('50.00 SYP'), findsWidgets); // closing balance

    await tester.tap(find.text('INV-1'));
    await tester.pumpAndSettle();
    expect(find.text('route:/finance/suppliers?invoiceId=501'), findsOneWidget);
  });

  testWidgets('renders without overflow across common desktop widths', (WidgetTester tester) async {
    final _FakeBackend backend = _FakeBackend();
    for (final double width in <double>[1280, 1366, 1440, 1600, 1920]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpWidget(_app(backend));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

Widget _app(_FakeBackend backend) {
  final GoRouter router = GoRouter(
    initialLocation: '/finance/reports',
    routes: <RouteBase>[
      GoRoute(path: '/finance/reports', builder: (_, _) => _wired(backend, const FinancialReportsScreen())),
      GoRoute(
        path: '/finance/suppliers',
        builder: (_, GoRouterState state) => Scaffold(body: Text('route:/finance/suppliers?${state.uri.query}')),
      ),
      GoRoute(
        path: '/finance/suppliers/:id',
        builder: (_, GoRouterState state) => Scaffold(body: Text('route:/finance/suppliers/${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Widget _wired(_FakeBackend backend, Widget child) {
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
  final FinanceSetupRepository repository = FinanceSetupRepository(DioApiClient(dio: dio));
  final FinanceSetupCubit cubit = FinanceSetupCubit(repository: repository);
  return Scaffold(body: BlocProvider<FinanceSetupCubit>.value(value: cubit, child: child));
}

Future<void> _pump(WidgetTester tester, _FakeBackend backend) async {
  await tester.binding.setSurfaceSize(const Size(1700, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(backend));
  await tester.pumpAndSettle();
}

class _FakeBackend {
  bool failProfitLoss = false;
  bool lastIncludeZero = false;
  int? lastBranchId;
  int? lastGeneralLedgerAccountId;
  int? lastSupplierStatementId;

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;
    final Map<String, dynamic> q = options.queryParameters;
    if (q.containsKey('branchId')) lastBranchId = int.tryParse('${q['branchId']}');

    if (path == 'finance/accounts') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'code': '1010',
          'nameAr': 'الصندوق',
          'nameEn': 'Cash Drawer',
          'accountGroup': 'assets',
          'normalBalance': 'debit',
          'isActive': true,
          'isSystemProtected': false,
        },
      ]);
    }
    if (path == 'branches') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Main Branch', 'currency': 'SYP', 'timezone': 'Asia/Damascus', 'isActive': true},
      ]);
    }
    if (path == 'finance/suppliers') {
      return _ok(options, <Map<String, dynamic>>[
        <String, dynamic>{'id': 5, 'supplierNumber': 'SUP-1', 'name': 'Eastern Mills', 'isActive': true},
      ]);
    }
    if (path == 'finance/reports/profit-loss') {
      if (failProfitLoss) {
        throw DioException(
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 500, data: <String, dynamic>{'message': 'Backend error.'}),
          type: DioExceptionType.badResponse,
        );
      }
      return _ok(options, <String, dynamic>{
        'dateFrom': '2026-09-01',
        'dateTo': '2026-09-30',
        'sections': <String, dynamic>{
          'revenue': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'code': '4000', 'name': 'Sales', 'group': 'revenue', 'normalBalance': 'credit', 'normalisedBalance': '1000.00'},
          ],
          'costOfSales': <Map<String, dynamic>>[
            <String, dynamic>{'id': 2, 'code': '5000', 'name': 'COGS', 'group': 'cost_of_sales', 'normalBalance': 'debit', 'normalisedBalance': '300.00'},
          ],
          'operatingExpenses': <Map<String, dynamic>>[
            <String, dynamic>{'id': 3, 'code': '6190', 'name': 'Misc Expense', 'group': 'expenses', 'normalBalance': 'debit', 'normalisedBalance': '100.00'},
          ],
        },
        'totals': <String, dynamic>{
          'revenue': '1000.00',
          'costOfSales': '300.00',
          'operatingExpenses': '100.00',
          'grossProfit': '700.00',
          'netOperatingProfit': '600.00',
        },
        'comparison': <String, dynamic>{
          'revenue': <String, dynamic>{'current': '1000.00', 'previous': '900.00', 'change': '100.00', 'percentageChange': '11.11'},
          'grossProfit': <String, dynamic>{'current': '700.00', 'previous': '600.00', 'change': '100.00', 'percentageChange': '16.67'},
          'netOperatingProfit': <String, dynamic>{'current': '600.00', 'previous': '500.00', 'change': '100.00', 'percentageChange': '20.00'},
        },
        'integrity': <String, dynamic>{'ledgerBased': true, 'cogsComplete': false, 'unpostedInventoryEventsCount': 2},
      });
    }
    if (path == 'finance/reports/balance-sheet') {
      return _ok(options, <String, dynamic>{
        'asOfDate': '2026-09-30',
        'assets': <String, dynamic>{
          'accounts': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'code': '1010', 'name': 'Cash Drawer', 'group': 'assets', 'normalBalance': 'debit', 'normalisedBalance': '500.00'},
          ],
          'total': '500.00',
        },
        'liabilities': <String, dynamic>{
          'accounts': <Map<String, dynamic>>[
            <String, dynamic>{'id': 2, 'code': '2001', 'name': 'Accounts Payable', 'group': 'liabilities', 'normalBalance': 'credit', 'normalisedBalance': '100.00'},
          ],
          'total': '100.00',
        },
        'equity': <String, dynamic>{
          'accounts': <Map<String, dynamic>>[
            <String, dynamic>{'id': 3, 'code': '3000', 'name': 'Capital', 'group': 'equity', 'normalBalance': 'credit', 'normalisedBalance': '300.00'},
          ],
          'currentPeriodEarnings': <String, dynamic>{'amount': '100.00', 'reportDerived': true},
          'total': '400.00',
        },
        'integrity': <String, dynamic>{'balanced': true, 'difference': '0.00'},
      });
    }
    if (path == 'finance/reports/cash-flow') {
      return _ok(options, <String, dynamic>{
        'dateFrom': '2026-09-01',
        'dateTo': '2026-09-30',
        'sections': <String, dynamic>{
          'operating': <Map<String, dynamic>>[
            <String, dynamic>{'journalId': 10, 'reference': 'JE-010', 'date': '2026-09-05', 'sourceType': 'pos_order', 'amount': '50.00'},
          ],
          'investing': <Map<String, dynamic>>[],
          'financing': <Map<String, dynamic>>[],
          'internal_transfer': <Map<String, dynamic>>[],
          'unclassified': <Map<String, dynamic>>[],
        },
        'openingCashBanks': '100.00',
        'closingCashBanks': '150.00',
        'netCashFlow': '50.00',
        'integrity': <String, dynamic>{'reconciled': true, 'difference': '0.00', 'unclassified': '0.00'},
      });
    }
    if (path == 'finance/reports/trial-balance') {
      lastIncludeZero = '${q['includeZero']}' == 'true';
      final List<Map<String, dynamic>> accounts = <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'code': '1010', 'name': 'Cash Drawer', 'group': 'assets', 'normalBalance': 'debit', 'closingDebit': '500.00', 'closingCredit': '0.00'},
        if (lastIncludeZero)
          <String, dynamic>{'id': 4, 'code': '5500', 'name': 'Zero Balance Account', 'group': 'expenses', 'normalBalance': 'debit', 'closingDebit': '0.00', 'closingCredit': '0.00'},
      ];
      return _ok(options, <String, dynamic>{
        'dateFrom': '2026-09-01',
        'dateTo': '2026-09-30',
        'accounts': accounts,
        'totals': <String, dynamic>{'debit': '500.00', 'credit': '500.00', 'difference': '0.00', 'balanced': true},
      });
    }
    if (path == 'finance/reports/general-ledger') {
      lastGeneralLedgerAccountId = int.tryParse('${q['accountId']}');
      return _ok(options, <String, dynamic>{
        'account': <String, dynamic>{'id': lastGeneralLedgerAccountId, 'code': '1010', 'name': 'Cash Drawer', 'normalBalance': 'debit'},
        'dateFrom': '2026-09-01',
        'dateTo': '2026-09-30',
        'openingBalance': '400.00',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'accountingDate': '2026-09-05',
            'journal': <String, dynamic>{'id': 10, 'reference': 'JE-010'},
            'source': <String, dynamic>{'type': 'pos_order', 'id': 77},
            'description': 'POS sale',
            'debit': '50.00',
            'credit': '0.00',
            'runningBalance': '450.00',
          },
        ],
        'closingBalance': '450.00',
        'meta': <String, dynamic>{'currentPage': 1, 'perPage': 50, 'total': 1, 'lastPage': 1},
      });
    }
    if (path == 'finance/reports/supplier-aging') {
      return _ok(options, <String, dynamic>{
        'asOfDate': '2026-09-30',
        'suppliers': <Map<String, dynamic>>[
          <String, dynamic>{
            'supplier': <String, dynamic>{'id': 5, 'name': 'Eastern Mills'},
            'current': '0.00',
            'days1To30': '80.00',
            'days31To60': '0.00',
            'days61To90': '0.00',
            'days90Plus': '0.00',
            'totalOutstanding': '80.00',
          },
        ],
        'totals': <String, dynamic>{
          'current': '0.00',
          'days1To30': '80.00',
          'days31To60': '0.00',
          'days61To90': '0.00',
          'days90Plus': '0.00',
          'totalOutstanding': '80.00',
        },
      });
    }
    if (path == 'finance/reports/supplier-statement') {
      lastSupplierStatementId = int.tryParse('${q['supplierId']}');
      return _ok(options, <String, dynamic>{
        'supplierId': lastSupplierStatementId,
        'dateFrom': '2026-09-01',
        'dateTo': '2026-09-30',
        'openingBalance': '0.00',
        'lines': <Map<String, dynamic>>[
          <String, dynamic>{
            'date': '2026-09-05',
            'type': 'supplier_invoice',
            'reference': 'INV-1',
            'description': 'Supplier invoice',
            'debit': '80.00',
            'credit': '0.00',
            'runningOutstanding': '80.00',
            'drillDown': <String, dynamic>{'resourceKind': 'supplier_invoice', 'id': 501, 'reference': 'INV-1'},
          },
          <String, dynamic>{
            'date': '2026-09-10',
            'type': 'supplier_payment',
            'reference': 'PAY-1',
            'description': 'Supplier payment allocation',
            'debit': '0.00',
            'credit': '30.00',
            'runningOutstanding': '50.00',
            'drillDown': <String, dynamic>{'resourceKind': 'supplier_payment', 'id': 701, 'reference': 'PAY-1'},
          },
        ],
        'closingBalance': '50.00',
      });
    }
    if (path.startsWith('finance/transactions/')) {
      final int id = int.parse(path.split('/').last);
      return _ok(options, <String, dynamic>{
        'reference': 'JE-$id',
        'transactionDate': '2026-09-05',
        'description': 'POS sale',
        'branch': <String, dynamic>{'name': 'Main Branch'},
        'source': <String, dynamic>{'type': 'pos_order', 'normalizedType': 'sale', 'resourceKind': 'order', 'id': 77, 'available': true},
        'displayAmount': <String, dynamic>{'amount': '50.00'},
        'reversal': <String, dynamic>{'state': 'none'},
        'journal': <String, dynamic>{'id': id, 'status': 'posted', 'lines': <Map<String, dynamic>>[]},
      });
    }

    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{'message': 'Unhandled test route: ${options.method} $path'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  Response<dynamic> _ok(RequestOptions options, dynamic data) =>
      Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': data});
}
