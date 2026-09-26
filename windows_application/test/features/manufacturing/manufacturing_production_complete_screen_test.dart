import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/manufacturing/controllers/manufacturing_production_cubit.dart';
import 'package:windows_application/features/manufacturing/repositories/manufacturing_repository.dart';
import 'package:windows_application/features/manufacturing/views/manufacturing_production_complete_screen.dart';
import 'package:windows_application/features/manufacturing/widgets/manufacturing_cost_summary.dart';
import 'package:windows_application/features/manufacturing/models/manufacturing_production_models.dart';

void main() {
  testWidgets(
    'completion shows material names and sends operating costs, rejects zero output',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? sent;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST') {
              sent = Map<String, dynamic>.from(options.data as Map);
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'id': 1,
                    'recipeId': 1,
                    'warehouseId': 1,
                    'qty': '4.000',
                    'unit': 'piece',
                    'consumption': [
                      {
                        'materialId': 7,
                        'name': 'طحين',
                        'planned': '2.000',
                        'actual': '2.000',
                        'unit': 'kilogram',
                      },
                    ],
                  },
                },
              ),
            );
          },
        ),
      );
      final cubit = ManufacturingProductionCubit(
        repository: ManufacturingRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const Scaffold(
              body: ManufacturingProductionCompleteScreen(draftId: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('طحين (kilogram) — مخطط 2.000'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), '0');
      await tester.ensureVisible(find.text('إتمام الإنتاج').last);
      await tester.tap(find.text('إتمام الإنتاج').last);
      await tester.pumpAndSettle();
      expect(sent, isNull);
      await tester.enterText(find.byType(TextFormField).at(0), '3');
      await tester.enterText(find.byType(TextFormField).at(4), '7.00');
      await tester.enterText(find.byType(TextFormField).at(5), '3.00');
      await tester.ensureVisible(find.text('إتمام الإنتاج').last);
      await tester.tap(find.text('إتمام الإنتاج').last);
      await tester.pumpAndSettle();
      expect(sent?['actualQty'], '3');
      expect(sent?['consumption'], [
        {'materialId': 7, 'actual': '2.000'},
      ]);
      expect(sent?['additionalCosts'], [
        {'type': 'أجور', 'amount': '7.00'},
        {'type': 'كهرباء', 'amount': '3.00'},
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cost summary uses server material and full unit costs', (
    tester,
  ) async {
    final order = ManufacturingProductionOrder.fromJson({
      'id': 'PR-1',
      'unit': 'piece',
      'actualCost': '20.00',
      'actualUnitCost': '6.6667',
      'additionalCostTotal': '10.00',
      'fullCost': '30.00',
      'fullUnitCost': '10.0000',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ManufacturingCostSummary(order: order)),
      ),
    );
    expect(find.text('6.6667'), findsOneWidget);
    expect(find.text('30.00'), findsOneWidget);
    expect(find.text('10.0000'), findsOneWidget);
  });
}
