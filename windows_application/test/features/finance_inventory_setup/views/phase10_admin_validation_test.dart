import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_operations_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/financial_accounts_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/payment_methods_screen.dart';

void main() {
  const List<double> widths = <double>[1280, 1366, 1440, 1600, 1920];

  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets(
    'Account Detail is RTL, overflow-free, and opens General Ledger at every desktop width',
    (WidgetTester tester) async {
      final _Phase10Api api = _Phase10Api();
      for (final double width in widths) {
        final GoRouter router = GoRouter(
          initialLocation: '/finance/accounts/1',
          routes: <RouteBase>[
            GoRoute(
              path: '/finance/accounts/:id',
              builder: (_, GoRouterState state) => _wired(
                api,
                FinancialAccountsScreen(
                  accountId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ),
            GoRoute(
              path: '/finance/reports',
              builder: (_, GoRouterState state) => Scaffold(
                body: Text('gl:${state.uri.queryParameters['accountId']}'),
              ),
            ),
          ],
        );
        await _pumpRouter(tester, router, width);

        expect(find.textContaining(_Phase10Api.longAccountName), findsWidgets);
        expect(find.text('عرض دفتر الأستاذ'), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.text('عرض دفتر الأستاذ'))),
          TextDirection.rtl,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'account detail width $width',
        );

        await tester.tap(find.text('عرض دفتر الأستاذ'));
        await tester.pumpAndSettle();
        expect(find.text('gl:1'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Accounting Period Detail presents backend readiness and blockers without overflow at every desktop width',
    (WidgetTester tester) async {
      final _Phase10Api api = _Phase10Api();
      serviceLocator.registerLazySingleton<FinanceSetupRepository>(
        () => api.repository(),
      );

      for (final double width in widths) {
        final GoRouter router = GoRouter(
          initialLocation: '/finance/accounting-periods/9',
          routes: <RouteBase>[
            GoRoute(
              path: '/finance/accounting-periods/:id',
              builder: (_, GoRouterState state) => FinanceOperationScreen(
                kind: FinanceOperationKind.period,
                id: int.parse(state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/finance/journal-entries',
              builder: (_, _) => const Scaffold(body: Text('journals-route')),
            ),
            GoRoute(
              path: '/finance/daily-closings',
              builder: (_, _) => const Scaffold(body: Text('closing-route')),
            ),
            GoRoute(
              path: '/inventory/movements',
              builder: (_, _) => const Scaffold(body: Text('inventory-route')),
            ),
          ],
        );
        await _pumpRouter(tester, router, width);

        expect(find.text('الإغلاق محجوب'), findsOneWidget);
        expect(find.textContaining('DRAFT_JOURNALS (1)'), findsOneWidget);
        expect(find.textContaining('OPEN_DAILY_CLOSINGS (1)'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'period detail width $width',
        );

        await tester.tap(find.text('عرض').first);
        await tester.pumpAndSettle();
        expect(find.text('journals-route'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Payment Method financial-location picker is expanded, submits the real relation, and remains overflow-free at every desktop width',
    (WidgetTester tester) async {
      final _Phase10Api api = _Phase10Api();
      for (final double width in widths) {
        final FinanceSetupRepository repository = api.repository();
        final FinanceSetupCubit cubit = FinanceSetupCubit(
          repository: repository,
        );
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: BlocProvider<FinanceSetupCubit>.value(
                  value: cubit,
                  child: const PaymentMethodsScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('غير مربوط'), findsOneWidget);
        await tester.tap(find.text('إضافة طريقة'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), 'WALLET');
        await tester.enterText(
          find.byType(TextField).at(1),
          'محفظة طويلة الاسم لاختبار اتساع الحوار',
        );
        await tester.tap(find.text('غير مربوط بموقع مالي'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('CASH-DRAWER'));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'payment dialog width $width',
        );

        await tester.tap(find.text('حفظ'));
        await tester.pumpAndSettle();
        expect(api.lastPaymentPayload?['financialLocationId'], 501);
        expect(api.lastPaymentPayload?['financialAccountId'], 11);
        expect(
          find.text('حفظ'),
          findsNothing,
          reason: 'dialog closes after backend success',
        );
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router,
  double width,
) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Widget _wired(_Phase10Api api, Widget child) {
  final FinanceSetupRepository repository = api.repository();
  return Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider<FinanceSetupCubit>.value(
      value: FinanceSetupCubit(repository: repository),
      child: child,
    ),
  );
}

class _Phase10Api {
  static const String longAccountName =
      'مصروفات تشغيلية طويلة جداً لاختبار قابلية قراءة الاسم ضمن دليل الحسابات';
  Map<String, dynamic>? lastPaymentPayload;

  FinanceSetupRepository repository() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          try {
            handler.resolve(respond(options));
          } on DioException catch (error) {
            handler.reject(error);
          }
        },
      ),
    );
    return FinanceSetupRepository(DioApiClient(dio: dio));
  }

  Response<dynamic> respond(RequestOptions options) {
    final String path = options.path;
    final String method = options.method;
    if (path == 'finance/accounts' && method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[_account(), _cashAccount()]);
    }
    if (path == 'finance/accounts/1' && method == 'GET') {
      return _ok(options, _account());
    }
    if (path == 'finance/accounting-periods/9' && method == 'GET') {
      return _ok(options, _period());
    }
    if (path == 'finance/payment-methods' && method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[_paymentMethod()]);
    }
    if (path == 'finance/payment-methods' && method == 'POST') {
      lastPaymentPayload = Map<String, dynamic>.from(options.data as Map);
      return _ok(options, <String, dynamic>{
        ..._paymentMethod(),
        ...lastPaymentPayload!,
      });
    }
    if (path == 'finance/cash-accounts' && method == 'GET') {
      return _ok(options, <Map<String, dynamic>>[_cashLocation()]);
    }
    if (path == 'finance/bank-accounts' && method == 'GET') {
      return _ok(options, const <Map<String, dynamic>>[]);
    }
    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{
          'message': 'Unhandled test route: $method $path',
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }

  Response<dynamic> _ok(RequestOptions options, dynamic data) =>
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{'data': data},
      );

  Map<String, dynamic> _account() => <String, dynamic>{
    'id': 1,
    'code': '6100',
    'nameAr': longAccountName,
    'nameEn': 'Very Long Operating Expense Account',
    'accountGroup': 'expenses',
    'normalBalance': 'debit',
    'parentAccountId': 10,
    'parentCode': '6000',
    'parentNameAr': 'المصروفات',
    'isActive': true,
    'isSystemProtected': false,
  };

  Map<String, dynamic> _paymentMethod() => <String, dynamic>{
    'id': 7,
    'code': 'CASH',
    'name': 'نقدي',
    'type': 'cash',
    'financialAccountId': 11,
    'financialAccountCode': '1010',
    'financialAccountNameAr': 'الصندوق',
    'financialLocationId': null,
    'financialLocationName': null,
    'isActive': true,
    'sortOrder': 0,
  };

  Map<String, dynamic> _cashAccount() => <String, dynamic>{
    'id': 11,
    'code': '1010',
    'nameAr': 'الصندوق',
    'nameEn': 'Cash Drawer',
    'accountGroup': 'assets',
    'normalBalance': 'debit',
    'isActive': true,
    'isSystemProtected': false,
  };

  Map<String, dynamic> _cashLocation() => <String, dynamic>{
    'id': 501,
    'code': 'CASH-DRAWER',
    'name': 'صندوق رئيسي طويل الاسم لاختبار قائمة الاختيار',
    'kind': 'cash',
    'type': 'cash_drawer',
    'financialAccountId': 11,
    'financialAccountCode': '1010',
    'balance': '0.00',
    'todayIncoming': '0.00',
    'todayOutgoing': '0.00',
    'isActive': true,
  };

  Map<String, dynamic> _period() => <String, dynamic>{
    'id': 9,
    'name': 'الفترة المحاسبية ذات الاسم الطويل لاختبار مساحة التفاصيل',
    'startDate': '2026-09-01',
    'endDate': '2026-09-30',
    'status': 'open',
    'closedAt': null,
    'lockedAt': null,
    'notes': 'تستخدم البيانات المعادة من الخادم كما هي.',
    'allowedActions': const <String>[],
    'readiness': <String, dynamic>{
      'canClose': false,
      'blockers': <Map<String, dynamic>>[
        <String, dynamic>{'code': 'DRAFT_JOURNALS', 'count': 1},
        <String, dynamic>{'code': 'OPEN_DAILY_CLOSINGS', 'count': 1},
      ],
      'warnings': const <Map<String, dynamic>>[],
    },
  };
}
