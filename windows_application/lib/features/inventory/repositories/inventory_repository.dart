import '../../../core/network/dio_api_client.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../pos/models/json_helpers.dart';
import '../models/inventory_models.dart';

class InventoryRepository {
  const InventoryRepository(this._api);
  final DioApiClient _api;
  Future<List<InventoryUnit>> units() async => readMapList(
    await _api.get('inventory/units'),
  ).map(InventoryUnit.fromJson).toList(growable: false);
  Future<InventoryDashboard> dashboard({
    int? branchId,
    int? warehouseId,
    String? from,
    String? to,
    String? search,
    bool comparePrevious = true,
  }) async => InventoryDashboard.fromJson(
    Map<String, dynamic>.from(
      await _api.get(
            'inventory/dashboard',
            queryParameters: <String, dynamic>{
              if (branchId != null) 'branch_id': branchId,
              if (warehouseId != null) 'warehouse_id': warehouseId,
              if (from != null) 'from': from,
              if (to != null) 'to': to,
              if (search != null && search.isNotEmpty) 'search': search,
              // Query parameters arrive at Laravel as strings; `1`/`0` are
              // accepted by its boolean validator while `true`/`false` are not.
              'compare_previous': comparePrevious ? '1' : '0',
            },
          )
          as Map,
    ),
  );

  Future<List<InventoryItem>> items({
    String? search,
    String? type,
    String? category,
    String? status,
    bool activeOnly = false,
  }) async => (await itemsPage(
    search: search,
    type: type,
    category: category,
    status: status ?? (activeOnly ? 'active' : null),
    perPage: 100,
  )).items;

  Future<InventoryItemsPage> itemsPage({
    String? search,
    String? type,
    String? category,
    String? status,
    String? stockStatus,
    int page = 1,
    int perPage = 25,
  }) async => InventoryItemsPage.fromJson(
    Map<String, dynamic>.from(
      await _api.get(
            'inventory/items',
            queryParameters: <String, dynamic>{
              'page': page,
              'perPage': perPage,
              if (search != null && search.isNotEmpty) 'search': search,
              if (type != null && type.isNotEmpty) 'type': type,
              if (category != null && category.isNotEmpty) 'category': category,
              if (status != null && status.isNotEmpty) 'status': status,
              if (stockStatus != null && stockStatus.isNotEmpty)
                'stockStatus': stockStatus,
            },
          )
          as Map,
    ),
  );
  Future<InventoryItem> item(int id) async => InventoryItem.fromJson(
    Map<String, dynamic>.from(await _api.get('inventory/items/$id') as Map),
  );

  Future<List<InventoryItem>> conversionItems({String? search}) async =>
      readMapList(
        await _api.get(
          'inventory/conversion-items',
          queryParameters: <String, dynamic>{
            if (search != null && search.isNotEmpty) 'search': search,
          },
        ),
      ).map(InventoryItem.fromJson).toList(growable: false);

  Future<List<InventoryItemUnitConversion>> unitConversions(int itemId) async =>
      readMapList(
        await _api.get('inventory/items/$itemId/unit-conversions'),
      ).map(InventoryItemUnitConversion.fromJson).toList(growable: false);

  Future<List<InventoryMovement>> itemMovements(int id) async => readMapList(
    await _api.get('inventory/items/$id/movements'),
  ).map(InventoryMovement.fromJson).toList(growable: false);

  Future<List<InventoryBalance>> balances({
    int? warehouseId,
    String? search,
    String? stockStatus,
  }) async => readMapList(
    await _api.get(
      'inventory/balances',
      queryParameters: <String, dynamic>{
        'perPage': 100,
        if (warehouseId != null) 'warehouseId': warehouseId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (stockStatus == 'low') 'lowStock': 'true',
        if (stockStatus == 'out') 'outOfStock': 'true',
      },
    ),
  ).map(InventoryBalance.fromJson).toList(growable: false);
  Future<List<InventoryMovement>> movements({
    int? warehouseId,
    int? itemId,
    String? type,
  }) async => readMapList(
    await _api.get(
      'inventory/movements',
      queryParameters: <String, dynamic>{
        'perPage': 100,
        if (warehouseId != null) 'warehouseId': warehouseId,
        if (itemId != null) 'itemId': itemId,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    ),
  ).map(InventoryMovement.fromJson).toList(growable: false);
  Future<List<InventoryCount>> counts() async => readMapList(
    await _api.get(
      'inventory/counts',
      queryParameters: const <String, dynamic>{'perPage': 100},
    ),
  ).map(InventoryCount.fromJson).toList(growable: false);
  Future<InventoryCount> count(int id) async => InventoryCount.fromJson(
    Map<String, dynamic>.from(await _api.get('inventory/counts/$id') as Map),
  );
  Future<List<WarehouseLocation>> warehouses() async =>
      readMapList(
            await _api.get(
              'warehouses',
              queryParameters: const <String, dynamic>{
                'perPage': 100,
                'status': 'active',
              },
            ),
          )
          .map(WarehouseLocation.fromJson)
          .where((WarehouseLocation warehouse) => !warehouse.isLegacy)
          .toList(growable: false);
  Future<void> saveItem(Map<String, dynamic> payload, {int? id}) async {
    if (id == null) {
      await _api.post('inventory/items', data: payload);
    } else {
      await _api.patch('inventory/items/$id', data: payload);
    }
  }

  Future<void> saveUnitConversion(
    int itemId,
    Map<String, dynamic> payload, {
    int? id,
  }) async {
    if (id == null) {
      await _api.post(
        'inventory/items/$itemId/unit-conversions',
        data: payload,
      );
    } else {
      await _api.patch(
        'inventory/items/$itemId/unit-conversions/$id',
        data: payload,
      );
    }
  }

  Future<void> postMovement(Map<String, dynamic> payload) async {
    await _api.post('inventory/movements', data: payload);
  }

  Future<void> createCount(Map<String, dynamic> payload) async {
    await _api.post('inventory/counts', data: payload);
  }

  Future<void> countAction(int id, String action) async {
    await _api.post('inventory/counts/$id/$action');
  }

  Future<void> saveCountLine(int countId, Map<String, dynamic> payload) async {
    await _api.put('inventory/counts/$countId/lines', data: payload);
  }
}
