import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class StickyFormActions extends StatelessWidget {
  const StickyFormActions({
    super.key,
    required this.cancelLabel,
    required this.onCancel,
    required this.primaryLabel,
    required this.onSave,
    required this.isDirty,
    this.isSaving = false,
    this.validationSummary = const <String>[],
    this.primaryActionKey,
  });

  final String cancelLabel;
  final VoidCallback onCancel;
  final String primaryLabel;
  final Future<void> Function()? onSave;
  final bool isDirty;
  final bool isSaving;
  final List<String> validationSummary;
  final Key? primaryActionKey;

  @override
  Widget build(BuildContext context) {
    final bool canSave = isDirty && !isSaving && onSave != null;
    final Widget actions = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.end,
      children: <Widget>[
        OutlinedButton(
          onPressed: isSaving ? null : onCancel,
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          key: primaryActionKey,
          onPressed: canSave ? () => onSave!() : null,
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(primaryLabel),
        ),
      ],
    );

    return Material(
      color: AppColors.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpacing.allLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (validationSummary.isNotEmpty) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  label: '${validationSummary.length} validation errors',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          validationSummary.join('\n'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget indicator = Semantics(
                    label: isSaving
                        ? 'Saving changes'
                        : isDirty
                        ? 'Unsaved changes'
                        : 'All changes saved',
                    liveRegion: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isSaving
                              ? Icons.sync
                              : isDirty
                              ? Icons.edit_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                          color: isDirty
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          isSaving
                              ? 'Saving changes'
                              : isDirty
                              ? 'Unsaved changes'
                              : 'All changes saved',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  );
                  if (constraints.maxWidth <
                      AppSizes.menuHeaderInlineBreakpoint) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        indicator,
                        const SizedBox(height: AppSpacing.md),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: indicator),
                      actions,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
