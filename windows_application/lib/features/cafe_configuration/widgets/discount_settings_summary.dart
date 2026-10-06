import 'package:flutter/material.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/discount_settings.dart';

class DiscountSettingsSummary extends StatelessWidget {
  const DiscountSettingsSummary({super.key, required this.draft});
  final DiscountSettingsDraft draft;
  @override
  Widget build(BuildContext c) {
    final l = c.l10n, d = draft;
    final rows = [
      (l.dsAutomatic, d.automaticEnabled ? l.commonActive : l.commonInactive),
      (
        l.dsStrategy,
        switch (d.selectionStrategy) {
          'highest_saving' => l.dsHighest,
          'lowest_saving' => l.dsLowest,
          _ => l.dsPriority,
        },
      ),
      (
        l.dsCombination,
        d.combinationMode == 'single' ? l.dsSingle : l.dsDisjoint,
      ),
      (
        l.dsOrderBehavior,
        d.orderDiscountBehavior == 'exclusive' ? l.dsExclusive : l.dsAfterItems,
      ),
      (
        l.dsCouponBehavior,
        d.couponBehavior == 'exclusive' ? l.dsExclusive : l.dsFollowRules,
      ),
      (
        l.dsManualBehavior,
        d.manualBehavior == 'exclusive' ? l.dsExclusive : l.dsFollowRules,
      ),
      (
        l.dsCap,
        d.maximumTotalDiscountPercent.isEmpty
            ? '—'
            : '${d.maximumTotalDiscountPercent}%',
      ),
      (
        l.dsAllowSuppression,
        d.allowAutomaticSuppression ? l.commonActive : l.commonInactive,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text('${row.$1}: ${row.$2}'),
          ),
      ],
    );
  }
}
