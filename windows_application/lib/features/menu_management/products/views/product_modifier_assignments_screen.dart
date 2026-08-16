// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../controllers/product_catalog_cubit.dart';
import '../controllers/product_modifier_assignments_cubit.dart';
import '../controllers/product_modifier_assignments_state.dart';
import '../models/product_modifier_assignment.dart';

class ProductModifierAssignmentsScreen extends StatefulWidget {
  const ProductModifierAssignmentsScreen({
    super.key,
    required this.productId,
    this.embedded = false,
  });
  final int productId;
  final bool embedded;
  @override
  State<ProductModifierAssignmentsScreen> createState() =>
      _ProductModifierAssignmentsScreenState();
}

class _ProductModifierAssignmentsScreenState
    extends State<ProductModifierAssignmentsScreen> {
  bool _reorderMode = false;
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
    child:
        BlocConsumer<
          ProductModifierAssignmentsCubit,
          ProductModifierAssignmentsState
        >(
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
            return _ModifierAssignmentsContent(
              state: state,
              reorderMode: _reorderMode,
              onReorderModeChanged: (value) =>
                  setState(() => _reorderMode = value),
              onBack: _back,
              onEdit: (assignment) async {
                final result = await _showCustomizationSheet(
                  context,
                  assignment,
                );
                if (result != null && mounted) cubit.update(result);
              },
              onRemove: (assignment) async {
                if (await _removeDialog(context) == true && mounted) {
                  cubit.remove(assignment.modifierGroupId);
                }
              },
              onAdd: () => _showAddGroupSheet(context, state, cubit),
              embedded: widget.embedded,
            );
            /*
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

*/
          },
        ),
  );
}

class _ModifierAssignmentsContent extends StatelessWidget {
  const _ModifierAssignmentsContent({
    required this.state,
    required this.reorderMode,
    required this.onReorderModeChanged,
    required this.onBack,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
    required this.embedded,
  });
  final ProductModifierAssignmentsState state;
  final bool reorderMode;
  final ValueChanged<bool> onReorderModeChanged;
  final Future<void> Function() onBack;
  final ValueChanged<ProductModifierAssignment> onEdit;
  final ValueChanged<ProductModifierAssignment> onRemove;
  final VoidCallback onAdd;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductModifierAssignmentsCubit>();
    return DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!embedded) ...<Widget>[
                  TextButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(state.product!.name),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Expanded(child: _ModifierIntroduction()),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.icon(
                      key: const Key('add-modifier-group-action'),
                      onPressed: state.isSaving ? null : onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Modifier Group'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: const Key('modifier-reorder-action'),
                      onPressed: state.isSaving
                          ? null
                          : () => onReorderModeChanged(!reorderMode),
                      icon: Icon(reorderMode ? Icons.check : Icons.reorder),
                      label: Text(reorderMode ? 'Done' : 'Reorder'),
                    ),
                    FilledButton.icon(
                      key: const Key('save-product-modifiers'),
                      onPressed: state.isDirty && !state.isSaving
                          ? cubit.save
                          : null,
                      icon: state.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save Changes'),
                    ),
                  ],
                ),
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _AssignmentError(state.errorMessage!),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (state.assignments.isEmpty)
                  const _AssignmentEmpty()
                else
                  ...state.assignments.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _AssignedModifierRow(
                        assignment: entry.value,
                        index: entry.key,
                        total: state.assignments.length,
                        reorderMode: reorderMode,
                        hasMaterialImpact: state
                            .materialImpactConfiguredGroupIds
                            .contains(entry.value.modifierGroupId),
                        error: state.fieldErrors['groups.${entry.key}'],
                        onMove: (direction) =>
                            cubit.move(entry.value.modifierGroupId, direction),
                        onEdit: () => onEdit(entry.value),
                        onRemove: () => onRemove(entry.value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModifierIntroduction extends StatelessWidget {
  const _ModifierIntroduction();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Modifiers', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Choose which Modifier Groups customers can use with this Product.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}

class _AssignedModifierRow extends StatelessWidget {
  const _AssignedModifierRow({
    required this.assignment,
    required this.index,
    required this.total,
    required this.reorderMode,
    required this.hasMaterialImpact,
    required this.error,
    required this.onMove,
    required this.onEdit,
    required this.onRemove,
  });
  final ProductModifierAssignment assignment;
  final int index;
  final int total;
  final bool reorderMode;
  final bool hasMaterialImpact;
  final String? error;
  final ValueChanged<int> onMove;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Container(
    key: Key('assigned-modifier-row-${assignment.modifierGroupId}'),
    padding: AppSpacing.allLg,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (reorderMode) ...<Widget>[
          Column(
            children: <Widget>[
              const Icon(Icons.drag_indicator, semanticLabel: 'Reorder'),
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
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    assignment.displayName(Localizations.localeOf(context)),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  _OptionBadge(assignment.activeOptionCount),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                modifierRuleSummary(assignment),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              if (hasMaterialImpact) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                const _SubtleIndicator(label: 'Material impact configured'),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            assignment.hasCustomSettings
                ? 'Customized for ${_productName(context)}'
                : 'Using library settings',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: assignment.hasCustomSettings
                  ? AppColors.secondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const _SubtleIndicator(label: 'Active'),
        PopupMenuButton<_ModifierAction>(
          key: Key('modifier-overflow-${assignment.modifierGroupId}'),
          tooltip: 'Actions for ${assignment.name}',
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => switch (action) {
            _ModifierAction.view => context.go(
              '/menu-management/modifiers/${assignment.modifierGroupId}',
            ),
            _ModifierAction.customize => onEdit(),
            _ModifierAction.remove => onRemove(),
          },
          itemBuilder: (context) => <PopupMenuEntry<_ModifierAction>>[
            _modifierItem(
              _ModifierAction.view,
              'View Modifier Group',
              Icons.visibility_outlined,
            ),
            _modifierItem(
              _ModifierAction.customize,
              assignment.hasCustomSettings
                  ? 'Customize for Product'
                  : 'Customize for ${_productName(context)}',
              Icons.tune,
            ),
            const PopupMenuDivider(),
            _modifierItem(
              _ModifierAction.remove,
              'Remove from Product',
              Icons.remove_circle_outline,
            ),
          ],
        ),
      ],
    ),
  );
  String _productName(BuildContext context) =>
      context.read<ProductModifierAssignmentsCubit>().state.product!.name;
  PopupMenuItem<_ModifierAction> _modifierItem(
    _ModifierAction action,
    String label,
    IconData icon,
  ) => PopupMenuItem<_ModifierAction>(
    value: action,
    child: Row(
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    ),
  );
}

enum _ModifierAction { view, customize, remove }

class _OptionBadge extends StatelessWidget {
  const _OptionBadge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 2,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(
      '$count OPTIONS',
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _SubtleIndicator extends StatelessWidget {
  const _SubtleIndicator({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.info_outline, size: 14, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.secondary),
        ),
      ],
    ),
  );
}

class _AssignmentEmpty extends StatelessWidget {
  const _AssignmentEmpty();
  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allXxl,
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: const Center(
      child: Text('No Modifier Groups are assigned to this Product.'),
    ),
  );
}

class _AssignmentError extends StatelessWidget {
  const _AssignmentError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: AppColors.discountOrangeBadge,
      borderRadius: AppRadius.control,
    ),
    child: Text(message),
  );
}

Future<void> _showAddGroupSheet(
  BuildContext context,
  ProductModifierAssignmentsState state,
  ProductModifierAssignmentsCubit cubit,
) async => showDialog<void>(
  context: context,
  builder: (context) => _SideSheet(
    child: _AvailableGroupsSheet(
      groups: state.assignableGroups,
      onAdd: (group) {
        cubit.add(group);
        Navigator.pop(context);
      },
    ),
  ),
);

class _AvailableGroupsSheet extends StatefulWidget {
  const _AvailableGroupsSheet({required this.groups, required this.onAdd});
  final List<dynamic> groups;
  final ValueChanged<dynamic> onAdd;
  @override
  State<_AvailableGroupsSheet> createState() => _AvailableGroupsSheetState();
}

class _AvailableGroupsSheetState extends State<_AvailableGroupsSheet> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final groups = widget.groups
        .where(
          (g) => g.localizedName.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Add Modifier Group',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Choose a group to make its customer choices available for this Product.',
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search Modifier Groups',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No available Modifier Groups found.'))
              : ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      title: Text(group.localizedName),
                      subtitle: Text(
                        modifierRuleSummaryValues(
                          selectionType: group.selectionType,
                          required: group.isRequired,
                          min: group.minSelections,
                          max: group.maxSelections,
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: () => widget.onAdd(group),
                        child: const Text('Add'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<ProductModifierAssignment?> _showCustomizationSheet(
  BuildContext context,
  ProductModifierAssignment assignment,
) => showDialog<ProductModifierAssignment>(
  context: context,
  builder: (context) =>
      _SideSheet(child: _CustomizationSheet(assignment: assignment)),
);

class _SideSheet extends StatelessWidget {
  const _SideSheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Dialog(
    alignment: AlignmentDirectional.centerEnd,
    insetPadding: EdgeInsets.zero,
    child: SizedBox(
      width: 520,
      height: double.infinity,
      child: Padding(padding: AppSpacing.allXl, child: child),
    ),
  );
}

class _CustomizationSheet extends StatefulWidget {
  const _CustomizationSheet({required this.assignment});
  final ProductModifierAssignment assignment;
  @override
  State<_CustomizationSheet> createState() => _CustomizationSheetState();
}

class _CustomizationSheetState extends State<_CustomizationSheet> {
  late bool customized;
  late bool required;
  late bool quantity;
  late TextEditingController min;
  late TextEditingController max;
  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    customized = a.hasCustomSettings;
    required = a.effectiveIsRequired;
    quantity = a.effectiveAllowQuantity;
    min = TextEditingController(text: '${a.effectiveMinSelections}');
    max = TextEditingController(text: '${a.effectiveMaxSelections}');
  }

  @override
  void dispose() {
    min.dispose();
    max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final multiple = a.selectionType == 'multiple';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Customize for ${context.read<ProductModifierAssignmentsCubit>().state.product!.name}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Current behavior'),
        Text(
          a.hasCustomSettings
              ? 'Customized for ${context.read<ProductModifierAssignmentsCubit>().state.product!.name}'
              : 'Using library settings',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        RadioListTile<bool>(
          value: false,
          groupValue: customized,
          onChanged: (v) => setState(() => customized = false),
          title: const Text('Use library settings'),
        ),
        RadioListTile<bool>(
          value: true,
          groupValue: customized,
          onChanged: (v) => setState(() => customized = true),
          title: Text(
            'Customize for ${context.read<ProductModifierAssignmentsCubit>().state.product!.name}',
          ),
        ),
        if (customized) ...<Widget>[
          const Divider(),
          Text(
            'How should customers choose?',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          RadioListTile<String>(
            value: 'single',
            groupValue: a.selectionType,
            onChanged: null,
            title: const Text('Choose one'),
          ),
          RadioListTile<String>(
            value: 'multiple',
            groupValue: a.selectionType,
            onChanged: null,
            title: const Text('Choose multiple'),
          ),
          Text(
            multiple
                ? 'This group uses multiple choices from the Modifier Library.'
                : 'This group uses one choice from the Modifier Library.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment(value: false, label: Text('Optional')),
              ButtonSegment(value: true, label: Text('Required')),
            ],
            selected: <bool>{required},
            onSelectionChanged: (v) => setState(() => required = v.first),
          ),
          if (multiple) ...<Widget>[
            TextField(
              controller: min,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minimum choices'),
            ),
            TextField(
              controller: max,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maximum choices'),
            ),
          ],
          SwitchListTile(
            value: quantity,
            onChanged: (v) => setState(() => quantity = v),
            title: const Text('Can the same option be added more than once?'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            modifierRuleSummaryValues(
              selectionType: a.selectionType,
              required: required,
              min: int.tryParse(min.text) ?? 0,
              max: int.tryParse(max.text) ?? 0,
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
        const Spacer(),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (customized)
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  a.copyWith(
                    clearRequired: true,
                    clearMinimum: true,
                    clearMaximum: true,
                    clearAllowQuantity: true,
                  ),
                ),
                child: const Text('Use library settings again'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                customized
                    ? a.copyWith(
                        isRequiredOverride: required,
                        minSelectionsOverride: multiple
                            ? int.tryParse(min.text)
                            : a.libraryMinSelections,
                        maxSelectionsOverride: multiple
                            ? int.tryParse(max.text)
                            : a.libraryMaxSelections,
                        allowQuantityOverride: quantity,
                      )
                    : a.copyWith(
                        clearRequired: true,
                        clearMinimum: true,
                        clearMaximum: true,
                        clearAllowQuantity: true,
                      ),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }
}

String modifierRuleSummary(ProductModifierAssignment assignment) =>
    assignment.managerRuleSummary;
String modifierRuleSummaryValues({
  required String selectionType,
  required bool required,
  required int min,
  required int max,
}) {
  if (selectionType == 'single')
    return required
        ? 'Customer must choose exactly 1 option.'
        : 'Optional — customer may choose 1 option.';
  if (required && min == max)
    return 'Customer must choose exactly $min option${min == 1 ? '' : 's'}.';
  if (required)
    return 'Customer must choose at least $min and up to $max options.';
  return max <= 1
      ? 'Optional — customer may choose 1 option.'
      : 'Optional — customer may add up to $max.';
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
