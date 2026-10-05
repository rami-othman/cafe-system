import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/controllers/inventory_cubit.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';

/// Stock Balances is the reference screen for warehouse-context correctness
/// (see the warehouse-context audit): selecting a warehouse must be the
/// value that actually reaches the API, and switching warehouses quickly
/// must never let a slower, superseded response win.
void main() {
  Dio fakeDio(
    Map<String, dynamic>? Function(String path, Map<String, dynamic> query)
    onPath,
  ) {
    final Dio dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final Map<String, dynamic>? data = onPath(
            options.path,
            Map<String, dynamic>.from(options.queryParameters),
          );
          if (data == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 500,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
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
    return dio;
  }

  Map<String, dynamic> balance(int warehouseId, String available) =>
      <String, dynamic>{
        'itemId': 1,
        'itemName': 'Cup lids',
        'warehouseId': warehouseId,
        'availableQuantity': available,
        'value': '0.00',
      };

  test(
    'selecting a warehouse sends that exact warehouseId to the API',
    () async {
      int? capturedWarehouseId = -1;
      int? capturedBranchId = -1;
      final Dio dio = fakeDio((String path, Map<String, dynamic> query) {
        if (path == 'inventory/balances') {
          capturedWarehouseId = query['warehouseId'] == null
              ? null
              : int.parse(query['warehouseId'].toString());
          capturedBranchId = query['branchId'] == null
              ? null
              : int.parse(query['branchId'].toString());
          return <String, dynamic>{
            'data': <Map<String, dynamic>>[balance(42, '100.000')],
          };
        }
        return <String, dynamic>{'data': <Map<String, dynamic>>[]};
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      await cubit.loadBalances(branchId: 7, warehouseId: 42);

      expect(capturedWarehouseId, 42);
      expect(capturedBranchId, 7);
      expect(cubit.state.balances.single.warehouseId, 42);
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNull);
    },
  );

  test(
    'switching from one warehouse id to another sends the new id, not the old one',
    () async {
      final List<int?> capturedWarehouseIds = <int?>[];
      final Dio dio = fakeDio((String path, Map<String, dynamic> query) {
        if (path == 'inventory/balances') {
          capturedWarehouseIds.add(
            query['warehouseId'] == null
                ? null
                : int.parse(query['warehouseId'].toString()),
          );
          return <String, dynamic>{'data': <Map<String, dynamic>>[]};
        }
        return <String, dynamic>{'data': <Map<String, dynamic>>[]};
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      // Bar (id 10), then Kitchen (id 20) - as a user clicking through the
      // dropdown would trigger.
      await cubit.loadBalances(warehouseId: 10);
      await cubit.loadBalances(warehouseId: 20);

      expect(capturedWarehouseIds, <int?>[10, 20]);
    },
  );

  test(
    'a slow response for an old warehouse selection never overwrites a newer one (latest-request-wins)',
    () async {
      final Dio dio = fakeDio((String path, Map<String, dynamic> query) {
        if (path != 'inventory/balances') {
          return <String, dynamic>{'data': <Map<String, dynamic>>[]};
        }
        // No artificial delay needed: both calls are fired without awaiting
        // the first, so their completion order is whatever the fake
        // interceptor resolves synchronously in - the guard must hold
        // regardless of which future the event loop happens to settle first.
        final int warehouseId = int.parse(query['warehouseId'].toString());
        return <String, dynamic>{
          'data': <Map<String, dynamic>>[
            balance(warehouseId, warehouseId == 10 ? '100.000' : '250.000'),
          ],
        };
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      // Fire "Bar" (10) then immediately "Kitchen" (20) without awaiting the
      // first - simulating a user clicking Bar then Kitchen before Bar's
      // response has come back.
      final Future<void> bar = cubit.loadBalances(warehouseId: 10);
      final Future<void> kitchen = cubit.loadBalances(warehouseId: 20);
      await Future.wait(<Future<void>>[bar, kitchen]);

      expect(cubit.state.balances.single.warehouseId, 20);
      expect(cubit.state.balances.single.available, '250.000');
      expect(cubit.state.loading, isFalse);
    },
  );

  test(
    'a secondary concurrent failure alongside the balances call does not leak an unhandled error',
    () async {
      final Dio dio = fakeDio((String path, Map<String, dynamic> query) {
        // Both the balances fetch and the concurrent warehouses() fetch fail.
        return null;
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      await cubit.loadBalances(warehouseId: 10);

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
  );
}
