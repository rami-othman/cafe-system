import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/inventory_text_styles.dart';
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
    Future<void>.microtask(() {
      context.read<InventoryCubit>().loadDashboard();
      context.read<InventoryCubit>().loadBalances();
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
        if (dashboard == null) {
          return _LoadState(
            loading: state.loading,
            error: state.error,
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
                actions: <Widget>[
                  AppButton(
                    label: 'بدء جرد مخزون',
                    icon: Icons.fact_check_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(AppRoutes.inventoryCounts),
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
                    branchId: _branchId,
                    warehouses: state.warehouses,
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
                                  label: 'قيمة الهالك',
                                  metric: dashboard.kpis.wasteValue,
                                  icon: Icons.delete_outline,
                                  color: AppColors.discountBlueBadge,
                                ),
                              ]
                              .map(
                                (Widget card) => SizedBox(
                                  width: constraints.maxWidth < 900
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth -
                                                AppSpacing.lg * 3) /
                                            4,
                                  child: card,
                                ),
                              )
                              .toList(),
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    constraints.maxWidth < 980
                    ? Column(
                        children: <Widget>[
                          _DashboardWarehouseValueCard(
                            values: dashboard.warehouseValues,
                            onTap: (int id) {
                              setState(() => _warehouseId = id);
                              _reload();
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DashboardLowStockAlerts(
                            alerts: dashboard.alerts,
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
                            flex: 3,
                            child: _DashboardWarehouseValueCard(
                              values: dashboard.warehouseValues,
                              onTap: (int id) {
                                setState(() => _warehouseId = id);
                                _reload();
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 2,
                            child: _DashboardLowStockAlerts(
                              alerts: dashboard.alerts,
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
              const Text(
                'أحدث حركات المخزون',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DashboardMovementsTable(items: dashboard.recent),
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
                  final bool saved = await context
                      .read<InventoryCubit>()
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
    Future<void>.microtask(
      () => context.read<InventoryCubit>().loadItemDetails(widget.itemId),
    );
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    showNavigation: false,
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
  int? _warehouseId;
  String _query = '';
  String _status = '';
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => context.read<InventoryCubit>().loadBalances());
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final List<InventoryBalance> rows = state.balances;
        final double value = rows.fold<double>(
          0,
          (double sum, InventoryBalance balance) =>
              sum + (double.tryParse(balance.value) ?? 0),
        );
        return Column(
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
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: <Widget>[
                _Kpi(
                  label: 'قيمة المخزون',
                  value: _money('$value'),
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _Kpi(
                  label: 'مواد منخفضة المخزون',
                  value:
                      '${rows.where((InventoryBalance row) => row.low).length}',
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.discountOrangeBadge,
                ),
                _Kpi(
                  label: 'مواد متاحة',
                  value:
                      '${rows.where((InventoryBalance row) => (double.tryParse(row.available) ?? 0) > 0).length}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.discountGreenBadge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: state.loading && rows.isEmpty
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
                  : _BalancesTable(
                      items: rows,
                      onOpen: (InventoryBalance balance) => context.go(
                        AppRoutes.inventoryItemDetailPath(balance.itemId),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );

  void _load() => context.read<InventoryCubit>().loadBalances(
    warehouseId: _warehouseId,
    search: _query,
    stockStatus: _status,
  );
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
    Future<void>.microtask(() {
      context.read<InventoryCubit>().loadMovements();
      context.read<InventoryCubit>().loadBalances();
    });
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'حركات المخزون',
            subtitle: 'سجل كامل قابل للتدقيق لجميع نشاطات المخزون.',
            actions: <Widget>[
              AppButton(
                label: 'إضافة حركة',
                icon: Icons.add,
                onPressed: () => context.go(AppRoutes.inventoryMovementCreate),
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
          Expanded(
            child: state.loading && state.movements.isEmpty
                ? const _LoadingSkeleton()
                : state.error != null && state.movements.isEmpty
                ? _LoadState(loading: false, error: state.error, onRetry: _load)
                : state.movements.isEmpty
                ? const _EmptyState(
                    message: 'لا توجد حركات تطابق المرشحات المحددة.',
                  )
                : _MovementsTable(items: state.movements),
          ),
        ],
      ),
    ),
  );

  void _load() => context.read<InventoryCubit>().loadMovements(
    warehouseId: _warehouseId,
    itemId: _itemId,
    type: _type,
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

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      context.read<InventoryCubit>().loadMovements();
      context.read<InventoryCubit>().loadBalances();
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
    showNavigation: false,
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
                            : () => _post(context, available),
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

  Future<void> _post(BuildContext context, double available) async {
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
    if (confirmed != true || !mounted) return;
    final String reason = <String>[
      _reason.text.trim(),
      _notes.text.trim(),
    ].where((String value) => value.isNotEmpty).join(' — ');
    final bool saved = await context
        .read<InventoryCubit>()
        .postMovement(<String, dynamic>{
          'warehouseId': _warehouseId,
          'itemId': _itemId,
          'type': _type,
          'quantity': _quantity.text.trim(),
          if (!_isOutbound(_type) && _cost.text.trim().isNotEmpty)
            'unitCost': _cost.text.trim(),
          if (reason.isNotEmpty) 'reason': reason,
        });
    if (!mounted) return;
    if (saved) {
      _notice(context, 'تم ترحيل حركة المخزون بنجاح.');
      context.go(AppRoutes.inventoryMovements);
    } else {
      _notice(
        context,
        _friendlyError(context.read<InventoryCubit>().state.error),
        error: true,
      );
    }
  }
}

class InventoryCountsScreen extends StatefulWidget {
  const InventoryCountsScreen({super.key});
  @override
  State<InventoryCountsScreen> createState() => _InventoryCountsState();
}

class _InventoryCountsState extends State<InventoryCountsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => context.read<InventoryCubit>().loadCounts());
  }

  @override
  Widget build(BuildContext context) => _InventoryPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'جرد المخزون',
            subtitle: 'تخطيط الجرد الفعلي ومراجعة الفروقات قبل ترحيلها.',
            actions: <Widget>[
              AppButton(
                label: 'بدء جرد مخزون',
                icon: Icons.add,
                onPressed: _branchWarehouses(context, state.warehouses).isEmpty
                    ? null
                    : () => _startCount(
                        context,
                        _branchWarehouses(context, state.warehouses),
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: state.loading && state.counts.isEmpty
                ? const _LoadingSkeleton()
                : state.error != null && state.counts.isEmpty
                ? _LoadState(
                    loading: false,
                    error: state.error,
                    onRetry: () => context.read<InventoryCubit>().loadCounts(),
                  )
                : state.counts.isEmpty
                ? const _EmptyState(message: 'لم يُنشأ أي جرد مخزون بعد.')
                : _CountsTable(
                    items: state.counts,
                    onOpen: (InventoryCount count) => context.go(
                      AppRoutes.inventoryCountDetailPath(count.id),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  Future<void> _startCount(
    BuildContext context,
    List<WarehouseLocation> warehouses,
  ) async {
    int warehouseId = warehouses.first.id;
    final bool? create = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('بدء جرد مخزون'),
        content: DropdownButtonFormField<int>(
          initialValue: warehouseId,
          decoration: const InputDecoration(labelText: 'المخزن'),
          items: warehouses
              .map(
                (WarehouseLocation warehouse) => DropdownMenuItem<int>(
                  value: warehouse.id,
                  child: Text(_warehouseLabel(warehouse)),
                ),
              )
              .toList(),
          onChanged: (int? value) => warehouseId = value ?? warehouseId,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'إنشاء مسودة',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (create != true || !mounted) return;
    final bool saved = await context
        .read<InventoryCubit>()
        .createCount(<String, dynamic>{
          'warehouseId': warehouseId,
          'countDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
    if (!mounted) return;
    _notice(
      context,
      saved
          ? 'تم إنشاء مسودة الجرد.'
          : _friendlyError(context.read<InventoryCubit>().state.error),
      error: !saved,
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
    showNavigation: false,
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
  const _InventoryPage({required this.child, this.showNavigation = true});
  final Widget child;
  final bool showNavigation;
  @override
  Widget build(BuildContext context) {
    if (!showNavigation) {
      return DesktopPageLayout(child: child);
    }
    return DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _InventorySubNavigation(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventorySubNavigation extends StatelessWidget {
  const _InventorySubNavigation();

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
            label: 'الوحدات والتحويلات',
            path: AppRoutes.inventoryUnitConversions,
            icon: Icons.straighten_outlined,
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
        ];

    return SizedBox(
      height: 58,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.horizontalXl,
        child: Row(
          children: destinations
              .map(
                (_InventoryNavDestination destination) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _InventoryNavTab(
                    destination: destination,
                    active: _isActive(currentPath, destination.path),
                    onTap: () {
                      final Uri target = Uri(
                        path: destination.path,
                        queryParameters: routerState.uri.queryParameters.isEmpty
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
        label == 'Total Inventory Value' || label == 'Waste Value';
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

class _DashboardWarehouseValueCard extends StatelessWidget {
  const _DashboardWarehouseValueCard({
    required this.values,
    required this.onTap,
  });
  final List<InventoryWarehouseValue> values;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final double maximum = values.fold(
      0,
      (double current, InventoryWarehouseValue item) =>
          current > (double.tryParse(item.value) ?? 0)
          ? current
          : (double.tryParse(item.value) ?? 0),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'قيمة المخزون حسب المخزن',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (values.isEmpty)
            const _EmptyState(message: 'لا يتوفر مخزون في المخازن لهذا النطاق.')
          else
            ...values.map(
              (InventoryWarehouseValue item) => _DashboardWarehouseRow(
                item: item,
                maximum: maximum,
                onTap: () => onTap(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardWarehouseRow extends StatelessWidget {
  const _DashboardWarehouseRow({
    required this.item,
    required this.maximum,
    required this.onTap,
  });
  final InventoryWarehouseValue item;
  final double maximum;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.control,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.warehouse_outlined,
                size: 18,
                color: AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(item.name, style: AppTextStyles.labelLarge)),
              Text(_money(item.value), style: AppTextStyles.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.pillRadius,
            child: LinearProgressIndicator(
              value: maximum == 0
                  ? 0
                  : (double.tryParse(item.value) ?? 0) / maximum,
              minHeight: 7,
              color: AppColors.tertiary,
              backgroundColor: AppColors.discountIconBackground,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DashboardLowStockAlerts extends StatelessWidget {
  const _DashboardLowStockAlerts({required this.alerts, required this.onOpen});
  final List<InventoryLowStockAlert> alerts;
  final ValueChanged<InventoryLowStockAlert> onOpen;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'تنبيهات المخزون المنخفض',
                style: AppTextStyles.titleMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.discountOrangeBadge,
                borderRadius: AppRadius.pillRadius,
              ),
              child: Text('${alerts.length}', style: AppTextStyles.labelSmall),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (alerts.isEmpty)
          const Text(
            'كل المواد المتابعة أعلى من حد إعادة الطلب.',
            style: AppTextStyles.bodySmall,
          )
        else
          ...alerts.map(
            (InventoryLowStockAlert alert) =>
                _DashboardAlertRow(alert: alert, onTap: () => onOpen(alert)),
          ),
      ],
    ),
  );
}

class _DashboardAlertRow extends StatelessWidget {
  const _DashboardAlertRow({required this.alert, required this.onTap});
  final InventoryLowStockAlert alert;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.control,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            alert.outOfStock
                ? Icons.error_outline
                : Icons.warning_amber_outlined,
            color: alert.outOfStock ? AppColors.danger : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(alert.itemName, style: AppTextStyles.labelLarge),
                Text(alert.warehouseName, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Text(
            '${_number(alert.quantity, digits: 3)} ${alert.unit}',
            style: AppTextStyles.labelMedium,
          ),
        ],
      ),
    ),
  );
}

class _DashboardMovementsTable extends StatelessWidget {
  const _DashboardMovementsTable({required this.items});
  final List<InventoryMovement> items;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: items.isEmpty
        ? const Padding(
            padding: AppSpacing.allXl,
            child: _EmptyState(message: 'لا توجد حركات مخزون ضمن هذا النطاق.'),
          )
        : ManagementTableShell(
            minWidth: 820,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll<Color>(
                AppColors.menuTableHeader,
              ),
              columns: const <DataColumn>[
                DataColumn(label: Text('المادة')),
                DataColumn(label: Text('نوع الحركة')),
                DataColumn(label: Text('الكمية'), numeric: true),
                DataColumn(label: Text('المخزن')),
                DataColumn(label: Text('الوقت')),
              ],
              rows: items
                  .take(10)
                  .map(
                    (InventoryMovement item) => DataRow(
                      cells: <DataCell>[
                        DataCell(
                          Text(item.itemName, style: AppTextStyles.labelLarge),
                        ),
                        DataCell(
                          ManagementBadge(
                            label: _movementLabel(item.type),
                            tone: _movementTone(item.type),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${item.quantity >= 0 ? '+' : ''}${_number('${item.quantity}', digits: 3)} ${_unitLabel(item.unit)}',
                            style: TextStyle(
                              color: item.quantity >= 0
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                        DataCell(Text(item.warehouseName)),
                        DataCell(Text(_shortDate(item.occurredAt))),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
  );
}

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
    required this.branchId,
    required this.warehouses,
    required this.onChanged,
  });
  final int? value;
  final int? branchId;
  final List<WarehouseLocation> warehouses;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) {
    final visible = warehouses
        .where(
          (WarehouseLocation warehouse) =>
              warehouse.isActive &&
              !warehouse.isLegacy &&
              (branchId == null || warehouse.branchId == branchId),
        )
        .toList(growable: false);
    final selected =
        visible.any((WarehouseLocation warehouse) => warehouse.id == value)
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
            (WarehouseLocation warehouse) => DropdownMenuItem<int?>(
              value: warehouse.id,
              child: Text(warehouse.displayName),
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
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => ManagementKpiCard(
    label: label,
    value: value,
    icon: icon,
    color: color ?? AppColors.discountIconBackground,
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ],
  );
}

class _WarehouseValueCard extends StatelessWidget {
  const _WarehouseValueCard({required this.values});
  final List<InventoryWarehouseValue> values;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('قيمة المخزون حسب المخزن', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (values.isEmpty)
          Text('لا تتوفر قيم للمخازن.', style: AppTextStyles.bodySmall)
        else
          ...values.map(
            (InventoryWarehouseValue value) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.warehouse_outlined,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(value.name, style: AppTextStyles.bodyMedium),
                  ),
                  Text(_money(value.value), style: AppTextStyles.labelLarge),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _LowStockAlert extends StatelessWidget {
  const _LowStockAlert({required this.count, required this.onOpen});
  final int count;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        const SizedBox(height: AppSpacing.sm),
        Text('تنبيه مخزون منخفض', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          count == 0
              ? 'كل المواد المتابعة ضمن مستويات المخزون الآن.'
              : '$count مواد تحتاج إلى اهتمام قبل أن تتأثر العمليات.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onOpen, child: const Text('مراجعة الأرصدة')),
      ],
    ),
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
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 950,
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
              onSelectChanged: onOpen == null ? null : (_) => onOpen!(balance),
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
    minWidth: 720,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('المخزن')),
        DataColumn(label: Text('تاريخ الجرد')),
        DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('الإجراء')),
      ],
      rows: items
          .map(
            (InventoryCount count) => DataRow(
              onSelectChanged: (_) => onOpen(count),
              cells: <DataCell>[
                DataCell(Text(count.warehouseName)),
                DataCell(Text(_shortDate(count.date))),
                DataCell(
                  ManagementBadge(
                    label: _countStatus(count.status),
                    tone: count.status == 'posted'
                        ? ManagementTone.success
                        : ManagementTone.warning,
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => onOpen(count),
                    child: const Text('فتح الجرد'),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

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
          isEmpty: selected == null,
          decoration: const InputDecoration(
            labelText: 'المادة المخزنية',
            suffixIcon: Icon(Icons.search_outlined),
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
    width: 170,
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
        DropdownMenuItem<String>(
          value: '',
          child: Text('كل $label', overflow: TextOverflow.ellipsis),
        ),
        ...options.entries.map(
          (MapEntry<String, String> entry) => DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
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
  });
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => loading
      ? const _LoadingSkeleton()
      : ManagementMessage(
          message: error == null
              ? 'لا تتوفر بيانات مخزون.'
              : _friendlyError(error),
          error: error != null,
          onRetry: onRetry,
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
  final DateTime? date = DateTime.tryParse(value);
  return date == null
      ? '—'
      : DateFormat('MMM d, y · h:mm a').format(date.toLocal());
}

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
