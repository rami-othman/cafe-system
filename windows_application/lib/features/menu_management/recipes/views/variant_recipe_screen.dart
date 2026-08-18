// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/menu_management_route_locations.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/catalog_models.dart';
import '../controllers/recipe_cubits.dart';
import '../models/recipe_models.dart';

void _returnToRecipeWorkspace(
  BuildContext context,
  int productId,
  int variantId,
) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(
    MenuManagementRouteLocations.productWorkspace(
      productId,
      tab: ProductWorkspaceTab.recipe,
      variantId: variantId,
    ),
  );
}

class VariantRecipeScreen extends StatefulWidget {
  const VariantRecipeScreen({
    super.key,
    required this.variantId,
    this.productId,
    this.editMode = false,
    this.readOnly = false,
    this.returnToRecipeWorkspace = false,
  });
  final int variantId;
  final int? productId;
  final bool editMode;
  final bool readOnly;
  final bool returnToRecipeWorkspace;
  @override
  State<VariantRecipeScreen> createState() => _VariantRecipeScreenState();
}

class _VariantRecipeScreenState extends State<VariantRecipeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<VariantRecipeCubit>().load(
        widget.variantId,
        productId: widget.productId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<VariantRecipeCubit, VariantRecipeState>(
        listenWhen: (a, b) => a.error != b.error && b.error != null,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).commonError)),
            ),
        builder: (context, state) {
          if (state.loading && state.recipe == null)
            return const Center(child: CircularProgressIndicator());
          if (state.recipe == null) {
            return Center(
              child: FilledButton(
                onPressed: () => context.read<VariantRecipeCubit>().load(
                  widget.variantId,
                  productId: widget.productId,
                ),
                child: Text(context.maybeL10n?.modifierRetry ?? 'Retry'),
              ),
            );
          }
          if (state.product == null || widget.editMode) {
            return _StandaloneRecipeEditor(
              key: const Key('standalone-recipe-editor'),
              state: state,
              variantId: widget.variantId,
              readOnly: widget.readOnly,
              onComplete: widget.returnToRecipeWorkspace
                  ? () => _returnToRecipeWorkspace(
                      context,
                      widget.productId!,
                      widget.variantId,
                    )
                  : null,
            );
          }
          return _RecipeWorkspaceBody(
            state: state,
            product: state.product,
            initialVariantId: widget.variantId,
            readOnly: widget.readOnly,
            embedded: false,
          );
        },
      );
}

/// Recipe & Materials content used inside the existing Product Workspace.
class RecipeMaterialsWorkspace extends StatefulWidget {
  const RecipeMaterialsWorkspace({
    super.key,
    required this.product,
    this.readOnly = false,
    this.selectedVariantId,
    this.onVariantChanged,
  });
  final ProductDetail product;
  final bool readOnly;
  final int? selectedVariantId;
  final ValueChanged<int>? onVariantChanged;
  @override
  State<RecipeMaterialsWorkspace> createState() =>
      _RecipeMaterialsWorkspaceState();
}

class _RecipeMaterialsWorkspaceState extends State<RecipeMaterialsWorkspace> {
  int? _loadedVariantId;
  bool _correctingInvalidRoute = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedVariant();
  }

  @override
  void didUpdateWidget(covariant RecipeMaterialsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedVariantId != widget.selectedVariantId ||
        oldWidget.product.id != widget.product.id) {
      _loadSelectedVariant();
    }
  }

  List<ProductVariant> get _recipeVariants => widget.product.variants
      .where((variant) => !variant.isArchived)
      .toList(growable: false);

  int get _fallbackVariantId {
    final defaultVariant = widget.product.defaultVariant;
    if (defaultVariant != null && !defaultVariant.isArchived) {
      return defaultVariant.id;
    }
    return _recipeVariants.isEmpty ? 0 : _recipeVariants.first.id;
  }

  int get _selectedVariantId {
    final requested = widget.selectedVariantId;
    if (requested != null &&
        _recipeVariants.any((variant) => variant.id == requested)) {
      return requested;
    }
    return _fallbackVariantId;
  }

  void _loadSelectedVariant() {
    final selected = _selectedVariantId;
    if (selected <= 0 || _loadedVariantId == selected) return;
    _loadedVariantId = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VariantRecipeCubit>().load(
        selected,
        productId: widget.product.id,
      );
      if (widget.selectedVariantId != selected &&
          widget.onVariantChanged != null &&
          !_correctingInvalidRoute) {
        _correctingInvalidRoute = true;
        widget.onVariantChanged!(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<VariantRecipeCubit, VariantRecipeState>(
        builder: (context, state) {
          final selectedVariantId = _selectedVariantId;
          if (selectedVariantId == 0 || _recipeVariants.isEmpty)
            return const _EmptyRecipeWorkspace();
          return _RecipeWorkspaceBody(
            state: state,
            product: widget.product,
            initialVariantId: selectedVariantId,
            readOnly: widget.readOnly || widget.product.isArchived,
            embedded: true,
            onVariantChanged: widget.onVariantChanged,
          );
        },
      );
}

class _RecipeWorkspaceBody extends StatelessWidget {
  const _RecipeWorkspaceBody({
    required this.state,
    required this.initialVariantId,
    required this.readOnly,
    required this.embedded,
    this.product,
    this.onVariantChanged,
  });
  final VariantRecipeState state;
  final ProductDetail? product;
  final int initialVariantId;
  final bool readOnly;
  final bool embedded;
  final ValueChanged<int>? onVariantChanged;

  @override
  Widget build(BuildContext context) {
    final recipe = state.recipe?.variantId == initialVariantId
        ? state.recipe
        : null;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!embedded) ...<Widget>[
            Text(
              l10n.recipeMaterials,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.recipeConsumptionHelp,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (product != null) ...<Widget>[
            _VariantPicker(
              product: product!,
              selectedId: initialVariantId,
              onChanged: readOnly ? null : onVariantChanged,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _RecipeStatus(
                    configured: recipe != null && recipe.components.isNotEmpty,
                    count: recipe?.components.length ?? 0,
                    recipeRequired: product?.isStockTracked ?? false,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BaseRecipeCard(
                    recipe: recipe,
                    materials: state.materials,
                    readOnly: readOnly,
                    variantId: initialVariantId,
                    productId: product?.id,
                  ),
                  if (product != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    _ModifierEffectsCard(
                      product: product!,
                      profiles: state.profiles,
                      materials: state.materials,
                      variantId: initialVariantId,
                    ),
                  ],
                ],
              );
              final testPanel = _TestRecipePanel(
                onPressed: product == null
                    ? null
                    : () => context.push(
                        MenuManagementRouteLocations.recipeTest(
                          product!.id,
                          initialVariantId,
                        ),
                      ),
              );
              if (constraints.maxWidth < 900)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    main,
                    const SizedBox(height: AppSpacing.md),
                    testPanel,
                  ],
                );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: main),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(width: 250, child: testPanel),
                ],
              );
            },
          ),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.product,
    required this.selectedId,
    this.onChanged,
  });
  final ProductDetail product;
  final int selectedId;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Text(
            AppLocalizations.of(context).recipeVariant,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              value: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: product.variants
                  .where((variant) => !variant.isArchived)
                  .map(
                    (v) => DropdownMenuItem<int>(
                      value: v.id,
                      child: Text(
                        v.displayName(Localizations.localeOf(context)),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onChanged == null
                  ? null
                  : (id) {
                      if (id != null) onChanged!(id);
                    },
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecipeStatus extends StatelessWidget {
  const _RecipeStatus({
    required this.configured,
    required this.count,
    required this.recipeRequired,
  });
  final bool configured;
  final int count;
  final bool recipeRequired;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: configured
            ? const Color(0xFFE6F3E8)
            : recipeRequired
            ? const Color(0xFFFFF1E5)
            : AppColors.contentBackground,
        borderRadius: AppRadius.control,
      ),
      child: Text(
        configured
            ? 'Recipe configured · $count materials'
            : recipeRequired
            ? AppLocalizations.of(context).recipeMissing
            : AppLocalizations.of(context).recipeNotConfigured,
        style: TextStyle(
          color: configured
              ? AppColors.success
              : recipeRequired
              ? AppColors.warning
              : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _BaseRecipeCard extends StatelessWidget {
  const _BaseRecipeCard({
    required this.recipe,
    required this.materials,
    required this.readOnly,
    required this.variantId,
    this.productId,
  });
  final VariantRecipe? recipe;
  final List<RecipeMaterial> materials;
  final bool readOnly;
  final int variantId;
  final int? productId;
  @override
  Widget build(BuildContext context) {
    final components = recipe?.components ?? const <RecipeComponent>[];
    final String editorRoute = productId == null
        ? '/menu-management/product-variants/$variantId/recipe'
        : MenuManagementRouteLocations.recipeEditor(productId!, variantId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _SectionHeading(
                    title: AppLocalizations.of(context).baseRecipe,
                    subtitle: AppLocalizations.of(
                      context,
                    ).recipeConsumptionHelp,
                  ),
                ),
                if (!readOnly)
                  OutlinedButton.icon(
                    onPressed: () => context.push(editorRoute),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: Text(AppLocalizations.of(context).manageRecipe),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (components.isEmpty)
              _EmptyRecipeState(
                readOnly: readOnly,
                variantId: variantId,
                productId: productId,
              )
            else
              ...components.map(
                (component) => _MaterialSummaryRow(
                  name: _materialName(materials, component),
                  subtitle: _materialSubtitle(materials, component),
                  quantity: component.quantity,
                  unit: component.unitCode,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecipeState extends StatelessWidget {
  const _EmptyRecipeState({
    required this.readOnly,
    required this.variantId,
    this.productId,
  });
  final bool readOnly;
  final int variantId;
  final int? productId;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.contentBackground,
      borderRadius: AppRadius.control,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(AppLocalizations.of(context).recipeNoComponentsHelp),
        ),
        if (!readOnly)
          TextButton(
            onPressed: () => context.push(
              productId == null
                  ? '/menu-management/product-variants/$variantId/recipe'
                  : MenuManagementRouteLocations.recipeEditor(
                      productId!,
                      variantId,
                    ),
            ),
            child: Text(AppLocalizations.of(context).addMaterial),
          ),
      ],
    ),
  );
}

class _MaterialSummaryRow extends StatelessWidget {
  const _MaterialSummaryRow({
    required this.name,
    this.subtitle,
    required this.quantity,
    required this.unit,
  });
  final String name;
  final String? subtitle;
  final String quantity;
  final String unit;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: AppColors.contentBackground,
      borderRadius: AppRadius.control,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: <Widget>[
        const Icon(
          Icons.inventory_2_outlined,
          size: 20,
          color: AppColors.secondary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
              ),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '$quantity $unit',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

class _ModifierEffectsCard extends StatelessWidget {
  const _ModifierEffectsCard({
    required this.product,
    required this.profiles,
    required this.materials,
    required this.variantId,
  });
  final ProductDetail product;
  final Map<int, ModifierRecipeProfile> profiles;
  final List<RecipeMaterial> materials;
  final int variantId;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionHeading(
            title: AppLocalizations.of(context).recipeModifierMaterialEffects,
            subtitle: AppLocalizations.of(
              context,
            ).recipeModifierMaterialEffectsHelp,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final group in product.modifierGroups.where(
            (group) => group.isActive && !group.isArchived,
          )) ...<Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
              child: Text(
                group
                    .displayName(Localizations.localeOf(context))
                    .toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: .5,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.control,
              ),
              child: Column(
                children: group.options
                    .where((option) => option.isActive && !option.isArchived)
                    .map((option) {
                      final profile = profiles[option.id];
                      return _EffectRow(
                        optionName: option.displayName(
                          Localizations.localeOf(context),
                        ),
                        summary: _effectSummary(profile, materials),
                        source: _effectSource(profile, variantId, product),
                        onEdit: () => context.push(
                          MenuManagementRouteLocations.variantMaterialEffect(
                            product.id,
                            variantId,
                            option.id,
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    ),
  );
}

class _EffectRow extends StatelessWidget {
  const _EffectRow({
    required this.optionName,
    required this.summary,
    required this.source,
    required this.onEdit,
  });
  final String optionName;
  final String summary;
  final String source;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 12,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                optionName,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(summary, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(
                source,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(AppLocalizations.of(context).commonEdit),
        ),
      ],
    ),
  );
}

class _TestRecipePanel extends StatelessWidget {
  const _TestRecipePanel({required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF8F1),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppLocalizations.of(context).recipeTest,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppLocalizations.of(context).recipeSimulationHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.science_outlined, size: 17),
            label: Text(AppLocalizations.of(context).recipeTest),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 3),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

String _materialName(
  List<RecipeMaterial> materials,
  RecipeComponent component,
) =>
    component.materialName ??
    materials.firstWhereOrNull((m) => m.id == component.materialId)?.name ??
    'Material #${component.materialId}';
String? _materialSubtitle(
  List<RecipeMaterial> materials,
  RecipeComponent component,
) =>
    materials.firstWhereOrNull((m) => m.id == component.materialId)?.sku == null
    ? null
    : 'SKU ${materials.firstWhereOrNull((m) => m.id == component.materialId)!.sku}';

String _effectSource(
  ModifierRecipeProfile? profile,
  int variantId,
  ProductDetail product,
) {
  if (profile == null) return 'Using Global settings';
  if (profile.hasOverride)
    return 'Customized for ${product.variants.firstWhereOrNull((v) => v.id == variantId)?.name ?? 'this Variant'}';
  return profile.inheritedFrom == 'product'
      ? 'Using Product settings'
      : profile.inheritedFrom == 'variant'
      ? 'Using Variant settings'
      : 'Using Global settings';
}

String _effectSummary(
  ModifierRecipeProfile? profile,
  List<RecipeMaterial> materials,
) {
  final components = profile?.components ?? const <RecipeComponent>[];
  final removes = components
      .where((c) => c.operation == 'remove')
      .toList(growable: false);
  final adds = components
      .where((c) => c.operation != 'remove')
      .toList(growable: false);
  if (removes.isEmpty && adds.isEmpty) return 'No material change';
  if (removes.length == 1 &&
      adds.length == 1 &&
      removes.single.materialId != adds.single.materialId)
    return 'Replaces ${_materialName(materials, removes.single)} with ${_materialName(materials, adds.single)}';
  final parts = <String>[];
  if (removes.isNotEmpty)
    parts.add(
      'Removes ${removes.map((c) => _materialName(materials, c)).join(', ')}',
    );
  if (adds.isNotEmpty)
    parts.add(
      'Adds ${adds.map((c) => '${_materialName(materials, c)} (+${c.quantity} ${c.unitCode})').join(', ')}',
    );
  return parts.join(' · ');
}

class _EmptyRecipeWorkspace extends StatelessWidget {
  const _EmptyRecipeWorkspace();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(AppLocalizations.of(context).commonNoData),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}

class _StandaloneRecipeEditor extends StatefulWidget {
  const _StandaloneRecipeEditor({
    super.key,
    required this.state,
    required this.variantId,
    required this.readOnly,
    this.onComplete,
  });
  final VariantRecipeState state;
  final int variantId;
  final bool readOnly;
  final VoidCallback? onComplete;
  @override
  State<_StandaloneRecipeEditor> createState() =>
      _StandaloneRecipeEditorState();
}

class _StandaloneRecipeEditorState extends State<_StandaloneRecipeEditor> {
  late List<RecipeComponent> _draft;

  @override
  void initState() {
    super.initState();
    _draft = List<RecipeComponent>.from(widget.state.draft);
  }

  @override
  void didUpdateWidget(covariant _StandaloneRecipeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.draft != widget.state.draft && !widget.state.saving) {
      _draft = List<RecipeComponent>.from(widget.state.draft);
    }
  }

  void _update(int index, RecipeComponent component) {
    setState(() => _draft[index] = component);
    context.read<VariantRecipeCubit>().updateDraft(_draft);
  }

  bool get _valid =>
      _draft.every(
        (component) =>
            RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(component.quantity) &&
            !RegExp(r'^0+(\.0+)?$').hasMatch(component.quantity),
      ) &&
      _draft.map((c) => c.materialId).toSet().length == _draft.length;

  bool get _hasDuplicate =>
      _draft.map((component) => component.materialId).toSet().length !=
      _draft.length;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.onComplete != null) ...<Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: widget.state.saving ? null : widget.onComplete,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      AppLocalizations.of(context).recipeBackToWorkspace,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _SectionHeading(
                title: AppLocalizations.of(context).baseRecipe,
                subtitle: AppLocalizations.of(context).recipeConsumptionHelp,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_draft.isEmpty)
                Text(AppLocalizations.of(context).recipeNoComponentsHelp),
              ..._draft.asMap().entries.map(
                (entry) => _EditableRecipeRow(
                  index: entry.key,
                  component: entry.value,
                  materials: widget.state.materials,
                  unavailableMaterialIds: _draft
                      .asMap()
                      .entries
                      .where((other) => other.key != entry.key)
                      .map((other) => other.value.materialId)
                      .toSet(),
                  readOnly: widget.readOnly,
                  onChanged: (value) => _update(entry.key, value),
                  onRemove: () {
                    setState(() => _draft.removeAt(entry.key));
                    context.read<VariantRecipeCubit>().updateDraft(_draft);
                  },
                ),
              ),
              if (!_valid && !widget.readOnly)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _hasDuplicate
                        ? AppLocalizations.of(context).recipeDuplicateMaterial
                        : AppLocalizations.of(context).recipeQuantityInvalid,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    key: const Key('add-material'),
                    onPressed: widget.readOnly ? null : _addMaterial,
                    icon: const Icon(Icons.add),
                    label: Text(AppLocalizations.of(context).addMaterial),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: widget.readOnly || widget.state.saving || !_valid
                        ? null
                        : _save,
                    icon: widget.state.saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(AppLocalizations.of(context).recipeSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _addMaterial() async {
    final cubit = context.read<VariantRecipeCubit>();
    final material = await showDialog<RecipeMaterial>(
      context: context,
      builder: (context) => RecipeMaterialSearchDialog(
        excludedIds: _draft.map((component) => component.materialId).toSet(),
        search: cubit.searchMaterials,
      ),
    );
    if (!mounted || material == null || material.unitCode == null) return;
    setState(
      () => _draft.add(
        RecipeComponent(
          materialId: material.id,
          quantity: '1',
          unitCode: material.unitCode!,
          sortOrder: _draft.length,
        ),
      ),
    );
    context.read<VariantRecipeCubit>().updateDraft(_draft);
  }

  Future<void> _save() async {
    final saved = await context.read<VariantRecipeCubit>().save(
      widget.variantId,
    );
    if (saved && mounted && Scaffold.maybeOf(context) != null)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).recipeSaved)),
      );
    if (saved && mounted) widget.onComplete?.call();
  }
}

class RecipeMaterialSearchDialog extends StatefulWidget {
  const RecipeMaterialSearchDialog({
    super.key,
    required this.excludedIds,
    required this.search,
  });
  final Set<int> excludedIds;
  final Future<List<RecipeMaterial>> Function(String query) search;

  @override
  State<RecipeMaterialSearchDialog> createState() =>
      _RecipeMaterialSearchDialogState();
}

class _RecipeMaterialSearchDialogState
    extends State<RecipeMaterialSearchDialog> {
  Timer? _debounce;
  int _request = 0;
  bool _loading = false;
  Object? _error;
  String _query = '';
  List<RecipeMaterial> _materials = const <RecipeMaterial>[];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _materials = const <RecipeMaterial>[];
        _error = null;
        _loading = false;
      });
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final materials = await widget.search(trimmed);
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _materials = materials
            .where(
              (material) =>
                  material.configurationAvailable &&
                  !widget.excludedIds.contains(material.id),
            )
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.recipeMaterialSearch),
      content: SizedBox(
        width: 480,
        height: 360,
        child: Column(
          children: <Widget>[
            TextField(
              autofocus: true,
              onChanged: _onQuery,
              decoration: InputDecoration(
                labelText: l10n.recipeMaterialSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: FilledButton(
                        onPressed: () => _search(_query),
                        child: Text(l10n.modifierRetry),
                      ),
                    )
                  : _materials.isEmpty
                  ? Center(child: Text(l10n.recipeNoMaterialResults))
                  : ListView.builder(
                      itemCount: _materials.length,
                      itemBuilder: (context, index) {
                        final material = _materials[index];
                        return ListTile(
                          title: Text(material.name),
                          subtitle: Text(
                            material.sku ?? material.unitCode ?? '',
                          ),
                          onTap: () => Navigator.of(context).pop(material),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.recipeCancel),
        ),
      ],
    );
  }
}

class _EditableRecipeRow extends StatelessWidget {
  const _EditableRecipeRow({
    required this.index,
    required this.component,
    required this.materials,
    required this.unavailableMaterialIds,
    required this.readOnly,
    required this.onChanged,
    required this.onRemove,
  });
  final int index;
  final RecipeComponent component;
  final List<RecipeMaterial> materials;
  final Set<int> unavailableMaterialIds;
  final bool readOnly;
  final ValueChanged<RecipeComponent> onChanged;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final material = materials.firstWhereOrNull(
      (m) => m.id == component.materialId,
    );
    final units = compatibleRecipeUnits(material?.unitCode);
    return Container(
      key: Key('recipe-row-$index'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.contentBackground,
        borderRadius: AppRadius.control,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<int>(
              value: component.materialId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).material,
                isDense: true,
              ),
              items: materials
                  .map(
                    (m) => DropdownMenuItem<int>(
                      value: m.id,
                      enabled: m.configurationAvailable && !_duplicate(m.id),
                      child: Text(m.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: readOnly
                  ? null
                  : (id) {
                      if (id == null) return;
                      final selected = materials.firstWhereOrNull(
                        (m) => m.id == id,
                      );
                      if (selected?.unitCode != null) {
                        onChanged(
                          RecipeComponent(
                            materialId: id,
                            quantity: component.quantity,
                            unitCode: selected!.unitCode!,
                            sortOrder: index,
                          ),
                        );
                      }
                    },
            ),
          ),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: Key('recipe-quantity-$index'),
              initialValue: component.quantity,
              enabled: !readOnly,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).quantity,
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) => onChanged(
                RecipeComponent(
                  materialId: component.materialId,
                  quantity: value.trim(),
                  unitCode: component.unitCode,
                  sortOrder: index,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: DropdownButtonFormField<String>(
                value: units.contains(component.unitCode)
                    ? component.unitCode
                    : null,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).unit,
                  isDense: true,
                ),
                items: units
                    .map(
                      (unit) => DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      ),
                    )
                    .toList(growable: false),
                onChanged: readOnly
                    ? null
                    : (unit) {
                        if (unit != null)
                          onChanged(
                            RecipeComponent(
                              materialId: component.materialId,
                              quantity: component.quantity,
                              unitCode: unit,
                              sortOrder: index,
                            ),
                          );
                      },
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).removeMaterial,
            onPressed: readOnly ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  bool _duplicate(int materialId) =>
      unavailableMaterialIds.contains(materialId);
}
