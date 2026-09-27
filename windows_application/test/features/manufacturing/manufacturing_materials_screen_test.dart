import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/controllers/inventory_cubit.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/manufacturing/views/manufacturing_materials_screen.dart';
import 'package:windows_application/features/operational_context/controllers/operational_branch_cubit.dart';
import 'package:windows_application/features/operational_context/repositories/fake_operational_branch_repository.dart';

Future<void> pumpMaterials(WidgetTester tester, InventoryCubit cubit) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final branch = OperationalBranchCubit(
    repository: const FakeOperationalBranchRepository(),
  );
  await branch.loadBranches();
  addTearDown(branch.close);
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: branch),
        ],
        child: const Scaffold(body: ManufacturingMaterialsScreen()),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'materials request is filtered before pagination and next page is reachable',
    (tester) async {
      final pages = <int>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            dynamic data = <dynamic>[];
            if (options.path == 'inventory/items') {
              expect(options.queryParameters['branchId'], 1);
              expect(
                options.queryParameters['types'],
                containsAll(<String>[
                  'raw_material',
                  'semi_finished_good',
                  'finished_good',
                  'packaging',
                ]),
              );
              final page = options.queryParameters['page'] as int;
              pages.add(page);
              data = <String, dynamic>{
                'items': <dynamic>[],
                'meta': <String, dynamic>{
                  'currentPage': page,
                  'lastPage': 2,
                  'total': 26,
                },
                'filters': <String, dynamic>{'categories': <String>[]},
              };
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'data': data},
              ),
            );
          },
        ),
      );
      final cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);
      await pumpMaterials(tester, cubit);
      await tester.pumpAndSettle();
      expect(find.text('الصفحة 1 من 2'), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(pages, <int>[1, 2]);
      expect(find.text('الصفحة 2 من 2'), findsOneWidget);
    },
  );

  testWidgets(
    'request failure is shown instead of an empty inventory message',
    (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Connection failed',
              ),
            );
          },
        ),
      );
      final cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);
      await pumpMaterials(tester, cubit);
      await tester.pumpAndSettle();
      expect(cubit.state.error, isNotNull);
      expect(find.text('لا توجد مواد مطابقة.'), findsNothing);
      expect(find.text(cubit.state.error!), findsOneWidget);
    },
  );
}
