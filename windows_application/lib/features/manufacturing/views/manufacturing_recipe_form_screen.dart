import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../inventory/models/inventory_models.dart';
import '../controllers/manufacturing_recipe_cubit.dart';
import '../controllers/manufacturing_recipe_state.dart';
import '../models/manufacturing_recipe_models.dart';

class _RecipeLineDraft {
  _RecipeLineDraft({this.materialId, this.unit, String quantity = ''})
    : quantityController = TextEditingController(text: quantity);
  int? materialId;
  String? unit;
  final TextEditingController quantityController;
}

class ManufacturingRecipeFormScreen extends StatefulWidget {
  const ManufacturingRecipeFormScreen({super.key, this.recipeId});
  final int? recipeId;

  @override
  State<ManufacturingRecipeFormScreen> createState() =>
      _ManufacturingRecipeFormScreenState();
}

class _ManufacturingRecipeFormScreenState
    extends State<ManufacturingRecipeFormScreen> {
  final TextEditingController _outputQuantity = TextEditingController(
    text: '1',
  );
  final TextEditingController _shelfLifeValue = TextEditingController();
  int? _productItemId;
  String _outputUnit = 'piece';
  String _shelfLifeUnit = 'days';
  bool _trackShelfLife = false;
  final List<_RecipeLineDraft> _lines = <_RecipeLineDraft>[];
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final ManufacturingRecipeCubit cubit = context
        .read<ManufacturingRecipeCubit>();
    Future<void>.microtask(() {
      cubit.loadIngredientCandidates();
      cubit.loadOutputItemCandidates();
      if (widget.recipeId != null) {
        cubit.loadRecipe(widget.recipeId!);
      }
    });
  }

  @override
  void dispose() {
    _outputQuantity.dispose();
    _shelfLifeValue.dispose();
    for (final _RecipeLineDraft line in _lines) {
      line.quantityController.dispose();
    }
    super.dispose();
  }

  void _hydrate(ManufacturingRecipeDetail recipe) {
    if (_hydrated) return;
    _hydrated = true;
    _productItemId = recipe.productItemId;
    _outputQuantity.text = recipe.yieldQuantity;
    _outputUnit = recipe.yieldUnit.isEmpty ? _outputUnit : recipe.yieldUnit;
    _trackShelfLife = recipe.shelfLife;
    if (recipe.shelfValue != null) {
      _shelfLifeValue.text = recipe.shelfValue.toString();
    }
    _shelfLifeUnit = recipe.shelfUnit ?? _shelfLifeUnit;
    _lines.clear();
    for (final ManufacturingRecipeLine line in recipe.rows) {
      _lines.add(
        _RecipeLineDraft(
          materialId: line.materialId,
          unit: line.unit,
          quantity: line.quantity,
        ),
      );
    }
    if (_lines.isEmpty) _lines.add(_RecipeLineDraft());
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ManufacturingRecipeCubit, ManufacturingRecipeState>(
    builder: (BuildContext context, ManufacturingRecipeState state) {
      if (widget.recipeId != null && state.selected?.id == widget.recipeId) {
        _hydrate(state.selected!);
      }
      if (_lines.isEmpty) _lines.add(_RecipeLineDraft());

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
              title: widget.recipeId == null ? 'وصفة جديدة' : 'تعديل الوصفة',
              subtitle: 'حدّد المنتج الناتج ومكوناته وكمياتها.',
              actions: <Widget>[
                AppButton(
                  label: 'إلغاء',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.go(AppRoutes.manufacturingRecipes),
                ),
                AppButton(
                  label: 'حفظ الوصفة',
                  icon: Icons.save_outlined,
                  onPressed: state.saving ? null : () => _save(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ManagementMessage(message: state.error!, error: true),
              ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('المنتج الناتج', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    initialValue: _productItemId,
                    decoration: const InputDecoration(labelText: 'المنتج'),
                    items: state.outputItemCandidates
                        .map(
                          (InventoryItem item) => DropdownMenuItem<int>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.recipeId == null
                        ? (int? value) => setState(() => _productItemId = value)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _outputQuantity,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'كمية الناتج',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _outputUnit,
                          decoration: const InputDecoration(
                            labelText: 'وحدة الناتج',
                          ),
                          items: InventoryUnit.fallback
                              .map(
                                (InventoryUnit unit) =>
                                    DropdownMenuItem<String>(
                                      value: unit.code,
                                      child: Text(unit.label),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (String? value) => setState(
                            () => _outputUnit = value ?? _outputUnit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('صلاحية محدودة'),
                    value: _trackShelfLife,
                    onChanged: (bool value) =>
                        setState(() => _trackShelfLife = value),
                  ),
                  if (_trackShelfLife)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _shelfLifeValue,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'مدة الصلاحية',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _shelfLifeUnit,
                            decoration: const InputDecoration(
                              labelText: 'الوحدة',
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem<String>(
                                value: 'days',
                                child: Text('أيام'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'hours',
                                child: Text('ساعات'),
                              ),
                            ],
                            onChanged: (String? value) => setState(
                              () => _shelfLifeUnit = value ?? _shelfLifeUnit,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('المكونات', style: AppTextStyles.titleMedium),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _lines.add(_RecipeLineDraft())),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة مكون'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    decoration: const InputDecoration(labelText: 'بحث المكونات', prefixIcon: Icon(Icons.search)),
                    onChanged: (value) => context.read<ManufacturingRecipeCubit>().loadIngredientCandidates(search: value),
                  ),
                  Row(children: [
                    TextButton(onPressed: () => context.read<ManufacturingRecipeCubit>().loadIngredientCandidates(), child: const Text('إعادة المحاولة')),
                    if (context.read<ManufacturingRecipeCubit>().ingredientPage < context.read<ManufacturingRecipeCubit>().ingredientLastPage)
                      TextButton(onPressed: () => context.read<ManufacturingRecipeCubit>().loadIngredientCandidates(nextPage: true), child: const Text('المزيد من المكونات')),
                  ]),
                  ..._lines.asMap().entries.map(
                    (MapEntry<int, _RecipeLineDraft> entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              initialValue: entry.value.materialId,
                              decoration: const InputDecoration(
                                labelText: 'المادة',
                              ),
                              items: state.ingredientCandidates
                                  .map(
                                    (InventoryItem item) =>
                                        DropdownMenuItem<int>(
                                          value: item.id,
                                          child: Text('${item.name} — ${item.quantity} ${item.unit}'),
                                        ),
                                  )
                                  .toList(growable: false),
                              onChanged: (int? value) => setState(() {
                                entry.value.materialId = value;
                                entry.value.unit ??= state.ingredientCandidates
                                    .where(
                                      (InventoryItem item) => item.id == value,
                                    )
                                    .cast<InventoryItem?>()
                                    .firstWhere((_) => true, orElse: () => null)
                                    ?.unit;
                              }),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: entry.value.quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'الكمية',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: entry.value.unit,
                              decoration: const InputDecoration(
                                labelText: 'الوحدة',
                              ),
                              items: InventoryUnit.fallback
                                  .map(
                                    (InventoryUnit unit) =>
                                        DropdownMenuItem<String>(
                                          value: unit.code,
                                          child: Text(unit.label),
                                        ),
                                  )
                                  .toList(growable: false),
                              onChanged: (String? value) =>
                                  setState(() => entry.value.unit = value),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _lines.length <= 1
                                ? null
                                : () => setState(
                                    () => _lines.removeAt(entry.key),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _save(BuildContext context) async {
    if (_productItemId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر المنتج الناتج.')));
      return;
    }
    final List<Map<String, dynamic>> lines = _lines
        .where(
          (_RecipeLineDraft line) =>
              line.materialId != null &&
              line.unit != null &&
              line.quantityController.text.trim().isNotEmpty,
        )
        .map(
          (_RecipeLineDraft line) => <String, dynamic>{
            'inventoryItemId': line.materialId,
            'quantity': line.quantityController.text.trim(),
            'unit': line.unit,
          },
        )
        .toList(growable: false);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مكوناً واحداً على الأقل.')),
      );
      return;
    }
    final ManufacturingRecipeCubit cubit = context
        .read<ManufacturingRecipeCubit>();
    final bool saved = await cubit.saveRecipe(<String, dynamic>{
      'productItemId': _productItemId,
      'outputQuantity': _outputQuantity.text.trim(),
      'outputUnit': _outputUnit,
      if (_trackShelfLife &&
          _shelfLifeValue.text.trim().isNotEmpty) ...<String, dynamic>{
        'shelfLifeValue': int.tryParse(_shelfLifeValue.text.trim()),
        'shelfLifeUnit': _shelfLifeUnit,
      },
      'lines': lines,
    }, id: widget.recipeId);
    if (!context.mounted) return;
    if (saved) {
      context.go(AppRoutes.manufacturingRecipes);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cubit.state.error ?? 'تعذر حفظ الوصفة')),
      );
    }
  }
}
