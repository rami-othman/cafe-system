import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../inventory/controllers/inventory_cubit.dart';
import '../../inventory/controllers/inventory_state.dart';
import '../../inventory/models/inventory_models.dart';
import '../../inventory/views/widgets/inventory_item_widgets.dart';
import '../../inventory/widgets/warehouse_dropdown.dart';

/// Manufacturing's Materials tab: the same `InventoryItem` list Inventory
/// itself uses (`ItemTable`/`ItemFilters`), scoped to the four item types
/// Manufacturing actually cares about (raw material / semi-finished /
/// finished good / packaging) and routed under `/manufacturing/materials/*`.
/// All data access goes through the existing `InventoryRepository`/
/// `InventoryCubit` - there is no parallel Manufacturing materials API.
class ManufacturingMaterialsScreen extends StatefulWidget {
  const ManufacturingMaterialsScreen({super.key});

  @override
  State<ManufacturingMaterialsScreen> createState() =>
      _ManufacturingMaterialsScreenState();
}

class _ManufacturingMaterialsScreenState
    extends State<ManufacturingMaterialsScreen> {
  final TextEditingController _search = TextEditingController();
  String _type = '';
  int? _warehouseId;

  static const Set<String> _materialTypes = <String>{
    'raw_material',
    'semi_finished_good',
    'finished_good',
    'packaging',
  };

  @override
  void initState() {
    super.initState();
    _warehouseId = activeFactoryWarehouseId(context);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load([int page = 1]) {
    context.read<InventoryCubit>().loadItems(
      branchId: activeInventoryBranchId(context),
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      type: _type.isEmpty ? null : _type,
      types: _materialTypes.toList(growable: false),
      warehouseId: _warehouseId,
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) => BranchChangeReload(
    onBranchChanged: () {
      setState(() => _warehouseId = activeFactoryWarehouseId(context));
      _load();
    },
    child: SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (BuildContext context, InventoryState state) {
          final List<InventoryItem> materials = state.items;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ManagementPageHeader(
                title: 'المواد',
                subtitle:
                    'المواد الخام ونصف المصنعة والتغليف المستخدمة في التصنيع.',
                actions: <Widget>[
                  AppButton(
                    label: 'شراء مواد',
                    icon: Icons.move_to_inbox_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(AppRoutes.financePurchasesNew),
                  ),
                  AppButton(
                    label: 'إضافة مادة',
                    icon: Icons.add,
                    onPressed: () =>
                        context.go(AppRoutes.manufacturingMaterialCreate),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ManagementFilterBar(
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_outlined),
                        hintText: 'ابحث بالاسم أو SKU',
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _type,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text('كل الأنواع'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'raw_material',
                        child: Text('مادة خام'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'semi_finished_good',
                        child: Text('نصف مصنع'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'finished_good',
                        child: Text('منتج جاهز'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'packaging',
                        child: Text('تغليف'),
                      ),
                    ],
                    onChanged: (String? value) {
                      setState(() => _type = value ?? '');
                      _load();
                    },
                  ),
                  WarehouseDropdown(
                    value: _warehouseId,
                    warehouses: state.warehouses,
                    allLabel: 'كل المخازن',
                    onChanged: (int? value) {
                      setState(() => _warehouseId = value);
                      _load();
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.loading && materials.isEmpty)
                const Padding(padding: AppSpacing.allXxl, child: AppLoading())
              else if (state.error != null)
                ManagementMessage(
                  message: state.error!,
                  error: true,
                  onRetry: () => _load(state.itemsPage),
                )
              else if (materials.isEmpty)
                const ManagementMessage(message: 'لا توجد مواد مطابقة.')
              else
                ItemTable(
                  items: materials,
                  onOpen: (InventoryItem item) => context.go(
                    AppRoutes.manufacturingMaterialDetailPath(item.id),
                  ),
                  onEdit: (InventoryItem item) => context.go(
                    AppRoutes.manufacturingMaterialEditPath(item.id),
                  ),
                ),
              if (state.error == null && state.itemsLastPage > 1)
                Row(
                  children: <Widget>[
                    Text('${state.itemsTotal} مادة'),
                    const Spacer(),
                    Text('الصفحة ${state.itemsPage} من ${state.itemsLastPage}'),
                    TextButton(
                      onPressed: !state.loading && state.itemsPage > 1
                          ? () => _load(state.itemsPage - 1)
                          : null,
                      child: const Text('السابق'),
                    ),
                    TextButton(
                      onPressed:
                          !state.loading &&
                              state.itemsPage < state.itemsLastPage
                          ? () => _load(state.itemsPage + 1)
                          : null,
                      child: const Text('التالي'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}
