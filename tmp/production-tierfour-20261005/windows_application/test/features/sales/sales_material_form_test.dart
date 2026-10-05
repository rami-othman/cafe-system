import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import 'package:windows_application/features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import 'package:windows_application/features/sales/controllers/sales_cubit.dart';
import 'package:windows_application/features/sales/repositories/sales_repository.dart';
import 'package:windows_application/features/sales/views/sales_screens.dart';

void main() {
  testWidgets('manual sales shows direct posting and sells raw material in an allowed weight unit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final path = options.path;
      final Object data;
      if (path.endsWith('finance/customers')) {
        data = <String, dynamic>{'data': <Map<String, dynamic>>[<String, dynamic>{'id': 1, 'name': 'زبون', 'customerNumber': 'C-1', 'isActive': true, 'isWalkIn': false}]};
      } else if (path.endsWith('finance/sales-products')) {
        handler.reject(DioException(requestOptions: options, message: 'Products unavailable'));
        return;
      } else if (path.endsWith('finance/sales-materials')) {
        data = <String, dynamic>{'data': <Map<String, dynamic>>[<String, dynamic>{'id': 7, 'name': 'بن خام', 'baseUnit': 'kilogram', 'units': <String>['kilogram', 'gram']}]};
      } else if (path.endsWith('branches')) {
        data = <String, dynamic>{'data': <Map<String, dynamic>>[<String, dynamic>{'id': 2, 'name': 'Main Branch', 'currency': 'SYP', 'timezone': 'Asia/Damascus', 'isActive': true}]};
      } else {
        throw StateError('Unexpected request: $path');
      }
      handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: data));
    }));
    final client = DioApiClient(dio: dio);
    final sales = SalesCubit(repository: SalesRepository(client));
    final finance = FinanceSetupCubit(repository: FinanceSetupRepository(client));
    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: MultiBlocProvider(providers: [
      BlocProvider<SalesCubit>.value(value: sales),
      BlocProvider<FinanceSetupCubit>.value(value: finance),
    ], child: const SalesInvoiceFormScreen())))));
    await tester.pumpAndSettle();
    expect(find.text('ترحيل فاتورة المبيعات'), findsOneWidget);
    expect(find.text('ملخص الفاتورة'), findsOneWidget);
    await tester.tap(find.text('إضافة بند'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('sales-item-0-false-null')), matching: find.byType(TextField)), 'بن خام');
    await tester.pumpAndSettle();
    await tester.tap(find.text('بن خام').last);
    await tester.pumpAndSettle();
    expect(find.text('بن خام'), findsOneWidget);
    expect(find.text('kilogram'), findsOneWidget);
    await tester.tap(find.text('kilogram'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gram').last);
    await tester.pumpAndSettle();
    expect(find.text('gram'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sales-line-quantity-0')), '250');
    await tester.enterText(find.byKey(const Key('sales-line-price-0')), '0.04');
    await tester.pumpAndSettle();
    expect(find.text('10.00'), findsWidgets);
  });
}
