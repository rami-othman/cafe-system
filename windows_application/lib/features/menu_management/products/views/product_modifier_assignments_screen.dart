// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../controllers/product_catalog_cubit.dart';
import '../controllers/product_modifier_assignments_cubit.dart';
import '../controllers/product_modifier_assignments_state.dart';
import '../models/product_modifier_assignment.dart';

class ProductModifierAssignmentsScreen extends StatefulWidget {
  const ProductModifierAssignmentsScreen({super.key, required this.productId});
  final int productId;
  @override
  State<ProductModifierAssignmentsScreen> createState() =>
      _ProductModifierAssignmentsScreenState();
}

class _ProductModifierAssignmentsScreenState
    extends State<ProductModifierAssignmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductModifierAssignmentsCubit>().load(
        widget.productId,
      ),
    );
  }

  Future<bool> _canLeave() async {
    if (!context.read<ProductModifierAssignmentsCubit>().state.isDirty)
      return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'You have unsaved changes. Leave without saving?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _back() async {
    if (await _canLeave() && mounted)
      context.go('/menu-management/products/${widget.productId}');
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
    onWillPop: _canLeave,
    child: BlocConsumer<ProductModifierAssignmentsCubit, ProductModifierAssignmentsState>(
      listener: (context, state) {
        if (state.successMessage != null)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.successMessage!)));
        if (state.successMessage != null)
          context.read<ProductCatalogCubit>().refresh();
      },
      builder: (context, state) {
        if (state.status == ProductModifierAssignmentsStatus.loading &&
            state.product == null)
          return const DesktopPageLayout(
            child: Center(child: CircularProgressIndicator()),
          );
        if (state.product == null)
          return DesktopPageLayout(
            child: Center(
              child: Text(state.errorMessage ?? 'Product not found.'),
            ),
          );
        final cubit = context.read<ProductModifierAssignmentsCubit>();
        if (state.product?.isArchived == true) {
          return DesktopPageLayout(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'This product is archived and modifier assignments are read-only.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => context.go(
                      '/menu-management/products/${state.product!.id}',
                    ),
                    child: const Text('View Product Detail'),
                  ),
                ],
              ),
            ),
          );
        }
        return DesktopPageLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Product'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: state.isSaving ? null : cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  FilledButton.icon(
                    key: const Key('save-product-modifiers'),
                    onPressed: state.isDirty && !state.isSaving
                        ? cubit.save
                        : null,
                    icon: state.isSaving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
              Text(
                'Product Modifiers',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                state.product!.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (state.errorMessage != null)
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _Panel(
                        title: 'Assigned Groups (${state.assignments.length})',
                        child: state.assignments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No modifier groups are assigned to this product.',
                                ),
                              )
                            : ListView.builder(
                                itemCount: state.assignments.length,
                                itemBuilder: (context, index) => _AssignmentRow(
                                  assignment: state.assignments[index],
                                  index: index,
                                  total: state.assignments.length,
                                  error: state.fieldErrors['groups.$index'],
                                  onMove: (direction) => cubit.move(
                                    state.assignments[index].modifierGroupId,
                                    direction,
                                  ),
                                  onEdit: () async {
                                    final result =
                                        await showDialog<
                                          ProductModifierAssignment
                                        >(
                                          context: context,
                                          builder: (_) => _Editor(
                                            assignment:
                                                state.assignments[index],
                                          ),
                                        );
                                    if (result != null && mounted)
                                      cubit.update(result);
                                  },
                                  onRemove: () async {
                                    final remove = await _removeDialog(context);
                                    if (remove == true && mounted)
                                      cubit.remove(
                                        state
                                            .assignments[index]
                                            .modifierGroupId,
                                      );
                                  },
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _Panel(
                        title: 'Available Groups',
                        child: state.assignableGroups.isEmpty
                            ? const Center(
                                child: Text(
                                  'All available modifier groups are already assigned.',
                                ),
                              )
                            : ListView.builder(
                                itemCount: state.assignableGroups.length,
                                itemBuilder: (context, index) {
                                  final group = state.assignableGroups[index];
                                  return ListTile(
                                    title: Text(group.localizedName),
                                    subtitle: Text(
                                      '${group.groupType} / ${group.selectionType} / ${group.activeOptionCount ?? group.optionCount} active options',
                                    ),
                                    trailing: FilledButton(
                                      onPressed: state.isSaving
                                          ? null
                                          : () => cubit.add(group),
                                      child: const Text('Add'),
                                    ),
                                  );
                                },
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
    ),
  );
}

Future<bool?> _removeDialog(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Remove modifier group?'),
    content: const Text(
      'Remove this Modifier Group from the Product? The Group and its Options will remain available in the Modifier Library.',
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Remove'),
      ),
    ],
  ),
);

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: AppSpacing.allMd,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    ),
  );
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.index,
    required this.total,
    required this.error,
    required this.onMove,
    required this.onEdit,
    required this.onRemove,
  });
  final ProductModifierAssignment assignment;
  final int index;
  final int total;
  final String? error;
  final ValueChanged<int> onMove;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(assignment.localizedName),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Effective Setting: ${assignment.effectiveIsRequired ? 'Required' : 'Optional'} / min ${assignment.effectiveMinSelections} / max ${assignment.effectiveMaxSelections} / quantity ${assignment.effectiveAllowQuantity ? 'allowed' : 'not allowed'}',
        ),
        Text(
          '${assignment.activeOptionCount} active options / ${assignment.selectionType}',
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    trailing: Wrap(
      children: <Widget>[
        IconButton(
          tooltip: 'Move up',
          onPressed: index == 0 ? null : () => onMove(-1),
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: 'Move down',
          onPressed: index == total - 1 ? null : () => onMove(1),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        IconButton(
          tooltip: 'Edit configuration',
          onPressed: onEdit,
          icon: const Icon(Icons.tune),
        ),
        IconButton(
          tooltip: 'Remove',
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({required this.assignment});
  final ProductModifierAssignment assignment;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late bool requiredOverride;
  late bool requiredValue;
  late bool minOverride;
  late bool maxOverride;
  late bool quantityOverride;
  late bool quantityValue;
  late TextEditingController min;
  late TextEditingController max;
  String? error;
  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    requiredOverride = a.isRequiredOverride != null;
    requiredValue = a.isRequiredOverride ?? a.libraryIsRequired;
    minOverride = a.minSelectionsOverride != null;
    maxOverride = a.maxSelectionsOverride != null;
    quantityOverride = a.allowQuantityOverride != null;
    quantityValue = a.allowQuantityOverride ?? a.libraryAllowQuantity;
    min = TextEditingController(
      text: '${a.minSelectionsOverride ?? a.libraryMinSelections}',
    );
    max = TextEditingController(
      text: '${a.maxSelectionsOverride ?? a.libraryMaxSelections}',
    );
  }

  @override
  void dispose() {
    min.dispose();
    max.dispose();
    super.dispose();
  }

  void save() {
    final parsedMin = int.tryParse(min.text);
    final parsedMax = int.tryParse(max.text);
    if ((minOverride && parsedMin == null) ||
        (maxOverride && parsedMax == null) ||
        (parsedMin != null && parsedMin < 0) ||
        (parsedMax != null && parsedMax < 0)) {
      setState(() => error = 'Use non-negative whole numbers.');
      return;
    }
    final next = widget.assignment.copyWith(
      isRequiredOverride: requiredValue,
      minSelectionsOverride: parsedMin,
      maxSelectionsOverride: parsedMax,
      allowQuantityOverride: quantityValue,
      clearRequired: !requiredOverride,
      clearMinimum: !minOverride,
      clearMaximum: !maxOverride,
      clearAllowQuantity: !quantityOverride,
    );
    if (next.effectiveMaxSelections < next.effectiveMinSelections ||
        (next.selectionType == 'single' && next.effectiveMaxSelections > 1) ||
        (next.effectiveIsRequired && next.effectiveMinSelections < 1)) {
      setState(
        () => error = 'The effective selection constraints are invalid.',
      );
      return;
    }
    Navigator.pop(context, next);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return AlertDialog(
      title: Text('Configure ${a.localizedName}'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _boolSetting(
              'Required',
              requiredOverride,
              requiredValue,
              a.libraryIsRequired,
              (v) => setState(() => requiredOverride = v),
              (v) => setState(() => requiredValue = v),
            ),
            _numberSetting(
              'Minimum selections',
              minOverride,
              min,
              a.libraryMinSelections,
              (v) => setState(() => minOverride = v),
            ),
            _numberSetting(
              'Maximum selections',
              maxOverride,
              max,
              a.libraryMaxSelections,
              (v) => setState(() => maxOverride = v),
            ),
            _boolSetting(
              'Allow quantity',
              quantityOverride,
              quantityValue,
              a.libraryAllowQuantity,
              (v) => setState(() => quantityOverride = v),
              (v) => setState(() => quantityValue = v),
            ),
            Text(
              'Effective Setting: ${requiredOverride ? (requiredValue ? 'Required' : 'Optional') : (a.libraryIsRequired ? 'Required' : 'Optional')}',
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: save, child: const Text('Apply')),
      ],
    );
  }

  Widget _boolSetting(
    String label,
    bool overridden,
    bool value,
    bool defaultValue,
    ValueChanged<bool> onOverride,
    ValueChanged<bool> onValue,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      CheckboxListTile(
        value: overridden,
        contentPadding: EdgeInsets.zero,
        onChanged: (v) => onOverride(v ?? false),
        title: Text('$label override'),
        subtitle: Text('Library Default: ${defaultValue ? 'Yes' : 'No'}'),
      ),
      if (overridden) Switch(value: value, onChanged: onValue),
    ],
  );
  Widget _numberSetting(
    String label,
    bool overridden,
    TextEditingController controller,
    int defaultValue,
    ValueChanged<bool> onOverride,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      CheckboxListTile(
        value: overridden,
        contentPadding: EdgeInsets.zero,
        onChanged: (v) => onOverride(v ?? false),
        title: Text('$label override'),
        subtitle: Text('Library Default: $defaultValue'),
      ),
      if (overridden)
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
    ],
  );
}
