import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_card.dart';
import 'management_ui.dart';

/// Shared building blocks for settings pages: a titled section card, switch
/// rows, choice cards, a numeric stepper, notices and a sticky action bar.
/// Business rules stay in the feature; these widgets only present them.

/// Title, subtitle and an optional status badge at the top of a settings page.
class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.status,
  });
  final String title;
  final String subtitle;
  final Widget? status;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ?status,
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        subtitle,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}

/// A card that groups related settings under an icon, title and description.
/// [notice] appears above the rows (for example why they are disabled).
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.description,
    this.notice,
  });
  final IconData icon;
  final String title;
  final String? description;
  final Widget? notice;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.discountIconBackground,
                borderRadius: AppRadius.control,
              ),
              child: Icon(icon, size: 22, color: AppColors.secondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (notice != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          notice!,
        ],
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const Divider(height: AppSpacing.lg),
          children[i],
        ],
      ],
    ),
  );
}

/// One on/off setting: label and help at the start, switch at the end.
/// A null [onChanged] shows the row as inactive without changing [value].
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    this.tileKey,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.emphasized = false,
  });

  /// Key of the inner [SwitchListTile] (for finding the control itself).
  final Key? tileKey;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Larger title for a section's main switch.
  final bool emphasized;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    key: tileKey,
    contentPadding: EdgeInsets.zero,
    title: Text(
      title,
      style: (emphasized ? AppTextStyles.titleMedium : AppTextStyles.bodyLarge)
          .copyWith(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            color: onChanged == null
                ? AppColors.textMuted
                : AppColors.textPrimary,
          ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
    value: value,
    onChanged: onChanged,
  );
}

/// One option of [SettingsChoiceCards].
class SettingsChoice<T> {
  const SettingsChoice({
    required this.value,
    required this.title,
    this.help,
    this.icon,
    this.key,
  });
  final T value;
  final String title;
  final String? help;
  final IconData? icon;
  final Key? key;
}

/// Mutually exclusive options shown as selectable cards, side by side when
/// there is room. A null [onChanged] shows them as inactive.
class SettingsChoiceCards<T> extends StatelessWidget {
  const SettingsChoiceCards({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.label,
  });
  final T value;
  final List<SettingsChoice<T>> choices;
  final ValueChanged<T>? onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (label != null) ...<Widget>[
        Text(
          label!,
          style: AppTextStyles.labelLarge.copyWith(
            color: onChanged == null
                ? AppColors.textMuted
                : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final List<Widget> cards = <Widget>[
            for (final SettingsChoice<T> choice in choices)
              _ChoiceCard<T>(
                choice: choice,
                selected: choice.value == value,
                onTap: onChanged == null
                    ? null
                    : () => onChanged!(choice.value),
              ),
          ];
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < cards.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  cards[i],
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < cards.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.selected,
    required this.onTap,
  });
  final SettingsChoice<T> choice;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final bool active = onTap != null;
    final Color accent = active ? AppColors.secondary : AppColors.textMuted;
    // One merged node: label, selection state and the tap action together.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: active,
        inMutuallyExclusiveGroup: true,
        child: Opacity(
          opacity: active ? 1 : 0.6,
          child: Material(
            color: selected
                ? AppColors.paymentSelectedBackground
                : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: BorderSide(
                color: selected ? accent : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              key: choice.key,
              borderRadius: AppRadius.card,
              onTap: selected ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? accent : AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (choice.icon != null) ...<Widget>[
                                Icon(choice.icon, size: 18, color: accent),
                                const SizedBox(width: AppSpacing.xs),
                              ],
                              Expanded(
                                child: Text(
                                  choice.title,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: active
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (choice.help != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              choice.help!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whole-number setting with − / + buttons around a compact text field.
/// The field stays editable so a value can also be typed.
class SettingsNumberStepper extends StatelessWidget {
  const SettingsNumberStepper({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.helper,
    this.errorText,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? errorText;
  final int min;
  final int max;

  /// Current numeric value (may be outside [min]..[max] while typing).
  final int value;

  /// Null shows the stepper as inactive.
  final ValueChanged<String>? onChanged;
  final String decreaseLabel;
  final String increaseLabel;
  @override
  Widget build(BuildContext context) {
    final bool active = onChanged != null;
    void step(int delta) {
      final int next = (value + delta).clamp(min, max);
      controller.text = '$next';
      onChanged!('$next');
    }

    return _LabeledSetting(
      label: label,
      helper: helper,
      errorText: errorText,
      active: active,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton.outlined(
            tooltip: decreaseLabel,
            onPressed: active && value > min ? () => step(-1) : null,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 72,
            child: TextField(
              key: fieldKey,
              controller: controller,
              enabled: active,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: increaseLabel,
            onPressed: active && value < max ? () => step(1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Compact numeric text setting (for example a percentage) with a suffix.
class SettingsCompactField extends StatelessWidget {
  const SettingsCompactField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.helper,
    this.errorText,
    this.suffixText,
    this.decimal = false,
    this.width = 180,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? errorText;
  final String? suffixText;
  final bool decimal;
  final double width;

  /// Null shows the field as inactive.
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => _LabeledSetting(
    label: label,
    helper: helper,
    errorText: errorText,
    active: onChanged != null,
    child: SizedBox(
      width: width,
      child: TextField(
        key: fieldKey,
        controller: controller,
        enabled: onChanged != null,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(isDense: true, suffixText: suffixText),
        onChanged: onChanged,
      ),
    ),
  );
}

/// Label and helper beside a control on wide layouts, stacked on narrow ones.
class _LabeledSetting extends StatelessWidget {
  const _LabeledSetting({
    required this.label,
    required this.child,
    required this.active,
    this.helper,
    this.errorText,
  });
  final String label;
  final String? helper;
  final String? errorText;
  final bool active;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: active ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        if (helper != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            helper!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
        if (errorText != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          constraints.maxWidth < 520
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                text,
                const SizedBox(height: AppSpacing.sm),
                child,
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: text),
                const SizedBox(width: AppSpacing.lg),
                child,
              ],
            ),
    );
  }
}

/// Inline message inside a page or section.
class SettingsNotice extends StatelessWidget {
  const SettingsNotice({
    super.key,
    required this.message,
    this.tone = ManagementTone.info,
    this.action,
  });
  final String message;
  final ManagementTone tone;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, IconData icon) = switch (tone) {
      ManagementTone.danger => (
        const Color(0xFFFFE6E4),
        AppColors.danger,
        Icons.error_outline,
      ),
      ManagementTone.warning => (
        AppColors.discountOrangeBadge,
        AppColors.discountOrangeText,
        Icons.warning_amber_outlined,
      ),
      ManagementTone.success => (
        AppColors.discountGreenBadge,
        AppColors.discountGreenText,
        Icons.check_circle_outline,
      ),
      _ => (
        AppColors.discountBlueBadge,
        AppColors.discountBlueText,
        Icons.info_outline,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(color: foreground),
                ),
                ?action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar that keeps the page's save actions visible while scrolling.
class SettingsActionBar extends StatelessWidget {
  const SettingsActionBar({super.key, required this.actions, this.status});
  final Widget? status;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          status ?? const SizedBox.shrink(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: actions,
          ),
        ],
      ),
    ),
  );
}

/// One line of a settings summary: a state icon and its text.
class SettingsSummaryRow extends StatelessWidget {
  const SettingsSummaryRow({super.key, required this.text, this.enabled});
  final String text;

  /// true = allowed (check), false = not allowed (cross), null = neutral fact.
  final bool? enabled;
  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (enabled) {
      true => (Icons.check_circle, AppColors.success),
      false => (Icons.cancel_outlined, AppColors.textMuted),
      null => (Icons.circle, AppColors.tertiary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: enabled == null ? 8 : 18, color: color),
          ),
          SizedBox(width: enabled == null ? AppSpacing.md : AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: enabled == false
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
