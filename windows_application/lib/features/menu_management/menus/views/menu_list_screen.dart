import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../widgets/catalog_formatters.dart';
import '../../widgets/menu_management_tabs.dart';
import '../controllers/menu_list_cubit.dart';
import '../models/menu_filter.dart';
import '../models/menu_models.dart';

class MenuListScreen extends StatefulWidget {
  const MenuListScreen({super.key});
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

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<MenuListCubit, MenuListState>(
        builder: (context, state) {
          final MenuListCubit cubit = context.read<MenuListCubit>();
          return DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Menu Management',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('Menus', style: TextStyle(fontSize: 20)),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            context.go('/menu-management/menus/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Menu'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: state.isBusy ? null : cubit.refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const MenuManagementTabs(selected: 'menus'),
                  const SizedBox(height: 20),
                  _Filters(state: state, cubit: cubit),
                  const SizedBox(height: 16),
                  if (state.status == MenuListStatus.loading &&
                      state.menus.isEmpty)
                    const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.status == MenuListStatus.failure &&
                      state.menus.isEmpty)
                    _Error(
                      message: state.errorMessage ?? 'Unable to load menus.',
                      retry: cubit.load,
                    )
                  else if (state.menus.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text(
                          state.filter.hasActiveFilters
                              ? 'No menus match the current filters.'
                              : 'No menus have been created yet.',
                        ),
                      ),
                    )
                  else ...<Widget>[
                    _Table(
                      menus: state.menus,
                      busyId: state.currentActionId,
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
                    ),
                    if (state.status == MenuListStatus.failure)
                      _Error(
                        message: state.errorMessage ?? 'Unable to load menus.',
                        retry: cubit.load,
                      ),
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: state.isBusy
                                ? null
                                : () => cubit.load(next: true),
                            child: const Text('Load more'),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.cubit});
  final MenuListState state;
  final MenuListCubit cubit;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: <Widget>[
      SizedBox(
        width: 260,
        child: TextField(
          onChanged: cubit.updateSearch,
          decoration: const InputDecoration(
            labelText: 'Search',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      _drop(
        'Status',
        state.filter.status,
        const <String>['draft', 'active', 'archived', 'all'],
        (v) => cubit.updateFilter(state.filter.copyWith(status: v)),
      ),
      _drop(
        'Sort',
        state.filter.sort,
        const <String>['priority', 'name', 'created_at', 'updated_at'],
        (v) => cubit.updateFilter(state.filter.copyWith(sort: v)),
      ),
      _drop(
        'Direction',
        state.filter.direction,
        const <String>['asc', 'desc'],
        (v) => cubit.updateFilter(state.filter.copyWith(direction: v)),
      ),
      if (state.filter.hasActiveFilters)
        TextButton(
          onPressed: () => cubit.updateFilter(const MenuFilter()),
          child: const Text('Clear filters'),
        ),
    ],
  );
  Widget _drop(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) => SizedBox(
    width: 160,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(e.replaceAll('_', ' ')),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

class _Table extends StatelessWidget {
  const _Table({
    required this.menus,
    required this.busyId,
    required this.onArchive,
    required this.onRestore,
  });
  final List<MenuRecord> menus;
  final int? busyId;
  final ValueChanged<int> onArchive, onRestore;
  @override
  Widget build(BuildContext context) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Menu')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Sections')),
          DataColumn(label: Text('Visible placements')),
          DataColumn(label: Text('Updated')),
          DataColumn(label: Text('Actions')),
        ],
        rows: menus
            .map(
              (m) => DataRow(
                cells: <DataCell>[
                  DataCell(
                    Text(m.localizedName),
                    onTap: () => context.go('/menu-management/menus/${m.id}'),
                  ),
                  DataCell(Text(m.isArchived ? 'Archived' : m.status)),
                  DataCell(Text('${m.sectionCount}')),
                  DataCell(Text('${m.visibleProductCount}')),
                  DataCell(Text(catalogDate(m.updatedAt))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Open',
                          onPressed: () =>
                              context.go('/menu-management/menus/${m.id}'),
                          icon: const Icon(Icons.open_in_new),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: m.isArchived
                              ? null
                              : () => context.go(
                                  '/menu-management/menus/${m.id}/edit',
                                ),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: m.isArchived ? 'Restore' : 'Archive',
                          onPressed: busyId == null
                              ? () => m.isArchived
                                    ? onRestore(m.id)
                                    : onArchive(m.id)
                              : null,
                          icon: Icon(
                            m.isArchived ? Icons.unarchive : Icons.archive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

Future<void> _confirmMenu(
  BuildContext context, {
  required bool archive,
  required Future<void> Function() action,
}) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(archive ? 'Archive menu?' : 'Restore menu?'),
      content: Text(
        archive
            ? 'The menu is soft archived, not permanently deleted. Existing orders and historical published versions are unchanged. Products, variants, modifier groups, and sections are not deleted. Restore and publish later before editable future use.'
            : 'Restoring makes the menu editable again. It does not publish the menu, assign a branch or channel, or restore archived sections.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(archive ? 'Archive' : 'Restore'),
        ),
      ],
    ),
  );
  if (yes == true) await action();
}
