import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'shift_design.dart';

/// Low-level presentation pieces every shift screen is assembled from.
///
/// They exist so the module has exactly one card, one badge, one metric tile
/// and one numeric field — a screen never re-derives padding, border or tone
/// rules locally.

/// Semantic tone shared by badges, alerts, readiness rows and count states.
enum ShiftTone { neutral, success, warning, surplus, blocker, accent }

extension ShiftToneColors on ShiftTone {
  Color get fill => switch (this) {
    ShiftTone.neutral => ShiftColors.neutralFill,
    ShiftTone.success => ShiftColors.matchFill,
    ShiftTone.warning => ShiftColors.shortageFill,
    ShiftTone.surplus => ShiftColors.surplusFill,
    ShiftTone.blocker => ShiftColors.blockerFill,
    ShiftTone.accent => ShiftColors.headerFill,
  };

  Color get ink => switch (this) {
    ShiftTone.neutral => ShiftColors.neutralInk,
    ShiftTone.success => ShiftColors.matchInk,
    ShiftTone.warning => ShiftColors.shortageInk,
    ShiftTone.surplus => ShiftColors.surplusInk,
    ShiftTone.blocker => ShiftColors.blockerInk,
    ShiftTone.accent => ShiftColors.ink,
  };

  IconData get icon => switch (this) {
    ShiftTone.neutral => Icons.info_outline,
    ShiftTone.success => Icons.check_circle_outline,
    ShiftTone.warning => Icons.warning_amber_outlined,
    ShiftTone.surplus => Icons.trending_up,
    ShiftTone.blocker => Icons.block_outlined,
    ShiftTone.accent => Icons.bolt_outlined,
  };
}

/// Digits, amounts, clock values and codes always render left-to-right so an
/// RTL paragraph can never reorder `-100` or `08:15`.
class ShiftValue extends StatelessWidget {
  const ShiftValue(
    this.value, {
    super.key,
    this.style,
    this.color,
    this.align = TextAlign.start,
    this.maxLines = 1,
  });

  final String value;
  final TextStyle? style;
  final Color? color;
  final TextAlign align;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
    value,
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: (style ?? ShiftText.bodyStrong).copyWith(color: color),
  );
}

/// The module's only card surface.
class ShiftCard extends StatelessWidget {
  const ShiftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.tone,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// When set, tints the card for an alert-style surface.
  final ShiftTone? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: padding, child: child);
    return Material(
      color: tone == null ? ShiftColors.surface : tone!.fill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(
          color: tone == null
              ? ShiftColors.border
              : tone!.ink.withValues(alpha: 0.24),
        ),
      ),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A card title with an optional trailing action or badge.
class ShiftSectionHeader extends StatelessWidget {
  const ShiftSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (icon != null) ...<Widget>[
        Icon(icon, size: 17, color: ShiftColors.inkMuted),
        const SizedBox(width: AppSpacing.sm),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: ShiftText.cardTitle),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(subtitle!, style: ShiftText.label),
            ],
          ],
        ),
      ),
      if (trailing != null) ...<Widget>[
        const SizedBox(width: AppSpacing.sm),
        trailing!,
      ],
    ],
  );
}

class ShiftBadge extends StatelessWidget {
  const ShiftBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
  });

  final String label;
  final ShiftTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: dense ? AppSpacing.sm : AppSpacing.md,
      vertical: dense ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: tone.fill,
      borderRadius: AppRadius.pillRadius,
      border: Border.all(color: tone.ink.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 12, color: tone.ink),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: ShiftText.badge.copyWith(color: tone.ink),
        ),
      ],
    ),
  );
}

/// Label + value pair used inside dense information cards.
class ShiftFactTile extends StatelessWidget {
  const ShiftFactTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.numeric = true,
    this.hint,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Numeric values render LTR; names and free text stay in the page
  /// direction.
  final bool numeric;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(label, style: ShiftText.label),
      const SizedBox(height: 3),
      if (numeric)
        ShiftValue(
          value,
          style: ShiftText.metricValueSmall,
          color: valueColor ?? ShiftColors.ink,
        )
      else
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ShiftText.metricValueSmall.copyWith(
            color: valueColor ?? ShiftColors.ink,
          ),
        ),
      if (hint != null) ...<Widget>[
        const SizedBox(height: 2),
        Text(hint!, style: ShiftText.label, maxLines: 2),
      ],
    ],
  );
}

/// A KPI tile: icon, label, headline value and one line of context.
class ShiftMetricCard extends StatelessWidget {
  const ShiftMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.context_,
    this.tone,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Secondary line beneath the value (comparison, share, unit count).
  final String? context_;
  final ShiftTone? tone;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => ShiftCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: (tone ?? ShiftTone.accent).fill,
                borderRadius: AppRadius.control,
              ),
              child: Icon(
                icon,
                size: 15,
                color: (tone ?? ShiftTone.accent).ink,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: ShiftText.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ShiftValue(
          value,
          style: ShiftText.metricValue,
          color: valueColor ?? ShiftColors.ink,
        ),
        if (context_ != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            context_!,
            style: ShiftText.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    ),
  );
}

/// A `label ................ value` row for summary lists.
class ShiftKeyValueRow extends StatelessWidget {
  const ShiftKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
    this.secondary,
    this.numeric = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  /// Optional middle column, e.g. a transaction count or a share.
  final String? secondary;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: emphasize ? ShiftText.bodyStrong : ShiftText.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (secondary != null) ...<Widget>[
          ShiftValue(secondary!, style: ShiftText.label),
          const SizedBox(width: AppSpacing.md),
        ],
        if (numeric)
          ShiftValue(
            value,
            style: emphasize
                ? ShiftText.metricValueSmall
                : ShiftText.bodyStrong,
            color: valueColor ?? ShiftColors.ink,
          )
        else
          Text(
            value,
            style: emphasize ? ShiftText.metricValueSmall : ShiftText.bodyStrong,
          ),
      ],
    ),
  );
}

class ShiftDividerLine extends StatelessWidget {
  const ShiftDividerLine({super.key, this.padding = AppSpacing.sm});

  final double padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: padding),
    child: const Divider(height: 1, thickness: 1, color: ShiftColors.border),
  );
}

/// Segmented control used for tabs, counting modes and filter chips.
class ShiftSegmentedControl<T> extends StatelessWidget {
  const ShiftSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<ShiftSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: ShiftColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: ShiftColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ShiftSegment<T> segment in segments)
          _Segment<T>(
            segment: segment,
            isSelected: segment.value == selected,
            onTap: () => onChanged(segment.value),
          ),
      ],
    ),
  );
}

class ShiftSegment<T> {
  const ShiftSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final ShiftSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: isSelected ? ShiftColors.ink : Colors.transparent,
    borderRadius: AppRadius.control,
    child: InkWell(
      borderRadius: AppRadius.control,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (segment.icon != null) ...<Widget>[
              Icon(
                segment.icon,
                size: 14,
                color: isSelected ? Colors.white : ShiftColors.inkSoft,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              segment.label,
              style: ShiftText.bodyStrong.copyWith(
                color: isSelected ? Colors.white : ShiftColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Selectable filter chip with a visible focus/selection state.
class ShiftFilterChip extends StatelessWidget {
  const ShiftFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => Material(
    color: isSelected ? ShiftColors.headerFill : ShiftColors.surface,
    borderRadius: AppRadius.pillRadius,
    child: InkWell(
      borderRadius: AppRadius.pillRadius,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.pillRadius,
          border: Border.all(
            color: isSelected ? ShiftColors.accent : ShiftColors.border,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: ShiftText.bodyStrong.copyWith(
                color: isSelected ? ShiftColors.ink : ShiftColors.inkSoft,
              ),
            ),
            if (count != null) ...<Widget>[
              const SizedBox(width: 5),
              ShiftValue(
                '$count',
                style: ShiftText.label,
                color: isSelected ? ShiftColors.ink : ShiftColors.inkMuted,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Labelled field wrapper: label, control, optional error and helper text.
class ShiftField extends StatelessWidget {
  const ShiftField({
    super.key,
    required this.label,
    required this.child,
    this.error,
    this.helper,
    this.isRequired = false,
  });

  final String label;
  final Widget child;
  final String? error;
  final String? helper;
  final bool isRequired;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        children: <Widget>[
          Flexible(child: Text(label, style: ShiftText.labelStrong)),
          if (isRequired)
            Text(
              ' *',
              style: ShiftText.labelStrong.copyWith(
                color: ShiftColors.blockerInk,
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      child,
      if (error != null) ...<Widget>[
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              size: 13,
              color: ShiftColors.blockerInk,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                error!,
                style: ShiftText.label.copyWith(color: ShiftColors.blockerInk),
              ),
            ),
          ],
        ),
      ] else if (helper != null) ...<Widget>[
        const SizedBox(height: 5),
        Text(helper!, style: ShiftText.label),
      ],
    ],
  );
}

/// Numeric entry used by cash and count fields. Enforces digits (and an
/// optional decimal separator) at the keyboard level so validation never has
/// to reject characters the user could not see were wrong.
class ShiftNumberField extends StatelessWidget {
  const ShiftNumberField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.allowDecimal = false,
    this.hasError = false,
    this.hintText,
    this.textAlign = TextAlign.start,
    this.large = false,
    this.focusNode,
    this.enabled = true,
    this.suffix,
    this.fieldKey,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool allowDecimal;
  final bool hasError;
  final String? hintText;
  final TextAlign textAlign;

  /// Headline sizing for the primary "amount in the drawer" field.
  final bool large;
  final FocusNode? focusNode;
  final bool enabled;
  final Widget? suffix;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: large ? 54 : ShiftLayout.touchTarget,
    child: TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      style:
          (large ? ShiftText.metricValue : ShiftText.bodyStrong).copyWith(
            color: ShiftColors.ink,
          ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: ShiftText.body.copyWith(color: ShiftColors.inkMuted),
        filled: true,
        fillColor: enabled ? ShiftColors.subtleFill : ShiftColors.neutralFill,
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: large ? AppSpacing.md : AppSpacing.sm,
        ),
        border: _border(ShiftColors.border),
        enabledBorder: _border(
          hasError ? ShiftColors.blockerInk : ShiftColors.border,
        ),
        focusedBorder: _border(
          hasError ? ShiftColors.blockerInk : ShiftColors.accent,
          width: 2,
        ),
        disabledBorder: _border(ShiftColors.border),
      ),
    ),
  );

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Multi-line note entry (opening notes, closing notes, variance detail).
class ShiftTextArea extends StatelessWidget {
  const ShiftTextArea({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText,
    this.minLines = 3,
    this.hasError = false,
    this.fieldKey,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final int minLines;
  final bool hasError;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    onChanged: onChanged,
    minLines: minLines,
    maxLines: minLines + 3,
    style: ShiftText.body.copyWith(color: ShiftColors.ink),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: ShiftText.body.copyWith(color: ShiftColors.inkMuted),
      filled: true,
      fillColor: ShiftColors.surface,
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      border: _border(ShiftColors.border),
      enabledBorder: _border(
        hasError ? ShiftColors.blockerInk : ShiftColors.border,
      ),
      focusedBorder: _border(
        hasError ? ShiftColors.blockerInk : ShiftColors.accent,
        width: 2,
      ),
    ),
  );

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Search box shared by the bar count toolbar and the history filters.
class ShiftSearchField extends StatelessWidget {
  const ShiftSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.width,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final double? width;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: ShiftLayout.touchTarget,
    child: TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      style: ShiftText.body.copyWith(color: ShiftColors.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: ShiftText.body.copyWith(color: ShiftColors.inkMuted),
        prefixIcon: const Icon(
          Icons.search,
          size: 17,
          color: ShiftColors.inkMuted,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 0,
        ),
        filled: true,
        fillColor: ShiftColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: _border(ShiftColors.border),
        enabledBorder: _border(ShiftColors.border),
        focusedBorder: _border(ShiftColors.accent, width: 2),
      ),
    ),
  );

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Compact labelled dropdown used across the history filter bar.
class ShiftDropdown<T> extends StatelessWidget {
  const ShiftDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 170,
    this.hint,
  });

  final T? value;
  final List<ShiftDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;
  final String? hint;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: ShiftLayout.touchTarget,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(
        Icons.expand_more,
        size: 18,
        color: ShiftColors.inkMuted,
      ),
      hint: hint == null
          ? null
          : Text(hint!, style: ShiftText.body, overflow: TextOverflow.ellipsis),
      style: ShiftText.bodyStrong.copyWith(color: ShiftColors.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ShiftColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: _border(ShiftColors.border),
        enabledBorder: _border(ShiftColors.border),
        focusedBorder: _border(ShiftColors.accent, width: 2),
      ),
      items: <DropdownMenuItem<T>>[
        for (final ShiftDropdownItem<T> item in items)
          DropdownMenuItem<T>(
            value: item.value,
            child: Text(
              item.label,
              style: ShiftText.body.copyWith(color: ShiftColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    ),
  );

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.control,
        borderSide: BorderSide(color: color, width: width),
      );
}

class ShiftDropdownItem<T> {
  const ShiftDropdownItem({required this.value, required this.label});

  final T? value;
  final String label;
}

/// Thin determinate progress bar (bar-count completion).
class ShiftProgressBar extends StatelessWidget {
  const ShiftProgressBar({
    super.key,
    required this.value,
    this.width,
    this.tone = ShiftTone.accent,
  });

  final double value;
  final double? width;
  final ShiftTone tone;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 6,
        backgroundColor: ShiftColors.border,
        valueColor: AlwaysStoppedAnimation<Color>(
          tone == ShiftTone.accent ? ShiftColors.ink : tone.ink,
        ),
      ),
    ),
  );
}

/// Primary/secondary/quiet buttons with a 44px minimum height.
enum ShiftButtonVariant { primary, secondary, quiet, danger }

class ShiftButton extends StatelessWidget {
  const ShiftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ShiftButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.large = false,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final ShiftButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool large;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    final (Color background, Color foreground, Color border) = switch (variant) {
      ShiftButtonVariant.primary => (
        ShiftColors.ink,
        Colors.white,
        ShiftColors.ink,
      ),
      ShiftButtonVariant.secondary => (
        ShiftColors.surface,
        ShiftColors.inkSoft,
        ShiftColors.border,
      ),
      ShiftButtonVariant.quiet => (
        Colors.transparent,
        ShiftColors.inkSoft,
        Colors.transparent,
      ),
      ShiftButtonVariant.danger => (
        ShiftColors.surface,
        ShiftColors.blockerInk,
        ShiftColors.blockerInk,
      ),
    };

    final Widget button = Material(
      color: isDisabled
          ? (variant == ShiftButtonVariant.primary
                ? ShiftColors.border
                : ShiftColors.neutralFill)
          : background,
      borderRadius: AppRadius.control,
      child: InkWell(
        key: buttonKey,
        borderRadius: AppRadius.control,
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(
            minHeight: large ? 50 : ShiftLayout.touchTarget,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: large ? AppSpacing.xl : AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.control,
            border: Border.all(
              color: isDisabled ? ShiftColors.border : border,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: isDisabled ? ShiftColors.inkMuted : foreground,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShiftText.button.copyWith(
                    fontSize: large ? 15 : 14,
                    color: isDisabled ? ShiftColors.inkMuted : foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Inline notice strip used for hints, warnings and blockers.
class ShiftNotice extends StatelessWidget {
  const ShiftNotice({
    super.key,
    required this.message,
    required this.tone,
    this.detail,
    this.action,
    this.icon,
  });

  final String message;
  final ShiftTone tone;
  final String? detail;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: tone.fill,
      borderRadius: AppRadius.card,
      border: Border.all(color: tone.ink.withValues(alpha: 0.22)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon ?? tone.icon, size: 17, color: tone.ink),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                style: ShiftText.bodyStrong.copyWith(color: tone.ink),
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  detail!,
                  style: ShiftText.body.copyWith(color: tone.ink),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          action!,
        ],
      ],
    ),
  );
}

/// Horizontally scrollable table frame with a minimum content width, so a
/// dense desktop table degrades to a scroll instead of overflowing.
class ShiftTableFrame extends StatelessWidget {
  const ShiftTableFrame({
    super.key,
    required this.child,
    this.minWidth = 900,
  });

  final Widget child;
  final double minWidth;

  @override
  Widget build(BuildContext context) => ShiftCard(
    padding: EdgeInsets.zero,
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= minWidth) return child;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: child,
          ),
        );
      },
    ),
  );
}

class ShiftTableHeader extends StatelessWidget {
  const ShiftTableHeader({super.key, required this.cells});

  final List<ShiftTableCell> cells;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    color: ShiftColors.headerFill,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Row(
      children: <Widget>[
        for (final ShiftTableCell cell in cells)
          Expanded(
            flex: (cell.flex * 10).round(),
            child: Align(
              alignment: cell.alignment,
              child: Text(
                cell.label,
                style: ShiftText.tableHeader,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    ),
  );
}

class ShiftTableCell {
  const ShiftTableCell(
    this.label, {
    this.flex = 1,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final String label;
  final double flex;
  final AlignmentGeometry alignment;
}
