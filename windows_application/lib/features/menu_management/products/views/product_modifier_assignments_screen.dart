// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../controllers/product_catalog_cubit.dart';
import '../../models/catalog_models.dart';
import '../controllers/product_modifier_assignments_cubit.dart';
import '../controllers/product_modifier_assignments_state.dart';
import '../models/product_modifier_assignment.dart';
import '../../modifiers/widgets/modifier_presentation.dart';

class ProductModifierAssignmentsScreen extends StatefulWidget {
  const ProductModifierAssignmentsScreen({
    super.key,
    required this.productId,
    this.embedded = false,
    this.onSummaryChanged,
  });
  final int productId;
  final bool embedded;
  final ValueChanged<ProductDetail>? onSummaryChanged;
  @override
  State<ProductModifierAssignmentsScreen> createState() =>
      _ProductModifierAssignmentsScreenState();
}

class _ProductModifierAssignmentsScreenState
    extends State<ProductModifierAssignmentsScreen> {
  bool _reorderMode = false;
  late VoidCallback _unregisterUnsavedNavigation;
  bool _registeredUnsavedNavigation = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductModifierAssignmentsCubit>().load(
        widget.productId,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredUnsavedNavigation) return;
    final UnsavedNavigationController? navigation =
        UnsavedNavigationScope.maybeOf(context);
    if (navigation == null) return;
    _registeredUnsavedNavigation = true;
    _unregisterUnsavedNavigation = navigation.register(
      UnsavedNavigationGuard(
        isDirty: () =>
            context.read<ProductModifierAssignmentsCubit>().state.isDirty,
        confirmLeave: _canLeave,
      ),
    );
  }

  @override
  void dispose() {
    if (_registeredUnsavedNavigation) _unregisterUnsavedNavigation();
    super.dispose();
  }

  Future<bool> _canLeave() async {
    if (!context.read<ProductModifierAssignmentsCubit>().state.isDirty)
      return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.menuUiUnsavedChangesTitle),
            content: Text(context.l10n.menuUiUnsavedChangesMessage),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.menuUiStay),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.menuUiLeaveWithoutSaving),
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
            if (state.summaryChanged && state.product != null)
              widget.onSummaryChanged?.call(state.product!);
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
                  child: Text(
                    state.errorMessage ?? context.l10n.productDetailNotFound,
                  ),
                ),
              );
            final cubit = context.read<ProductModifierAssignmentsCubit>();
            if (state.product?.isArchived == true) {
              return DesktopPageLayout(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(context.l10n.modifierAssignmentArchivedReadOnly),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () => context.guardedGo(
                          '/menu-management/products/${state.product!.id}',
                        ),
                        child: Text(context.l10n.modifierAssignmentViewProduct),
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
                    label: Text(context.l10n.modifierAssignmentSaveChanges),
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
                      label: Text(context.l10n.modifierAssignmentAddGroup),
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
                      label: Text(
                        reorderMode
                            ? context.l10n.modifierAssignmentDone
                            : context.l10n.modifierAssignmentReorder,
                      ),
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
                      label: Text(context.l10n.modifierAssignmentSaveChanges),
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
      Text(
        context.l10n.modifierAssignmentTitle,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        context.l10n.modifierAssignmentHelp,
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
              Icon(
                Icons.drag_indicator,
                semanticLabel: context.l10n.variantReorderSemantic,
              ),
              IconButton(
                tooltip: context.l10n.modifierAssignmentMoveUp,
                onPressed: index == 0 ? null : () => onMove(-1),
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: context.l10n.modifierAssignmentMoveDown,
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
                modifierRuleSummaryForAssignment(context, assignment),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              if (hasMaterialImpact) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                _SubtleIndicator(
                  label: context.l10n.modifierAssignmentMaterialImpact,
                ),
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
                ? context.l10n.modifierAssignmentCustomizedFor(
                    _productName(context),
                  )
                : context.l10n.modifierAssignmentUsingLibrarySettings,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: assignment.hasCustomSettings
                  ? AppColors.secondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        _SubtleIndicator(label: context.l10n.variantActive),
        PopupMenuButton<_ModifierAction>(
          key: Key('modifier-overflow-${assignment.modifierGroupId}'),
          tooltip: context.l10n.modifierAssignmentActionsFor(assignment.name),
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => switch (action) {
            _ModifierAction.view => context.guardedGo(
              '/menu-management/modifiers/${assignment.modifierGroupId}',
            ),
            _ModifierAction.customize => onEdit(),
            _ModifierAction.remove => onRemove(),
          },
          itemBuilder: (context) => <PopupMenuEntry<_ModifierAction>>[
            _modifierItem(
              _ModifierAction.view,
              context.l10n.modifierAssignmentViewGroup,
              Icons.visibility_outlined,
            ),
            _modifierItem(
              _ModifierAction.customize,
              assignment.hasCustomSettings
                  ? context.l10n.modifierAssignmentCustomizeForProduct
                  : context.l10n.modifierAssignmentCustomizeFor(
                      _productName(context),
                    ),
              Icons.tune,
            ),
            const PopupMenuDivider(),
            _modifierItem(
              _ModifierAction.remove,
              context.l10n.modifierAssignmentRemoveFromProduct,
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
    child: Center(child: Text(context.l10n.modifierAssignmentNoAssigned)),
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
          context.l10n.modifierAssignmentAddGroup,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(context.l10n.modifierAssignmentChooseGroupHelp),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: context.l10n.modifierAssignmentSearch,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: groups.isEmpty
              ? Center(child: Text(context.l10n.modifierAssignmentNoAvailable))
              : ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      title: Text(group.localizedName),
                      subtitle: Text(
                        modifierRuleSummaryForFields(
                          context,
                          selectionType: group.selectionType,
                          isRequired: group.isRequired,
                          minSelections: group.minSelections,
                          maxSelections: group.maxSelections,
                          allowQuantity: group.allowQuantity,
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: () => widget.onAdd(group),
                        child: Text(context.l10n.commonAdd),
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
) {
  final cubit = context.read<ProductModifierAssignmentsCubit>();
  return showDialog<ProductModifierAssignment>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _SideSheet(child: _CustomizationSheet(assignment: assignment)),
    ),
  );
}

class _SideSheet extends StatelessWidget {
  const _SideSheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final Size window = MediaQuery.sizeOf(context);
    return Dialog(
      alignment: AlignmentDirectional.centerEnd,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: SizedBox(
          width: math.min(520, window.width),
          height: window.height,
          child: Padding(padding: AppSpacing.allXl, child: child),
        ),
      ),
    );
  }
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.modifierAssignmentCustomizeFor(
                    context
                        .read<ProductModifierAssignmentsCubit>()
                        .state
                        .product!
                        .name,
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(context.l10n.modifierAssignmentCurrentBehavior),
                Text(
                  a.hasCustomSettings
                      ? context.l10n.modifierAssignmentCustomizedFor(
                          context
                              .read<ProductModifierAssignmentsCubit>()
                              .state
                              .product!
                              .name,
                        )
                      : context.l10n.modifierAssignmentUsingLibrarySettings,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: false,
                  groupValue: customized,
                  onChanged: (v) => setState(() => customized = false),
                  title: Text(
                    context.l10n.modifierAssignmentUseLibrarySettings,
                  ),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: true,
                  groupValue: customized,
                  onChanged: (v) => setState(() => customized = true),
                  title: Text(
                    context.l10n.modifierAssignmentCustomizeFor(
                      context
                          .read<ProductModifierAssignmentsCubit>()
                          .state
                          .product!
                          .name,
                    ),
                  ),
                ),
                if (customized) ...<Widget>[
                  const Divider(height: AppSpacing.xl),
                  Text(
                    context.l10n.modifierAssignmentHowChoose,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: 'single',
                    groupValue: a.selectionType,
                    onChanged: null,
                    title: Text(context.l10n.modifierAssignmentChooseOne),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: 'multiple',
                    groupValue: a.selectionType,
                    onChanged: null,
                    title: Text(context.l10n.modifierAssignmentChooseMultiple),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    multiple
                        ? context.l10n.modifierAssignmentMultipleHelp
                        : context.l10n.modifierAssignmentSingleHelp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: <ButtonSegment<bool>>[
                        ButtonSegment(
                          value: false,
                          label: Text(context.l10n.modifierOptional),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(context.l10n.modifierRequired),
                        ),
                      ],
                      selected: <bool>{required},
                      onSelectionChanged: (v) =>
                          setState(() => required = v.first),
                    ),
                  ),
                  if (multiple) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: min,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            context.l10n.modifierAssignmentMinimumChoices,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: max,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            context.l10n.modifierAssignmentMaximumChoices,
                      ),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: quantity,
                    onChanged: (v) => setState(() => quantity = v),
                    title: Text(context.l10n.modifierAssignmentAllowDuplicate),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    modifierRuleSummaryForFields(
                      context,
                      selectionType: a.selectionType,
                      isRequired: required,
                      minSelections: int.tryParse(min.text) ?? 0,
                      maxSelections: int.tryParse(max.text) ?? 0,
                      allowQuantity: quantity,
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: AppSpacing.xl),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonCancel),
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
                  child: Text(
                    context.l10n.modifierAssignmentUseLibrarySettings,
                  ),
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
                child: Text(context.l10n.modifierAssignmentApply),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<bool?> _removeDialog(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.modifierAssignmentRemoveTitle),
    content: Text(context.l10n.modifierAssignmentRemoveMessage),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(context.l10n.commonDelete),
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
      setState(() => error = context.l10n.modifierAssignmentNonNegative);
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
      setState(() => error = context.l10n.modifierAssignmentInvalidConstraints);
      return;
    }
    Navigator.pop(context, next);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return AlertDialog(
      title: Text(context.l10n.modifierAssignmentConfigure(a.localizedName)),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _boolSetting(
              context.l10n.modifierRequired,
              requiredOverride,
              requiredValue,
              a.libraryIsRequired,
              (v) => setState(() => requiredOverride = v),
              (v) => setState(() => requiredValue = v),
            ),
            _numberSetting(
              context.l10n.modifierAssignmentMinimumChoices,
              minOverride,
              min,
              a.libraryMinSelections,
              (v) => setState(() => minOverride = v),
            ),
            _numberSetting(
              context.l10n.modifierAssignmentMaximumChoices,
              maxOverride,
              max,
              a.libraryMaxSelections,
              (v) => setState(() => maxOverride = v),
            ),
            _boolSetting(
              context.l10n.modifierAllowQuantity,
              quantityOverride,
              quantityValue,
              a.libraryAllowQuantity,
              (v) => setState(() => quantityOverride = v),
              (v) => setState(() => quantityValue = v),
            ),
            Text(
              context.l10n.modifierAssignmentEffectiveSetting(
                requiredOverride
                    ? (requiredValue
                          ? context.l10n.modifierRequired
                          : context.l10n.modifierOptional)
                    : (a.libraryIsRequired
                          ? context.l10n.modifierRequired
                          : context.l10n.modifierOptional),
              ),
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
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: save,
          child: Text(context.l10n.modifierAssignmentApply),
        ),
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
        title: Text(context.l10n.modifierAssignmentOverride(label)),
        subtitle: Text(
          context.l10n.modifierAssignmentLibraryDefaultBoolean(
            defaultValue ? context.l10n.commonYes : context.l10n.commonNo,
          ),
        ),
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
        title: Text(context.l10n.modifierAssignmentOverride(label)),
        subtitle: Text(
          context.l10n.modifierAssignmentLibraryDefaultNumber(defaultValue),
        ),
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
