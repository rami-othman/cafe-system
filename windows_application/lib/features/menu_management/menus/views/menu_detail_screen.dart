import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../widgets/catalog_formatters.dart';
import '../../widgets/menu_management_tabs.dart';
import '../controllers/menu_detail_cubit.dart';
import '../models/menu_editor_draft.dart';
import '../models/menu_models.dart';

class MenuDetailScreen extends StatefulWidget {
  const MenuDetailScreen({super.key, required this.menuId});
  final int menuId;
  @override
  State<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends State<MenuDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MenuDetailCubit>().load(widget.menuId),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<MenuDetailCubit, MenuDetailState>(builder: _build);
  Widget _build(BuildContext context, MenuDetailState state) {
    final MenuDetailCubit cubit = context.read<MenuDetailCubit>();
    if (state.status == MenuDetailStatus.loading && state.menu == null)
      return const Center(child: CircularProgressIndicator());
    if (state.menu == null)
      return DesktopPageLayout(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(state.errorMessage ?? 'Menu not found.'),
              TextButton(
                onPressed: () => cubit.load(widget.menuId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    final MenuRecord menu = state.menu!;
    final List<MenuSectionRecord> active =
        menu.sections.where((s) => !s.isArchived).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
            _header(context, menu, state, cubit),
            const SizedBox(height: 16),
            const MenuManagementTabs(selected: 'menus'),
            const SizedBox(height: 20),
            if (state.errorMessage != null) _Alert(state.errorMessage!),
            if (menu.isArchived)
              const _Alert(
                'This menu is archived and read-only. Restore it before changing sections.',
              ),
            _General(menu: menu),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Sections',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!menu.isArchived)
                  FilledButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => _addSection(context, cubit),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Section'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage the sections here, then place Catalog Products in them.',
            ),
            const SizedBox(height: 12),
            SegmentedButton<MenuSectionFilter>(
              segments: const <ButtonSegment<MenuSectionFilter>>[
                ButtonSegment(
                  value: MenuSectionFilter.active,
                  label: Text('Active'),
                ),
                ButtonSegment(
                  value: MenuSectionFilter.inactive,
                  label: Text('Inactive'),
                ),
                ButtonSegment(
                  value: MenuSectionFilter.archived,
                  label: Text('Archived'),
                ),
                ButtonSegment(value: MenuSectionFilter.all, label: Text('All')),
              ],
              selected: <MenuSectionFilter>{state.sectionFilter},
              onSelectionChanged: (s) => cubit.setSectionFilter(s.first),
            ),
            const SizedBox(height: 12),
            if (state.sections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  state.sectionFilter == MenuSectionFilter.archived
                      ? 'No archived sections are available.'
                      : 'No sections have been created for this menu.',
                ),
              )
            else
              _SectionsTable(
                sections: state.sections,
                allActive: active,
                disabled: state.isBusy || menu.isArchived,
                onEdit: (section) => _editSection(context, cubit, section),
                onArchive: (id) => _confirmSection(
                  context,
                  true,
                  () => cubit.archiveSection(id),
                ),
                onRestore: (id) => _confirmSection(
                  context,
                  false,
                  () => cubit.restoreSection(id),
                ),
                onActivate: cubit.activateSection,
                onDeactivate: cubit.deactivateSection,
                onMove: cubit.moveSection,
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    MenuRecord menu,
    MenuDetailState state,
    MenuDetailCubit cubit,
  ) => Row(
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              menu.displayName(Localizations.localeOf(context)),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('Menu detail'),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.go('/menu-management/menus'),
        child: const Text('Back to menus'),
      ),
      if (menu.isArchived)
        FilledButton.icon(
          onPressed: state.isBusy
              ? null
              : () => _confirmMenuAction(context, false, cubit.restoreMenu),
          icon: const Icon(Icons.unarchive),
          label: const Text('Restore Menu'),
        )
      else ...<Widget>[
        OutlinedButton.icon(
          onPressed: state.isBusy
              ? null
              : () => context.go('/menu-management/review?menuId=${menu.id}'),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Validate & Preview'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: state.isBusy
              ? null
              : () =>
                    context.go('/menu-management/menus/${menu.id}/placements'),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Manage Products'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: state.isBusy
              ? null
              : () => context.go(
                  '/menu-management/assignments?menuId=${menu.id}',
                ),
          icon: const Icon(Icons.link),
          label: const Text('Manage Assignments'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: state.isBusy
              ? null
              : () => context.go('/menu-management/menus/${menu.id}/edit'),
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: state.isBusy
              ? null
              : () => _confirmMenuAction(context, true, cubit.archiveMenu),
          icon: const Icon(Icons.archive),
          label: const Text('Archive Menu'),
        ),
      ],
    ],
  );
  Future<void> _addSection(BuildContext context, MenuDetailCubit cubit) async {
    final MenuSectionDraft? draft = await showMenuSectionEditor(context);
    if (draft != null && context.mounted) await cubit.createSection(draft);
  }

  Future<void> _editSection(
    BuildContext context,
    MenuDetailCubit cubit,
    MenuSectionRecord section,
  ) async {
    final MenuSectionDraft? draft = await showMenuSectionEditor(
      context,
      section: section,
    );
    if (draft != null && context.mounted)
      await cubit.updateSection(section.id, draft);
  }
}

class _General extends StatelessWidget {
  const _General({required this.menu});
  final MenuRecord menu;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        children: <Widget>[
          Text('Status: ${menu.isArchived ? 'Archived' : menu.status}'),
          Text('Priority: ${menu.priority}'),
          Text('Sections: ${menu.sectionCount}'),
          Text('Visible placements: ${menu.visibleProductCount}'),
          Text('Updated: ${catalogDate(menu.updatedAt)}'),
          if (menu.archivedAt != null)
            Text('Archived: ${catalogDate(menu.archivedAt)}'),
          if (menu.description.isNotEmpty)
            SizedBox(width: 420, child: Text(menu.description)),
        ],
      ),
    ),
  );
}

class _SectionsTable extends StatelessWidget {
  const _SectionsTable({
    required this.sections,
    required this.allActive,
    required this.disabled,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onActivate,
    required this.onDeactivate,
    required this.onMove,
  });
  final List<MenuSectionRecord> sections, allActive;
  final bool disabled;
  final ValueChanged<MenuSectionRecord> onEdit;
  final ValueChanged<int> onArchive, onRestore;
  final ValueChanged<MenuSectionRecord> onActivate;
  final ValueChanged<MenuSectionRecord> onDeactivate;
  final Future<void> Function(int, int) onMove;
  @override
  Widget build(BuildContext context) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Section')),
          DataColumn(label: Text('State')),
          DataColumn(label: Text('Placements')),
          DataColumn(label: Text('Sort order')),
          DataColumn(label: Text('Actions')),
        ],
        rows: sections.map((section) {
          final int index = allActive.indexWhere((s) => s.id == section.id);
          return DataRow(
            cells: <DataCell>[
              DataCell(
                Text(section.displayName(Localizations.localeOf(context))),
              ),
              DataCell(
                Text(
                  section.isArchived
                      ? 'Archived'
                      : section.isActive
                      ? 'Active'
                      : 'Inactive',
                ),
              ),
              DataCell(Text('${section.placementCount}')),
              DataCell(Text('${section.sortOrder}')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Move Up',
                      onPressed: disabled || section.isArchived || index <= 0
                          ? null
                          : () => onMove(section.id, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move Down',
                      onPressed:
                          disabled ||
                              section.isArchived ||
                              index < 0 ||
                              index >= allActive.length - 1
                          ? null
                          : () => onMove(section.id, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: disabled || section.isArchived
                          ? null
                          : () => onEdit(section),
                      icon: const Icon(Icons.edit),
                    ),
                    if (!section.isArchived)
                      IconButton(
                        tooltip: section.isActive
                            ? context.l10n.commonDeactivate
                            : context.l10n.commonActivate,
                        onPressed: disabled
                            ? null
                            : () => section.isActive
                                  ? onDeactivate(section)
                                  : onActivate(section),
                        icon: Icon(
                          section.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                      ),
                    IconButton(
                      tooltip: section.isArchived ? 'Restore' : 'Archive',
                      onPressed: disabled
                          ? null
                          : () => section.isArchived
                                ? onRestore(section.id)
                                : onArchive(section.id),
                      icon: Icon(
                        section.isArchived ? Icons.unarchive : Icons.archive,
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

class _Alert extends StatelessWidget {
  const _Alert(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Text(text),
    ),
  );
}

Future<void> _confirmMenuAction(
  BuildContext context,
  bool archive,
  Future<void> Function() action,
) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(archive ? 'Archive menu?' : 'Restore menu?'),
      content: Text(
        archive
            ? 'The menu is soft archived, not permanently deleted. Existing orders and historical published versions are unchanged. Products, variants, modifier groups, and sections are not deleted.'
            : 'Restoring makes the menu editable again. It does not publish the menu, assign it to a branch or channel, or automatically restore archived sections.',
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

Future<void> _confirmSection(
  BuildContext context,
  bool archive,
  Future<void> Function() action,
) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(archive ? 'Archive section?' : 'Restore section?'),
      content: Text(
        archive
            ? 'This section is not permanently deleted. Products are not deleted from the Catalog and historical published versions remain unchanged.'
            : 'Only this section is restored. Archived product placements are not restored automatically.',
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

Future<MenuSectionDraft?> showMenuSectionEditor(
  BuildContext context, {
  MenuSectionRecord? section,
}) => showDialog<MenuSectionDraft>(
  context: context,
  builder: (_) => _SectionDialog(section: section),
);

class _SectionDialog extends StatefulWidget {
  const _SectionDialog({this.section});
  final MenuSectionRecord? section;
  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  late MenuSectionDraft draft;
  bool dirty = false, saving = false;
  @override
  void initState() {
    super.initState();
    final MenuSectionRecord? s = widget.section;
    draft = s == null
        ? const MenuSectionDraft()
        : MenuSectionDraft(
            name: s.name,
            nameAr: s.nameAr,
            nameEn: s.nameEn,
            description: s.description,
            imageUrl: s.imageUrl,
            isActive: s.isActive,
            sortOrder: '${s.sortOrder}',
          );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await _leaveDialog(context)) Navigator.pop(context);
    },
    child: AlertDialog(
      title: Text(widget.section == null ? 'Add Section' : 'Edit Section'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _field(
                'Default name',
                draft.name,
                (v) => _set(draft.copyWith(name: v)),
              ),
              _field(
                'Arabic name',
                draft.nameAr,
                (v) => _set(draft.copyWith(nameAr: v)),
              ),
              _field(
                'English name',
                draft.nameEn,
                (v) => _set(draft.copyWith(nameEn: v)),
              ),
              _field(
                'Description',
                draft.description,
                (v) => _set(draft.copyWith(description: v)),
                lines: 3,
              ),
              _field(
                'Image URL',
                draft.imageUrl,
                (v) => _set(draft.copyWith(imageUrl: v)),
              ),
              _field(
                'Sort order',
                draft.sortOrder,
                (v) => _set(draft.copyWith(sortOrder: v)),
                keyboard: TextInputType.number,
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: draft.isActive,
                onChanged: (v) => _set(draft.copyWith(isActive: v)),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            if (!dirty || await _leaveDialog(context)) {
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () {
                  if (draft.name.trim().isEmpty ||
                      (draft.sortOrder.trim().isNotEmpty &&
                          int.tryParse(draft.sortOrder.trim()) == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a section name and an integer sort order.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => saving = true);
                  Navigator.pop(context, draft);
                },
          child: Text(saving ? 'Saving…' : 'Save Section'),
        ),
      ],
    ),
  );
  void _set(MenuSectionDraft value) => setState(() {
    draft = value;
    dirty = true;
  });
  Widget _field(
    String label,
    String value,
    ValueChanged<String> changed, {
    int lines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value,
      maxLines: lines,
      keyboardType: keyboard,
      onChanged: changed,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

Future<bool> _leaveDialog(BuildContext context) async =>
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
// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously
