// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../menus/models/menu_models.dart';
import '../../widgets/menu_management_tabs.dart';
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
  String search = '';
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
  Widget build(
    BuildContext context,
  ) => BlocConsumer<MenuAssignmentsCubit, MenuAssignmentsState>(
    listenWhen: (before, after) =>
        before.successMessage != after.successMessage &&
        after.successMessage != null,
    listener: (context, state) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.successMessage!))),
    builder: (context, state) {
      final MenuAssignmentsCubit cubit = context.read<MenuAssignmentsCubit>();
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
                          'Assignments & Schedules',
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: state.isBusy ? null : cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const MenuManagementTabs(selected: 'assignments'),
              const SizedBox(height: 20),
              _ScopeSelectors(state: state, cubit: cubit),
              if (widget.initialMenuId != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Opened from Menu #${widget.initialMenuId}. Select its Branch and Channel assignment below.',
                ),
              ],
              const SizedBox(height: 20),
              if (state.errorMessage != null)
                _Error(message: state.errorMessage!, onRetry: cubit.refresh),
              if (state.status == MenuAssignmentsStatus.loadingContext)
                const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.branches.isEmpty)
                const _Empty(
                  text: 'No active Branch is available for this Tenant.',
                )
              else if (state.status == MenuAssignmentsStatus.loading &&
                  state.assignments.isEmpty)
                const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...<Widget>[
                _AssignmentsCard(state: state, cubit: cubit),
                const SizedBox(height: 24),
                _AvailableMenusCard(
                  search: search,
                  onSearch: (value) => setState(() => search = value),
                  state: state,
                  cubit: cubit,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ScopeSelectors extends StatelessWidget {
  const _ScopeSelectors({required this.state, required this.cubit});
  final MenuAssignmentsState state;
  final MenuAssignmentsCubit cubit;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: <Widget>[
      SizedBox(
        width: 260,
        child: DropdownButtonFormField<int>(
          initialValue: state.selectedBranch?.id,
          decoration: const InputDecoration(
            labelText: 'Branch',
            border: OutlineInputBorder(),
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
      SizedBox(
        width: 220,
        child: DropdownButtonFormField<String>(
          initialValue: state.selectedChannel,
          decoration: const InputDecoration(
            labelText: 'Sales Channel',
            border: OutlineInputBorder(),
          ),
          items: salesChannels
              .map(
                (channel) => DropdownMenuItem<String>(
                  value: channel,
                  child: Text(channel.replaceAll('_', ' ')),
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
      if (state.selectedBranch?.timezone.isNotEmpty == true)
        Chip(label: Text('Branch timezone: ${state.selectedBranch!.timezone}')),
    ],
  );
}

class _AssignmentsCard extends StatelessWidget {
  const _AssignmentsCard({required this.state, required this.cubit});
  final MenuAssignmentsState state;
  final MenuAssignmentsCubit cubit;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Assigned Menus',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Assignments are ordered within this Branch and Sales Channel. Removing one does not archive its Menu or change its composition.',
          ),
          const SizedBox(height: 12),
          if (state.assignments.isEmpty)
            const _Empty(
              text: 'No menus are assigned to this Branch and Channel.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Order')),
                  DataColumn(label: Text('Menu')),
                  DataColumn(label: Text('Menu lifecycle')),
                  DataColumn(label: Text('Assignment')),
                  DataColumn(label: Text('Schedule')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: state.orderedAssignments
                    .asMap()
                    .entries
                    .map((entry) {
                      final int index = entry.key;
                      final MenuAssignment assignment = entry.value;
                      final MenuRecord? menu = assignment.menu;
                      final List<MenuScheduleRule>? rules =
                          state.scheduleRules[assignment.menuId];
                      final bool busy = state.currentActionKey != null;
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text('${index + 1}')),
                          DataCell(
                            Text(
                              menu?.localizedName ??
                                  'Menu #${assignment.menuId}',
                            ),
                          ),
                          DataCell(
                            Text(
                              menu?.isArchived == true
                                  ? 'Archived'
                                  : menu?.status ?? 'Unknown',
                            ),
                          ),
                          DataCell(
                            Switch(
                              value: assignment.isActive,
                              onChanged: busy || menu?.isArchived == true
                                  ? null
                                  : (value) => cubit.setAssignmentActive(
                                      assignment.menuId,
                                      value,
                                    ),
                            ),
                          ),
                          DataCell(
                            Text(
                              rules == null
                                  ? (state.scheduleLoadFailures.contains(
                                          assignment.menuId,
                                        )
                                        ? 'Schedule unavailable'
                                        : 'Loading…')
                                  : scheduleSummary(
                                      rules,
                                      state.selectedBranch!.id,
                                      state.selectedChannel,
                                    ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Move Up',
                                  onPressed: busy || index == 0
                                      ? null
                                      : () => cubit.moveAssignment(
                                          assignment.menuId,
                                          -1,
                                        ),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: 'Move Down',
                                  onPressed:
                                      busy ||
                                          index == state.assignments.length - 1
                                      ? null
                                      : () => cubit.moveAssignment(
                                          assignment.menuId,
                                          1,
                                        ),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                IconButton(
                                  tooltip: 'Manage Schedule',
                                  onPressed:
                                      busy ||
                                          menu?.isArchived == true ||
                                          rules == null
                                      ? null
                                      : () => _showSchedule(
                                          context,
                                          cubit,
                                          assignment,
                                          rules,
                                        ),
                                  icon: const Icon(Icons.schedule),
                                ),
                                IconButton(
                                  tooltip: 'Remove Assignment',
                                  onPressed: busy || menu?.isArchived == true
                                      ? null
                                      : () => _confirmRemoveAssignment(
                                          context,
                                          cubit,
                                          assignment.menuId,
                                        ),
                                  icon: const Icon(Icons.link_off),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AvailableMenusCard extends StatelessWidget {
  const _AvailableMenusCard({
    required this.search,
    required this.onSearch,
    required this.state,
    required this.cubit,
  });
  final String search;
  final ValueChanged<String> onSearch;
  final MenuAssignmentsState state;
  final MenuAssignmentsCubit cubit;
  @override
  Widget build(BuildContext context) {
    final String needle = search.trim().toLowerCase();
    final List<MenuRecord> menus = state.availableMenus
        .where(
          (menu) =>
              needle.isEmpty ||
              menu.localizedName.toLowerCase().contains(needle),
        )
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Available Menus',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  labelText: 'Search menus',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (menus.isEmpty)
              const _Empty(text: 'All eligible menus are already assigned.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: menus
                    .map(
                      (menu) => SizedBox(
                        width: 280,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          title: Text(menu.localizedName),
                          subtitle: Text(
                            '${menu.sectionCount} sections · ${menu.visibleProductCount} placements',
                          ),
                          trailing: FilledButton(
                            onPressed: state.isBusy || menu.isArchived
                                ? null
                                : () => cubit.assignMenu(menu),
                            child: const Text('Assign'),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

String scheduleSummary(
  List<MenuScheduleRule> rules,
  int branchId,
  String channel,
) {
  final List<MenuScheduleRule> exact = rules
      .where((rule) => rule.matchesExactScope(branchId, channel))
      .toList(growable: false);
  final List<MenuScheduleRule> applicable = rules
      .where(
        (rule) =>
            rule.isActive &&
            (rule.branchId == null || rule.branchId == branchId) &&
            (rule.channel == null || rule.channel == channel),
      )
      .toList(growable: false);
  if (applicable.isEmpty) {
    return exact.isEmpty ? 'Unrestricted' : 'No active schedule rules';
  }
  int specificity(MenuScheduleRule rule) =>
      (rule.branchId == null ? 0 : 2) + (rule.channel == null ? 0 : 1);
  final int strongest = applicable
      .map(specificity)
      .reduce((a, b) => a > b ? a : b);
  final List<MenuScheduleRule> active = applicable
      .where((rule) => specificity(rule) == strongest)
      .toList(growable: false);
  final bool inherited = !active.any(
    (rule) => rule.matchesExactScope(branchId, channel),
  );
  final String prefix = inherited ? 'Inherited: ' : '';
  if (active.length > 1) return '$prefix${active.length} active rules';
  final MenuScheduleRule rule = active.single;
  final String day = rule.dayOfWeek == null ? 'Daily' : _day(rule.dayOfWeek!);
  final String time = rule.startTime == null
      ? ''
      : ', ${rule.startTime}–${rule.endTime}${rule.isOvernight ? ' (overnight)' : ''}';
  return '$prefix$day$time';
}

String _day(int value) =>
    const <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][value];

Future<void> _confirmRemoveAssignment(
  BuildContext context,
  MenuAssignmentsCubit cubit,
  int menuId,
) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Remove menu assignment?'),
      content: const Text(
        'The Menu remains editable, its Sections and Placements are unchanged, and historical Published Versions are unchanged. This removes only this Branch/Channel assignment.',
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
  if (yes == true && context.mounted) await cubit.removeAssignment(menuId);
}

Future<void> _showSchedule(
  BuildContext context,
  MenuAssignmentsCubit cubit,
  MenuAssignment assignment,
  List<MenuScheduleRule> rules,
) => showDialog<void>(
  context: context,
  builder: (_) =>
      _ScheduleDialog(cubit: cubit, assignment: assignment, rules: rules),
);

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({
    required this.cubit,
    required this.assignment,
    required this.rules,
  });
  final MenuAssignmentsCubit cubit;
  final MenuAssignment assignment;
  final List<MenuScheduleRule> rules;
  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  MenuScheduleRuleDraft draft = const MenuScheduleRuleDraft();
  int? editingId;
  bool dirty = false;
  @override
  Widget build(BuildContext context) {
    final MenuAssignmentsState state = widget.cubit.state;
    final List<MenuScheduleRule> scoped = widget.rules
        .where(
          (r) => r.matchesExactScope(
            widget.assignment.branchId,
            widget.assignment.channel,
          ),
        )
        .toList(growable: false);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _leave(context)) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: AlertDialog(
        title: Text(
          'Schedule · ${widget.assignment.menu?.localizedName ?? 'Menu'}',
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Rules are fixed to the selected Branch and Channel. No scoped rules means this Menu is unrestricted for this scope. Overnight ranges are allowed.',
                ),
                const SizedBox(height: 12),
                if (scoped.isEmpty)
                  const _Empty(
                    text:
                        'No exact scope rules are configured. Applicable inherited rules remain unchanged; no applicable active rules means unrestricted.',
                  )
                else
                  ...scoped.map(
                    (rule) => ListTile(
                      title: Text(
                        scheduleSummary(
                          <MenuScheduleRule>[rule],
                          widget.assignment.branchId,
                          widget.assignment.channel,
                        ),
                      ),
                      subtitle: Text(
                        rule.isActive
                            ? 'Active · Priority ${rule.priority}'
                            : 'Inactive · Priority ${rule.priority}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Edit rule',
                            onPressed: state.isBusy
                                ? null
                                : () => setState(() {
                                    draft = rule.toDraft();
                                    editingId = rule.id;
                                    dirty = true;
                                  }),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'Remove rule',
                            onPressed: state.isBusy
                                ? null
                                : () async {
                                    final bool? yes = await _confirmRule(
                                      context,
                                    );
                                    if (yes == true) {
                                      await widget.cubit.removeScheduleRule(
                                        widget.assignment.menuId,
                                        rule.id,
                                      );
                                      if (context.mounted)
                                        Navigator.pop(context);
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(),
                Text(
                  editingId == null
                      ? 'Add schedule rule'
                      : 'Edit schedule rule',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<int?>(
                        initialValue: draft.dayOfWeek,
                        decoration: const InputDecoration(
                          labelText: 'Day (optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Daily'),
                          ),
                          ...List<DropdownMenuItem<int?>>.generate(
                            7,
                            (i) => DropdownMenuItem<int?>(
                              value: i,
                              child: Text(_day(i)),
                            ),
                          ),
                        ],
                        onChanged: (v) => _set(
                          draft.copyWith(dayOfWeek: v, clearDay: v == null),
                        ),
                      ),
                    ),
                    _field(
                      'Start time',
                      draft.startTime,
                      (v) => _set(draft.copyWith(startTime: v)),
                      width: 150,
                    ),
                    _field(
                      'End time',
                      draft.endTime,
                      (v) => _set(draft.copyWith(endTime: v)),
                      width: 150,
                    ),
                    _field(
                      'Start date',
                      draft.startDate,
                      (v) => _set(draft.copyWith(startDate: v)),
                      width: 170,
                    ),
                    _field(
                      'End date',
                      draft.endDate,
                      (v) => _set(draft.copyWith(endDate: v)),
                      width: 170,
                    ),
                    _field(
                      'Priority',
                      draft.priority,
                      (v) => _set(draft.copyWith(priority: v)),
                      width: 120,
                    ),
                    SizedBox(
                      width: 160,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: draft.isActive,
                        onChanged: (v) => _set(draft.copyWith(isActive: v)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              if (!dirty || await _leave(context)) {
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: state.isBusy
                ? null
                : () async {
                    await widget.cubit.saveScheduleRule(
                      widget.assignment.menuId,
                      draft,
                      replacingRuleId: editingId,
                    );
                    if (widget.cubit.state.errorMessage == null &&
                        context.mounted)
                      Navigator.pop(context);
                  },
            child: Text(editingId == null ? 'Add rule' : 'Save rule'),
          ),
        ],
      ),
    );
  }

  void _set(MenuScheduleRuleDraft value) => setState(() {
    draft = value;
    dirty = true;
  });
  Widget _field(
    String label,
    String value,
    ValueChanged<String> changed, {
    required double width,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      initialValue: value,
      onChanged: changed,
      decoration: InputDecoration(
        labelText: label,
        hintText: label.contains('time') ? 'HH:mm' : 'YYYY-MM-DD',
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

Future<bool> _leave(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('You have unsaved changes. Leave without saving?'),
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
Future<bool?> _confirmRule(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Remove schedule rule?'),
    content: const Text(
      'The Menu assignment and other rules remain unchanged. Future Preview and Publishing will use the updated editable schedule.',
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

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(24), child: Text(text));
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Row(
      children: <Widget>[
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
