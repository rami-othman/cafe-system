import 'package:flutter/material.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/discount_settings.dart';

/// Plain-language summary of the Cafe Discount Policy as it is enforced.
class DiscountSettingsSummary extends StatelessWidget {
  const DiscountSettingsSummary({super.key, required this.draft});
  final DiscountSettingsDraft draft;
  @override
  Widget build(BuildContext c) {
    final l = c.l10n, p = draft.policy;
    String allowed(bool value) => value ? l.ds3Allowed : l.ds3NotAllowed;
    final cap = draft.maximumTotalDiscountPercent.trim();
    final rows = [
      p.allowMultipleDiscounts
          ? l.ds3UpToDiscounts(p.effectiveMaximumDiscounts)
          : l.ds3OneDiscount,
      if (p.allowMultipleDiscounts) ...[
        p.stackingMode == 'same_item_allowed'
            ? l.ds3StackingSame
            : l.ds3StackingDifferent,
        '${l.ds3AllowCoupons}: ${allowed(p.allowMultipleCoupons)}',
        '${l.ds3AllowCouponConfigured}: ${allowed(p.allowCouponWithConfigured)}',
        '${l.ds3AllowOrderAfterItems}: ${allowed(p.allowOrderAfterItemDiscounts)}',
      ],
      cap.isEmpty ? l.ds3NoCap : l.ds3CapValue(cap),
      p.conflictResolution == 'priority' ? l.ds3PriorityRule : l.ds3BestSaving,
    ];
    return Column(
      key: const Key('ds-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text('• $row'),
          ),
      ],
    );
  }
}
