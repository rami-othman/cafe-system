import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../widgets/menu_content_components.dart';
import '../../widgets/menu_page_header.dart';
import '../../widgets/sticky_form_actions.dart';
import '../controllers/modifier_group_editor_cubit.dart';
import '../models/modifier_editor_drafts.dart';
import '../widgets/modifier_presentation.dart';

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
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.groupId == null
          ? context.read<ModifierGroupEditorCubit>().initializeCreate()
          : context.read<ModifierGroupEditorCubit>().loadForEdit(
              widget.groupId!,
            ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ModifierGroupEditorCubit, ModifierGroupEditorState>(
    listener: (context, state) {
      if (state.status == ModifierEditorStatus.success &&
          state.savedGroup != null) {
        context.go('/menu-management/modifiers/${state.savedGroup!.id}');
      }
    },
    builder: (context, state) {
      final ModifierGroupEditorCubit cubit = context
          .read<ModifierGroupEditorCubit>();
      final l10n = context.l10n;
      return PopScope<void>(
        canPop: !state.isDirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (await _canLeave(context, state.isDirty) && context.mounted) {
            context.go('/menu-management/modifiers');
          }
        },
        child: DesktopPageLayout(
          padding: EdgeInsets.zero,
          child: state.status == ModifierEditorStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.xxxl,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                MenuPageHeader(
                                  title: state.isCreate
                                      ? l10n.modifierCreateTitle
                                      : l10n.modifierEditTitle,
                                  subtitle: state.isCreate
                                      ? l10n.modifierBasicInformationHelper
                                      : null,
                                ),
                                if (state.formError != null) ...<Widget>[
                                  const SizedBox(height: AppSpacing.lg),
                                  _Message(text: state.formError!),
                                ],
                                const SizedBox(height: AppSpacing.xl),
                                _GroupForm(
                                  state: state,
                                  update: cubit.updateDraft,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    StickyFormActions(
                      cancelLabel: l10n.modifierCancel,
                      onCancel: () async {
                        if (await _canLeave(context, state.isDirty) &&
                            context.mounted) {
                          context.go('/menu-management/modifiers');
                        }
                      },
                      primaryLabel: state.isCreate
                          ? l10n.modifierCreateAction
                          : l10n.modifierSaveChanges,
                      onSave: cubit.submit,
                      isDirty: state.isDirty,
                      isSaving: state.status == ModifierEditorStatus.submitting,
                      validationSummary: state.fieldErrors.values.toList(),
                      primaryActionKey: const Key('modifier-group-submit'),
                    ),
                  ],
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
    final ModifierGroupDraft draft = state.draft;
    final l10n = context.l10n;
    final bool multiple = draft.selectionType == 'multiple';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ContentSection(
          title: l10n.modifierBasicInformation,
          description: l10n.modifierBasicInformationHelper,
          trailingAction: TextButton.icon(
            onPressed: () => _translations(context, draft, update),
            icon: const Icon(Icons.translate),
            label: Text(l10n.modifierTranslations),
          ),
          child: _textField(
            label: l10n.modifierGroupName,
            hint: l10n.modifierGroupNameHint,
            value: draft.name,
            error: state.fieldErrors['name'],
            onChanged: (value) => update(draft.copyWith(name: value)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ContentSection(
          title: l10n.modifierSelectionRules,
          description: l10n.modifierSelectionRulesHelper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _QuestionLabel(l10n.modifierHowChoose),
              _ChoiceCards(
                value: draft.selectionType,
                options: <String, String>{
                  'single': l10n.modifierChooseOne,
                  'multiple': l10n.modifierChooseMultiple,
                },
                onChanged: (value) {
                  if (value == 'single') {
                    update(
                      draft.copyWith(
                        selectionType: value,
                        minSelections: draft.isRequired ? '1' : '0',
                        maxSelections: '1',
                      ),
                    );
                  } else {
                    update(draft.copyWith(selectionType: value));
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              _QuestionLabel(l10n.modifierChoiceRequired),
              _ChoiceCards(
                value: draft.isRequired ? 'required' : 'optional',
                options: <String, String>{
                  'required': l10n.modifierRequired,
                  'optional': l10n.modifierOptional,
                },
                onChanged: (value) => update(
                  draft.copyWith(
                    isRequired: value == 'required',
                    minSelections:
                        value == 'required' && draft.minSelections == '0'
                        ? '1'
                        : draft.minSelections,
                  ),
                ),
              ),
              if (multiple) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _numberField(
                        label: l10n.modifierMinimumChoices,
                        value: draft.minSelections,
                        error: state.fieldErrors['minSelections'],
                        onChanged: (value) =>
                            update(draft.copyWith(minSelections: value)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _numberField(
                        label: l10n.modifierMaximumChoices,
                        value: draft.maxSelections,
                        error: state.fieldErrors['maxSelections'],
                        onChanged: (value) =>
                            update(draft.copyWith(maxSelections: value)),
                      ),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.modifierSameOptionQuantity),
                  subtitle: Text(l10n.modifierQuantityHelper),
                  value: draft.allowQuantity,
                  onChanged: (value) =>
                      update(draft.copyWith(allowQuantity: value)),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _RuleSummary(draft: draft),
            ],
          ),
        ),
        if (state.isCreate) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          ContentSection(
            title: l10n.modifierInitialOption,
            description: l10n.modifierInitialOptionHelper,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _textField(
                    label: l10n.modifierOptionName,
                    hint: l10n.modifierOptionNameHint,
                    value: draft.initialOptionName,
                    error: state.fieldErrors['options.0.name'],
                    onChanged: (value) =>
                        update(draft.copyWith(initialOptionName: value)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _textField(
                    label: l10n.modifierPriceAdjustment,
                    value: draft.initialOptionPriceDelta,
                    error: state.fieldErrors['options.0.priceDelta'],
                    onChanged: (value) =>
                        update(draft.copyWith(initialOptionPriceDelta: value)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        DetailsDisclosure(
          title: l10n.modifierAdvanced,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _textField(
                label: l10n.modifierInternalCode,
                value: draft.code,
                error: state.fieldErrors['code'],
                onChanged: (value) => update(draft.copyWith(code: value)),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _dropdown(
                      label: l10n.modifierGroupType,
                      value: draft.groupType,
                      items: const <String>[
                        'choice',
                        'add_on',
                        'preparation_instruction',
                      ],
                      labels: <String, String>{
                        'choice': l10n.modifierGroupTypeChoice,
                        'add_on': l10n.modifierGroupTypeAddOn,
                        'preparation_instruction':
                            l10n.modifierGroupTypePreparation,
                      },
                      onChanged: (value) =>
                          update(draft.copyWith(groupType: value)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _numberField(
                      label: l10n.modifierSortOrder,
                      value: draft.sortOrder,
                      error: state.fieldErrors['sortOrder'],
                      onChanged: (value) =>
                          update(draft.copyWith(sortOrder: value)),
                    ),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.modifierActiveStatus),
                subtitle: Text(l10n.modifierAvailableForUse),
                value: draft.isActive,
                onChanged: (value) => update(draft.copyWith(isActive: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionLabel extends StatelessWidget {
  const _QuestionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _ChoiceCards extends StatelessWidget {
  const _ChoiceCards({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: options.entries
          .map(
            (entry) => SizedBox(
              width: (constraints.maxWidth - AppSpacing.md) / 2,
              child: _ChoiceCard(
                label: entry.value,
                selected: value == entry.key,
                onTap: () => onChanged(entry.key),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    selected: selected,
    button: true,
    label: label,
    child: Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: AppRadius.control,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.control,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: AppSpacing.allMd,
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RuleSummary extends StatelessWidget {
  const _RuleSummary({required this.draft});

  final ModifierGroupDraft draft;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: AppRadius.control,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.rule, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.modifierCurrentRuleSummary,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(modifierRuleSummaryForDraft(context, draft)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _textField({
  required String label,
  String? hint,
  required String value,
  String? error,
  required ValueChanged<String> onChanged,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: TextFormField(
    initialValue: value,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
    ),
  ),
);

Widget _numberField({
  required String label,
  required String value,
  String? error,
  required ValueChanged<String> onChanged,
}) =>
    _textField(label: label, value: value, error: error, onChanged: onChanged);

Widget _dropdown({
  required String label,
  required String value,
  required List<String> items,
  required Map<String, String> labels,
  required ValueChanged<String> onChanged,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: items
        .map(
          (item) =>
              DropdownMenuItem(value: item, child: Text(labels[item] ?? item)),
        )
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  ),
);

Future<void> _translations(
  BuildContext context,
  ModifierGroupDraft draft,
  ValueChanged<ModifierGroupDraft> update,
) async {
  final Map<String, String>? result = await showModifierTranslationsSheet(
    context,
    arabic: draft.nameAr,
    english: draft.nameEn,
  );
  if (!context.mounted || result == null) return;
  update(draft.copyWith(nameAr: result['nameAr'], nameEn: result['nameEn']));
}

Future<bool> _canLeave(BuildContext context, bool dirty) async {
  if (!dirty) return true;
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.modifierUnsavedChanges),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.modifierStay),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.modifierLeave),
            ),
          ],
        ),
      ) ??
      false;
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: AppRadius.control,
    ),
    child: Text(text),
  );
}
