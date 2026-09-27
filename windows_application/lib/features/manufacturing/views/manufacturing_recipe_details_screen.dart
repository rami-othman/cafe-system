import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/manufacturing_recipe_cubit.dart';
import '../controllers/manufacturing_recipe_state.dart';
import '../models/manufacturing_recipe_models.dart';

class ManufacturingRecipeDetailsScreen extends StatefulWidget {
  const ManufacturingRecipeDetailsScreen({super.key, required this.recipeId});
  final int recipeId;

  @override
  State<ManufacturingRecipeDetailsScreen> createState() =>
      _ManufacturingRecipeDetailsScreenState();
}

class _ManufacturingRecipeDetailsScreenState
    extends State<ManufacturingRecipeDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final ManufacturingRecipeCubit cubit = context
        .read<ManufacturingRecipeCubit>();
    Future<void>.microtask(() => cubit.loadRecipe(widget.recipeId));
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ManufacturingRecipeCubit, ManufacturingRecipeState>(
    builder: (BuildContext context, ManufacturingRecipeState state) {
      final ManufacturingRecipeDetail? recipe =
          state.selected?.id == widget.recipeId ? state.selected : null;
      return SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ManagementPageHeader(
              title: recipe?.name ?? 'تفاصيل الوصفة',
              subtitle: recipe == null
                  ? ''
                  : 'الإصدار v${recipe.version} · ${recipe.yieldQuantity} ${recipe.yieldUnit}',
              actions: recipe == null
                  ? const <Widget>[]
                  : <Widget>[
                      AppButton(
                        label: recipe.isActive
                            ? 'إيقاف الوصفة'
                            : 'تفعيل الوصفة',
                        variant: AppButtonVariant.outlined,
                        onPressed: () async {
                          final ManufacturingRecipeCubit cubit = context
                              .read<ManufacturingRecipeCubit>();
                          await cubit.setStatus(
                            recipe.id,
                            recipe.isActive ? 'inactive' : 'active',
                          );
                        },
                      ),
                      AppButton(
                        label: 'تعديل',
                        icon: Icons.edit_outlined,
                        onPressed: () => context.go(
                          AppRoutes.manufacturingRecipeEditPath(recipe.id),
                        ),
                      ),
                      AppButton(
                        label: 'إنتاج',
                        icon: Icons.precision_manufacturing_outlined,
                        onPressed: () => context.go(
                          AppRoutes.manufacturingProductionNewForRecipePath(
                            recipe.id,
                          ),
                        ),
                      ),
                    ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.loading && recipe == null)
              const Padding(padding: AppSpacing.allXxl, child: AppLoading())
            else if (state.error != null && recipe == null)
              ManagementMessage(message: state.error!, error: true)
            else if (recipe == null)
              const ManagementMessage(message: 'الوصفة غير موجودة.')
            else
              _RecipeDetailsBody(recipe: recipe),
          ],
        ),
      );
    },
  );
}

class _RecipeDetailsBody extends StatelessWidget {
  const _RecipeDetailsBody({required this.recipe});
  final ManufacturingRecipeDetail recipe;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          ManagementKpiCard(
            label: 'تكلفة المواد',
            value: recipe.hasMissingCost
                ? 'غير متاحة'
                : (recipe.materialsCost?.toStringAsFixed(2) ?? '—'),
            icon: Icons.payments_outlined,
          ),
          ManagementKpiCard(
            label: 'تكلفة الوحدة',
            value: recipe.hasMissingCost
                ? 'غير متاحة'
                : (recipe.unitCost?.toStringAsFixed(4) ?? '—'),
            icon: Icons.calculate_outlined,
          ),
          if (recipe.shelfLife)
            ManagementKpiCard(
              label: 'الصلاحية',
              value:
                  '${recipe.shelfValue ?? '—'} ${recipe.shelfUnit == 'hours' ? 'ساعة' : 'يوم'}',
              icon: Icons.schedule_outlined,
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('المكونات', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ManagementTableShell(
              minWidth: 700,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll<Color>(
                  AppColors.menuTableHeader,
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('المادة')),
                  DataColumn(label: Text('الكمية')),
                  DataColumn(label: Text('التكلفة')),
                ],
                rows: recipe.rows
                    .map(
                      (ManufacturingRecipeLine line) => DataRow(
                        cells: <DataCell>[
                          DataCell(
                            Text(
                              line.semiFinished
                                  ? '${line.name} (نصف مصنع)'
                                  : line.name,
                            ),
                          ),
                          DataCell(Text('${line.quantity} ${line.unit}')),
                          DataCell(
                            Text(
                              line.error != null
                                  ? 'غير متاحة'
                                  : (line.cost?.toStringAsFixed(2) ?? '—'),
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
      const SizedBox(height: AppSpacing.lg),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('آخر عمليات الإنتاج', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (recipe.history.isEmpty)
              const ManagementMessage(message: 'لا يوجد سجل إنتاج بعد.')
            else
              Column(
                children: recipe.history
                    .map(
                      (ManufacturingRecipeHistoryEntry entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.id),
                        subtitle: Text(
                          'مخطط ${entry.planned}${entry.actual != null ? ' · فعلي ${entry.actual}' : ''}',
                        ),
                        trailing: Text(entry.date ?? ''),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    ],
  );
}
