import 'package:equatable/equatable.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../models/inventory_models.dart';

class InventoryState extends Equatable {
  const InventoryState({
    this.loading = false,
    this.saving = false,
    this.error,
    this.dashboard,
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
    this.counts = const <InventoryCount>[],
    this.selectedCount,
    this.warehouses = const <WarehouseLocation>[],
    this.itemMovements = const <InventoryMovement>[],
  });
  final bool loading;
  final bool saving;
  final String? error;
  final InventoryDashboard? dashboard;
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
  final List<InventoryCount> counts;
  final InventoryCount? selectedCount;
  final List<WarehouseLocation> warehouses;
  final List<InventoryMovement> itemMovements;
  InventoryState copyWith({
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    InventoryDashboard? dashboard,
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
    List<InventoryCount>? counts,
    InventoryCount? selectedCount,
    List<WarehouseLocation>? warehouses,
    List<InventoryMovement>? itemMovements,
  }) => InventoryState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
    dashboard: dashboard ?? this.dashboard,
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
    counts: counts ?? this.counts,
    selectedCount: selectedCount ?? this.selectedCount,
    warehouses: warehouses ?? this.warehouses,
    itemMovements: itemMovements ?? this.itemMovements,
  );
  @override
  List<Object?> get props => <Object?>[
    loading,
    saving,
    error,
    dashboard,
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
    counts,
    selectedCount,
    warehouses,
    itemMovements,
  ];
}
