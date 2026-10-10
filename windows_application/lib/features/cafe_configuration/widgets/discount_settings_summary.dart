import 'package:flutter/material.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../shared/widgets/settings_ui.dart';
import '../models/discount_settings.dart';

/// Plain-language summary of the Cafe Discount Policy as it is enforced.
class DiscountSettingsSummary extends StatelessWidget {
  const DiscountSettingsSummary({super.key, required this.draft});
  final DiscountSettingsDraft draft;
  @override
  Widget build(BuildContext c) {
    final l = c.l10n, p = draft.policy;
    final cap = draft.maximumTotalDiscountPercent.trim();
    final rows = <SettingsSummaryRow>[
      SettingsSummaryRow(
        text: p.allowMultipleDiscounts
            ? l.ds3UpToDiscounts(p.effectiveMaximumDiscounts)
            : l.ds3OneDiscount,
      ),
      SettingsSummaryRow(text: l.ds5Automatic, enabled: draft.automaticEnabled),
      if (p.allowMultipleDiscounts) ...[
        SettingsSummaryRow(
          text: p.stackingMode == 'same_item_allowed'
              ? l.ds3StackingSame
              : l.ds3StackingDifferent,
        ),
        SettingsSummaryRow(
          text: l.ds3AllowCoupons,
          enabled: p.allowMultipleCoupons,
        ),
        SettingsSummaryRow(
          text: l.ds3AllowCouponConfigured,
          enabled: p.allowCouponWithConfigured,
        ),
        SettingsSummaryRow(
          text: l.ds3AllowOrderAfterItems,
          enabled: p.allowOrderAfterItemDiscounts,
        ),
      ],
      SettingsSummaryRow(text: cap.isEmpty ? l.ds3NoCap : l.ds3CapValue(cap)),
      SettingsSummaryRow(
        text: p.conflictResolution == 'priority'
            ? l.ds3PriorityRule
            : l.ds3BestSaving,
      ),
    ];
    return Column(
      key: const Key('ds-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}
