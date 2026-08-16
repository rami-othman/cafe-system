import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../widgets/menu_content_components.dart';
import '../../widgets/menu_page_header.dart';
import '../controllers/modifier_library_cubit.dart';
import '../models/modifier_models.dart';
import '../widgets/modifier_presentation.dart';

class ModifierLibraryScreen extends StatefulWidget {
  const ModifierLibraryScreen({super.key});

  @override
  State<ModifierLibraryScreen> createState() => _ModifierLibraryScreenState();
}

class _ModifierLibraryScreenState extends State<ModifierLibraryScreen> {
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ModifierLibraryCubit>().load(),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ModifierLibraryCubit, ModifierLibraryState>(
    builder: (context, state) {
      final ModifierLibraryCubit cubit = context.read<ModifierLibraryCubit>();
      final l10n = context.l10n;
      return DesktopPageLayout(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            120,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  MenuPageHeader(
                    title: l10n.modifierLibraryTitle,
                    subtitle: l10n.modifierLibrarySubtitle,
                    primaryAction: FilledButton.icon(
                      key: const Key('create-modifier-group-action'),
                      onPressed: () =>
                          context.go('/menu-management/modifiers/create'),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.modifierCreateGroup),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Toolbar(
                    state: state,
                    reordering: _reordering,
                    onSearch: cubit.updateSearch,
                    onStatus: (status) => cubit.updateFilter(
                      state.filter.copyWith(status: status),
                    ),
                    onReorder: () => setState(() => _reordering = true),
                    onDone: () => setState(() => _reordering = false),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.status == ModifierLibraryStatus.loading &&
                      state.groups.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.status == ModifierLibraryStatus.failure &&
                      state.groups.isEmpty)
                    EmptyState(
                      title: l10n.modifierUnableToLoad,
                      message: state.errorMessage ?? l10n.modifierUnableToLoad,
                      recoveryAction: EmptyStateAction(
                        label: l10n.modifierRetry,
                        onPressed: cubit.load,
                      ),
                    )
                  else if (state.groups.isEmpty)
                    EmptyState(
                      title: state.filter.hasActiveFilters
                          ? l10n.modifierNoGroupMatches
                          : l10n.modifierNoGroups,
                      message: state.filter.hasActiveFilters
                          ? l10n.modifierNoGroupMatches
                          : l10n.modifierNoGroups,
                      primaryAction: !state.filter.hasActiveFilters
                          ? EmptyStateAction(
                              label: l10n.modifierCreateGroup,
                              onPressed: () => context.go(
                                '/menu-management/modifiers/create',
                              ),
                            )
                          : null,
                    )
                  else ...<Widget>[
                    _GroupList(
                      groups: state.groups,
                      busyId: state.currentActionId,
                      reordering: _reordering,
                      onMove: cubit.move,
                      onArchive: (group) => _confirmArchive(
                        context,
                        group,
                        () => cubit.archive(group.id),
                      ),
                      onRestore: cubit.restore,
                    ),
                    if (state.status == ModifierLibraryStatus.failure)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _InlineError(
                          message:
                              state.errorMessage ?? l10n.modifierUnableToLoad,
                          retry: cubit.load,
                        ),
                      ),
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: state.isBusy
                                ? null
                                : () => cubit.load(next: true),
                            child: Text(l10n.modifierLoadMore),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.state,
    required this.reordering,
    required this.onSearch,
    required this.onStatus,
    required this.onReorder,
    required this.onDone,
  });

  final ModifierLibraryState state;
  final bool reordering;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatus;
  final VoidCallback onReorder;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
      ),
      child: Padding(
        padding: AppSpacing.allMd,
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: constraints.maxWidth < 700 ? 260 : 320,
                child: TextField(
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: l10n.modifierSearch,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment(
                    value: 'active',
                    label: Text(l10n.modifierActive),
                  ),
                  ButtonSegment(
                    value: 'archived',
                    label: Text(l10n.modifierArchived),
                  ),
                  ButtonSegment(value: 'all', label: Text(l10n.modifierAll)),
                ],
                selected: <String>{state.filter.status},
                onSelectionChanged: (values) => onStatus(values.first),
              ),
              if (reordering)
                OutlinedButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.modifierDone),
                )
              else
                OutlinedButton.icon(
                  onPressed: state.filter.status == 'active' ? onReorder : null,
                  icon: const Icon(Icons.swap_vert),
                  label: Text(l10n.modifierReorder),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.busyId,
    required this.reordering,
    required this.onMove,
    required this.onArchive,
    required this.onRestore,
  });

  final List<ModifierGroupRecord> groups;
  final int? busyId;
  final bool reordering;
  final void Function(ModifierGroupRecord, int) onMove;
  final ValueChanged<ModifierGroupRecord> onArchive;
  final ValueChanged<int> onRestore;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: Column(
      children: <Widget>[
        for (int index = 0; index < groups.length; index++) ...<Widget>[
          _GroupRow(
            group: groups[index],
            busy: busyId == groups[index].id,
            reordering: reordering,
            canMoveUp: index > 0,
            canMoveDown: index < groups.length - 1,
            onMove: onMove,
            onArchive: onArchive,
            onRestore: onRestore,
          ),
          if (index < groups.length - 1)
            const Divider(height: 1, indent: 68, endIndent: 16),
        ],
      ],
    ),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.busy,
    required this.reordering,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onArchive,
    required this.onRestore,
  });

  final ModifierGroupRecord group;
  final bool busy;
  final bool reordering;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(ModifierGroupRecord, int) onMove;
  final ValueChanged<ModifierGroupRecord> onArchive;
  final ValueChanged<int> onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final List<ModifierOptionRecord> preview = group.options.take(3).toList();
    final int more = math.max(0, group.optionCount - preview.length);
    final List<PopupMenuEntry<String>> menu = <PopupMenuEntry<String>>[
      PopupMenuItem(value: 'view', child: Text(l10n.modifierViewGroup)),
      if (!group.isArchived)
        PopupMenuItem(value: 'edit', child: Text(l10n.modifierEditGroup)),
      if (!group.isArchived)
        PopupMenuItem(
          value: 'adjustments',
          child: Text(l10n.modifierMaterialAdjustments),
        ),
      PopupMenuItem(
        value: group.isArchived ? 'restore' : 'archive',
        child: Text(
          group.isArchived ? l10n.modifierRestore : l10n.modifierArchive,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showPreview =
            constraints.maxWidth >= 860 && preview.isNotEmpty;
        return Semantics(
          container: true,
          button: !reordering,
          label:
              '${group.displayName(locale)}. ${modifierRuleSummary(context, group)}',
          child: InkWell(
            onTap: reordering
                ? null
                : () => context.go('/menu-management/modifiers/${group.id}'),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppRadius.control,
                    ),
                    child: const Icon(Icons.tune, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          group.displayName(locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${modifierOptionCountLabel(context, group.optionCount)} · ${modifierRuleSummary(context, group)}',
                          maxLines: constraints.maxWidth < 720 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (showPreview) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: <Widget>[
                              for (final ModifierOptionRecord option in preview)
                                ModifierPreviewChip(
                                  label: option.displayName(locale),
                                ),
                              if (more > 0)
                                Text(
                                  l10n.modifierOptionPreviewMore(more),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (reordering)
                    _MoveButtons(
                      canMoveUp: canMoveUp,
                      canMoveDown: canMoveDown,
                      disabled: busy || group.isArchived,
                      onUp: () => onMove(group, -1),
                      onDown: () => onMove(group, 1),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  modifierStatusBadge(context, group),
                  PopupMenuButton<String>(
                    tooltip:
                        '${l10n.modifierViewGroup}: ${group.displayName(locale)}',
                    enabled: !busy,
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          context.go('/menu-management/modifiers/${group.id}');
                        case 'edit':
                          context.go(
                            '/menu-management/modifiers/${group.id}/edit',
                          );
                        case 'adjustments':
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.modifierMaterialAdjustments),
                            ),
                          );
                        case 'archive':
                          onArchive(group);
                        case 'restore':
                          onRestore(group.id);
                      }
                    },
                    itemBuilder: (_) => menu,
                    icon: const Icon(Icons.more_vert),
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

class _MoveButtons extends StatelessWidget {
  const _MoveButtons({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.disabled,
    required this.onUp,
    required this.onDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final bool disabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      IconButton(
        tooltip: context.l10n.modifierMoveUp,
        onPressed: disabled || !canMoveUp ? null : onUp,
        icon: const Icon(Icons.keyboard_arrow_up),
      ),
      IconButton(
        tooltip: context.l10n.modifierMoveDown,
        onPressed: disabled || !canMoveDown ? null : onDown,
        icon: const Icon(Icons.keyboard_arrow_down),
      ),
    ],
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.retry});

  final String message;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(message)),
      TextButton(onPressed: retry, child: Text(context.l10n.modifierRetry)),
    ],
  );
}

Future<void> _confirmArchive(
  BuildContext context,
  ModifierGroupRecord group,
  Future<void> Function() action,
) async {
  final l10n = context.l10n;
  final bool? accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.modifierArchiveGroupTitle),
      content: Text(l10n.modifierArchiveMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.modifierCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.modifierConfirmArchive),
        ),
      ],
    ),
  );
  if (accepted == true) await action();
}
