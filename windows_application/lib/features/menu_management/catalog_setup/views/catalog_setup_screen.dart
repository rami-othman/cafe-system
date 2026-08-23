import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/catalog_setup_cubit.dart';
import '../models/catalog_setup_models.dart';

class CatalogSetupScreen extends StatefulWidget {
  const CatalogSetupScreen({super.key, required this.initialKind});
  final CatalogSetupKind initialKind;
  @override
  State<CatalogSetupScreen> createState() => _CatalogSetupScreenState();
}

class _CatalogSetupScreenState extends State<CatalogSetupScreen> {
  final _search = TextEditingController();
  String _searchDraft = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CatalogSetupCubit>().initialize(widget.initialKind),
    );
  }

  @override
  void didUpdateWidget(covariant CatalogSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialKind != widget.initialKind) {
      context.read<CatalogSetupCubit>().selectKind(widget.initialKind);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CatalogSetupCubit, CatalogSetupState>(
    listener: (context, state) {
      if (_search.text != state.search) {
        _search.value = TextEditingValue(
          text: state.search,
          selection: TextSelection.collapsed(offset: state.search.length),
        );
      }
      if (state.message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!)));
      }
    },
    builder: (context, state) {
      final l10n = context.l10n;
      final cubit = context.read<CatalogSetupCubit>();
      return DesktopPageLayout(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.catalogSetupTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.catalogSetupWorkspaceHelp,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _title(l10n, state.kind),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_purpose(l10n, state.kind)),
                      if (state.kind == CatalogSetupKind.reportingCategories)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            l10n.catalogSetupReportingNote,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: CatalogSetupKind.values
                            .map(
                              (kind) => ChoiceChip(
                                label: Text(_title(l10n, kind)),
                                selected: kind == state.kind,
                                onSelected: (_) => _selectKind(kind),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: kind == state.kind
                                      ? AppColors.textInverse
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _ManagementPanel(
                    state: state,
                    search: _search,
                    searchHint: _searchHint(l10n, state.kind),
                    entity: _singular(l10n, state.kind),
                    onSearch: _onSearch,
                    onStatus: cubit.setStatus,
                    onRefresh: cubit.load,
                    onAdd: () => _openEditor(),
                    onEdit: (record) => _openEditor(record),
                    onArchive: _confirmArchive,
                    onRestore: cubit.restore,
                    onMove: cubit.move,
                    emptyTitle: _emptyTitle(l10n, state.kind),
                    emptyHelp: _emptyHelp(l10n, state.kind),
                    onRetry: cubit.load,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  void _selectKind(CatalogSetupKind kind) {
    if (GoRouter.maybeOf(context) == null) {
      context.read<CatalogSetupCubit>().selectKind(kind);
      return;
    }
    context.go('/menu-management/catalog-setup?tab=${kind.queryValue}');
  }

  void _onSearch(String value) {
    _searchDraft = value;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _searchDraft == value) {
        context.read<CatalogSetupCubit>().setSearch(value);
      }
    });
  }

  Future<void> _openEditor([CatalogSetupRecord? record]) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.commonCancel,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, primaryAnimation, secondaryAnimation) =>
          BlocProvider.value(
            value: context.read<CatalogSetupCubit>(),
            child: _CatalogSetupEditorSheet(record: record),
          ),
      transitionBuilder:
          (dialogContext, animation, secondaryAnimation, child) =>
              SlideTransition(
                position:
                    Tween<Offset>(
                      begin: Offset(rtl ? -.08 : .08, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                child: FadeTransition(opacity: animation, child: child),
              ),
    );
  }

  Future<void> _confirmArchive(CatalogSetupRecord record) async {
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l10n.catalogSetupArchiveTitle(
            record.displayName(Localizations.localeOf(context)),
          ),
        ),
        content: Text(l10n.catalogSetupArchiveHelp),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              l10n.catalogSetupArchive(
                _singular(l10n, context.read<CatalogSetupCubit>().state.kind),
              ),
            ),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await context.read<CatalogSetupCubit>().archive(record.id);
    }
  }
}

class _ManagementPanel extends StatelessWidget {
  const _ManagementPanel({
    required this.state,
    required this.search,
    required this.searchHint,
    required this.entity,
    required this.onSearch,
    required this.onStatus,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onMove,
    required this.emptyTitle,
    required this.emptyHelp,
    required this.onRetry,
  });
  final CatalogSetupState state;
  final TextEditingController search;
  final String searchHint, entity, emptyTitle, emptyHelp;
  final ValueChanged<String> onSearch;
  final ValueChanged<CatalogSetupStatus> onStatus;
  final VoidCallback onRefresh, onAdd, onRetry;
  final ValueChanged<CatalogSetupRecord> onEdit, onArchive;
  final ValueChanged<int> onRestore;
  final void Function(int, int) onMove;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initialLoading =
        state.page == null &&
        state.requestStatus == CatalogSetupRequestStatus.loading;
    final initialFailure =
        state.page == null &&
        state.requestStatus == CatalogSetupRequestStatus.failure;
    final refreshing =
        state.page != null &&
        state.requestStatus == CatalogSetupRequestStatus.loading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final controls = <Widget>[
                SizedBox(
                  key: const Key('catalog-setup-status-filter'),
                  width: 154,
                  child: _StatusFilter(
                    value: state.status,
                    enabled: !state.isBusy,
                    onChanged: onStatus,
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: Tooltip(
                    message: l10n.commonRefresh,
                    child: OutlinedButton.icon(
                      onPressed: state.isBusy ? null : onRefresh,
                      icon: refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(l10n.commonRefresh),
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: state.isBusy ? null : onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.catalogSetupAdd(entity)),
                  ),
                ),
              ];
              final searchField = SizedBox(
                height: 42,
                child: TextField(
                  controller: search,
                  enabled: !state.isBusy || state.page != null,
                  onChanged: onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              );

              if (constraints.maxWidth >= 760) {
                return Row(
                  key: const Key('catalog-setup-toolbar-row'),
                  children: <Widget>[
                    Expanded(child: searchField),
                    const SizedBox(width: AppSpacing.sm),
                    ...controls
                        .expand(
                          (control) => <Widget>[
                            control,
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        )
                        .toList()
                      ..removeLast(),
                  ],
                );
              }
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  SizedBox(width: constraints.maxWidth, child: searchField),
                  ...controls,
                ],
              );
            },
          ),
        ),
        if (refreshing) const LinearProgressIndicator(minHeight: 2),
        const Divider(height: 1),
        if (initialLoading)
          const _CatalogSetupSkeleton()
        else if (initialFailure)
          _LoadFailure(onRetry: onRetry)
        else if (state.page == null || state.page!.items.isEmpty)
          _EmptyState(title: emptyTitle, help: emptyHelp, onAdd: onAdd)
        else
          _RecordList(
            state: state,
            onEdit: onEdit,
            onArchive: onArchive,
            onRestore: onRestore,
            onMove: onMove,
          ),
        if (state.page != null)
          _Pagination(
            state: state,
            onPage: (page) =>
                context.read<CatalogSetupCubit>().load(page: page),
          ),
      ],
    );
  }
}

class _CatalogSetupSkeleton extends StatelessWidget {
  const _CatalogSetupSkeleton();
  @override
  Widget build(BuildContext context) => Skeletonizer(
    key: const Key('catalog-setup-skeleton'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _ListHeader(),
        ListView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: catalogSetupPageSize,
          itemBuilder: (context, index) =>
              const _RecordRow(item: _skeletonRecord, index: 0, count: 5),
        ),
      ],
    ),
  );
}

const _skeletonRecord = CatalogSetupRecord(
  id: 0,
  name: 'Catalog item name',
  nameAr: '',
  nameEn: '',
  description: '',
  code: '',
  printerName: '',
  branchId: null,
  isActive: true,
  isArchived: false,
  sortOrder: 0,
  productCount: 12,
);

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final CatalogSetupStatus value;
  final bool enabled;
  final ValueChanged<CatalogSetupStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DropdownButtonFormField<CatalogSetupStatus>(
      key: ValueKey<CatalogSetupStatus>(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      selectedItemBuilder: (context) => CatalogSetupStatus.values
          .map(
            (status) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${l10n.menuPublishStatus}: ${_statusLabel(l10n, status)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      items: CatalogSetupStatus.values
          .map(
            (status) => DropdownMenuItem(
              value: status,
              child: Text(_statusLabel(l10n, status)),
            ),
          )
          .toList(growable: false),
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null,
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({
    required this.state,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onMove,
  });
  final CatalogSetupState state;
  final ValueChanged<CatalogSetupRecord> onEdit, onArchive;
  final ValueChanged<int> onRestore;
  final void Function(int, int) onMove;
  @override
  Widget build(BuildContext context) {
    final items = state.page!.items;
    // The reorder endpoint receives a complete ordered collection. Reordering
    // a paginated subset would duplicate sort values outside the visible page.
    final canReorder =
        state.status != CatalogSetupStatus.archived &&
        items.length == state.page!.meta.total;
    return Column(
      key: const Key('catalog-setup-record-list'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _ListHeader(),
        ListView.separated(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => _RecordRow(
            item: items[index],
            index: index,
            count: items.length,
            canReorder: canReorder,
            busy: state.isBusy,
            onEdit: onEdit,
            onArchive: onArchive,
            onRestore: onRestore,
            onMove: onMove,
          ),
        ),
      ],
    );
  }
}

abstract final class _CatalogTableColumns {
  // Mirrors the Claude grid: a strong name column, balanced management
  // metadata, and enough room for four compact row actions.
  static const int name = 31;
  static const int products = 18;
  static const int status = 14;
  static const int order = 16;
  static const int actions = 21;
}

class _ListHeader extends StatelessWidget {
  const _ListHeader();
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );
    return Container(
      color: AppColors.menuTableHeader,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: _CatalogTableColumns.name,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.catalogSetupName, style: style),
            ),
          ),
          Expanded(
            flex: _CatalogTableColumns.products,
            child: Align(
              alignment: Alignment.center,
              child: Text(l10n.catalogSetupProducts, style: style),
            ),
          ),
          Expanded(
            flex: _CatalogTableColumns.status,
            child: Align(
              alignment: Alignment.center,
              child: Text(l10n.menuPublishStatus, style: style),
            ),
          ),
          Expanded(
            flex: _CatalogTableColumns.order,
            child: Align(
              alignment: Alignment.center,
              child: Text(l10n.catalogSetupOrder, style: style),
            ),
          ),
          Expanded(
            flex: _CatalogTableColumns.actions,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(l10n.catalogSetupActions, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.item,
    required this.index,
    required this.count,
    this.canReorder = false,
    this.busy = false,
    this.onEdit,
    this.onArchive,
    this.onRestore,
    this.onMove,
  });
  final CatalogSetupRecord item;
  final int index, count;
  final bool canReorder;
  final bool busy;
  final ValueChanged<CatalogSetupRecord>? onEdit, onArchive;
  final ValueChanged<int>? onRestore;
  final void Function(int, int)? onMove;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final archived = item.isArchived;
    final inactive = !item.isActive || archived;
    final label = archived
        ? l10n.catalogSetupArchived
        : item.isActive
        ? l10n.catalogSetupActive
        : l10n.catalogSetupInactive;
    return Semantics(
      label: '${item.displayName(Localizations.localeOf(context))}, $label',
      child: Container(
        color: inactive ? AppColors.surfaceAlt.withValues(alpha: .32) : null,
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: _CatalogTableColumns.name,
              child: _NameCell(item: item, muted: inactive),
            ),
            Expanded(
              flex: _CatalogTableColumns.products,
              child: Align(
                alignment: Alignment.center,
                child: Text('${item.productCount}'),
              ),
            ),
            Expanded(
              flex: _CatalogTableColumns.status,
              child: Align(
                alignment: Alignment.center,
                child: _StatusPill(
                  label: label,
                  active: item.isActive && !archived,
                ),
              ),
            ),
            Expanded(
              flex: _CatalogTableColumns.order,
              child: Align(
                alignment: Alignment.center,
                child: Text('${item.sortOrder}'),
              ),
            ),
            Expanded(
              flex: _CatalogTableColumns.actions,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: archived
                    ? <Widget>[
                        IconButton(
                          tooltip: l10n.catalogSetupRestore,
                          onPressed: busy
                              ? null
                              : () => onRestore?.call(item.id),
                          icon: const Icon(Icons.restore_outlined, size: 19),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                        ),
                      ]
                    : <Widget>[
                        IconButton(
                          tooltip: l10n.commonEdit,
                          onPressed: busy || !item.isActive
                              ? null
                              : () => onEdit?.call(item),
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.catalogSetupArchive(
                            _singular(
                              l10n,
                              context.read<CatalogSetupCubit>().state.kind,
                            ),
                          ),
                          onPressed: busy || !item.isActive
                              ? null
                              : () => onArchive?.call(item),
                          icon: const Icon(Icons.archive_outlined, size: 19),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.catalogSetupMoveUp,
                          onPressed: busy || !canReorder || index == 0
                              ? null
                              : () => onMove?.call(item.id, -1),
                          icon: const Icon(Icons.keyboard_arrow_up, size: 19),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.catalogSetupMoveDown,
                          onPressed: busy || !canReorder || index == count - 1
                              ? null
                              : () => onMove?.call(item.id, 1),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 19),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.item, required this.muted});
  final CatalogSetupRecord item;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final name = item.displayName(locale);
    final alternate = locale.languageCode == 'ar' ? item.nameEn : item.nameAr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: muted ? AppColors.textMuted : AppColors.textDark,
          ),
        ),
        if (alternate.trim().isNotEmpty && alternate != name)
          Text(
            alternate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: active ? AppColors.discountGreenBadge : AppColors.surfaceAlt,
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: active ? AppColors.success : AppColors.textMuted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.help,
    required this.onAdd,
  });
  final String title, help;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AppSpacing.allXl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.category_outlined,
            size: 34,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            help,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(
              context.l10n.catalogSetupAdd(
                _singular(
                  context.l10n,
                  context.read<CatalogSetupCubit>().state.kind,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.warning_amber_rounded,
          size: 38,
          color: AppColors.danger,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.catalogSetupCouldNotLoad,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.catalogSetupLoadHelp,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
      ],
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.state, required this.onPage});
  final CatalogSetupState state;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final page = state.page!.meta;
    return Container(
      key: const Key('catalog-setup-pagination'),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              context.l10n.catalogSetupShowing(
                state.page!.items.length,
                page.total,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: AppSpacing.horizontalMd,
            ),
            onPressed: state.isBusy || page.currentPage <= 1
                ? null
                : () => onPage(page.currentPage - 1),
            child: Text(context.l10n.catalogSetupPrevious),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: AppSpacing.horizontalMd,
            ),
            onPressed: state.isBusy || !page.hasNextPage
                ? null
                : () => onPage(page.currentPage + 1),
            child: Text(context.l10n.catalogSetupNext),
          ),
        ],
      ),
    );
  }
}

class _CatalogSetupEditorSheet extends StatefulWidget {
  const _CatalogSetupEditorSheet({this.record});
  final CatalogSetupRecord? record;
  @override
  State<_CatalogSetupEditorSheet> createState() =>
      _CatalogSetupEditorSheetState();
}

class _CatalogSetupEditorSheetState extends State<_CatalogSetupEditorSheet> {
  late final _nameAr = TextEditingController(text: widget.record?.nameAr ?? '');
  late final _nameEn = TextEditingController(
    text: widget.record?.nameEn.isNotEmpty == true
        ? widget.record!.nameEn
        : widget.record?.name ?? '',
  );
  bool _submitted = false;
  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Material(
      color: AppColors.surface,
      child: SafeArea(
        child: SizedBox(
          width: 520,
          child: BlocBuilder<CatalogSetupCubit, CatalogSetupState>(
            builder: (context, state) {
              final l10n = context.l10n;
              final kind = state.kind;
              final saving =
                  state.requestStatus == CatalogSetupRequestStatus.mutating;
              final edit = widget.record != null;
              final localizedName = _localizedName;
              final nameError = _submitted && localizedName.isEmpty
                  ? l10n.catalogSetupValidationRequired
                  : state.fieldErrors['name']?.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                edit
                                    ? l10n.catalogSetupEdit(
                                        _singular(l10n, kind),
                                      )
                                    : l10n.catalogSetupAdd(
                                        _singular(l10n, kind),
                                      ),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                l10n.catalogSetupEditorHelp,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.commonCancel,
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(context),
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
                        children: <Widget>[
                          TextField(
                            controller: _nameEn,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: l10n.catalogSetupNameEnglish,
                              errorText:
                                  state.fieldErrors['nameEn']?.first ??
                                  nameError,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: _nameAr,
                            textDirection: TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText: l10n.catalogSetupNameArabic,
                              errorText: state.fieldErrors['nameAr']?.first,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
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
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context),
                            child: Text(l10n.commonCancel),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                            ),
                            onPressed: saving ? null : _save,
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    l10n.catalogSetupSave(
                                      _singular(l10n, kind),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    softWrap: false,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  Future<void> _save() async {
    setState(() => _submitted = true);
    final cubit = context.read<CatalogSetupCubit>();
    final name = _localizedName;
    if (name.isEmpty) return;
    final existing = widget.record == null
        ? const CatalogSetupDraft()
        : CatalogSetupDraft.fromRecord(widget.record!);
    final draft = CatalogSetupDraft(
      // The API still requires its canonical name. For localized entities it
      // is derived from the manager-facing English name, or Arabic when only
      // that locale is provided, so the form never duplicates the concept.
      name: name,
      nameAr: _nameAr.text,
      nameEn: _nameEn.text,
      description: existing.description,
      code: existing.code,
      printerName: existing.printerName,
      branchId: existing.branchId,
      isActive: existing.isActive,
    );
    if (widget.record == null) {
      await cubit.create(draft);
    } else {
      await cubit.update(widget.record!.id, draft);
    }
    if (mounted &&
        cubit.state.requestStatus != CatalogSetupRequestStatus.failure) {
      Navigator.pop(context);
    }
  }

  String get _localizedName {
    final english = _nameEn.text.trim();
    return english.isNotEmpty ? english : _nameAr.text.trim();
  }
}

String _title(dynamic l10n, CatalogSetupKind kind) => switch (kind) {
  CatalogSetupKind.categories => l10n.catalogSetupCategoriesTitle,
  CatalogSetupKind.reportingCategories =>
    l10n.catalogSetupReportingCategoriesTitle,
  CatalogSetupKind.kitchenStations => l10n.catalogSetupKitchenStationsTitle,
};
String _singular(dynamic l10n, CatalogSetupKind kind) => switch (kind) {
  CatalogSetupKind.categories => l10n.catalogSetupCategory,
  CatalogSetupKind.reportingCategories => l10n.catalogSetupReportingCategory,
  CatalogSetupKind.kitchenStations => l10n.catalogSetupKitchenStation,
};
String _purpose(dynamic l10n, CatalogSetupKind kind) => switch (kind) {
  CatalogSetupKind.categories => l10n.catalogSetupCategoriesPurpose,
  CatalogSetupKind.reportingCategories => l10n.catalogSetupReportingPurpose,
  CatalogSetupKind.kitchenStations => l10n.catalogSetupStationsPurpose,
};
String _searchHint(dynamic l10n, CatalogSetupKind kind) => switch (kind) {
  CatalogSetupKind.categories => l10n.catalogSetupSearchCategories,
  CatalogSetupKind.reportingCategories => l10n.catalogSetupSearchReporting,
  CatalogSetupKind.kitchenStations => l10n.catalogSetupSearchStations,
};
String _emptyTitle(dynamic l10n, CatalogSetupKind kind) => switch (kind) {
  CatalogSetupKind.categories => l10n.catalogSetupNoCategories,
  CatalogSetupKind.reportingCategories =>
    l10n.catalogSetupNoReportingCategories,
  CatalogSetupKind.kitchenStations => l10n.catalogSetupNoKitchenStations,
};
String _emptyHelp(dynamic l10n, CatalogSetupKind kind) => switch (kind) {
  CatalogSetupKind.categories => l10n.catalogSetupEmptyCategoriesHelp,
  CatalogSetupKind.reportingCategories => l10n.catalogSetupEmptyReportingHelp,
  CatalogSetupKind.kitchenStations => l10n.catalogSetupEmptyStationsHelp,
};
String _statusLabel(dynamic l10n, CatalogSetupStatus status) =>
    switch (status) {
      CatalogSetupStatus.active => l10n.catalogSetupActive,
      CatalogSetupStatus.archived => l10n.catalogSetupArchived,
      CatalogSetupStatus.all => l10n.catalogSetupAll,
    };
