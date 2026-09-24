import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/controllers/inventory_cubit.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';

/// Builds a [Dio] instance whose requests never touch the network. [onPath]
/// receives the request path and query parameters and returns the JSON body
/// to resolve with; return null to reject with a 500 response.
Dio _fakeDio(
  Map<String, dynamic>? Function(String path, Map<String, dynamic> query)
  onPath,
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

Map<String, dynamic> _movement(int id, String type) => <String, dynamic>{
  'id': id,
  'type': type,
  'quantityIn': '1.000',
  'quantityOut': '0.000',
  'unitCost': '1.0000',
  'totalCost': '1.00',
  'occurredAt': '2026-09-01T00:00:00Z',
};

void main() {
  group('InventoryCubit item-details tabs', () {
    test(
      'loadItemMovementHistory populates the full-history pagination fields, '
      'not the fixed 5-row recentMovements summary',
      () async {
        final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
          if (path == 'inventory/items/9/movements') {
            expect(query['page'], 2);
            return <String, dynamic>{
              'data': <Map<String, dynamic>>[_movement(6, 'stock_in')],
              'meta': <String, dynamic>{
                'currentPage': 2,
                'lastPage': 2,
                'total': 6,
              },
            };
          }
          return null;
        });
        final InventoryCubit cubit = InventoryCubit(
          repository: InventoryRepository(DioApiClient(dio: dio)),
        );

        await cubit.loadItemMovementHistory(9, page: 2);

        expect(cubit.state.itemMovementHistory, hasLength(1));
        expect(cubit.state.itemMovementHistory.first.type, 'stock_in');
        expect(cubit.state.itemMovementHistoryPage, 2);
        expect(cubit.state.itemMovementHistoryLastPage, 2);
        expect(cubit.state.itemMovementHistoryTotal, 6);
        expect(cubit.state.itemMovementHistoryLoading, isFalse);
        expect(cubit.state.error, isNull);
      },
    );

    test(
      'loadItemRecipeUsage populates recipe usage and marks it as loaded '
      'even when the item is unused (empty state, not an error)',
      () async {
        final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
          if (path == 'inventory/items/9/recipe-usage') {
            return <String, dynamic>{'data': <Map<String, dynamic>>[]};
          }
          return null;
        });
        final InventoryCubit cubit = InventoryCubit(
          repository: InventoryRepository(DioApiClient(dio: dio)),
        );

        await cubit.loadItemRecipeUsage(9);

        expect(cubit.state.itemRecipeUsage, isEmpty);
        expect(cubit.state.itemRecipeUsageLoaded, isTrue);
        expect(cubit.state.itemRecipeUsageLoading, isFalse);
        expect(cubit.state.error, isNull);
      },
    );

    test('loadItemPurchaseHistory populates paginated purchase entries', () async {
      final Dio dio = _fakeDio((String path, Map<String, dynamic> query) {
        if (path == 'inventory/items/9/purchase-history') {
          return <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'receiptId': 1,
                'receiptNumber': 'GRN-2026-000001',
                'receiptDate': '2026-09-01',
                'supplierName': 'Acme Supplies',
                'invoiceNumber': 'INV-1',
                'invoiceDate': '2026-08-30',
                'warehouseName': 'Main Warehouse',
                'quantity': '10.000',
                'unit': 'kg',
                'unitCost': '2.0000',
                'lineTotal': '20.00',
              },
            ],
            'meta': <String, dynamic>{
              'currentPage': 1,
              'lastPage': 1,
              'total': 1,
            },
          };
        }
        return null;
      });
      final InventoryCubit cubit = InventoryCubit(
        repository: InventoryRepository(DioApiClient(dio: dio)),
      );

      await cubit.loadItemPurchaseHistory(9);

      expect(cubit.state.itemPurchaseHistory, hasLength(1));
      expect(cubit.state.itemPurchaseHistory.first.supplierName, 'Acme Supplies');
      expect(cubit.state.itemPurchaseHistory.first.lineTotal, '20.00');
      expect(cubit.state.itemPurchaseHistoryTotal, 1);
      expect(cubit.state.error, isNull);
    });

    test(
      'a failed tab load surfaces an error without leaving loading stuck true',
      () async {
        final Dio dio = _fakeDio((_, _) => null);
        final InventoryCubit cubit = InventoryCubit(
          repository: InventoryRepository(DioApiClient(dio: dio)),
        );

        await cubit.loadItemMovementHistory(9);

        expect(cubit.state.itemMovementHistoryLoading, isFalse);
        expect(cubit.state.error, isNotNull);
      },
    );
  });
}
