import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/shift_models.dart';
import 'shift_design.dart';
import 'shift_primitives.dart';
import 'shift_strings.dart';

/// Renders every [ShiftAlert] as a stacked notice list.
///
/// Blockers always sort first so the reason a shift cannot close is the
/// first thing a cashier reads, even when several warnings are present too.
class ShiftAlertsCard extends StatelessWidget {
  const ShiftAlertsCard({super.key, required this.alerts, this.onAction});

  final List<ShiftAlert> alerts;
  final ValueChanged<ShiftAlert>? onAction;

  @override
  Widget build(BuildContext context) {
    final List<ShiftAlert> sorted = List<ShiftAlert>.of(alerts)
      ..sort((ShiftAlert a, ShiftAlert b) => _rank(a).compareTo(_rank(b)));

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftSectionHeader(
            title: ShiftStrings.shiftAlerts,
            icon: Icons.notifications_active_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < sorted.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            ShiftNotice(
              message: sorted[i].title,
              detail: sorted[i].detail,
              tone: _toneFor(sorted[i].severity),
              action: sorted[i].actionLabel == null || onAction == null
                  ? null
                  : ShiftButton(
                      label: sorted[i].actionLabel!,
                      variant: ShiftButtonVariant.secondary,
                      onPressed: () => onAction!(sorted[i]),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  static int _rank(ShiftAlert alert) => switch (alert.severity) {
    ShiftAlertSeverity.blocker => 0,
    ShiftAlertSeverity.warning => 1,
    ShiftAlertSeverity.info => 2,
    ShiftAlertSeverity.success => 3,
  };

  static ShiftTone _toneFor(ShiftAlertSeverity severity) => switch (severity) {
    ShiftAlertSeverity.blocker => ShiftTone.blocker,
    ShiftAlertSeverity.warning => ShiftTone.warning,
    ShiftAlertSeverity.info => ShiftTone.accent,
    ShiftAlertSeverity.success => ShiftTone.success,
  };
}

/// The checklist that decides whether the primary close button is enabled.
class ShiftReadinessChecklist extends StatelessWidget {
  const ShiftReadinessChecklist({super.key, required this.items});

  final List<ShiftReadinessItem> items;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ShiftSectionHeader(
          title: ShiftStrings.closingReadiness,
          icon: Icons.fact_check_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _ReadinessRow(item: items[i]),
        ],
      ],
    ),
  );
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({required this.item});

  final ShiftReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (item.status) {
      ShiftReadinessStatus.done => (Icons.check_circle, ShiftColors.matchInk),
      ShiftReadinessStatus.pending => (
        Icons.radio_button_unchecked,
        ShiftColors.inkMuted,
      ),
      ShiftReadinessStatus.warning => (
        Icons.warning_amber_rounded,
        ShiftColors.shortageInk,
      ),
      ShiftReadinessStatus.blocked => (Icons.cancel, ShiftColors.blockerInk),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.label,
                style: ShiftText.bodyStrong.copyWith(
                  color: item.status == ShiftReadinessStatus.pending
                      ? ShiftColors.inkMuted
                      : ShiftColors.ink,
                ),
              ),
              if (item.detail != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(item.detail!, style: ShiftText.label),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal stage tracker used on the overview and (compact) in the wizard
/// footer.
class ShiftProgressTrack extends StatelessWidget {
  const ShiftProgressTrack({super.key, required this.steps});

  final List<ShiftStageStep> steps;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ShiftSectionHeader(
          title: ShiftStrings.shiftProgress,
          icon: Icons.route_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (int i = 0; i < steps.length; i++) ...<Widget>[
              _StageDot(step: steps[i], number: i + 1),
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 12,
                    color: ShiftColors.trackLine,
                  ),
                ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.step, required this.number});

  final ShiftStageStep step;
  final int number;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink) = switch (step.status) {
      ShiftStageStatus.done => (ShiftColors.matchInk, Colors.white),
      ShiftStageStatus.current => (ShiftColors.ink, Colors.white),
      ShiftStageStatus.warning => (ShiftColors.shortageFill, ShiftColors.shortageInk),
      ShiftStageStatus.pending => (ShiftColors.neutralFill, ShiftColors.inkMuted),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: step.status == ShiftStageStatus.done
                ? Icon(Icons.check, size: 13, color: ink)
                : Text(
                    '$number',
                    style: ShiftText.badge.copyWith(color: ink),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            step.label,
            style: ShiftText.body.copyWith(
              fontWeight: step.status == ShiftStageStatus.current
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: step.status == ShiftStageStatus.pending
                  ? ShiftColors.inkMuted
                  : ShiftColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
