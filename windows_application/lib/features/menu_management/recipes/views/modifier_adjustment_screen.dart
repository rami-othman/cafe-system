// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/menu_management_route_locations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/recipe_cubits.dart';
import '../models/recipe_models.dart';
import 'variant_recipe_screen.dart' show RecipeMaterialSearchDialog;

Widget _materialEffectPanel(Widget child) => Align(
  alignment: AlignmentDirectional.topEnd,
  child: ConstrainedBox(
    constraints: const BoxConstraints(
      maxWidth: AppSizes.materialEffectPanelWidth,
    ),
    child: Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.black.withValues(alpha: 0.08),
      child: SizedBox(height: double.infinity, child: child),
    ),
  ),
);

class ModifierAdjustmentScreen extends StatefulWidget {
  const ModifierAdjustmentScreen({
    super.key,
    required this.optionId,
    this.productId,
    this.variantId,
    this.groupId,
  });
  final int optionId;
  final int? productId;
  final int? variantId;
  final int? groupId;

  @override
  State<ModifierAdjustmentScreen> createState() =>
      _ModifierAdjustmentScreenState();
}

class _ModifierAdjustmentScreenState extends State<ModifierAdjustmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() => context.read<ModifierAdjustmentCubit>().load(
    widget.optionId,
    productId: widget.productId,
    variantId: widget.variantId,
    groupId: widget.groupId,
  );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ModifierAdjustmentCubit, ModifierAdjustmentState>(
        listenWhen: (a, b) => a.error != b.error && b.error != null,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).commonError)),
            ),
        builder: (context, state) {
          if (state.loading && state.profile == null)
            return _materialEffectPanel(
              const Center(child: CircularProgressIndicator()),
            );
          if (state.profile == null)
            return _materialEffectPanel(
              Center(
                child: FilledButton(
                  onPressed: _load,
                  child: Text(AppLocalizations.of(context).modifierRetry),
                ),
              ),
            );
          return _EffectEditor(
            state: state,
            optionId: widget.optionId,
            productId: widget.productId,
            variantId: widget.variantId,
            groupId: widget.groupId,
            onRetry: _load,
          );
        },
      );
}

class _EffectEditor extends StatefulWidget {
  const _EffectEditor({
    required this.state,
    required this.optionId,
    required this.productId,
    required this.variantId,
    required this.groupId,
    required this.onRetry,
  });
  final ModifierAdjustmentState state;
  final int optionId;
  final int? productId;
  final int? variantId;
  final int? groupId;
  final VoidCallback onRetry;
  @override
  State<_EffectEditor> createState() => _EffectEditorState();
}

class _EffectEditorState extends State<_EffectEditor> {
  late List<RecipeComponent> _draft;
  bool _customizing = false;

  @override
  void initState() {
    super.initState();
    _draft = List<RecipeComponent>.from(widget.state.draft);
    _customizing = widget.state.profile?.hasOverride ?? false;
  }

  @override
  void didUpdateWidget(covariant _EffectEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.draft != widget.state.draft &&
        !widget.state.saving &&
        !widget.state.deleting) {
      _draft = List<RecipeComponent>.from(widget.state.draft);
      _customizing = widget.state.profile?.hasOverride ?? false;
    }
  }

  ModifierRecipeProfile get profile => widget.state.profile!;
  bool get canCustomize => widget.productId != null || widget.variantId != null;
  bool get noEffect => profile.hasOverride && _draft.isEmpty;
  String _localizedContext(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (widget.variantId != null) return l10n.recipeVariant;
    if (widget.productId != null) return l10n.menuBreadcrumbProduct;
    return l10n.modifierOptions;
  }

  List<RecipeComponent> get removes =>
      _draft.where((c) => c.operation == 'remove').toList(growable: false);
  List<RecipeComponent> get adds =>
      _draft.where((c) => c.operation != 'remove').toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final bool busy = widget.state.saving || widget.state.deleting;
    return _materialEffectPanel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                _behavior(context),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppLocalizations.of(context).recipeModifierMaterialEffects,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppLocalizations.of(
                    context,
                  ).recipeModifierMaterialEffectsHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (noEffect) _noEffectState(context),
                if (canCustomize && !noEffect)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: TextButton.icon(
                      onPressed: busy ? null : _setNoMaterialEffect,
                      icon: const Icon(Icons.block_outlined, size: 17),
                      label: Text(
                        AppLocalizations.of(
                          context,
                        ).recipeNoMaterialEffectFor(_localizedContext(context)),
                      ),
                    ),
                  ),
                if (!noEffect) ...<Widget>[
                  _materialSection(
                    context,
                    title: AppLocalizations.of(context).recipeRemoves,
                    operation: 'remove',
                    components: removes,
                    busy: busy,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _materialSection(
                    context,
                    title: AppLocalizations.of(context).recipeAdds,
                    operation: 'add',
                    components: adds,
                    busy: busy,
                  ),
                ],
              ],
            ),
          ),
          _footer(context, busy),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.md,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppLocalizations.of(context).recipeModifierMaterialEffects,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppLocalizations.of(context).recipeModifierMaterialEffects,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              _contextHeader(context),
            ],
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).commonClose,
          onPressed: _returnToParent,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _contextHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    if (widget.state.contextUnavailable) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.commonError,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: widget.onRetry,
            child: Text(l10n.modifierRetry),
          ),
        ],
      );
    }

    final List<String> names = <String>[
      if (widget.productId == null) l10n.global,
      if (widget.state.product != null)
        widget.state.product!.displayName(locale),
      if (widget.state.variant != null)
        widget.state.variant!.displayName(locale),
      if (widget.state.productGroup != null)
        widget.state.productGroup!.displayName(locale),
      if (widget.state.globalGroup != null)
        widget.state.globalGroup!.displayName(locale),
      if (widget.state.productOption != null)
        widget.state.productOption!.displayName(locale),
      if (widget.state.globalOption != null)
        widget.state.globalOption!.displayName(locale),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.variantId != null
              ? l10n.variantOverride
              : widget.productId != null
              ? l10n.productOverride
              : l10n.global,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (int index = 0; index < names.length; index++) ...<Widget>[
              if (index > 0)
                const Text('›', style: TextStyle(color: AppColors.textMuted)),
              Text(names[index], style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ],
    );
  }

  Widget _behavior(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        AppLocalizations.of(context).recipeCurrentBehavior,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(
            child: _BehaviorCard(
              selected: !_customizing && !profile.hasOverride,
              title: AppLocalizations.of(context).recipeUseInherited,
              subtitle: profile.inheritedFrom == 'product'
                  ? AppLocalizations.of(context).recipeInheritedFromProduct
                  : AppLocalizations.of(context).recipeInheritedFromGlobal,
              onTap: !canCustomize
                  ? null
                  : profile.hasOverride
                  ? _restoreInheritance
                  : () => setState(() => _customizing = false),
            ),
          ),
          if (canCustomize) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _BehaviorCard(
                selected: _customizing || profile.hasOverride,
                title: AppLocalizations.of(
                  context,
                ).recipeCustomizeFor(_localizedContext(context)),
                subtitle: AppLocalizations.of(
                  context,
                ).recipeModifierMaterialEffectsHelp,
                onTap: () => setState(() => _customizing = true),
              ),
            ),
          ],
        ],
      ),
    ],
  );

  Widget _noEffectState(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7EA),
      border: Border.all(color: const Color(0xFFE7C99D)),
      borderRadius: AppRadius.control,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppLocalizations.of(
            context,
          ).recipeNoMaterialEffectFor(_localizedContext(context)),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(AppLocalizations.of(context).recipeEmptyOverride),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: widget.productId == null ? null : _restoreInheritance,
          icon: const Icon(Icons.undo, size: 17),
          label: Text(AppLocalizations.of(context).recipeUseInheritedAgain),
        ),
      ],
    ),
  );

  Widget _materialSection(
    BuildContext context, {
    required String title,
    required String operation,
    required List<RecipeComponent> components,
    required bool busy,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          Text(
            '${components.length}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      ...components.map(
        (component) => _materialRow(context, component, operation, busy),
      ),
      OutlinedButton.icon(
        key: Key('add-material-to-$operation'),
        onPressed: busy ? null : () => _customizeAndAdd(operation),
        icon: const Icon(Icons.add, size: 17),
        label: Text(
          operation == 'remove'
              ? AppLocalizations.of(context).recipeAddMaterialToRemove
              : AppLocalizations.of(context).recipeAddMaterialToAdd,
        ),
      ),
    ],
  );

  Widget _materialRow(
    BuildContext context,
    RecipeComponent component,
    String operation,
    bool busy,
  ) {
    final int index = _draft.indexOf(component);
    final RecipeMaterial? material = widget.state.materials.firstWhereOrNull(
      (m) => m.id == component.materialId,
    );
    final List<String> units = compatibleRecipeUnits(material?.unitCode);
    return Container(
      key: Key('effect-row-${operation}-${component.materialId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.contentBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              value: component.materialId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).material,
                isDense: true,
              ),
              items: widget.state.materials
                  .map(
                    (m) =>
                        DropdownMenuItem<int>(value: m.id, child: Text(m.name)),
                  )
                  .toList(growable: false),
              onChanged: busy || (!_customizing && !profile.hasOverride)
                  ? null
                  : (id) {
                      if (id == null) return;
                      final selected = widget.state.materials.firstWhereOrNull(
                        (m) => m.id == id,
                      );
                      if (selected?.unitCode != null)
                        _replace(
                          index,
                          RecipeComponent(
                            materialId: id,
                            quantity: component.quantity,
                            unitCode: selected!.unitCode!,
                            operation: operation,
                            sortOrder: index,
                          ),
                        );
                    },
            ),
          ),
          SizedBox(
            width: 105,
            child: TextFormField(
              key: Key('adjustment-quantity-$operation-$index'),
              initialValue: component.quantity,
              enabled: !busy && (_customizing || profile.hasOverride),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).quantity,
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) => _replace(
                index,
                RecipeComponent(
                  materialId: component.materialId,
                  quantity: value.trim(),
                  unitCode: component.unitCode,
                  operation: operation,
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
                key: Key('adjustment-unit-$operation-$index'),
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
                onChanged: busy || (!_customizing && !profile.hasOverride)
                    ? null
                    : (unit) {
                        if (unit == null) return;
                        _replace(
                          index,
                          RecipeComponent(
                            materialId: component.materialId,
                            quantity: component.quantity,
                            unitCode: unit,
                            operation: operation,
                            sortOrder: index,
                          ),
                        );
                      },
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).removeMaterial,
            onPressed: busy
                ? null
                : () => setState(() => _draft.removeAt(index)),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, bool busy) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(
          onPressed: busy ? null : _returnToParent,
          child: Text(AppLocalizations.of(context).recipeCancel),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: busy || (!_customizing && !profile.hasOverride)
              ? null
              : _save,
          child: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).recipeSaveChanges),
        ),
      ],
    ),
  );

  void _replace(int index, RecipeComponent value) =>
      setState(() => _draft[index] = value);

  Future<void> _add(String operation) async {
    final cubit = context.read<ModifierAdjustmentCubit>();
    final material = await showDialog<RecipeMaterial>(
      context: context,
      builder: (context) => RecipeMaterialSearchDialog(
        excludedIds: _draft
            .where((component) => component.operation == operation)
            .map((component) => component.materialId)
            .toSet(),
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
          operation: operation,
          sortOrder: _draft.length,
        ),
      ),
    );
  }

  Future<void> _customizeAndAdd(String operation) async {
    if (!_customizing && !profile.hasOverride) {
      setState(() => _customizing = true);
    }
    await _add(operation);
  }

  Future<void> _save() async {
    context.read<ModifierAdjustmentCubit>().updateDraft(_draft);
    final saved = await context.read<ModifierAdjustmentCubit>().save(
      widget.optionId,
      productId: widget.productId,
      variantId: widget.variantId,
    );
    if (saved && mounted) _returnToParent(changed: true);
  }

  Future<void> _restoreInheritance() async {
    if (widget.productId == null) return;
    final restored = await context
        .read<ModifierAdjustmentCubit>()
        .deleteOverride(
          widget.optionId,
          productId: widget.productId!,
          variantId: widget.variantId,
        );
    if (restored && mounted) setState(() => _customizing = false);
  }

  Future<void> _setNoMaterialEffect() async {
    if (!canCustomize) return;
    final saved = await context
        .read<ModifierAdjustmentCubit>()
        .suppressInherited(
          widget.optionId,
          productId: widget.productId,
          variantId: widget.variantId,
        );
    if (saved && mounted) setState(() => _customizing = true);
  }

  void _returnToParent({bool changed = false}) {
    if (context.canPop()) {
      context.pop(changed);
      return;
    }
    if (widget.productId != null) {
      context.go(
        MenuManagementRouteLocations.productWorkspace(
          widget.productId!,
          tab: ProductWorkspaceTab.recipe,
          variantId: widget.variantId,
        ),
      );
      return;
    }
    if (widget.groupId != null) {
      context.go('/menu-management/modifiers/${widget.groupId}');
      return;
    }
    context.go('/menu-management/modifiers');
  }
}

class _BehaviorCard extends StatelessWidget {
  const _BehaviorCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.control,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF8F1) : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.tertiary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 19,
            color: selected ? AppColors.tertiary : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
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
