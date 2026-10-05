import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/controllers/inventory_cubit.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';

/// Builds a [Dio] instance whose requests never touch the network. [onPath]
/// receives the request path and query parameters and returns the JSON body
/// to resolve with; return null to reject with a 500 response.
Dio _fakeDio(
  Map<String, dynamic>? Function(String path, Map<String, dynamic> query) onPath,
) {
  final Dio dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        final Map<String, dynamic> body = Map<String, dynamic>.from(
          options.queryParameters,
        );
        final Map<String, dynamic>? data = onPath(options.path, body);
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

Map<String, dynamic> _itemsEnvelope(List<Map<String, dynamic>> items, {int total = -1}) =>
    <String, dynamic>{
      'data': <String, dynamic>{
        'items': items,
        'meta': <String, dynamic>{
          'currentPage': 1,
          'lastPage': 1,
          'total': total < 0 ? items.length : total,
        },
        'filters': <String, dynamic>{'categories': <String>[]},
      },
    };

const Map<String, dynamic> _emptyList = <String, dynamic>{
  'data': <Map<String, dynamic>>[],
};

Map<String, dynamic> _item(int id, String name) => <String, dynamic>{
  'id': id,
  'displayName': name,
  'sku': 'SKU-$id',
  'itemType': 'stock_item',
  'stockStatus': 'active',
  'isActive': true,
};

void main() {
  group('InventoryCubit.loadItems', () {
    test('empty filtered result (out_of_stock, zero matches) ends loading with no error', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        if (path == 'inventory/items') {
          expect(query['stockStatus'], 'out_of_stock');
          return _itemsEnvelope(const <Map<String, dynamic>>[]);
        }
        return _emptyList;
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      await cubit.loadItems(stockStatus: 'out_of_stock');

      // A 200 response with an empty data set is a valid, successful result -
      // it must never be treated as an error.
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.itemsTotal, 0);
    });

    test('successful non-empty result populates items and pagination', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        if (path == 'inventory/items') {
          return _itemsEnvelope(<Map<String, dynamic>>[
            _item(1, 'Coffee Beans'),
            _item(2, 'Milk'),
          ]);
        }
        return _emptyList;
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      await cubit.loadItems();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.items, hasLength(2));
      expect(cubit.state.items.map((item) => item.name), <String>['Coffee Beans', 'Milk']);
    });

    test('backend error transitions from loading to an error state instead of spinning forever', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        if (path == 'inventory/items') return null; // 500
        return _emptyList;
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      await cubit.loadItems();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.items, isEmpty);
    });

    test('a second concurrent call failing alongside the primary call does not leak an unhandled error', () async {
      // Regression test: loadItems fires itemsPage/units/warehouses
      // concurrently. Awaiting them one at a time meant that once the first
      // await threw, the others were abandoned mid-flight; if they failed
      // too, their rejections had no listener and surfaced later as
      // uncaught exceptions (visible as unhandled errors in main.dart.js on
      // Flutter Web) even though the cubit's state had already settled.
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        if (path == 'inventory/items' || path == 'inventory/units') return null; // both 500
        return _emptyList;
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      await cubit.loadItems();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNotNull);

      // Pump the event queue: if any future's rejection were left unhandled
      // it would surface as a test failure at (or after) this point.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    test('rapid filter changes: latest-request-wins and loading always ends false', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        if (path != 'inventory/items') return _emptyList;
        if (query['stockStatus'] == null) {
          // The superseded "All" request resolves slower than the follow-up
          // filtered one; its stale result must never win.
          return _itemsEnvelope(<Map<String, dynamic>>[_item(1, 'Stale Item')]);
        }
        return _itemsEnvelope(const <Map<String, dynamic>>[]);
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );
      addTearDown(cubit.close);

      final Future<void> slowAll = cubit.loadItems();
      final Future<void> fastFiltered = cubit.loadItems(stockStatus: 'out_of_stock');
      await Future.wait(<Future<void>>[slowAll, fastFiltered]);

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.items, isEmpty);
    });

    test('loading always terminates across empty, non-empty, and error outcomes', () async {
      for (final Map<String, dynamic>? Function(String, Map<String, dynamic>) responder in <
          Map<String, dynamic>? Function(String, Map<String, dynamic>)>[
        (String path, Map<String, dynamic> q) =>
            path == 'inventory/items' ? _itemsEnvelope(const <Map<String, dynamic>>[]) : _emptyList,
        (String path, Map<String, dynamic> q) =>
            path == 'inventory/items' ? _itemsEnvelope(<Map<String, dynamic>>[_item(1, 'X')]) : _emptyList,
        (String path, Map<String, dynamic> q) => path == 'inventory/items' ? null : _emptyList,
      ]) {
        final Dio dio = _fakeDio(responder);
        final InventoryCubit cubit = InventoryCubit(
          repository: InventoryRepository(DioApiClient(dio: dio)),
        );
        await cubit.loadItems();
        expect(cubit.state.loading, isFalse);
        await cubit.close();
      }
    });
  });
}
