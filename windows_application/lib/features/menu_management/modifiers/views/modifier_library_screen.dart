// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../widgets/catalog_formatters.dart';
import '../../widgets/menu_management_tabs.dart';
import '../controllers/modifier_library_cubit.dart';
import '../models/modifier_models.dart';

class ModifierLibraryScreen extends StatefulWidget {
  const ModifierLibraryScreen({super.key});
  @override
  State<ModifierLibraryScreen> createState() => _ModifierLibraryScreenState();
}

class _ModifierLibraryScreenState extends State<ModifierLibraryScreen> {
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
                        Text(
                          'Modifier Library',
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        context.go('/menu-management/modifiers/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Modifier Group'),
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
              const MenuManagementTabs(selected: 'modifiers'),
              const SizedBox(height: 20),
              _Filters(state: state, cubit: cubit),
              const SizedBox(height: 16),
              if (state.status == ModifierLibraryStatus.loading &&
                  state.groups.isEmpty)
                const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.status == ModifierLibraryStatus.failure &&
                  state.groups.isEmpty)
                _Error(
                  message:
                      state.errorMessage ?? 'Unable to load modifier groups.',
                  retry: cubit.load,
                )
              else if (state.groups.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(
                      state.filter.hasActiveFilters
                          ? 'No modifier groups match the current filters.'
                          : 'No modifier groups have been created yet.',
                    ),
                  ),
                )
              else ...<Widget>[
                _GroupTable(
                  groups: state.groups,
                  busyId: state.currentActionId,
                  onArchive: (id) => _confirm(
                    context,
                    'Archive modifier group?',
                    'The group and its options remain stored and can be restored later.',
                    () => cubit.archive(id),
                  ),
                  onRestore: cubit.restore,
                ),
                if (state.status == ModifierLibraryStatus.failure)
                  _Error(
                    message:
                        state.errorMessage ?? 'Unable to load modifier groups.',
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
  final ModifierLibraryState state;
  final ModifierLibraryCubit cubit;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
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
      _select(
        'Status',
        state.filter.status,
        const <String>['active', 'archived', 'all'],
        (v) => cubit.updateFilter(state.filter.copyWith(status: v)),
      ),
      _select(
        'Group type',
        state.filter.groupType,
        const <String>['choice', 'add_on', 'preparation_instruction'],
        (v) => cubit.updateFilter(
          state.filter.copyWith(groupType: v, clearGroupType: v == null),
        ),
      ),
      _select(
        'Selection',
        state.filter.selectionType,
        const <String>['single', 'multiple'],
        (v) => cubit.updateFilter(
          state.filter.copyWith(
            selectionType: v,
            clearSelectionType: v == null,
          ),
        ),
      ),
      if (state.filter.hasActiveFilters)
        TextButton(
          onPressed: () => cubit.updateFilter(const ModifierGroupFilter()),
          child: const Text('Clear filters'),
        ),
    ],
  );
  Widget _select(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String>>[
        if (label != 'Status')
          const DropdownMenuItem<String>(value: null, child: Text('Any')),
        ...values.map(
          (v) => DropdownMenuItem<String>(
            value: v,
            child: Text(
              v.replaceAll('_', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: changed,
    ),
  );
}

class _GroupTable extends StatelessWidget {
  const _GroupTable({
    required this.groups,
    required this.busyId,
    required this.onArchive,
    required this.onRestore,
  });
  final List<ModifierGroupRecord> groups;
  final int? busyId;
  final ValueChanged<int> onArchive, onRestore;
  @override
  Widget build(BuildContext context) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Group name')),
          DataColumn(label: Text('Group type')),
          DataColumn(label: Text('Selection')),
          DataColumn(label: Text('Required')),
          DataColumn(label: Text('Min / Max')),
          DataColumn(label: Text('Quantity')),
          DataColumn(label: Text('Active options')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Updated')),
          DataColumn(label: Text('Actions')),
        ],
        rows: groups
            .map(
              (g) => DataRow(
                cells: <DataCell>[
                  DataCell(
                    Text(g.displayName(Localizations.localeOf(context))),
                    onTap: () =>
                        context.go('/menu-management/modifiers/${g.id}'),
                  ),
                  DataCell(Text(g.groupType.replaceAll('_', ' '))),
                  DataCell(Text(g.selectionType)),
                  DataCell(Text(g.isRequired ? 'Required' : 'Optional')),
                  DataCell(Text('${g.minSelections} / ${g.maxSelections}')),
                  DataCell(Text(booleanLabel(g.allowQuantity))),
                  DataCell(Text('${g.activeOptionCount ?? g.optionCount}')),
                  DataCell(
                    Text(
                      g.isArchived
                          ? 'Archived'
                          : g.isActive
                          ? 'Active'
                          : 'Inactive',
                    ),
                  ),
                  DataCell(Text(catalogDate(g.updatedAt))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Open',
                          onPressed: () =>
                              context.go('/menu-management/modifiers/${g.id}'),
                          icon: const Icon(Icons.open_in_new),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: g.isArchived
                              ? null
                              : () => context.go(
                                  '/menu-management/modifiers/${g.id}/edit',
                                ),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: g.isArchived ? 'Restore' : 'Archive',
                          onPressed: busyId == null
                              ? () => g.isArchived
                                    ? onRestore(g.id)
                                    : onArchive(g.id)
                              : null,
                          icon: Icon(
                            g.isArchived ? Icons.unarchive : Icons.archive,
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

Future<void> _confirm(
  BuildContext context,
  String title,
  String message,
  Future<void> Function() action,
) async {
  final bool? accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );
  if (accepted == true) await action();
}
