import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../inventory/controllers/inventory_cubit.dart';
import '../../inventory/controllers/inventory_state.dart';
import '../../inventory/widgets/warehouse_dropdown.dart';
import '../controllers/manufacturing_production_cubit.dart';
import '../controllers/manufacturing_production_state.dart';
import '../models/manufacturing_production_models.dart';

class ManufacturingProductionHistoryScreen extends StatefulWidget {
  const ManufacturingProductionHistoryScreen({super.key});

  @override
  State<ManufacturingProductionHistoryScreen> createState() =>
      _ManufacturingProductionHistoryScreenState();
}

class _ManufacturingProductionHistoryScreenState
    extends State<ManufacturingProductionHistoryScreen> {
  final TextEditingController _search = TextEditingController();
  int? _warehouseId;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _warehouseId = activeFactoryWarehouseId(context);
    final ManufacturingProductionCubit cubit = context
        .read<ManufacturingProductionCubit>();
    final InventoryCubit inventoryCubit = context.read<InventoryCubit>();
    final branchId = activeInventoryBranchId(context);
    Future<void>.microtask(() {
      cubit.loadOrders(warehouseId: _warehouseId, branchId: branchId);
      inventoryCubit.loadItems(branchId: branchId);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    context.read<ManufacturingProductionCubit>().loadOrders(
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      warehouseId: _warehouseId,
      branchId: activeInventoryBranchId(context),
      status: _status.isEmpty ? null : _status,
    );
  }

  @override
  Widget build(BuildContext context) => BranchChangeReload(
    onBranchChanged: () {
      setState(() => _warehouseId = activeFactoryWarehouseId(context));
      context.read<InventoryCubit>().loadItems(
        branchId: activeInventoryBranchId(context),
      );
      _load();
    },
    child: SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: BlocBuilder<ManufacturingProductionCubit, ManufacturingProductionState>(
        builder: (BuildContext context, ManufacturingProductionState state) =>
            BlocBuilder<InventoryCubit, InventoryState>(
              builder: (BuildContext context, InventoryState inventoryState) =>
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ManagementPageHeader(
                        title: 'سجل الإنتاج',
                        subtitle: 'كل عمليات الإنتاج المسجلة وحالاتها.',
                        actions: <Widget>[
                          AppButton(
                            label: 'إنتاج جديد',
                            icon: Icons.add,
                            onPressed: () => context.go(
                              AppRoutes.manufacturingProductionNew,
                            ),
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
                                hintText: 'ابحث بالمرجع أو المنتج',
                              ),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _status,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text('كل الحالات'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'draft',
                                child: Text('مسودة'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'completed',
                                child: Text('مكتمل'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'reversed',
                                child: Text('ملغي'),
                              ),
                            ],
                            onChanged: (String? value) {
                              setState(() => _status = value ?? '');
                              _load();
                            },
                          ),
                          WarehouseDropdown(
                            value: _warehouseId,
                            warehouses: inventoryState.warehouses,
                            onChanged: (int? value) {
                              setState(() => _warehouseId = value);
                              _load();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (state.loading && state.orders.isEmpty)
                        const Padding(
                          padding: AppSpacing.allXxl,
                          child: AppLoading(),
                        )
                      else if (state.orders.isEmpty)
                        const ManagementMessage(
                          message: 'لا توجد عمليات إنتاج.',
                        )
                      else
                        ManagementTableShell(
                          minWidth: 900,
                          child: DataTable(
                            headingRowColor:
                                const WidgetStatePropertyAll<Color>(
                                  AppColors.menuTableHeader,
                                ),
                            columns: const <DataColumn>[
                              DataColumn(label: Text('المرجع')),
                              DataColumn(label: Text('المنتج')),
                              DataColumn(label: Text('المخطط')),
                              DataColumn(label: Text('الفعلي')),
                              DataColumn(label: Text('التكلفة')),
                              DataColumn(label: Text('الحالة')),
                            ],
                            rows: state.orders
                                .map(
                                  (
                                    ManufacturingProductionListItem item,
                                  ) => DataRow(
                                    onSelectChanged: (_) => context.go(
                                      AppRoutes.manufacturingProductionDetailPath(
                                        item.id,
                                      ),
                                    ),
                                    cells: <DataCell>[
                                      DataCell(Text(item.id)),
                                      DataCell(Text(item.product)),
                                      DataCell(
                                        Text('${item.planned} ${item.unit}'),
                                      ),
                                      DataCell(
                                        Text(
                                          item.actual == null
                                              ? '—'
                                              : '${item.actual} ${item.unit}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item.actualCost ??
                                              item.plannedCost ??
                                              '—',
                                        ),
                                      ),
                                      DataCell(
                                        ManagementBadge(
                                          label: _statusLabel(item.status),
                                          tone: switch (item.status) {
                                            'completed' =>
                                              ManagementTone.success,
                                            'reversed' => ManagementTone.danger,
                                            _ => ManagementTone.neutral,
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                    ],
                  ),
            ),
      ),
    ),
  );
}

String _statusLabel(String status) => switch (status) {
  'completed' => 'مكتمل',
  'draft' => 'مسودة',
  'reversed' => 'ملغي',
  _ => status,
};
