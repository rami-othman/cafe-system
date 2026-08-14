// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../l10n/app_localizations.dart';

import '../../models/catalog_models.dart';
import '../controllers/recipe_cubits.dart';

/// Sends selections to the backend resolver. It intentionally performs no
/// material arithmetic in Flutter.
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
  @override
  void initState() {
    super.initState();
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
      _selected.where((id) => group.options.any((o) => o.id == id)).length <
          group.effectiveMaximum;
  void _toggle(ModifierGroup group, ModifierOption option, bool value) {
    setState(() {
      if (value) {
        if (group.selectionType == 'single')
          _selected.removeWhere((id) => group.options.any((o) => o.id == id));
        _selected.add(option.id);
        _quantities.putIfAbsent(option.id, () => 1);
      } else {
        _selected.remove(option.id);
        _quantities.remove(option.id);
      }
    });
  }

  bool get _valid {
    final product = context.read<RecipeSimulationCubit>().state.product;
    if (product == null) return false;
    return product.modifierGroups.every((group) {
      final count = _selected
          .where((id) => group.options.any((o) => o.id == id))
          .length;
      return count >= group.effectiveMinimum && count <= group.effectiveMaximum;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).recipeSimulation)),
    body: BlocConsumer<RecipeSimulationCubit, RecipeSimulationState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (context, state) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!))),
      builder: (context, state) {
        if (state.loading && state.product == null)
          return const Center(child: CircularProgressIndicator());
        if (state.product == null)
          return Center(
            child: FilledButton(
              onPressed: () => context
                  .read<RecipeSimulationCubit>()
                  .loadContext(widget.productId),
              child: const Text('Retry'),
            ),
          );
        final product = state.product!;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(product.name, style: Theme.of(context).textTheme.titleLarge),
              Text(
                AppLocalizations.of(context).recipeSimulationHelp,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).selectedModifiers,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: ListView(
                  children: product.modifierGroups
                      .map((group) => _group(group))
                      .toList(growable: false),
                ),
              ),
              if (!_valid)
                const Text(
                  'Select the required number of options in each modifier group.',
                  style: TextStyle(color: Colors.deepOrange),
                ),
              if (state.error != null)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                    TextButton(
                      onPressed: state.resolving
                          ? null
                          : () => context.read<RecipeSimulationCubit>().resolve(
                              widget.variantId,
                              _request,
                            ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: state.resolving || !_valid
                      ? null
                      : () => context.read<RecipeSimulationCubit>().resolve(
                          widget.variantId,
                          _request,
                        ),
                  icon: state.resolving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Resolve Recipe'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).recipeSimulationResultHelp,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (state.result == null)
                Text(AppLocalizations.of(context).recipeSimulationStartHelp)
              else if (state.result!.components.isEmpty)
                const Text('No resolved components.')
              else
                _result(state),
            ],
          ),
        );
      },
    ),
  );
  Widget _group(ModifierGroup group) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${group.name} (${group.effectiveMinimum}–${group.effectiveMaximum})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          ...group.options.where((o) => o.isActive && o.isAvailable).map((
            option,
          ) {
            final checked = _selected.contains(option.id);
            return Row(
              children: <Widget>[
                if (group.selectionType == 'single')
                  Radio<int>(
                    value: option.id,
                    groupValue: _selected.firstWhere(
                      (id) =>
                          group.options.any((candidate) => candidate.id == id),
                      orElse: () => -1,
                    ),
                    onChanged: !_canSelect(group, option) && !checked
                        ? null
                        : (_) => _toggle(group, option, true),
                  )
                else
                  Checkbox(
                    value: checked,
                    onChanged: !_canSelect(group, option) && !checked
                        ? null
                        : (value) => _toggle(group, option, value ?? false),
                  ),
                Expanded(child: Text(option.name)),
                if (checked && group.effectiveAllowQuantity)
                  SizedBox(
                    width: 96,
                    child: DropdownButton<int>(
                      value: _quantities[option.id] ?? 1,
                      items: List<DropdownMenuItem<int>>.generate(
                        10,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                        growable: false,
                      ),
                      onChanged: (value) =>
                          setState(() => _quantities[option.id] = value ?? 1),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    ),
  );
  Widget _result(RecipeSimulationState state) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: <DataColumn>[
        DataColumn(label: Text(AppLocalizations.of(context).material)),
        DataColumn(label: Text(AppLocalizations.of(context).quantity)),
        DataColumn(label: Text(AppLocalizations.of(context).unit)),
      ],
      rows: state.result!.components
          .map(
            (c) => DataRow(
              cells: <DataCell>[
                DataCell(
                  Text(
                    c.materialName?.isNotEmpty == true
                        ? c.materialName!
                        : 'Material #${c.materialId}',
                  ),
                ),
                DataCell(
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(c.quantity),
                  ),
                ),
                DataCell(
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(c.unitCode),
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    ),
  );
}
