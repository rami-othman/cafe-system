import 'package:flutter_bloc/flutter_bloc.dart';

import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../models/inventory_models.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit({required this._repository}) : super(const InventoryState());
  final InventoryRepository _repository;

  Future<void> loadDashboard({
    int? branchId,
    int? warehouseId,
    String? from,
    String? to,
    String? search,
  }) => _load(() async {
    final InventoryDashboard dashboard = await _repository.dashboard(
      branchId: branchId,
      warehouseId: warehouseId,
      from: from,
      to: to,
      search: search,
    );
    emit(state.copyWith(dashboard: dashboard, clearError: true));
  });
  Future<void> loadItems({
    String? search,
    String? type,
    String? category,
    String? status,
    String? stockStatus,
    int page = 1,
  }) => _load(() async {
    final Future<InventoryItemsPage> itemsFuture = _repository.itemsPage(
      search: search,
      type: type,
      category: category,
      status: status,
      stockStatus: stockStatus,
      page: page,
    );
    final Future<List<InventoryUnit>> unitsFuture = _repository.units();
    final InventoryItemsPage result = await itemsFuture;
    final List<InventoryUnit> units = await unitsFuture;
    emit(
      state.copyWith(
        items: result.items,
        units: units,
        itemsPage: result.currentPage,
        itemsLastPage: result.lastPage,
        itemsTotal: result.total,
        itemCategories: result.categories,
        clearError: true,
      ),
    );
  });
  Future<void> loadBalances({
    int? warehouseId,
    String? search,
    String? stockStatus,
  }) => _load(() async {
    final Future<List<InventoryBalance>> balancesFuture = _repository.balances(
      warehouseId: warehouseId,
      search: search,
      stockStatus: stockStatus,
    );
    final Future<List<WarehouseLocation>> warehousesFuture = _repository
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
  Future<void> loadMovements({int? warehouseId, int? itemId, String? type}) =>
      _load(() async {
        final Future<List<InventoryMovement>> movementsFuture = _repository
            .movements(warehouseId: warehouseId, itemId: itemId, type: type);
        final Future<List<InventoryItem>> itemsFuture = _repository.items(
          activeOnly: true,
        );
        final Future<List<WarehouseLocation>> warehousesFuture = _repository
            .warehouses();
        final List<InventoryMovement> movements = await movementsFuture;
        final List<InventoryItem> items = await itemsFuture;
        final List<WarehouseLocation> warehouses = await warehousesFuture;
        emit(
          state.copyWith(
            movements: movements,
            items: items,
            warehouses: warehouses,
            clearError: true,
          ),
        );
      });
  Future<void> loadItemDetails(int id) => _load(() async {
    final InventoryItem item = await _repository.item(id);
    emit(
      state.copyWith(
        selectedItem: item,
        itemMovements: item.recentMovements,
        clearError: true,
      ),
    );
  });
  Future<void> loadUnitConversions({int? itemId}) => _load(() async {
    final Future<List<InventoryItem>> itemsFuture = _repository
        .conversionItems();
    final Future<List<InventoryUnit>> unitsFuture = _repository.units();
    final List<InventoryItem> items = await itemsFuture;
    final List<InventoryUnit> units = await unitsFuture;
    final int? selected =
        itemId ??
        state.selectedConversionItemId ??
        (items.isEmpty ? null : items.first.id);
    final List<InventoryItemUnitConversion> conversions = selected == null
        ? const <InventoryItemUnitConversion>[]
        : await _repository.unitConversions(selected);
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
  Future<void> loadCounts() => _load(() async {
    final Future<List<InventoryCount>> countsFuture = _repository.counts();
    final Future<List<WarehouseLocation>> warehousesFuture = _repository
        .warehouses();
    final List<InventoryCount> counts = await countsFuture;
    final List<WarehouseLocation> warehouses = await warehousesFuture;
    emit(
      state.copyWith(counts: counts, warehouses: warehouses, clearError: true),
    );
  });
  Future<void> loadCountDetails(int id) => _load(() async {
    final InventoryCount count = await _repository.count(id);
    emit(state.copyWith(selectedCount: count, clearError: true));
  });
  Future<bool> saveItem(Map<String, dynamic> payload, {int? id}) =>
      _save(() async {
        await _repository.saveItem(payload, id: id);
      });
  Future<bool> saveUnitConversion(
    int itemId,
    Map<String, dynamic> payload, {
    int? id,
  }) => _save(() async {
    await _repository.saveUnitConversion(itemId, payload, id: id);
    await loadUnitConversions(itemId: itemId);
  });
  Future<bool> postMovement(Map<String, dynamic> payload) => _save(() async {
    await _repository.postMovement(payload);
    await loadMovements();
  });
  Future<bool> createCount(Map<String, dynamic> payload) => _save(() async {
    await _repository.createCount(payload);
    await loadCounts();
  });
  Future<bool> countAction(int id, String action) => _save(() async {
    await _repository.countAction(id, action);
    await loadCounts();
    await loadCountDetails(id);
  });
  Future<bool> saveCountLine(int countId, Map<String, dynamic> payload) =>
      _save(() async {
        await _repository.saveCountLine(countId, payload);
        await loadCountDetails(countId);
        await loadCounts();
      });
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
