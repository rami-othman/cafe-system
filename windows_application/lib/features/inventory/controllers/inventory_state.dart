import 'package:equatable/equatable.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../models/inventory_models.dart';

enum InventoryCountLineSaveStatus { idle, saving, saved, failed }

class InventoryState extends Equatable {
  const InventoryState({
    this.loading = false,
    this.saving = false,
    this.error,
    this.dashboard,
    this.dashboardLoading = false,
    this.dashboardError,
    this.dashboardPermissionDenied = false,
    this.selectedItem,
    this.items = const <InventoryItem>[],
    this.units = const <InventoryUnit>[],
    this.conversionItems = const <InventoryItem>[],
    this.conversions = const <InventoryItemUnitConversion>[],
    this.selectedConversionItemId,
    this.itemsPage = 1,
    this.itemsLastPage = 1,
    this.itemsTotal = 0,
    this.itemCategories = const <String>[],
    this.balances = const <InventoryBalance>[],
    this.movements = const <InventoryMovement>[],
    this.movementsPage = 1,
    this.movementsLastPage = 1,
    this.movementsTotal = 0,
    this.counts = const <InventoryCount>[],
    this.countsPage = 1,
    this.countsLastPage = 1,
    this.countsTotal = 0,
    this.countSummary = const InventoryCountSummary(),
    this.countCreators = const <InventoryCountCreator>[],
    this.selectedCount,
    this.countLineSaveStatus = InventoryCountLineSaveStatus.idle,
    this.countLineSaveError,
    this.warehouses = const <WarehouseLocation>[],
    this.stockCountWarehouses = const <WarehouseLocation>[],
    this.itemMovements = const <InventoryMovement>[],
    this.itemMovementHistory = const <InventoryMovement>[],
    this.itemMovementHistoryPage = 1,
    this.itemMovementHistoryLastPage = 1,
    this.itemMovementHistoryTotal = 0,
    this.itemMovementHistoryLoading = false,
    this.itemRecipeUsage = const <InventoryRecipeUsage>[],
    this.itemRecipeUsageLoaded = false,
    this.itemRecipeUsageLoading = false,
    this.itemPurchaseHistory = const <InventoryPurchaseHistoryEntry>[],
    this.itemPurchaseHistoryPage = 1,
    this.itemPurchaseHistoryLastPage = 1,
    this.itemPurchaseHistoryTotal = 0,
    this.itemPurchaseHistoryLoading = false,
    this.barCheckTemplates = const <BarCheckTemplate>[],
    this.selectedBarCheckTemplate,
    this.transfers = const <WarehouseTransfer>[],
    this.transferMeta = const TransferPaginationMeta(),
    this.selectedTransfer,
  });
  final bool loading;
  final bool saving;
  final String? error;
  final InventoryDashboard? dashboard;
  final bool dashboardLoading;
  final String? dashboardError;
  final bool dashboardPermissionDenied;
  final InventoryItem? selectedItem;
  final List<InventoryItem> items;
  final List<InventoryUnit> units;
  final List<InventoryItem> conversionItems;
  final List<InventoryItemUnitConversion> conversions;
  final int? selectedConversionItemId;
  final int itemsPage;
  final int itemsLastPage;
  final int itemsTotal;
  final List<String> itemCategories;
  final List<InventoryBalance> balances;
  final List<InventoryMovement> movements;
  final int movementsPage;
  final int movementsLastPage;
  final int movementsTotal;
  final List<InventoryCount> counts;
  final int countsPage;
  final int countsLastPage;
  final int countsTotal;
  final InventoryCountSummary countSummary;
  final List<InventoryCountCreator> countCreators;
  final InventoryCount? selectedCount;
  final InventoryCountLineSaveStatus countLineSaveStatus;
  final String? countLineSaveError;
  final List<WarehouseLocation> warehouses;
  /// The permission-filtered subset of warehouses the current actor may
  /// start a stock count in (loadCounts' `accessibleForStockCount: true`
  /// fetch) - kept separate from [warehouses] so the Stock Counts screen's
  /// dropdown never gets silently swapped for the plain "all active
  /// warehouses" list another loader last populated, or vice versa.
  final List<WarehouseLocation> stockCountWarehouses;
  final List<InventoryMovement> itemMovements;
  /// The item details screen's full, paginated "سجل الحركات" tab data -
  /// distinct from [itemMovements] (the item-show endpoint's fixed 5-row
  /// recent summary shown elsewhere on that screen).
  final List<InventoryMovement> itemMovementHistory;
  final int itemMovementHistoryPage;
  final int itemMovementHistoryLastPage;
  final int itemMovementHistoryTotal;
  final bool itemMovementHistoryLoading;
  final List<InventoryRecipeUsage> itemRecipeUsage;
  final bool itemRecipeUsageLoaded;
  final bool itemRecipeUsageLoading;
  final List<InventoryPurchaseHistoryEntry> itemPurchaseHistory;
  final int itemPurchaseHistoryPage;
  final int itemPurchaseHistoryLastPage;
  final int itemPurchaseHistoryTotal;
  final bool itemPurchaseHistoryLoading;
  final List<BarCheckTemplate> barCheckTemplates;
  final BarCheckTemplate? selectedBarCheckTemplate;
  final List<WarehouseTransfer> transfers;
  final TransferPaginationMeta transferMeta;
  final WarehouseTransfer? selectedTransfer;
  InventoryState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    InventoryDashboard? dashboard,
    bool? dashboardLoading,
    String? dashboardError,
    bool clearDashboardError = false,
    bool? dashboardPermissionDenied,
    InventoryItem? selectedItem,
    List<InventoryItem>? items,
    List<InventoryUnit>? units,
    List<InventoryItem>? conversionItems,
    List<InventoryItemUnitConversion>? conversions,
    int? selectedConversionItemId,
    int? itemsPage,
    int? itemsLastPage,
    int? itemsTotal,
    List<String>? itemCategories,
    List<InventoryBalance>? balances,
    List<InventoryMovement>? movements,
    int? movementsPage,
    int? movementsLastPage,
    int? movementsTotal,
    List<InventoryCount>? counts,
    int? countsPage,
    int? countsLastPage,
    int? countsTotal,
    InventoryCountSummary? countSummary,
    List<InventoryCountCreator>? countCreators,
    InventoryCount? selectedCount,
    InventoryCountLineSaveStatus? countLineSaveStatus,
    String? countLineSaveError,
    bool clearCountLineSaveError = false,
    List<WarehouseLocation>? warehouses,
    List<WarehouseLocation>? stockCountWarehouses,
    List<InventoryMovement>? itemMovements,
    List<InventoryMovement>? itemMovementHistory,
    int? itemMovementHistoryPage,
    int? itemMovementHistoryLastPage,
    int? itemMovementHistoryTotal,
    bool? itemMovementHistoryLoading,
    List<InventoryRecipeUsage>? itemRecipeUsage,
    bool? itemRecipeUsageLoaded,
    bool? itemRecipeUsageLoading,
    List<InventoryPurchaseHistoryEntry>? itemPurchaseHistory,
    int? itemPurchaseHistoryPage,
    int? itemPurchaseHistoryLastPage,
    int? itemPurchaseHistoryTotal,
    bool? itemPurchaseHistoryLoading,
    List<BarCheckTemplate>? barCheckTemplates,
    BarCheckTemplate? selectedBarCheckTemplate,
    List<WarehouseTransfer>? transfers,
    TransferPaginationMeta? transferMeta,
    WarehouseTransfer? selectedTransfer,
  }) => InventoryState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
    dashboard: dashboard ?? this.dashboard,
    dashboardLoading: dashboardLoading ?? this.dashboardLoading,
    dashboardError: clearDashboardError
        ? null
        : dashboardError ?? this.dashboardError,
    dashboardPermissionDenied:
        dashboardPermissionDenied ?? this.dashboardPermissionDenied,
    selectedItem: selectedItem ?? this.selectedItem,
    items: items ?? this.items,
    units: units ?? this.units,
    conversionItems: conversionItems ?? this.conversionItems,
    conversions: conversions ?? this.conversions,
    selectedConversionItemId:
        selectedConversionItemId ?? this.selectedConversionItemId,
    itemsPage: itemsPage ?? this.itemsPage,
    itemsLastPage: itemsLastPage ?? this.itemsLastPage,
    itemsTotal: itemsTotal ?? this.itemsTotal,
    itemCategories: itemCategories ?? this.itemCategories,
    balances: balances ?? this.balances,
    movements: movements ?? this.movements,
    movementsPage: movementsPage ?? this.movementsPage,
    movementsLastPage: movementsLastPage ?? this.movementsLastPage,
    movementsTotal: movementsTotal ?? this.movementsTotal,
    counts: counts ?? this.counts,
    countsPage: countsPage ?? this.countsPage,
    countsLastPage: countsLastPage ?? this.countsLastPage,
    countsTotal: countsTotal ?? this.countsTotal,
    countSummary: countSummary ?? this.countSummary,
    countCreators: countCreators ?? this.countCreators,
    selectedCount: selectedCount ?? this.selectedCount,
    countLineSaveStatus: countLineSaveStatus ?? this.countLineSaveStatus,
    countLineSaveError: clearCountLineSaveError
        ? null
        : countLineSaveError ?? this.countLineSaveError,
    warehouses: warehouses ?? this.warehouses,
    stockCountWarehouses: stockCountWarehouses ?? this.stockCountWarehouses,
    itemMovements: itemMovements ?? this.itemMovements,
    itemMovementHistory: itemMovementHistory ?? this.itemMovementHistory,
    itemMovementHistoryPage:
        itemMovementHistoryPage ?? this.itemMovementHistoryPage,
    itemMovementHistoryLastPage:
        itemMovementHistoryLastPage ?? this.itemMovementHistoryLastPage,
    itemMovementHistoryTotal:
        itemMovementHistoryTotal ?? this.itemMovementHistoryTotal,
    itemMovementHistoryLoading:
        itemMovementHistoryLoading ?? this.itemMovementHistoryLoading,
    itemRecipeUsage: itemRecipeUsage ?? this.itemRecipeUsage,
    itemRecipeUsageLoaded: itemRecipeUsageLoaded ?? this.itemRecipeUsageLoaded,
    itemRecipeUsageLoading:
        itemRecipeUsageLoading ?? this.itemRecipeUsageLoading,
    itemPurchaseHistory: itemPurchaseHistory ?? this.itemPurchaseHistory,
    itemPurchaseHistoryPage:
        itemPurchaseHistoryPage ?? this.itemPurchaseHistoryPage,
    itemPurchaseHistoryLastPage:
        itemPurchaseHistoryLastPage ?? this.itemPurchaseHistoryLastPage,
    itemPurchaseHistoryTotal:
        itemPurchaseHistoryTotal ?? this.itemPurchaseHistoryTotal,
    itemPurchaseHistoryLoading:
        itemPurchaseHistoryLoading ?? this.itemPurchaseHistoryLoading,
    barCheckTemplates: barCheckTemplates ?? this.barCheckTemplates,
    selectedBarCheckTemplate: selectedBarCheckTemplate ?? this.selectedBarCheckTemplate,
    transfers: transfers ?? this.transfers,
    transferMeta: transferMeta ?? this.transferMeta,
    selectedTransfer: selectedTransfer ?? this.selectedTransfer,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    saving,
    error,
    dashboard,
    dashboardLoading,
    dashboardError,
    dashboardPermissionDenied,
    selectedItem,
    items,
    units,
    conversionItems,
    conversions,
    selectedConversionItemId,
    itemsPage,
    itemsLastPage,
    itemsTotal,
    itemCategories,
    balances,
    movements,
    movementsPage,
    movementsLastPage,
    movementsTotal,
    counts,
    countsPage,
    countsLastPage,
    countsTotal,
    countSummary,
    countCreators,
    selectedCount,
    countLineSaveStatus,
    countLineSaveError,
    warehouses,
    stockCountWarehouses,
    itemMovements,
    itemMovementHistory,
    itemMovementHistoryPage,
    itemMovementHistoryLastPage,
    itemMovementHistoryTotal,
    itemMovementHistoryLoading,
    itemRecipeUsage,
    itemRecipeUsageLoaded,
    itemRecipeUsageLoading,
    itemPurchaseHistory,
    itemPurchaseHistoryPage,
    itemPurchaseHistoryLastPage,
    itemPurchaseHistoryTotal,
    itemPurchaseHistoryLoading,
    barCheckTemplates,
    selectedBarCheckTemplate,
    transfers,
    transferMeta,
    selectedTransfer,
  ];
}
