import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/sales/controllers/sales_cubit.dart';
import 'package:windows_application/features/sales/models/sales_models.dart';
import 'package:windows_application/features/sales/repositories/sales_repository.dart';
import 'package:windows_application/features/sales/views/sales_screens.dart';

void main() {
  test('Phase 1 invoice action model never enables posting', () {
    final SalesInvoice invoice = SalesInvoice.fromJson(<String, dynamic>{
      'id': 1, 'invoiceNumber': 'SI-2026-000001', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'invoiceDate': '2026-09-12', 'status': 'draft', 'subtotal': '10.00', 'taxTotal': '0.80', 'total': '10.80', 'allowedActions': <String, dynamic>{'canView': true, 'canEdit': true, 'canCancel': true, 'canPost': false},
    });
    expect(invoice.canEdit, isTrue);
    expect(invoice.allowedActions['canPost'], isFalse);
  });

  testWidgets('Sales Center renders Arabic draft KPIs and no post action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1/'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) => handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{'data': <Map<String, dynamic>>[<String, dynamic>{'id': 1, 'invoiceNumber': 'SI-2026-000001', 'customerId': 2, 'customerName': 'Damascus Tech', 'branchId': 3, 'branchName': 'Downtown', 'invoiceDate': '2026-09-12', 'status': 'draft', 'subtotal': '10.00', 'taxTotal': '0.80', 'total': '10.80', 'allowedActions': <String, dynamic>{'canView': true, 'canEdit': true, 'canCancel': true, 'canPost': false}}], 'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 1}, 'summary': <String, dynamic>{'draftInvoiceCount': 1, 'draftInvoiceTotal': '10.80'}}))));
    final SalesCubit cubit = SalesCubit(repository: SalesRepository(DioApiClient(dio: dio)));
    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: BlocProvider<SalesCubit>.value(value: cubit, child: const SalesCenterScreen())))));
    await tester.pumpAndSettle();
    expect(find.text('المبيعات'), findsWidgets);
    expect(find.text('إجمالي الفواتير المسودة'), findsOneWidget);
    expect(find.text('SI-2026-000001'), findsOneWidget);
    expect(find.textContaining('ترحيل'), findsNothing);
  });
}
