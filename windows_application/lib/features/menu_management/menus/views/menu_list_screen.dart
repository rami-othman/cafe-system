import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/menu_list_cubit.dart';
import '../controllers/menu_editor_cubit.dart';
import '../models/menu_filter.dart';
import '../models/menu_models.dart';
import 'menu_editor_screen.dart';

class MenuListScreen extends StatefulWidget {
  const MenuListScreen({super.key, this.createEditorCubit});
  final MenuEditorCubit Function()? createEditorCubit;

  @override
  State<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends State<MenuListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MenuListCubit>().load(),
    );
  }

  Future<void> _openEditor([int? menuId]) async {
    final result = await showMenuEditorSheet(
      context,
      menuId: menuId,
      cubit: widget.createEditorCubit?.call(),
    );
    if (result != null && mounted) context.read<MenuListCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<MenuListCubit, MenuListState>(
        builder: (context, state) {
          final _MenuListCopy copy = _MenuListCopy.of(context);
          final MenuListCubit cubit = context.read<MenuListCubit>();
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 96),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _PageHeader(copy: copy, onAdd: _openEditor),
                      const SizedBox(height: AppSpacing.xl),
                      _MenuListPanel(
                        state: state,
                        cubit: cubit,
                        copy: copy,
                        onEdit: _openEditor,
                        onAdd: _openEditor,
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

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.copy, required this.onAdd});
  final _MenuListCopy copy;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(copy.title, style: AppTextStyles.headlineLarge),
            const SizedBox(height: 4),
            Text(
              copy.subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: AppSpacing.lg),
      FilledButton.icon(
        key: const Key('menu-list-add'),
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 18),
        label: Text(copy.addMenu),
      ),
    ],
  );
}

class _MenuListPanel extends StatelessWidget {
  const _MenuListPanel({
    required this.state,
    required this.cubit,
    required this.copy,
    required this.onEdit,
    required this.onAdd,
  });
  final MenuListState state;
  final MenuListCubit cubit;
  final _MenuListCopy copy;
  final ValueChanged<int> onEdit;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _Toolbar(state: state, cubit: cubit, copy: copy),
        ),
        const Divider(height: 1, color: AppColors.divider),
        if (state.status == MenuListStatus.loading && state.menus.isEmpty)
          _Skeleton(copy: copy)
        else if (state.status == MenuListStatus.failure && state.menus.isEmpty)
          _ErrorState(copy: copy, retry: cubit.load)
        else if (state.menus.isEmpty)
          _EmptyState(
            copy: copy,
            filtered: state.filter.hasActiveFilters,
            onClear: () => cubit.updateFilter(const MenuFilter()),
            onAdd: onAdd,
          )
        else ...<Widget>[
          _Table(
            menus: state.menus,
            busyId: state.currentActionId,
            copy: copy,
            onArchive: (id) => _confirmMenu(
              context,
              archive: true,
              action: () => cubit.archive(id),
            ),
            onRestore: (id) => _confirmMenu(
              context,
              archive: false,
              action: () => cubit.restore(id),
            ),
            onEdit: onEdit,
          ),
          if (state.status == MenuListStatus.failure)
            _InlineError(copy: copy, retry: cubit.load),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: OutlinedButton(
                onPressed: state.isBusy ? null : () => cubit.load(next: true),
                child: Text(copy.loadMore),
              ),
            ),
        ],
      ],
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.state,
    required this.cubit,
    required this.copy,
  });
  final MenuListState state;
  final MenuListCubit cubit;
  final _MenuListCopy copy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bool stacks = constraints.maxWidth < 760;
      final List<Widget> controls = <Widget>[
        _Dropdown(
          key: const Key('menu-list-status'),
          width: stacks ? 260 : 150,
          value: state.filter.status,
          semanticLabel: copy.status,
          labels: copy.statusValue,
          selectedLabel: (value) =>
              '${copy.status}: ${copy.statusValue(value)}',
          values: const <String>[
            'all',
            'draft',
            'active',
            'paused',
            'archived',
          ],
          onChanged: (value) =>
              cubit.updateFilter(state.filter.copyWith(status: value)),
        ),
        _Dropdown(
          key: const Key('menu-list-sort'),
          width: stacks ? 260 : 150,
          value: state.filter.sort,
          semanticLabel: copy.sort,
          labels: copy.sortValue,
          selectedLabel: (value) => '${copy.sort}: ${copy.sortValue(value)}',
          values: const <String>[
            'priority',
            'name',
            'created_at',
            'updated_at',
          ],
          onChanged: (value) =>
              cubit.updateFilter(state.filter.copyWith(sort: value)),
        ),
        _Dropdown(
          key: const Key('menu-list-direction'),
          width: stacks ? 260 : 130,
          value: state.filter.direction,
          semanticLabel: copy.direction,
          labels: copy.directionValue,
          selectedLabel: copy.directionValue,
          values: const <String>['asc', 'desc'],
          onChanged: (value) =>
              cubit.updateFilter(state.filter.copyWith(direction: value)),
        ),
      ];
      final Widget search = TextField(
        key: const Key('menu-list-search'),
        onChanged: cubit.updateSearch,
        decoration: InputDecoration(
          hintText: copy.search,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: const OutlineInputBorder(),
        ),
      );
      if (stacks) {
        return Column(
          children: <Widget>[
            search,
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: controls,
            ),
          ],
        );
      }
      return Row(
        children: <Widget>[
          Expanded(child: search),
          const SizedBox(width: AppSpacing.sm),
          for (var i = 0; i < controls.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            controls[i],
          ],
        ],
      );
    },
  );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required super.key,
    required this.width,
    required this.value,
    required this.semanticLabel,
    required this.labels,
    required this.selectedLabel,
    required this.values,
    required this.onChanged,
  });
  final double width;
  final String value;
  final String semanticLabel;
  final String Function(String) labels;
  final String Function(String) selectedLabel;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 42,
    child: Semantics(
      label: semanticLabel,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
          border: OutlineInputBorder(),
        ),
        selectedItemBuilder: (context) => values
            .map(
              (item) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  selectedLabel(item),
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium,
                ),
              ),
            )
            .toList(),
        items: values
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(labels(item)),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table({
    required this.menus,
    required this.busyId,
    required this.copy,
    required this.onArchive,
    required this.onRestore,
    required this.onEdit,
  });
  final List<MenuRecord> menus;
  final int? busyId;
  final _MenuListCopy copy;
  final ValueChanged<int> onArchive;
  final ValueChanged<int> onRestore;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      _TableLine(
        header: true,
        cells: <Widget>[
          _Cell(flex: 29, child: Text(copy.menu)),
          _Cell(flex: 16, child: Text(copy.status)),
          _Cell(flex: 10, number: true, child: Text(copy.sections)),
          _Cell(
            flex: 20,
            number: true,
            child: Text(
              copy.visibleProducts,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _Cell(
            flex: 26,
            child: Text(
              copy.lastUpdated,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _Cell(flex: 17, child: Text(copy.actions)),
        ],
      ),
      for (final menu in menus)
        _MenuRow(
          menu: menu,
          busy: busyId != null,
          copy: copy,
          onArchive: () => onArchive(menu.id),
          onRestore: () => onRestore(menu.id),
          onEdit: () => onEdit(menu.id),
        ),
    ],
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.menu,
    required this.busy,
    required this.copy,
    required this.onArchive,
    required this.onRestore,
    required this.onEdit,
  });
  final MenuRecord menu;
  final bool busy;
  final _MenuListCopy copy;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final Locale locale = Localizations.localeOf(context);
    final String primary = menu.displayName(locale);
    final String secondary = _alternateName(menu, locale, primary);
    return Opacity(
      opacity: menu.isArchived ? .6 : 1,
      child: Material(
        color: menu.isArchived
            ? AppColors.contentBackground
            : AppColors.surface,
        child: InkWell(
          onTap: () => context.go('/menu-management/menus/${menu.id}'),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: _TableLine(
              cells: <Widget>[
                _Cell(
                  flex: 29,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        primary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textDark,
                        ),
                      ),
                      if (secondary.isNotEmpty)
                        Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall,
                        ),
                    ],
                  ),
                ),
                _Cell(
                  flex: 16,
                  child: _StatusPill(status: menu.status, copy: copy),
                ),
                _Cell(
                  flex: 10,
                  number: true,
                  child: Text('${menu.sectionCount}'),
                ),
                _Cell(
                  flex: 20,
                  number: true,
                  child: Text('${menu.visibleProductCount}'),
                ),
                _Cell(
                  flex: 26,
                  child: Text(
                    _date(menu.updatedAt, locale, copy.notAvailable),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _Cell(
                  flex: 17,
                  child: _Actions(
                    menu: menu,
                    busy: busy,
                    copy: copy,
                    onArchive: onArchive,
                    onRestore: onRestore,
                    onEdit: onEdit,
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

class _TableLine extends StatelessWidget {
  const _TableLine({this.header = false, required this.cells});
  final bool header;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Container(
    height: header ? 42 : 64,
    color: header ? AppColors.menuTableHeader : null,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
    child: Row(children: cells),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.flex, required this.child, this.number = false});
  final int flex;
  final Widget child;
  final bool number;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Align(
      alignment: number
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
        child: DefaultTextStyle.merge(
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.copy});
  final String status;
  final _MenuListCopy copy;

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
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          copy.statusValue(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.menu,
    required this.busy,
    required this.copy,
    required this.onArchive,
    required this.onRestore,
    required this.onEdit,
  });
  final MenuRecord menu;
  final bool busy;
  final _MenuListCopy copy;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Tooltip(
        message: copy.open,
        child: Semantics(
          label: copy.open,
          button: true,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => context.go('/menu-management/menus/${menu.id}'),
            icon: const Icon(Icons.open_in_new_outlined, size: 18),
          ),
        ),
      ),
      PopupMenuButton<_MenuAction>(
        tooltip: copy.actionsFor(
          menu.displayName(Localizations.localeOf(context)),
        ),
        enabled: !busy,
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.more_horiz, size: 20),
        onSelected: (action) {
          switch (action) {
            case _MenuAction.edit:
              onEdit();
            case _MenuAction.archive:
              onArchive();
            case _MenuAction.restore:
              onRestore();
          }
        },
        itemBuilder: (context) => <PopupMenuEntry<_MenuAction>>[
          if (!menu.isArchived)
            PopupMenuItem(value: _MenuAction.edit, child: Text(copy.edit)),
          PopupMenuItem(
            value: menu.isArchived ? _MenuAction.restore : _MenuAction.archive,
            child: Text(menu.isArchived ? copy.restore : copy.archive),
          ),
        ],
      ),
    ],
  );
}

enum _MenuAction { edit, archive, restore }

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.copy});
  final _MenuListCopy copy;

  @override
  Widget build(BuildContext context) => Skeletonizer(
    child: Column(
      children: <Widget>[
        _TableLine(
          header: true,
          cells: <Widget>[
            _Cell(flex: 29, child: Text(copy.menu)),
            _Cell(flex: 16, child: Text(copy.status)),
            _Cell(flex: 10, number: true, child: Text(copy.sections)),
            _Cell(flex: 20, number: true, child: Text(copy.visibleProducts)),
            _Cell(flex: 26, child: Text(copy.lastUpdated)),
            _Cell(flex: 17, child: Text(copy.actions)),
          ],
        ),
        for (var index = 0; index < 4; index++)
          _TableLine(
            cells: <Widget>[
              _Cell(flex: 29, child: Text('Main menu $index')),
              _Cell(flex: 16, child: Text(copy.statusValue('active'))),
              _Cell(flex: 10, number: true, child: const Text('3')),
              _Cell(flex: 20, number: true, child: const Text('12')),
              _Cell(flex: 26, child: const Text('Aug 20, 2026 6:10 PM')),
              _Cell(flex: 17, child: const Icon(Icons.more_horiz)),
            ],
          ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.copy,
    required this.filtered,
    required this.onClear,
    required this.onAdd,
  });
  final _MenuListCopy copy;
  final bool filtered;
  final VoidCallback onClear;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 58,
      horizontal: AppSpacing.xl,
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            filtered ? Icons.search_off_outlined : Icons.menu_book_outlined,
            size: 34,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            filtered ? copy.noMatches : copy.noMenusYet,
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            filtered ? copy.noMatchesHelp : copy.noMenusHelp,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (filtered)
            TextButton(onPressed: onClear, child: Text(copy.clearFilters))
          else
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(copy.addMenu),
            ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.copy, required this.retry});
  final _MenuListCopy copy;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 58,
      horizontal: AppSpacing.xl,
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_outlined,
            size: 36,
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(copy.couldNotLoad, style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            copy.couldNotLoadHelp,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: retry, child: Text(copy.retry)),
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.copy, required this.retry});
  final _MenuListCopy copy;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Row(
      children: <Widget>[
        const Icon(Icons.info_outline, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(copy.couldNotLoad, style: AppTextStyles.bodySmall),
        ),
        TextButton(onPressed: retry, child: Text(copy.retry)),
      ],
    ),
  );
}

String _alternateName(MenuRecord menu, Locale locale, String primary) {
  final String alternate = locale.languageCode == 'ar'
      ? menu.nameEn
      : menu.nameAr;
  return alternate.trim() == primary.trim() ? '' : alternate.trim();
}

String _date(DateTime? value, Locale locale, String unavailable) =>
    value == null
    ? unavailable
    : DateFormat.yMMMd(locale.toString()).add_jm().format(value);

Future<void> _confirmMenu(
  BuildContext context, {
  required bool archive,
  required Future<void> Function() action,
}) async {
  final _MenuListCopy copy = _MenuListCopy.of(context);
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(archive ? copy.archiveTitle : copy.restoreTitle),
      content: Text(archive ? copy.archiveHelp : copy.restoreHelp),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(copy.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(archive ? copy.archive : copy.restore),
        ),
      ],
    ),
  );
  if (yes == true) await action();
}

class _MenuListCopy {
  const _MenuListCopy._(this.context);
  factory _MenuListCopy.of(BuildContext context) => _MenuListCopy._(context);
  final BuildContext context;
  String get title => context.maybeL10n?.menuListTitle ?? 'Menus';
  String get subtitle =>
      context.maybeL10n?.menuListSubtitle ??
      'Create and organize the menus customers can order from.';
  String get addMenu => context.maybeL10n?.menuListAdd ?? 'Add Menu';
  String get search => context.maybeL10n?.menuListSearch ?? 'Search menus...';
  String get status => context.maybeL10n?.menuListStatus ?? 'Status';
  String get sort => context.maybeL10n?.menuListSort ?? 'Sort';
  String get direction => context.maybeL10n?.menuListDirection ?? 'Direction';
  String get refresh => context.maybeL10n?.menuListRefresh ?? 'Refresh menus';
  String get menu => context.maybeL10n?.menuListMenu ?? 'Menu';
  String get sections => context.maybeL10n?.menuListSections ?? 'Sections';
  String get visibleProducts =>
      context.maybeL10n?.menuListVisibleProducts ?? 'Visible Products';
  String get lastUpdated =>
      context.maybeL10n?.menuListLastUpdated ?? 'Last Updated';
  String get actions => context.maybeL10n?.menuListActions ?? 'Actions';
  String get open => context.maybeL10n?.menuListOpen ?? 'Open';
  String get edit => context.maybeL10n?.menuListEdit ?? 'Edit';
  String get archive => context.maybeL10n?.menuListArchive ?? 'Archive';
  String get restore => context.maybeL10n?.menuListRestore ?? 'Restore';
  String get cancel => context.maybeL10n?.menuListCancel ?? 'Cancel';
  String get clearFilters =>
      context.maybeL10n?.menuListClearFilters ?? 'Clear filters';
  String get noMenusYet =>
      context.maybeL10n?.menuListNoMenusYet ?? 'No menus yet';
  String get noMenusHelp =>
      context.maybeL10n?.menuListNoMenusHelp ??
      'Create your first Menu and start organizing Products into Sections.';
  String get noMatches =>
      context.maybeL10n?.menuListNoMatches ?? 'No menus match these filters.';
  String get noMatchesHelp =>
      context.maybeL10n?.menuListNoMatchesHelp ??
      'Try changing the search or status filter.';
  String get couldNotLoad =>
      context.maybeL10n?.menuListCouldNotLoad ?? 'Couldn’t load menus';
  String get couldNotLoadHelp =>
      context.maybeL10n?.menuListCouldNotLoadHelp ??
      'Check your connection and try again.';
  String get retry => context.maybeL10n?.menuListRetry ?? 'Retry';
  String get loadMore => context.maybeL10n?.menuListLoadMore ?? 'Load more';
  String get notAvailable => context.maybeL10n?.menuListNotAvailable ?? '—';
  String get archiveTitle =>
      context.maybeL10n?.menuListArchiveTitle ?? 'Archive menu?';
  String get archiveHelp =>
      context.maybeL10n?.menuListArchiveHelp ??
      'The menu can be restored later. Existing orders and published versions are unchanged.';
  String get restoreTitle =>
      context.maybeL10n?.menuListRestoreTitle ?? 'Restore menu?';
  String get restoreHelp =>
      context.maybeL10n?.menuListRestoreHelp ??
      'Restoring makes the menu editable again. It does not publish the menu.';
  String actionsFor(String name) =>
      context.maybeL10n?.menuListActionsFor(name) ?? 'Actions for $name';
  String statusValue(String value) => switch (value) {
    'all' => context.maybeL10n?.menuListAll ?? 'All',
    'draft' => context.maybeL10n?.menuListDraft ?? 'Draft',
    'active' => context.maybeL10n?.menuListActive ?? 'Active',
    'paused' => context.maybeL10n?.menuListPaused ?? 'Paused',
    'archived' => context.maybeL10n?.menuListArchived ?? 'Archived',
    _ => value,
  };
  String sortValue(String value) => switch (value) {
    'priority' => context.maybeL10n?.menuListPriority ?? 'Priority',
    'name' => context.maybeL10n?.menuListName ?? 'Name',
    'created_at' => context.maybeL10n?.menuListCreated ?? 'Created',
    'updated_at' => context.maybeL10n?.menuListUpdated ?? 'Last updated',
    _ => value,
  };
  String directionValue(String value) => value == 'desc'
      ? (context.maybeL10n?.menuListDescending ?? 'Descending')
      : (context.maybeL10n?.menuListAscending ?? 'Ascending');
}
