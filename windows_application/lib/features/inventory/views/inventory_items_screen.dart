import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/inventory_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../controllers/inventory_cubit.dart';
import '../controllers/inventory_state.dart';
import '../models/inventory_models.dart';
import 'widgets/inventory_item_widgets.dart';

class InventoryItemsScreen extends StatefulWidget {
  const InventoryItemsScreen({super.key});
  @override
  State<InventoryItemsScreen> createState() => _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends State<InventoryItemsScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = '';
  String _type = '';
  String _stockStatus = '';
  int? _warehouseId;

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
  Widget build(BuildContext context) => DesktopPageLayout(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
    ),
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'المواد المخزنية',
            subtitle: 'إدارة أصناف المقهى وتكلفتها وقواعد توفرها في المخازن.',
            actions: <Widget>[
              AppButton(
                label: 'إضافة مادة',
                icon: Icons.add,
                onPressed: () => context.go(AppRoutes.inventoryItemCreate),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ItemFilters(
            searchController: _search,
            category: _category,
            type: _type,
            stockStatus: _stockStatus,
            warehouseId: _warehouseId,
            categories: state.itemCategories,
            warehouses: state.warehouses
                .map(
                  (WarehouseLocation item) =>
                      (id: item.id, name: item.displayName),
                )
                .toList(growable: false),
            onSearch: (_) => _load(),
            onCategoryChanged: (String value) {
              setState(() => _category = value);
              _load();
            },
            onTypeChanged: (String value) {
              setState(() => _type = value);
              _load();
            },
            onStatusChanged: (String value) {
              setState(() => _stockStatus = value);
              _load();
            },
            onWarehouseChanged: (int? value) {
              setState(() => _warehouseId = value);
              _load();
            },
            onClear: _clear,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _body(state)),
        ],
      ),
    ),
  );

  Widget _body(InventoryState state) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ManagementMessage(
        message: state.error!,
        error: true,
        onRetry: _load,
      );
    }
    if (state.items.isEmpty) {
      return const ManagementMessage(
        message: 'لا توجد مواد تطابق المرشحات المحددة.',
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: ItemTable(
            items: state.items,
            onOpen: (InventoryItem item) =>
                context.go(AppRoutes.inventoryItemDetailPath(item.id)),
            onEdit: (InventoryItem item) =>
                context.go(AppRoutes.inventoryItemEditPath(item.id)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Text('${state.itemsTotal} مادة', style: AppTextStyles.bodySmall),
            const Spacer(),
            Text(
              'الصفحة ${state.itemsPage} من ${state.itemsLastPage}',
              style: AppTextStyles.bodySmall,
            ),
            TextButton.icon(
              onPressed: state.itemsPage > 1
                  ? () => _load(state.itemsPage - 1)
                  : null,
              icon: const Icon(Icons.navigate_before),
              label: const Text('السابق'),
            ),
            TextButton.icon(
              onPressed: state.itemsPage < state.itemsLastPage
                  ? () => _load(state.itemsPage + 1)
                  : null,
              icon: const Icon(Icons.navigate_next),
              label: const Text('التالي'),
            ),
          ],
        ),
      ],
    );
  }

  void _load([int page = 1]) => context.read<InventoryCubit>().loadItems(
    search: _search.text.trim(),
    type: _type,
    category: _category,
    stockStatus: _stockStatus,
    warehouseId: _warehouseId,
    page: page,
  );

  void _clear() {
    _search.clear();
    setState(() {
      _category = '';
      _type = '';
      _stockStatus = '';
      _warehouseId = null;
    });
    _load();
  }
}
