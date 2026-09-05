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
    String? movementType,
    int? trendDays,
    bool comparePrevious = true,
  }) async => InventoryDashboard.fromJson(
    Map<String, dynamic>.from(
      await _api.get(
            'inventory/dashboard',
            queryParameters: <String, dynamic>{
              if (branchId case final int value) 'branch_id': value,
              if (warehouseId case final int value) 'warehouse_id': value,
              if (from case final String value) 'from': value,
              if (to case final String value) 'to': value,
              if (search != null && search.isNotEmpty) 'search': search,
              if (movementType != null && movementType.isNotEmpty)
                'movement_type': movementType,
              if (trendDays case final int value) 'trend_days': value,
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
    int? warehouseId,
    bool activeOnly = false,
  }) async => (await itemsPage(
    search: search,
    type: type,
    category: category,
    status: status ?? (activeOnly ? 'active' : null),
    warehouseId: warehouseId,
    perPage: 100,
  )).items;

  Future<InventoryItemsPage> itemsPage({
    String? search,
    String? type,
    String? category,
    String? status,
    String? stockStatus,
    int? warehouseId,
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
              if (warehouseId case final int value) 'warehouseId': value,
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
        if (warehouseId case final int value) 'warehouseId': value,
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
  }) async => (await movementsPage(
    warehouseId: warehouseId,
    itemId: itemId,
    type: type,
    perPage: 100,
  )).movements;

  Future<InventoryMovementsPage> movementsPage({
    int? warehouseId,
    int? itemId,
    String? type,
    int page = 1,
    int perPage = 5,
  }) async => InventoryMovementsPage.fromJson(
    Map<String, dynamic>.from(
      await _api.getEnvelope(
            'inventory/movements',
            queryParameters: <String, dynamic>{
              'page': page,
              'perPage': perPage,
              if (warehouseId case final int value) 'warehouseId': value,
              if (itemId case final int value) 'itemId': value,
              if (type != null && type.isNotEmpty) 'type': type,
            },
          )
          as Map,
    ),
  );
  Future<List<InventoryCount>> counts({
    String? status,
    int? warehouseId,
    String? countType,
  }) async => (await countsPage(
    status: status,
    warehouseId: warehouseId,
    countType: countType,
    perPage: 100,
  )).items;

  Future<InventoryCountsPage> countsPage({
    String? status,
    int? warehouseId,
    String? countType,
    String? source,
    int? createdBy,
    String? from,
    String? to,
    int page = 1,
    int perPage = 10,
  }) async => InventoryCountsPage.fromJson(
    Map<String, dynamic>.from(
      await _api.getEnvelope(
            'inventory/counts',
            queryParameters: <String, dynamic>{
              'page': page,
              'perPage': perPage,
              if (status != null && status.isNotEmpty) 'status': status,
              if (warehouseId case final int value) 'warehouseId': value,
              if (countType != null && countType.isNotEmpty)
                'countType': countType,
              if (source != null && source.isNotEmpty) 'source': source,
              if (createdBy case final int value) 'createdBy': value,
              if (from != null && from.isNotEmpty) 'from': from,
              if (to != null && to.isNotEmpty) 'to': to,
            },
          )
          as Map,
    ),
  );
  Future<InventoryCount> count(int id) async => InventoryCount.fromJson(
    Map<String, dynamic>.from(await _api.get('inventory/counts/$id') as Map),
  );
  Future<List<WarehouseLocation>> warehouses({
    bool accessibleForStockCount = false,
  }) async =>
      readMapList(
            await _api.get(
              'warehouses',
              queryParameters: <String, dynamic>{
                'perPage': 100,
                'status': 'active',
                if (accessibleForStockCount) 'forStockCount': true,
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

  Future<InventoryCount> createCount(Map<String, dynamic> payload) async =>
      InventoryCount.fromJson(
        Map<String, dynamic>.from(
          await _api.post('inventory/counts', data: payload) as Map,
        ),
      );

  Future<void> countAction(int id, String action) async {
    await _api.post('inventory/counts/$id/$action');
  }

  Future<void> saveCountLine(int countId, Map<String, dynamic> payload) async {
    await _api.put('inventory/counts/$countId/lines', data: payload);
  }

  Future<void> reviewCountLine(
    int countId,
    int itemId,
    Map<String, dynamic> payload,
  ) async {
    await _api.post('inventory/counts/$countId/lines/$itemId/review', data: payload);
  }

  Future<List<BarCheckTemplate>> barCheckTemplates() async => readMapList(await _api.get('inventory/bar-check-templates')).map(BarCheckTemplate.fromJson).toList(growable: false);
  Future<BarCheckTemplate> barCheckTemplate(int id) async => BarCheckTemplate.fromJson(Map<String, dynamic>.from(await _api.get('inventory/bar-check-templates/$id') as Map));
  Future<BarCheckTemplate> createBarCheckTemplate(Map<String, dynamic> payload) async => BarCheckTemplate.fromJson(Map<String, dynamic>.from(await _api.post('inventory/bar-check-templates', data: payload) as Map));
  Future<BarCheckTemplate> updateBarCheckTemplate(int id, Map<String, dynamic> payload) async => BarCheckTemplate.fromJson(Map<String, dynamic>.from(await _api.patch('inventory/bar-check-templates/$id', data: payload) as Map));
  Future<WarehouseTransfersPage> transfersPage({String? search, String? status, int? sourceWarehouseId, int? destinationWarehouseId, int page = 1, int perPage = 25}) async => WarehouseTransfersPage.fromJson(Map<String, dynamic>.from(await _api.getEnvelope('inventory/transfers', queryParameters: <String, dynamic>{'page': page, 'perPage': perPage, if (search != null && search.isNotEmpty) 'search': search, if (status != null && status.isNotEmpty) 'status': status, if (sourceWarehouseId != null) 'sourceWarehouseId': sourceWarehouseId, if (destinationWarehouseId != null) 'destinationWarehouseId': destinationWarehouseId}) as Map));
  Future<List<WarehouseTransfer>> transfers() async => (await transfersPage(perPage: 100)).items;
  Future<WarehouseTransfer> transfer(int id) async => WarehouseTransfer.fromJson(Map<String, dynamic>.from(await _api.get('inventory/transfers/$id') as Map));
  Future<WarehouseTransfer> createTransfer(Map<String, dynamic> payload) async => WarehouseTransfer.fromJson(Map<String, dynamic>.from(await _api.post('inventory/transfers', data: payload) as Map));
  Future<WarehouseTransfer> updateTransfer(int id, Map<String, dynamic> payload) async => WarehouseTransfer.fromJson(Map<String, dynamic>.from(await _api.patch('inventory/transfers/$id', data: payload) as Map));
  Future<WarehouseTransfer> transferAction(
    int id,
    String action, [
    Map<String, dynamic>? payload,
  ]) async => WarehouseTransfer.fromJson(Map<String, dynamic>.from(
    await _api.post('inventory/transfers/$id/$action', data: payload) as Map,
  ));
  Future<WarehouseTransfer> receiveTransfer(int id, Map<String, dynamic> payload) async => WarehouseTransfer.fromJson(Map<String, dynamic>.from(await _api.post('inventory/transfers/$id/receive', data: payload) as Map));
}
