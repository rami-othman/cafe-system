import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/inventory_text_styles.dart';
import '../../../core/utils/backend_datetime.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../operational_context/controllers/operational_branch_cubit.dart';
import '../controllers/inventory_cubit.dart';
import '../controllers/inventory_state.dart';
import '../models/inventory_models.dart';

String _number(String value, {int digits = 2}) =>
    NumberFormat.decimalPatternDigits(
      locale: 'en_US',
      decimalDigits: digits,
    ).format(double.tryParse(value) ?? 0);
String _money(String value) => '\$${_number(value)}';
String _itemType(String value) => switch (value) {
  'raw_material' => 'مادة خام',
  'packaging' => 'تغليف',
  'supply' => 'مستلزمات',
  'finished_good' => 'منتج جاهز',
  _ => 'أخرى',
};
String _movementLabel(String value) => switch (value) {
  'stock_in' || 'opening_balance' || 'adjustment_in' => 'إدخال مخزون',
  'return_in' => 'مرتجع وارد',
  'stock_out' => 'إخراج مخزون',
  'adjustment_out' => 'تسوية إخراج',
  'return_out' => 'مرتجع صادر',
  'waste' => 'هالك',
  'stock_count_variance' => 'فرق جرد',
  'transfer_in' || 'transfer_out' => 'تحويل',
  _ => 'تسوية',
};
ManagementTone _movementTone(String value) => switch (value) {
  'stock_in' || 'opening_balance' || 'adjustment_in' => ManagementTone.success,
  'waste' => ManagementTone.danger,
  'stock_count_variance' || 'adjustment_out' => ManagementTone.warning,
  'transfer_in' || 'transfer_out' => ManagementTone.info,
  _ => ManagementTone.neutral,
};
String _dashboardMovementLabel(InventoryMovement movement) =>
    switch (movement.dashboardType) {
      'purchase_receive' => 'استلام شراء',
      'recipe_consumption' => 'استهلاك بيع',
      'transfer_in' => 'تحويل وارد',
      'transfer_out' => 'تحويل صادر',
      'waste' => 'هدر',
      'adjustment' => 'تعديل مخزون',
      'opening_balance' => 'رصيد افتتاحي',
      'return' => 'مرتجع',
      _ => _movementLabel(movement.type),
    };
ManagementTone _dashboardMovementTone(InventoryMovement movement) =>
    switch (movement.dashboardType) {
      'purchase_receive' => ManagementTone.success,
      'recipe_consumption' => ManagementTone.danger,
      'transfer_in' || 'transfer_out' => ManagementTone.info,
      'waste' => ManagementTone.warning,
      'adjustment' => ManagementTone.warning,
      'opening_balance' => ManagementTone.success,
      'return' => ManagementTone.neutral,
      _ => _movementTone(movement.type),
    };
bool _isOutbound(String type) =>
    type == 'stock_out' || type == 'waste' || type == 'adjustment_out';
String _stockLabel(String quantity, bool low) {
  if ((double.tryParse(quantity) ?? 0) <= 0) return 'نفد المخزون';
  return low ? 'مخزون منخفض' : 'متوفر';
}

ManagementTone _stockTone(String quantity, bool low) {
  if ((double.tryParse(quantity) ?? 0) <= 0) return ManagementTone.danger;
  return low ? ManagementTone.warning : ManagementTone.success;
}

String _warehouseLabel(WarehouseLocation warehouse) => warehouse.displayName;
String _unitLabel(String unit) => InventoryUnit.labelFor(unit);
String _itemSelectorLabel(InventoryItem item) {
  final String name = item.name.isEmpty ? 'مادة مخزنية' : item.name;
  final String sku = item.sku.isEmpty ? 'بلا رمز' : item.sku;

  return '$name — $sku — ${_unitLabel(item.unit)}';
}

List<InventoryItem> _uniqueActiveItems(List<InventoryItem> items) {
  final Set<String> seen = <String>{};

  return items
      .where((InventoryItem item) {
        if (!item.active) return false;
        // A SKU identifies one catalog item. Items without a SKU are retained by
        // ID so genuinely distinct variants are never silently merged in Flutter.
        final String identity = item.sku.trim().isEmpty
            ? 'id:${item.id}'
            : 'sku:${item.sku.trim().toLowerCase()}';
        return seen.add(identity);
      })
      .toList(growable: false);
}

List<WarehouseLocation> _branchWarehouses(
  BuildContext context,
  List<WarehouseLocation> warehouses,
) {
  final int? branchId = context
      .read<OperationalBranchCubit>()
      .state
      .selectedBranchId;
  return warehouses
      .where(
        (WarehouseLocation warehouse) =>
            !warehouse.isLegacy &&
            warehouse.isActive &&
            warehouse.branchId == branchId,
      )
      .toList(growable: false);
}

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});
  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboardScreen> {
  int? _branchId;
  int? _warehouseId;
  String _activityMovementType = '';
  int _trendDays = 30;
  late DateTimeRange _range;
  final TextEditingController _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(today.year, today.month),
      end: today,
    );
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() {
      cubit.loadDashboard();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final InventoryDashboard? dashboard = state.dashboard;
        if (dashboard == null ||
            state.dashboardError != null ||
            state.dashboardPermissionDenied) {
          return _LoadState(
            loading: state.dashboardLoading,
            error: state.dashboardError,
            permissionDenied: state.dashboardPermissionDenied,
            onRetry: _reload,
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ManagementPageHeader(
                title: 'إدارة المخزون',
                subtitle:
                    'تابع المخزون والحركات والتنبيهات التشغيلية في الفروع.',
                actions: const <Widget>[],
              ),
              const SizedBox(height: AppSpacing.lg),
              ManagementFilterBar(
                children: <Widget>[
                  _DashboardBranchDropdown(
                    value: _branchId,
                    branches: dashboard.branches,
                    onChanged: (int? value) {
                      setState(() {
                        _branchId = value;
                        _warehouseId = null;
                      });
                      _reload();
                    },
                  ),
                  _DashboardWarehouseDropdown(
                    value: _warehouseId,
                    warehouses: dashboard.warehouses,
                    onChanged: (int? value) {
                      setState(() => _warehouseId = value);
                      _reload();
                    },
                  ),
                  _DateRangeFilter(range: _range, onTap: _pickRange),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _reload(),
                      decoration: const InputDecoration(
                        hintText: 'ابحث عن مادة أو حركة...',
                        prefixIcon: Icon(Icons.search_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.dashboardLoading) ...<Widget>[
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
              ],
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.lg,
                      children:
                          <Widget>[
                                _DashboardKpi(
                                  label: 'إجمالي قيمة المخزون',
                                  metric: dashboard.kpis.totalValue,
                                  icon: Icons.account_balance_wallet_outlined,
                                ),
                                _DashboardKpi(
                                  label: 'إجمالي المواد',
                                  metric: dashboard.kpis.totalItems,
                                  icon: Icons.inventory_2_outlined,
                                ),
                                _DashboardKpi(
                                  label: 'مواد منخفضة المخزون',
                                  metric: dashboard.kpis.lowStock,
                                  icon: Icons.warning_amber_rounded,
                                  color: AppColors.discountOrangeBadge,
                                ),
                                _DashboardKpi(
                                  label: 'مواد نافدة',
                                  metric: dashboard.kpis.outOfStock,
                                  icon: Icons.remove_shopping_cart_outlined,
                                  color: const Color(0xFFFFE6E4),
                                ),
                                _DashboardKpi(
                                  label: 'تكلفة استهلاك اليوم',
                                  metric: dashboard.kpis.todayConsumption,
                                  icon: Icons.restaurant_outlined,
                                  color: AppColors.discountBlueBadge,
                                ),
                                _DashboardKpi(
                                  label: 'تكلفة هالك اليوم',
                                  metric: dashboard.kpis.todayWaste,
                                  icon: Icons.delete_outline,
                                  color: AppColors.discountBlueBadge,
                                ),
                              ]
                              .map(
                                (Widget card) => SizedBox(
                                  width: constraints.maxWidth < 900
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth -
                                                AppSpacing.lg * 2) /
                                            3,
                                  child: card,
                                ),
                              )
                              .toList(),
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DashboardQuickActions(
                onAddItem: () => context.go(AppRoutes.inventoryItems),
                onMovement: () => context.go(AppRoutes.inventoryMovementCreate),
                onCount: () => context.go(AppRoutes.inventoryCounts),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    constraints.maxWidth < 980
                    ? Column(
                        children: <Widget>[
                          _DashboardWarehouseValueCard(
                            values: dashboard.warehouses,
                            onTap: (int id) {
                              setState(() => _warehouseId = id);
                              _reload();
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DashboardLowStockAlerts(
                            alerts: dashboard.alerts,
                            summary: dashboard.alertSummary,
                            onOpen: (InventoryLowStockAlert alert) =>
                                context.go(
                                  AppRoutes.inventoryItemDetailPath(
                                    alert.itemId,
                                  ),
                                ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 1,
                            child: _DashboardWarehouseValueCard(
                              values: dashboard.warehouses,
                              onTap: (int id) {
                                setState(() => _warehouseId = id);
                                _reload();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 1,
                            child: _DashboardLowStockAlerts(
                              alerts: dashboard.alerts,
                              summary: dashboard.alertSummary,
                              onOpen: (InventoryLowStockAlert alert) =>
                                  context.go(
                                    AppRoutes.inventoryItemDetailPath(
                                      alert.itemId,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              InventoryDashboardAnalyticsSection(
                loading: state.dashboardLoading,
                trend: dashboard.stockValueTrend,
                waste: dashboard.wasteSummary,
                consumption: dashboard.consumptionSummary,
                selectedTrendDays: _trendDays,
                onTrendDaysChanged: (int value) {
                  setState(() => _trendDays = value);
                  _reload();
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              InventoryDashboardRecentActivityFeed(
                items: dashboard.recent,
                selectedType: _activityMovementType,
                onTypeChanged: (String value) {
                  setState(() => _activityMovementType = value);
                  _reload();
                },
                onViewAll: () => context.go(AppRoutes.inventoryMovements),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _pickRange() async {
    final DateTimeRange? selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: const DialogThemeData(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: 660),
            insetPadding: EdgeInsets.all(24),
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _range = selected);
    _reload();
  }

  void _reload() => context.read<InventoryCubit>().loadDashboard(
    branchId: _branchId,
    warehouseId: _warehouseId,
    from: _apiDate(_range.start),
    to: _apiDate(_range.end),
    search: _search.text.trim(),
    movementType: _activityMovementType.isEmpty ? null : _activityMovementType,
    trendDays: _trendDays,
  );
}

class InventoryItemsScreen extends StatefulWidget {
  const InventoryItemsScreen({super.key});
  @override
  State<InventoryItemsScreen> createState() => _InventoryItemsState();
}

class _InventoryItemsState extends State<InventoryItemsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _type = '';
  String _category = '';
  String _activeStatus = '';
  String _stockStatus = '';
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ManagementPageHeader(
              title: 'المواد المخزنية',
              subtitle:
                  'إدارة المواد الخام والتغليف والمستلزمات الخاضعة للرقابة.',
              actions: <Widget>[
                AppButton(
                  label: 'إضافة مادة',
                  icon: Icons.add,
                  onPressed: () => _showItemDialog(
                    context,
                    categories: state.itemCategories,
                    units: state.units,
                    onSaved: _load,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ManagementFilterBar(
              children: <Widget>[
                _SearchField(
                  hint: 'البحث بالاسم أو رمز المادة',
                  controller: _search,
                  onChanged: (String value) => setState(() => _query = value),
                  onSubmitted: (_) => _load(),
                ),
                _StringDropdown(
                  value: _type,
                  label: 'نوع المادة',
                  options: const <String, String>{
                    'raw_material': 'مادة خام',
                    'packaging': 'تغليف',
                    'supply': 'مستلزمات',
                    'finished_good': 'منتج جاهز',
                    'other': 'أخرى',
                  },
                  onChanged: (String value) {
                    setState(() => _type = value);
                    _load();
                  },
                ),
                _StringDropdown(
                  value: _category,
                  label: 'الفئة',
                  options: <String, String>{
                    for (final String category in state.itemCategories)
                      category: category,
                  },
                  onChanged: (String value) {
                    setState(() => _category = value);
                    _load();
                  },
                ),
                _StringDropdown(
                  value: _stockStatus,
                  label: 'حالة المخزون',
                  options: const <String, String>{
                    'in': 'متوفر',
                    'low': 'مخزون منخفض',
                    'out': 'نفد المخزون',
                  },
                  onChanged: (String value) {
                    setState(() => _stockStatus = value);
                    _load();
                  },
                ),
                _StringDropdown(
                  value: _activeStatus,
                  label: 'حالة التفعيل',
                  options: const <String, String>{
                    'active': 'نشط',
                    'inactive': 'غير نشط',
                  },
                  onChanged: (String value) {
                    setState(() => _activeStatus = value);
                    _load();
                  },
                ),
                IconButton(
                  tooltip: 'تطبيق المرشحات',
                  onPressed: _load,
                  icon: const Icon(Icons.filter_alt_outlined),
                ),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('مسح المرشحات'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: state.loading && state.items.isEmpty
                  ? const _LoadingSkeleton()
                  : state.error != null && state.items.isEmpty
                  ? _LoadState(
                      loading: false,
                      error: state.error,
                      onRetry: _load,
                    )
                  : state.items.isEmpty
                  ? const _EmptyState(
                      message: 'لا توجد مواد تطابق المرشحات المحددة.',
                    )
                  : Column(
                      children: <Widget>[
                        Expanded(
                          child: _ItemsTable(
                            items: state.items,
                            onOpen: (InventoryItem item) => context.go(
                              AppRoutes.inventoryItemDetailPath(item.id),
                            ),
                            onEdit: (InventoryItem item) => _showItemDialog(
                              context,
                              current: item,
                              categories: state.itemCategories,
                              units: state.units,
                              onSaved: _load,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ItemsPagination(
                          page: state.itemsPage,
                          lastPage: state.itemsLastPage,
                          total: state.itemsTotal,
                          onPageChanged: _loadPage,
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    ),
  );

  void _load() => _loadPage(1);

  void _loadPage(int page) => context.read<InventoryCubit>().loadItems(
    search: _query.trim(),
    type: _type,
    category: _category,
    status: _activeStatus,
    stockStatus: _stockStatus,
    page: page,
  );

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _type = '';
      _category = '';
      _activeStatus = '';
      _stockStatus = '';
    });
    _load();
  }
}

class InventoryUnitConversionsScreen extends StatefulWidget {
  const InventoryUnitConversionsScreen({super.key});

  @override
  State<InventoryUnitConversionsScreen> createState() =>
      _InventoryUnitConversionsState();
}

class _InventoryUnitConversionsState
    extends State<InventoryUnitConversionsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final InventoryItem? item = _firstOrNull<InventoryItem>(
          state.conversionItems.where(
            (InventoryItem entry) => entry.id == state.selectedConversionItemId,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ManagementPageHeader(
              title: 'الوحدات والتحويلات',
              subtitle: 'تحديد تحويلات التغليف والقياس الخاصة بكل مادة.',
              actions: <Widget>[
                AppButton(
                  label: 'إضافة تحويل',
                  icon: Icons.add,
                  onPressed: item == null
                      ? null
                      : () => _showUnitConversionDialog(
                          context,
                          item: item,
                          units: state.units,
                          onSaved: _load,
                        ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ManagementFilterBar(
              children: <Widget>[
                _ItemDropdown(
                  value: state.selectedConversionItemId,
                  items: state.conversionItems,
                  allowAll: false,
                  onChanged: (int? value) {
                    if (value != null) _load(value);
                  },
                ),
                if (item != null) _ConversionBaseUnit(unit: item.unit),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: state.loading && state.conversionItems.isEmpty
                  ? const _LoadingSkeleton()
                  : state.error != null && state.conversionItems.isEmpty
                  ? _LoadState(
                      loading: false,
                      error: state.error,
                      onRetry: _load,
                    )
                  : item == null
                  ? const _EmptyState(
                      message: 'أنشئ مادة مخزنية نشطة قبل إضافة التحويلات.',
                    )
                  : state.conversions.isEmpty
                  ? _EmptyState(
                      message:
                          'لا توجد تحويلات معرفة لـ ${item.name}. أضف تحويلًا عند الشراء أو الجرد بوحدة مختلفة.',
                    )
                  : _UnitConversionsTable(
                      conversions: state.conversions,
                      onEdit: (InventoryItemUnitConversion conversion) =>
                          _showUnitConversionDialog(
                            context,
                            item: item,
                            units: state.units,
                            current: conversion,
                            onSaved: _load,
                          ),
                    ),
            ),
          ],
        );
      },
    ),
  );

  void _load([int? itemId]) =>
      context.read<InventoryCubit>().loadUnitConversions(itemId: itemId);
}

class _ConversionBaseUnit extends StatelessWidget {
  const _ConversionBaseUnit({required this.unit});
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: AppSpacing.horizontalMd,
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(AppRadius.md),
      color: AppColors.surface,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.straighten_outlined, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text('الوحدة الأساسية: ${_unitLabel(unit)}'),
      ],
    ),
  );
}

class _UnitConversionsTable extends StatelessWidget {
  const _UnitConversionsTable({
    required this.conversions,
    required this.onEdit,
  });
  final List<InventoryItemUnitConversion> conversions;
  final ValueChanged<InventoryItemUnitConversion> onEdit;

  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 760,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('من وحدة')),
        DataColumn(label: Text('يساوي')),
        DataColumn(label: Text('إلى وحدة')),
        DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('الإجراءات')),
      ],
      rows: conversions
          .map(
            (InventoryItemUnitConversion conversion) => DataRow(
              cells: <DataCell>[
                DataCell(Text(conversion.sourceLabel)),
                DataCell(
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      '1 ${conversion.sourceLabel} = ${_factorLabel(conversion.factor)} ${conversion.targetLabel}',
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                DataCell(Text(conversion.targetLabel)),
                DataCell(
                  ManagementBadge(
                    label: conversion.active ? 'نشط' : 'غير نشط',
                    tone: conversion.active
                        ? ManagementTone.success
                        : ManagementTone.neutral,
                  ),
                ),
                DataCell(
                  IconButton(
                    tooltip: 'تعديل التحويل',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEdit(conversion),
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    ),
  );
}

String _factorLabel(String value) {
  final double? factor = double.tryParse(value);
  if (factor == null) return value;
  return factor == factor.roundToDouble()
      ? factor.toInt().toString()
      : factor.toString();
}

Future<void> _showUnitConversionDialog(
  BuildContext context, {
  required InventoryItem item,
  required List<InventoryUnit> units,
  InventoryItemUnitConversion? current,
  VoidCallback? onSaved,
}) async {
  final InventoryCubit cubit = context.read<InventoryCubit>();
  final List<InventoryUnit> availableUnits = units.isEmpty
      ? InventoryUnit.fallback
      : units;
  String sourceUnit =
      current?.sourceUnit ??
      availableUnits
          .firstWhere(
            (InventoryUnit unit) => unit.code != item.unit,
            orElse: () => availableUnits.first,
          )
          .code;
  String targetUnit = current?.targetUnit ?? item.unit;
  bool active = current?.active ?? true;
  final TextEditingController factor = TextEditingController(
    text: _factorLabel(current?.factor ?? ''),
  );

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext dialogContext, StateSetter setDialogState) =>
          AlertDialog(
            title: Text(
              current == null ? 'إضافة تحويل وحدة' : 'تعديل تحويل وحدة',
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.name, style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'الوحدة الأساسية: ${_unitLabel(item.unit)}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('من وحدة', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _UnitSelector(
                    value: sourceUnit,
                    units: availableUnits,
                    onChanged: (String value) =>
                        setDialogState(() => sourceUnit = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TextInput(
                    controller: factor,
                    label: 'الكمية المكافئة',
                    number: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('إلى وحدة', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  _UnitSelector(
                    value: targetUnit,
                    units: availableUnits,
                    onChanged: (String value) =>
                        setDialogState(() => targetUnit = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تحويل نشط'),
                    value: active,
                    onChanged: (bool value) =>
                        setDialogState(() => active = value),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              AppButton(
                label: current == null ? 'إضافة التحويل' : 'حفظ التغييرات',
                icon: Icons.save_outlined,
                onPressed: () async {
                  if (sourceUnit == targetUnit ||
                      (double.tryParse(factor.text.trim()) ?? 0) <= 0) {
                    _notice(
                      dialogContext,
                      'اختر وحدتين مختلفتين وأدخل كمية أكبر من صفر.',
                      error: true,
                    );
                    return;
                  }
                  final bool saved = await cubit
                      .saveUnitConversion(item.id, <String, dynamic>{
                        'sourceUnit': sourceUnit,
                        'targetUnit': targetUnit,
                        'factor': factor.text.trim(),
                        'isActive': active,
                      }, id: current?.id);
                  if (!dialogContext.mounted) return;
                  if (saved) {
                    Navigator.pop(dialogContext);
                    onSaved?.call();
                  } else {
                    _notice(
                      dialogContext,
                      'تعذر حفظ التحويل. تحقق من الوحدات وحاول مجددًا.',
                      error: true,
                    );
                  }
                },
              ),
            ],
          ),
    ),
  );
  factor.dispose();
}

class InventoryItemDetailsScreen extends StatefulWidget {
  const InventoryItemDetailsScreen({super.key, required this.itemId});
  final int itemId;
  @override
  State<InventoryItemDetailsScreen> createState() =>
      _InventoryItemDetailsState();
}

class _InventoryItemDetailsState extends State<InventoryItemDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() => cubit.loadItemDetails(widget.itemId));
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final InventoryItem? item = state.selectedItem;
        if (item == null || item.id != widget.itemId) {
          return _LoadState(
            loading: state.loading,
            error: state.error,
            onRetry: () =>
                context.read<InventoryCubit>().loadItemDetails(widget.itemId),
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Breadcrumb(item: item),
              const SizedBox(height: AppSpacing.md),
              ManagementPageHeader(
                title: item.name,
                subtitle:
                    '${item.sku} · ${_itemType(item.itemType)} · ${_unitLabel(item.unit)}',
                actions: <Widget>[
                  AppButton(
                    label: 'العودة للمواد',
                    icon: Icons.arrow_back,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(AppRoutes.inventoryItems),
                  ),
                  AppButton(
                    label: 'تعديل المادة',
                    icon: Icons.edit_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => _showItemDialog(context, current: item),
                  ),
                  AppButton(
                    label: 'إضافة حركة',
                    icon: Icons.add,
                    onPressed: () =>
                        context.go(AppRoutes.inventoryMovementCreate),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Wrap(
                  spacing: AppSpacing.xxl,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    _Detail('رمز المادة', item.sku),
                    _Detail('الفئة', _englishCategory(item.category)),
                    _Detail('الوحدة', _unitLabel(item.unit)),
                    _Detail('متوسط التكلفة', _money(item.cost)),
                    _StatusBadge(active: item.active),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) => Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children:
                      <Widget>[
                            _Kpi(
                              label: 'إجمالي الكمية',
                              value:
                                  '${_number(item.quantity, digits: 3)} ${_unitLabel(item.unit)}',
                              icon: Icons.inventory_2_outlined,
                            ),
                            _Kpi(
                              label: 'إجمالي القيمة',
                              value: _money(item.totalValue),
                              icon: Icons.payments_outlined,
                            ),
                            _Kpi(
                              label: 'حد إعادة الطلب',
                              value:
                                  '${_number(item.reorderLevel, digits: 3)} ${_unitLabel(item.unit)}',
                              icon: Icons.reorder_outlined,
                            ),
                            _Kpi(
                              label: 'آخر حركة',
                              value: state.itemMovements.isEmpty
                                  ? 'لا توجد حركة'
                                  : _shortDate(
                                      state.itemMovements.first.occurredAt,
                                    ),
                              icon: Icons.schedule_outlined,
                            ),
                          ]
                          .map(
                            (Widget card) => SizedBox(
                              width: constraints.maxWidth < 900
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - AppSpacing.lg * 3) /
                                        4,
                              child: card,
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader(title: 'أرصدة المخازن'),
              const SizedBox(height: AppSpacing.sm),
              item.balances.isEmpty
                  ? const _EmptyState(
                      message: 'لا توجد أرصدة مخازن لهذه المادة بعد.',
                    )
                  : _ItemBalancesTable(items: item.balances),
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader(title: 'سجل الحركات الأخير'),
              const SizedBox(height: AppSpacing.sm),
              state.itemMovements.isEmpty
                  ? const _EmptyState(
                      message: 'لا توجد حركات مخزون لهذه المادة.',
                    )
                  : _ItemMovementHistory(items: state.itemMovements),
            ],
          ),
        );
      },
    ),
  );
}

class InventoryBalancesScreen extends StatefulWidget {
  const InventoryBalancesScreen({super.key});
  @override
  State<InventoryBalancesScreen> createState() => _InventoryBalancesState();
}

class _InventoryBalancesState extends State<InventoryBalancesScreen> {
  static const int _rowsPerPage = 5;
  int? _warehouseId;
  String _query = '';
  String _status = '';
  int _page = 1;
  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(cubit.loadBalances);
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final List<InventoryBalance> rows = state.balances;
        final int lastPage = (rows.length + _rowsPerPage - 1) ~/ _rowsPerPage;
        final int page = lastPage == 0 ? 1 : _page.clamp(1, lastPage);
        final List<InventoryBalance> pageRows = rows
            .skip((page - 1) * _rowsPerPage)
            .take(_rowsPerPage)
            .toList(growable: false);
        final double value = rows.fold<double>(
          0,
          (double sum, InventoryBalance balance) =>
              sum + (double.tryParse(balance.value) ?? 0),
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ManagementPageHeader(
                title: 'أرصدة المخازن',
                subtitle: 'عرض الكميات المتاحة وقيمتها في كل مخزن.',
              ),
              const SizedBox(height: AppSpacing.lg),
              ManagementFilterBar(
                children: <Widget>[
                  _WarehouseDropdown(
                    value: _warehouseId,
                    warehouses: state.warehouses,
                    onChanged: (int? value) {
                      setState(() => _warehouseId = value);
                      _load();
                    },
                  ),
                  _SearchField(
                    hint: 'البحث في المواد المخزنية',
                    onChanged: (String value) => _query = value,
                    onSubmitted: (_) => _load(),
                  ),
                  _StringDropdown(
                    value: _status,
                    label: 'حالة المخزون',
                    options: const <String, String>{
                      'low': 'مخزون منخفض',
                      'out': 'نفد المخزون',
                    },
                    onChanged: (String value) {
                      setState(() => _status = value);
                      _load();
                    },
                  ),
                  IconButton(
                    tooltip: 'تطبيق المرشحات',
                    onPressed: _load,
                    icon: const Icon(Icons.filter_alt_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final List<Widget> cards = <Widget>[
                    _Kpi(
                      label: 'قيمة المخزون',
                      value: _money('$value'),
                      icon: Icons.account_balance_wallet_outlined,
                      compact: true,
                    ),
                    _Kpi(
                      label: 'مواد منخفضة المخزون',
                      value:
                          '${rows.where((InventoryBalance row) => row.low).length}',
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.discountOrangeBadge,
                      compact: true,
                    ),
                    _Kpi(
                      label: 'مواد متاحة',
                      value:
                          '${rows.where((InventoryBalance row) => (double.tryParse(row.available) ?? 0) > 0).length}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.discountGreenBadge,
                      compact: true,
                    ),
                  ];

                  if (constraints.maxWidth < 760) {
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: cards
                          .map(
                            (Widget card) => SizedBox(
                              width: constraints.maxWidth,
                              child: card,
                            ),
                          )
                          .toList(),
                    );
                  }

                  return Row(
                    children: cards
                        .expand(
                          (Widget card) => <Widget>[
                            Expanded(child: card),
                            const SizedBox(width: AppSpacing.md),
                          ],
                        )
                        .take(cards.length * 2 - 1)
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              state.loading && rows.isEmpty
                  ? const _LoadingSkeleton()
                  : state.error != null && rows.isEmpty
                  ? _LoadState(
                      loading: false,
                      error: state.error,
                      onRetry: _load,
                    )
                  : rows.isEmpty
                  ? const _EmptyState(
                      message: 'لا توجد أرصدة للمرشحات المحددة.',
                    )
                  : Column(
                      children: <Widget>[
                        _BalancesTable(
                          items: pageRows,
                          onOpen: (InventoryBalance balance) => context.go(
                            AppRoutes.inventoryItemDetailPath(balance.itemId),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _BalancesPagination(
                          page: page,
                          lastPage: lastPage,
                          total: rows.length,
                          visibleCount: pageRows.length,
                          onPageChanged: (int value) =>
                              setState(() => _page = value),
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    ),
  );

  void _load() {
    setState(() => _page = 1);
    context.read<InventoryCubit>().loadBalances(
      warehouseId: _warehouseId,
      search: _query,
      stockStatus: _status,
    );
  }
}

class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({super.key});
  @override
  State<InventoryMovementsScreen> createState() => _InventoryMovementsState();
}

class _InventoryMovementsState extends State<InventoryMovementsScreen> {
  int? _warehouseId;
  int? _itemId;
  String _type = '';
  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() {
      cubit.loadMovements();
      cubit.loadBalances();
    });
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) =>
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ManagementPageHeader(
                  title: 'حركات المخزون',
                  subtitle: 'سجل كامل قابل للتدقيق لجميع نشاطات المخزون.',
                  actions: <Widget>[
                    AppButton(
                      label: 'إضافة حركة',
                      icon: Icons.add,
                      onPressed: () =>
                          context.go(AppRoutes.inventoryMovementCreate),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ManagementFilterBar(
                  children: <Widget>[
                    const _ReadOnlyFilter(
                      label: 'كل التواريخ',
                      icon: Icons.date_range_outlined,
                    ),
                    _WarehouseDropdown(
                      value: _warehouseId,
                      warehouses: state.warehouses,
                      onChanged: (int? value) {
                        setState(() => _warehouseId = value);
                        _load();
                      },
                    ),
                    _ItemDropdown(
                      value: _itemId,
                      items: state.items,
                      onChanged: (int? value) {
                        setState(() => _itemId = value);
                        _load();
                      },
                    ),
                    _StringDropdown(
                      value: _type,
                      label: 'نوع الحركة',
                      options: const <String, String>{
                        'stock_in': 'إدخال مخزون',
                        'stock_out': 'إخراج مخزون',
                        'waste': 'هالك',
                        'adjustment_in': 'تسوية',
                        'stock_count_variance': 'فرق جرد',
                        'transfer_in': 'تحويل',
                      },
                      onChanged: (String value) {
                        setState(() => _type = value);
                        _load();
                      },
                    ),
                    const _ReadOnlyFilter(
                      label: 'كل الموظفين',
                      icon: Icons.person_outline,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                state.loading && state.movements.isEmpty
                    ? const _LoadingSkeleton()
                    : state.error != null && state.movements.isEmpty
                    ? _LoadState(
                        loading: false,
                        error: state.error,
                        onRetry: _load,
                      )
                    : state.movements.isEmpty
                    ? const _EmptyState(
                        message: 'لا توجد حركات تطابق المرشحات المحددة.',
                      )
                    : Column(
                        children: <Widget>[
                          _MovementsTable(items: state.movements),
                          const SizedBox(height: AppSpacing.md),
                          _MovementsPagination(
                            page: state.movementsPage,
                            lastPage: state.movementsLastPage,
                            total: state.movementsTotal,
                            visibleCount: state.movements.length,
                            onPageChanged: _load,
                          ),
                        ],
                      ),
              ],
            ),
          ),
    ),
  );

  void _load([int page = 1]) => context.read<InventoryCubit>().loadMovements(
    warehouseId: _warehouseId,
    itemId: _itemId,
    type: _type,
    page: page,
  );
}

class InventoryMovementCreateScreen extends StatefulWidget {
  const InventoryMovementCreateScreen({super.key});
  @override
  State<InventoryMovementCreateScreen> createState() =>
      _InventoryMovementCreateState();
}

class _InventoryMovementCreateState
    extends State<InventoryMovementCreateScreen> {
  int? _warehouseId;
  int? _itemId;
  String _type = 'stock_in';
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() {
      cubit.loadMovements();
      cubit.loadBalances();
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final InventoryItem? item = _itemId == null
            ? null
            : _firstOrNull<InventoryItem>(
                state.items.where((InventoryItem entry) => entry.id == _itemId),
              );
        final InventoryBalance? balance = item == null || _warehouseId == null
            ? null
            : _firstOrNull<InventoryBalance>(
                state.balances.where(
                  (InventoryBalance entry) =>
                      entry.itemId == item.id &&
                      entry.warehouseId == _warehouseId,
                ),
              );
        final double quantity = double.tryParse(_quantity.text) ?? 0;
        final double available =
            double.tryParse(balance?.available ?? item?.quantity ?? '0') ?? 0;
        final double after = _isOutbound(_type)
            ? available - quantity
            : available + quantity;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ManagementPageHeader(
                  title: 'إضافة حركة مخزون',
                  subtitle: 'تسجيل تغيير مخزني مضبوط مع سجل تدقيق كامل.',
                  actions: <Widget>[
                    AppButton(
                      label: 'العودة للسجل',
                      icon: Icons.arrow_back,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go(AppRoutes.inventoryMovements),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('نوع الحركة', style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children:
                            <String>['stock_in', 'waste', 'adjustment_out']
                                .map(
                                  (String type) => _MovementTypeCard(
                                    type: type,
                                    selected: _type == type,
                                    onTap: () => setState(() => _type = type),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      LayoutBuilder(
                        builder:
                            (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) => Wrap(
                              spacing: AppSpacing.lg,
                              runSpacing: AppSpacing.lg,
                              children: <Widget>[
                                SizedBox(
                                  width: constraints.maxWidth < 680
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - AppSpacing.lg) /
                                            2,
                                  child: _WarehouseDropdown(
                                    value: _warehouseId,
                                    warehouses: state.warehouses,
                                    onChanged: (int? value) =>
                                        setState(() => _warehouseId = value),
                                  ),
                                ),
                                SizedBox(
                                  width: constraints.maxWidth < 680
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - AppSpacing.lg) /
                                            2,
                                  child: _ItemDropdown(
                                    value: _itemId,
                                    items: state.items,
                                    allowAll: false,
                                    onChanged: (int? value) =>
                                        setState(() => _itemId = value),
                                  ),
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (item != null)
                        _BalancePreview(item: item, balance: balance),
                      if (item != null) const SizedBox(height: AppSpacing.lg),
                      LayoutBuilder(
                        builder:
                            (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) => Wrap(
                              spacing: AppSpacing.lg,
                              runSpacing: AppSpacing.lg,
                              children: <Widget>[
                                SizedBox(
                                  width: constraints.maxWidth < 680
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - AppSpacing.lg) /
                                            2,
                                  child: _TextInput(
                                    controller: _quantity,
                                    label: 'الكمية',
                                    number: true,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                if (!_isOutbound(_type))
                                  SizedBox(
                                    width: constraints.maxWidth < 680
                                        ? constraints.maxWidth
                                        : (constraints.maxWidth -
                                                  AppSpacing.lg) /
                                              2,
                                    child: _TextInput(
                                      controller: _cost,
                                      label: 'تكلفة الوحدة',
                                      number: true,
                                    ),
                                  ),
                              ],
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_type == 'waste' ||
                          _type == 'adjustment_out') ...<Widget>[
                        _TextInput(controller: _reason, label: 'السبب (مطلوب)'),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _TextInput(
                        controller: _notes,
                        label: 'ملاحظات (اختياري)',
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ExpectedBalance(
                        after: after,
                        unit: item?.unit ?? 'units',
                        invalid: _isOutbound(_type) && quantity > available,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: state.saving
                            ? 'جارٍ ترحيل الحركة...'
                            : 'ترحيل الحركة',
                        icon: Icons.check_circle_outline,
                        onPressed: state.saving
                            ? null
                            : () => _post(context, available, item?.unit),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _post(
    BuildContext context,
    double available,
    String? unit,
  ) async {
    final InventoryCubit cubit = context.read<InventoryCubit>();
    final double quantity = double.tryParse(_quantity.text) ?? 0;
    if (_warehouseId == null ||
        _itemId == null ||
        quantity <= 0 ||
        ((_type == 'waste' || _type == 'adjustment_out') &&
            _reason.text.trim().isEmpty)) {
      _notice(context, 'أكمل الحقول المطلوبة قبل الترحيل.', error: true);
      return;
    }
    if (_isOutbound(_type) && quantity > available) {
      _notice(context, 'الكمية تتجاوز الرصيد المتاح.', error: true);
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('ترحيل حركة المخزون؟'),
        content: const Text(
          'سينشئ هذا سجلًا غير قابل للتعديل ويحدّث رصيد المخزون المباشر.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'ترحيل الحركة',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final String reason = <String>[
      _reason.text.trim(),
      _notes.text.trim(),
    ].where((String value) => value.isNotEmpty).join(' — ');
    final String key = _idempotencyKey ??=
        'movement-${DateTime.now().microsecondsSinceEpoch}';
    final bool saved = await cubit.postMovement(<String, dynamic>{
      'warehouseId': _warehouseId,
      'itemId': _itemId,
      'type': _type,
      'quantity': _quantity.text.trim(),
      if (unit != null && unit.isNotEmpty) 'unit': unit,
      'idempotencyKey': key,
      if (!_isOutbound(_type) && _cost.text.trim().isNotEmpty)
        'unitCost': _cost.text.trim(),
      if (reason.isNotEmpty) 'reason': reason,
    });
    if (!context.mounted) return;
    if (saved) {
      _idempotencyKey = null;
      _notice(context, 'تم ترحيل حركة المخزون بنجاح.');
      context.go(AppRoutes.inventoryMovements);
    } else {
      _notice(context, _friendlyError(cubit.state.error), error: true);
    }
  }
}

class InventoryCountsScreen extends StatefulWidget {
  const InventoryCountsScreen({super.key});
  @override
  State<InventoryCountsScreen> createState() => _InventoryCountsState();
}

/// Source-shaped destination for the transfer workflow. Its operational data
/// and workspace are introduced with the transfer API in Phase 4.
class InventoryTransfersScreen extends StatelessWidget {
  const InventoryTransfersScreen({super.key});

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'تحويلات المخازن',
            subtitle: 'متابعة التحويلات بين المخازن التشغيلية.',
            actions: <Widget>[
              AppButton(
                label: 'إنشاء تحويل',
                icon: Icons.add,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _EmptyState(
            message: 'لا توجد تحويلات مخزون ضمن النطاق المحدد.',
          ),
        ],
      ),
    ),
  );
}

enum _CountPeriod { all, today, last7Days, currentMonth }

extension on _CountPeriod {
  String get label => switch (this) {
    _CountPeriod.all => 'كل الفترات',
    _CountPeriod.today => 'اليوم',
    _CountPeriod.last7Days => 'آخر 7 أيام',
    _CountPeriod.currentMonth => 'هذا الشهر',
  };

  (String? from, String? to) get range {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return switch (this) {
      _CountPeriod.all => (null, null),
      _CountPeriod.today => (formatter.format(today), formatter.format(today)),
      _CountPeriod.last7Days => (
        formatter.format(today.subtract(const Duration(days: 6))),
        formatter.format(today),
      ),
      _CountPeriod.currentMonth => (
        formatter.format(DateTime(now.year, now.month)),
        formatter.format(today),
      ),
    };
  }
}

class _InventoryCountsState extends State<InventoryCountsScreen> {
  String _status = '';
  int? _warehouseId;
  String _countType = '';
  String _source = '';
  int? _createdBy;
  _CountPeriod _period = _CountPeriod.all;

  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() {
      _loadCounts();
      // Categories are supplied by the live inventory catalog. They are only
      // used to build a cycle count and are never a client-side fallback.
      cubit.loadItems();
    });
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'الجرد المخزني',
            subtitle: 'إدارة الجرد الفعلي ومراجعته وترحيل فروقات المخزون.',
            actions: <Widget>[
              AppButton(
                label: 'بدء جرد جديد',
                icon: Icons.add,
                onPressed: _branchWarehouses(context, state.warehouses).isEmpty
                    ? null
                    : () => _startCount(
                        context,
                        _branchWarehouses(context, state.warehouses),
                        state.itemCategories,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _CountFilters(
            status: _status,
            warehouseId: _warehouseId,
            countType: _countType,
            createdBy: _createdBy,
            period: _period,
            warehouses: _branchWarehouses(context, state.warehouses),
            creators: state.countCreators,
            onStatusChanged: (String value) {
              setState(() => _status = value);
              _loadCounts();
            },
            onWarehouseChanged: (int? value) {
              setState(() => _warehouseId = value);
              _loadCounts();
            },
            onCountTypeChanged: (String value) {
              setState(() => _countType = value);
              _loadCounts();
            },
            onCreatedByChanged: (int? value) {
              setState(() => _createdBy = value);
              _loadCounts();
            },
            onPeriodChanged: (_CountPeriod value) {
              setState(() => _period = value);
              _loadCounts();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _CountSourceSelector(
            value: _source,
            onChanged: (String value) {
              setState(() => _source = value);
              _loadCounts();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _CountKpis(summary: state.countSummary),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: state.loading && state.counts.isEmpty
                ? const _LoadingSkeleton()
                : state.error != null && state.counts.isEmpty
                ? _LoadState(
                    loading: false,
                    error: state.error,
                    onRetry: _loadCounts,
                  )
                : state.counts.isEmpty
                ? const _EmptyState(message: 'لم يُنشأ أي جرد مخزون بعد.')
                : Column(
                    children: <Widget>[
                      Expanded(
                        child: _CountsTable(
                          items: state.counts,
                          onOpen: (InventoryCount count) => context.go(
                            AppRoutes.inventoryCountDetailPath(count.id),
                          ),
                        ),
                      ),
                      if (state.countsLastPage > 1) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        _CountsPagination(
                          page: state.countsPage,
                          lastPage: state.countsLastPage,
                          total: state.countsTotal,
                          onPageChanged: (int page) => _loadCounts(page: page),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    ),
  );

  Future<void> _startCount(
    BuildContext context,
    List<WarehouseLocation> warehouses,
    List<String> categories,
  ) async {
    final InventoryCubit cubit = context.read<InventoryCubit>();
    final StockCountStartRequest? request =
        await showDialog<StockCountStartRequest>(
          context: context,
          builder: (BuildContext dialogContext) => StockCountStartDialog(
            warehouses: warehouses,
            categories: categories,
          ),
        );
    if (request == null || !context.mounted) return;
    final bool saved = await cubit.createCount(<String, dynamic>{
      'warehouseId': request.warehouseId,
      'countDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'countType': request.countType,
      if (request.countType == 'cycle') 'categoryFilters': request.categories,
      if (request.notes.isNotEmpty) 'notes': request.notes,
    });
    if (!context.mounted) return;
    _notice(
      context,
      saved ? 'تم إنشاء مسودة الجرد.' : _friendlyError(cubit.state.error),
      error: !saved,
    );
    if (saved && cubit.state.selectedCount != null) {
      context.go(
        AppRoutes.inventoryCountDetailPath(cubit.state.selectedCount!.id),
      );
    }
  }

  void _loadCounts({int page = 1}) {
    final (String? from, String? to) = _period.range;
    context.read<InventoryCubit>().loadCounts(
      status: _status.isEmpty ? null : _status,
      warehouseId: _warehouseId,
      countType: _countType.isEmpty ? null : _countType,
      source: _source.isEmpty ? null : _source,
      createdBy: _createdBy,
      from: from,
      to: to,
      page: page,
    );
  }
}

class InventoryCountDetailsScreen extends StatefulWidget {
  const InventoryCountDetailsScreen({super.key, required this.countId});
  final int countId;

  @override
  State<InventoryCountDetailsScreen> createState() =>
      _InventoryCountDetailsScreenState();
}

class _InventoryCountDetailsScreenState
    extends State<InventoryCountDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      context.read<InventoryCubit>().loadCountDetails(widget.countId);
      context.read<InventoryCubit>().loadItems(page: 1);
    });
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final InventoryCount? count = state.selectedCount;
        if (count == null || count.id != widget.countId) {
          return _LoadState(
            loading: state.loading,
            error: state.error,
            onRetry: () =>
                context.read<InventoryCubit>().loadCountDetails(widget.countId),
          );
        }
        final bool renderApprovedWorkspace =
            state.selectedCount?.id == widget.countId;
        if (renderApprovedWorkspace) {
          return _StockCountWorkspace(count: count);
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ManagementPageHeader(
                title: 'جرد مخزون #${count.id}',
                subtitle: '${count.warehouseName} · ${_shortDate(count.date)}',
                actions: <Widget>[
                  AppButton(
                    label: 'العودة للجرد',
                    icon: Icons.arrow_back,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(AppRoutes.inventoryCounts),
                  ),
                  if (_countIsEditable(count.status))
                    AppButton(
                      label: 'إضافة مادة مجرّدة',
                      icon: Icons.add,
                      variant: AppButtonVariant.outlined,
                      onPressed: state.items.isEmpty
                          ? null
                          : () => _showCountLineDialog(
                              context,
                              count: count,
                              items: state.items,
                            ),
                    ),
                  if (_countNextAction(count.status) != null)
                    AppButton(
                      label: _countNextActionLabel(count.status),
                      icon: _countNextActionIcon(count.status),
                      onPressed: state.saving
                          ? null
                          : () => _advanceCount(context, count),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Wrap(
                  spacing: AppSpacing.xxl,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    _Detail('المخزن', count.warehouseName),
                    _Detail('تاريخ الجرد', _shortDate(count.date)),
                    _Detail('الحالة', _countStatus(count.status)),
                    _Detail('ملاحظات', count.notes ?? 'لا توجد ملاحظات'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader(title: 'المواد المجردة'),
              const SizedBox(height: AppSpacing.sm),
              count.lines.isEmpty
                  ? const _EmptyState(message: 'لم تُدخل مواد في هذا الجرد.')
                  : _CountLinesTable(lines: count.lines),
            ],
          ),
        );
      },
    ),
  );
}

class StockCountStartRequest {
  const StockCountStartRequest({
    required this.warehouseId,
    required this.countType,
    required this.categories,
    required this.notes,
  });

  final int warehouseId;
  final String countType;
  final List<String> categories;
  final String notes;
}

class StockCountStartDialog extends StatefulWidget {
  const StockCountStartDialog({
    super.key,
    required this.warehouses,
    required this.categories,
  });

  final List<WarehouseLocation> warehouses;
  final List<String> categories;

  @override
  State<StockCountStartDialog> createState() => _StockCountStartDialogState();
}

class _StockCountStartDialogState extends State<StockCountStartDialog> {
  int? _warehouseId;
  String _countType = 'full';
  final Set<String> _categories = <String>{};
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _canStart =>
      _warehouseId != null && (_countType == 'full' || _categories.isNotEmpty);

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
    title: Row(
      children: <Widget>[
        const Expanded(
          child: Text('بدء جرد جديد', style: AppTextStyles.titleMedium),
        ),
        IconButton(
          tooltip: 'إغلاق',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<int>(
              initialValue: _warehouseId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المستودع',
                hintText: 'اختر المستودع…',
              ),
              items: widget.warehouses
                  .map(
                    (WarehouseLocation warehouse) => DropdownMenuItem<int>(
                      value: warehouse.id,
                      child: Text(_warehouseLabel(warehouse)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? value) => setState(() => _warehouseId = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('نوع الجرد', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                _CountTypeOption(
                  label: 'جرد كامل',
                  selected: _countType == 'full',
                  onPressed: () => setState(() => _countType = 'full'),
                ),
                _CountTypeOption(
                  label: 'جرد دوري / جزئي',
                  selected: _countType == 'cycle',
                  onPressed: () => setState(() => _countType = 'cycle'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _countType == 'full'
                  ? 'سيتم جرد جميع عناصر المخزون النشطة المخصصة لهذا المستودع.'
                  : 'سيتم جرد عناصر المخزون النشطة في الفئات المحددة فقط.',
              style: AppTextStyles.bodySmall,
            ),
            if (_countType == 'cycle') ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text('الفئات المراد جردها', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              if (widget.categories.isEmpty)
                const Text(
                  'لا توجد فئات نشطة متاحة للجرد حالياً.',
                  style: AppTextStyles.bodySmall,
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: widget.categories
                      .map(
                        (String category) => FilterChip(
                          label: Text(category),
                          selected: _categories.contains(category),
                          onSelected: (bool selected) => setState(() {
                            if (selected) {
                              _categories.add(category);
                            } else {
                              _categories.remove(category);
                            }
                          }),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                hintText: 'أي تفاصيل إضافية عن هذا الجرد',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      AppButton(
        label: 'بدء الجرد',
        minimumHeight: 42,
        onPressed: _canStart
            ? () => Navigator.pop(
                context,
                StockCountStartRequest(
                  warehouseId: _warehouseId!,
                  countType: _countType,
                  categories: _categories.toList(growable: false),
                  notes: _notesController.text.trim(),
                ),
              )
            : null,
      ),
    ],
  );
}

class _CountTypeOption extends StatelessWidget {
  const _CountTypeOption({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    height: 44,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.primary : AppColors.surface,
        foregroundColor: selected
            ? AppColors.textInverse
            : AppColors.textPrimary,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),
      child: Text(label),
    ),
  );
}

class _StockCountWorkspace extends StatefulWidget {
  const _StockCountWorkspace({required this.count});
  final InventoryCount count;

  @override
  State<_StockCountWorkspace> createState() => _StockCountWorkspaceState();
}

class _StockCountWorkspaceState extends State<_StockCountWorkspace> {
  String _search = '';
  String _filter = 'all';
  final Map<int, String> _pendingCountedQuantities = <int, String>{};
  final Map<int, String> _pendingReasons = <int, String>{};
  final Map<int, Timer> _lineSaveTimers = <int, Timer>{};
  final Map<int, String> _lineErrors = <int, String>{};

  @override
  void dispose() {
    for (final Timer timer in _lineSaveTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final InventoryCount count = widget.count;
    final InventoryState state = context.watch<InventoryCubit>().state;
    final bool editable = _countIsEditable(count.status);
    final List<InventoryCountLine> lines = count.lines
        .where((line) {
          final String query = _search.trim().toLowerCase();
          final bool matchesQuery =
              query.isEmpty ||
              line.itemName.toLowerCase().contains(query) ||
              line.sku.toLowerCase().contains(query);
          final bool hasVariance =
              (double.tryParse(line.varianceQuantity) ?? 0).abs() > 0.0001;
          final bool matchesFilter = switch (_filter) {
            'counted' => line.isCounted && !hasVariance,
            'remaining' => !line.isCounted,
            'variance' => hasVariance,
            'reason_required' =>
              line.isCounted && hasVariance && line.reason == null,
            _ => true,
          };
          return matchesQuery && matchesFilter;
        })
        .toList(growable: false);
    final int counted = count.lines
        .where(
          (InventoryCountLine line) =>
              line.isCounted ||
              _pendingCountedQuantities.containsKey(line.itemId),
        )
        .length;
    final int variance = count.lines
        .where(
          (line) =>
              (double.tryParse(line.varianceQuantity) ?? 0).abs() > 0.0001,
        )
        .length;
    final bool hasMissingVarianceReason = count.lines.any(
      (InventoryCountLine line) =>
          line.isCounted &&
          (double.tryParse(line.varianceQuantity) ?? 0).abs() > 0.0001 &&
          (line.reason?.trim().isEmpty ?? true),
    );
    final String varianceValue = count.lines
        .fold<double>(
          0,
          (sum, line) => sum + (double.tryParse(line.varianceValue) ?? 0),
        )
        .toStringAsFixed(2);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: <Widget>[
                TextButton(
                  onPressed: () => context.go(AppRoutes.inventoryCounts),
                  child: const Text('إدارة المخزون'),
                ),
                const Text('/'),
                TextButton(
                  onPressed: () => context.go(AppRoutes.inventoryCounts),
                  child: const Text('الجرد المخزني'),
                ),
                const Text('/'),
                Text(count.number, style: AppTextStyles.labelLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.xxl,
                          runSpacing: AppSpacing.md,
                          children: <Widget>[
                            _Detail('رقم الجرد', count.number),
                            _Detail('المستودع', count.warehouseName),
                            _Detail(
                              'نوع الجرد',
                              count.countType == 'cycle'
                                  ? 'دوري / جزئي'
                                  : 'كامل',
                            ),
                            _CountStatusDetail(status: count.status),
                            _Detail('بدأ بواسطة', count.createdByName ?? '—'),
                            _Detail('بدأ في', _shortDate(count.date)),
                          ],
                        ),
                      ),
                      if (editable)
                        TextButton(
                          onPressed: () => _cancel(context, count),
                          child: const Text(
                            'إلغاء الجرد',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                  if (count.notes != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'ملاحظات: ${count.notes}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _WorkspaceKpis(
              total: count.lines.length,
              counted: counted,
              variance: variance,
              varianceValue: varianceValue,
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget filters = Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final (String key, String label) in <(String, String)>[
                      ('all', 'الكل'),
                      ('remaining', 'غير معدود'),
                      ('counted', 'مطابق'),
                      ('variance', 'يوجد فرق'),
                      ('reason_required', 'بحاجة لسبب'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _filter == key,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppColors.paginationActive,
                        labelStyle: TextStyle(
                          color: _filter == key
                              ? AppColors.surface
                              : AppColors.textPrimary,
                        ),
                        onSelected: (_) => setState(() => _filter = key),
                      ),
                  ],
                );
                final Widget search = SizedBox(
                  width: constraints.maxWidth > 900 ? 300 : double.infinity,
                  child: TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'بحث عن عنصر أو رمز SKU...',
                    ),
                  ),
                );
                return AppCard(
                  padding: AppSpacing.allMd,
                  child: constraints.maxWidth > 900
                      ? Directionality(
                          textDirection: ui.TextDirection.ltr,
                          child: Row(
                            children: <Widget>[
                              Expanded(child: filters),
                              const SizedBox(width: AppSpacing.md),
                              search,
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            filters,
                            const SizedBox(height: AppSpacing.md),
                            search,
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            lines.isEmpty
                ? const _EmptyState(
                    message: 'لا توجد أسطر مطابقة للبحث أو التصفية.',
                  )
                : _WorkspaceLinesTable(
                    lines: lines,
                    editable: editable,
                    pendingCountedQuantities: _pendingCountedQuantities,
                    lineErrors: _lineErrors,
                    onCountedChanged: (InventoryCountLine line, String value) =>
                        _queueQuantitySave(context, count, line, value),
                    onCountedSubmitted:
                        (InventoryCountLine line, String value) =>
                            _saveQuantityNow(context, count, line, value),
                    onReasonChanged: (InventoryCountLine line, String value) =>
                        _queueReasonSave(context, count, line, value),
                  ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  Text(
                    _saveStatusMessage(
                      state,
                      editable,
                      count.status,
                      hasMissingVarianceReason,
                    ),
                    style: AppTextStyles.bodySmall,
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      if (editable)
                        AppButton(
                          label: 'حفظ كمسودة',
                          variant: AppButtonVariant.outlined,
                          onPressed: state.saving
                              ? null
                              : () => _saveDraft(context, count),
                        ),
                      if (count.status == 'draft')
                        AppButton(
                          label: 'بدء الجرد',
                          onPressed: state.saving
                              ? null
                              : () => _advanceCount(context, count),
                        ),
                      if (count.status == 'in_progress')
                        AppButton(
                          label: 'إرسال للمراجعة',
                          onPressed:
                              !state.saving &&
                                  counted == count.lines.length &&
                                  count.lines.isNotEmpty &&
                                  !hasMissingVarianceReason
                              ? () => _submitForReview(context, count)
                              : null,
                        ),
                      if (count.status == 'submitted')
                        AppButton(
                          label: 'اعتماد الجرد',
                          icon: Icons.verified_outlined,
                          onPressed: state.saving
                              ? null
                              : () => _advanceCount(context, count),
                        ),
                      if (count.status == 'approved')
                        AppButton(
                          label: 'ترحيل الفروقات',
                          icon: Icons.post_add_outlined,
                          onPressed: state.saving
                              ? null
                              : () => _advanceCount(context, count),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForReview(
    BuildContext context,
    InventoryCount count,
  ) async {
    if (!await _flushPendingSaves(context, count) || !context.mounted) return;
    final InventoryCount latest =
        context.read<InventoryCubit>().state.selectedCount ?? count;
    final bool submitted = await context.read<InventoryCubit>().countAction(
      latest.id,
      'submit',
    );
    if (!context.mounted) return;
    _notice(
      context,
      submitted
          ? 'تم إرسال الجرد للمراجعة.'
          : _friendlyError(context.read<InventoryCubit>().state.error),
      error: !submitted,
    );
  }

  String _saveStatusMessage(
    InventoryState state,
    bool editable,
    String countStatus,
    bool hasMissingVarianceReason,
  ) {
    if (!editable) return _countStatus(countStatus);
    if (state.countLineSaveStatus == InventoryCountLineSaveStatus.saving) {
      return 'جارٍ حفظ التغييرات…';
    }
    if (state.countLineSaveStatus == InventoryCountLineSaveStatus.saved) {
      return 'تم الحفظ تلقائياً.';
    }
    if (state.countLineSaveStatus == InventoryCountLineSaveStatus.failed) {
      return 'تعذر الحفظ. راجع الكمية أو أعد المحاولة.';
    }
    return hasMissingVarianceReason
        ? 'أدخل سبباً لكل فرق كمية قبل الإرسال للمراجعة.'
        : 'تُحفظ التغييرات تلقائياً بعد التوقف عن الكتابة.';
  }

  void _queueQuantitySave(
    BuildContext context,
    InventoryCount count,
    InventoryCountLine line,
    String value,
  ) {
    final String quantity = value.trim();
    _lineSaveTimers.remove(line.itemId)?.cancel();
    setState(() {
      if (quantity.isEmpty) {
        _pendingCountedQuantities.remove(line.itemId);
        _lineErrors.remove(line.itemId);
        return;
      }
      _pendingCountedQuantities[line.itemId] = quantity;
      if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(quantity)) {
        _lineErrors[line.itemId] = 'أدخل رقماً غير سالب حتى 3 منازل عشرية';
      } else {
        _lineErrors.remove(line.itemId);
      }
    });
    if (_lineErrors.containsKey(line.itemId)) return;
    _lineSaveTimers[line.itemId] = Timer(
      const Duration(milliseconds: 600),
      () => _saveQuantityNow(context, count, line, quantity),
    );
  }

  void _queueReasonSave(
    BuildContext context,
    InventoryCount count,
    InventoryCountLine line,
    String value,
  ) {
    _pendingReasons[line.itemId] = value.trim();
    final String? pendingQuantity = _pendingCountedQuantities[line.itemId];
    if (pendingQuantity != null) {
      _queueQuantitySave(context, count, line, pendingQuantity);
      return;
    }
    if (!line.isCounted) return;
    _lineSaveTimers.remove(line.itemId)?.cancel();
    _lineSaveTimers[line.itemId] = Timer(
      const Duration(milliseconds: 600),
      () => _saveQuantityNow(context, count, line, line.countedQuantity),
    );
  }

  Future<void> _saveQuantityNow(
    BuildContext context,
    InventoryCount count,
    InventoryCountLine line,
    String value,
  ) async {
    final String quantity = value.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(quantity)) return;
    _lineSaveTimers.remove(line.itemId)?.cancel();
    final String? pendingReason = _pendingReasons[line.itemId];
    final bool saved = await context
        .read<InventoryCubit>()
        .saveCountLine(count.id, <String, dynamic>{
          'itemId': line.itemId,
          'countedQuantity': quantity,
          if (line.countUnit != null) 'unit': line.countUnit,
          if (pendingReason != null || line.reason != null)
            'reason': pendingReason ?? line.reason,
        });
    if (!mounted) return;
    setState(() {
      if (saved) {
        _pendingCountedQuantities.remove(line.itemId);
        _pendingReasons.remove(line.itemId);
      }
    });
  }

  Future<bool> _flushPendingSaves(
    BuildContext context,
    InventoryCount count,
  ) async {
    if (_lineErrors.isNotEmpty) {
      _notice(context, 'صحح الكميات غير الصالحة قبل المتابعة.', error: true);
      return false;
    }
    final Set<int> pendingLineIds = <int>{
      ..._pendingCountedQuantities.keys,
      ..._pendingReasons.keys,
    };
    for (final Timer timer in _lineSaveTimers.values) {
      timer.cancel();
    }
    _lineSaveTimers.clear();
    for (final int itemId in pendingLineIds) {
      final InventoryCountLine line = count.lines.firstWhere(
        (InventoryCountLine item) => item.itemId == itemId,
      );
      final String? pendingQuantity = _pendingCountedQuantities[itemId];
      final String quantity = pendingQuantity ?? line.countedQuantity;
      await _saveQuantityNow(context, count, line, quantity);
      if (!mounted || !context.mounted) return false;
      final InventoryCubit cubit = context.read<InventoryCubit>();
      if (cubit.state.countLineSaveStatus ==
          InventoryCountLineSaveStatus.failed) {
        _notice(context, _friendlyError(cubit.state.error), error: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _saveDraft(BuildContext context, InventoryCount count) async {
    final bool saved = await _flushPendingSaves(context, count);
    if (!context.mounted) return;
    _notice(
      context,
      saved
          ? 'تم حفظ مسودة الجرد.'
          : _friendlyError(context.read<InventoryCubit>().state.error),
      error: !saved,
    );
  }

  Future<void> _cancel(BuildContext context, InventoryCount count) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الجرد؟'),
        content: const Text('لن تتمكن من متابعة هذا الجرد بعد إلغائه.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          AppButton(
            label: 'إلغاء الجرد',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<InventoryCubit>().countAction(count.id, 'cancel');
    if (!context.mounted) return;
    context.go(AppRoutes.inventoryCounts);
  }
}

class _CountFilters extends StatelessWidget {
  const _CountFilters({
    required this.status,
    required this.warehouseId,
    required this.countType,
    required this.createdBy,
    required this.period,
    required this.warehouses,
    required this.creators,
    required this.onStatusChanged,
    required this.onWarehouseChanged,
    required this.onCountTypeChanged,
    required this.onCreatedByChanged,
    required this.onPeriodChanged,
  });

  final String status;
  final int? warehouseId;
  final String countType;
  final int? createdBy;
  final _CountPeriod period;
  final List<WarehouseLocation> warehouses;
  final List<InventoryCountCreator> creators;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<int?> onWarehouseChanged;
  final ValueChanged<String> onCountTypeChanged;
  final ValueChanged<int?> onCreatedByChanged;
  final ValueChanged<_CountPeriod> onPeriodChanged;

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  );

  @override
  Widget build(BuildContext context) => ManagementFilterBar(
    children: <Widget>[
      SizedBox(
        width: 210,
        child: DropdownButtonFormField<_CountPeriod>(
          initialValue: period,
          isExpanded: true,
          decoration: _decoration('الفترة'),
          items: _CountPeriod.values
              .map(
                (_CountPeriod value) => DropdownMenuItem<_CountPeriod>(
                  value: value,
                  child: _DropdownSelection(value.label),
                ),
              )
              .toList(growable: false),
          onChanged: (_CountPeriod? value) {
            if (value != null) onPeriodChanged(value);
          },
        ),
      ),
      SizedBox(
        width: 230,
        child: DropdownButtonFormField<int?>(
          initialValue:
              warehouses.any((WarehouseLocation item) => item.id == warehouseId)
              ? warehouseId
              : null,
          isExpanded: true,
          decoration: _decoration('المستودع'),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
              value: null,
              child: _DropdownSelection('كل المستودعات'),
            ),
            ...warehouses.map(
              (WarehouseLocation warehouse) => DropdownMenuItem<int?>(
                value: warehouse.id,
                child: _DropdownSelection(_warehouseLabel(warehouse)),
              ),
            ),
          ],
          onChanged: onWarehouseChanged,
        ),
      ),
      SizedBox(
        width: 200,
        child: DropdownButtonFormField<String>(
          initialValue: countType,
          isExpanded: true,
          decoration: _decoration('نوع الجرد'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(
              value: '',
              child: _DropdownSelection('كل الأنواع'),
            ),
            DropdownMenuItem(
              value: 'full',
              child: _DropdownSelection('جرد كامل'),
            ),
            DropdownMenuItem(
              value: 'cycle',
              child: _DropdownSelection('جرد دوري / جزئي'),
            ),
            DropdownMenuItem(
              value: 'shift_check',
              child: _DropdownSelection('فحص شيفت POS'),
            ),
          ],
          onChanged: (String? value) => onCountTypeChanged(value ?? ''),
        ),
      ),
      SizedBox(
        width: 210,
        child: DropdownButtonFormField<String>(
          initialValue: status,
          isExpanded: true,
          decoration: _decoration('الحالة'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(
              value: '',
              child: _DropdownSelection('كل الحالات'),
            ),
            DropdownMenuItem(
              value: 'draft',
              child: _DropdownSelection('مسودة'),
            ),
            DropdownMenuItem(
              value: 'in_progress',
              child: _DropdownSelection('قيد التنفيذ'),
            ),
            DropdownMenuItem(
              value: 'submitted',
              child: _DropdownSelection('بانتظار الاعتماد'),
            ),
            DropdownMenuItem(
              value: 'approved',
              child: _DropdownSelection('بانتظار الترحيل'),
            ),
            DropdownMenuItem(
              value: 'posted',
              child: _DropdownSelection('مُرحّل'),
            ),
          ],
          onChanged: (String? value) => onStatusChanged(value ?? ''),
        ),
      ),
      SizedBox(
        width: 210,
        child: DropdownButtonFormField<int?>(
          initialValue:
              creators.any((InventoryCountCreator item) => item.id == createdBy)
              ? createdBy
              : null,
          isExpanded: true,
          decoration: _decoration('أنشئ بواسطة'),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
              value: null,
              child: _DropdownSelection('كل المستخدمين'),
            ),
            ...creators.map(
              (InventoryCountCreator creator) => DropdownMenuItem<int?>(
                value: creator.id,
                child: _DropdownSelection(creator.name),
              ),
            ),
          ],
          onChanged: onCreatedByChanged,
        ),
      ),
    ],
  );
}

class _DropdownSelection extends StatelessWidget {
  const _DropdownSelection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodyMedium,
    ),
  );
}

class _CountKpis extends StatelessWidget {
  const _CountKpis({required this.summary});
  final InventoryCountSummary summary;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      _CountKpi(
        label: 'مسودات',
        value: summary.drafts,
        color: AppColors.textPrimary,
      ),
      const SizedBox(width: AppSpacing.md),
      _CountKpi(
        label: 'قيد التنفيذ',
        value: summary.inProgress,
        color: AppColors.info,
      ),
      const SizedBox(width: AppSpacing.md),
      _CountKpi(
        label: 'بانتظار الاعتماد',
        value: summary.submitted,
        color: AppColors.warning,
      ),
      const SizedBox(width: AppSpacing.md),
      _CountKpi(
        label: 'بانتظار الترحيل',
        value: summary.approved,
        color: AppColors.paginationActive,
      ),
    ],
  );
}

class _CountSourceSelector extends StatelessWidget {
  const _CountSourceSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      Text('المصدر:', style: AppTextStyles.labelMedium),
      for (final (String id, String label) option in <(String, String)>[
        ('', 'الكل'),
        ('administrative', 'جرد إداري'),
        ('shift_pos', 'فحص شيفت POS'),
      ])
        ChoiceChip(
          label: Text(option.$2),
          selected: value == option.$1,
          onSelected: (_) => onChanged(option.$1),
        ),
    ],
  );
}

class _CountsPagination extends StatelessWidget {
  const _CountsPagination({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onPageChanged,
  });
  final int page;
  final int lastPage;
  final int total;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Text('إجمالي $total جرد', style: AppTextStyles.labelSmall),
      const Spacer(),
      IconButton(
        tooltip: 'الصفحة السابقة',
        onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
      Text('الصفحة $page من $lastPage', style: AppTextStyles.labelSmall),
      IconButton(
        tooltip: 'الصفحة التالية',
        onPressed: page < lastPage ? () => onPageChanged(page + 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
    ],
  );
}

class _CountKpi extends StatelessWidget {
  const _CountKpi({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: AppCard(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$value',
            style: AppTextStyles.titleLarge.copyWith(color: color),
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceKpis extends StatelessWidget {
  const _WorkspaceKpis({
    required this.total,
    required this.counted,
    required this.variance,
    required this.varianceValue,
  });
  final int total;
  final int counted;
  final int variance;
  final String varianceValue;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: AppSpacing.allMd,
    child: Row(
      children: <Widget>[
        _WorkspaceKpi(
          label: 'إجمالي العناصر',
          value: '$total',
          color: AppColors.textPrimary,
        ),
        const VerticalDivider(width: 1),
        _WorkspaceKpi(
          label: 'تم جرده',
          value: '$counted',
          color: AppColors.info,
        ),
        const VerticalDivider(width: 1),
        _WorkspaceKpi(
          label: 'المتبقي',
          value: '${total - counted}',
          color: AppColors.textSecondary,
        ),
        const VerticalDivider(width: 1),
        _WorkspaceKpi(
          label: 'عناصر بها فرق',
          value: '$variance',
          color: AppColors.warning,
        ),
        const VerticalDivider(width: 1),
        _WorkspaceKpi(
          label: 'إجمالي قيمة الفرق',
          value: _money(varianceValue),
          color: (double.tryParse(varianceValue) ?? 0) < 0
              ? AppColors.danger
              : AppColors.success,
        ),
      ],
    ),
  );
}

class _WorkspaceKpi extends StatelessWidget {
  const _WorkspaceKpi({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(color: color),
          textDirection: ui.TextDirection.ltr,
        ),
      ],
    ),
  );
}

class _WorkspaceLinesTable extends StatelessWidget {
  const _WorkspaceLinesTable({
    required this.lines,
    required this.editable,
    required this.pendingCountedQuantities,
    required this.lineErrors,
    required this.onCountedChanged,
    required this.onCountedSubmitted,
    required this.onReasonChanged,
  });
  final List<InventoryCountLine> lines;
  final bool editable;
  final Map<int, String> pendingCountedQuantities;
  final Map<int, String> lineErrors;
  final void Function(InventoryCountLine line, String value) onCountedChanged;
  final void Function(InventoryCountLine line, String value) onCountedSubmitted;
  final void Function(InventoryCountLine line, String value) onReasonChanged;

  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 1170,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('العنصر')),
        DataColumn(label: Text('رمز SKU')),
        DataColumn(label: Text('الوحدة')),
        DataColumn(label: Text('الكمية المتوقعة'), numeric: true),
        DataColumn(label: Text('الكمية المجردة'), numeric: true),
        DataColumn(label: Text('فرق الكمية'), numeric: true),
        DataColumn(label: Text('متوسط التكلفة'), numeric: true),
        DataColumn(label: Text('قيمة الفرق'), numeric: true),
        DataColumn(label: Text('السبب')),
      ],
      rows: lines
          .map(
            (InventoryCountLine line) =>
                _row(context, line, pendingCountedQuantities[line.itemId]),
          )
          .toList(growable: false),
    ),
  );

  DataRow _row(
    BuildContext context,
    InventoryCountLine line,
    String? pendingCountedQuantity,
  ) {
    final double variance = double.tryParse(line.varianceQuantity) ?? 0;
    final bool hasVariance = variance.abs() > 0.0001;
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(line.itemName, style: AppTextStyles.labelMedium)),
        DataCell(Text(line.sku, textDirection: ui.TextDirection.ltr)),
        DataCell(Text(_unitLabel(line.unit))),
        DataCell(
          Text(
            _number(line.expectedQuantity, digits: 3),
            textDirection: ui.TextDirection.ltr,
          ),
        ),
        DataCell(
          SizedBox(
            width: 78,
            child: TextFormField(
              initialValue:
                  pendingCountedQuantity ??
                  (line.isCounted ? line.countedQuantity : ''),
              enabled: editable,
              textDirection: ui.TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: '—',
                isDense: true,
                errorText: lineErrors[line.itemId],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
              ),
              onChanged: (String value) => onCountedChanged(line, value),
              onFieldSubmitted: (String value) =>
                  onCountedSubmitted(line, value),
            ),
          ),
        ),
        DataCell(
          Text(
            _number(line.varianceQuantity, digits: 3),
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(
              color: hasVariance ? AppColors.danger : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Text(
            _money(line.averageUnitCost),
            textDirection: ui.TextDirection.ltr,
          ),
        ),
        DataCell(
          Text(
            _money(line.varianceValue),
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(
              color: (double.tryParse(line.varianceValue) ?? 0) < 0
                  ? AppColors.danger
                  : AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(_reasonControl(context, line, hasVariance)),
      ],
    );
  }

  Widget _reasonControl(
    BuildContext context,
    InventoryCountLine line,
    bool hasVariance,
  ) {
    if (!hasVariance || !line.isCounted) return const Text('—');
    return SizedBox(
      width: 180,
      child: TextFormField(
        initialValue: line.reason ?? '',
        enabled: editable,
        maxLength: 4000,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'سبب الفرق',
          counterText: '',
        ),
        onChanged: (String value) => onReasonChanged(line, value),
      ),
    );
  }
}

bool _countIsEditable(String status) =>
    status == 'draft' || status == 'in_progress';

String? _countNextAction(String status) => switch (status) {
  'draft' => 'start',
  'in_progress' => 'submit',
  'submitted' => 'approve',
  'approved' => 'post',
  _ => null,
};

String _countNextActionLabel(String status) => switch (status) {
  'draft' => 'بدء الجرد',
  'in_progress' => 'إرسال للمراجعة',
  'submitted' => 'اعتماد الجرد',
  'approved' => 'ترحيل الفروقات',
  _ => '',
};

IconData _countNextActionIcon(String status) => switch (status) {
  'draft' => Icons.play_arrow_outlined,
  'in_progress' => Icons.send_outlined,
  'submitted' => Icons.verified_outlined,
  'approved' => Icons.post_add_outlined,
  _ => Icons.check_outlined,
};

Future<void> _advanceCount(BuildContext context, InventoryCount count) async {
  final String? action = _countNextAction(count.status);
  if (action == null) return;
  if (action == 'post') {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('ترحيل فروقات الجرد؟'),
        content: const Text(
          'سيُنشئ هذا حركات مخزون غير قابلة للتعديل لكل فرق جرد.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'ترحيل الفروقات',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  final bool saved = await context.read<InventoryCubit>().countAction(
    count.id,
    action,
  );
  if (!context.mounted) return;
  _notice(
    context,
    saved
        ? 'تم ${_countNextActionLabel(count.status)} بنجاح.'
        : _friendlyError(context.read<InventoryCubit>().state.error),
    error: !saved,
  );
}

Future<void> _showCountLineDialog(
  BuildContext context, {
  required InventoryCount count,
  required List<InventoryItem> items,
}) async {
  final List<InventoryItem> activeItems = _uniqueActiveItems(items);
  if (activeItems.isEmpty) return;
  InventoryItem selected = activeItems.first;
  final TextEditingController quantity = TextEditingController();
  final TextEditingController reason = TextEditingController();
  final bool? save = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setDialogState) =>
          AlertDialog(
            title: const Text('إضافة مادة إلى الجرد'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    initialValue: selected.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المادة'),
                    items: activeItems
                        .map(
                          (InventoryItem item) => DropdownMenuItem<int>(
                            value: item.id,
                            child: Text(
                              _itemSelectorLabel(item),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (int? itemId) {
                      final InventoryItem? next = _firstOrNull<InventoryItem>(
                        activeItems.where(
                          (InventoryItem item) => item.id == itemId,
                        ),
                      );
                      if (next != null) setDialogState(() => selected = next);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TextInput(
                    controller: quantity,
                    label: 'الكمية المجردة (${_unitLabel(selected.unit)})',
                    number: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TextInput(
                    controller: reason,
                    label: 'سبب الفرق (مطلوب عند وجود فرق)',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              AppButton(
                label: 'حفظ سطر الجرد',
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
    ),
  );
  if (save != true || !context.mounted) {
    quantity.dispose();
    reason.dispose();
    return;
  }
  final String countedQuantity = quantity.text.trim();
  final String lineReason = reason.text.trim();
  quantity.dispose();
  reason.dispose();
  if ((double.tryParse(countedQuantity) ?? -1) < 0) {
    _notice(context, 'أدخل كمية صحيحة تساوي صفرًا أو أكثر.', error: true);
    return;
  }
  final bool saved = await context
      .read<InventoryCubit>()
      .saveCountLine(count.id, <String, dynamic>{
        'itemId': selected.id,
        'countedQuantity': countedQuantity,
        if (selected.unit.isNotEmpty) 'unit': selected.unit,
        if (lineReason.isNotEmpty) 'reason': lineReason,
      });
  if (!context.mounted) return;
  _notice(
    context,
    saved
        ? 'تم حفظ سطر الجرد.'
        : _friendlyError(context.read<InventoryCubit>().state.error),
    error: !saved,
  );
}

class _InventoryPage extends StatelessWidget {
  const _InventoryPage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
    ),
    child: child,
  );
}

class InventorySubNavigation extends StatelessWidget {
  const InventorySubNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouterState routerState = GoRouterState.of(context);
    final String currentPath = routerState.uri.path;
    const List<_InventoryNavDestination> destinations =
        <_InventoryNavDestination>[
          _InventoryNavDestination(
            label: 'نظرة عامة',
            path: AppRoutes.inventory,
            icon: Icons.dashboard_outlined,
          ),
          _InventoryNavDestination(
            label: 'المواد المخزنية',
            path: AppRoutes.inventoryItems,
            icon: Icons.inventory_2_outlined,
          ),
          _InventoryNavDestination(
            label: 'أرصدة المخازن',
            path: AppRoutes.inventoryBalances,
            icon: Icons.warehouse_outlined,
          ),
          _InventoryNavDestination(
            label: 'حركات المخزون',
            path: AppRoutes.inventoryMovements,
            icon: Icons.swap_horiz_outlined,
          ),
          _InventoryNavDestination(
            label: 'جرد المخزون',
            path: AppRoutes.inventoryCounts,
            icon: Icons.fact_check_outlined,
          ),
          _InventoryNavDestination(
            label: 'تحويلات المخازن',
            path: AppRoutes.inventoryTransfers,
            icon: Icons.swap_calls_outlined,
          ),
          _InventoryNavDestination(
            label: 'قوالب فحص البار',
            path: AppRoutes.barCheckTemplates,
            icon: Icons.fact_check_outlined,
          ),
        ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 58,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.horizontalXl,
            child: Row(
              children: destinations
                  .map(
                    (_InventoryNavDestination destination) => Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: _InventoryNavTab(
                        destination: destination,
                        active: _isActive(currentPath, destination.path),
                        onTap: () {
                          final Uri target = Uri(
                            path: destination.path,
                            queryParameters:
                                routerState.uri.queryParameters.isEmpty
                                ? null
                                : routerState.uri.queryParameters,
                          );
                          context.go(target.toString());
                        },
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }

  bool _isActive(String currentPath, String destinationPath) {
    if (destinationPath == AppRoutes.inventory) {
      return currentPath == AppRoutes.inventory;
    }
    return currentPath == destinationPath ||
        currentPath.startsWith('$destinationPath/');
  }
}

class _InventoryNavDestination {
  const _InventoryNavDestination({
    required this.label,
    required this.path,
    required this.icon,
  });
  final String label;
  final String path;
  final IconData icon;
}

class _InventoryNavTab extends StatelessWidget {
  const _InventoryNavTab({
    required this.destination,
    required this.active,
    required this.onTap,
  });
  final _InventoryNavDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? AppColors.primarySoft : AppColors.transparent,
    borderRadius: AppRadius.pillRadius,
    child: InkWell(
      borderRadius: AppRadius.pillRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              destination.icon,
              size: 18,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              destination.label,
              style: AppTextStyles.labelLarge.copyWith(
                color: active ? AppColors.primary : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashboardKpi extends StatelessWidget {
  const _DashboardKpi({
    required this.label,
    required this.metric,
    required this.icon,
    this.color,
  });
  final String label;
  final InventoryDashboardMetric metric;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final bool money =
        label == 'إجمالي قيمة المخزون' ||
        label == 'تكلفة استهلاك اليوم' ||
        label == 'تكلفة هالك اليوم';
    final double? current = double.tryParse(metric.value);
    final double? previous = metric.previousValue == null
        ? null
        : double.tryParse(metric.previousValue!);
    final double? difference = current != null && previous != null
        ? current - previous
        : null;
    return AppCard(
      child: SizedBox(
        height: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: AppSpacing.allSm,
                  decoration: BoxDecoration(
                    color: color ?? AppColors.discountIconBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.secondary, size: 19),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(label, style: AppTextStyles.labelMedium)),
              ],
            ),
            const Spacer(),
            Text(
              money ? _money(metric.value) : metric.value,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (difference == null)
              const Text(
                'لا توجد بيانات مقارنة',
                style: AppTextStyles.labelSmall,
              )
            else
              Row(
                children: <Widget>[
                  Icon(
                    difference >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: difference >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${difference >= 0 ? '+' : ''}${money ? _money('${difference.abs()}') : _number('${difference.abs()}', digits: 0)} مقارنة بالفترة السابقة',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: difference >= 0
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardQuickActions extends StatelessWidget {
  const _DashboardQuickActions({
    required this.onAddItem,
    required this.onMovement,
    required this.onCount,
  });
  final VoidCallback onAddItem;
  final VoidCallback onMovement;
  final VoidCallback onCount;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('إجراءات سريعة', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _DashboardQuickAction(
              label: 'إضافة مادة',
              icon: Icons.add_box_outlined,
              onTap: onAddItem,
            ),
            _DashboardQuickAction(
              label: 'حركة مخزون',
              icon: Icons.swap_vert_outlined,
              onTap: onMovement,
            ),
            _DashboardQuickAction(
              label: 'جرد مخزون',
              icon: Icons.fact_check_outlined,
              onTap: onCount,
            ),
            const _DashboardQuickAction(
              label: 'تحويل مخزون',
              icon: Icons.swap_horiz_outlined,
              unavailable: true,
            ),
            const _DashboardQuickAction(
              label: 'أمر شراء',
              icon: Icons.shopping_cart_outlined,
              unavailable: true,
            ),
          ],
        ),
      ],
    ),
  );
}

class _DashboardQuickAction extends StatelessWidget {
  const _DashboardQuickAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.unavailable = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool unavailable;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: unavailable ? 'غير متاح حتى تكتمل هذه العملية' : label,
    child: OutlinedButton.icon(
      onPressed: unavailable ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    ),
  );
}

class _DashboardWarehouseValueCard extends StatefulWidget {
  const _DashboardWarehouseValueCard({
    required this.values,
    required this.onTap,
  });
  final List<InventoryWarehouseValue> values;
  final ValueChanged<int> onTap;

  @override
  State<_DashboardWarehouseValueCard> createState() =>
      _DashboardWarehouseValueCardState();
}

class _DashboardWarehouseValueCardState
    extends State<_DashboardWarehouseValueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<InventoryWarehouseValue> visible = _expanded
        ? widget.values
        : widget.values.take(4).toList(growable: false);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('صحة المخازن', style: AppTextStyles.titleMedium),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'حالة الجاهزية والتنبيهات لكل مخزن',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              if (widget.values.length > 4)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'عرض أقل' : 'عرض كل المخازن'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.values.isEmpty)
            const _EmptyState(message: 'لا يتوفر مخزون في المخازن لهذا النطاق.')
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: visible
                        .map(
                          (InventoryWarehouseValue item) => SizedBox(
                            width: constraints.maxWidth < 560
                                ? constraints.maxWidth
                                : (constraints.maxWidth - AppSpacing.sm) / 2,
                            child: _DashboardWarehouseHealthCard(
                              item: item,
                              onTap: () => widget.onTap(item.id),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
            ),
        ],
      ),
    );
  }
}

class _DashboardWarehouseHealthCard extends StatelessWidget {
  const _DashboardWarehouseHealthCard({
    required this.item,
    required this.onTap,
  });
  final InventoryWarehouseValue item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _warehouseStatusColor(item.status);
    final String statusLabel = _warehouseStatusLabel(item.status);
    return Material(
      color: AppColors.transparent,
      borderRadius: AppRadius.control,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.control,
        child: Container(
          padding: AppSpacing.allMd,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.control,
            border: Border.all(color: statusColor.withValues(alpha: .34)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.warehouse_outlined,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item.name, style: AppTextStyles.labelLarge),
                        const SizedBox(height: 2),
                        Text(
                          item.warehouseTypeLabel,
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  _DashboardStatusPill(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_money(item.value), style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${item.itemCount} مادة · ${item.alertsCount} تنبيه',
                style: AppTextStyles.labelSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'جاهزية المخزون ${item.healthPercentage}%',
                      style: AppTextStyles.labelSmall,
                    ),
                  ),
                  Text(
                    _lastActivityLabel(item.lastMovementAt),
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadius.pillRadius,
                child: LinearProgressIndicator(
                  value: item.healthPercentage.clamp(0, 100) / 100,
                  minHeight: 6,
                  color: statusColor,
                  backgroundColor: AppColors.discountIconBackground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _warehouseStatusColor(String status) => switch (status) {
  'critical' => AppColors.danger,
  'attention' => AppColors.warning,
  _ => AppColors.success,
};

String _warehouseStatusLabel(String status) => switch (status) {
  'critical' => 'حرج',
  'attention' => 'يحتاج متابعة',
  _ => 'سليم',
};

class _DashboardStatusPill extends StatelessWidget {
  const _DashboardStatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(7, 3, 7, 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
  );
}

String _lastActivityLabel(String? value) {
  final DateTime? date = parseBackendDateTime(value);
  if (date == null) return 'لا نشاط مسجل';
  final Duration elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return 'آخر حركة الآن';
  if (elapsed.inMinutes < 60) return 'آخر حركة منذ ${elapsed.inMinutes} د';
  if (elapsed.inHours < 24) return 'آخر حركة منذ ${elapsed.inHours} س';
  return 'آخر حركة ${DateFormat('d MMM').format(date)}';
}

class _DashboardLowStockAlerts extends StatefulWidget {
  const _DashboardLowStockAlerts({
    required this.alerts,
    required this.summary,
    required this.onOpen,
  });
  final List<InventoryLowStockAlert> alerts;
  final InventoryAlertSummary summary;
  final ValueChanged<InventoryLowStockAlert> onOpen;

  @override
  State<_DashboardLowStockAlerts> createState() =>
      _DashboardLowStockAlertsState();
}

class _DashboardLowStockAlertsState extends State<_DashboardLowStockAlerts> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('تنبيهات المخزون', style: AppTextStyles.titleMedium),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'مواد تحتاج إلى تدخل قبل تأثر التشغيل',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            if (widget.alerts.length > 4)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'عرض أقل' : 'عرض الكل'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            _AlertSummaryBadge(
              label: 'حرج: ${widget.summary.critical}',
              tone: ManagementTone.danger,
            ),
            _AlertSummaryBadge(
              label: 'منخفض: ${widget.summary.low}',
              tone: ManagementTone.warning,
            ),
            _AlertSummaryBadge(
              label: 'الإجمالي: ${widget.summary.total}',
              tone: ManagementTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: _EmptyState(
              message: 'كل المواد المتابعة أعلى من الحد الأدنى.',
            ),
          )
        else
          ...(_expanded
                  ? widget.alerts
                  : widget.alerts.take(4).toList(growable: false))
              .map(
                (InventoryLowStockAlert alert) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _InventoryAlertCard(
                    alert: alert,
                    onOpen: () => widget.onOpen(alert),
                  ),
                ),
              ),
      ],
    ),
  );
}

class _AlertSummaryBadge extends StatelessWidget {
  const _AlertSummaryBadge({required this.label, required this.tone});
  final String label;
  final ManagementTone tone;

  @override
  Widget build(BuildContext context) =>
      ManagementBadge(label: label, tone: tone);
}

class _InventoryAlertCard extends StatelessWidget {
  const _InventoryAlertCard({required this.alert, required this.onOpen});
  final InventoryLowStockAlert alert;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final Color color = _alertColor(alert.severity);
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.control,
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  alert.outOfStock
                      ? Icons.remove_shopping_cart_outlined
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(alert.itemName, style: AppTextStyles.labelLarge),
                    const SizedBox(height: 2),
                    Text(alert.warehouseName, style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              _DashboardStatusPill(
                label: _alertLabel(alert.severity),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _AlertQuantity(
                label: 'الحالي',
                value: alert.quantity,
                unit: alert.unit,
                color: color,
              ),
              const SizedBox(width: AppSpacing.md),
              _AlertQuantity(
                label: 'الحد الأدنى',
                value: alert.minimumLevel,
                unit: alert.unit,
              ),
              const SizedBox(width: AppSpacing.md),
              _AlertQuantity(
                label: 'المطلوب',
                value: alert.missingQuantity,
                unit: alert.unit,
                color: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_outlined, size: 16),
                label: const Text('عرض المادة'),
              ),
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: 'يتطلب سير عمل أوامر الشراء',
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.shopping_cart_outlined, size: 16),
                  label: Text('إنشاء أمر شراء'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertQuantity extends StatelessWidget {
  const _AlertQuantity({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });
  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: 2),
        Text(
          '${_number(value, digits: 3)} ${_unitLabel(unit)}',
          style: AppTextStyles.labelMedium.copyWith(color: color),
        ),
      ],
    ),
  );
}

Color _alertColor(String severity) => switch (severity) {
  'out_of_stock' || 'critical' => AppColors.danger,
  _ => AppColors.warning,
};

String _alertLabel(String severity) => switch (severity) {
  'out_of_stock' => 'نافد',
  'critical' => 'حرج',
  _ => 'منخفض',
};

class InventoryDashboardAnalyticsSection extends StatelessWidget {
  const InventoryDashboardAnalyticsSection({
    super.key,
    required this.loading,
    required this.trend,
    required this.waste,
    required this.consumption,
    required this.selectedTrendDays,
    required this.onTrendDaysChanged,
  });

  final bool loading;
  final InventoryStockValueTrend trend;
  final InventoryWasteSummary waste;
  final InventoryConsumptionSummary consumption;
  final int selectedTrendDays;
  final ValueChanged<int> onTrendDaysChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      _DashboardTrendCard(
        loading: loading,
        trend: trend,
        selectedDays: selectedTrendDays,
        onDaysChanged: onTrendDaysChanged,
      ),
      const SizedBox(height: AppSpacing.lg),
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            constraints.maxWidth < 900
            ? Column(
                children: <Widget>[
                  _WasteAnalyticsCard(summary: waste),
                  const SizedBox(height: AppSpacing.lg),
                  _ConsumptionAnalyticsCard(summary: consumption),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _WasteAnalyticsCard(summary: waste)),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _ConsumptionAnalyticsCard(summary: consumption),
                  ),
                ],
              ),
      ),
    ],
  );
}

class _DashboardTrendCard extends StatelessWidget {
  const _DashboardTrendCard({
    required this.loading,
    required this.trend,
    required this.selectedDays,
    required this.onDaysChanged,
  });

  final bool loading;
  final InventoryStockValueTrend trend;
  final int selectedDays;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'تغير قيمة المخزون',
                style: AppTextStyles.titleMedium,
              ),
            ),
            _TrendPeriodSelector(
              selectedDays: selectedDays,
              onChanged: onDaysChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'قيمة المخزون اليومية من البيانات الخادمية',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (loading)
          const _AnalyticsChartSkeleton()
        else if (!trend.available || trend.points.isEmpty)
          const SizedBox(
            height: 160,
            child: _EmptyState(message: 'لا تتوفر بيانات'),
          )
        else ...<Widget>[
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(painter: _StockValueTrendPainter(trend.points)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Text(
                _trendDate(trend.points.first.date),
                style: AppTextStyles.labelSmall,
              ),
              const Spacer(),
              Text(
                _trendDate(trend.points.last.date),
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _TrendPeriodSelector extends StatelessWidget {
  const _TrendPeriodSelector({
    required this.selectedDays,
    required this.onChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: <int>[7, 30, 90]
        .map(
          (int days) => ChoiceChip(
            label: Text('$days يوم'),
            selected: selectedDays == days,
            onSelected: (_) => onChanged(days),
            visualDensity: VisualDensity.compact,
          ),
        )
        .toList(growable: false),
  );
}

class _AnalyticsChartSkeleton extends StatelessWidget {
  const _AnalyticsChartSkeleton();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List<Widget>.generate(
            3,
            (_) => Container(height: 1, color: AppColors.border),
          ),
        ),
        const Center(child: CircularProgressIndicator()),
      ],
    ),
  );
}

class _WasteAnalyticsCard extends StatelessWidget {
  const _WasteAnalyticsCard({required this.summary});
  final InventoryWasteSummary summary;

  @override
  Widget build(BuildContext context) => _AnalyticsSummaryCard(
    title: 'تحليل الهدر',
    icon: Icons.delete_outline,
    tone: AppColors.warning,
    metrics: <_AnalyticsMetric>[
      _AnalyticsMetric(label: 'هدر اليوم', value: _money(summary.todayCost)),
      _AnalyticsMetric(
        label: 'هدر هذا الأسبوع',
        value: _money(summary.weekCost),
      ),
      _AnalyticsMetric(label: 'حركات الهدر', value: '${summary.movementCount}'),
    ],
    items: summary.topItems,
    emptyMessage: 'لا تتوفر بيانات هدر',
  );
}

class _ConsumptionAnalyticsCard extends StatelessWidget {
  const _ConsumptionAnalyticsCard({required this.summary});
  final InventoryConsumptionSummary summary;

  @override
  Widget build(BuildContext context) => _AnalyticsSummaryCard(
    title: 'الاستهلاك',
    icon: Icons.restaurant_outlined,
    tone: AppColors.tertiary,
    metrics: <_AnalyticsMetric>[
      _AnalyticsMetric(
        label: 'تكلفة الاستهلاك',
        value: _money(summary.totalCost),
      ),
    ],
    items: summary.topItems,
    emptyMessage: 'لا تتوفر بيانات استهلاك',
  );
}

class _AnalyticsMetric {
  const _AnalyticsMetric({required this.label, required this.value});
  final String label;
  final String value;
}

class _AnalyticsSummaryCard extends StatelessWidget {
  const _AnalyticsSummaryCard({
    required this.title,
    required this.icon,
    required this.tone,
    required this.metrics,
    required this.items,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final Color tone;
  final List<_AnalyticsMetric> metrics;
  final List<InventoryAnalyticsTopItem> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: tone),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTextStyles.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: metrics
              .map(
                (_AnalyticsMetric metric) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(metric.label, style: AppTextStyles.labelSmall),
                    const SizedBox(height: 2),
                    Text(metric.value, style: AppTextStyles.labelLarge),
                  ],
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('أكثر المواد', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        if (items.isEmpty)
          _CompactAnalyticsEmptyState(message: emptyMessage)
        else
          ...items
              .take(3)
              .map(
                (InventoryAnalyticsTopItem item) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: AppTextStyles.labelMedium,
                        ),
                      ),
                      Text(
                        '${_number(item.quantity, digits: 3)} ${_unitLabel(item.unit)} · ${_money(item.cost)}',
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
      ],
    ),
  );
}

class _CompactAnalyticsEmptyState extends StatelessWidget {
  const _CompactAnalyticsEmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    width: double.infinity,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.inbox_outlined, size: 20, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _StockValueTrendPainter extends CustomPainter {
  const _StockValueTrendPainter(this.points);
  final List<InventoryStockValueTrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;
    final List<double> values = points
        .map(
          (InventoryStockValueTrendPoint point) =>
              double.tryParse(point.value) ?? 0,
        )
        .toList(growable: false);
    double low = values.first;
    double high = values.first;
    for (final double value in values.skip(1)) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final double spread = high - low;
    final double displaySpread = spread == 0 ? 1 : spread;
    const double top = 12;
    const double bottom = 12;
    final double plotHeight = size.height - top - bottom;
    final double plotWidth = size.width;
    final Paint guidePaint = Paint()
      ..color = AppColors.border.withValues(alpha: .65)
      ..strokeWidth = 1;
    for (int index = 0; index < 3; index++) {
      final double y = top + plotHeight * index / 2;
      canvas.drawLine(Offset(0, y), Offset(plotWidth, y), guidePaint);
    }
    final Path line = Path();
    for (int index = 0; index < values.length; index++) {
      final double x = values.length == 1
          ? plotWidth / 2
          : plotWidth * index / (values.length - 1);
      final double y =
          top + (high - values[index]) / displaySpread * plotHeight;
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.tertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _StockValueTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

String _trendDate(String value) {
  final DateTime? date = parseBackendDateTime(value);
  return date == null ? '—' : DateFormat('MMM d').format(date);
}

class InventoryDashboardRecentActivityFeed extends StatelessWidget {
  const InventoryDashboardRecentActivityFeed({
    super.key,
    required this.items,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onViewAll,
  });
  final List<InventoryMovement> items;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'النشاط الأخير للمخزون',
                    style: AppTextStyles.titleMedium,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'وفق نطاق التاريخ والمخزن المحدد أعلاه',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Text('عرض كل الحركات'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 190,
            child: _RecentActivityTypeFilter(
              value: selectedType,
              onChanged: onTypeChanged,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: _EmptyState(message: 'لا توجد حركات مخزون حديثة'),
          )
        else
          ...items
              .take(8)
              .map(
                (InventoryMovement item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RecentActivityRow(item: item),
                ),
              ),
      ],
    ),
  );
}

class _RecentActivityTypeFilter extends StatelessWidget {
  const _RecentActivityTypeFilter({
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey<String>(value),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'نوع الحركة',
      isDense: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: EdgeInsetsDirectional.fromSTEB(12, 10, 12, 8),
    ),
    items: const <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(value: '', child: Text('كل الحركات')),
      DropdownMenuItem<String>(
        value: 'purchase_receive',
        child: Text('استلام شراء'),
      ),
      DropdownMenuItem<String>(
        value: 'recipe_consumption',
        child: Text('استهلاك بيع'),
      ),
      DropdownMenuItem<String>(value: 'transfer_in', child: Text('تحويل وارد')),
      DropdownMenuItem<String>(
        value: 'transfer_out',
        child: Text('تحويل صادر'),
      ),
      DropdownMenuItem<String>(value: 'waste', child: Text('هدر')),
      DropdownMenuItem<String>(value: 'adjustment', child: Text('تعديل مخزون')),
      DropdownMenuItem<String>(
        value: 'opening_balance',
        child: Text('رصيد افتتاحي'),
      ),
      DropdownMenuItem<String>(value: 'return', child: Text('مرتجع')),
    ],
    onChanged: (String? value) => onChanged(value ?? ''),
  );
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.item});
  final InventoryMovement item;

  @override
  Widget build(BuildContext context) {
    final ManagementTone tone = _dashboardMovementTone(item);
    final Color color = _activityColor(tone);
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.control,
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _activityIcon(item.dashboardType),
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: AppTextStyles.labelLarge,
                      ),
                    ),
                    ManagementBadge(
                      label: _dashboardMovementLabel(item),
                      tone: tone,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    _ActivityMeta(
                      icon: Icons.warehouse_outlined,
                      label: item.warehouseName,
                    ),
                    if (item.reference case final String reference)
                      _ActivityMeta(
                        icon: Icons.link_outlined,
                        label: reference,
                      ),
                    if (item.employee case final String employee)
                      _ActivityMeta(
                        icon: Icons.person_outline,
                        label: employee,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _shortDate(item.occurredAt),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${_number('${item.quantity.abs()}', digits: 3)} ${_unitLabel(item.unit)}',
            style: AppTextStyles.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ActivityMeta extends StatelessWidget {
  const _ActivityMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 3),
      Text(label, style: AppTextStyles.labelSmall),
    ],
  );
}

Color _activityColor(ManagementTone tone) => switch (tone) {
  ManagementTone.success => AppColors.success,
  ManagementTone.warning => AppColors.warning,
  ManagementTone.danger => AppColors.danger,
  ManagementTone.info => AppColors.info,
  ManagementTone.neutral => AppColors.secondary,
};

IconData _activityIcon(String type) => switch (type) {
  'purchase_receive' => Icons.move_to_inbox_outlined,
  'recipe_consumption' => Icons.restaurant_outlined,
  'transfer_in' => Icons.call_received_outlined,
  'transfer_out' => Icons.call_made_outlined,
  'waste' => Icons.delete_outline,
  'opening_balance' => Icons.account_balance_wallet_outlined,
  'return' => Icons.assignment_return_outlined,
  _ => Icons.tune_outlined,
};

class _DashboardBranchDropdown extends StatelessWidget {
  const _DashboardBranchDropdown({
    required this.value,
    required this.branches,
    required this.onChanged,
  });
  final int? value;
  final List<InventoryDashboardBranch> branches;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<int?>(
      key: ValueKey<int?>(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'الفرع',
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
      ),
      items: <DropdownMenuItem<int?>>[
        const DropdownMenuItem<int?>(value: null, child: Text('كل الفروع')),
        ...branches.map(
          (InventoryDashboardBranch branch) => DropdownMenuItem<int?>(
            value: branch.id,
            child: Text(branch.name),
          ),
        ),
      ],
      onChanged: onChanged,
    ),
  );
}

class _DashboardWarehouseDropdown extends StatelessWidget {
  const _DashboardWarehouseDropdown({
    required this.value,
    required this.warehouses,
    required this.onChanged,
  });
  final int? value;
  final List<InventoryWarehouseValue> warehouses;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) {
    final List<InventoryWarehouseValue> visible = warehouses;
    final selected =
        visible.any(
          (InventoryWarehouseValue warehouse) => warehouse.id == value,
        )
        ? value
        : null;
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<int?>(
        key: ValueKey<int?>(selected),
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'المخزن',
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
        ),
        items: <DropdownMenuItem<int?>>[
          const DropdownMenuItem<int?>(value: null, child: Text('كل المخازن')),
          ...visible.map(
            (InventoryWarehouseValue warehouse) => DropdownMenuItem<int?>(
              value: warehouse.id,
              child: Text(warehouse.name),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.compact = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final bool compact;
  @override
  Widget build(BuildContext context) => compact
      ? AppCard(
          padding: AppSpacing.allMd,
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color ?? AppColors.discountIconBackground,
                  borderRadius: AppRadius.control,
                ),
                child: Icon(icon, size: 20, color: AppColors.secondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: AppTextStyles.labelSmall),
                    const SizedBox(height: 2),
                    Text(value, style: AppTextStyles.titleMedium),
                  ],
                ),
              ),
            ],
          ),
        )
      : ManagementKpiCard(
          label: label,
          value: value,
          icon: icon,
          color: color ?? AppColors.discountIconBackground,
        );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
    ],
  );
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.items,
    required this.onOpen,
    required this.onEdit,
  });
  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onOpen;
  final ValueChanged<InventoryItem> onEdit;
  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 1060,
    verticalScroll: true,
    child: DataTable(
      horizontalMargin: AppSpacing.md,
      columnSpacing: AppSpacing.lg,
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('المادة')),
        DataColumn(label: Text('الرمز')),
        DataColumn(label: Text('النوع')),
        DataColumn(label: Text('الوحدة')),
        DataColumn(label: Text('الكمية المتاحة'), numeric: true),
        DataColumn(label: Text('حد إعادة الطلب'), numeric: true),
        DataColumn(label: Text('متوسط التكلفة'), numeric: true),
        DataColumn(label: Text('حالة المخزون')),
        DataColumn(label: Text('الإجراءات')),
      ],
      rows: items.map((InventoryItem item) {
        final bool low =
            (double.tryParse(item.availableQuantity) ?? 0) <=
            (double.tryParse(item.reorderLevel) ?? 0);
        return DataRow(
          onSelectChanged: (_) => onOpen(item),
          cells: <DataCell>[
            DataCell(Text(item.name, style: AppTextStyles.labelLarge)),
            DataCell(Text(item.sku)),
            DataCell(Text(_itemType(item.itemType))),
            DataCell(Text(_unitLabel(item.unit))),
            DataCell(
              Text(
                '${_number(item.availableQuantity, digits: 3)} ${_unitLabel(item.unit)}',
              ),
            ),
            DataCell(
              Text(
                '${_number(item.reorderLevel, digits: 3)} ${_unitLabel(item.unit)}',
              ),
            ),
            DataCell(Text(_money(item.cost))),
            DataCell(
              ManagementBadge(
                label: _stockLabel(item.availableQuantity, low),
                tone: _stockTone(item.availableQuantity, low),
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'عرض التفاصيل',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => onOpen(item),
                  ),
                  IconButton(
                    tooltip: 'تعديل المادة',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEdit(item),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

class _ItemsPagination extends StatelessWidget {
  const _ItemsPagination({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.onPageChanged,
  });
  final int page;
  final int lastPage;
  final int total;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Text('$total مادة', style: AppTextStyles.bodySmall),
      const Spacer(),
      Text('الصفحة $page من $lastPage', style: AppTextStyles.bodySmall),
      IconButton(
        tooltip: 'الصفحة السابقة',
        onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'الصفحة التالية',
        onPressed: page < lastPage ? () => onPageChanged(page + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _MovementsPagination extends StatelessWidget {
  const _MovementsPagination({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.visibleCount,
    required this.onPageChanged,
  });
  final int page;
  final int lastPage;
  final int total;
  final int visibleCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final int first = total == 0 ? 0 : (page - 1) * 5 + 1;
    final int last = first + visibleCount - 1;
    return Row(
      children: <Widget>[
        Text('$first–$last من $total حركة', style: AppTextStyles.bodySmall),
        const Spacer(),
        Text('الصفحة $page من $lastPage', style: AppTextStyles.bodySmall),
        IconButton(
          tooltip: 'الصفحة السابقة',
          onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'الصفحة التالية',
          onPressed: page < lastPage ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _BalancesPagination extends StatelessWidget {
  const _BalancesPagination({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.visibleCount,
    required this.onPageChanged,
  });
  final int page;
  final int lastPage;
  final int total;
  final int visibleCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final int first = total == 0 ? 0 : (page - 1) * 5 + 1;
    final int last = first + visibleCount - 1;
    return Row(
      children: <Widget>[
        Text('$first–$last من $total رصيد', style: AppTextStyles.bodySmall),
        const Spacer(),
        Text('الصفحة $page من $lastPage', style: AppTextStyles.bodySmall),
        IconButton(
          tooltip: 'الصفحة السابقة',
          onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'الصفحة التالية',
          onPressed: page < lastPage ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ItemBalancesTable extends StatelessWidget {
  const _ItemBalancesTable({required this.items});
  final List<InventoryBalance> items;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: ManagementTableShell(
      minWidth: 900,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll<Color>(
          AppColors.menuTableHeader,
        ),
        columns: const <DataColumn>[
          DataColumn(label: Text('المخزن')),
          DataColumn(label: Text('الفرع')),
          DataColumn(label: Text('الكمية الفعلية'), numeric: true),
          DataColumn(label: Text('الكمية المتاحة'), numeric: true),
          DataColumn(label: Text('متوسط التكلفة'), numeric: true),
          DataColumn(label: Text('إجمالي القيمة'), numeric: true),
        ],
        rows: items
            .map(
              (InventoryBalance balance) => DataRow(
                cells: <DataCell>[
                  DataCell(
                    Text(
                      balance.warehouseName,
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                  DataCell(
                    Text(
                      balance.branchName.isEmpty ? 'مشترك' : balance.branchName,
                    ),
                  ),
                  DataCell(
                    Text(
                      '${_number(balance.quantity, digits: 3)} ${_unitLabel(balance.unit)}',
                    ),
                  ),
                  DataCell(
                    Text(
                      '${_number(balance.available, digits: 3)} ${_unitLabel(balance.unit)}',
                    ),
                  ),
                  DataCell(Text(_money(balance.cost))),
                  DataCell(Text(_money(balance.value))),
                ],
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
}

class _ItemMovementHistory extends StatelessWidget {
  const _ItemMovementHistory({required this.items});
  final List<InventoryMovement> items;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: items
          .map(
            (InventoryMovement movement) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: _movementHistoryBackground(movement.type),
                    child: Icon(
                      _movementHistoryIcon(movement.type),
                      color: _movementHistoryColor(movement.type),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _movementLabel(movement.type),
                          style: AppTextStyles.labelLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _shortDate(movement.occurredAt),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${movement.quantity >= 0 ? '+' : '-'}${_number('${movement.quantity.abs()}', digits: 3)} ${_unitLabel(movement.unit)}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: _movementHistoryColor(movement.type),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

IconData _movementHistoryIcon(String type) => switch (type) {
  'stock_in' ||
  'opening_balance' ||
  'adjustment_in' ||
  'transfer_in' => Icons.south_west_outlined,
  'waste' => Icons.delete_outline,
  'stock_count_variance' || 'adjustment_out' => Icons.tune_outlined,
  _ => Icons.north_east_outlined,
};

Color _movementHistoryColor(String type) => switch (type) {
  'stock_in' ||
  'opening_balance' ||
  'adjustment_in' ||
  'transfer_in' => AppColors.success,
  'waste' => AppColors.danger,
  'stock_count_variance' || 'adjustment_out' => AppColors.warning,
  _ => AppColors.info,
};

Color _movementHistoryBackground(String type) =>
    _movementHistoryColor(type).withValues(alpha: .12);

class _BalancesTable extends StatelessWidget {
  const _BalancesTable({required this.items, required this.onOpen});
  final List<InventoryBalance> items;
  final ValueChanged<InventoryBalance>? onOpen;
  @override
  Widget build(BuildContext context) {
    final Widget table = ManagementTableShell(
      minWidth: AppSizes.inventoryDesktopTableWidth,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll<Color>(
          AppColors.menuTableHeader,
        ),
        columns: const <DataColumn>[
          DataColumn(label: Text('المادة')),
          DataColumn(label: Text('الكمية الفعلية'), numeric: true),
          DataColumn(label: Text('الكمية المتاحة'), numeric: true),
          DataColumn(label: Text('متوسط التكلفة'), numeric: true),
          DataColumn(label: Text('إجمالي القيمة'), numeric: true),
          DataColumn(label: Text('حالة المخزون')),
        ],
        rows: items
            .map(
              (InventoryBalance balance) => DataRow(
                onSelectChanged: onOpen == null
                    ? null
                    : (_) => onOpen!(balance),
                cells: <DataCell>[
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          balance.itemName.isEmpty
                              ? 'مادة مخزنية'
                              : balance.itemName,
                          style: AppTextStyles.labelLarge,
                        ),
                        Row(
                          children: <Widget>[
                            Text(
                              balance.warehouseName,
                              style: AppTextStyles.labelSmall,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            ManagementBadge(
                              label: balance.warehouseTypeLabel,
                              tone: ManagementTone.info,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      '${_number(balance.quantity, digits: 3)} ${_unitLabel(balance.unit)}',
                    ),
                  ),
                  DataCell(
                    Text(
                      '${_number(balance.available, digits: 3)} ${_unitLabel(balance.unit)}',
                    ),
                  ),
                  DataCell(Text(_money(balance.cost))),
                  DataCell(Text(_money(balance.value))),
                  DataCell(
                    ManagementBadge(
                      label: _stockLabel(balance.available, balance.low),
                      tone: _stockTone(balance.available, balance.low),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          constraints.maxWidth >= AppSizes.inventoryDesktopTableWidth
          ? Center(
              child: SizedBox(
                width: AppSizes.inventoryDesktopTableWidth,
                child: table,
              ),
            )
          : table,
    );
  }
}

class _MovementsTable extends StatelessWidget {
  const _MovementsTable({required this.items});
  final List<InventoryMovement> items;
  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 1180,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('التاريخ والوقت')),
        DataColumn(label: Text('المادة')),
        DataColumn(label: Text('المخزن')),
        DataColumn(label: Text('نوع الحركة')),
        DataColumn(label: Text('الكمية'), numeric: true),
        DataColumn(label: Text('تكلفة الوحدة'), numeric: true),
        DataColumn(label: Text('التكلفة الإجمالية'), numeric: true),
        DataColumn(label: Text('الموظف')),
        DataColumn(label: Text('المرجع')),
        DataColumn(label: Text('التفاصيل')),
      ],
      rows: items
          .map(
            (InventoryMovement movement) => DataRow(
              cells: <DataCell>[
                DataCell(Text(_shortDate(movement.occurredAt))),
                DataCell(
                  Text(
                    movement.itemName.isEmpty
                        ? 'مادة مخزنية'
                        : movement.itemName,
                    style: AppTextStyles.labelLarge,
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(movement.warehouseName),
                      const SizedBox(width: AppSpacing.sm),
                      ManagementBadge(
                        label: movement.warehouseTypeLabel,
                        tone: ManagementTone.info,
                      ),
                    ],
                  ),
                ),
                DataCell(
                  ManagementBadge(
                    label: _movementLabel(movement.type),
                    tone: _movementTone(movement.type),
                  ),
                ),
                DataCell(
                  Text(
                    '${movement.quantity >= 0 ? '+' : ''}${_number('${movement.quantity.abs()}', digits: 3)} ${_unitLabel(movement.unit)}',
                  ),
                ),
                DataCell(Text(_money(movement.unitCost))),
                DataCell(Text(_money(movement.totalCost))),
                DataCell(
                  Text(_safeEnglish(movement.employee, fallback: 'النظام')),
                ),
                DataCell(Text(movement.reference ?? '—')),
                DataCell(
                  IconButton(
                    tooltip: 'عرض الحركة',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => _showMovementDetails(context, movement),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

class _CountsTable extends StatelessWidget {
  const _CountsTable({required this.items, required this.onOpen});
  final List<InventoryCount> items;
  final ValueChanged<InventoryCount> onOpen;
  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 1170,
    verticalScroll: true,
    child: DataTable(
      showCheckboxColumn: false,
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('رقم الجرد')),
        DataColumn(label: Text('المخزن')),
        DataColumn(label: Text('نوع الجرد')),
        DataColumn(label: Text('تاريخ الجرد')),
        DataColumn(label: Text('أنشئ بواسطة')),
        DataColumn(label: Text('العناصر المجرودة / الإجمالي'), numeric: true),
        DataColumn(label: Text('الحالة')),
      ],
      rows: items
          .map(
            (InventoryCount count) => DataRow(
              onSelectChanged: (_) => onOpen(count),
              cells: <DataCell>[
                DataCell(Text(count.number, style: AppTextStyles.labelMedium)),
                DataCell(Text(count.warehouseName)),
                DataCell(Text(_countTypeLabel(count.countType))),
                DataCell(Text(_countListDate(count.date))),
                DataCell(Text(count.createdByName ?? '—')),
                DataCell(
                  Text(
                    '${count.countedItems}/${count.totalItems}',
                    textDirection: ui.TextDirection.ltr,
                  ),
                ),
                DataCell(
                  ManagementBadge(
                    label: _countStatus(count.status),
                    tone: _countTone(count.status),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

ManagementTone _countTone(String status) => switch (status) {
  'posted' => ManagementTone.success,
  'in_progress' => ManagementTone.info,
  'submitted' || 'approved' => ManagementTone.warning,
  'cancelled' => ManagementTone.danger,
  _ => ManagementTone.neutral,
};

class _CountLinesTable extends StatelessWidget {
  const _CountLinesTable({required this.lines});
  final List<InventoryCountLine> lines;

  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 780,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('المادة')),
        DataColumn(label: Text('المتوقع'), numeric: true),
        DataColumn(label: Text('المجرد'), numeric: true),
        DataColumn(label: Text('الفرق'), numeric: true),
        DataColumn(label: Text('السبب')),
      ],
      rows: lines
          .map(
            (InventoryCountLine line) => DataRow(
              cells: <DataCell>[
                DataCell(Text(line.itemName)),
                DataCell(
                  Text(
                    '${_number(line.expectedQuantity, digits: 3)} ${_unitLabel(line.unit)}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_number(line.countedQuantity, digits: 3)} ${_unitLabel(line.unit)}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_number(line.varianceQuantity, digits: 3)} ${_unitLabel(line.unit)}',
                  ),
                ),
                DataCell(Text(line.reason ?? '—')),
              ],
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.onSubmitted,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
      ),
    ),
  );
}

class _ReadOnlyFilter extends StatelessWidget {
  const _ReadOnlyFilter({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: AppSpacing.horizontalMd,
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
      color: AppColors.surface,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 17, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.expand_more, size: 17),
      ],
    ),
  );
}

class _DateRangeFilter extends StatelessWidget {
  const _DateRangeFilter({required this.range, required this.onTap});
  final DateTimeRange range;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      height: 40,
      padding: AppSpacing.horizontalMd,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.date_range_outlined,
            size: 17,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d, y').format(range.end)}',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _WarehouseDropdown extends StatelessWidget {
  const _WarehouseDropdown({
    required this.value,
    required this.warehouses,
    required this.onChanged,
  });
  final int? value;
  final List<WarehouseLocation> warehouses;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) {
    context.watch<OperationalBranchCubit>();
    final List<WarehouseLocation> visible = _branchWarehouses(
      context,
      warehouses,
    );
    final int? selectedValue =
        visible.any((WarehouseLocation warehouse) => warehouse.id == value)
        ? value
        : null;

    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<int?>(
        key: ValueKey<int?>(selectedValue),
        initialValue: selectedValue,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'المخزن',
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
        ),
        items: <DropdownMenuItem<int?>>[
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('كل مخازن الفرع'),
          ),
          ...visible.map(
            (WarehouseLocation warehouse) => DropdownMenuItem<int?>(
              value: warehouse.id,
              child: Text(_warehouseLabel(warehouse)),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ItemDropdown extends StatelessWidget {
  const _ItemDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.allowAll = true,
  });
  final int? value;
  final List<InventoryItem> items;
  final ValueChanged<int?> onChanged;
  final bool allowAll;
  @override
  Widget build(BuildContext context) {
    final List<InventoryItem> visible = _uniqueActiveItems(items);
    final InventoryItem? selected = _firstOrNull<InventoryItem>(
      visible.where((InventoryItem item) => item.id == value),
    );

    return SizedBox(
      width: 280,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final int? picked = await showDialog<int>(
            context: context,
            builder: (BuildContext dialogContext) =>
                _InventoryItemPicker(items: visible, allowAll: allowAll),
          );
          if (picked == null || !context.mounted) return;
          if (picked == -1 && allowAll) {
            onChanged(null);
          } else if (picked != -1) {
            onChanged(picked);
          }
        },
        child: InputDecorator(
          isEmpty: false,
          decoration: const InputDecoration(
            labelText: 'المادة المخزنية',
            suffixIcon: Icon(Icons.search_outlined),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: Text(
            selected == null
                ? (allowAll ? 'كل المواد' : 'اختر مادة مخزنية')
                : _itemSelectorLabel(selected),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _InventoryItemPicker extends StatefulWidget {
  const _InventoryItemPicker({required this.items, required this.allowAll});
  final List<InventoryItem> items;
  final bool allowAll;

  @override
  State<_InventoryItemPicker> createState() => _InventoryItemPickerState();
}

class _InventoryItemPickerState extends State<_InventoryItemPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String query = _query.trim().toLowerCase();
    final List<InventoryItem> results = widget.items
        .where(
          (InventoryItem item) =>
              query.isEmpty ||
              _itemSelectorLabel(item).toLowerCase().contains(query),
        )
        .toList(growable: false);
    return AlertDialog(
      title: const Text('اختيار مادة مخزنية'),
      content: SizedBox(
        width: 560,
        height: 440,
        child: Column(
          children: <Widget>[
            TextField(
              autofocus: true,
              onChanged: (String value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو الرمز أو الوحدة',
                prefixIcon: Icon(Icons.search_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                children: <Widget>[
                  if (widget.allowAll)
                    ListTile(
                      leading: const Icon(Icons.select_all_outlined),
                      title: const Text('كل المواد'),
                      onTap: () => Navigator.pop(context, -1),
                    ),
                  if (results.isEmpty)
                    const ListTile(title: Text('لا توجد مواد تطابق بحثك.'))
                  else
                    ...results.map(
                      (InventoryItem item) => ListTile(
                        title: Text(_itemSelectorLabel(item)),
                        onTap: () => Navigator.pop(context, item.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({
    required this.value,
    required this.label,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final String label;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
      ),
      items: <DropdownMenuItem<String>>[
        DropdownMenuItem<String>(value: '', child: Text('كل $label')),
        ...options.entries.map(
          (MapEntry<String, String> entry) => DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          ),
        ),
      ],
      onChanged: (String? next) => onChanged(next ?? ''),
    ),
  );
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({
    required this.value,
    required this.units,
    required this.onChanged,
  });
  final String value;
  final List<InventoryUnit> units;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      icon: const Icon(Icons.straighten_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(InventoryUnit.labelFor(value)),
      ),
      onPressed: () async {
        final String? selected = await showDialog<String>(
          context: context,
          builder: (BuildContext context) =>
              _UnitPicker(units: units, selected: value),
        );
        if (selected != null) onChanged(selected);
      },
    ),
  );
}

class _UnitPicker extends StatefulWidget {
  const _UnitPicker({required this.units, required this.selected});
  final List<InventoryUnit> units;
  final String selected;

  @override
  State<_UnitPicker> createState() => _UnitPickerState();
}

class _UnitPickerState extends State<_UnitPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String query = _query.trim().toLowerCase();
    final List<InventoryUnit> matches = widget.units
        .where(
          (InventoryUnit unit) =>
              query.isEmpty ||
              unit.label.toLowerCase().contains(query) ||
              unit.code.contains(query),
        )
        .toList(growable: false);
    return AlertDialog(
      title: const Text('اختيار وحدة'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: <Widget>[
            TextField(
              autofocus: true,
              onChanged: (String value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_outlined),
                hintText: 'ابحث في الوحدات',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                children: matches
                    .map(
                      (InventoryUnit unit) => ListTile(
                        title: Text(unit.label),
                        trailing: unit.code == widget.selected
                            ? const Icon(Icons.check, color: AppColors.success)
                            : null,
                        onTap: () => Navigator.pop(context, unit.code),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.number = false,
    this.maxLines = 1,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final bool number;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    maxLines: maxLines,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
  );
}

class _MovementTypeCard extends StatelessWidget {
  const _MovementTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });
  final String type;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 150,
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.paymentSelectedBackground
            : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.tertiary : AppColors.border,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            _isOutbound(type)
                ? Icons.north_east_rounded
                : Icons.south_west_rounded,
            color: _isOutbound(type) ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_movementLabel(type), style: AppTextStyles.labelLarge),
        ],
      ),
    ),
  );
}

class _BalancePreview extends StatelessWidget {
  const _BalancePreview({required this.item, required this.balance});
  final InventoryItem item;
  final InventoryBalance? balance;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allLg,
    decoration: BoxDecoration(
      color: AppColors.paymentSelectedBackground,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Wrap(
      spacing: AppSpacing.xxl,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        _Detail(
          'الرصيد الحالي',
          '${_number(balance?.quantity ?? item.quantity, digits: 3)} ${_unitLabel(item.unit)}',
        ),
        _Detail(
          'الكمية المتاحة',
          '${_number(balance?.available ?? item.quantity, digits: 3)} ${_unitLabel(item.unit)}',
        ),
        _Detail('متوسط التكلفة', _money(balance?.cost ?? item.cost)),
      ],
    ),
  );
}

class _ExpectedBalance extends StatelessWidget {
  const _ExpectedBalance({
    required this.after,
    required this.unit,
    required this.invalid,
  });
  final double after;
  final String unit;
  final bool invalid;
  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: invalid ? const Color(0xFFFFF1F0) : AppColors.discountGreenBadge,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: <Widget>[
        Icon(
          invalid ? Icons.error_outline : Icons.check_circle_outline,
          color: invalid ? AppColors.danger : AppColors.success,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          invalid
              ? 'هذه الحركة ستتجاوز الرصيد المتاح.'
              : 'الرصيد المتوقع بعد الحركة: ${_number('$after', digits: 3)} $unit',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    ),
  );
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      TextButton(
        onPressed: () => context.go(AppRoutes.inventory),
        child: const Text('إدارة المخزون'),
      ),
      const Text('/'),
      TextButton(
        onPressed: () => context.go(AppRoutes.inventoryItems),
        child: const Text('المواد المخزنية'),
      ),
      const Text('/'),
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Text(item.name, style: AppTextStyles.bodySmall),
      ),
    ],
  );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTextStyles.labelLarge),
    ],
  );
}

class _CountStatusDetail extends StatelessWidget {
  const _CountStatusDetail({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const Text('الحالة', style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      ManagementBadge(label: _countStatus(status), tone: _countTone(status)),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const Text('الحالة', style: AppTextStyles.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      ManagementBadge(
        label: active ? 'نشط' : 'غير نشط',
        tone: active ? ManagementTone.success : ManagementTone.neutral,
      ),
    ],
  );
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) => AppCard(
    child: SizedBox(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'جارٍ تحميل بيانات المخزون المباشرة…',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _LoadState extends StatelessWidget {
  const _LoadState({
    required this.loading,
    required this.error,
    required this.onRetry,
    this.permissionDenied = false,
  });
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool permissionDenied;
  @override
  Widget build(BuildContext context) => loading
      ? const _LoadingSkeleton()
      : ManagementMessage(
          message: permissionDenied
              ? 'ليس لديك صلاحية عرض لوحة المخزون.'
              : error == null
              ? 'لا تتوفر بيانات مخزون.'
              : _friendlyError(error),
          error: error != null || permissionDenied,
          onRetry: permissionDenied ? null : onRetry,
        );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => ManagementMessage(message: message);
}

Future<void> _showItemDialog(
  BuildContext context, {
  InventoryItem? current,
  List<String> categories = const <String>[],
  List<InventoryUnit> units = const <InventoryUnit>[],
  VoidCallback? onSaved,
}) async {
  final TextEditingController name = TextEditingController(text: current?.name);
  final TextEditingController sku = TextEditingController(text: current?.sku);
  final TextEditingController barcode = TextEditingController(
    text: current?.barcode,
  );
  final TextEditingController categoryInput = TextEditingController(
    text: current?.category,
  );
  final TextEditingController reorder = TextEditingController(
    text: current?.reorderLevel ?? '0.000',
  );
  final TextEditingController minimumStock = TextEditingController(
    text: current?.minimumStock ?? '0.000',
  );
  final TextEditingController cost = TextEditingController(
    text: current?.cost ?? '0.0000',
  );
  final TextEditingController notes = TextEditingController(
    text: current?.notes,
  );
  final List<String> categoryOptions = <String>{
    ...categories,
    if (current?.category.isNotEmpty ?? false) current!.category,
  }.toList()..sort();
  String type = current?.itemType ?? 'raw_material';
  String category = current?.category ?? '';
  String unit = current?.unit ?? 'piece';
  bool active = current?.active ?? true;
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext dialogContext, StateSetter setDialogState) => AlertDialog(
        title: Text(
          current == null ? 'إضافة مادة مخزنية' : 'تعديل مادة مخزنية',
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('بيانات المادة', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _TextInput(controller: name, label: 'اسم المادة'),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TextInput(controller: sku, label: 'رمز المادة'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TextInput(controller: barcode, label: 'الباركود'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StringDropdown(
                        value: type,
                        label: 'نوع المادة',
                        options: const <String, String>{
                          'raw_material': 'مادة خام',
                          'packaging': 'تغليف',
                          'supply': 'مستلزمات',
                          'finished_good': 'منتج جاهز',
                          'other': 'أخرى',
                        },
                        onChanged: (String value) =>
                            setDialogState(() => type = value),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: categoryOptions.isEmpty
                          ? _TextInput(
                              controller: categoryInput,
                              label: 'الفئة',
                              onChanged: (String value) => category = value,
                            )
                          : _StringDropdown(
                              value: category,
                              label: 'الفئة',
                              options: <String, String>{
                                for (final String value in categoryOptions)
                                  value: value,
                              },
                              onChanged: (String value) =>
                                  setDialogState(() => category = value),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _UnitSelector(
                  value: unit,
                  units: units.isEmpty ? InventoryUnit.fallback : units,
                  onChanged: (String value) =>
                      setDialogState(() => unit = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('ضوابط المخزون', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TextInput(
                        controller: minimumStock,
                        label: 'الحد الأدنى للمخزون',
                        number: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TextInput(
                        controller: reorder,
                        label: 'حد إعادة الطلب',
                        number: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TextInput(
                        controller: cost,
                        label: 'تكلفة الوحدة',
                        number: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'يمكن إضافة الكمية الافتتاحية عبر إدخال مخزون بعد إنشاء المادة.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('ملاحظات', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _TextInput(controller: notes, label: 'ملاحظات', maxLines: 3),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مادة نشطة'),
                  value: active,
                  onChanged: (bool value) =>
                      setDialogState(() => active = value),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: current == null ? 'إنشاء المادة' : 'حفظ التغييرات',
            icon: Icons.save_outlined,
            onPressed: () async {
              final String selectedCategory = categoryOptions.isEmpty
                  ? categoryInput.text.trim()
                  : category.trim();
              if (name.text.trim().isEmpty ||
                  selectedCategory.isEmpty ||
                  unit.isEmpty) {
                _notice(
                  dialogContext,
                  'اسم المادة والفئة والوحدة حقول مطلوبة.',
                  error: true,
                );
                return;
              }
              if (current?.active == true && !active) {
                final bool? confirmed = await showDialog<bool>(
                  context: dialogContext,
                  builder: (BuildContext confirmationContext) => AlertDialog(
                    title: const Text('إلغاء تفعيل المادة المخزنية؟'),
                    content: const Text(
                      'لن تكون هذه المادة متاحة لعمليات المخزون الجديدة حتى يُعاد تفعيلها.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(confirmationContext, false),
                        child: const Text('إبقاء نشطة'),
                      ),
                      AppButton(
                        label: 'إلغاء التفعيل',
                        onPressed: () =>
                            Navigator.pop(confirmationContext, true),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }
              if (!dialogContext.mounted || !context.mounted) return;
              final bool saved = await context
                  .read<InventoryCubit>()
                  .saveItem(<String, dynamic>{
                    'nameAr': name.text.trim(),
                    'nameEn': name.text.trim(),
                    'sku': sku.text.trim(),
                    'barcode': barcode.text.trim(),
                    'itemType': type,
                    'category': selectedCategory,
                    'unit': unit,
                    'minimumStock': minimumStock.text.trim().isEmpty
                        ? '0.000'
                        : minimumStock.text.trim(),
                    'reorderLevel': reorder.text.trim().isEmpty
                        ? '0.000'
                        : reorder.text.trim(),
                    'latestUnitCost': cost.text.trim().isEmpty
                        ? '0.0000'
                        : cost.text.trim(),
                    'isActive': active,
                    'notes': notes.text.trim(),
                  }, id: current?.id);
              if (!dialogContext.mounted || !context.mounted) return;
              if (saved) {
                Navigator.pop(dialogContext);
                onSaved?.call();
                _notice(
                  context,
                  current == null
                      ? 'تم إنشاء المادة المخزنية.'
                      : 'تم تحديث المادة المخزنية.',
                );
              } else {
                _notice(
                  dialogContext,
                  _friendlyError(context.read<InventoryCubit>().state.error),
                  error: true,
                );
              }
            },
          ),
        ],
      ),
    ),
  );
  name.dispose();
  sku.dispose();
  barcode.dispose();
  categoryInput.dispose();
  minimumStock.dispose();
  reorder.dispose();
  cost.dispose();
  notes.dispose();
}

void _showMovementDetails(BuildContext context, InventoryMovement movement) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('تفاصيل حركة المخزون'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Detail(
              'المادة',
              movement.itemName.isEmpty ? 'مادة مخزنية' : movement.itemName,
            ),
            const SizedBox(height: AppSpacing.md),
            _Detail('المخزن', movement.warehouseName),
            const SizedBox(height: AppSpacing.md),
            _Detail('نوع الحركة', _movementLabel(movement.type)),
            const SizedBox(height: AppSpacing.md),
            _Detail(
              'الكمية',
              '${movement.quantity >= 0 ? '+' : ''}${_number('${movement.quantity.abs()}', digits: 3)} ${_unitLabel(movement.unit)}',
            ),
            if (movement.reason.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _Detail(
                'السبب',
                _safeEnglish(movement.reason, fallback: 'مسجل في سجل المخزون'),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}

String _englishCategory(String value) {
  if (value.isEmpty) return 'غير مصنفة';
  return RegExp(r'^[\x00-\x7F]+$').hasMatch(value) ? value : 'فئة مخزون';
}

String _safeEnglish(String? value, {required String fallback}) {
  if (value == null || value.isEmpty) return fallback;
  return RegExp(r'^[\x00-\x7F]+$').hasMatch(value) ? value : fallback;
}

String _shortDate(String value) {
  final DateTime? date = parseBackendDateTime(value);
  return date == null ? '—' : DateFormat('MMM d, y · h:mm a').format(date);
}

String _countListDate(String value) {
  final DateTime? date = DateTime.tryParse(value);
  if (date == null) return '—';
  const List<String> months = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _countTypeLabel(String value) => switch (value) {
  'cycle' => 'جرد دوري / جزئي',
  'shift_check' => 'فحص شيفت POS',
  _ => 'جرد كامل',
};

String _apiDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String _countStatus(String status) => switch (status) {
  'draft' => 'مسودة',
  'in_progress' => 'قيد الجرد',
  'submitted' => 'مُرسل',
  'approved' => 'معتمد',
  'posted' => 'مُرحل',
  _ => 'ملغى',
};
T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;

String _friendlyError(Object? error) {
  if (error == null) {
    return 'تعذر إكمال الإجراء. يرجى المحاولة مجددًا.';
  }
  final ApiException? apiError = error is ApiException ? error : null;
  final String message = apiError?.message ?? error.toString();
  return message.isEmpty
      ? 'تعذر إكمال الإجراء. يرجى المحاولة مجددًا.'
      : message.replaceFirst('Exception: ', '');
}

void _notice(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ),
  );
}
