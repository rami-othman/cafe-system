import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_home_screen.dart';
import 'package:windows_application/features/reports/models/reports_overview.dart';
import 'package:windows_application/features/reports/repositories/reports_repository.dart';

void main() {
  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets('shows real Net Sales and Gross Profit KPIs sourced from Reports Overview', (
    WidgetTester tester,
  ) async {
    serviceLocator.registerLazySingleton<ReportsRepository>(
      () => _FakeReportsRepository(available: true),
    );
    await _pumpScreen(tester);

    expect(find.text('صافي المبيعات اليوم'), findsOneWidget);
    expect(find.text('120.50'), findsOneWidget);
    expect(find.text('الربح الإجمالي اليوم'), findsOneWidget);
    expect(find.text('45.25'), findsOneWidget);
  });

  testWidgets('shows an unavailable message instead of a fabricated gross profit', (
    WidgetTester tester,
  ) async {
    serviceLocator.registerLazySingleton<ReportsRepository>(
      () => _FakeReportsRepository(available: false),
    );
    await _pumpScreen(tester);

    expect(find.text('التكلفة غير متاحة لكل الطلبات'), findsOneWidget);
    expect(find.text('45.25'), findsNothing);
  });

  testWidgets('the integration status reflects that POS accounting is now connected', (
    WidgetTester tester,
  ) async {
    serviceLocator.registerLazySingleton<ReportsRepository>(
      () => _FakeReportsRepository(available: true),
    );
    await _pumpScreen(tester);

    expect(find.text('محاسبة نقاط البيع'), findsOneWidget);
    expect(find.text('متصلة'), findsWidgets);
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        if (options.path == 'finance/setup-status') {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{
                'data': <String, dynamic>{
                  'systemAccountsReady': true,
                  'centralWarehouseReady': true,
                  'branchWarehouseCoverageReady': true,
                  'financialSetupReady': true,
                  'missingBranchWarehouses': <String>[],
                  'accountCount': 20,
                  'activeAccountCount': 20,
                  'journalCount': 3,
                  'draftJournalCount': 0,
                  'postedJournalCount': 3,
                  'cashBankAccountCount': 3,
                  'cashBankBalance': '500.00',
                  'activePaymentMethodCount': 1,
                  'expensesToday': '0.00',
                  'expensesThisMonth': '0.00',
                  'pendingExpenseCount': 0,
                  'unpaidExpenseCount': 0,
                  'journalEngineReady': true,
                  'journalReversalReady': true,
                  'postingInfrastructureReady': true,
                },
              },
            ),
          );
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(requestOptions: options, statusCode: 404),
          ),
        );
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
            child: const FinanceHomeScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeReportsRepository extends ReportsRepository {
  _FakeReportsRepository({required this.available}) : super();

  final bool available;

  @override
  Future<ReportsOverview> getOverview({
    required DateTime from,
    required DateTime to,
    int? branchId,
    required bool comparePrevious,
  }) async => ReportsOverview.fromJson(<String, dynamic>{
    'period': <String, dynamic>{
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    },
    'currency': 'SYP',
    'branches': const <dynamic>[],
    'selectedBranchId': null,
    'kpis': <String, dynamic>{
      'netSales': <String, dynamic>{
        'value': 120.50,
        'previousValue': null,
        'available': true,
        'reason': null,
      },
      'grossProfit': <String, dynamic>{
        'value': available ? 45.25 : null,
        'previousValue': null,
        'available': available,
        'reason': available
            ? null
            : 'Cost of goods sold has not been recorded for every paid order.',
      },
      'grossMargin': <String, dynamic>{
        'value': null,
        'previousValue': null,
        'available': false,
        'reason': null,
      },
      'totalExpenses': <String, dynamic>{
        'value': null,
        'previousValue': null,
        'available': false,
        'reason': null,
      },
      'netProfit': <String, dynamic>{
        'value': null,
        'previousValue': null,
        'available': false,
        'reason': null,
      },
    },
    'salesTrend': const <dynamic>[],
    'branchComparison': const <dynamic>[],
    'topProducts': const <dynamic>[],
    'recentExceptions': const <dynamic>[],
  });
}
