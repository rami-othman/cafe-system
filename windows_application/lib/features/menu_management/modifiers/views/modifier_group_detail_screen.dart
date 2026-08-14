// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../widgets/catalog_formatters.dart';
import '../../widgets/menu_management_tabs.dart';
import '../controllers/modifier_group_detail_cubit.dart';
import '../models/modifier_editor_drafts.dart';
import '../models/modifier_models.dart';

class ModifierGroupDetailScreen extends StatefulWidget {
  const ModifierGroupDetailScreen({super.key, required this.groupId});
  final int groupId;
  @override
  State<ModifierGroupDetailScreen> createState() =>
      _ModifierGroupDetailScreenState();
}

class _ModifierGroupDetailScreenState extends State<ModifierGroupDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ModifierGroupDetailCubit>().load(widget.groupId),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ModifierGroupDetailCubit, ModifierGroupDetailState>(
    builder: (context, state) {
      final ModifierGroupDetailCubit cubit = context
          .read<ModifierGroupDetailCubit>();
      if (state.status == ModifierDetailStatus.loading && state.group == null)
        return const DesktopPageLayout(
          child: Center(child: CircularProgressIndicator()),
        );
      if (state.group == null)
        return DesktopPageLayout(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(state.errorMessage ?? 'Modifier group not found.'),
                FilledButton(
                  onPressed: () => cubit.load(widget.groupId),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      final ModifierGroupRecord group = state.group!;
      return DesktopPageLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => context.go('/menu-management/modifiers'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      group.displayName(Localizations.localeOf(context)),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!group.isArchived)
                    OutlinedButton.icon(
                      onPressed: () => context.go(
                        '/menu-management/modifiers/${group.id}/edit',
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: state.currentActionId == null
                        ? cubit.refresh
                        : null,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const MenuManagementTabs(selected: 'modifiers'),
              const SizedBox(height: 20),
              _configuration(group),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Options',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: state.optionFilter,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'archived',
                        child: Text('Archived'),
                      ),
                      DropdownMenuItem(value: 'all', child: Text('All')),
                    ],
                    onChanged: (v) {
                      if (v != null) cubit.setOptionFilter(v);
                    },
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: group.isArchived || state.currentActionId != null
                        ? null
                        : () => _optionDialog(context, cubit),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Option'),
                  ),
                ],
              ),
              if (state.errorMessage != null)
                _error(context, state.errorMessage!),
              const SizedBox(height: 8),
              if (state.visibleOptions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    state.optionFilter == 'archived'
                        ? 'No archived modifier options.'
                        : 'No modifier options have been created yet.',
                  ),
                )
              else
                _options(context, state, cubit),
              const SizedBox(height: 20),
              const Text(
                'Product assignments will be managed separately.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _configuration(ModifierGroupRecord g) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 40,
        runSpacing: 16,
        children: <Widget>[
          _item('Arabic name', g.nameAr ?? '—'),
          _item('English name', g.nameEn ?? '—'),
          _item('Group type', g.groupType.replaceAll('_', ' ')),
          _item('Selection type', g.selectionType),
          _item('Required', g.isRequired ? 'Yes' : 'No'),
          _item('Selections', '${g.minSelections} to ${g.maxSelections}'),
          _item('Allow quantity', g.allowQuantity ? 'Yes' : 'No'),
          _item(
            'Status',
            g.isArchived
                ? 'Archived'
                : g.isActive
                ? 'Active'
                : 'Inactive',
          ),
        ],
      ),
    ),
  );
  Widget _item(String label, String value) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    ),
  );
  Widget _options(
    BuildContext context,
    ModifierGroupDetailState state,
    ModifierGroupDetailCubit cubit,
  ) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Price delta')),
          DataColumn(label: Text('Default')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Sort order')),
          DataColumn(label: Text('Actions')),
        ],
        rows: state.visibleOptions.asMap().entries.map((entry) {
          final int index = entry.key;
          final ModifierOptionRecord o = entry.value;
          return DataRow(
            cells: <DataCell>[
              DataCell(Text(o.displayName(Localizations.localeOf(context)))),
              DataCell(Text(catalogMoney(o.priceDelta))),
              DataCell(
                o.isDefault
                    ? const Chip(label: Text('Default'))
                    : const Text('—'),
              ),
              DataCell(
                Text(
                  o.isArchived
                      ? 'Archived'
                      : o.isActive
                      ? 'Active'
                      : 'Inactive',
                ),
              ),
              DataCell(Text('${o.sortOrder}')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Move up',
                      onPressed:
                          o.isArchived || index == 0 || state.isReordering
                          ? null
                          : () => cubit.move(o, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed:
                          o.isArchived ||
                              index == state.visibleOptions.length - 1 ||
                              state.isReordering
                          ? null
                          : () => cubit.move(o, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: o.isArchived || state.currentActionId != null
                          ? null
                          : () => _optionDialog(context, cubit, option: o),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Material Adjustments',
                      onPressed: o.isArchived
                          ? null
                          : () => context.go(
                              '/menu-management/modifier-options/${o.id}/recipe-adjustments',
                            ),
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                    IconButton(
                      tooltip: o.isArchived ? 'Restore' : 'Archive',
                      onPressed: state.currentActionId == null
                          ? () => o.isArchived
                                ? cubit.restoreOption(o.id)
                                : _archiveOption(context, cubit, o.id)
                          : null,
                      icon: Icon(
                        o.isArchived ? Icons.unarchive : Icons.archive,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ),
  );
}

Widget _error(BuildContext context, String text) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  color: Theme.of(context).colorScheme.errorContainer,
  child: Text(text),
);
Future<void> _archiveOption(
  BuildContext context,
  ModifierGroupDetailCubit cubit,
  int id,
) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Archive modifier option?'),
      content: const Text(
        'The option remains stored and can be restored later.',
      ),
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
  if (yes == true) await cubit.archiveOption(id);
}

Future<void> _optionDialog(
  BuildContext context,
  ModifierGroupDetailCubit cubit, {
  ModifierOptionRecord? option,
}) => showDialog<void>(
  context: context,
  builder: (_) => _OptionDialog(cubit: cubit, option: option),
);

class _OptionDialog extends StatefulWidget {
  const _OptionDialog({required this.cubit, this.option});
  final ModifierGroupDetailCubit cubit;
  final ModifierOptionRecord? option;
  @override
  State<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends State<_OptionDialog> {
  late ModifierOptionDraft draft = ModifierOptionDraft(
    name: widget.option?.name ?? '',
    nameAr: widget.option?.nameAr ?? '',
    nameEn: widget.option?.nameEn ?? '',
    priceDelta: widget.option?.priceDelta.toString() ?? '0',
    isDefault: widget.option?.isDefault ?? false,
    isActive: widget.option?.isActive ?? true,
    isAvailable: widget.option?.isAvailable ?? true,
    sortOrder: widget.option?.sortOrder.toString() ?? '0',
  );
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.option == null ? 'Add Modifier Option' : 'Edit Modifier Option',
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (error != null) _error(context, error!),
            _field(
              'Default name',
              draft.name,
              (v) => setState(() => draft = draft.copyWith(name: v)),
            ),
            _field(
              'Arabic name',
              draft.nameAr,
              (v) => setState(() => draft = draft.copyWith(nameAr: v)),
            ),
            _field(
              'English name',
              draft.nameEn,
              (v) => setState(() => draft = draft.copyWith(nameEn: v)),
            ),
            _field(
              'Price delta',
              draft.priceDelta,
              (v) => setState(() => draft = draft.copyWith(priceDelta: v)),
            ),
            _field(
              'Sort order',
              draft.sortOrder,
              (v) => setState(() => draft = draft.copyWith(sortOrder: v)),
            ),
            SwitchListTile(
              title: const Text('Default option'),
              value: draft.isDefault,
              onChanged: (v) =>
                  setState(() => draft = draft.copyWith(isDefault: v)),
            ),
            SwitchListTile(
              title: const Text('Active'),
              value: draft.isActive,
              onChanged: (v) =>
                  setState(() => draft = draft.copyWith(isActive: v)),
            ),
            SwitchListTile(
              title: const Text('Available'),
              value: draft.isAvailable,
              onChanged: (v) =>
                  setState(() => draft = draft.copyWith(isAvailable: v)),
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving...' : 'Save'),
      ),
    ],
  );
  Widget _field(String label, String value, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  Future<void> _save() async {
    if (draft.name.trim().isEmpty) {
      setState(() => error = 'Modifier option name is required.');
      return;
    }
    if (num.tryParse(draft.priceDelta) == null ||
        num.parse(draft.priceDelta) < 0) {
      setState(() => error = 'Price delta must be zero or positive.');
      return;
    }
    if (int.tryParse(draft.sortOrder) == null) {
      setState(() => error = 'Sort order must be a whole number.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.cubit.saveOption(draft, optionId: widget.option?.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          saving = false;
          error =
              'Unable to save this modifier option. Check the option rules and try again.';
        });
    }
  }
}
