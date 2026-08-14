// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../l10n/app_localizations.dart';

import '../controllers/recipe_cubits.dart';
import '../models/recipe_models.dart';

class ModifierAdjustmentScreen extends StatefulWidget {
  const ModifierAdjustmentScreen({
    super.key,
    required this.optionId,
    this.productId,
    this.variantId,
  });
  final int optionId;
  final int? productId;
  final int? variantId;
  @override
  State<ModifierAdjustmentScreen> createState() =>
      _ModifierAdjustmentScreenState();
}

class _ModifierAdjustmentScreenState extends State<ModifierAdjustmentScreen> {
  String get _scope => widget.variantId != null
      ? 'Variant'
      : widget.productId != null
      ? 'Product'
      : 'Global';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${_scopeLabel(context)} ${AppLocalizations.of(context).materialAdjustments}',
      ),
    ),
    body: BlocConsumer<ModifierAdjustmentCubit, ModifierAdjustmentState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (context, state) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!))),
      builder: (context, state) {
        if (state.loading && state.profile == null)
          return const Center(child: CircularProgressIndicator());
        if (state.profile == null)
          return Center(
            child: FilledButton(onPressed: _load, child: const Text('Retry')),
          );
        return _AdjustmentEditor(
          scope: _scope,
          optionId: widget.optionId,
          productId: widget.productId,
          variantId: widget.variantId,
          state: state,
        );
      },
    ),
  );

  String _scopeLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    return widget.variantId != null
        ? l.variantOverride
        : widget.productId != null
        ? l.productOverride
        : l.global;
  }
}

class _AdjustmentEditor extends StatefulWidget {
  const _AdjustmentEditor({
    required this.scope,
    required this.optionId,
    required this.productId,
    required this.variantId,
    required this.state,
  });
  final String scope;
  final int optionId;
  final int? productId;
  final int? variantId;
  final ModifierAdjustmentState state;
  @override
  State<_AdjustmentEditor> createState() => _AdjustmentEditorState();
}

class _AdjustmentEditorState extends State<_AdjustmentEditor> {
  late List<RecipeComponent> _draft;
  @override
  void initState() {
    super.initState();
    _draft = List<RecipeComponent>.from(widget.state.draft);
  }

  @override
  void didUpdateWidget(covariant _AdjustmentEditor old) {
    super.didUpdateWidget(old);
    if (old.state.draft != widget.state.draft && !widget.state.saving)
      _draft = List<RecipeComponent>.from(widget.state.draft);
  }

  void _set(List<RecipeComponent> value) {
    setState(() => _draft = value);
    context.read<ModifierAdjustmentCubit>().updateDraft(_draft);
  }

  bool get _valid =>
      _draft.every(
        (component) =>
            RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(component.quantity) &&
            component.quantity != '0',
      ) &&
      _draft
              .map(
                (component) => '${component.materialId}:${component.operation}',
              )
              .toSet()
              .length ==
          _draft.length;

  RecipeMaterial? _material(int id) =>
      widget.state.materials.firstWhereOrNull((material) => material.id == id);

  void _update(int index, RecipeComponent component) {
    final next = List<RecipeComponent>.from(_draft);
    next[index] = component;
    _set(next);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile!;
    final canOverride = widget.scope != 'Global';
    final materials = widget.state.materials;
    final editable = !widget.state.saving && !widget.state.deleting;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Chip(
            label: Text(
              '${AppLocalizations.of(context).effectiveFrom}: ${profile.effectiveSource}',
            ),
          ),
          if (canOverride && !profile.hasOverride)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(AppLocalizations.of(context).recipeInheritedDraft),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _draft.isEmpty
                ? Center(
                    child: Text(
                      canOverride && profile.hasOverride
                          ? AppLocalizations.of(context).recipeEmptyOverride
                          : 'No material adjustments are configured.',
                    ),
                  )
                : ListView.builder(
                    itemCount: _draft.length,
                    itemBuilder: (context, index) {
                      final c = _draft[index];
                      final material = _material(c.materialId);
                      final units = compatibleRecipeUnits(material?.unitCode);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 140,
                                child: DropdownButtonFormField<String>(
                                  value: c.operation ?? 'add',
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Operation',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: const <DropdownMenuItem<String>>[
                                    DropdownMenuItem(
                                      value: 'add',
                                      child: Text('ADD'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'remove',
                                      child: Text('REMOVE'),
                                    ),
                                  ],
                                  onChanged: !editable
                                      ? null
                                      : (operation) {
                                          if (operation == null ||
                                              _draft.any(
                                                (other) =>
                                                    other != c &&
                                                    other.materialId ==
                                                        c.materialId &&
                                                    other.operation ==
                                                        operation,
                                              ))
                                            return;
                                          _update(
                                            index,
                                            RecipeComponent(
                                              materialId: c.materialId,
                                              quantity: c.quantity,
                                              unitCode: c.unitCode,
                                              operation: operation,
                                              sortOrder: index,
                                            ),
                                          );
                                        },
                                ),
                              ),
                              SizedBox(
                                width: 280,
                                child: DropdownButtonFormField<int>(
                                  value: c.materialId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Material',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: materials
                                      .map(
                                        (candidate) => DropdownMenuItem<int>(
                                          value: candidate.id,
                                          enabled:
                                              candidate
                                                  .configurationAvailable &&
                                              !_draft.any(
                                                (other) =>
                                                    other != c &&
                                                    other.materialId ==
                                                        candidate.id &&
                                                    other.operation ==
                                                        c.operation,
                                              ),
                                          child: Text(
                                            candidate.configurationAvailable
                                                ? candidate.name
                                                : '${candidate.name} (${candidate.unavailabilityReason ?? 'unavailable'})',
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: !editable
                                      ? null
                                      : (id) {
                                          final selected = id == null
                                              ? null
                                              : _material(id);
                                          if (selected == null ||
                                              !selected
                                                  .configurationAvailable ||
                                              selected.unitCode == null)
                                            return;
                                          _update(
                                            index,
                                            RecipeComponent(
                                              materialId: id!,
                                              quantity: c.quantity,
                                              unitCode: selected.unitCode!,
                                              operation: c.operation,
                                              sortOrder: index,
                                            ),
                                          );
                                        },
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  key: Key('adjustment-quantity-$index'),
                                  initialValue: c.quantity,
                                  enabled: editable,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (quantity) => _update(
                                    index,
                                    RecipeComponent(
                                      materialId: c.materialId,
                                      quantity: quantity.trim(),
                                      unitCode: c.unitCode,
                                      operation: c.operation,
                                      sortOrder: index,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: DropdownButtonFormField<String>(
                                    value: units.contains(c.unitCode)
                                        ? c.unitCode
                                        : null,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: units
                                        .map(
                                          (unit) => DropdownMenuItem(
                                            value: unit,
                                            child: Text(unit),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: !editable
                                        ? null
                                        : (unit) {
                                            if (unit != null)
                                              _update(
                                                index,
                                                RecipeComponent(
                                                  materialId: c.materialId,
                                                  quantity: c.quantity,
                                                  unitCode: unit,
                                                  operation: c.operation,
                                                  sortOrder: index,
                                                ),
                                              );
                                          },
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove component',
                                onPressed: !editable
                                    ? null
                                    : () {
                                        final next = List<RecipeComponent>.from(
                                          _draft,
                                        )..removeAt(index);
                                        _set(next);
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_valid)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Use unique material and operation pairs with a positive decimal quantity (up to 6 places).',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: !editable
                    ? null
                    : () {
                        final m = materials.firstWhereOrNull(
                          (x) =>
                              x.configurationAvailable &&
                              x.unitCode != null &&
                              !_draft.any(
                                (c) =>
                                    c.materialId == x.id &&
                                    c.operation == 'add',
                              ),
                        );
                        if (m != null)
                          _set(<RecipeComponent>[
                            ..._draft,
                            RecipeComponent(
                              materialId: m.id,
                              quantity: '1',
                              unitCode: m.unitCode!,
                              operation: 'add',
                              sortOrder: _draft.length,
                            ),
                          ]);
                      },
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).addMaterial),
              ),
              const SizedBox(width: 8),
              if (canOverride && profile.hasOverride)
                TextButton(
                  onPressed: !editable
                      ? null
                      : () async {
                          if (await _confirm(
                                context,
                                AppLocalizations.of(
                                  context,
                                ).recipeRemoveOverrideTitle,
                                AppLocalizations.of(
                                  context,
                                ).recipeRemoveOverrideBody,
                              ) &&
                              mounted)
                            await context
                                .read<ModifierAdjustmentCubit>()
                                .deleteOverride(
                                  widget.optionId,
                                  productId: widget.productId ?? 0,
                                  variantId: widget.variantId,
                                );
                        },
                  child: Text(AppLocalizations.of(context).restoreInheritance),
                ),
              if (canOverride)
                TextButton(
                  onPressed: !editable
                      ? null
                      : () async {
                          if (await _confirm(
                                context,
                                AppLocalizations.of(
                                  context,
                                ).recipeSuppressConfirmationTitle,
                                AppLocalizations.of(
                                  context,
                                ).recipeSuppressConfirmationBody,
                              ) &&
                              mounted)
                            await context
                                .read<ModifierAdjustmentCubit>()
                                .suppressInherited(
                                  widget.optionId,
                                  productId: widget.productId,
                                  variantId: widget.variantId,
                                );
                        },
                  child: Text(
                    AppLocalizations.of(context).suppressInheritedEffects,
                  ),
                ),
              FilledButton(
                onPressed: !editable || !_valid
                    ? null
                    : () => context.read<ModifierAdjustmentCubit>().save(
                        widget.optionId,
                        productId: widget.productId,
                        variantId: widget.variantId,
                      ),
                child: const Text('Save replacement'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

extension _RecipeFirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final v in this) {
      if (test(v)) return v;
    }
    return null;
  }
}
