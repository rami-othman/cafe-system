import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/shift_models.dart';
import 'shift_design.dart';
import 'shift_format.dart';
import 'shift_primitives.dart';
import 'shift_strings.dart';

/// Answers "who, where, which shift, since when" in a single strip.
///
/// For an open shift the duration ticks once a second; a closed shift shows
/// its sealed duration and the closing time instead, so the same widget backs
/// both the live screen and the report header.
class ShiftIdentityHeader extends StatefulWidget {
  const ShiftIdentityHeader({
    super.key,
    required this.identity,
    this.compact = false,
  });

  final ShiftIdentity identity;

  /// Drops the status badge and tightens padding for report/print layouts.
  final bool compact;

  @override
  State<ShiftIdentityHeader> createState() => _ShiftIdentityHeaderState();
}

class _ShiftIdentityHeaderState extends State<ShiftIdentityHeader> {
  Timer? _ticker;
  late DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startTickerIfOpen();
  }

  @override
  void didUpdateWidget(covariant ShiftIdentityHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity.isOpen != widget.identity.isOpen) {
      _ticker?.cancel();
      _startTickerIfOpen();
    }
  }

  void _startTickerIfOpen() {
    if (!widget.identity.isOpen) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftIdentity identity = widget.identity;
    final Duration elapsed = identity.elapsedAt(_now);

    final List<Widget> facts = <Widget>[
      ShiftFactTile(
        label: ShiftStrings.shiftNumber,
        value: identity.shiftNumber,
      ),
      ShiftFactTile(
        label: ShiftStrings.branch,
        value: identity.branchName,
        numeric: false,
      ),
      ShiftFactTile(
        label: ShiftStrings.cashier,
        value: identity.cashierName,
        numeric: false,
        hint: '${ShiftStrings.employeeCode}: ${identity.cashierCode}',
      ),
      ShiftFactTile(
        label: ShiftStrings.openedAt,
        value: ShiftFormat.timeOfDay(identity.openedAt),
      ),
      ShiftFactTile(
        label: ShiftStrings.date,
        value: ShiftFormat.longDate(identity.openedAt),
        numeric: false,
      ),
      ShiftFactTile(
        label: ShiftStrings.duration,
        value: identity.isOpen
            ? ShiftFormat.stopwatch(elapsed)
            : ShiftFormat.humanDuration(elapsed),
        numeric: identity.isOpen,
      ),
      if (identity.closedAt != null)
        ShiftFactTile(
          label: ShiftStrings.closedAt,
          value: ShiftFormat.timeOfDay(identity.closedAt!),
        ),
    ];

    return ShiftCard(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: widget.compact ? AppSpacing.md : AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!widget.compact) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.badge_outlined,
                  size: 17,
                  color: ShiftColors.inkMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    ShiftStrings.shiftInformation,
                    style: ShiftText.cardTitle,
                  ),
                ),
                ShiftStatusChip(lifecycle: identity.lifecycle),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 1000
                  ? facts.length.clamp(1, 7)
                  : constraints.maxWidth >= ShiftLayout.tabletBreakpoint
                  ? 3
                  : 2;
              final double spacing = AppSpacing.lg;
              final double itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  for (final Widget fact in facts)
                    SizedBox(width: itemWidth, child: fact),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Open/closed pill with the same visual language as the top-bar badge.
class ShiftStatusChip extends StatelessWidget {
  const ShiftStatusChip({super.key, required this.lifecycle});

  final ShiftLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final bool isOpen = lifecycle == ShiftLifecycle.open;
    final ShiftTone tone = isOpen ? ShiftTone.success : ShiftTone.neutral;
    return Container(
      key: const Key('shift-status-chip'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.ink.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone.ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? ShiftStrings.statusOpen : ShiftStrings.statusClosed,
            style: ShiftText.badge.copyWith(color: tone.ink),
          ),
        ],
      ),
    );
  }
}
