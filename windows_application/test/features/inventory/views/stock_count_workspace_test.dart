import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/controllers/inventory_cubit.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/inventory/views/inventory_screens.dart';

void main() {
  testWidgets('workspace autosaves a valid counted quantity at desktop width', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _CountApi api = _CountApi();
    final InventoryCubit cubit = InventoryCubit(
      repository: InventoryRepository(DioApiClient(dio: api.dio)),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<InventoryCubit>.value(
          value: cubit,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: InventoryCountDetailsScreen(countId: 81)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SC-00081'), findsWidgets);
    final Finder quantity = find.byType(TextFormField).first;
    await tester.enterText(quantity, '8.500');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    expect(api.savedQuantities, <String>['8.500']);
    expect(find.text('تم الحفظ تلقائياً.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitted workspace keeps counted quantities read-only', (
    WidgetTester tester,
  ) async {
    final _CountApi api = _CountApi(status: 'submitted');
    final InventoryCubit cubit = InventoryCubit(
      repository: InventoryRepository(DioApiClient(dio: api.dio)),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<InventoryCubit>.value(
          value: cubit,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: InventoryCountDetailsScreen(countId: 81)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      isFalse,
    );
    expect(find.text('إرسال للمراجعة'), findsNothing);
  });
}

class _CountApi {
  _CountApi({this.status = 'in_progress'}) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (options.method == 'PUT' && options.path.endsWith('/lines')) {
            savedQuantities.add(
              (options.data as Map)['countedQuantity'] as String,
            );
            counted = (options.data as Map)['countedQuantity'] as String;
          }
          final dynamic responseData = options.path == 'inventory/items'
              ? <String, dynamic>{
                  'data': <dynamic>[],
                  'meta': <String, dynamic>{
                    'currentPage': 1,
                    'lastPage': 1,
                    'total': 0,
                  },
                }
              : <String, dynamic>{'data': _payload(status, counted)};
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: responseData,
            ),
          );
        },
      ),
    );
  }

  final Dio dio = Dio();
  final String status;
  String counted = '0.000';
  final List<String> savedQuantities = <String>[];
}

Map<String, dynamic> _payload(String status, String counted) =>
    <String, dynamic>{
      'id': 81,
      'number': 'SC-00081',
      'warehouseId': 7,
      'warehouseName': 'المستودع الرئيسي',
      'countDate': '2026-08-26',
      'countType': 'full',
      'status': status,
      'totalItems': 1,
      'countedItems': counted == '0.000' ? 0 : 1,
      'varianceItems': counted == '0.000' ? 0 : 1,
      'varianceValue': counted == '0.000' ? '0.00' : '-3.00',
      'createdByName': 'مدير المخزون',
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'itemId': 10,
          'itemNameAr': 'بن أرابيكا',
          'itemNameEn': 'Arabica beans',
          'sku': 'RM-1001',
          'unit': 'kilogram',
          'expectedQuantity': '10.000',
          'countedQuantity': counted,
          'varianceQuantity': counted == '0.000' ? '0.000' : '-1.500',
          'averageUnitCost': '2.0000',
          'varianceValue': counted == '0.000' ? '0.00' : '-3.00',
          'isCounted': counted != '0.000',
          'reason': null,
        },
      ],
    };
