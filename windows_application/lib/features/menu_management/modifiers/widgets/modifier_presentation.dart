import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../models/modifier_editor_drafts.dart';
import '../models/modifier_models.dart';

String modifierRuleSummary(BuildContext context, ModifierGroupRecord group) {
  return modifierRuleSummaryForFields(
    context,
    selectionType: group.selectionType,
    isRequired: group.isRequired,
    minSelections: group.minSelections,
    maxSelections: group.maxSelections,
    allowQuantity: group.allowQuantity,
  );
}

String modifierRuleSummaryForDraft(
  BuildContext context,
  ModifierGroupDraft draft,
) => modifierRuleSummaryForFields(
  context,
  selectionType: draft.selectionType,
  isRequired: draft.isRequired,
  minSelections: int.tryParse(draft.minSelections) ?? 0,
  maxSelections: int.tryParse(draft.maxSelections) ?? 1,
  allowQuantity: draft.allowQuantity,
);

String modifierRuleSummaryForFields(
  BuildContext context, {
  required String selectionType,
  required bool isRequired,
  required int minSelections,
  required int maxSelections,
  required bool allowQuantity,
}) {
  final AppLocalizations l10n = context.l10n;
  final int min = minSelections;
  final int max = maxSelections;
  final bool multiple = selectionType == 'multiple';
  final bool required = isRequired || min > 0;
  final String rule;

  if (!multiple) {
    rule = required
        ? l10n.modifierRuleExactly(1)
        : l10n.modifierRuleOptionalExactly(1);
  } else if (required && min == max) {
    rule = l10n.modifierRuleExactly(min);
  } else if (required) {
    rule = l10n.modifierRuleAtLeastUpTo(min, max);
  } else if (min == max && min > 0) {
    rule = l10n.modifierRuleOptionalExactly(min);
  } else {
    rule = l10n.modifierRuleOptionalUpTo(max);
  }

  if (!allowQuantity) return rule;
  return '$rule ${l10n.modifierRuleQuantity}';
}

String modifierOptionCountLabel(BuildContext context, int count) =>
    context.l10n.modifierOptionsCount(count);

Widget modifierStatusBadge(BuildContext context, ModifierGroupRecord group) {
  final AppLocalizations l10n = context.l10n;
  final bool archived = group.isArchived;
  final bool active = !archived && group.isActive;
  return _StatusBadge(
    label: archived
        ? l10n.modifierStatusArchived
        : active
        ? l10n.modifierStatusActive
        : l10n.modifierStatusInactive,
    icon: archived
        ? Icons.archive_outlined
        : active
        ? Icons.check_circle_outline
        : Icons.pause_circle_outline,
    color: archived
        ? AppColors.textMuted
        : active
        ? AppColors.success
        : AppColors.warning,
  );
}

Widget modifierOptionStatusBadge(
  BuildContext context,
  ModifierOptionRecord option,
) {
  final AppLocalizations l10n = context.l10n;
  final bool active = !option.isArchived && option.isActive;
  return _StatusBadge(
    label: option.isArchived
        ? l10n.modifierStatusArchived
        : active
        ? l10n.modifierStatusActive
        : l10n.modifierStatusInactive,
    icon: option.isArchived
        ? Icons.archive_outlined
        : active
        ? Icons.check_circle_outline
        : Icons.pause_circle_outline,
    color: option.isArchived
        ? AppColors.textMuted
        : active
        ? AppColors.success
        : AppColors.warning,
  );
}

class ModifierPreviewChip extends StatelessWidget {
  const ModifierPreviewChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 180),
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.control,
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}

Future<Map<String, String>?> showModifierTranslationsSheet(
  BuildContext context, {
  required String arabic,
  required String english,
}) => showGeneralDialog<Map<String, String>>(
  context: context,
  barrierDismissible: true,
  barrierLabel: context.l10n.modifierTranslations,
  barrierColor: Colors.black54,
  requestFocus: true,
  pageBuilder: (context, animation, secondaryAnimation) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: _TranslationsPanel(arabic: arabic, english: english),
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
);

class _TranslationsPanel extends StatefulWidget {
  const _TranslationsPanel({required this.arabic, required this.english});

  final String arabic;
  final String english;

  @override
  State<_TranslationsPanel> createState() => _TranslationsPanelState();
}

class _TranslationsPanelState extends State<_TranslationsPanel> {
  late String arabic = widget.arabic;
  late String english = widget.english;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: SizedBox(
          width: math.min(420, MediaQuery.sizeOf(context).width * .86),
          height: double.infinity,
          child: Padding(
            padding: AppSpacing.allXl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.modifierTranslations,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.modifierClose,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  initialValue: arabic,
                  textDirection: TextDirection.rtl,
                  autofocus: true,
                  onChanged: (value) => arabic = value,
                  decoration: InputDecoration(labelText: l10n.modifierArabic),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  initialValue: english,
                  onChanged: (value) => english = value,
                  decoration: InputDecoration(labelText: l10n.modifierEnglish),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, <String, String>{
                      'nameAr': arabic,
                      'nameEn': english,
                    }),
                    child: Text(l10n.modifierSaveChanges),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
