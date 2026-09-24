import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/inventory_text_styles.dart';
import '../../../core/utils/backend_datetime.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/inventory_cubit.dart';
import '../controllers/inventory_state.dart';
import '../models/inventory_models.dart';
import 'widgets/inventory_item_widgets.dart';

class InventoryItemDetailsScreen extends StatefulWidget {
  const InventoryItemDetailsScreen({super.key, required this.itemId});
  final int itemId;
  @override
  State<InventoryItemDetailsScreen> createState() =>
      _InventoryItemDetailsScreenState();
}

class _InventoryItemDetailsScreenState extends State<InventoryItemDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this)
    ..addListener(_onTabChanged);
  // Each of these tabs' data is fetched once, the first time it is opened,
  // rather than eagerly alongside the item itself - avoids three extra
  // requests on every item-details visit for tabs the user may never open.
  bool _movementHistoryRequested = false;
  bool _recipeUsageRequested = false;
  bool _purchaseHistoryRequested = false;

  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() => cubit.loadItemDetails(widget.itemId));
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final InventoryCubit cubit = context.read<InventoryCubit>();
    switch (_tabs.index) {
      case 2:
        if (!_movementHistoryRequested) {
          _movementHistoryRequested = true;
          cubit.loadItemMovementHistory(widget.itemId);
        }
      case 3:
        if (!_recipeUsageRequested) {
          _recipeUsageRequested = true;
          cubit.loadItemRecipeUsage(widget.itemId);
        }
      case 4:
        if (!_purchaseHistoryRequested) {
          _purchaseHistoryRequested = true;
          cubit.loadItemPurchaseHistory(widget.itemId);
        }
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
    ),
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final InventoryItem? item = state.selectedItem?.id == widget.itemId
            ? state.selectedItem
            : null;
        if (item == null) {
          return state.loading
              ? const Center(child: CircularProgressIndicator())
              : ManagementMessage(
                  message: state.error ?? 'تعذر تحميل المادة',
                  error: true,
                  onRetry: () => context.read<InventoryCubit>().loadItemDetails(
                    widget.itemId,
                  ),
                );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ManagementPageHeader(
              title: item.name,
              subtitle:
                  '${item.sku.isEmpty ? 'بدون SKU' : item.sku} · ${inventoryItemTypeLabel(item.itemType)}',
              actions: <Widget>[
                AppButton(
                  label: 'العودة للمواد',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.go(AppRoutes.inventoryItems),
                ),
                AppButton(
                  label: 'تعديل المادة',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: () =>
                      context.go(AppRoutes.inventoryItemEditPath(item.id)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  _fact('الفئة', item.category.isEmpty ? '—' : item.category),
                  _fact('الوحدة الأساسية', inventoryUnitLabel(item.unit)),
                  _fact('متوسط التكلفة', inventoryMoney(item.cost)),
                  ItemStatusBadge(status: item.stockStatus),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: const <Tab>[
                Tab(text: 'نظرة عامة'),
                Tab(text: 'المخزون حسب المخزن'),
                Tab(text: 'سجل الحركات'),
                Tab(text: 'استخدام الوصفات'),
                Tab(text: 'سجل الشراء'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: <Widget>[
                  _overview(item),
                  _stock(item),
                  _movementHistory(state),
                  _recipeUsage(state),
                  _purchaseHistory(state),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _overview(InventoryItem item) => SingleChildScrollView(
    child: Column(
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: <Widget>[
            _metric(
              'الكمية الحالية',
              '${inventoryNumber(item.quantity, digits: 3)} ${inventoryUnitLabel(item.unit)}',
            ),
            _metric('القيمة الإجمالية', inventoryMoney(item.totalValue)),
            _metric(
              'نقطة إعادة الطلب',
              '${inventoryNumber(item.reorderLevel, digits: 3)} ${inventoryUnitLabel(item.unit)}',
            ),
            _metric('آخر تكلفة شراء', inventoryMoney(item.lastPurchaseCost)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('الوحدات وقواعد التتبع', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'شراء: ${inventoryUnitLabel(item.purchaseUnit.isEmpty ? item.unit : item.purchaseUnit)} · استهلاك: ${inventoryUnitLabel(item.consumptionUnit.isEmpty ? item.unit : item.consumptionUnit)}',
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'الصلاحية: ${item.trackExpiry ? 'مفعّل' : 'غير مفعّل'} · الدفعات: ${item.trackBatch ? 'مفعّل' : 'غير مفعّل'}',
              ),
              if (item.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(item.notes),
              ],
            ],
          ),
        ),
      ],
    ),
  );
  Widget _stock(InventoryItem item) => item.balances.isEmpty
      ? const ManagementMessage(message: 'لا توجد أرصدة مخازن لهذه المادة بعد.')
      : ManagementTableShell(
          minWidth: 760,
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('المخزن')),
              DataColumn(label: Text('المتاح')),
              DataColumn(label: Text('متوسط التكلفة')),
              DataColumn(label: Text('القيمة')),
            ],
            rows: item.balances
                .map(
                  (InventoryBalance balance) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(balance.warehouseName)),
                      DataCell(
                        Text(
                          '${inventoryNumber(balance.available, digits: 3)} ${inventoryUnitLabel(balance.unit)}',
                        ),
                      ),
                      DataCell(Text(inventoryMoney(balance.cost))),
                      DataCell(Text(inventoryMoney(balance.value))),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        );
  Widget _movementHistory(InventoryState state) {
    if (state.itemMovementHistoryLoading && state.itemMovementHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.itemMovementHistory.isEmpty) {
      return const ManagementMessage(message: 'لا توجد حركات مخزون لهذه المادة.');
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            itemCount: state.itemMovementHistory.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (BuildContext context, int index) {
              final InventoryMovement movement = state.itemMovementHistory[index];
              final String? reference = movement.reference;
              return ListTile(
                title: Text(inventoryMovementTypeLabel(movement.type)),
                subtitle: Text(
                  '${movement.warehouseName} · ${_movementDateTime(movement.occurredAt)}'
                  '${reference == null ? '' : ' · $reference'}',
                ),
                trailing: Text(
                  '${inventoryNumber(movement.quantityIn == '0.000' ? movement.quantityOut : movement.quantityIn, digits: 3)} ${inventoryUnitLabel(movement.unit)}',
                ),
              );
            },
          ),
        ),
        if (state.itemMovementHistoryLastPage > 1)
          _ItemDetailsPagination(
            page: state.itemMovementHistoryPage,
            lastPage: state.itemMovementHistoryLastPage,
            total: state.itemMovementHistoryTotal,
            totalLabel: 'حركة',
            onPageChanged: (int page) => context
                .read<InventoryCubit>()
                .loadItemMovementHistory(widget.itemId, page: page),
          ),
      ],
    );
  }

  Widget _recipeUsage(InventoryState state) {
    if (state.itemRecipeUsageLoading && !state.itemRecipeUsageLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.itemRecipeUsage.isEmpty) {
      return const ManagementMessage(
        message: 'لا توجد وصفات تستخدم هذه المادة.',
      );
    }
    return ManagementTableShell(
      minWidth: 760,
      verticalScroll: true,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('المنتج')),
          DataColumn(label: Text('الخيار')),
          DataColumn(label: Text('الكمية')),
          DataColumn(label: Text('الحالة')),
        ],
        rows: state.itemRecipeUsage
            .map(
              (InventoryRecipeUsage usage) => DataRow(
                cells: <DataCell>[
                  DataCell(Text(usage.productName)),
                  DataCell(
                    Text(
                      usage.condition == null
                          ? usage.variantName
                          : '${usage.variantName} (${usage.condition})',
                    ),
                  ),
                  DataCell(
                    Text(
                      '${inventoryNumber(usage.quantity, digits: 3)} ${inventoryUnitLabel(usage.unit)}',
                    ),
                  ),
                  DataCell(Text(usage.isActive ? 'نشط' : 'غير نشط')),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _purchaseHistory(InventoryState state) {
    if (state.itemPurchaseHistoryLoading && state.itemPurchaseHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.itemPurchaseHistory.isEmpty) {
      return const ManagementMessage(message: 'لا يوجد سجل شراء لهذه المادة.');
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: ManagementTableShell(
            minWidth: 900,
            verticalScroll: true,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('المورد')),
                DataColumn(label: Text('رقم الفاتورة')),
                DataColumn(label: Text('رقم الاستلام')),
                DataColumn(label: Text('تاريخ الاستلام')),
                DataColumn(label: Text('المخزن')),
                DataColumn(label: Text('الكمية')),
                DataColumn(label: Text('تكلفة الوحدة')),
                DataColumn(label: Text('الإجمالي')),
              ],
              rows: state.itemPurchaseHistory
                  .map(
                    (InventoryPurchaseHistoryEntry entry) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text(entry.supplierName)),
                        DataCell(Text(entry.invoiceNumber)),
                        DataCell(Text(entry.receiptNumber)),
                        DataCell(Text(_dateOnly(entry.receiptDate))),
                        DataCell(Text(entry.warehouseName)),
                        DataCell(
                          Text(
                            '${inventoryNumber(entry.quantity, digits: 3)} ${inventoryUnitLabel(entry.unit)}',
                          ),
                        ),
                        DataCell(Text(inventoryMoney(entry.unitCost))),
                        DataCell(Text(inventoryMoney(entry.lineTotal))),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        if (state.itemPurchaseHistoryLastPage > 1)
          _ItemDetailsPagination(
            page: state.itemPurchaseHistoryPage,
            lastPage: state.itemPurchaseHistoryLastPage,
            total: state.itemPurchaseHistoryTotal,
            totalLabel: 'عملية شراء',
            onPageChanged: (int page) => context
                .read<InventoryCubit>()
                .loadItemPurchaseHistory(widget.itemId, page: page),
          ),
      ],
    );
  }
  Widget _metric(String label, String value) => SizedBox(
    width: 210,
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.titleMedium),
        ],
      ),
    ),
  );
  Widget _fact(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: AppTextStyles.labelSmall),
      const SizedBox(height: 2),
      Text(value, style: AppTextStyles.labelLarge),
    ],
  );
}

String _movementDateTime(String value) {
  final DateTime? timestamp = parseBackendDateTime(value);
  return timestamp == null
      ? value
      : DateFormat('MMM d, y · h:mm a').format(timestamp);
}

String _dateOnly(String value) {
  final DateTime? date = parseBackendDateTime(value);
  return date == null ? value : DateFormat('MMM d, y').format(date);
}

class _ItemDetailsPagination extends StatelessWidget {
  const _ItemDetailsPagination({
    required this.page,
    required this.lastPage,
    required this.total,
    required this.totalLabel,
    required this.onPageChanged,
  });
  final int page;
  final int lastPage;
  final int total;
  final String totalLabel;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Row(
      children: <Widget>[
        Text('إجمالي $total $totalLabel', style: AppTextStyles.labelSmall),
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
    ),
  );
}
