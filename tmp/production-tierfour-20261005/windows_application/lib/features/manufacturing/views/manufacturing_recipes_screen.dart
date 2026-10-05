import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/manufacturing_recipe_cubit.dart';
import '../controllers/manufacturing_recipe_state.dart';
import '../models/manufacturing_recipe_models.dart';

class ManufacturingRecipesScreen extends StatefulWidget {
  const ManufacturingRecipesScreen({super.key});

  @override
  State<ManufacturingRecipesScreen> createState() =>
      _ManufacturingRecipesScreenState();
}

class _ManufacturingRecipesScreenState
    extends State<ManufacturingRecipesScreen> {
  final TextEditingController _search = TextEditingController();
  String _status = '';

  @override
  void initState() {
    super.initState();
    final ManufacturingRecipeCubit cubit = context
        .read<ManufacturingRecipeCubit>();
    Future<void>.microtask(cubit.loadRecipes);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    context.read<ManufacturingRecipeCubit>().loadRecipes(
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      status: _status.isEmpty ? null : _status,
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
    ),
    child: BlocBuilder<ManufacturingRecipeCubit, ManufacturingRecipeState>(
      builder: (BuildContext context, ManufacturingRecipeState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'الوصفات',
            subtitle: 'وصفات التصنيع ومكوناتها وتكلفتها التقديرية.',
            actions: <Widget>[
              AppButton(
                label: 'وصفة جديدة',
                icon: Icons.add,
                onPressed: () =>
                    context.go(AppRoutes.manufacturingRecipeCreate),
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
                    hintText: 'ابحث باسم المنتج',
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
                    value: 'active',
                    child: Text('نشطة'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'inactive',
                    child: Text('غير نشطة'),
                  ),
                ],
                onChanged: (String? value) {
                  setState(() => _status = value ?? '');
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (state.loading && state.recipes.isEmpty)
            const Padding(padding: AppSpacing.allXxl, child: AppLoading())
          else if (state.error != null && state.recipes.isEmpty)
            ManagementMessage(
              message: state.error!,
              error: true,
              onRetry: _load,
            )
          else if (state.recipes.isEmpty)
            const ManagementMessage(message: 'لا توجد وصفات بعد.')
          else
            ManagementTableShell(
              minWidth: 900,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll<Color>(
                  AppColors.menuTableHeader,
                ),
                columns: const <DataColumn>[
                  DataColumn(label: Text('المنتج')),
                  DataColumn(label: Text('الإصدار')),
                  DataColumn(label: Text('الناتج')),
                  DataColumn(label: Text('تكلفة الوحدة')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('')),
                ],
                rows: state.recipes
                    .map(
                      (ManufacturingRecipeSummary recipe) => DataRow(
                        onSelectChanged: (_) => context.go(
                          AppRoutes.manufacturingRecipeDetailPath(recipe.id),
                        ),
                        cells: <DataCell>[
                          DataCell(Text(recipe.name)),
                          DataCell(Text('v${recipe.version}')),
                          DataCell(
                            Text('${recipe.yieldQuantity} ${recipe.yieldUnit}'),
                          ),
                          DataCell(
                            Text(
                              recipe.unitCost == null
                                  ? '—'
                                  : recipe.unitCost!.toStringAsFixed(4),
                            ),
                          ),
                          DataCell(
                            ManagementBadge(
                              label: recipe.isActive ? 'نشطة' : 'غير نشطة',
                              tone: recipe.isActive
                                  ? ManagementTone.success
                                  : ManagementTone.neutral,
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'تعديل',
                              onPressed: () => context.go(
                                AppRoutes.manufacturingRecipeEditPath(
                                  recipe.id,
                                ),
                              ),
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
  );
}
