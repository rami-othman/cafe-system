import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../inventory/controllers/inventory_cubit.dart';
import '../../inventory/controllers/inventory_state.dart';
import '../../inventory/widgets/warehouse_dropdown.dart';
import '../controllers/manufacturing_production_cubit.dart';
import '../controllers/manufacturing_production_state.dart';
import '../controllers/manufacturing_recipe_cubit.dart';
import '../controllers/manufacturing_recipe_state.dart';
import '../models/manufacturing_production_models.dart';
import '../models/manufacturing_recipe_models.dart';

/// Recipe select -> preview -> draft creation, the first step of the
/// Production flow (`GET production/preview` then `POST production/drafts`).
/// Every number shown in the preview table comes straight from the backend.
class ManufacturingProductionNewScreen extends StatefulWidget {
  const ManufacturingProductionNewScreen({super.key, this.recipeId});
  final int? recipeId;

  @override
  State<ManufacturingProductionNewScreen> createState() =>
      _ManufacturingProductionNewScreenState();
}

class _ManufacturingProductionNewScreenState
    extends State<ManufacturingProductionNewScreen> {
  final TextEditingController _qty = TextEditingController(text: '1');
  int? _recipeId;
  int? _warehouseId;

  @override
  void initState() {
    super.initState();
    _recipeId = widget.recipeId;
    _warehouseId = activeFactoryWarehouseId(context);
    final ManufacturingRecipeCubit recipeCubit = context
        .read<ManufacturingRecipeCubit>();
    final InventoryCubit inventoryCubit = context.read<InventoryCubit>();
    final branchId = activeInventoryBranchId(context);
    Future<void>.microtask(() {
      recipeCubit.loadRecipes(status: 'active');
      inventoryCubit.loadItems(branchId: branchId, warehouseId: _warehouseId);
    });
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (_recipeId == null) return;
    context.read<ManufacturingProductionCubit>().loadPreview(
      recipeId: _recipeId!,
      qty: _qty.text.trim().isEmpty ? '0' : _qty.text.trim(),
      warehouseId: _warehouseId,
      branchId: activeInventoryBranchId(context),
    );
  }

  @override
  Widget build(BuildContext context) => BranchChangeReload(
    onBranchChanged: () {
      setState(() => _warehouseId = activeFactoryWarehouseId(context));
      context.read<InventoryCubit>().loadItems(
        branchId: activeInventoryBranchId(context),
        warehouseId: _warehouseId,
      );
      _refreshPreview();
    },
    child: SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: BlocBuilder<ManufacturingRecipeCubit, ManufacturingRecipeState>(
        builder: (BuildContext context, ManufacturingRecipeState recipeState) =>
            BlocBuilder<
              ManufacturingProductionCubit,
              ManufacturingProductionState
            >(
              builder:
                  (
                    BuildContext context,
                    ManufacturingProductionState productionState,
                  ) => BlocBuilder<InventoryCubit, InventoryState>(
                    builder:
                        (
                          BuildContext context,
                          InventoryState inventoryState,
                        ) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const ManagementPageHeader(
                              title: 'إنتاج جديد',
                              subtitle:
                                  'اختر الوصفة والكمية لعرض معاينة الاستهلاك والتكلفة.',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  DropdownButtonFormField<int>(
                                    initialValue: _recipeId,
                                    decoration: const InputDecoration(
                                      labelText: 'الوصفة',
                                    ),
                                    items: recipeState.recipes
                                        .map(
                                          (ManufacturingRecipeSummary recipe) =>
                                              DropdownMenuItem<int>(
                                                value: recipe.id,
                                                child: Text(recipe.name),
                                              ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (int? value) {
                                      setState(() => _recipeId = value);
                                      _refreshPreview();
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: TextFormField(
                                          controller: _qty,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: const InputDecoration(
                                            labelText: 'الكمية المطلوب إنتاجها',
                                          ),
                                          onChanged: (_) => _refreshPreview(),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      WarehouseDropdown(
                                        value: _warehouseId,
                                        warehouses: inventoryState.warehouses,
                                        onChanged: (int? value) {
                                          setState(() => _warehouseId = value);
                                          _refreshPreview();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (productionState.error != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: ManagementMessage(
                                  message: productionState.error!,
                                  error: true,
                                ),
                              ),
                            if (productionState.preview != null)
                              _PreviewCard(preview: productionState.preview!),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton(
                              label: productionState.submitting
                                  ? 'جارٍ الإنشاء...'
                                  : 'إنشاء مسودة إنتاج',
                              icon: Icons.playlist_add_check_outlined,
                              onPressed:
                                  (_recipeId == null ||
                                      _warehouseId == null ||
                                      productionState.submitting)
                                  ? null
                                  : () => _createDraft(context),
                            ),
                          ],
                        ),
                  ),
            ),
      ),
    ),
  );

  Future<void> _createDraft(BuildContext context) async {
    final ManufacturingProductionCubit cubit = context
        .read<ManufacturingProductionCubit>();
    final bool ok = await cubit.createDraft(
      recipeId: _recipeId!,
      qty: _qty.text.trim(),
      warehouseId: _warehouseId!,
      branchId: activeInventoryBranchId(context),
    );
    if (!context.mounted) return;
    if (ok && cubit.state.draft != null) {
      context.go(
        AppRoutes.manufacturingProductionCompletePath(cubit.state.draft!.id),
      );
    }
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});
  final ManufacturingProductionPreview preview;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text('معاينة الاستهلاك', style: AppTextStyles.titleMedium),
            Text(
              preview.batchCost == null
                  ? 'التكلفة: غير متاحة'
                  : 'التكلفة: ${preview.batchCost!.toStringAsFixed(2)} (${preview.unitCost?.toStringAsFixed(4) ?? '—'} للوحدة)',
              style: AppTextStyles.labelMedium,
            ),
          ],
        ),
        if (preview.hasInsufficient)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: ManagementBadge(
              label: 'مخزون غير كافٍ',
              tone: ManagementTone.danger,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        ManagementTableShell(
          minWidth: 700,
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll<Color>(
              AppColors.menuTableHeader,
            ),
            columns: const <DataColumn>[
              DataColumn(label: Text('المادة')),
              DataColumn(label: Text('المطلوب')),
              DataColumn(label: Text('المتاح')),
              DataColumn(label: Text('الحالة')),
            ],
            rows: preview.rows
                .map(
                  (ManufacturingProductionPreviewRow row) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(row.name)),
                      DataCell(
                        Text(
                          row.reqBase == null
                              ? '—'
                              : '${row.reqBase} ${row.baseUnit}',
                        ),
                      ),
                      DataCell(
                        Text(row.available == null ? '—' : '${row.available}'),
                      ),
                      DataCell(
                        ManagementBadge(
                          label: row.status,
                          tone: switch (row.level) {
                            'ok' => ManagementTone.success,
                            'danger' => ManagementTone.danger,
                            'warning' => ManagementTone.warning,
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
  );
}
