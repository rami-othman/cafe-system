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

/// Phase 5 — AR aging strip on the Customer Receivables screen. Every
/// request is routed by path through one fake Dio, mirroring the real
/// Finance API (same pattern as sales_phase_three_test.dart/sales_phase_four_test.dart).
void main() {
  group('models', () {
    test('CustomerArOverviewSummary parses totals and invoice counts', () {
      final CustomerArOverviewSummary summary = CustomerArOverviewSummary.fromJson(<String, dynamic>{
        'totalOutstanding': '200.00', 'currentOutstanding': '150.00', 'overdueOutstanding': '50.00',
        'totalCustomerCredit': '30.00', 'invoiceCounts': <String, dynamic>{'paid': 2, 'partial': 1, 'unpaid': 1},
      });
      expect(summary.totalOutstanding, '200.00');
      expect(summary.overdueOutstanding, '50.00');
      expect(summary.totalCustomerCredit, '30.00');
      expect(summary.partialCount, 1);
    });

    test('CustomerArAgingTotals parses every bucket', () {
      final CustomerArAgingTotals totals = CustomerArAgingTotals.fromJson(<String, dynamic>{
        'current': '100.00', 'days1To30': '50.00', 'days31To60': '25.00', 'days61To90': '10.00', 'days90Plus': '5.00', 'totalOutstanding': '190.00',
      });
      expect(totals.current, '100.00');
      expect(totals.days31To60, '25.00');
      expect(totals.totalOutstanding, '190.00');
    });
  });

  group('Customer Receivables aging strip', () {
    testWidgets('shows total AR, aging buckets and customer credit above the per-customer table', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.path == 'finance/customers-receivables') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
            'data': <Map<String, dynamic>>[<String, dynamic>{
              'customerId': 2, 'customerName': 'Damascus Tech', 'customerNumber': 'CUST-2', 'invoiceCount': 2,
              'totalInvoiced': '500.00', 'totalPaid': '300.00', 'outstanding': '200.00',
            }],
            'summary': <String, dynamic>{
              'totalOutstanding': '200.00', 'currentOutstanding': '150.00', 'overdueOutstanding': '50.00',
              'totalCustomerCredit': '45.00', 'invoiceCounts': <String, dynamic>{'paid': 1, 'partial': 1, 'unpaid': 0},
            },
          }));
        }
        if (options.path == 'finance/reports/customer-aging') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{
            'data': <String, dynamic>{
              'asOfDate': '2026-09-13', 'customers': <dynamic>[],
              'totals': <String, dynamic>{'current' : '150.00', 'days1To30': '30.00', 'days31To60': '20.00', 'days61To90': '0.00', 'days90Plus': '0.00', 'totalOutstanding': '200.00'},
            },
          }));
        }
        if (options.path == 'branches') {
          return handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <dynamic>[]}));
        }
        return handler.next(options);
      }));
      final SalesCubit salesCubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
      final FinanceSetupCubit financeCubit = FinanceSetupCubit(repository: FinanceSetupRepository(DioApiClient(dio: dio)));
      await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: MultiBlocProvider(providers: <BlocProvider<dynamic>>[
        BlocProvider<SalesCubit>.value(value: salesCubit),
        BlocProvider<FinanceSetupCubit>.value(value: financeCubit),
      ], child: const CustomerReceivablesScreen())))));
      await tester.pumpAndSettle();

      expect(find.text('Damascus Tech (CUST-2)'), findsOneWidget);
      expect(find.text('30.00'), findsOneWidget, reason: 'the days1To30 aging bucket');
      expect(find.text('20.00'), findsOneWidget, reason: 'the days31To60 aging bucket');
      expect(find.text('45.00'), findsOneWidget, reason: 'the customer credit tile');
      expect(find.textContaining('200.00'), findsWidgets, reason: 'total AR appears both in the strip and the aging totals');
    });
  });
}
