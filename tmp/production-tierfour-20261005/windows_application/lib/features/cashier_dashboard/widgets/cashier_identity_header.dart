import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/cashier_dashboard.dart';
import 'cashier_dashboard_widgets.dart';

/// Who is on the till, where, and on which shift. When no shift is open this
/// says so plainly instead of showing a dormant shift number.
class CashierIdentityHeader extends StatefulWidget {
  const CashierIdentityHeader({
    super.key,
    required this.scope,
    required this.shift,
  });

  final CashierScope scope;
  final CashierShift? shift;

  @override
  State<CashierIdentityHeader> createState() => _CashierIdentityHeaderState();
}

class _CashierIdentityHeaderState extends State<CashierIdentityHeader> {
  Timer? _ticker;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // durationSeconds is only a snapshot from the last load; ticking off the
    // shift's openedAt keeps the header live between dashboard reloads.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CashierScope scope = widget.scope;
    final CashierShift? shift = widget.shift;
    final bool open = shift != null;
    final DateTime? openedAt = shift?.openedAt;
    final int liveDurationSeconds = openedAt == null
        ? shift?.durationSeconds ?? 0
        : _now.difference(openedAt).inSeconds;
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.panel,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _Field(
            label: context.l10n.cashierBranchLabel,
            value: scope.branchName.isEmpty ? '—' : scope.branchName,
          ),
          _Field(
            label: context.l10n.cashierNameLabel,
            value: scope.cashierName.isEmpty ? '—' : scope.cashierName,
          ),
          if (open) ...<Widget>[
            _Field(
              label: context.l10n.cashierShiftLabel,
              value: '#${shift.id}',
            ),
            _Field(
              label: context.l10n.cashierShiftOpenedAt,
              value: _clock(shift.openedAt),
            ),
            _Field(
              label: context.l10n.cashierShiftDuration,
              value: formatCashierDuration(liveDurationSeconds),
            ),
            CashierStateBadge(
              label: context.l10n.cashierShiftStatusOpen,
              colour: AppColors.success,
            ),
          ] else
            _Field(
              label: context.l10n.cashierShiftStatus,
              value: context.l10n.cashierNoOpenShift,
              hint: context.l10n.cashierNoOpenShiftHint,
            ),
        ],
      ),
    );
  }

  static String _clock(DateTime? value) {
    if (value == null) return '—';
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

String formatCashierDuration(int seconds) {
  final int safe = seconds < 0 ? 0 : seconds;
  final String hours = (safe ~/ 3600).toString().padLeft(2, '0');
  final String minutes = ((safe % 3600) ~/ 60).toString().padLeft(2, '0');
  return '$hours:$minutes';
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 2),
      Text(value, style: AppTextStyles.titleMedium),
      if (hint case final String text) ...<Widget>[
        const SizedBox(height: 2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    ],
  );
}
