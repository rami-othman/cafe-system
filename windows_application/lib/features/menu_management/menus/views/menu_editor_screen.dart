import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/menu_editor_cubit.dart';
import '../models/menu_editor_draft.dart';
import '../models/menu_models.dart';

/// Opens the single Menu editor used by both the list and the Menu workspace.
Future<MenuRecord?> showMenuEditorSheet(
  BuildContext context, {
  int? menuId,
  MenuEditorCubit? cubit,
}) {
  final bool rtl = Directionality.of(context) == TextDirection.rtl;
  final Widget editor = cubit == null
      ? BlocProvider<MenuEditorCubit>(
          create: (_) => serviceLocator<MenuEditorCubit>(),
          child: _MenuEditorSheet(menuId: menuId),
        )
      : BlocProvider<MenuEditorCubit>.value(
          value: cubit,
          child: _MenuEditorSheet(menuId: menuId),
        );
  return showGeneralDialog<MenuRecord>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.menuEditorClose,
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => editor,
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: Offset(rtl ? -.08 : .08, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _MenuEditorSheet extends StatefulWidget {
  const _MenuEditorSheet({this.menuId});
  final int? menuId;

  @override
  State<_MenuEditorSheet> createState() => _MenuEditorSheetState();
}

class _MenuEditorSheetState extends State<_MenuEditorSheet> {
  final TextEditingController _nameEn = TextEditingController();
  final TextEditingController _nameAr = TextEditingController();
  final TextEditingController _descriptionEn = TextEditingController();
  final TextEditingController _descriptionAr = TextEditingController();
  final TextEditingController _coverImageUrl = TextEditingController();
  final TextEditingController _priority = TextEditingController();
  bool _initialized = false;
  bool _populated = false;
  bool _showDetails = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final MenuEditorCubit cubit = context.read<MenuEditorCubit>();
      if (widget.menuId == null) {
        cubit.initializeCreate();
      } else {
        cubit.loadForEdit(widget.menuId!);
      }
    });
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _descriptionEn.dispose();
    _descriptionAr.dispose();
    _coverImageUrl.dispose();
    _priority.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Material(
      color: AppColors.surface,
      child: SafeArea(
        child: SizedBox(
          key: const Key('menu-editor-sheet'),
          width: 520,
          child: BlocConsumer<MenuEditorCubit, MenuEditorState>(
            listener: _listen,
            builder: _build,
          ),
        ),
      ),
    ),
  );

  void _listen(BuildContext context, MenuEditorState state) {
    if (!_populated &&
        state.status != MenuEditorStatus.initializing &&
        state.status != MenuEditorStatus.loading) {
      _populate(state.draft);
      _populated = true;
    }
    if (state.status == MenuEditorStatus.success && state.result != null) {
      Navigator.of(context).pop(state.result);
    }
  }

  void _populate(MenuEditorDraft draft) {
    _nameEn.text = draft.nameEn.isNotEmpty ? draft.nameEn : draft.name;
    _nameAr.text = draft.nameAr;
    _descriptionEn.text = draft.descriptionEn.isNotEmpty
        ? draft.descriptionEn
        : draft.description;
    _descriptionAr.text = draft.descriptionAr;
    _coverImageUrl.text = draft.coverImageUrl;
    _priority.text = draft.priority;
  }

  Widget _build(BuildContext context, MenuEditorState state) {
    final l10n = context.l10n;
    final bool loading =
        state.status == MenuEditorStatus.initializing ||
        state.status == MenuEditorStatus.loading;
    final bool saving = state.status == MenuEditorStatus.submitting;
    final bool edit = state.isEdit;
    final bool disabled = loading || saving || state.isArchived;
    if (!_populated && !loading) {
      _populate(state.draft);
      _populated = true;
    }
    return Column(
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
                      edit ? l10n.menuEditorEditTitle : l10n.menuEditorAddTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      edit ? l10n.menuEditorEditHelp : l10n.menuEditorAddHelp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('menu-editor-close'),
                tooltip: l10n.menuEditorClose,
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: AppSpacing.allLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (state.isArchived) const _ArchivedNotice(),
                      if (!edit) ...<Widget>[
                        const _DraftNotice(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _field(
                        key: const Key('menu-editor-name-en'),
                        controller: _nameEn,
                        label: l10n.menuEditorEnglishName,
                        enabled: !disabled,
                        error: _fieldError(l10n, state.fieldErrors['name']),
                        onChanged: (value) => _updateNames(value, _nameAr.text),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _field(
                        key: const Key('menu-editor-name-ar'),
                        controller: _nameAr,
                        label: l10n.menuEditorArabicName,
                        textDirection: TextDirection.rtl,
                        enabled: !disabled,
                        error: _fieldError(l10n, state.fieldErrors['nameAr']),
                        onChanged: (value) => _updateNames(_nameEn.text, value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton.icon(
                        key: const Key('menu-editor-more-details'),
                        onPressed: disabled
                            ? null
                            : () =>
                                  setState(() => _showDetails = !_showDetails),
                        icon: Icon(
                          _showDetails
                              ? Icons.expand_less_outlined
                              : Icons.expand_more_outlined,
                        ),
                        label: Text(
                          _showDetails
                              ? l10n.menuEditorHideDetails
                              : l10n.menuEditorMoreDetails,
                        ),
                      ),
                      if (_showDetails) ...<Widget>[
                        const Divider(height: AppSpacing.xxl),
                        _field(
                          key: const Key('menu-editor-description-en'),
                          controller: _descriptionEn,
                          label: l10n.menuEditorEnglishDescription,
                          enabled: !disabled,
                          maxLines: 3,
                          onChanged: (value) =>
                              _updateDescriptions(value, _descriptionAr.text),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _field(
                          key: const Key('menu-editor-description-ar'),
                          controller: _descriptionAr,
                          label: l10n.menuEditorArabicDescription,
                          textDirection: TextDirection.rtl,
                          enabled: !disabled,
                          maxLines: 3,
                          onChanged: (value) =>
                              _updateDescriptions(_descriptionEn.text, value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _field(
                          key: const Key('menu-editor-cover-image-url'),
                          controller: _coverImageUrl,
                          label: l10n.menuEditorCoverImageUrl,
                          enabled: !disabled,
                          keyboardType: TextInputType.url,
                          onChanged: (value) =>
                              context.read<MenuEditorCubit>().updateDraft(
                                state.draft.copyWith(coverImageUrl: value),
                              ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _field(
                          key: const Key('menu-editor-priority'),
                          controller: _priority,
                          label: l10n.menuEditorPriority,
                          helper: l10n.menuEditorPriorityHelp,
                          enabled: !disabled,
                          keyboardType: TextInputType.number,
                          error: _fieldError(
                            l10n,
                            state.fieldErrors['priority'],
                          ),
                          onChanged: (value) =>
                              context.read<MenuEditorCubit>().updateDraft(
                                state.draft.copyWith(priority: value),
                              ),
                        ),
                        if (edit) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            l10n.menuEditorStatus,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<String>(
                            key: const Key('menu-editor-status'),
                            initialValue: state.draft.status,
                            decoration: const InputDecoration(),
                            isExpanded: true,
                            items: <String>['draft', 'active', 'paused']
                                .map(
                                  (status) => DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(_statusLabel(l10n, status)),
                                  ),
                                )
                                .toList(),
                            onChanged: disabled
                                ? null
                                : (value) {
                                    if (value != null) {
                                      context
                                          .read<MenuEditorCubit>()
                                          .updateDraft(
                                            state.draft.copyWith(status: value),
                                          );
                                    }
                                  },
                          ),
                        ],
                      ],
                      if (state.errorMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        _ErrorMessage(
                          state.errorMessage == 'saveFailed'
                              ? l10n.menuEditorSaveFailed
                              : state.errorMessage!,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        const Divider(height: 1),
        _Footer(
          saving: saving,
          readOnly: state.isArchived,
          primaryLabel: edit
              ? l10n.menuEditorSaveChanges
              : l10n.menuEditorCreate,
          onCancel: () => Navigator.of(context).pop(),
          onSave: context.read<MenuEditorCubit>().submit,
        ),
      ],
    );
  }

  String? _fieldError(AppLocalizations l10n, String? error) => switch (error) {
    'required' => l10n.menuEditorNameRequired,
    'invalidInteger' => l10n.menuEditorPriorityInvalid,
    _ => error,
  };

  void _updateNames(String english, String arabic) {
    final cubit = context.read<MenuEditorCubit>();
    cubit.updateDraft(
      cubit.state.draft.withLocalizedNames(english: english, arabic: arabic),
    );
  }

  void _updateDescriptions(String english, String arabic) {
    final cubit = context.read<MenuEditorCubit>();
    cubit.updateDraft(
      cubit.state.draft.withLocalizedDescriptions(
        english: english,
        arabic: arabic,
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required ValueChanged<String> onChanged,
    String? error,
    String? helper,
    TextDirection? textDirection,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: enabled,
    textDirection: textDirection,
    keyboardType: keyboardType,
    minLines: maxLines,
    maxLines: maxLines,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      errorText: error,
    ),
  );
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.discountOrangeBadge,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: AppSpacing.allMd,
      child: Text(
        context.l10n.menuEditorDraftHelp,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}

class _ArchivedNotice extends StatelessWidget {
  const _ArchivedNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: AppSpacing.allMd,
        child: Text(
          context.l10n.menuEditorArchivedReadOnly,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.saving,
    required this.readOnly,
    required this.primaryLabel,
    required this.onCancel,
    required this.onSave,
  });
  final bool saving;
  final bool readOnly;
  final String primaryLabel;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
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
                onPressed: saving ? null : onCancel,
                child: Text(
                  readOnly ? l10n.menuEditorClose : l10n.commonCancel,
                ),
              ),
            ),
            if (!readOnly) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('menu-editor-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                  ),
                  onPressed: saving ? null : onSave,
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
                          primaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
  'active' => l10n.menuEditorStatusActive,
  'paused' => l10n.menuEditorStatusPaused,
  'archived' => l10n.menuEditorStatusArchived,
  _ => l10n.menuEditorStatusDraft,
};
