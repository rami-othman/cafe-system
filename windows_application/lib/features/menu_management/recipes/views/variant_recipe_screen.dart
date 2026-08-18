// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/catalog_models.dart';
import '../controllers/recipe_cubits.dart';
import '../models/recipe_models.dart';

class VariantRecipeScreen extends StatefulWidget {
  const VariantRecipeScreen({
    super.key,
    required this.variantId,
    this.productId,
    this.editMode = false,
    this.readOnly = false,
  });
  final int variantId;
  final int? productId;
  final bool editMode;
  final bool readOnly;
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
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!))),
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
  });
  final ProductDetail product;
  final bool readOnly;
  @override
  State<RecipeMaterialsWorkspace> createState() =>
      _RecipeMaterialsWorkspaceState();
}

class _RecipeMaterialsWorkspaceState extends State<RecipeMaterialsWorkspace> {
  late int _variantId;

  @override
  void initState() {
    super.initState();
    _variantId =
        widget.product.defaultVariant?.id ??
        (widget.product.variants.isEmpty
            ? 0
            : widget.product.variants.first.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_variantId > 0)
        context.read<VariantRecipeCubit>().load(
          _variantId,
          productId: widget.product.id,
        );
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<VariantRecipeCubit, VariantRecipeState>(
        builder: (context, state) {
          if (_variantId == 0 || widget.product.variants.isEmpty)
            return const _EmptyRecipeWorkspace();
          return _RecipeWorkspaceBody(
            state: state,
            product: widget.product,
            initialVariantId: _variantId,
            readOnly: widget.readOnly || widget.product.isArchived,
            embedded: true,
            onVariantChanged: (id) {
              setState(() => _variantId = id);
              context.read<VariantRecipeCubit>().load(
                id,
                productId: widget.product.id,
              );
            },
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
                    : () => context.go(
                        '/menu-management/products/${product!.id}/variants/$initialVariantId/recipe-simulation',
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
          Text('Variant', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              value: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: product.variants
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
  const _RecipeStatus({required this.configured, required this.count});
  final bool configured;
  final int count;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: configured ? const Color(0xFFE6F3E8) : const Color(0xFFFFF1E5),
        borderRadius: AppRadius.control,
      ),
      child: Text(
        configured
            ? 'Recipe configured · $count materials'
            : 'No recipe configured',
        style: TextStyle(
          color: configured ? AppColors.success : AppColors.warning,
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
        : '/menu-management/product-variants/$variantId/recipe?productId=$productId&edit=1';
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
                    onPressed: () => context.go(editorRoute),
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
            onPressed: () => context.go(
              productId == null
                  ? '/menu-management/product-variants/$variantId/recipe'
                  : '/menu-management/product-variants/$variantId/recipe?productId=$productId&edit=1',
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
          const _SectionHeading(
            title: 'Modifier Material Effects',
            subtitle: 'See how customer choices change the materials consumed.',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final group in product.modifierGroups.where(
            (group) => group.isActive && !group.isArchived,
          )) ...<Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
              child: Text(
                group.name.toUpperCase(),
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
                        optionName: option.name,
                        summary: _effectSummary(profile, materials),
                        source: _effectSource(profile, variantId, product),
                        onEdit: () => context.go(
                          '/menu-management/product-variants/$variantId/modifier-options/${option.id}/recipe-adjustments?productId=${product.id}&optionName=${Uri.encodeQueryComponent(option.name)}&contextName=${Uri.encodeQueryComponent(product.variants.firstWhereOrNull((v) => v.id == variantId)?.name ?? "Variant")}',
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
          label: const Text('Edit'),
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
          Text('Test Recipe', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose customer options and preview the final materials consumed.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.science_outlined, size: 17),
            label: const Text('Test Recipe'),
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
      child: Text('No variants are available for this Product.'),
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
  });
  final VariantRecipeState state;
  final int variantId;
  final bool readOnly;
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
                  readOnly: widget.readOnly,
                  onChanged: (value) => _update(entry.key, value),
                  onRemove: () {
                    setState(() => _draft.removeAt(entry.key));
                    context.read<VariantRecipeCubit>().updateDraft(_draft);
                  },
                ),
              ),
              if (!_valid && !widget.readOnly)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Use a unique material and a positive decimal quantity (up to 6 places).',
                    style: TextStyle(color: AppColors.danger),
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
                    label: const Text('Save recipe'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _addMaterial() {
    final material = widget.state.materials.firstWhereOrNull(
      (m) =>
          m.configurationAvailable && !_draft.any((c) => c.materialId == m.id),
    );
    if (material == null || material.unitCode == null) return;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recipe saved.')));
  }
}

class _EditableRecipeRow extends StatelessWidget {
  const _EditableRecipeRow({
    required this.index,
    required this.component,
    required this.materials,
    required this.readOnly,
    required this.onChanged,
    required this.onRemove,
  });
  final int index;
  final RecipeComponent component;
  final List<RecipeMaterial> materials;
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
              decoration: const InputDecoration(
                labelText: 'Material',
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
              decoration: const InputDecoration(
                labelText: 'Quantity',
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
                decoration: const InputDecoration(
                  labelText: 'Unit',
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
            tooltip: 'Remove material',
            onPressed: readOnly ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  bool _duplicate(int materialId) => materials.isEmpty ? false : false;
}
