import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../models/inventory_models.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit({required this.repository}) : super(const InventoryState());
  final InventoryRepository repository;

  final Map<String, int> _requestGenerations = <String, int>{};
  int _dashboardRequestGeneration = 0;

  /// Runs [task] as the latest call for [key]. Filters (including a
  /// selected warehouse) can change faster than the network responds - each
  /// call claims the next generation for its key, and [task] is handed an
  /// `isCurrent` check so it can skip applying its own success result once a
  /// newer call for the same key has started; this wrapper likewise skips
  /// the error/loading:false transitions for a superseded call. Every
  /// warehouse-scoped loader below goes through this one implementation
  /// instead of re-deriving its own request-id counter.
  Future<void> _loadLatest(
    String key,
    Future<void> Function(bool Function() isCurrent) task,
  ) async {
    final int generation = (_requestGenerations[key] ?? 0) + 1;
    _requestGenerations[key] = generation;
    bool isCurrent() => _requestGenerations[key] == generation;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      await task(isCurrent);
    } catch (error) {
      if (!isCurrent()) return;
      emit(state.copyWith(error: error.toString()));
    } finally {
      if (isCurrent()) {
        emit(state.copyWith(loading: false));
      }
    }
  }

  Future<void> loadDashboard({
    int? branchId,
    int? warehouseId,
    String? from,
    String? to,
    String? search,
    String? movementType,
    int? trendDays,
  }) async {
    final int generation = ++_dashboardRequestGeneration;
    bool isCurrent() => generation == _dashboardRequestGeneration;
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
      if (!isCurrent()) return;
      emit(
        state.copyWith(
          dashboard: dashboard,
          dashboardPermissionDenied: false,
          clearDashboardError: true,
        ),
      );
    } catch (error) {
      if (!isCurrent()) return;
      final ApiException? apiError = error is ApiException ? error : null;
      emit(
        state.copyWith(
          dashboardError: apiError?.message ?? error.toString(),
          dashboardPermissionDenied:
              apiError?.statusCode == 401 || apiError?.statusCode == 403,
        ),
      );
    } finally {
      if (isCurrent()) emit(state.copyWith(dashboardLoading: false));
    }
  }

  // Future.wait ensures every concurrent request in a loader below is
  // awaited together. Awaiting each future one at a time (as separate
  // statements) means that if the first one throws, the others are
  // abandoned mid-flight; if they later fail too, their errors have no
  // listener and surface as unhandled exceptions instead of a caught error.
  Future<void> loadItems({
    int? branchId,
    String? search,
    String? type,
    String? category,
    String? status,
    String? stockStatus,
    int? warehouseId,
    int page = 1,
  }) => _loadLatest('items', (bool Function() isCurrent) async {
    final List<dynamic> results = await Future.wait(<Future<dynamic>>[
      repository.itemsPage(
        search: search,
        type: type,
        category: category,
        status: status,
        stockStatus: stockStatus,
        warehouseId: warehouseId,
        branchId: branchId,
        page: page,
      ),
      repository.units(),
      repository.warehouses(),
    ]);
    if (!isCurrent()) return;
    final InventoryItemsPage result = results[0] as InventoryItemsPage;
    final List<InventoryUnit> units = results[1] as List<InventoryUnit>;
    final List<WarehouseLocation> warehouses =
        results[2] as List<WarehouseLocation>;
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
    int? branchId,
    int? warehouseId,
    String? search,
    String? stockStatus,
  }) => _loadLatest('balances', (bool Function() isCurrent) async {
    final List<dynamic> results = await Future.wait(<Future<dynamic>>[
      repository.balances(
        branchId: branchId,
        warehouseId: warehouseId,
        search: search,
        stockStatus: stockStatus,
      ),
      repository.warehouses(),
    ]);
    if (!isCurrent()) return;
    emit(
      state.copyWith(
        balances: results[0] as List<InventoryBalance>,
        warehouses: results[1] as List<WarehouseLocation>,
        clearError: true,
      ),
    );
  });
  Future<void> loadMovements({
    int? branchId,
    int? warehouseId,
    int? itemId,
    String? type,
    int page = 1,
  }) => _loadLatest('movements', (bool Function() isCurrent) async {
    final List<dynamic> results = await Future.wait(<Future<dynamic>>[
      repository.movementsPage(
        branchId: branchId,
        warehouseId: warehouseId,
        itemId: itemId,
        type: type,
        page: page,
      ),
      repository.items(activeOnly: true),
      repository.warehouses(),
    ]);
    if (!isCurrent()) return;
    final InventoryMovementsPage result = results[0] as InventoryMovementsPage;
    emit(
      state.copyWith(
        movements: result.movements,
        movementsPage: result.currentPage,
        movementsLastPage: result.lastPage,
        movementsTotal: result.total,
        items: results[1] as List<InventoryItem>,
        warehouses: results[2] as List<WarehouseLocation>,
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
    int? branchId,
    String? status,
    int? warehouseId,
    String? countType,
    String? source,
    int? createdBy,
    String? from,
    String? to,
    int page = 1,
  }) => _loadLatest('counts', (bool Function() isCurrent) async {
    final List<dynamic> results = await Future.wait(<Future<dynamic>>[
      repository.countsPage(
        branchId: branchId,
        status: status,
        warehouseId: warehouseId,
        countType: countType,
        source: source,
        createdBy: createdBy,
        from: from,
        to: to,
        page: page,
      ),
      // Stock-count-eligible warehouses are a different, permission-filtered
      // set from every other loader's plain repository.warehouses() call -
      // it must land in its own state field (stockCountWarehouses), not the
      // shared `warehouses` field other screens' dropdowns also read from.
      repository.warehouses(accessibleForStockCount: true),
    ]);
    if (!isCurrent()) return;
    final InventoryCountsPage counts = results[0] as InventoryCountsPage;
    emit(
      state.copyWith(
        counts: counts.items,
        countsPage: counts.currentPage,
        countsLastPage: counts.lastPage,
        countsTotal: counts.total,
        countSummary: counts.summary,
        countCreators: counts.creators,
        stockCountWarehouses: results[1] as List<WarehouseLocation>,
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

  Future<void> loadBarCheckTemplates() =>
      _loadLatest('barCheckTemplates', (bool Function() isCurrent) async {
        final results = await Future.wait(<Future<dynamic>>[
          repository.barCheckTemplates(),
          repository.warehouses(),
          repository.items(activeOnly: true),
        ]);
        if (!isCurrent()) return;
        emit(
          state.copyWith(
            barCheckTemplates: results[0] as List<BarCheckTemplate>,
            warehouses: results[1] as List<WarehouseLocation>,
            items: results[2] as List<InventoryItem>,
            clearError: true,
          ),
        );
      });
  Future<void> loadBarCheckTemplate(int id) => _load(() async {
    final template = await repository.barCheckTemplate(id);
    emit(state.copyWith(selectedBarCheckTemplate: template, clearError: true));
  });
  Future<void> loadBarCheckTemplateItems(int warehouseId) =>
      _loadLatest('barCheckTemplateItems', (bool Function() isCurrent) async {
        final items = await repository.items(
          activeOnly: true,
          warehouseId: warehouseId,
        );
        if (!isCurrent()) return;
        emit(state.copyWith(items: items, clearError: true));
      });
  Future<bool> createBarCheckTemplate(Map<String, dynamic> payload) =>
      _save(() async {
        final template = await repository.createBarCheckTemplate(payload);
        emit(state.copyWith(selectedBarCheckTemplate: template));
        await loadBarCheckTemplates();
      });
  Future<bool> updateBarCheckTemplate(int id, Map<String, dynamic> payload) =>
      _save(() async {
        final template = await repository.updateBarCheckTemplate(id, payload);
        emit(state.copyWith(selectedBarCheckTemplate: template));
        await loadBarCheckTemplates();
        await loadBarCheckTemplateItems(template.warehouseId);
      });
  Future<void> loadTransfers({
    String? search,
    String? status,
    int? sourceWarehouseId,
    int? destinationWarehouseId,
    int page = 1,
  }) => _loadLatest('transfers', (bool Function() isCurrent) async {
    final results = await Future.wait(<Future<dynamic>>[
      repository.transfersPage(
        search: search,
        status: status,
        sourceWarehouseId: sourceWarehouseId,
        destinationWarehouseId: destinationWarehouseId,
        page: page,
      ),
      repository.warehouses(),
    ]);
    if (!isCurrent()) return;
    final transfers = results[0] as WarehouseTransfersPage;
    emit(
      state.copyWith(
        transfers: transfers.items,
        transferMeta: transfers.meta,
        warehouses: results[1] as List<WarehouseLocation>,
        clearError: true,
      ),
    );
  });
  Future<void> loadTransferItems(int warehouseId) =>
      _loadLatest('transferItems', (bool Function() isCurrent) async {
        final items = await repository.items(
          activeOnly: true,
          warehouseId: warehouseId,
        );
        if (!isCurrent()) return;
        emit(state.copyWith(items: items, clearError: true));
      });
  Future<void> loadTransfer(int id) => _load(() async {
    emit(
      state.copyWith(
        selectedTransfer: await repository.transfer(id),
        clearError: true,
      ),
    );
  });
  Future<bool> createTransfer(Map<String, dynamic> payload) => _save(() async {
    final transfer = await repository.createTransfer(payload);
    emit(state.copyWith(selectedTransfer: transfer));
    await loadTransfers();
  });
  Future<bool> updateTransfer(int id, Map<String, dynamic> payload) =>
      _save(() async {
        final transfer = await repository.updateTransfer(id, payload);
        emit(state.copyWith(selectedTransfer: transfer));
        await loadTransfers();
      });
  Future<bool> transferAction(
    int id,
    String action, [
    Map<String, dynamic>? payload,
  ]) => _save(() async {
    final transfer = await repository.transferAction(id, action, payload);
    emit(state.copyWith(selectedTransfer: transfer));
    await loadTransfers();
  });
  Future<bool> receiveTransfer(int id, Map<String, dynamic> payload) =>
      _save(() async {
        final transfer = await repository.receiveTransfer(id, payload);
        emit(state.copyWith(selectedTransfer: transfer));
        await loadTransfers();
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
