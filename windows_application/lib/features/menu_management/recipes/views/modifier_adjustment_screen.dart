// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/recipe_cubits.dart';
import '../models/recipe_models.dart';

class ModifierAdjustmentScreen extends StatefulWidget {
  const ModifierAdjustmentScreen({
    super.key,
    required this.optionId,
    this.productId,
    this.variantId,
    this.optionName,
    this.contextName,
  });
  final int optionId;
  final int? productId;
  final int? variantId;
  final String? optionName;
  final String? contextName;
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
  );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ModifierAdjustmentCubit, ModifierAdjustmentState>(
        listenWhen: (a, b) => a.error != b.error && b.error != null,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!))),
        builder: (context, state) {
          if (state.loading && state.profile == null)
            return const Center(child: CircularProgressIndicator());
          if (state.profile == null)
            return Center(
              child: FilledButton(
                onPressed: _load,
                child: Text(AppLocalizations.of(context).modifierRetry),
              ),
            );
          return _EffectEditor(
            state: state,
            optionId: widget.optionId,
            productId: widget.productId,
            variantId: widget.variantId,
            optionName: widget.optionName ?? 'Option ${widget.optionId}',
            contextName:
                widget.contextName ??
                (widget.variantId != null ? 'Variant' : 'Product'),
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
    required this.optionName,
    required this.contextName,
  });
  final ModifierAdjustmentState state;
  final int optionId;
  final int? productId;
  final int? variantId;
  final String optionName;
  final String contextName;
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
  List<RecipeComponent> get removes =>
      _draft.where((c) => c.operation == 'remove').toList(growable: false);
  List<RecipeComponent> get adds =>
      _draft.where((c) => c.operation != 'remove').toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final bool busy = widget.state.saving || widget.state.deleting;
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Material(
          color: AppColors.surface,
          child: SizedBox(
            height: double.infinity,
            child: Column(
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
                        'When this Option is selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Define how this Option changes the materials consumed by the Recipe.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (noEffect) _noEffectState(context),
                      if (!noEffect) ...<Widget>[
                        _materialSection(
                          context,
                          title: 'Removes',
                          operation: 'remove',
                          components: removes,
                          busy: busy,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _materialSection(
                          context,
                          title: 'Adds',
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
          ),
        ),
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
                '${widget.contextName}  ›  Material Effect',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.optionName} | Material Effect',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _behavior(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text('Current Behavior', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(
            child: _BehaviorCard(
              selected: !_customizing && !profile.hasOverride,
              title: 'Use inherited settings',
              subtitle: profile.inheritedFrom == 'product'
                  ? 'From this Product'
                  : 'From Global settings',
              onTap: canCustomize
                  ? () => setState(() => _customizing = false)
                  : null,
            ),
          ),
          if (canCustomize) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _BehaviorCard(
                selected: _customizing || profile.hasOverride,
                title: 'Customize for ${widget.contextName}',
                subtitle: 'Set a material effect for this context',
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
          'No material effect for this Product/Variant',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'This Product intentionally ignores the inherited material settings for this Option.',
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: widget.productId == null ? null : _restoreInheritance,
          icon: const Icon(Icons.undo, size: 17),
          label: const Text('Use inherited settings again'),
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
          'Add Material to ${operation == 'remove' ? 'Remove' : 'Add'}',
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
              decoration: const InputDecoration(
                labelText: 'Material',
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
              decoration: const InputDecoration(
                labelText: 'Quantity',
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
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(component.unitCode),
          ),
          IconButton(
            tooltip: 'Remove material',
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
          onPressed: busy ? null : () => context.pop(),
          child: const Text('Cancel'),
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
              : const Text('Save Changes'),
        ),
      ],
    ),
  );

  void _replace(int index, RecipeComponent value) =>
      setState(() => _draft[index] = value);

  void _add(String operation) {
    final material = widget.state.materials.firstWhereOrNull(
      (m) =>
          m.configurationAvailable &&
          m.unitCode != null &&
          !_draft.any((c) => c.materialId == m.id && c.operation == operation),
    );
    if (material == null) return;
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

  void _customizeAndAdd(String operation) {
    if (!_customizing && !profile.hasOverride) {
      setState(() => _customizing = true);
    }
    _add(operation);
  }

  Future<void> _save() async {
    context.read<ModifierAdjustmentCubit>().updateDraft(_draft);
    final saved = await context.read<ModifierAdjustmentCubit>().save(
      widget.optionId,
      productId: widget.productId,
      variantId: widget.variantId,
    );
    if (saved && mounted) context.pop();
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
