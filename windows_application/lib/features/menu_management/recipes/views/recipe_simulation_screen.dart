// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/catalog_models.dart';
import '../controllers/recipe_cubits.dart';
import '../models/recipe_models.dart';

class RecipeSimulationScreen extends StatefulWidget {
  const RecipeSimulationScreen({
    super.key,
    required this.productId,
    required this.variantId,
  });
  final int productId;
  final int variantId;
  @override
  State<RecipeSimulationScreen> createState() => _RecipeSimulationScreenState();
}

class _RecipeSimulationScreenState extends State<RecipeSimulationScreen> {
  final Map<int, int> _quantities = <int, int>{};
  final Set<int> _selected = <int>{};
  late int _variantId;

  @override
  void initState() {
    super.initState();
    _variantId = widget.variantId;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          context.read<RecipeSimulationCubit>().loadContext(widget.productId),
    );
  }

  List<Map<String, dynamic>> get _request => (_selected.toList()..sort())
      .map(
        (id) => <String, dynamic>{
          'optionId': id,
          if ((_quantities[id] ?? 1) != 1) 'quantity': _quantities[id],
        },
      )
      .toList(growable: false);

  bool _canSelect(ModifierGroup group, ModifierOption option) =>
      _selected.contains(option.id) ||
      _groupSelectionCount(group) < group.effectiveMaximum;
  int _groupSelectionCount(ModifierGroup group) => _selected
      .where((id) => group.options.any((option) => option.id == id))
      .length;

  void _toggle(ModifierGroup group, ModifierOption option, bool value) {
    setState(() {
      if (value) {
        if (group.selectionType == 'single')
          _selected.removeWhere(
            (id) => group.options.any((candidate) => candidate.id == id),
          );
        _selected.add(option.id);
        _quantities.putIfAbsent(option.id, () => 1);
      } else {
        _selected.remove(option.id);
        _quantities.remove(option.id);
      }
    });
    context.read<RecipeSimulationCubit>().invalidateResult();
  }

  void _changeVariant(int id) {
    setState(() {
      _variantId = id;
      _selected.clear();
      _quantities.clear();
    });
    context.read<RecipeSimulationCubit>().invalidateResult();
  }

  bool _valid(ProductDetail product) => product.modifierGroups
      .where((group) => group.isActive && !group.isArchived)
      .every((group) {
        final count = _groupSelectionCount(group);
        return count >= group.effectiveMinimum &&
            count <= group.effectiveMaximum &&
            group.options
                .where((option) => _selected.contains(option.id))
                .every(
                  (option) =>
                      option.isActive &&
                      !option.isArchived &&
                      option.isAvailable &&
                      (_quantities[option.id] ?? 1) > 0 &&
                      (group.effectiveAllowQuantity ||
                          (_quantities[option.id] ?? 1) == 1),
                );
      });

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RecipeSimulationCubit, RecipeSimulationState>(
    listenWhen: (a, b) => a.error != b.error && b.error != null,
    listener: (context, state) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.error!))),
    builder: (context, state) {
      if (state.loading && state.product == null)
        return const Center(child: CircularProgressIndicator());
      if (state.product == null)
        return const Center(child: Text('Unable to load recipe choices.'));
      final product = state.product!;
      final valid = _valid(product);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _pageIntro(context, product),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final choices = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _variantPicker(context, product),
                        const SizedBox(height: AppSpacing.md),
                        ...product.modifierGroups
                            .where(
                              (group) => group.isActive && !group.isArchived,
                            )
                            .map((group) => _group(context, group)),
                        if (!valid)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              'Select the required number of options in each group.',
                              style: TextStyle(color: AppColors.warning),
                            ),
                          ),
                      ],
                    );
                    final result = _finalMaterials(context, state);
                    if (constraints.maxWidth < 900)
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          choices,
                          const SizedBox(height: AppSpacing.lg),
                          result,
                        ],
                      );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: choices),
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(width: 370, child: result),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _pageIntro(BuildContext context, ProductDetail product) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Test Recipe', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Choose customer options and preview the final materials consumed.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(product.name, style: Theme.of(context).textTheme.labelLarge),
    ],
  );

  Widget _variantPicker(BuildContext context, ProductDetail product) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Variant', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<int>(
            value: _variantId,
            isExpanded: true,
            items: product.variants
                .map(
                  (variant) => DropdownMenuItem<int>(
                    value: variant.id,
                    child: Text(
                      variant.displayName(Localizations.localeOf(context)),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (id) {
              if (id != null) _changeVariant(id);
            },
          ),
        ],
      ),
    ),
  );

  Widget _group(BuildContext context, ModifierGroup group) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(group.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _ruleSentence(l10n, group),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ...group.options
                .where(
                  (option) =>
                      option.isActive &&
                      !option.isArchived &&
                      option.isAvailable,
                )
                .map((option) => _optionRow(context, group, option)),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(
    BuildContext context,
    ModifierGroup group,
    ModifierOption option,
  ) {
    final checked = _selected.contains(option.id);
    final bool enabled = checked || _canSelect(group, option);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: checked ? const Color(0xFFFFF8F1) : AppColors.surface,
        border: Border.all(
          color: checked ? AppColors.tertiary : AppColors.border,
        ),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        children: <Widget>[
          if (group.selectionType == 'single')
            Radio<int>(
              value: option.id,
              groupValue:
                  _selected.firstWhereOrNull(
                    (id) =>
                        group.options.any((candidate) => candidate.id == id),
                  ) ??
                  -1,
              onChanged: !enabled ? null : (_) => _toggle(group, option, true),
            )
          else
            Checkbox(
              value: checked,
              onChanged: !enabled
                  ? null
                  : (value) => _toggle(group, option, value ?? false),
            ),
          Expanded(child: Text(option.name)),
          if (checked && group.effectiveAllowQuantity)
            _stepper(context, option),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _stepper(BuildContext context, ModifierOption option) {
    final value = _quantities[option.id] ?? 1;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Decrease quantity',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: value <= 1
                ? null
                : () {
                    setState(() => _quantities[option.id] = value - 1);
                    context.read<RecipeSimulationCubit>().invalidateResult();
                  },
            icon: const Icon(Icons.remove, size: 15),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 24,
              child: Text('$value', textAlign: TextAlign.center),
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() => _quantities[option.id] = value + 1);
              context.read<RecipeSimulationCubit>().invalidateResult();
            },
            icon: const Icon(Icons.add, size: 15),
          ),
        ],
      ),
    );
  }

  Widget _finalMaterials(BuildContext context, RecipeSimulationState state) {
    final List<RecipeComponent> components = state.result == null
        ? const <RecipeComponent>[]
        : aggregateRecipeComponents(state.result!.components);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Final Materials',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (state.resolving)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.resultStale) _staleState(context),
            if (!state.resultStale && state.result == null)
              Text(
                'Choose options, then preview the materials consumed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!state.resultStale &&
                state.result != null &&
                components.isEmpty)
              Text(
                'No materials are consumed for these choices.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!state.resultStale && state.result != null)
              ...components.map(
                (component) => _finalMaterialRow(context, component),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: state.resolving || !_valid(state.product!)
                  ? null
                  : () => context.read<RecipeSimulationCubit>().resolve(
                      _variantId,
                      _request,
                    ),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Preview Materials'),
            ),
            const Divider(height: AppSpacing.xl),
            _calculationDisclosure(context, state),
          ],
        ),
      ),
    );
  }

  Widget _staleState(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7EA),
      borderRadius: AppRadius.control,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.refresh, size: 18, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Choices changed',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 3),
              const Text('Preview the materials again to update this result.'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _finalMaterialRow(BuildContext context, RecipeComponent component) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                component.materialName ?? 'Material #${component.materialId}',
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${component.quantity} ${component.unitCode}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      );

  Widget _calculationDisclosure(
    BuildContext context,
    RecipeSimulationState state,
  ) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    title: const Text('How this was calculated'),
    children: <Widget>[
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          'Variant: ${state.result?.variantId == null ? _variantId : state.result!.variantId}',
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(_selectedNames(state.product)),
      ),
    ],
  );

  String _selectedNames(ProductDetail? product) {
    if (product == null || _selected.isEmpty)
      return 'No customer options selected.';
    final names = product.modifierGroups
        .expand((group) => group.options)
        .where((option) => _selected.contains(option.id))
        .map((option) => option.name)
        .toList(growable: false);
    return names.isEmpty
        ? 'No customer options selected.'
        : 'Selected choices: ${names.join(', ')}';
  }

  String _ruleSentence(AppLocalizations l10n, ModifierGroup group) {
    final int min = group.effectiveMinimum;
    final int max = group.effectiveMaximum;
    final String rule = min == max && min > 0
        ? (group.effectiveRequired
              ? l10n.modifierRuleExactly(min)
              : l10n.modifierRuleOptionalExactly(min))
        : group.effectiveRequired
        ? l10n.modifierRuleAtLeastUpTo(min, max)
        : l10n.modifierRuleOptionalUpTo(max);
    return group.effectiveAllowQuantity
        ? '$rule ${l10n.modifierRuleQuantity}'
        : rule;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
