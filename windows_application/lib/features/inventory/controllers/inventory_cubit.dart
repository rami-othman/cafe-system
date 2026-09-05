import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../models/inventory_models.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit({required this.repository}) : super(const InventoryState());
  final InventoryRepository repository;

  Future<void> loadDashboard({
    int? branchId,
    int? warehouseId,
    String? from,
    String? to,
    String? search,
    String? movementType,
    int? trendDays,
  }) async {
    emit(
      state.copyWith(
        dashboardLoading: true,
        dashboardPermissionDenied: false,
        clearDashboardError: true,
      ),
    );
    try {
      final InventoryDashboard dashboard = await repository.dashboard(
        branchId: branchId,
        warehouseId: warehouseId,
        from: from,
        to: to,
        search: search,
        movementType: movementType,
        trendDays: trendDays,
      );
      emit(
        state.copyWith(
          dashboard: dashboard,
          dashboardPermissionDenied: false,
          clearDashboardError: true,
        ),
      );
    } catch (error) {
      final ApiException? apiError = error is ApiException ? error : null;
      emit(
        state.copyWith(
          dashboardError: apiError?.message ?? error.toString(),
          dashboardPermissionDenied:
              apiError?.statusCode == 401 || apiError?.statusCode == 403,
        ),
      );
    } finally {
      emit(state.copyWith(dashboardLoading: false));
    }
  }

  Future<void> loadItems({
    String? search,
    String? type,
    String? category,
    String? status,
    String? stockStatus,
    int? warehouseId,
    int page = 1,
  }) => _load(() async {
    final Future<InventoryItemsPage> itemsFuture = repository.itemsPage(
      search: search,
      type: type,
      category: category,
      status: status,
      stockStatus: stockStatus,
      warehouseId: warehouseId,
      page: page,
    );
    final Future<List<InventoryUnit>> unitsFuture = repository.units();
    final Future<List<WarehouseLocation>> warehousesFuture = repository
        .warehouses();
    final InventoryItemsPage result = await itemsFuture;
    final List<InventoryUnit> units = await unitsFuture;
    final List<WarehouseLocation> warehouses = await warehousesFuture;
    emit(
      state.copyWith(
        items: result.items,
        units: units,
        itemsPage: result.currentPage,
        itemsLastPage: result.lastPage,
        itemsTotal: result.total,
        itemCategories: result.categories,
        warehouses: warehouses,
        clearError: true,
      ),
    );
  });
  Future<void> loadBalances({
    int? warehouseId,
    String? search,
    String? stockStatus,
  }) => _load(() async {
    final Future<List<InventoryBalance>> balancesFuture = repository.balances(
      warehouseId: warehouseId,
      search: search,
      stockStatus: stockStatus,
    );
    final Future<List<WarehouseLocation>> warehousesFuture = repository
        .warehouses();
    final List<InventoryBalance> balances = await balancesFuture;
    final List<WarehouseLocation> warehouses = await warehousesFuture;
    emit(
      state.copyWith(
        balances: balances,
        warehouses: warehouses,
        clearError: true,
      ),
    );
  });
  Future<void> loadMovements({
    int? warehouseId,
    int? itemId,
    String? type,
    int page = 1,
  }) => _load(() async {
    final Future<InventoryMovementsPage> movementsFuture = repository
        .movementsPage(
          warehouseId: warehouseId,
          itemId: itemId,
          type: type,
          page: page,
        );
    final Future<List<InventoryItem>> itemsFuture = repository.items(
      activeOnly: true,
    );
    final Future<List<WarehouseLocation>> warehousesFuture = repository
        .warehouses();
    final InventoryMovementsPage result = await movementsFuture;
    final List<InventoryItem> items = await itemsFuture;
    final List<WarehouseLocation> warehouses = await warehousesFuture;
    emit(
      state.copyWith(
        movements: result.movements,
        movementsPage: result.currentPage,
        movementsLastPage: result.lastPage,
        movementsTotal: result.total,
        items: items,
        warehouses: warehouses,
        clearError: true,
      ),
    );
  });
  Future<void> loadItemDetails(int id) => _load(() async {
    final InventoryItem item = await repository.item(id);
    emit(
      state.copyWith(
        selectedItem: item,
        itemMovements: item.recentMovements,
        clearError: true,
      ),
    );
  });
  Future<void> loadUnitConversions({int? itemId}) => _load(() async {
    final Future<List<InventoryItem>> itemsFuture = repository
        .conversionItems();
    final Future<List<InventoryUnit>> unitsFuture = repository.units();
    final List<InventoryItem> items = await itemsFuture;
    final List<InventoryUnit> units = await unitsFuture;
    final int? selected =
        itemId ??
        state.selectedConversionItemId ??
        (items.isEmpty ? null : items.first.id);
    final List<InventoryItemUnitConversion> conversions = selected == null
        ? const <InventoryItemUnitConversion>[]
        : await repository.unitConversions(selected);
    emit(
      state.copyWith(
        conversionItems: items,
        conversions: conversions,
        selectedConversionItemId: selected,
        units: units,
        clearError: true,
      ),
    );
  });
  Future<void> loadCounts({
    String? status,
    int? warehouseId,
    String? countType,
    String? source,
    int? createdBy,
    String? from,
    String? to,
    int page = 1,
  }) => _load(() async {
    final Future<InventoryCountsPage> countsFuture = repository.countsPage(
      status: status,
      warehouseId: warehouseId,
      countType: countType,
      source: source,
      createdBy: createdBy,
      from: from,
      to: to,
      page: page,
    );
    final Future<List<WarehouseLocation>> warehousesFuture = repository
        .warehouses(accessibleForStockCount: true);
    final InventoryCountsPage counts = await countsFuture;
    final List<WarehouseLocation> warehouses = await warehousesFuture;
    emit(
      state.copyWith(
        counts: counts.items,
        countsPage: counts.currentPage,
        countsLastPage: counts.lastPage,
        countsTotal: counts.total,
        countSummary: counts.summary,
        countCreators: counts.creators,
        warehouses: warehouses,
        clearError: true,
      ),
    );
  });
  Future<void> loadCountDetails(int id) => _load(() async {
    final InventoryCount count = await repository.count(id);
    emit(state.copyWith(selectedCount: count, clearError: true));
  });
  Future<bool> saveItem(Map<String, dynamic> payload, {int? id}) =>
      _save(() async {
        await repository.saveItem(payload, id: id);
      });
  Future<bool> saveUnitConversion(
    int itemId,
    Map<String, dynamic> payload, {
    int? id,
  }) => _save(() async {
    await repository.saveUnitConversion(itemId, payload, id: id);
    await loadUnitConversions(itemId: itemId);
  });
  Future<bool> postMovement(Map<String, dynamic> payload) => _save(() async {
    await repository.postMovement(payload);
    await loadMovements();
  });
  Future<bool> createCount(Map<String, dynamic> payload) => _save(() async {
    final InventoryCount count = await repository.createCount(payload);
    await loadCounts();
    await loadCountDetails(count.id);
  });
  Future<bool> countAction(int id, String action) => _save(() async {
    await repository.countAction(id, action);
    await loadCounts();
    await loadCountDetails(id);
  });
  Future<bool> saveCountLine(int countId, Map<String, dynamic> payload) async {
    emit(
      state.copyWith(
        saving: true,
        countLineSaveStatus: InventoryCountLineSaveStatus.saving,
        clearError: true,
        clearCountLineSaveError: true,
      ),
    );
    try {
      await repository.saveCountLine(countId, payload);
      final InventoryCount count = await repository.count(countId);
      emit(
        state.copyWith(
          selectedCount: count,
          countLineSaveStatus: InventoryCountLineSaveStatus.saved,
          clearError: true,
          clearCountLineSaveError: true,
        ),
      );
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          error: error.toString(),
          countLineSaveStatus: InventoryCountLineSaveStatus.failed,
          countLineSaveError: error.toString(),
        ),
      );
      return false;
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  Future<bool> reviewCountLine(
    int countId,
    int itemId,
    Map<String, dynamic> payload,
  ) => _save(() async {
    await repository.reviewCountLine(countId, itemId, payload);
    await loadCountDetails(countId);
  });

  Future<void> loadBarCheckTemplates() => _load(() async {
    final results = await Future.wait(<Future<dynamic>>[
      repository.barCheckTemplates(), repository.warehouses(), repository.items(activeOnly: true),
    ]);
    emit(state.copyWith(barCheckTemplates: results[0] as List<BarCheckTemplate>, warehouses: results[1] as List<WarehouseLocation>, items: results[2] as List<InventoryItem>, clearError: true));
  });
  Future<void> loadBarCheckTemplate(int id) => _load(() async {
    final template = await repository.barCheckTemplate(id);
    emit(state.copyWith(selectedBarCheckTemplate: template, clearError: true));
  });
  Future<void> loadBarCheckTemplateItems(int warehouseId) => _load(() async {
    final items = await repository.items(
      activeOnly: true,
      warehouseId: warehouseId,
    );
    emit(state.copyWith(items: items, clearError: true));
  });
  Future<bool> createBarCheckTemplate(Map<String, dynamic> payload) => _save(() async {
    final template = await repository.createBarCheckTemplate(payload);
    emit(state.copyWith(selectedBarCheckTemplate: template));
    await loadBarCheckTemplates();
  });
  Future<bool> updateBarCheckTemplate(int id, Map<String, dynamic> payload) => _save(() async {
    final template = await repository.updateBarCheckTemplate(id, payload);
    emit(state.copyWith(selectedBarCheckTemplate: template));
    await loadBarCheckTemplates();
    await loadBarCheckTemplateItems(template.warehouseId);
  });
  Future<void> loadTransfers({String? search, String? status, int? sourceWarehouseId, int? destinationWarehouseId, int page = 1}) => _load(() async {
    final results = await Future.wait(<Future<dynamic>>[repository.transfersPage(search: search, status: status, sourceWarehouseId: sourceWarehouseId, destinationWarehouseId: destinationWarehouseId, page: page), repository.warehouses()]);
    final transfers = results[0] as WarehouseTransfersPage;
    emit(state.copyWith(transfers: transfers.items, transferMeta: transfers.meta, warehouses: results[1] as List<WarehouseLocation>, clearError: true));
  });
  Future<void> loadTransferItems(int warehouseId) => _load(() async { emit(state.copyWith(items: await repository.items(activeOnly: true, warehouseId: warehouseId), clearError: true)); });
  Future<void> loadTransfer(int id) => _load(() async { emit(state.copyWith(selectedTransfer: await repository.transfer(id), clearError: true)); });
  Future<bool> createTransfer(Map<String, dynamic> payload) => _save(() async { final transfer = await repository.createTransfer(payload); emit(state.copyWith(selectedTransfer: transfer)); await loadTransfers(); });
  Future<bool> updateTransfer(int id, Map<String, dynamic> payload) => _save(() async { final transfer = await repository.updateTransfer(id, payload); emit(state.copyWith(selectedTransfer: transfer)); await loadTransfers(); });
  Future<bool> transferAction(
    int id,
    String action, [
    Map<String, dynamic>? payload,
  ]) => _save(() async { final transfer = await repository.transferAction(id, action, payload); emit(state.copyWith(selectedTransfer: transfer)); await loadTransfers(); });
  Future<bool> receiveTransfer(int id, Map<String, dynamic> payload) => _save(() async { final transfer = await repository.receiveTransfer(id, payload); emit(state.copyWith(selectedTransfer: transfer)); await loadTransfers(); });

  Future<void> _load(Future<void> Function() task) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await task();
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<bool> _save(Future<void> Function() task) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await task();
      return true;
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
      return false;
    } finally {
      emit(state.copyWith(saving: false));
    }
  }
}
