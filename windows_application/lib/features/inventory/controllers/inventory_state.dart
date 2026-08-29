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
    this.itemMovements = const <InventoryMovement>[],
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
  final List<InventoryMovement> itemMovements;
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
    List<InventoryMovement>? itemMovements,
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
    itemMovements: itemMovements ?? this.itemMovements,
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
    itemMovements,
    barCheckTemplates,
    selectedBarCheckTemplate,
    transfers,
    transferMeta,
    selectedTransfer,
  ];
}
