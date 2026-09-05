import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/controllers/inventory_cubit.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/inventory/views/inventory_screens.dart';
import 'package:windows_application/features/operational_context/controllers/operational_branch_cubit.dart';
import 'package:windows_application/features/operational_context/repositories/operational_branch_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  testWidgets('stock counts list renders at desktop width without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final Dio dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final dynamic data = switch ((options.method, options.path)) {
            ('POST', 'inventory/counts') => <String, dynamic>{
              'data': _countPayload(1040),
            },
            (_, 'inventory/counts/1040') => <String, dynamic>{
              'data': _countPayload(1040),
            },
            (_, 'inventory/counts') => <String, dynamic>{
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1038,
                  'number': 'SC-01038',
                  'warehouseId': 7,
                  'warehouseName': 'المستودع الرئيسي',
                  'countDate': '2026-08-19',
                  'countType': 'full',
                  'status': 'draft',
                  'totalItems': 8,
                  'countedItems': 5,
                  'createdByName': 'مدير الفرع',
                },
              ],
              'meta': <String, dynamic>{
                'currentPage': 1,
                'lastPage': 1,
                'total': 1,
                'summary': <String, dynamic>{
                  'drafts': 1,
                  'inProgress': 0,
                  'submitted': 0,
                  'approved': 0,
                },
                'filterOptions': <String, dynamic>{
                  'createdBy': <Map<String, dynamic>>[
                    <String, dynamic>{'id': 4, 'name': 'مدير الفرع'},
                  ],
                },
              },
            },
            (_, 'warehouses') => <String, dynamic>{
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 7,
                  'name': 'المستودع الرئيسي',
                  'displayName': 'المستودع الرئيسي',
                  'code': 'MAIN',
                  'type': 'central',
                  'typeLabel': 'رئيسي',
                  'isActive': true,
                  'isLegacy': false,
                },
              ],
            },
            (_, 'inventory/items') => <String, dynamic>{
              'data': <Map<String, dynamic>>[],
              'meta': <String, dynamic>{
                'currentPage': 1,
                'lastPage': 1,
                'total': 0,
              },
            },
            _ => <String, dynamic>{'data': <dynamic>[]},
          };
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: data,
            ),
          );
        },
      ),
    );
    final InventoryCubit inventoryCubit = InventoryCubit(
      repository: InventoryRepository(DioApiClient(dio: dio)),
    );
    final OperationalBranchCubit branchCubit = OperationalBranchCubit(
      repository: const _EmptyBranchReader(),
    );
    addTearDown(inventoryCubit.close);
    addTearDown(branchCubit.close);

    final GoRouter router = GoRouter(
      initialLocation: '/inventory/counts',
      routes: <RouteBase>[
        GoRoute(
          path: '/inventory/counts',
          builder: (_, _) => const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: InventoryCountsScreen()),
          ),
        ),
        GoRoute(
          path: '/inventory/counts/:id',
          builder: (_, GoRouterState state) =>
              Scaffold(body: Text('workspace ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<InventoryCubit>.value(value: inventoryCubit),
          BlocProvider<OperationalBranchCubit>.value(value: branchCubit),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الجرد المخزني'), findsOneWidget);
    expect(find.text('SC-01038'), findsOneWidget);
    expect(find.text('العناصر المجرودة / الإجمالي'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'بدء جرد جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المستودع الرئيسي').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'بدء الجرد'));
    await tester.pumpAndSettle();

    expect(find.text('workspace 1040'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _countPayload(int id) => <String, dynamic>{
  'id': id,
  'number': 'SC-0$id',
  'warehouseId': 7,
  'warehouseName': 'المستودع الرئيسي',
  'countDate': '2026-08-19',
  'countType': 'full',
  'status': 'draft',
  'totalItems': 8,
  'countedItems': 0,
  'createdByName': 'مدير الفرع',
};

class _EmptyBranchReader implements OperationalBranchReader {
  const _EmptyBranchReader();

  @override
  Future<List<Branch>> getActiveBranches() async => const <Branch>[];
}
