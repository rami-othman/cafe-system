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
  late final TabController _tabs = TabController(length: 5, vsync: this);
  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() => cubit.loadItemDetails(widget.itemId));
  }

  @override
  void dispose() {
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
                  _movements(state.itemMovements),
                  const ManagementMessage(
                    message: 'لا تتوفر بيانات استخدام الوصفات بعد.',
                  ),
                  const ManagementMessage(message: 'لا يتوفر سجل شراء بعد.'),
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
  Widget _movements(List<InventoryMovement> movements) => movements.isEmpty
      ? const ManagementMessage(message: 'لا توجد حركات مخزون لهذه المادة.')
      : ListView.separated(
          itemCount: movements.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (BuildContext context, int index) {
            final InventoryMovement movement = movements[index];
            return ListTile(
              title: Text(movement.type),
              subtitle: Text(
                '${movement.warehouseName} · ${_movementDateTime(movement.occurredAt)}',
              ),
              trailing: Text(
                '${inventoryNumber(movement.quantityIn == '0.000' ? movement.quantityOut : movement.quantityIn, digits: 3)} ${inventoryUnitLabel(movement.unit)}',
              ),
            );
          },
        );
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
