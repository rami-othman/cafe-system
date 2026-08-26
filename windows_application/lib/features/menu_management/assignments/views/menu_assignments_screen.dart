import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../menus/models/menu_models.dart';
import '../../review/models/review_models.dart';
import '../controllers/menu_assignments_cubit.dart';
import '../models/menu_assignment_models.dart';

class MenuAssignmentsScreen extends StatefulWidget {
  const MenuAssignmentsScreen({
    super.key,
    this.initialBranchId,
    this.initialChannel,
    this.initialMenuId,
  });
  final int? initialBranchId, initialMenuId;
  final String? initialChannel;

  @override
  State<MenuAssignmentsScreen> createState() => _MenuAssignmentsScreenState();
}

class _MenuAssignmentsScreenState extends State<MenuAssignmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MenuAssignmentsCubit>().load(
        branchId: widget.initialBranchId,
        channel: widget.initialChannel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MenuAssignmentsCubit, MenuAssignmentsState>(
        listenWhen: (before, after) =>
            before.successMessage != after.successMessage &&
            after.successMessage != null,
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.successMessage!))),
        builder: (context, state) {
          final cubit = context.read<MenuAssignmentsCubit>();
          final l10n = context.l10n;
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                96,
              ),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  l10n.assignmentsWorkspaceTitle,
                                  style: AppTextStyles.headlineLarge,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  l10n.assignmentsWorkspaceHelp,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.commonRefresh,
                            onPressed: state.hasScope && !state.isBusy
                                ? cubit.refresh
                                : null,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _ScopeSelectors(state: state, cubit: cubit),
                      const SizedBox(height: AppSpacing.xl),
                      if (state.status == MenuAssignmentsStatus.loadingContext)
                        const _ContextSkeleton()
                      else if (!state.hasScope)
                        const _NoContextState()
                      else if (state.status == MenuAssignmentsStatus.loading ||
                          state.status == MenuAssignmentsStatus.refreshing)
                        const _AssignmentsSkeleton()
                      else if (state.status == MenuAssignmentsStatus.failure)
                        _WorkspaceError(onRetry: cubit.refresh)
                      else
                        _AssignmentsWorkspace(
                          state: state,
                          cubit: cubit,
                          onAddMenus: _openAddMenus,
                          onSchedule: _openSchedule,
                          onReorder: cubit.startReordering,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Future<void> _openAddMenus() async {
    final cubit = context.read<MenuAssignmentsCubit>();
    // Keep the workspace visible while this bounded source list loads.
    unawaited(cubit.loadAvailableMenus());
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => BlocProvider.value(
        value: cubit,
        child: _AddMenusSheet(
          branchId: cubit.state.selectedBranch!.id,
          channel: cubit.state.selectedChannel!,
        ),
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: Directionality.of(context) == TextDirection.rtl
              ? const Offset(-1, 0)
              : const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }

  Future<void> _openSchedule(MenuAssignment assignment) async {
    final cubit = context.read<MenuAssignmentsCubit>();
    // A schedule is an on-demand Menu detail.  Open its directional sheet
    // immediately so the contextual header and schedule skeleton stay in
    // place while this single Menu request is in flight.
    unawaited(cubit.retryScheduleRules(assignment.menuId));
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (sheetContext, _, _) => BlocProvider.value(
        value: cubit,
        child: _MenuScheduleSheet(assignment: assignment),
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: Directionality.of(context) == TextDirection.rtl
              ? const Offset(-1, 0)
              : const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }
}

class _ScopeSelectors extends StatelessWidget {
  const _ScopeSelectors({required this.state, required this.cubit});
  final MenuAssignmentsState state;
  final MenuAssignmentsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fields = <Widget>[
              _ContextField(
                label: l10n.assignmentsBranch,
                child: DropdownButtonFormField<int>(
                  key: const Key('assignments-branch-selector'),
                  initialValue: state.selectedBranch?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: l10n.assignmentsChooseBranch,
                    border: const OutlineInputBorder(),
                  ),
                  items: state.branches
                      .map(
                        (branch) => DropdownMenuItem<int>(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.isBusy
                      ? null
                      : (value) {
                          if (value != null) cubit.selectBranch(value);
                        },
                ),
              ),
              _ContextField(
                label: l10n.assignmentsSalesChannel,
                child: DropdownButtonFormField<String>(
                  key: const Key('assignments-channel-selector'),
                  initialValue: state.selectedChannel,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: l10n.assignmentsChooseChannel,
                    border: const OutlineInputBorder(),
                  ),
                  items: salesChannels
                      .map(
                        (channel) => DropdownMenuItem<String>(
                          value: channel,
                          child: Text(_channelLabel(l10n, channel)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.isBusy
                      ? null
                      : (value) {
                          if (value != null) cubit.selectChannel(value);
                        },
                ),
              ),
              _ContextField(
                label: l10n.assignmentsTimezone,
                child: Container(
                  height: 56,
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.selectedBranch?.timezone.isNotEmpty == true
                        ? state.selectedBranch!.timezone
                        : l10n.assignmentsTimezonePending,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
            ];
            if (constraints.maxWidth < 760) {
              return Column(
                children: fields
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: field,
                      ),
                    )
                    .toList(),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: fields
                  .map(
                    (field) => Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.md,
                        ),
                        child: field,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _ContextField extends StatelessWidget {
  const _ContextField({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: AppTextStyles.labelMedium),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );
}

class _AssignmentsWorkspace extends StatelessWidget {
  const _AssignmentsWorkspace({
    required this.state,
    required this.cubit,
    required this.onAddMenus,
    required this.onSchedule,
    required this.onReorder,
  });
  final MenuAssignmentsState state;
  final MenuAssignmentsCubit cubit;
  final Future<void> Function() onAddMenus;
  final VoidCallback onReorder;
  final Future<void> Function(MenuAssignment assignment) onSchedule;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.isReordering) {
      return _ReorderWorkspace(state: state, cubit: cubit);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: state.canReorder ? onReorder : null,
                      icon: const Icon(Icons.reorder, size: 18),
                      label: Text(l10n.assignmentsReorderMenus),
                    ),
                    FilledButton.icon(
                      onPressed: state.isBusy ? null : onAddMenus,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.assignmentsAddMenus),
                    ),
                  ],
                );
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.assignmentsAssignedMenus,
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.assignmentsMenuCount(state.assignments.length),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                );
                return constraints.maxWidth < 620
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          title,
                          const SizedBox(height: AppSpacing.md),
                          actions,
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          Expanded(child: title),
                          actions,
                        ],
                      );
              },
            ),
            if (state.assignments.length > 1 && state.hasArchivedAssignment)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.assignmentsReorderArchivedUnavailable,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            if (state.previewUnavailable &&
                state.assignments.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.assignmentsScheduleUnknown,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: state.isBusy ? null : cubit.retryPreview,
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (state.assignments.isEmpty)
              _EmptyScope(
                branch: state.selectedBranch!.name,
                channel: _channelLabel(l10n, state.selectedChannel!),
                onAddMenus: onAddMenus,
              )
            else
              ...state.orderedAssignments.map(
                (assignment) => _AssignmentRow(
                  assignment: assignment,
                  preview: state.previewMenus[assignment.menuId],
                  busy: state.isBusy,
                  cubit: cubit,
                  onSchedule: onSchedule,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.preview,
    required this.busy,
    required this.cubit,
    required this.onSchedule,
  });
  final MenuAssignment assignment;
  final ResolvedMenu? preview;
  final bool busy;
  final MenuAssignmentsCubit cubit;
  final Future<void> Function(MenuAssignment assignment) onSchedule;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final menu = assignment.menu;
    final bool archived = menu?.isArchived == true;
    final locale = Localizations.localeOf(context);
    final String name =
        menu?.displayName(locale) ?? l10n.assignmentsMenuFallback;
    final String secondary = locale.languageCode == 'ar'
        ? (menu?.nameEn ?? '')
        : (menu?.nameAr ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
                if (secondary.isNotEmpty)
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    _Tag(
                      label: l10n.assignmentsLifecycle(
                        _lifecycleLabel(l10n, menu),
                      ),
                      tone: _lifecycleTone(menu),
                    ),
                    _Tag(
                      label: assignment.isActive
                          ? l10n.assignmentsActive
                          : l10n.assignmentsInactive,
                      tone: assignment.isActive
                          ? _TagTone.success
                          : _TagTone.muted,
                    ),
                    _Tag(
                      label: _scheduleLabel(l10n, assignment, preview),
                      tone: _scheduleTone(assignment, preview),
                    ),
                  ],
                ),
              ],
            ),
          );
          final controls = Wrap(
            spacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Switch(
                value: assignment.isActive,
                onChanged: busy || archived
                    ? null
                    : (value) =>
                          cubit.setAssignmentActive(assignment.menuId, value),
              ),
              TextButton(
                onPressed: busy || archived
                    ? null
                    : () => onSchedule(assignment),
                child: Text(l10n.assignmentsManageSchedule),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.assignmentsRemove,
                enabled: !busy && !archived,
                onSelected: (value) {
                  if (value == 'remove') {
                    _confirmRemoveAssignment(context, cubit, assignment.menuId);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Text(l10n.assignmentsRemove),
                  ),
                ],
              ),
            ],
          );
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                identity,
                const SizedBox(height: AppSpacing.sm),
                controls,
                if (archived)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      l10n.assignmentsArchivedDiagnostic,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              identity,
              const SizedBox(width: AppSpacing.md),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _ReorderWorkspace extends StatelessWidget {
  const _ReorderWorkspace({required this.state, required this.cubit});
  final MenuAssignmentsState state;
  final MenuAssignmentsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool saving = state.currentActionKey == 'save-reorder';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.assignmentsReorderMenus,
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.assignmentsReorderHelp,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                );
                final done = FilledButton(
                  key: const Key('assignments-reorder-done'),
                  onPressed: saving ? null : cubit.doneReordering,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.assignmentsReorderDone),
                );
                return constraints.maxWidth < 520
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          title,
                          const SizedBox(height: AppSpacing.md),
                          done,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: title),
                          done,
                        ],
                      );
              },
            ),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.assignmentsReorderSaveFailed,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: state.reorderDraft
                    .asMap()
                    .entries
                    .map(
                      (entry) => _ReorderAssignmentRow(
                        assignment: entry.value,
                        isFirst: entry.key == 0,
                        isLast: entry.key == state.reorderDraft.length - 1,
                        busy: state.isBusy,
                        cubit: cubit,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderAssignmentRow extends StatelessWidget {
  const _ReorderAssignmentRow({
    required this.assignment,
    required this.isFirst,
    required this.isLast,
    required this.busy,
    required this.cubit,
  });
  final MenuAssignment assignment;
  final bool isFirst, isLast, busy;
  final MenuAssignmentsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final menu = assignment.menu;
    final locale = Localizations.localeOf(context);
    final String name =
        menu?.displayName(locale) ?? l10n.assignmentsMenuFallback;
    final String secondary = locale.languageCode == 'ar'
        ? (menu?.nameEn ?? '')
        : (menu?.nameAr ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
                if (secondary.isNotEmpty)
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _Tag(label: _lifecycleLabel(l10n, menu), tone: _lifecycleTone(menu)),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            label: l10n.assignmentsMoveUp,
            button: true,
            child: IconButton(
              key: Key('assignments-reorder-up-${assignment.menuId}'),
              tooltip: l10n.assignmentsMoveUp,
              onPressed: busy || isFirst
                  ? null
                  : () => cubit.moveReorderDraft(assignment.menuId, -1),
              icon: const Icon(Icons.arrow_upward),
            ),
          ),
          Semantics(
            label: l10n.assignmentsMoveDown,
            button: true,
            child: IconButton(
              key: Key('assignments-reorder-down-${assignment.menuId}'),
              tooltip: l10n.assignmentsMoveDown,
              onPressed: busy || isLast
                  ? null
                  : () => cubit.moveReorderDraft(assignment.menuId, 1),
              icon: const Icon(Icons.arrow_downward),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.tone});
  final String label;
  final _TagTone tone;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _TagTone.success => (const Color(0xFFE3F5E8), AppColors.success),
      _TagTone.warning => (const Color(0xFFFFF0DA), AppColors.warning),
      _TagTone.danger => (const Color(0xFFFFE8E6), AppColors.danger),
      _TagTone.muted => (AppColors.surfaceAlt, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: foreground),
      ),
    );
  }
}

enum _TagTone { success, warning, danger, muted }

class _NoContextState extends StatelessWidget {
  const _NoContextState();
  @override
  Widget build(BuildContext context) => _StateCard(
    icon: Icons.calendar_month_outlined,
    title: context.l10n.assignmentsNoContextTitle,
    help: context.l10n.assignmentsNoContextHelp,
  );
}

class _EmptyScope extends StatelessWidget {
  const _EmptyScope({
    required this.branch,
    required this.channel,
    required this.onAddMenus,
  });
  final String branch, channel;
  final Future<void> Function() onAddMenus;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
    child: _StateCard(
      icon: Icons.link_off,
      title: context.l10n.assignmentsNoMenusTitle,
      help: context.l10n.assignmentsNoMenusHelp(branch, channel),
      action: FilledButton.icon(
        onPressed: onAddMenus,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.assignmentsAddMenus),
      ),
    ),
  );
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => _StateCard(
    icon: Icons.error_outline,
    title: context.l10n.assignmentsLoadErrorTitle,
    help: context.l10n.commonError,
    action: FilledButton(
      onPressed: onRetry,
      child: Text(context.l10n.commonRetry),
    ),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.help,
    this.action,
  });
  final IconData icon;
  final String title, help;
  final Widget? action;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: SizedBox(
      width: double.infinity,
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 34, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              help,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    ),
  );
}

class _ContextSkeleton extends StatelessWidget {
  const _ContextSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 240,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _AssignmentsSkeleton extends StatelessWidget {
  const _AssignmentsSkeleton();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: List<Widget>.generate(
          5,
          (index) => Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AddMenusSheet extends StatefulWidget {
  const _AddMenusSheet({required this.branchId, required this.channel});
  final int branchId;
  final String channel;

  @override
  State<_AddMenusSheet> createState() => _AddMenusSheetState();
}

class _AddMenusSheetState extends State<_AddMenusSheet> {
  final Set<int> _selected = <int>{};
  String _search = '';
  bool _submitting = false;

  Future<void> _submit(MenuAssignmentsCubit cubit) async {
    if (_submitting || _selected.isEmpty) return;
    setState(() => _submitting = true);
    final bool saved = await cubit.addMenus(_selected);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MenuAssignmentsCubit, MenuAssignmentsState>(
      listenWhen: (before, after) =>
          before.selectedBranch?.id != after.selectedBranch?.id ||
          before.selectedChannel != after.selectedChannel ||
          before.hasScope != after.hasScope,
      listener: (context, state) {
        if (!state.hasScope ||
            state.selectedBranch!.id != widget.branchId ||
            state.selectedChannel != widget.channel) {
          Navigator.of(context).pop();
        }
      },
      child: BlocBuilder<MenuAssignmentsCubit, MenuAssignmentsState>(
        builder: (context, state) {
          final l10n = context.l10n;
          final cubit = context.read<MenuAssignmentsCubit>();
          final Set<int> assigned = state.assignments
              .map((assignment) => assignment.menuId)
              .toSet();
          final needle = _search.trim().toLowerCase();
          final List<MenuRecord> menus = state.availableMenus
              .where((menu) {
                if (needle.isEmpty) return true;
                return <String>[
                  menu.name,
                  menu.nameAr,
                  menu.nameEn,
                ].any((name) => name.toLowerCase().contains(needle));
              })
              .toList(growable: false);
          final bool loading = state.currentActionKey == 'available-menus';
          final bool saving =
              _submitting || state.currentActionKey == 'add-menus';
          final bool hasEligible = state.availableMenus.any(
            (menu) => !menu.isArchived && !assigned.contains(menu.id),
          );
          final AddMenusFailure failure = state.addMenusFailure;
          final String? error = switch (failure) {
            AddMenusFailure.load => l10n.assignmentsAddLoadError,
            AddMenusFailure.duplicate => l10n.assignmentsAddDuplicateError,
            AddMenusFailure.archivedScope =>
              l10n.assignmentsAddArchivedScopeError,
            AddMenusFailure.save => l10n.assignmentsAddSaveError,
            AddMenusFailure.none => null,
          };
          final String contextSummary =
              '${state.selectedBranch?.name ?? ''} · ${_channelLabel(l10n, widget.channel)}';
          return Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Material(
              color: AppColors.surface,
              child: SizedBox(
                width: 446,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    l10n.assignmentsAddMenus,
                                    style: AppTextStyles.titleLarge,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    contextSummary,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.commonClose,
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: TextField(
                          key: const Key('assignments-add-search'),
                          autofocus: true,
                          enabled: !loading && !saving,
                          onChanged: (value) => setState(() => _search = value),
                          decoration: InputDecoration(
                            hintText: l10n.assignmentsAddSearch,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: _AddMenusBody(
                          loading: loading,
                          error: error,
                          menus: menus,
                          hasEligible: hasEligible,
                          assigned: assigned,
                          selected: _selected,
                          onRetry: loading || saving
                              ? null
                              : failure == AddMenusFailure.load
                              ? cubit.loadAvailableMenus
                              : failure == AddMenusFailure.none
                              ? null
                              : () => _submit(cubit),
                          onToggle: saving
                              ? null
                              : (id) => setState(() {
                                  _selected.contains(id)
                                      ? _selected.remove(id)
                                      : _selected.add(id);
                                }),
                        ),
                      ),
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  l10n.assignmentsAddSelected(_selected.length),
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: Text(l10n.commonCancel),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilledButton(
                                key: const Key('assignments-add-submit'),
                                onPressed: saving || _selected.isEmpty
                                    ? null
                                    : () => _submit(cubit),
                                child: Text(
                                  _selected.isEmpty
                                      ? l10n.assignmentsAddMenus
                                      : l10n.assignmentsAddSelectedAction(
                                          _selected.length,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddMenusBody extends StatelessWidget {
  const _AddMenusBody({
    required this.loading,
    required this.error,
    required this.menus,
    required this.hasEligible,
    required this.assigned,
    required this.selected,
    required this.onRetry,
    required this.onToggle,
  });
  final bool loading, hasEligible;
  final String? error;
  final List<MenuRecord> menus;
  final Set<int> assigned, selected;
  final VoidCallback? onRetry;
  final ValueChanged<int>? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (loading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 5,
        itemBuilder: (_, _) => Container(
          height: 66,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      );
    }
    if (menus.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            hasEligible
                ? l10n.assignmentsAddNoMatches
                : l10n.assignmentsAddEmpty,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: menus.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final MenuRecord menu = menus[index];
        final bool alreadyAssigned = assigned.contains(menu.id);
        final bool archived = menu.isArchived;
        final bool enabled = !alreadyAssigned && !archived;
        final locale = Localizations.localeOf(context);
        final String secondary = locale.languageCode == 'ar'
            ? menu.nameEn
            : menu.nameAr;
        final String disabledText = alreadyAssigned
            ? l10n.assignmentsAddAlreadyAssigned
            : archived
            ? l10n.assignmentsAddArchivedUnavailable
            : '';
        return Semantics(
          enabled: enabled,
          checked: selected.contains(menu.id),
          label:
              '${menu.displayName(locale)} ${_lifecycleLabel(l10n, menu)} $disabledText',
          child: InkWell(
            key: Key('assignments-add-menu-${menu.id}'),
            onTap: enabled ? () => onToggle?.call(menu.id) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Opacity(
                      opacity: enabled ? 1 : .58,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  menu.displayName(locale),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelLarge,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _Tag(
                                label: _lifecycleLabel(l10n, menu),
                                tone: _lifecycleTone(menu),
                              ),
                            ],
                          ),
                          if (secondary.isNotEmpty)
                            Text(
                              secondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          if (disabledText.isNotEmpty)
                            Text(
                              disabledText,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Checkbox(
                    value: selected.contains(menu.id),
                    onChanged: enabled ? (_) => onToggle?.call(menu.id) : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _confirmRemoveAssignment(
  BuildContext context,
  MenuAssignmentsCubit cubit,
  int menuId,
) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.assignmentsRemove),
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
  if (yes == true && context.mounted) await cubit.removeAssignment(menuId);
}

// ignore: unused_element
Future<void> _showSchedule(
  BuildContext context,
  MenuAssignmentsCubit cubit,
  MenuAssignment assignment,
  List<MenuScheduleRule> rules,
) => showDialog<void>(
  context: context,
  builder: (context) =>
      _ScheduleDialog(cubit: cubit, assignment: assignment, rules: rules),
);

class _ScheduleDialog extends StatelessWidget {
  const _ScheduleDialog({
    required this.cubit,
    required this.assignment,
    required this.rules,
  });
  final MenuAssignmentsCubit cubit;
  final MenuAssignment assignment;
  final List<MenuScheduleRule> rules;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.assignmentsManageSchedule),
    content: SizedBox(
      width: 560,
      child: rules.isEmpty
          ? Text(context.l10n.assignmentsNoScheduleRestriction)
          : ListView(
              shrinkWrap: true,
              children: rules
                  .map(
                    (rule) => ListTile(
                      title: Text(
                        '${rule.startTime ?? ''} – ${rule.endTime ?? ''}',
                      ),
                      subtitle: Text(
                        rule.isActive
                            ? context.l10n.commonActive
                            : context.l10n.commonInactive,
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonClose),
      ),
    ],
  );
}

enum _MenuScheduleDayMode { allDay, custom, unavailable }

class _MenuScheduleSheet extends StatefulWidget {
  const _MenuScheduleSheet({required this.assignment});
  final MenuAssignment assignment;
  @override
  State<_MenuScheduleSheet> createState() => _MenuScheduleSheetState();
}

class _MenuScheduleSheetState extends State<_MenuScheduleSheet> {
  static const List<int> _week = <int>[1, 2, 3, 4, 5, 6, 0];
  List<MenuScheduleRule>? _draft;
  List<MenuScheduleRule>? _savedDraft;
  int? _editingDay;
  _MenuScheduleDayMode _mode = _MenuScheduleDayMode.allDay;
  final List<_ScheduleWindowEditor> _windows = <_ScheduleWindowEditor>[];
  String? _editorError;
  bool _moreOptionsOpen = false;
  DateTime? _dateLimitStart, _dateLimitEnd;
  bool _dateLimitsMixed = false;
  String? _dateLimitsError;
  DateTime _checkDate = DateTime.now();
  final TextEditingController _checkTime = TextEditingController(text: '13:00');
  _ScheduleCheckResult? _checkResult;
  String? _checkFailureMessage;
  bool _checking = false;
  bool _discardApproved = false;

  @override
  void dispose() {
    for (final window in _windows) {
      window.dispose();
    }
    _checkTime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MenuAssignmentsCubit>().state;
    final cubit = context.read<MenuAssignmentsCubit>();
    final loaded = state.scheduleRules[widget.assignment.menuId];
    if (_draft == null && loaded != null) {
      _draft = List<MenuScheduleRule>.of(loaded);
      _savedDraft = List<MenuScheduleRule>.of(loaded);
      _hydrateDateLimits();
    }
    final loading =
        _draft == null &&
        state.currentActionKey == 'load-schedule-${widget.assignment.menuId}';
    final saving =
        state.currentActionKey ==
        'save-menu-schedule-${widget.assignment.menuId}';
    final failed = _draft == null && !loading && state.errorMessage != null;
    final width = math
        .min(520, MediaQuery.sizeOf(context).width * .44)
        .toDouble();
    final menu = widget.assignment.menu;
    final name =
        menu?.displayName(Localizations.localeOf(context)) ??
        context.l10n.assignmentsMenuFallback;
    final branch = state.selectedBranch?.name ?? '';
    final channel = state.selectedChannel == null
        ? ''
        : _channelLabel(context.l10n, state.selectedChannel!);
    final timezone = state.selectedBranch?.timezone.isNotEmpty == true
        ? state.selectedBranch!.timezone
        : '';
    return PopScope(
      canPop: !saving && (_discardApproved || !_hasUnsavedChanges),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Material(
          color: AppColors.surface,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ScheduleSheetHeader(
                  title: context.l10n.menuScheduleTitle,
                  name: name,
                  contextLabel: '$branch · $channel',
                  timezone: timezone.isEmpty
                      ? null
                      : context.l10n.menuScheduleTimesShownIn(timezone),
                  onClose: saving ? null : _requestClose,
                ),
                Expanded(
                  child: loading
                      ? const _ScheduleSkeleton()
                      : failed
                      ? _ScheduleLoadError(
                          onRetry: () => cubit.retryScheduleRules(
                            widget.assignment.menuId,
                          ),
                        )
                      : _scheduleContent(context, saving),
                ),
                if (!loading && !failed)
                  _ScheduleSheetFooter(
                    saving: saving,
                    onCancel: _requestClose,
                    onSave: () => _save(cubit),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scheduleContent(BuildContext context, bool saving) {
    final state = context.read<MenuAssignmentsCubit>().state;
    final cubit = context.read<MenuAssignmentsCubit>();
    final branchId = state.selectedBranch!.id;
    final channel = state.selectedChannel!;
    final exact = _draft!
        .where((rule) => rule.matchesExactScope(branchId, channel))
        .toList(growable: false);
    final customized = exact.isNotEmpty;
    final source = customized
        ? exact.where((rule) => rule.isActive).toList(growable: false)
        : _broaderSource(_draft!, branchId, channel);
    final scope =
        '${state.selectedBranch!.name} · ${_channelLabel(context.l10n, channel)}';
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        if (_dateLimitsError != null || state.errorMessage != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _dateLimitsError ??
                  state.errorMessage ??
                  context.l10n.menuScheduleSaveError,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                customized ? Icons.tune_outlined : Icons.account_tree_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  customized
                      ? context.l10n.menuScheduleCustomizedFor(scope)
                      : context.l10n.menuScheduleUsingBroader,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              TextButton(
                key: const Key('menu-schedule-source-action'),
                onPressed: saving
                    ? null
                    : customized
                    ? () => _useBroader(cubit)
                    : _customize,
                child: Text(
                  customized
                      ? context.l10n.menuScheduleUseBroader
                      : context.l10n.menuScheduleCustomize,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: <Widget>[
              for (final day in _week) ...<Widget>[
                _ScheduleDayRow(
                  day: _dayLabel(context, day),
                  summary: _summaryForDay(context, source, day),
                  editing: _editingDay == day,
                  onEdit: saving
                      ? null
                      : () => _editingDay == day
                            ? setState(_clearEditor)
                            : _beginEdit(day),
                ),
                if (_editingDay == day)
                  _DayEditor(
                    mode: _mode,
                    windows: _windows,
                    error: _editorError,
                    onModeChanged: (value) => setState(() {
                      _mode = value;
                      _editorError = null;
                    }),
                    onAddWindow: _addWindow,
                    onRemoveWindow: _removeWindow,
                    onWindowChanged: _refreshEditor,
                    onCancel: () => setState(_clearEditor),
                    onApply: _applyDay,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          key: const Key('menu-schedule-more-options'),
          onPressed: () => setState(() => _moreOptionsOpen = !_moreOptionsOpen),
          icon: Icon(
            _moreOptionsOpen ? Icons.expand_less : Icons.expand_more,
            size: 18,
          ),
          label: Text(context.l10n.menuScheduleMoreOptions),
        ),
        if (_moreOptionsOpen) ...<Widget>[
          _DateLimitsCard(
            start: _dateLimitStart,
            end: _dateLimitEnd,
            mixed: _dateLimitsMixed,
            errorText: _dateLimitsError,
            onStart: _setDateLimitStart,
            onEnd: _setDateLimitEnd,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _CheckScheduleCard(
          date: _checkDate,
          time: _checkTime,
          timezone: state.selectedBranch!.timezone,
          result: _checkResult,
          failureMessage: _checkFailureMessage,
          checking: _checking,
          requiresSave: _hasUnsavedChanges,
          onDate: _pickCheckDate,
          onCheck: _checkSchedule,
        ),
      ],
    );
  }

  void _customize() => setState(_customizeDraft);

  void _customizeDraft() {
    final state = context.read<MenuAssignmentsCubit>().state;
    final branchId = state.selectedBranch!.id;
    final channel = state.selectedChannel!;
    final source = _broaderSource(_draft!, branchId, channel);
    // Preserve the current governing schedule when it becomes a new exact
    // context. Other scope rules are never edited or copied into this set.
    final List<MenuScheduleRule> exact = source.isEmpty
        ? <MenuScheduleRule>[
            MenuScheduleRule(
              id: -1,
              branchId: branchId,
              channel: channel,
              dayOfWeek: null,
              startTime: null,
              endTime: null,
              startDate: null,
              endDate: null,
              priority: 0,
              isActive: true,
              createdAt: null,
              updatedAt: null,
            ),
          ]
        : source
              .map(
                (rule) => MenuScheduleRule(
                  id: -rule.id.abs() - 1,
                  branchId: branchId,
                  channel: channel,
                  dayOfWeek: rule.dayOfWeek,
                  startTime: rule.startTime,
                  endTime: rule.endTime,
                  startDate: rule.startDate,
                  endDate: rule.endDate,
                  priority: rule.priority,
                  isActive: rule.isActive,
                  createdAt: null,
                  updatedAt: null,
                ),
              )
              .toList(growable: false);
    _draft = <MenuScheduleRule>[..._draft!, ...exact];
  }

  Future<void> _useBroader(MenuAssignmentsCubit cubit) async {
    final state = context.read<MenuAssignmentsCubit>().state;
    setState(() {
      _draft = _draft!
          .where(
            (rule) => !rule.matchesExactScope(
              state.selectedBranch!.id,
              state.selectedChannel!,
            ),
          )
          .toList(growable: false);
      _clearEditor();
      _hydrateDateLimits();
    });
    await _save(cubit);
  }

  Future<void> _beginEdit(int day) async {
    if (!_hasExactRules()) setState(_customizeDraft);
    if (_hasExactEveryDayRule()) {
      final bool? customize = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            context.l10n.menuScheduleCustomizeDayTitle(_dayLabel(context, day)),
          ),
          content: Text(context.l10n.menuScheduleCustomizeDayMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              key: Key('menu-schedule-customize-$day'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                context.l10n.menuScheduleCustomizeDayAction(
                  _dayLabel(context, day),
                ),
              ),
            ),
          ],
        ),
      );
      if (customize != true || !mounted) return;
      setState(_expandEveryDayRules);
    }
    if (!mounted) return;
    setState(() => _openDayEditor(day));
  }

  void _openDayEditor(int day) {
    final matches = _exactRulesForDay(day);
    _editingDay = day;
    _editorError = null;
    _mode = matches.isEmpty
        ? _MenuScheduleDayMode.unavailable
        : matches.any((rule) => rule.startTime == null)
        ? _MenuScheduleDayMode.allDay
        : _MenuScheduleDayMode.custom;
    _replaceWindows(matches);
  }

  /// Converts only the exact daily rules. Every clone retains the original
  /// timing, dates, priority, activity flag, and exact branch/channel scope.
  void _expandEveryDayRules() {
    final state = context.read<MenuAssignmentsCubit>().state;
    final List<MenuScheduleRule> expanded = <MenuScheduleRule>[];
    for (final rule in _draft!) {
      if (!rule.matchesExactScope(
            state.selectedBranch!.id,
            state.selectedChannel!,
          ) ||
          rule.dayOfWeek != null) {
        expanded.add(rule);
        continue;
      }
      for (final day in _week) {
        expanded.add(
          MenuScheduleRule(
            id: _nextTemporaryRuleId(expanded),
            branchId: rule.branchId,
            channel: rule.channel,
            dayOfWeek: day,
            startTime: rule.startTime,
            endTime: rule.endTime,
            startDate: rule.startDate,
            endDate: rule.endDate,
            priority: rule.priority,
            isActive: rule.isActive,
            createdAt: rule.createdAt,
            updatedAt: rule.updatedAt,
          ),
        );
      }
    }
    _draft = expanded;
    _hydrateDateLimits();
  }

  int _nextTemporaryRuleId([List<MenuScheduleRule>? additional]) {
    final ids = <int>[
      ..._draft!.map((rule) => rule.id),
      ...?additional?.map((rule) => rule.id),
    ];
    final lowest = ids.where((id) => id < 0).fold<int>(0, math.min);
    return lowest - 1;
  }

  void _applyDay() {
    final day = _editingDay!;
    final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (_mode == _MenuScheduleDayMode.custom &&
        (_windows.isEmpty ||
            _windows.any(
              (window) =>
                  !time.hasMatch(window.start.text) ||
                  !time.hasMatch(window.end.text) ||
                  window.start.text == window.end.text,
            ))) {
      setState(() => _editorError = context.l10n.menuScheduleInvalidTimes);
      return;
    }
    if (_mode == _MenuScheduleDayMode.unavailable && _hasExactEveryDayRule()) {
      setState(
        () => _editorError = context.l10n.menuScheduleUnavailableNotSupported,
      );
      return;
    }
    final state = context.read<MenuAssignmentsCubit>().state;
    final direct = _exactRulesForDay(day);
    final kept = _draft!
        .where((rule) => !direct.contains(rule))
        .toList(growable: true);
    if (_mode != _MenuScheduleDayMode.unavailable) {
      final values = _mode == _MenuScheduleDayMode.allDay
          ? <MenuScheduleRule?>[direct.firstOrNull]
          : _windows.map((window) => window.rule).toList(growable: false);
      for (final entry in values.asMap().entries) {
        // Reusing the existing all-day rule for the first custom window keeps
        // its rule-level metadata (especially priority and date limits) when
        // a manager changes availability mode.
        final existing =
            entry.value ??
            (entry.key == 0
                ? direct.where((rule) => rule.startTime == null).firstOrNull
                : null);
        final window = _mode == _MenuScheduleDayMode.allDay
            ? null
            : _windows[entry.key];
        kept.add(
          MenuScheduleRule(
            id: existing?.id ?? _nextTemporaryRuleId(),
            branchId: state.selectedBranch!.id,
            channel: state.selectedChannel!,
            dayOfWeek: day,
            startTime: _mode == _MenuScheduleDayMode.allDay
                ? null
                : window!.start.text,
            endTime: _mode == _MenuScheduleDayMode.allDay
                ? null
                : window!.end.text,
            startDate: existing?.startDate ?? _dateString(_dateLimitStart),
            endDate: existing?.endDate ?? _dateString(_dateLimitEnd),
            priority: existing?.priority ?? _nextExactPriority() + entry.key,
            isActive: existing?.isActive ?? true,
            createdAt: existing?.createdAt,
            updatedAt: existing?.updatedAt,
          ),
        );
      }
    }
    setState(() {
      _draft = kept;
      _clearEditor();
    });
  }

  Future<void> _save(MenuAssignmentsCubit cubit) async {
    final error = _validateDraft();
    if (error != null) {
      setState(() => _dateLimitsError = error);
      return;
    }
    final saved = await cubit.saveMenuSchedule(
      widget.assignment.menuId,
      _draft!.map((rule) => rule.toSyncJson()).toList(growable: false),
    );
    if (saved && mounted) {
      final savedRules = cubit.state.scheduleRules[widget.assignment.menuId];
      setState(() {
        _draft = List<MenuScheduleRule>.of(savedRules ?? _draft!);
        _savedDraft = List<MenuScheduleRule>.of(_draft!);
        _clearEditor();
        _hydrateDateLimits();
      });
    }
  }

  String? _validateDraft() {
    for (final rule in _draft!) {
      final error = _dateRangeError(
        _parseDate(rule.startDate),
        _parseDate(rule.endDate),
      );
      if (error != null) return error;
    }
    return null;
  }

  bool _hasExactRules() {
    final state = context.read<MenuAssignmentsCubit>().state;
    return _draft!.any(
      (rule) => rule.matchesExactScope(
        state.selectedBranch!.id,
        state.selectedChannel!,
      ),
    );
  }

  List<MenuScheduleRule> _exactRulesForDay(int day) {
    final state = context.read<MenuAssignmentsCubit>().state;
    return _draft!
        .where(
          (rule) =>
              rule.matchesExactScope(
                state.selectedBranch!.id,
                state.selectedChannel!,
              ) &&
              rule.dayOfWeek == day,
        )
        .toList(growable: false);
  }

  bool _hasExactEveryDayRule() {
    final state = context.read<MenuAssignmentsCubit>().state;
    return _draft!.any(
      (rule) =>
          rule.matchesExactScope(
            state.selectedBranch!.id,
            state.selectedChannel!,
          ) &&
          rule.dayOfWeek == null,
    );
  }

  int _nextExactPriority() {
    final active = _draft!
        .where((rule) => rule.isActive)
        .toList(growable: false);
    return active.isEmpty
        ? 0
        : active.map((rule) => rule.priority).reduce(math.max) + 1;
  }

  void _replaceWindows(List<MenuScheduleRule> rules) {
    for (final window in _windows) {
      window.dispose();
    }
    _windows
      ..clear()
      ..addAll(
        rules
            .where((rule) => rule.startTime != null)
            .map(_ScheduleWindowEditor.fromRule),
      );
  }

  void _addWindow() => setState(() => _windows.add(_ScheduleWindowEditor()));

  void _refreshEditor() => setState(() {});

  void _removeWindow(_ScheduleWindowEditor window) => setState(() {
    window.dispose();
    _windows.remove(window);
    if (_windows.isEmpty) _mode = _MenuScheduleDayMode.unavailable;
  });

  void _hydrateDateLimits() {
    final state = context.read<MenuAssignmentsCubit>().state;
    final exact = _draft!
        .where(
          (rule) => rule.matchesExactScope(
            state.selectedBranch!.id,
            state.selectedChannel!,
          ),
        )
        .toList(growable: false);
    _dateLimitsMixed = false;
    if (exact.isEmpty) {
      _dateLimitStart = null;
      _dateLimitEnd = null;
      _dateLimitsError = null;
      return;
    }
    final limits = exact
        .map((rule) => '${rule.startDate ?? ''}\u0000${rule.endDate ?? ''}')
        .toSet();
    if (limits.length > 1) {
      _dateLimitsMixed = true;
      _dateLimitStart = null;
      _dateLimitEnd = null;
      _dateLimitsError = null;
      return;
    }
    _dateLimitStart = _parseDate(exact.first.startDate);
    _dateLimitEnd = _parseDate(exact.first.endDate);
    _dateLimitsError = _dateRangeError(_dateLimitStart, _dateLimitEnd);
  }

  void _setDateLimitStart(DateTime? value) {
    setState(() {
      final error = _dateRangeError(value, _dateLimitEnd);
      if (error != null) {
        _dateLimitsError = error;
        return;
      }
      _dateLimitStart = value;
      _dateLimitsError = null;
      _applyDateLimits();
    });
  }

  void _setDateLimitEnd(DateTime? value) {
    setState(() {
      final error = _dateRangeError(_dateLimitStart, value);
      if (error != null) {
        _dateLimitsError = error;
        return;
      }
      _dateLimitEnd = value;
      _dateLimitsError = null;
      _applyDateLimits();
    });
  }

  String? _dateRangeError(DateTime? start, DateTime? end) =>
      start != null && end != null && end.isBefore(start)
      ? context.l10n.menuScheduleInvalidDateRange
      : null;

  void _applyDateLimits() {
    if (_dateLimitsMixed) return;
    if (!_hasExactRules()) _customizeDraft();
    final state = context.read<MenuAssignmentsCubit>().state;
    _draft = _draft!
        .map(
          (rule) =>
              rule.matchesExactScope(
                state.selectedBranch!.id,
                state.selectedChannel!,
              )
              ? _copyRule(
                  rule,
                  startDate: _dateString(_dateLimitStart),
                  endDate: _dateString(_dateLimitEnd),
                )
              : rule,
        )
        .toList(growable: false);
  }

  Future<void> _pickCheckDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _checkDate,
    );
    if (date != null && mounted) setState(() => _checkDate = date);
  }

  Future<void> _checkSchedule() async {
    if (_checking || _hasUnsavedChanges) return;
    final match = RegExp(
      r'^([01]\d|2[0-3]):[0-5]\d$',
    ).firstMatch(_checkTime.text);
    if (match == null) {
      setState(() => _checkResult = _ScheduleCheckResult.invalid);
      return;
    }
    setState(() {
      _checking = true;
      _checkResult = null;
      _checkFailureMessage = null;
    });
    try {
      final at = _branchEvaluationAt(
        _checkDate,
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        context.read<MenuAssignmentsCubit>().state.selectedBranch!.timezone,
      );
      final menu = await context.read<MenuAssignmentsCubit>().checkMenuSchedule(
        widget.assignment.menuId,
        at,
      );
      if (mounted) {
        setState(
          () => _checkResult = menu.isScheduledAvailable
              ? _ScheduleCheckResult.available
              : _ScheduleCheckResult.outsideHours,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _checkResult = _ScheduleCheckResult.failure;
          _checkFailureMessage = _scheduleCheckFailureMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _scheduleCheckFailureMessage(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    if (error is FormatException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    final description = error.toString().trim();
    return description.isEmpty
        ? context.l10n.menuScheduleCheckFailed
        : description;
  }

  bool get _hasUnsavedChanges {
    final saved = _savedDraft;
    if (saved == null || _draft == null || saved.length != _draft!.length) {
      return saved != _draft;
    }
    for (var index = 0; index < saved.length; index++) {
      if (saved[index] != _draft![index]) return true;
    }
    return false;
  }

  Future<void> _requestClose() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.menuScheduleDiscardTitle),
        content: Text(context.l10n.menuScheduleDiscardMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.menuScheduleDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _discardApproved = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _clearEditor() {
    _editingDay = null;
    _editorError = null;
    for (final window in _windows) {
      window.dispose();
    }
    _windows.clear();
  }
}

class _ScheduleSheetHeader extends StatelessWidget {
  const _ScheduleSheetHeader({
    required this.title,
    required this.name,
    required this.contextLabel,
    required this.timezone,
    required this.onClose,
  });
  final String title, name, contextLabel;
  final String? timezone;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: AppTextStyles.titleLarge)),
            IconButton(
              tooltip: context.l10n.commonClose,
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(name, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(contextLabel, style: AppTextStyles.bodySmall),
        if (timezone != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            timezone!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    ),
  );
}

class _ScheduleSkeleton extends StatelessWidget {
  const _ScheduleSkeleton();
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(AppSpacing.lg),
    itemCount: 7,
    itemBuilder: (_, _) => Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

class _ScheduleLoadError extends StatelessWidget {
  const _ScheduleLoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(context.l10n.menuScheduleLoadError, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleDayRow extends StatelessWidget {
  const _ScheduleDayRow({
    required this.day,
    required this.summary,
    required this.editing,
    required this.onEdit,
  });
  final String day, summary;
  final bool editing;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(day, style: AppTextStyles.bodyMedium)),
        Flexible(
          child: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: summary.contains(':') ? TextDirection.ltr : null,
            style: AppTextStyles.bodyMedium.copyWith(
              color: summary == context.l10n.menuScheduleUnavailable
                  ? AppColors.textMuted
                  : null,
            ),
          ),
        ),
        IconButton(
          key: Key('menu-schedule-edit-$day'),
          tooltip: context.l10n.menuScheduleEditDay(day),
          onPressed: onEdit,
          icon: Icon(
            editing ? Icons.expand_less : Icons.edit_outlined,
            size: 18,
          ),
        ),
      ],
    ),
  );
}

class _DayEditor extends StatelessWidget {
  const _DayEditor({
    required this.mode,
    required this.windows,
    required this.error,
    required this.onModeChanged,
    required this.onAddWindow,
    required this.onRemoveWindow,
    required this.onWindowChanged,
    required this.onCancel,
    required this.onApply,
  });
  final _MenuScheduleDayMode mode;
  final List<_ScheduleWindowEditor> windows;
  final String? error;
  final ValueChanged<_MenuScheduleDayMode> onModeChanged;
  final VoidCallback onAddWindow;
  final ValueChanged<_ScheduleWindowEditor> onRemoveWindow;
  final VoidCallback onWindowChanged;
  final VoidCallback onCancel, onApply;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RadioGroup<_MenuScheduleDayMode>(
      groupValue: mode,
      onChanged: (value) {
        if (value != null) onModeChanged(value);
      },
      child: Material(
        color: AppColors.surfaceAlt,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              RadioListTile<_MenuScheduleDayMode>(
                contentPadding: EdgeInsets.zero,
                value: _MenuScheduleDayMode.allDay,
                title: Text(l10n.menuScheduleAvailableAllDay),
              ),
              RadioListTile<_MenuScheduleDayMode>(
                contentPadding: EdgeInsets.zero,
                value: _MenuScheduleDayMode.custom,
                title: Text(l10n.menuScheduleCustomHours),
              ),
              if (mode == _MenuScheduleDayMode.custom) ...<Widget>[
                for (final window in windows)
                  _ScheduleWindowFields(
                    window: window,
                    onRemove: () => onRemoveWindow(window),
                    onChanged: onWindowChanged,
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('menu-schedule-add-window'),
                    onPressed: onAddWindow,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.menuScheduleAddTimeWindow),
                  ),
                ),
              ],
              RadioListTile<_MenuScheduleDayMode>(
                contentPadding: EdgeInsets.zero,
                value: _MenuScheduleDayMode.unavailable,
                title: Text(l10n.menuScheduleUnavailable),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: onCancel,
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: onApply,
                    child: Text(l10n.menuScheduleSaveDay),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleWindowFields extends StatelessWidget {
  const _ScheduleWindowFields({
    required this.window,
    required this.onRemove,
    required this.onChanged,
  });
  final _ScheduleWindowEditor window;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final overnight = _isOvernight(window.start.text, window.end.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _ScheduleTimePicker(
                  fieldKey: Key('menu-schedule-window-${window.key}-start'),
                  controller: window.start,
                  label: context.l10n.menuScheduleStartTime,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ScheduleTimePicker(
                  fieldKey: Key('menu-schedule-window-${window.key}-end'),
                  controller: window.end,
                  label: context.l10n.menuScheduleEndTime,
                  onChanged: onChanged,
                ),
              ),
              IconButton(
                key: Key('menu-schedule-window-${window.key}-remove'),
                tooltip: context.l10n.commonDelete,
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (overnight)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                context.l10n.menuScheduleOvernightUntil(window.end.text),
                textDirection: TextDirection.ltr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleWindowEditor {
  _ScheduleWindowEditor({this.rule})
    : key = '${rule?.id ?? DateTime.now().microsecondsSinceEpoch}',
      start = TextEditingController(text: rule?.startTime ?? ''),
      end = TextEditingController(text: rule?.endTime ?? '');
  _ScheduleWindowEditor.fromRule(MenuScheduleRule rule) : this(rule: rule);

  final MenuScheduleRule? rule;
  final String key;
  final TextEditingController start, end;
  void dispose() {
    start.dispose();
    end.dispose();
  }
}

enum _ScheduleCheckResult { available, outsideHours, invalid, failure }

class _DateLimitsCard extends StatelessWidget {
  const _DateLimitsCard({
    required this.start,
    required this.end,
    required this.mixed,
    required this.errorText,
    required this.onStart,
    required this.onEnd,
  });
  final DateTime? start, end;
  final bool mixed;
  final String? errorText;
  final ValueChanged<DateTime?> onStart, onEnd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.menuScheduleDateLimits,
          style: AppTextStyles.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (mixed)
          Text(
            context.l10n.menuScheduleDateLimitsMixed,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                Expanded(
                  child: _ScheduleDateField(
                    label: context.l10n.menuScheduleStartDate,
                    value: start,
                    lastDate: end,
                    onChanged: onStart,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ScheduleDateField(
                    label: context.l10n.menuScheduleEndDate,
                    value: end,
                    firstDate: start,
                    errorText: errorText,
                    onChanged: onEnd,
                  ),
                ),
              ];
              return constraints.maxWidth < 360
                  ? Column(
                      children: <Widget>[
                        fields.first,
                        const SizedBox(height: AppSpacing.sm),
                        fields.last,
                      ],
                    )
                  : Row(children: fields);
            },
          ),
      ],
    ),
  );
}

class _ScheduleDateField extends StatelessWidget {
  const _ScheduleDateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.errorText,
  });
  final String label;
  final DateTime? value;
  final DateTime? firstDate, lastDate;
  final String? errorText;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    // [initialValue] is intentionally recreated when the selected value
    // changes; otherwise TextFormField keeps its original date on screen.
    key: ValueKey<String>(
      'menu-schedule-date-$label-${value?.toIso8601String() ?? 'none'}',
    ),
    readOnly: true,
    initialValue: value == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(value!),
    decoration: InputDecoration(
      labelText: label,
      errorText: errorText,
      suffixIcon: IconButton(
        tooltip: context.l10n.commonDelete,
        onPressed: value == null ? null : () => onChanged(null),
        icon: const Icon(Icons.close, size: 18),
      ),
    ),
    onTap: () async {
      final minimum = firstDate ?? DateTime(2020);
      final maximum = lastDate ?? DateTime(2100);
      final candidate = value ?? DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: candidate.isBefore(minimum)
            ? minimum
            : candidate.isAfter(maximum)
            ? maximum
            : candidate,
        firstDate: minimum,
        lastDate: maximum,
      );
      if (date != null) onChanged(date);
    },
  );
}

class _CheckScheduleCard extends StatelessWidget {
  const _CheckScheduleCard({
    required this.date,
    required this.time,
    required this.timezone,
    required this.result,
    required this.failureMessage,
    required this.checking,
    required this.requiresSave,
    required this.onDate,
    required this.onCheck,
  });
  final DateTime date;
  final TextEditingController time;
  final String timezone;
  final _ScheduleCheckResult? result;
  final String? failureMessage;
  final bool checking, requiresSave;
  final Future<void> Function() onDate, onCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resultWidget = switch (result) {
      _ScheduleCheckResult.available => _result(
        context,
        Icons.check_circle_outline,
        l10n.commonAvailable,
        const Color(0xFFE3F5E8),
        AppColors.success,
      ),
      _ScheduleCheckResult.outsideHours => _result(
        context,
        Icons.schedule_outlined,
        l10n.assignmentsOutsideHours,
        const Color(0xFFFFEEE8),
        AppColors.danger,
      ),
      _ScheduleCheckResult.invalid => _result(
        context,
        Icons.info_outline,
        l10n.menuScheduleInvalidTimes,
        const Color(0xFFFFEEE8),
        AppColors.danger,
      ),
      _ScheduleCheckResult.failure => _result(
        context,
        Icons.error_outline,
        failureMessage ?? l10n.menuScheduleCheckFailed,
        const Color(0xFFFFE8E6),
        AppColors.danger,
      ),
      null => null,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.menuScheduleCheckTitle, style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  key: ValueKey<String>(
                    'menu-schedule-check-date-${date.toIso8601String()}',
                  ),
                  readOnly: true,
                  initialValue: MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(date),
                  decoration: InputDecoration(labelText: l10n.menuScheduleDate),
                  onTap: onDate,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ScheduleTimePicker(
                  fieldKey: const Key('menu-schedule-check-time'),
                  controller: time,
                  label: l10n.menuScheduleTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.menuScheduleCheckTimezone(timezone),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          if (requiresSave) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.menuScheduleCheckSaveFirst,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('menu-schedule-check'),
            onPressed: checking || requiresSave ? null : onCheck,
            child: checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.menuScheduleCheckTitle),
          ),
          if (resultWidget != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            resultWidget,
          ],
        ],
      ),
    );
  }

  Widget _result(
    BuildContext context,
    IconData icon,
    String label,
    Color background,
    Color foreground,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
      ],
    ),
  );
}

class _ScheduleTimePicker extends StatelessWidget {
  const _ScheduleTimePicker({
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.onChanged,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    controller: controller,
    readOnly: true,
    showCursor: false,
    textDirection: TextDirection.ltr,
    onTap: () => _pick(context),
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: const Icon(Icons.access_time_outlined),
    ),
  );

  Future<void> _pick(BuildContext context) async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: _parse(controller.text) ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (selected == null) return;
    controller.text =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    onChanged?.call();
  }

  TimeOfDay? _parse(String value) {
    final Match? match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final int? hour = int.tryParse(match.group(1)!);
    final int? minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
}

bool _isOvernight(String start, String end) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(start) &&
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(end) &&
    end.compareTo(start) < 0;

DateTime? _parseDate(String? value) =>
    value == null || value.isEmpty ? null : DateTime.tryParse(value);

String? _dateString(DateTime? date) => date == null
    ? null
    : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

MenuScheduleRule _copyRule(
  MenuScheduleRule rule, {
  String? startDate,
  String? endDate,
}) => MenuScheduleRule(
  id: rule.id,
  branchId: rule.branchId,
  channel: rule.channel,
  dayOfWeek: rule.dayOfWeek,
  startTime: rule.startTime,
  endTime: rule.endTime,
  startDate: startDate,
  endDate: endDate,
  priority: rule.priority,
  isActive: rule.isActive,
  createdAt: rule.createdAt,
  updatedAt: rule.updatedAt,
);

/// The backend receives an instant and resolves it in the Branch timezone.
/// Asia/Damascus is the supported branch zone in this workspace (UTC+03:00);
/// keeping this explicit prevents the administrator workstation timezone from
/// changing the manager-selected wall-clock time. Other zones retain the
/// platform offset until a timezone package is introduced centrally.
DateTime _branchEvaluationAt(DateTime date, int hour, int minute, String zone) {
  if (zone == 'Asia/Damascus') {
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 3));
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

class _ScheduleSheetFooter extends StatelessWidget {
  const _ScheduleSheetFooter({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });
  final bool saving;
  final VoidCallback onCancel, onSave;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text(context.l10n.commonCancel),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('menu-schedule-save'),
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.menuScheduleSave),
          ),
        ],
      ),
    ),
  );
}

List<MenuScheduleRule> _broaderSource(
  List<MenuScheduleRule> all,
  int branchId,
  String channel,
) {
  final matching = all
      .where(
        (rule) =>
            rule.isActive &&
            !rule.matchesExactScope(branchId, channel) &&
            (rule.branchId == null || rule.branchId == branchId) &&
            (rule.channel == null || rule.channel == channel),
      )
      .toList(growable: false);
  if (matching.isEmpty) return matching;
  int specificity(MenuScheduleRule rule) =>
      (rule.branchId == null ? 0 : 2) + (rule.channel == null ? 0 : 1);
  final highest = matching.map(specificity).reduce(math.max);
  return matching
      .where((rule) => specificity(rule) == highest)
      .toList(growable: false);
}

String _summaryForDay(
  BuildContext context,
  List<MenuScheduleRule> source,
  int day,
) {
  final matches = source
      .where((rule) => rule.dayOfWeek == day || rule.dayOfWeek == null)
      .toList(growable: false);
  if (matches.isEmpty) {
    return source.isEmpty
        ? context.l10n.menuScheduleAvailableAllDay
        : context.l10n.menuScheduleUnavailable;
  }
  if (matches.any((rule) => rule.startTime == null)) {
    return context.l10n.menuScheduleAvailableAllDay;
  }
  if (matches.length > 1) {
    return matches
        .map(
          (rule) => rule.startTime == null
              ? context.l10n.menuScheduleAvailableAllDay
              : '${rule.startTime}–${rule.endTime}',
        )
        .join(' · ');
  }
  final rule = matches.single;
  return rule.startTime == null
      ? context.l10n.menuScheduleAvailableAllDay
      : '${rule.startTime} – ${rule.endTime}';
}

String _dayLabel(BuildContext context, int day) => switch (day) {
  1 => context.l10n.menuScheduleMonday,
  2 => context.l10n.menuScheduleTuesday,
  3 => context.l10n.menuScheduleWednesday,
  4 => context.l10n.menuScheduleThursday,
  5 => context.l10n.menuScheduleFriday,
  6 => context.l10n.menuScheduleSaturday,
  _ => context.l10n.menuScheduleSunday,
};

/// Small, non-technical summary retained for focused schedule rule tests and
/// diagnostic surfaces. The drawer itself uses localized weekly labels.
String scheduleSummary(
  List<MenuScheduleRule> rules,
  int branchId,
  String channel,
) {
  if (rules.isEmpty) return 'Unrestricted';
  final List<MenuScheduleRule> exact = rules
      .where(
        (rule) => rule.matchesExactScope(branchId, channel) && rule.isActive,
      )
      .toList(growable: false);
  final List<MenuScheduleRule> source = exact.isNotEmpty
      ? exact
      : _broaderSource(rules, branchId, channel);
  if (source.isEmpty) return 'Unrestricted';
  final MenuScheduleRule rule = source.first;
  final String day = switch (rule.dayOfWeek) {
    null => 'Daily',
    0 => 'Sun',
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    _ => 'Sat',
  };
  if (source.length > 1) {
    return '$day, ${source.map((item) => item.startTime == null ? 'all day' : '${item.startTime}–${item.endTime}').join(' · ')}';
  }
  if (rule.startTime == null) return 'Inherited: $day';
  return '$day, ${rule.startTime}\u2013${rule.endTime}${rule.isOvernight ? ' (overnight)' : ''}';
}

String _channelLabel(dynamic l10n, String channel) => switch (channel) {
  'pos' => l10n.salesChannelPos,
  'waiter_app' => l10n.assignmentsChannelWaiterApp,
  'kiosk' => l10n.assignmentsChannelKiosk,
  'qr_ordering' => l10n.assignmentsChannelQrOrdering,
  'delivery' => l10n.assignmentsChannelDelivery,
  'online_ordering' => l10n.assignmentsChannelOnlineOrdering,
  _ => l10n.commonUnknown,
};
String _lifecycleLabel(dynamic l10n, MenuRecord? menu) =>
    switch (menu?.isArchived == true ? 'archived' : menu?.status) {
      'draft' => l10n.statusDraft,
      'active' => l10n.commonActive,
      'paused' => l10n.assignmentsPaused,
      'archived' => l10n.commonArchived,
      _ => l10n.commonUnknown,
    };
_TagTone _lifecycleTone(MenuRecord? menu) => menu?.isArchived == true
    ? _TagTone.muted
    : switch (menu?.status) {
        'active' => _TagTone.success,
        'paused' => _TagTone.warning,
        'draft' => _TagTone.muted,
        _ => _TagTone.muted,
      };
String _scheduleLabel(
  dynamic l10n,
  MenuAssignment assignment,
  ResolvedMenu? preview,
) {
  if (!assignment.isActive) return l10n.assignmentsScheduleUnknown;
  if (preview == null) return l10n.assignmentsScheduleUnknown;
  return switch (preview.scheduleReason) {
    'no_schedule_restriction' => l10n.assignmentsNoScheduleRestriction,
    'matched_rule' when preview.isScheduledAvailable =>
      l10n.assignmentsAvailableNow,
    'outside_schedule' when !preview.isScheduledAvailable =>
      l10n.assignmentsOutsideHours,
    _ => l10n.assignmentsScheduleUnknown,
  };
}

_TagTone _scheduleTone(MenuAssignment assignment, ResolvedMenu? preview) =>
    !assignment.isActive || preview == null
    ? _TagTone.muted
    : preview.isScheduledAvailable
    ? _TagTone.success
    : _TagTone.warning;
