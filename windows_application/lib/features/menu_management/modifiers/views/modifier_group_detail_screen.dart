import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/menu_management_route_locations.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../widgets/menu_content_components.dart';
import '../../widgets/menu_page_header.dart';
import '../controllers/modifier_group_detail_cubit.dart';
import '../models/modifier_editor_drafts.dart';
import '../models/modifier_models.dart';
import '../widgets/modifier_presentation.dart';

class ModifierGroupDetailScreen extends StatefulWidget {
  const ModifierGroupDetailScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<ModifierGroupDetailScreen> createState() =>
      _ModifierGroupDetailScreenState();
}

class _ModifierGroupDetailScreenState extends State<ModifierGroupDetailScreen> {
  bool _reordering = false;

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
      final l10n = context.l10n;
      if (state.status == ModifierDetailStatus.loading && state.group == null) {
        return const DesktopPageLayout(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (state.group == null) {
        return DesktopPageLayout(
          child: EmptyState(
            title: l10n.modifierGroupDetailNotFound,
            message: state.errorMessage ?? l10n.modifierGroupDetailNotFound,
            recoveryAction: EmptyStateAction(
              label: l10n.modifierRetry,
              onPressed: () => cubit.load(widget.groupId),
            ),
          ),
        );
      }

      final ModifierGroupRecord group = state.group!;
      return DesktopPageLayout(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            120,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  MenuPageHeader(
                    title: group.displayName(Localizations.localeOf(context)),
                    subtitle: modifierRuleSummary(context, group),
                    primaryAction: group.isArchived
                        ? null
                        : FilledButton.icon(
                            key: const Key('add-modifier-option-action'),
                            onPressed: state.currentActionId != null
                                ? null
                                : () => _optionDialog(context, cubit),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.modifierAddOption),
                          ),
                    secondaryActions: <Widget>[
                      if (!group.isArchived)
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/menu-management/modifiers/${group.id}/edit',
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.modifierEditGroup),
                        ),
                    ],
                    overflowActions: <MenuOverflowAction>[
                      MenuOverflowAction(
                        label: group.isArchived
                            ? l10n.modifierRestore
                            : l10n.modifierArchive,
                        icon: group.isArchived
                            ? Icons.restore
                            : Icons.archive_outlined,
                        onSelected: group.isArchived
                            ? () => cubit.restoreGroup()
                            : () => _archiveGroup(context, cubit),
                      ),
                      if (!group.isArchived)
                        MenuOverflowAction(
                          label: group.isActive
                              ? l10n.commonDeactivate
                              : l10n.commonActivate,
                          icon: group.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          onSelected: group.isActive
                              ? cubit.deactivateGroup
                              : cubit.activateGroup,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      modifierStatusBadge(context, group),
                      _Metric(
                        label: l10n.modifierOptions,
                        value: modifierOptionCountLabel(
                          context,
                          group.optionCount,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ContentSection(
                    title: l10n.modifierCurrentRuleSummary,
                    child: Semantics(
                      liveRegion: true,
                      label: modifierRuleSummary(context, group),
                      child: Text(
                        modifierRuleSummary(context, group),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DetailsDisclosure(
                    title: l10n.modifierAdvancedDetails,
                    child: Wrap(
                      spacing: AppSpacing.xxxl,
                      runSpacing: AppSpacing.lg,
                      children: <Widget>[
                        _DetailValue(
                          label: l10n.modifierSelectionMode,
                          value: group.selectionType,
                        ),
                        _DetailValue(
                          label: l10n.modifierMinimum,
                          value: '${group.minSelections}',
                        ),
                        _DetailValue(
                          label: l10n.modifierMaximum,
                          value: '${group.maxSelections}',
                        ),
                        _DetailValue(
                          label: l10n.modifierAllowQuantity,
                          value: group.allowQuantity
                              ? l10n.modifierYes
                              : l10n.modifierNo,
                        ),
                        _DetailValue(
                          label: l10n.modifierGroupType,
                          value: group.groupType,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  _OptionsSection(
                    state: state,
                    group: group,
                    reordering: _reordering,
                    onReorder: () => setState(() => _reordering = true),
                    onDone: () => setState(() => _reordering = false),
                    onMove: cubit.move,
                    onOption: (option) =>
                        _optionDialog(context, cubit, option: option),
                    onArchive: (option) =>
                        _archiveOption(context, cubit, option),
                    onRestore: cubit.restoreOption,
                    onActivate: cubit.activateOption,
                    onDeactivate: cubit.deactivateOption,
                    onDefault: (option) => _optionDialog(
                      context,
                      cubit,
                      option: option,
                      setDefault: true,
                    ),
                  ),
                  if (state.errorMessage != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    _ErrorPanel(message: _localizedDetailError(context, state)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.state,
    required this.group,
    required this.reordering,
    required this.onReorder,
    required this.onDone,
    required this.onMove,
    required this.onOption,
    required this.onArchive,
    required this.onRestore,
    required this.onActivate,
    required this.onDeactivate,
    required this.onDefault,
  });

  final ModifierGroupDetailState state;
  final ModifierGroupRecord group;
  final bool reordering;
  final VoidCallback onReorder;
  final VoidCallback onDone;
  final void Function(ModifierOptionRecord, int) onMove;
  final ValueChanged<ModifierOptionRecord> onOption;
  final ValueChanged<ModifierOptionRecord> onArchive;
  final ValueChanged<int> onRestore;
  final ValueChanged<ModifierOptionRecord> onActivate;
  final ValueChanged<ModifierOptionRecord> onDeactivate;
  final ValueChanged<ModifierOptionRecord> onDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<ModifierOptionRecord> options = state.visibleOptions;
    return ContentSection(
      title: l10n.modifierOptions,
      trailingAction: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment(value: 'active', label: Text(l10n.modifierActive)),
              ButtonSegment(
                value: 'inactive',
                label: Text(l10n.modifierStatusInactive),
              ),
              ButtonSegment(
                value: 'archived',
                label: Text(l10n.modifierArchived),
              ),
              ButtonSegment(value: 'all', label: Text(l10n.modifierAll)),
            ],
            selected: <String>{state.optionFilter},
            onSelectionChanged: (values) => context
                .read<ModifierGroupDetailCubit>()
                .setOptionFilter(values.first),
          ),
          if (reordering)
            OutlinedButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check),
              label: Text(l10n.modifierDone),
            )
          else
            OutlinedButton.icon(
              onPressed: group.isArchived || state.optionFilter != 'active'
                  ? null
                  : onReorder,
              icon: const Icon(Icons.swap_vert),
              label: Text(l10n.modifierReorderOptions),
            ),
        ],
      ),
      child: options.isEmpty
          ? Padding(
              padding: AppSpacing.allXl,
              child: Text(
                state.optionFilter == 'archived'
                    ? l10n.modifierNoArchivedOptions
                    : l10n.modifierNoOptions,
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.control,
              ),
              child: Column(
                children: <Widget>[
                  for (
                    int index = 0;
                    index < options.length;
                    index++
                  ) ...<Widget>[
                    _OptionRow(
                      groupId: group.id,
                      option: options[index],
                      index: index,
                      total: options.length,
                      reordering: reordering,
                      busy: state.currentActionId == options[index].id,
                      onMove: onMove,
                      onEdit: onOption,
                      onArchive: onArchive,
                      onRestore: onRestore,
                      onActivate: onActivate,
                      onDeactivate: onDeactivate,
                      onDefault: onDefault,
                    ),
                    if (index < options.length - 1)
                      const Divider(height: 1, indent: 56, endIndent: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.groupId,
    required this.option,
    required this.index,
    required this.total,
    required this.reordering,
    required this.busy,
    required this.onMove,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onActivate,
    required this.onDeactivate,
    required this.onDefault,
  });

  final int groupId;
  final ModifierOptionRecord option;
  final int index;
  final int total;
  final bool reordering;
  final bool busy;
  final void Function(ModifierOptionRecord, int) onMove;
  final ValueChanged<ModifierOptionRecord> onEdit;
  final ValueChanged<ModifierOptionRecord> onArchive;
  final ValueChanged<int> onRestore;
  final ValueChanged<ModifierOptionRecord> onActivate;
  final ValueChanged<ModifierOptionRecord> onDeactivate;
  final ValueChanged<ModifierOptionRecord> onDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final List<PopupMenuEntry<String>> menu = <PopupMenuEntry<String>>[
      if (!option.isArchived)
        PopupMenuItem(value: 'edit', child: Text(l10n.modifierOptionEditTitle)),
      if (!option.isArchived)
        PopupMenuItem(
          value: 'adjustments',
          child: Text(l10n.modifierMaterialAdjustments),
        ),
      if (!option.isArchived && option.isActive && !option.isDefault)
        PopupMenuItem(value: 'default', child: Text(l10n.modifierSetDefault)),
      if (!option.isArchived)
        PopupMenuItem(
          value: option.isActive ? 'deactivate' : 'activate',
          child: Text(
            option.isActive ? l10n.commonDeactivate : l10n.commonActivate,
          ),
        ),
      PopupMenuItem(
        value: option.isArchived ? 'restore' : 'archive',
        child: Text(
          option.isArchived ? l10n.modifierRestore : l10n.modifierArchive,
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        container: true,
        label:
            '${option.displayName(locale)}, ${option.isDefault ? l10n.modifierDefault : ''}',
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (reordering)
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: 8),
                  child: Icon(Icons.drag_indicator, color: AppColors.textMuted),
                )
              else
                const SizedBox(width: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          option.displayName(locale),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (option.isDefault)
                          Container(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: AppRadius.pillRadius,
                            ),
                            child: Text(
                              l10n.modifierDefault,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      modifierPriceAdjustmentLabel(context, option.priceDelta),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (constraints.maxWidth >= 760)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4),
                  child: modifierOptionStatusBadge(context, option),
                ),
              if (reordering)
                _OptionMoveButtons(
                  canMoveUp: index > 0,
                  canMoveDown: index < total - 1,
                  disabled: busy || option.isArchived,
                  onUp: () => onMove(option, -1),
                  onDown: () => onMove(option, 1),
                ),
              PopupMenuButton<String>(
                tooltip:
                    '${l10n.modifierOptions}: ${option.displayName(locale)}',
                enabled: !busy,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit(option);
                    case 'adjustments':
                      context.push(
                        MenuManagementRouteLocations.globalMaterialEffect(
                          groupId,
                          option.id,
                        ),
                      );
                    case 'default':
                      onDefault(option);
                    case 'archive':
                      onArchive(option);
                    case 'restore':
                      onRestore(option.id);
                    case 'activate':
                      onActivate(option);
                    case 'deactivate':
                      onDeactivate(option);
                  }
                },
                itemBuilder: (_) => menu,
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionMoveButtons extends StatelessWidget {
  const _OptionMoveButtons({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.disabled,
    required this.onUp,
    required this.onDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final bool disabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      IconButton(
        tooltip: context.l10n.modifierMoveUp,
        onPressed: disabled || !canMoveUp ? null : onUp,
        icon: const Icon(Icons.keyboard_arrow_up),
      ),
      IconButton(
        tooltip: context.l10n.modifierMoveDown,
        onPressed: disabled || !canMoveDown ? null : onDown,
        icon: const Icon(Icons.keyboard_arrow_down),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(value, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

Future<void> _archiveGroup(
  BuildContext context,
  ModifierGroupDetailCubit cubit,
) async {
  final l10n = context.l10n;
  final bool? accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.modifierArchiveGroupTitle),
      content: Text(l10n.modifierArchiveMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.modifierCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.modifierConfirmArchive),
        ),
      ],
    ),
  );
  if (accepted == true) await cubit.archiveGroup();
}

Future<void> _archiveOption(
  BuildContext context,
  ModifierGroupDetailCubit cubit,
  ModifierOptionRecord option,
) async {
  final l10n = context.l10n;
  final bool? accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.modifierArchiveOptionTitle),
      content: Text(l10n.modifierArchiveMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.modifierCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.modifierConfirmArchive),
        ),
      ],
    ),
  );
  if (accepted == true) await cubit.archiveOption(option.id);
}

Future<void> _optionDialog(
  BuildContext context,
  ModifierGroupDetailCubit cubit, {
  ModifierOptionRecord? option,
  bool setDefault = false,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _OptionDialog(cubit: cubit, option: option, setDefault: setDefault),
);

class _OptionDialog extends StatefulWidget {
  const _OptionDialog({
    required this.cubit,
    this.option,
    this.setDefault = false,
  });

  final ModifierGroupDetailCubit cubit;
  final ModifierOptionRecord? option;
  final bool setDefault;

  @override
  State<_OptionDialog> createState() => _OptionDialogState();
}

class _OptionDialogState extends State<_OptionDialog> {
  late ModifierOptionDraft draft = ModifierOptionDraft(
    name: widget.option?.name ?? '',
    nameAr: widget.option?.nameAr ?? '',
    nameEn: widget.option?.nameEn ?? '',
    priceDelta: widget.option?.priceDelta.toString() ?? '0',
    isDefault: widget.setDefault || (widget.option?.isDefault ?? false),
    isActive: widget.option?.isActive ?? true,
    isAvailable: widget.option?.isAvailable ?? true,
    sortOrder: widget.option?.sortOrder.toString() ?? '0',
  );
  bool saving = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.option == null
            ? l10n.modifierOptionCreateTitle
            : l10n.modifierOptionEditTitle,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (error != null) _ErrorPanel(message: error!),
              ContentSection(
                title: l10n.modifierOptionBasicInformation,
                child: Column(
                  children: <Widget>[
                    _field(
                      l10n.modifierOptionName,
                      draft.name,
                      (value) =>
                          setState(() => draft = draft.copyWith(name: value)),
                    ),
                    _field(
                      l10n.modifierPriceAdjustment,
                      draft.priceDelta,
                      (value) => setState(
                        () => draft = draft.copyWith(priceDelta: value),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: saving ? null : _translations,
                        icon: const Icon(Icons.translate),
                        label: Text(l10n.modifierTranslations),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DetailsDisclosure(
                title: l10n.modifierOptionAdvanced,
                child: Column(
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      title: Text(l10n.modifierOptionDefault),
                      value: draft.isDefault,
                      onChanged: (value) => setState(
                        () => draft = draft.copyWith(isDefault: value),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.modifierOptionActive),
                      value: draft.isActive,
                      onChanged: (value) => setState(
                        () => draft = draft.copyWith(isActive: value),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.modifierOptionAvailable),
                      value: draft.isAvailable,
                      onChanged: (value) => setState(
                        () => draft = draft.copyWith(isAvailable: value),
                      ),
                    ),
                    _field(
                      l10n.modifierSortOrder,
                      draft.sortOrder,
                      (value) => setState(
                        () => draft = draft.copyWith(sortOrder: value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(l10n.modifierCancel),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(
            saving ? l10n.modifierOptionSaving : l10n.modifierOptionSave,
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _translations() async {
    final Map<String, String>? result = await showModifierTranslationsSheet(
      context,
      arabic: draft.nameAr,
      english: draft.nameEn,
    );
    if (!mounted || result == null) return;
    setState(
      () => draft = draft.copyWith(
        nameAr: result['nameAr'],
        nameEn: result['nameEn'],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (draft.name.trim().isEmpty) {
      setState(() => error = l10n.modifierOptionNameRequired);
      return;
    }
    if (!isValidModifierPriceAdjustment(draft.priceDelta)) {
      setState(() => error = l10n.modifierOptionPriceInvalid);
      return;
    }
    if (int.tryParse(draft.sortOrder) == null) {
      setState(() => error = l10n.modifierOptionSortInvalid);
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
      if (mounted) {
        setState(() {
          saving = false;
          error = l10n.modifierOptionSaveError;
        });
      }
    }
  }
}

String _localizedDetailError(
  BuildContext context,
  ModifierGroupDetailState state,
) {
  final String message = state.errorMessage ?? '';
  if (message.contains('invalidating') ||
      message.contains('selection rules are invalid')) {
    return context.l10n.modifierOptionGroupInvalid;
  }
  return message;
}
