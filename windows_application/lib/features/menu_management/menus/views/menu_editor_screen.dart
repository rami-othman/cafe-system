import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/menu_editor_cubit.dart';

class MenuEditorScreen extends StatefulWidget {
  const MenuEditorScreen({super.key, this.menuId});
  final int? menuId;
  @override
  State<MenuEditorScreen> createState() => _MenuEditorScreenState();
}

class _MenuEditorScreenState extends State<MenuEditorScreen> {
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final MenuEditorCubit cubit = context.read<MenuEditorCubit>();
      widget.menuId == null
          ? cubit.initializeCreate()
          : cubit.loadForEdit(widget.menuId!);
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<MenuEditorCubit, MenuEditorState>(
        listener: (context, state) {
          if (state.status == MenuEditorStatus.success && state.result != null)
            context.go('/menu-management/menus/${state.result!.id}');
        },
        child: BlocBuilder<MenuEditorCubit, MenuEditorState>(builder: _build),
      );
  Widget _build(BuildContext context, MenuEditorState state) {
    if (state.status == MenuEditorStatus.loading ||
        state.status == MenuEditorStatus.initializing)
      return const Center(child: CircularProgressIndicator());
    final MenuEditorCubit cubit = context.read<MenuEditorCubit>();
    return PopScope(
      canPop: !state.isDirty || state.status == MenuEditorStatus.success,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _leave(context) && context.mounted) context.pop();
      },
      child: DesktopPageLayout(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.menuId == null ? 'Create Menu' : 'Edit Menu',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if ((!state.isDirty || await _leave(context)) &&
                          context.mounted)
                        context.pop();
                    },
                    child: const Text('Back'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (state.errorMessage != null) _Message(state.errorMessage!),
              _field(
                'Default name',
                state.draft.name,
                (v) => cubit.updateDraft(state.draft.copyWith(name: v)),
                error: state.fieldErrors['name'],
              ),
              _field(
                'Arabic name',
                state.draft.nameAr,
                (v) => cubit.updateDraft(state.draft.copyWith(nameAr: v)),
              ),
              _field(
                'English name',
                state.draft.nameEn,
                (v) => cubit.updateDraft(state.draft.copyWith(nameEn: v)),
              ),
              _field(
                'Default description',
                state.draft.description,
                (v) => cubit.updateDraft(state.draft.copyWith(description: v)),
                maxLines: 3,
              ),
              _field(
                'Arabic description',
                state.draft.descriptionAr,
                (v) =>
                    cubit.updateDraft(state.draft.copyWith(descriptionAr: v)),
                maxLines: 3,
              ),
              _field(
                'English description',
                state.draft.descriptionEn,
                (v) =>
                    cubit.updateDraft(state.draft.copyWith(descriptionEn: v)),
                maxLines: 3,
              ),
              _field(
                'Cover image URL',
                state.draft.coverImageUrl,
                (v) =>
                    cubit.updateDraft(state.draft.copyWith(coverImageUrl: v)),
              ),
              _field(
                'Priority',
                state.draft.priority,
                (v) => cubit.updateDraft(state.draft.copyWith(priority: v)),
                error: state.fieldErrors['priority'],
                keyboard: TextInputType.number,
              ),
              if (state.isEdit)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: state.draft.status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                    ],
                    onChanged: (v) {
                      if (v != null)
                        cubit.updateDraft(state.draft.copyWith(status: v));
                    },
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.status == MenuEditorStatus.submitting
                    ? null
                    : cubit.submit,
                child: Text(
                  state.status == MenuEditorStatus.submitting
                      ? 'Saving...'
                      : 'Save Menu',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> changed, {
    String? error,
    int maxLines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SizedBox(
      width: 560,
      child: TextFormField(
        initialValue: value,
        onChanged: changed,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
// ignore_for_file: curly_braces_in_flow_control_structures
