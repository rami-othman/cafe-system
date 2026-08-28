import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/menu_management_route_locations.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/menu_detail_cubit.dart';
import '../controllers/menu_editor_cubit.dart';
import '../models/menu_editor_draft.dart';
import '../models/menu_models.dart';
import 'product_placements_screen.dart';
import 'menu_editor_screen.dart';

/// Canonical URL-addressable workspace for one menu.
class MenuDetailScreen extends StatefulWidget {
  const MenuDetailScreen({
    super.key,
    required this.menuId,
    this.initialTab = MenuWorkspaceTab.overview,
    this.createEditorCubit,
  });
  final int menuId;
  final MenuWorkspaceTab initialTab;
  final MenuEditorCubit Function()? createEditorCubit;

  @override
  State<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends State<MenuDetailScreen> {
  late MenuWorkspaceTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MenuDetailCubit>().load(widget.menuId),
    );
  }

  void _select(MenuWorkspaceTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    context.go(
      MenuManagementRouteLocations.menuWorkspace(widget.menuId, tab: tab),
    );
  }

  Future<void> _openEditor() async {
    final result = await showMenuEditorSheet(
      context,
      menuId: widget.menuId,
      cubit: widget.createEditorCubit?.call(),
    );
    if (result != null && mounted) {
      await context.read<MenuDetailCubit>().load(widget.menuId);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<MenuDetailCubit, MenuDetailState>(
    builder: (context, state) {
      final menu = state.menu;
      if (menu == null) return _loadingOrError(state);
      return DesktopPageLayout(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            72,
          ),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              key: const Key('menu-workspace-content'),
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _WorkspaceHeader(
                    menu: menu,
                    state: state,
                    onEdit: _openEditor,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Tabs(selected: _tab, onSelected: _select),
                  const SizedBox(height: AppSpacing.lg),
                  if (menu.isArchived) const _ReadOnlyNotice(),
                  if (state.errorMessage != null) _Message(state.errorMessage!),
                  switch (_tab) {
                    MenuWorkspaceTab.overview => _Overview(
                      menu: menu,
                      onTab: _select,
                    ),
                    MenuWorkspaceTab.sections => _Sections(
                      menu: menu,
                      state: state,
                    ),
                    MenuWorkspaceTab.products => ProductPlacementsScreen(
                      menuId: widget.menuId,
                      embedded: true,
                      initialMenu: menu,
                      onAddSection: () => showMenuSectionEditor(
                        context,
                        onSubmit: context.read<MenuDetailCubit>().createSection,
                      ),
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _loadingOrError(MenuDetailState state) => DesktopPageLayout(
    child: Center(
      child: state.status == MenuDetailStatus.failure
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.cloud_off_outlined, size: 38),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _tab == MenuWorkspaceTab.sections
                      ? context.l10n.menuSectionsLoadError
                      : _MenuOverviewCopy.of(context).couldNotLoad,
                ),
                TextButton(
                  onPressed: () =>
                      context.read<MenuDetailCubit>().load(widget.menuId),
                  child: Text(_MenuOverviewCopy.of(context).retry),
                ),
              ],
            )
          : _tab == MenuWorkspaceTab.sections
          ? const _SectionsWorkspaceSkeleton()
          : _tab == MenuWorkspaceTab.products
          ? const ProductCompositionSkeleton()
          : _WorkspaceSkeleton(copy: _MenuOverviewCopy.of(context)),
    ),
  );
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.menu,
    required this.state,
    required this.onEdit,
  });
  final MenuRecord menu;
  final MenuDetailState state;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final copy = _MenuOverviewCopy.of(context);
    final locale = Localizations.localeOf(context);
    final primaryName = menu.displayName(locale);
    final secondaryName = _alternateMenuName(menu, locale, primaryName);
    final cubit = context.read<MenuDetailCubit>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                primaryName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (secondaryName.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  secondaryName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _StatusPill(
                status: menu.isArchived ? 'archived' : menu.status,
                copy: copy,
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: menu.isArchived ? null : onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: Text(copy.editMenu),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<String>(
          tooltip: copy.actions,
          onSelected: state.isBusy
              ? null
              : (value) async {
                  final restore = value == 'restore';
                  if (await _confirmMenu(context, restore: restore)) {
                    await (restore ? cubit.restoreMenu() : cubit.archiveMenu());
                  }
                },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            PopupMenuItem(
              value: menu.isArchived ? 'restore' : 'archive',
              child: Text(menu.isArchived ? copy.restore : copy.archive),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});
  final MenuWorkspaceTab selected;
  final ValueChanged<MenuWorkspaceTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = _MenuOverviewCopy.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final controlWidth = constraints.maxWidth < 280
            ? constraints.maxWidth
            : 280.0;
        return Semantics(
          container: true,
          label: copy.workspaceTabs,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: controlWidth,
              child: Container(
                key: const Key('menu-workspace-tabs'),
                height: 42,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _WorkspaceTabButton(
                        tabKey: const Key('menu-workspace-tab-overview'),
                        label: copy.overview,
                        selected: selected == MenuWorkspaceTab.overview,
                        onPressed: () => onSelected(MenuWorkspaceTab.overview),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _WorkspaceTabButton(
                        tabKey: const Key('menu-workspace-tab-sections'),
                        label: copy.sections,
                        selected: selected == MenuWorkspaceTab.sections,
                        onPressed: () => onSelected(MenuWorkspaceTab.sections),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _WorkspaceTabButton(
                        tabKey: const Key('menu-workspace-tab-products'),
                        label: copy.products,
                        selected: selected == MenuWorkspaceTab.products,
                        onPressed: () => onSelected(MenuWorkspaceTab.products),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceTabButton extends StatelessWidget {
  const _WorkspaceTabButton({
    required this.tabKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final Key tabKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    key: tabKey,
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.navActiveBackground : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onPressed,
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? AppColors.navActiveText
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.menu, required this.onTab});
  final MenuRecord menu;
  final ValueChanged<MenuWorkspaceTab> onTab;

  @override
  Widget build(BuildContext context) {
    final copy = _MenuOverviewCopy.of(context);
    return Container(
      key: const Key('menu-overview-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.menuDetails,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            label: copy.name,
            value: menu.displayName(Localizations.localeOf(context)),
          ),
          _DetailRow(
            label: copy.status,
            valueWidget: _StatusPill(
              status: menu.isArchived ? 'archived' : menu.status,
              copy: copy,
            ),
          ),
          _DetailRow(
            label: copy.composition,
            value: copy.compositionValue(
              menu.sectionCount,
              menu.visibleProductCount,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  OutlinedButton(
                    key: const Key('menu-overview-manage-sections'),
                    onPressed: () => onTab(MenuWorkspaceTab.sections),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(copy.manageSections),
                  ),
                  OutlinedButton(
                    key: const Key('menu-overview-manage-products'),
                    onPressed: () => onTab(MenuWorkspaceTab.products),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(copy.manageProducts),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sections extends StatefulWidget {
  const _Sections({required this.menu, required this.state});
  final MenuRecord menu;
  final MenuDetailState state;

  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections> {
  bool _reorderMode = false;

  Future<void> _openEditor(MenuSectionRecord? section) => showMenuSectionEditor(
    context,
    section: section,
    onSubmit: (draft) => section == null
        ? context.read<MenuDetailCubit>().createSection(draft)
        : context.read<MenuDetailCubit>().updateSection(section.id, draft),
  );

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final state = widget.state;
    final l10n = context.l10n;
    final sections = [...menu.sections]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final reorderable = sections
        .where((section) => !section.isArchived)
        .toList();
    final cubit = context.read<MenuDetailCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: AppSpacing.md,
          spacing: AppSpacing.md,
          children: <Widget>[
            SizedBox(
              width: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _reorderMode
                        ? l10n.menuSectionsReorder
                        : l10n.menuSectionsTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _reorderMode
                        ? l10n.menuSectionsReorderHelp
                        : l10n.menuSectionsHelp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                if (_reorderMode)
                  OutlinedButton(
                    key: const Key('sections-reorder-done'),
                    onPressed: () => setState(() => _reorderMode = false),
                    child: Text(l10n.menuSectionsDone),
                  )
                else
                  OutlinedButton(
                    key: const Key('sections-reorder'),
                    onPressed:
                        menu.isArchived || state.isBusy || sections.length < 2
                        ? null
                        : () => setState(() => _reorderMode = true),
                    child: Text(l10n.menuSectionsReorder),
                  ),
                FilledButton.icon(
                  key: const Key('sections-add'),
                  onPressed: menu.isArchived || state.isBusy
                      ? null
                      : () => _openEditor(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.menuSectionsAdd),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (sections.isEmpty)
          _EmptySections(
            onAdd: menu.isArchived || state.isBusy
                ? null
                : () => _openEditor(null),
          )
        else
          Container(
            key: const Key('sections-list'),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < sections.length; index++)
                  _SectionRow(
                    section: sections[index],
                    index: index,
                    length: sections.length,
                    reorderIndex: reorderable.indexWhere(
                      (section) => section.id == sections[index].id,
                    ),
                    reorderLength: reorderable.length,
                    productCount: menu.placements.isEmpty
                        ? sections[index].placementCount
                        : menu.placements
                              .where((p) => p.sectionId == sections[index].id)
                              .length,
                    disabled: menu.isArchived || state.isBusy,
                    reorderMode: _reorderMode,
                    onEdit: () => _openEditor(sections[index]),
                    onMove: (delta) =>
                        cubit.moveSection(sections[index].id, delta),
                    onArchive: () => cubit.archiveSection(sections[index].id),
                    onRestore: () => cubit.restoreSection(sections[index].id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.index,
    required this.length,
    required this.reorderIndex,
    required this.reorderLength,
    required this.productCount,
    required this.disabled,
    required this.reorderMode,
    required this.onEdit,
    required this.onMove,
    required this.onArchive,
    required this.onRestore,
  });
  final MenuSectionRecord section;
  final int index, length, reorderIndex, reorderLength, productCount;
  final bool disabled;
  final bool reorderMode;
  final VoidCallback onEdit, onArchive, onRestore;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final primary = section.displayName(locale);
    final alternate = locale.languageCode == 'ar'
        ? section.nameEn
        : section.nameAr;
    final lifecycle = section.isArchived
        ? l10n.menuSectionsArchived
        : section.isInactive
        ? l10n.menuSectionsInactive
        : null;
    return Opacity(
      opacity: section.isArchived ? .62 : 1,
      child: Container(
        key: Key('section-row-${section.id}'),
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
        decoration: BoxDecoration(
          border: index == length - 1
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.folder_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (alternate.trim().isNotEmpty &&
                        alternate.trim() != primary.trim())
                      Text(
                        alternate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.menuSectionsProducts(productCount),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (lifecycle != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              _SectionLifecyclePill(label: lifecycle),
            ],
            const SizedBox(width: AppSpacing.xs),
            if (reorderMode && !section.isArchived) ...<Widget>[
              IconButton(
                key: Key('section-move-up-${section.id}'),
                tooltip: l10n.menuSectionsMoveUp,
                onPressed: disabled || reorderIndex == 0
                    ? null
                    : () => onMove(-1),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                key: Key('section-move-down-${section.id}'),
                tooltip: l10n.menuSectionsMoveDown,
                onPressed: disabled || reorderIndex == reorderLength - 1
                    ? null
                    : () => onMove(1),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
            ] else if (!reorderMode)
              PopupMenuButton<String>(
                key: Key('section-actions-${section.id}'),
                tooltip: l10n.menuSectionsActions(primary),
                enabled: !disabled,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'archive':
                      onArchive();
                      break;
                    case 'restore':
                      onRestore();
                      break;
                  }
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  if (!section.isArchived)
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l10n.menuSectionsEdit),
                    ),
                  PopupMenuItem(
                    value: section.isArchived ? 'restore' : 'archive',
                    child: Text(
                      section.isArchived
                          ? l10n.menuSectionsRestore
                          : l10n.menuSectionsArchive,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /* Legacy list-tile presentation retired in favor of the compact row above.
  Widget _legacy(BuildContext context) {
    final cubit = context.read<MenuDetailCubit>();
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(section.displayName(Localizations.localeOf(context))),
      subtitle: Text(
        '${section.placementCount} products · ${section.isArchived
            ? 'Archived'
            : section.isActive
            ? 'Active'
            : 'Inactive'}',
      ),
      trailing: Wrap(
        spacing: AppSpacing.xs,
        children: <Widget>[
          IconButton(
            tooltip: 'Move Up',
            onPressed: disabled || section.isArchived || index == 0
                ? null
                : () => cubit.moveSection(section.id, -1),
            icon: const Icon(Icons.arrow_upward),
          ),
          IconButton(
            tooltip: 'Move Down',
            onPressed: disabled || section.isArchived || index == length - 1
                ? null
                : () => cubit.moveSection(section.id, 1),
            icon: const Icon(Icons.arrow_downward),
          ),
          PopupMenuButton<String>(
            tooltip: 'Section actions',
            onSelected: disabled
                ? null
                : (value) async {
                    if (value == 'edit') {
                      final draft = await showMenuSectionEditor(
                        context,
                        section: section,
                      );
                      if (draft != null && context.mounted) {
                        await cubit.updateSection(section.id, draft);
                      }
                    }
                    if (value == 'archive') {
                      await cubit.archiveSection(section.id);
                    }
                    if (value == 'restore') {
                      await cubit.restoreSection(section.id);
                    }
                  },
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              if (!section.isArchived)
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: section.isArchived ? 'restore' : 'archive',
                child: Text(section.isArchived ? 'Restore' : 'Archive'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  */
}

class _SectionLifecyclePill extends StatelessWidget {
  const _SectionLifecyclePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.valueWidget})
    : assert(value != null || valueWidget != null);
  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child:
              valueWidget ??
              Text(
                value!,
                textAlign: TextAlign.end,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.copy});
  final String status;
  final _MenuOverviewCopy copy;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (status) {
      'active' => (AppColors.discountGreenBadge, AppColors.discountGreenText),
      'paused' => (AppColors.discountOrangeBadge, AppColors.discountOrangeText),
      'archived' => (AppColors.surfaceAlt, AppColors.textMuted),
      _ => (AppColors.discountOrangeBadge, AppColors.discountOrangeText),
    };
    return Semantics(
      label: '${copy.status}: ${copy.statusValue(status)}',
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          copy.statusValue(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.lg),
    child: _Message(_MenuOverviewCopy.of(context).archivedReadOnly),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message),
  );
}

class _EmptySections extends StatelessWidget {
  const _EmptySections({this.onAdd});
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('sections-empty'),
    width: double.infinity,
    padding: AppSpacing.allXxl,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.folder_off_outlined),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.menuSectionsNoSections,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.menuSectionsEmptyHelp,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.l10n.menuSectionsAdd),
        ),
      ],
    ),
  );
}

class _WorkspaceSkeleton extends StatelessWidget {
  const _WorkspaceSkeleton({required this.copy});
  final _MenuOverviewCopy copy;
  @override
  Widget build(BuildContext context) => Skeletonizer(
    child: SizedBox(
      width: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(copy.loading, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: AppSpacing.xl),
          const Card(child: SizedBox(height: 200)),
        ],
      ),
    ),
  );
}

class _SectionsWorkspaceSkeleton extends StatelessWidget {
  const _SectionsWorkspaceSkeleton();

  @override
  Widget build(BuildContext context) => Skeletonizer(
    child: SizedBox(
      width: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Sections', style: TextStyle(fontSize: 24)),
          const SizedBox(height: AppSpacing.xs),
          const Text('Organize this menu into customer-friendly groups.'),
          const SizedBox(height: AppSpacing.lg),
          Container(
            height: 178,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _confirmMenu(
  BuildContext context, {
  required bool restore,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(restore ? 'Restore menu?' : 'Archive menu?'),
        content: Text(
          restore
              ? 'Restoring this menu returns it to Draft. It does not restore archived sections.'
              : 'This archives the menu without deleting it. Its composition remains available to review.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(restore ? 'Restore' : 'Archive'),
          ),
        ],
      ),
    ) ??
    false;

String _alternateMenuName(MenuRecord menu, Locale locale, String primary) {
  final alternate = locale.languageCode == 'ar' ? menu.nameEn : menu.nameAr;
  return alternate.trim() == primary.trim() ? '' : alternate.trim();
}

class _MenuOverviewCopy {
  const _MenuOverviewCopy._(this.context);
  factory _MenuOverviewCopy.of(BuildContext context) =>
      _MenuOverviewCopy._(context);
  final BuildContext context;

  String get editMenu => context.maybeL10n?.menuOverviewEditMenu ?? 'Edit Menu';
  String get actions =>
      context.maybeL10n?.menuOverviewActions ?? 'Menu actions';
  String get overview => context.maybeL10n?.menuOverviewTab ?? 'Overview';
  String get sections =>
      context.maybeL10n?.menuOverviewSectionsTab ?? 'Sections';
  String get products =>
      context.maybeL10n?.menuOverviewProductsTab ?? 'Products';
  String get workspaceTabs =>
      context.maybeL10n?.menuOverviewWorkspaceTabs ?? 'Menu workspace tabs';
  String get menuDetails =>
      context.maybeL10n?.menuOverviewDetails ?? 'Menu details';
  String get name => context.maybeL10n?.menuOverviewName ?? 'Name';
  String get status => context.maybeL10n?.menuOverviewStatus ?? 'Status';
  String get composition =>
      context.maybeL10n?.menuOverviewComposition ?? 'Composition';
  String get manageSections =>
      context.maybeL10n?.menuOverviewManageSections ?? 'Manage Sections';
  String get manageProducts =>
      context.maybeL10n?.menuOverviewManageProducts ?? 'Manage Products';
  String compositionValue(int sectionCount, int visibleProductCount) =>
      context.maybeL10n?.menuOverviewCompositionValue(
        sectionCount,
        visibleProductCount,
      ) ??
      '$sectionCount Sections · $visibleProductCount visible Products';
  String get archivedReadOnly =>
      context.maybeL10n?.menuOverviewArchivedReadOnly ??
      'This menu is archived and read-only. Restore it before changing its composition.';
  String get loading =>
      context.maybeL10n?.menuOverviewLoading ?? 'Loading menu workspace';
  String get couldNotLoad =>
      context.maybeL10n?.menuOverviewCouldNotLoad ?? 'Couldn’t load this menu';
  String get retry => context.maybeL10n?.commonRetry ?? 'Retry';
  String statusValue(String value) => switch (value) {
    'draft' => context.maybeL10n?.menuOverviewDraft ?? 'Draft',
    'active' => context.maybeL10n?.menuOverviewActive ?? 'Active',
    'paused' => context.maybeL10n?.menuOverviewPaused ?? 'Paused',
    'archived' => context.maybeL10n?.menuOverviewArchived ?? 'Archived',
    _ => context.maybeL10n?.menuOverviewDraft ?? 'Draft',
  };
  String get archive => context.maybeL10n?.menuOverviewArchive ?? 'Archive';
  String get restore => context.maybeL10n?.menuOverviewRestore ?? 'Restore';
}

/// Compatibility accessors for the new ARB entries while Flutter's generated
/// localization source is refreshed. Once `gen-l10n` writes the entries, the
/// generated instance members take precedence over these extension members.
/*
extension _MenuSectionLocalizations on AppLocalizations {
  bool get _ar => localeName.startsWith('ar');
  String get menuSectionsTitle => _ar ? 'الأقسام' : 'Sections';
  String get menuSectionsHelp => _ar
      ? 'نظّم هذه القائمة ضمن مجموعات يسهل على العميل تصفحها.'
      : 'Organize this menu into customer-friendly groups.';
  String get menuSectionsAdd => _ar ? 'إضافة قسم' : 'Add Section';
  String get menuSectionsReorder => _ar ? 'ترتيب الأقسام' : 'Reorder Sections';
  String get menuSectionsDone => _ar ? 'تم' : 'Done';
  String get menuSectionsReorderHelp => _ar
      ? 'استخدم الأسهم لتغيير الترتيب الذي يراه العملاء.'
      : 'Use the arrows to change the order customers see.';
  String menuSectionsProducts(int count) =>
      _ar ? '$count منتجات' : '$count Products';
  String get menuSectionsArchived => _ar ? 'مؤرشف' : 'Archived';
  String get menuSectionsInactive => _ar ? 'غير نشط' : 'Inactive';
  String menuSectionsActions(String name) =>
      _ar ? 'إجراءات $name' : 'Actions for $name';
  String get menuSectionsEdit => _ar ? 'تعديل' : 'Edit';
  String get menuSectionsArchive => _ar ? 'أرشفة' : 'Archive';
  String get menuSectionsRestore => _ar ? 'استعادة' : 'Restore';
  String get menuSectionsMoveUp => _ar ? 'نقل للأعلى' : 'Move Up';
  String get menuSectionsMoveDown => _ar ? 'نقل للأسفل' : 'Move Down';
  String get menuSectionsNoSections =>
      _ar ? 'لا توجد أقسام بعد' : 'No Sections yet';
  String get menuSectionsEmptyHelp => _ar
      ? 'أنشئ قسمًا قبل إضافة المنتجات.'
      : 'Create a Section before adding Products.';
  String get menuSectionsLoadError =>
      _ar ? 'تعذر تحميل الأقسام' : 'Couldn’t load Sections';
  String get menuSectionEditorAddTitle => _ar ? 'إضافة قسم' : 'Add Section';
  String get menuSectionEditorEditTitle => _ar ? 'تعديل القسم' : 'Edit Section';
  String get menuSectionEditorAddHelp => _ar
      ? 'أنشئ مجموعة واضحة يمكن للعملاء تصفحها.'
      : 'Create a clear group customers can browse.';
  String get menuSectionEditorEditHelp => _ar
      ? 'حدّث هذه المجموعة دون مغادرة مساحة عمل القائمة.'
      : 'Update this group without leaving the menu workspace.';
  String get menuSectionEditorClose =>
      _ar ? 'إغلاق محرر القسم' : 'Close Section editor';
  String get menuSectionEditorEnglishName =>
      _ar ? 'الاسم بالإنجليزية' : 'English Name';
  String get menuSectionEditorArabicName =>
      _ar ? 'الاسم بالعربية' : 'Arabic Name';
  String get menuSectionEditorMoreDetails =>
      _ar ? 'تفاصيل أكثر' : 'More details';
  String get menuSectionEditorHideDetails =>
      _ar ? 'إخفاء التفاصيل' : 'Hide details';
  String get menuSectionEditorDescription => _ar ? 'الوصف' : 'Description';
  String get menuSectionEditorImageUrl => _ar ? 'رابط الصورة' : 'Image URL';
  String get menuSectionEditorActive => _ar ? 'قسم نشط' : 'Active Section';
  String get menuSectionEditorNameRequired => _ar
      ? 'أدخل اسمًا بالإنجليزية أو العربية للمتابعة.'
      : 'Enter an English or Arabic name to continue.';
  String get menuSectionEditorSaveFailed => _ar
      ? 'تعذر حفظ هذا القسم. راجع الحقول وحاول مرة أخرى.'
      : 'Couldn’t save this Section. Check the fields and try again.';
  String get menuSectionEditorSave => _ar ? 'حفظ التغييرات' : 'Save Changes';
}
*/

Future<void> showMenuSectionEditor(
  BuildContext context, {
  MenuSectionRecord? section,
  required Future<void> Function(MenuSectionDraft draft) onSubmit,
}) {
  final bool rtl = Directionality.of(context) == TextDirection.rtl;
  final MenuDetailCubit detailCubit = context.read<MenuDetailCubit>();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.menuSectionEditorClose,
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => BlocProvider<MenuDetailCubit>.value(
      value: detailCubit,
      child: _SectionEditor(section: section, onSubmit: onSubmit),
    ),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: Offset(rtl ? -.08 : .08, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _SectionEditor extends StatefulWidget {
  const _SectionEditor({this.section, required this.onSubmit});
  final MenuSectionRecord? section;
  final Future<void> Function(MenuSectionDraft draft) onSubmit;
  @override
  State<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<_SectionEditor> {
  late final _en = TextEditingController(
    text: widget.section == null
        ? ''
        : widget.section!.nameEn.isNotEmpty
        ? widget.section!.nameEn
        : widget.section!.name,
  );
  late final _ar = TextEditingController(text: widget.section?.nameAr ?? '');
  late final _description = TextEditingController(
    text: widget.section?.description ?? '',
  );
  late final _imageUrl = TextEditingController(
    text: widget.section?.imageUrl ?? '',
  );
  bool _showDetails = false;
  bool _active = true;
  bool _saving = false;
  String? _nameError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _active = widget.section?.isActive ?? true;
  }

  @override
  void dispose() {
    _en.dispose();
    _ar.dispose();
    _description.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = widget.section != null;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        color: AppColors.surface,
        child: SafeArea(
          child: SizedBox(
            key: const Key('section-editor-sheet'),
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: AppSpacing.allLg,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              editing
                                  ? l10n.menuSectionEditorEditTitle
                                  : l10n.menuSectionEditorAddTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              editing
                                  ? l10n.menuSectionEditorEditHelp
                                  : l10n.menuSectionEditorAddHelp,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('section-editor-close'),
                        tooltip: l10n.menuSectionEditorClose,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.allLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextField(
                          key: const Key('section-editor-name-en'),
                          controller: _en,
                          enabled: !_saving,
                          onChanged: (_) => setState(() {
                            _nameError = null;
                            _saveError = null;
                          }),
                          decoration: InputDecoration(
                            labelText: l10n.menuSectionEditorEnglishName,
                            errorText: _nameError,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          key: const Key('section-editor-name-ar'),
                          controller: _ar,
                          enabled: !_saving,
                          textDirection: TextDirection.rtl,
                          onChanged: (_) => setState(() {
                            _nameError = null;
                            _saveError = null;
                          }),
                          decoration: InputDecoration(
                            labelText: l10n.menuSectionEditorArabicName,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton.icon(
                          key: const Key('section-editor-more-details'),
                          onPressed: _saving
                              ? null
                              : () => setState(
                                  () => _showDetails = !_showDetails,
                                ),
                          icon: Icon(
                            _showDetails
                                ? Icons.expand_less_outlined
                                : Icons.expand_more_outlined,
                          ),
                          label: Text(
                            _showDetails
                                ? l10n.menuSectionEditorHideDetails
                                : l10n.menuSectionEditorMoreDetails,
                          ),
                        ),
                        if (_showDetails) ...<Widget>[
                          const Divider(height: AppSpacing.xxl),
                          TextField(
                            key: const Key('section-editor-description'),
                            controller: _description,
                            enabled: !_saving,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: l10n.menuSectionEditorDescription,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            key: const Key('section-editor-image-url'),
                            controller: _imageUrl,
                            enabled: !_saving,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              labelText: l10n.menuSectionEditorImageUrl,
                            ),
                          ),
                          if (editing) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            SwitchListTile.adaptive(
                              key: const Key('section-editor-active'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.menuSectionEditorActive),
                              value: _active,
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(() => _active = value),
                            ),
                          ],
                        ],
                        if (_saveError != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            _saveError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(l10n.commonCancel),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            key: const Key('section-editor-save'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                            ),
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    editing
                                        ? l10n.menuSectionEditorSave
                                        : l10n.menuSectionsAdd,
                                    maxLines: 1,
                                    softWrap: false,
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
  }

  Future<void> _submit() async {
    if (_saving) return;
    final draft = const MenuSectionDraft()
        .withLocalizedNames(english: _en.text.trim(), arabic: _ar.text.trim())
        .copyWith(
          description: _description.text.trim(),
          imageUrl: _imageUrl.text.trim(),
          isActive: _active,
          sortOrder: widget.section?.sortOrder.toString() ?? '',
        );
    if (draft.name.trim().isEmpty) {
      setState(() => _nameError = context.l10n.menuSectionEditorNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    await widget.onSubmit(draft);
    if (!mounted) return;
    final state = context.read<MenuDetailCubit>().state;
    if (state.errorMessage != null) {
      setState(() {
        _saving = false;
        _nameError =
            state.sectionFieldErrors['name'] ??
            state.sectionFieldErrors['nameEn'];
        _saveError = _nameError == null
            ? context.l10n.menuSectionEditorSaveFailed
            : null;
      });
      return;
    }
    Navigator.of(context).pop();
  }
}
