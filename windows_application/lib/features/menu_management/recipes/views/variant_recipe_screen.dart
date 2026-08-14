// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously, unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';

import '../controllers/recipe_cubits.dart';
import '../models/recipe_models.dart';

class VariantRecipeScreen extends StatefulWidget {
  const VariantRecipeScreen({
    super.key,
    required this.variantId,
    this.productId,
    this.readOnly = false,
  });
  final int variantId;
  final int? productId;
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).recipeMaterials),
      actions: <Widget>[
        if (widget.productId != null)
          TextButton.icon(
            onPressed: () => context.go(
              '/menu-management/products/${widget.productId}/variants/${widget.variantId}/recipe-simulation',
            ),
            icon: const Icon(Icons.science_outlined),
            label: Text(AppLocalizations.of(context).recipeSimulation),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => context.read<VariantRecipeCubit>().load(
            widget.variantId,
            productId: widget.productId,
          ),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: BlocConsumer<VariantRecipeCubit, VariantRecipeState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (context, state) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!))),
      builder: (context, state) {
        if (state.loading && state.recipe == null)
          return const Center(child: CircularProgressIndicator());
        if (state.recipe == null)
          return Center(
            child: FilledButton(
              onPressed: () => context.read<VariantRecipeCubit>().load(
                widget.variantId,
                productId: widget.productId,
              ),
              child: const Text('Retry'),
            ),
          );
        return _RecipeEditor(
          state: state,
          readOnly: widget.readOnly,
          variantId: widget.variantId,
          productId: widget.productId,
        );
      },
    ),
  );
}

class _RecipeEditor extends StatefulWidget {
  const _RecipeEditor({
    required this.state,
    required this.readOnly,
    required this.variantId,
    required this.productId,
  });
  final VariantRecipeState state;
  final bool readOnly;
  final int variantId;
  final int? productId;
  @override
  State<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<_RecipeEditor> {
  late List<RecipeComponent> _draft;
  @override
  void initState() {
    super.initState();
    _draft = List<RecipeComponent>.from(widget.state.draft);
  }

  @override
  void didUpdateWidget(covariant _RecipeEditor old) {
    super.didUpdateWidget(old);
    if (old.state.draft != widget.state.draft && !widget.state.saving)
      _draft = List<RecipeComponent>.from(widget.state.draft);
  }

  void _update(int index, RecipeComponent value) {
    setState(() => _draft[index] = value);
    context.read<VariantRecipeCubit>().updateDraft(_draft);
  }

  bool get _valid =>
      _draft.isNotEmpty &&
      _draft.every(
        (c) =>
            RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(c.quantity) &&
            !RegExp(r'^0+(\.0+)?$').hasMatch(c.quantity),
      ) &&
      _draft.map((c) => c.materialId).toSet().length == _draft.length;
  @override
  Widget build(BuildContext context) {
    final materials = widget.state.materials;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppLocalizations.of(context).baseRecipe,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.readOnly
                ? AppLocalizations.of(context).recipeReadOnly
                : AppLocalizations.of(context).recipeConsumptionHelp,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          if (_draft.isEmpty && !widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppLocalizations.of(context).recipeNoComponentsHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (widget.productId != null &&
              widget.state.product != null) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Variant Modifier Overrides',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 8,
              children: widget.state.product!.modifierGroups
                  .expand((group) => group.options)
                  .where((option) => option.isActive)
                  .map(
                    (option) => ActionChip(
                      label: Text(option.name),
                      avatar: const Icon(Icons.tune, size: 16),
                      onPressed: widget.readOnly
                          ? null
                          : () => context.go(
                              '/menu-management/product-variants/${widget.variantId}/modifier-options/${option.id}/recipe-adjustments',
                            ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (materials.any((m) => !m.configurationAvailable))
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                AppLocalizations.of(context).recipeUnavailableMaterial,
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: <DataColumn>[
                  DataColumn(
                    label: Text(AppLocalizations.of(context).material),
                  ),
                  DataColumn(
                    label: Text(AppLocalizations.of(context).quantity),
                  ),
                  DataColumn(label: Text(AppLocalizations.of(context).unit)),
                  DataColumn(label: Text('')),
                ],
                rows: List<DataRow>.generate(_draft.length, (index) {
                  final component = _draft[index];
                  final material = _material(materials, component.materialId);
                  return DataRow(
                    cells: <DataCell>[
                      DataCell(
                        DropdownButton<int>(
                          value: component.materialId,
                          items: materials
                              .map(
                                (m) => DropdownMenuItem<int>(
                                  value: m.id,
                                  enabled:
                                      m.configurationAvailable &&
                                      !_draft
                                          .where((c) => c.materialId == m.id)
                                          .any((c) => c != component),
                                  child: Text(
                                    m.configurationAvailable
                                        ? m.name
                                        : '${m.name} (unit unmapped)',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: widget.readOnly
                              ? null
                              : (id) {
                                  if (id == null) return;
                                  final selected = _material(materials, id)!;
                                  _update(
                                    index,
                                    RecipeComponent(
                                      materialId: id,
                                      quantity: component.quantity,
                                      unitCode: selected.unitCode!,
                                      sortOrder: index,
                                    ),
                                  );
                                },
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            key: Key('recipe-quantity-$index'),
                            initialValue: component.quantity,
                            enabled: !widget.readOnly,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) => _update(
                              index,
                              RecipeComponent(
                                materialId: component.materialId,
                                quantity: value.trim(),
                                unitCode: component.unitCode,
                                sortOrder: index,
                              ),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: DropdownButtonFormField<String>(
                              value:
                                  compatibleRecipeUnits(
                                    material?.unitCode,
                                  ).contains(component.unitCode)
                                  ? component.unitCode
                                  : null,
                              items: compatibleRecipeUnits(material?.unitCode)
                                  .map(
                                    (unit) => DropdownMenuItem<String>(
                                      value: unit,
                                      child: Text(unit),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: widget.readOnly
                                  ? null
                                  : (unit) {
                                      if (unit == null) return;
                                      _update(
                                        index,
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
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'Remove material',
                          onPressed: widget.readOnly
                              ? null
                              : () {
                                  setState(() => _draft.removeAt(index));
                                  context
                                      .read<VariantRecipeCubit>()
                                      .updateDraft(_draft);
                                },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (!_valid && !widget.readOnly)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Use a unique material and a positive decimal quantity (up to 6 places).',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: widget.readOnly
                    ? null
                    : () {
                        final candidate = materials.firstWhereOrNull(
                          (m) =>
                              m.configurationAvailable &&
                              !_draft.any((c) => c.materialId == m.id),
                        );
                        if (candidate != null) {
                          setState(
                            () => _draft.add(
                              RecipeComponent(
                                materialId: candidate.id,
                                quantity: '1',
                                unitCode: candidate.unitCode!,
                                sortOrder: _draft.length,
                              ),
                            ),
                          );
                          context.read<VariantRecipeCubit>().updateDraft(
                            _draft,
                          );
                        }
                      },
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).addMaterial),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.readOnly || widget.state.saving || !_valid
                    ? null
                    : () async {
                        if (await context.read<VariantRecipeCubit>().save(
                              widget.variantId,
                            ) &&
                            mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recipe saved.')),
                          );
                      },
                icon: widget.state.saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save recipe'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

RecipeMaterial? _material(List<RecipeMaterial> materials, int id) =>
    materials.firstWhereOrNull((m) => m.id == id);

extension _FirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}
