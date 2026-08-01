// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/modifier_group_editor_cubit.dart';
import '../models/modifier_editor_drafts.dart';

class ModifierGroupEditorScreen extends StatefulWidget {
  const ModifierGroupEditorScreen({super.key, this.groupId});
  final int? groupId;
  @override
  State<ModifierGroupEditorScreen> createState() =>
      _ModifierGroupEditorScreenState();
}

class _ModifierGroupEditorScreenState extends State<ModifierGroupEditorScreen> {
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.groupId == null
            ? context.read<ModifierGroupEditorCubit>().initializeCreate()
            : context.read<ModifierGroupEditorCubit>().loadForEdit(
                widget.groupId!,
              ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ModifierGroupEditorCubit, ModifierGroupEditorState>(
    listener: (context, state) {
      if (state.status == ModifierEditorStatus.success &&
          state.savedGroup != null)
        context.go('/menu-management/modifiers/${state.savedGroup!.id}');
    },
    builder: (context, state) {
      final ModifierGroupEditorCubit cubit = context
          .read<ModifierGroupEditorCubit>();
      return WillPopScope(
        onWillPop: () => _canLeave(context, state.isDirty),
        child: DesktopPageLayout(
          child: state.status == ModifierEditorStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: () async {
                                if (await _canLeave(context, state.isDirty) &&
                                    context.mounted)
                                  context.go('/menu-management/modifiers');
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                            Text(
                              state.isCreate
                                  ? 'Create Modifier Group'
                                  : 'Edit Modifier Group',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (state.formError != null) _Message(state.formError!),
                        _GroupForm(state: state, update: cubit.updateDraft),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed:
                              state.status == ModifierEditorStatus.submitting
                              ? null
                              : cubit.submit,
                          icon: state.status == ModifierEditorStatus.submitting
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            state.status == ModifierEditorStatus.submitting
                                ? 'Saving...'
                                : 'Save modifier group',
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

class _GroupForm extends StatelessWidget {
  const _GroupForm({required this.state, required this.update});
  final ModifierGroupEditorState state;
  final ValueChanged<ModifierGroupDraft> update;
  @override
  Widget build(BuildContext context) {
    final ModifierGroupDraft d = state.draft;
    return Column(
      children: <Widget>[
        _field(
          'Default name',
          d.name,
          state.fieldErrors['name'],
          (v) => update(d.copyWith(name: v)),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _field(
                'Arabic name',
                d.nameAr,
                state.fieldErrors['nameAr'],
                (v) => update(d.copyWith(nameAr: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                'English name',
                d.nameEn,
                state.fieldErrors['nameEn'],
                (v) => update(d.copyWith(nameEn: v)),
              ),
            ),
          ],
        ),
        _field(
          'Code',
          d.code,
          state.fieldErrors['code'],
          (v) => update(d.copyWith(code: v)),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _dropdown('Group type', d.groupType, const <String>[
                'choice',
                'add_on',
                'preparation_instruction',
              ], (v) => update(d.copyWith(groupType: v!))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                'Selection type',
                d.selectionType,
                const <String>['single', 'multiple'],
                (v) => update(d.copyWith(selectionType: v!)),
              ),
            ),
          ],
        ),
        SwitchListTile(
          title: const Text('Required'),
          value: d.isRequired,
          onChanged: (v) => update(d.copyWith(isRequired: v)),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _integer(
                'Minimum selections',
                d.minSelections,
                state.fieldErrors['minSelections'],
                (v) => update(d.copyWith(minSelections: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _integer(
                'Maximum selections',
                d.maxSelections,
                state.fieldErrors['maxSelections'],
                (v) => update(d.copyWith(maxSelections: v)),
              ),
            ),
          ],
        ),
        SwitchListTile(
          title: const Text('Allow quantity'),
          value: d.allowQuantity,
          onChanged: (v) => update(d.copyWith(allowQuantity: v)),
        ),
        SwitchListTile(
          title: const Text('Active'),
          value: d.isActive,
          onChanged: (v) => update(d.copyWith(isActive: v)),
        ),
        _integer(
          'Sort order',
          d.sortOrder,
          state.fieldErrors['sortOrder'],
          (v) => update(d.copyWith(sortOrder: v)),
        ),
        if (state.isCreate) ...<Widget>[
          const Divider(height: 36),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Initial option',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'The current backend requires one active option when creating a group. More options can be managed after saving.',
            ),
          ),
          _field(
            'Initial option name',
            d.initialOptionName,
            state.fieldErrors['options.0.name'],
            (v) => update(d.copyWith(initialOptionName: v)),
          ),
          _decimal(
            'Initial option price delta',
            d.initialOptionPriceDelta,
            state.fieldErrors['options.0.priceDelta'],
            (v) => update(d.copyWith(initialOptionPriceDelta: v)),
          ),
        ],
      ],
    );
  }

  Widget _field(
    String label,
    String value,
    String? error,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value,
      onChanged: changed,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget _integer(
    String label,
    String value,
    String? error,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value,
      onChanged: changed,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget _decimal(
    String label,
    String value,
    String? error,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value,
      onChanged: changed,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      value: value,
      onChanged: changed,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (v) => DropdownMenuItem<String>(
              value: v,
              child: Text(v.replaceAll('_', ' ')),
            ),
          )
          .toList(),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Text(text),
  );
}

Future<bool> _canLeave(BuildContext context, bool dirty) async {
  if (!dirty) return true;
  return (await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
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
      )) ??
      false;
}
