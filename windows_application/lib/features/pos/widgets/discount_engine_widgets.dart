import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
import '../models/discount_engine.dart';

/// Formats a backend decimal string ("1234.50") with the same shared convention
/// as the POS totals panel, so every discount amount reads like the cart
/// beside it. Display only: the backend remains the monetary authority.
/// A [negative] amount shows a leading minus, except for zero.
String discountMoney(String? amount, {bool negative = false}) {
  final double? value = double.tryParse(amount ?? '');
  if (value == null) return amount ?? '';
  final String text = CurrencyFormatter.format(value.abs());
  return negative && value != 0 ? '-$text' : text;
}

String discountSource(AppLocalizations l, String? source) => switch (source) {
  'automatic' => l.d2SourceAutomatic,
  'code' => l.d2SourceCode,
  'configured_manual' => l.d2SourceManual,
  'ad_hoc' => l.d2SourceAdHoc,
  _ => l.posDiscount,
};

/// Why the backend did not apply a requested discount. Stable V3 codes only;
/// an unknown code falls back to the generic eligibility message.
String localizedExclusionReason(AppLocalizations l, String code) =>
    switch (code) {
      'MULTIPLE_DISCOUNTS_DISABLED' => l.d3ReasonMultipleDisabled,
      'SAME_ITEM_STACKING_DISABLED' => l.d3ReasonSameItem,
      'MULTIPLE_COUPONS_DISABLED' => l.d3ReasonMultipleCoupons,
      'COUPON_COMBINATION_NOT_ALLOWED' => l.d3ReasonCouponCombination,
      'ORDER_ITEM_COMBINATION_NOT_ALLOWED' => l.d3ReasonOrderItem,
      'EXCLUSIVE_DISCOUNT_CONFLICT' => l.d3ReasonExclusive,
      'MAXIMUM_DISCOUNT_COUNT_EXCEEDED' => l.d3ReasonMaxCount,
      'MAXIMUM_TOTAL_DISCOUNT_EXCEEDED' => l.d3ReasonMaxTotal,
      'DISCOUNT_ITEMS_NOT_ELIGIBLE' => l.d3ReasonNoItems,
      'DISCOUNT_CONFLICT' => l.d3ReasonConflict,
      _ => localizedDiscountError(l, code),
    };

String localizedDiscountError(AppLocalizations l, Object? error) {
  final code = error is ApiException
      ? error.code
      : error is String
      ? error
      : null;
  return switch (code) {
    'D2_UNCERTAIN' => l.d2Uncertain,
    'D2_SYNC' => l.d2Sync,
    'DISCOUNT_ENGINE_NOT_READY' => l.dsActivationUnavailable,
    'DISCOUNT_REVIEW_REQUIRED' || 'DISCOUNT_REVIEW_STALE' => l.d2FreshReview,
    'PAYMENT_QUOTE_REQUIRED' || 'ORDER_TOTAL_CHANGED' => l.d2QuoteChanged,
    'DISCOUNT_SETTINGS_FORBIDDEN' ||
    'DISCOUNT_SUPPRESSION_FORBIDDEN' ||
    'DISCOUNT_SUPPRESSION_DISABLED' => l.d2Forbidden,
    'PAYMENT_METHOD_INVALID' || 'PAYMENT_TENDER_REQUIRED' => l.d2ChooseTender,
    'DISCOUNT_CLIENT_UPDATE_REQUIRED' => l.d2UpdateRequired,
    'ACCOUNTING_CONFIGURATION_MISSING' => l.d2Configuration,
    'INSUFFICIENT_STOCK' => l.d2Stock,
    'PAYMENT_VALIDATION_FAILED' => l.d2Validation,
    'D2_FORBIDDEN' => l.d2Forbidden,
    'DISCOUNT_OPERATION_CONFLICT' ||
    'PAYMENT_IDEMPOTENCY_CONFLICT' ||
    'ORDER_IDEMPOTENCY_CONFLICT' => l.d2Uncertain,
    'ORDER_NOT_RESUMABLE' ||
    'ORDER_ALREADY_PAID' ||
    'ORDER_NOT_EDITABLE' ||
    'ORDER_PAYMENT_NOT_ALLOWED' => l.d2Lifecycle,
    'NO_OPEN_SHIFT' => l.posOpenShiftRequired,
    'DISCOUNT_DUPLICATE_INTENT' => l.d3Duplicate,
    'MAXIMUM_DISCOUNT_COUNT_EXCEEDED' => l.d3ReasonMaxCount,
    'MULTIPLE_DISCOUNTS_DISABLED' ||
    'SAME_ITEM_STACKING_DISABLED' ||
    'MULTIPLE_COUPONS_DISABLED' ||
    'COUPON_COMBINATION_NOT_ALLOWED' ||
    'ORDER_ITEM_COMBINATION_NOT_ALLOWED' ||
    'EXCLUSIVE_DISCOUNT_CONFLICT' ||
    'MAXIMUM_TOTAL_DISCOUNT_EXCEEDED' ||
    'DISCOUNT_CONFLICT' => localizedExclusionReason(l, code!),
    'COUPON_ATTEMPTS_THROTTLED' => l.d4CouponThrottled,
    'DISCOUNT_NOT_FOUND' => l.d4CouponInvalid,
    'DISCOUNT_AD_HOC_DISABLED' ||
    'DISCOUNT_APPLICATION_MODE_INVALID' ||
    'DISCOUNT_INACTIVE' ||
    'DISCOUNT_NOT_STARTED' ||
    'DISCOUNT_EXPIRED' ||
    'DISCOUNT_DAY_NOT_ALLOWED' ||
    'DISCOUNT_TIME_NOT_ALLOWED' ||
    'DISCOUNT_BRANCH_NOT_ELIGIBLE' ||
    'DISCOUNT_CHANNEL_NOT_ELIGIBLE' ||
    'DISCOUNT_CUSTOMER_NOT_ELIGIBLE' ||
    'DISCOUNT_CUSTOMER_REQUIRED' ||
    'DISCOUNT_MINIMUM_NOT_MET' ||
    'DISCOUNT_ITEMS_NOT_ELIGIBLE' ||
    'DISCOUNT_PAYMENT_METHOD_NOT_ALLOWED' ||
    'DISCOUNT_USAGE_LIMIT_REACHED' ||
    'DISCOUNT_DAILY_USAGE_LIMIT_REACHED' ||
    'DISCOUNT_BOGO_UNSUPPORTED' => l.d2Eligibility,
    _ => l.d2Generic,
  };
}

/// Authoritative per-discount lines in backend application order. Amounts are
/// shown exactly as returned; nothing is recalculated here.
class DiscountBreakdown extends StatelessWidget {
  const DiscountBreakdown({
    super.key,
    required this.discounts,
    this.onRemove,
    this.total,
  });
  final List<SavedDiscount> discounts;

  /// Called with the policy id of a removable (explicit) discount.
  final ValueChanged<int>? onRemove;

  /// The backend discount total; shown as "Total discounts" when more than
  /// one discount applies. Never summed on the client.
  final String? total;

  static List<SavedDiscount> ordered(List<SavedDiscount> discounts) {
    final indexed = discounts.indexed.toList();
    indexed.sort(
      (a, b) =>
          (a.$2.sequence ?? 1 << 30).compareTo(b.$2.sequence ?? 1 << 30) != 0
          ? (a.$2.sequence ?? 1 << 30).compareTo(b.$2.sequence ?? 1 << 30)
          : a.$1.compareTo(b.$1),
    );
    return [for (final entry in indexed) entry.$2];
  }

  @override
  Widget build(BuildContext c) {
    final l = c.l10n;
    final rows = ordered(discounts);
    final numbered = rows.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, d) in rows.indexed)
          Padding(
            key: Key('discount-line-${d.discountId ?? 'x$index'}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        numbered ? '${index + 1}. ${d.name}' : d.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        discountSource(l, d.source),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (d.capped)
                        Text(
                          l.d3Capped,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  discountMoney(d.amount, negative: true),
                  textDirection: TextDirection.ltr,
                ),
                if (onRemove != null &&
                    d.discountId != null &&
                    d.source != 'automatic')
                  IconButton(
                    key: Key('discount-remove-${d.discountId}'),
                    tooltip: l.d3RemoveDiscount,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onRemove!(d.discountId!),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
          ),
        if (total != null && rows.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.d3TotalDiscounts,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  discountMoney(total, negative: true),
                  key: const Key('discount-lines-total'),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Requested discounts the backend did not apply, each with its reason.
class ExcludedDiscountList extends StatelessWidget {
  const ExcludedDiscountList({super.key, required this.excluded});
  final List<ExcludedDiscount> excluded;
  @override
  Widget build(BuildContext c) {
    final l = c.l10n;
    if (excluded.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('discount-excluded-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            l.d3NotApplied,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.dangerStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final e in excluded)
          Padding(
            key: Key('discount-excluded-${e.discountId ?? e.position}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.block,
                  size: 16,
                  color: AppColors.dangerStrong,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.name ?? l.d3UnknownDiscount} · ${discountSource(l, e.source)}',
                      ),
                      Text(
                        localizedExclusionReason(l, e.code),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Applied + not-applied result of a backend resolution (review or quote).
class DiscountResolutionSummary extends StatelessWidget {
  const DiscountResolutionSummary({super.key, required this.resolution});
  final DiscountResolution resolution;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        c.l10n.d3Applied,
        style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w800),
      ),
      if (resolution.discounts.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(c.l10n.d3NothingApplied),
        )
      else
        DiscountBreakdown(
          discounts: resolution.discounts,
          total: resolution.totals.discountTotal,
        ),
      ExcludedDiscountList(excluded: resolution.excluded),
    ],
  );
}

class ExactDiscountTotals extends StatelessWidget {
  const ExactDiscountTotals({super.key, required this.totals});
  final DiscountTotals totals;
  @override
  Widget build(BuildContext c) => Column(
    children: [
      for (final row in [
        (c.l10n.posSubtotal, totals.subtotal),
        (c.l10n.posDiscount, totals.discountTotal),
        (c.l10n.cafeConfigurationTax, totals.taxTotal),
        (c.l10n.posTotal, totals.total),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(child: Text(row.$1)),
              Flexible(
                child: Text(
                  discountMoney(row.$2),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

Future<void> showDiscountReview(
  BuildContext context,
  PosCubit cubit,
  DiscountReviewRequest request,
) => showDiscountChangeReview(
  context,
  cubit,
  () => cubit.previewDiscountChange(request),
);

/// Previews a change with [preview] (which builds the request against fresh
/// backend state), then lets the cashier confirm the authoritative result.
Future<void> showDiscountChangeReview(
  BuildContext context,
  PosCubit cubit,
  Future<bool> Function() preview,
) async {
  await preview();
  if (!context.mounted || cubit.isClosed) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DiscountReviewDialog(preview: preview),
    ),
  );
}

class _DiscountReviewDialog extends StatelessWidget {
  const _DiscountReviewDialog({required this.preview});
  final Future<bool> Function() preview;
  @override
  Widget build(BuildContext c) => BlocBuilder<PosCubit, PosState>(
    builder: (c, state) {
      final w = state.discounts, l = c.l10n, cubit = c.read<PosCubit>();
      final r = w.review;
      return PopScope(
        canPop: !w.busy,
        child: AlertDialog(
          title: Text(l.d2Review),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (w.busy) const LinearProgressIndicator(),
                  if (r != null) ...[
                    Text(
                      l.d3ReviewHelp,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DiscountResolutionSummary(resolution: r.resolution),
                    const Divider(),
                    Text(l.d2Before),
                    ExactDiscountTotals(totals: r.before),
                    const Divider(),
                    Text(l.d2After),
                    ExactDiscountTotals(totals: r.after),
                    if (r.resolution.provisional) Text(l.d2Provisional),
                  ],
                  if (w.errorCode != null)
                    Text(
                      localizedDiscountError(l, w.errorCode),
                      key: const Key('discount-review-error'),
                      style: const TextStyle(color: AppColors.dangerStrong),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: w.busy ? null : () => Navigator.pop(c),
              child: Text(l.commonCancel),
            ),
            if (w.operationUncertain)
              TextButton(
                onPressed: w.busy
                    ? null
                    : () async {
                        final confirmed = await cubit.recoverDiscountChange();
                        if (confirmed && c.mounted) Navigator.pop(c);
                      },
                child: Text(l.d2Recover),
              )
            else if (r == null)
              TextButton(
                onPressed: w.busy ? null : preview,
                child: Text(l.commonRetry),
              )
            else
              FilledButton(
                key: const Key('discount-review-confirm'),
                onPressed: w.busy
                    ? null
                    : () async {
                        final success = await cubit.confirmDiscountReview(
                          r.reviewId,
                        );
                        if (success && c.mounted) {
                          Navigator.pop(c);
                        } else if (c.mounted &&
                            cubit.state.discounts.errorCode ==
                                'DISCOUNT_REVIEW_STALE') {
                          // Never apply an outdated result: show the fresh one.
                          await preview();
                        }
                      },
                child: Text(l.d2ConfirmReview),
              ),
          ],
        ),
      );
    },
  );
}

Future<String?> requestSuppressionReason(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, change) => AlertDialog(
        title: Text(c.l10n.d2Suppress),
        content: TextField(
          key: const Key('suppression-reason'),
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(labelText: c.l10n.d2Reason),
          onChanged: (_) => change(() {}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(c.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(c, controller.text.trim()),
            child: Text(c.l10n.d2Review),
          ),
        ],
      ),
    ),
  );
  // Dialog route animations may still own the field for one frame.
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  return result;
}
