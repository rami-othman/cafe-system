import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/controllers/inventory_cubit.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/inventory/transfers/views/transfers_screen.dart';
import 'package:windows_application/shared/widgets/app_button.dart';

void main() {
  testWidgets(
    'create-transfer dialog can read InventoryCubit when the provider is scoped inside a ShellRoute (not around MaterialApp.router)',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final Dio dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
            final dynamic data = switch (options.path) {
              'inventory/transfers' => <String, dynamic>{
                'data': <dynamic>[],
                'meta': <String, dynamic>{'currentPage': 1, 'lastPage': 1, 'total': 0, 'perPage': 25, 'kpis': <String, dynamic>{}},
              },
              'warehouses' => <String, dynamic>{
                'data': <Map<String, dynamic>>[
                  <String, dynamic>{'id': 1, 'name': 'Central', 'displayName': 'Central Warehouse', 'code': 'MAIN', 'type': 'central', 'typeLabel': 'Central', 'isActive': true, 'isLegacy': false},
                  <String, dynamic>{'id': 2, 'name': 'Bar', 'displayName': 'Bar', 'code': 'BAR', 'type': 'bar', 'typeLabel': 'Bar', 'isActive': true, 'isLegacy': false},
                ],
              },
              _ => <String, dynamic>{'data': <dynamic>[]},
            };
            handler.resolve(Response<dynamic>(requestOptions: options, statusCode: 200, data: data));
          },
        ),
      );

      final InventoryCubit inventoryCubit = InventoryCubit(repository: InventoryRepository(DioApiClient(dio: dio)));
      addTearDown(inventoryCubit.close);

      // Mirrors app_router.dart's ShellRoute: BlocProvider<InventoryCubit> is
      // created inside the shell builder (below the router's root Navigator),
      // not wrapped around MaterialApp.router. showDialog's default
      // useRootNavigator: true inserts routes on that outer root Navigator,
      // so a dialog that isn't explicitly re-provided the cubit cannot read
      // it there — this is the exact shape that produced the
      // ProviderNotFoundException opening the create-transfer dialog.
      final GoRouter router = GoRouter(
        initialLocation: '/inventory/transfers',
        routes: <RouteBase>[
          ShellRoute(
            builder: (BuildContext context, GoRouterState state, Widget child) =>
                BlocProvider<InventoryCubit>.value(value: inventoryCubit, child: child),
            routes: <RouteBase>[
              GoRoute(
                path: '/inventory/transfers',
                builder: (_, _) => const Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(body: TransfersScreen()),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppButton, 'إنشاء تحويل'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}
