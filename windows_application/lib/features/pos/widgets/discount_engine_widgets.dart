import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
import '../models/discount_engine.dart';

String discountSource(AppLocalizations l, String? source) => switch (source) {
  'automatic' => l.d2SourceAutomatic,
  'code' => l.d2SourceCode,
  'configured_manual' => l.d2SourceManual,
  'ad_hoc' => l.d2SourceAdHoc,
  _ => l.posDiscount,
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
    'DISCOUNT_NOT_FOUND' ||
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

class DiscountBreakdown extends StatelessWidget {
  const DiscountBreakdown({super.key, required this.discounts});
  final List<SavedDiscount> discounts;
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final d in discounts)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${d.name}\n${discountSource(c.l10n, d.source)}',
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text('-${d.amount}', textDirection: TextDirection.ltr),
              ),
            ],
          ),
        ),
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
              Flexible(child: Text(row.$2, textDirection: TextDirection.ltr)),
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
) async {
  await cubit.previewDiscountChange(request);
  if (!context.mounted || cubit.isClosed) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _DiscountReviewDialog(request: request),
    ),
  );
}

class _DiscountReviewDialog extends StatelessWidget {
  const _DiscountReviewDialog({required this.request});
  final DiscountReviewRequest request;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (w.busy) const LinearProgressIndicator(),
                  if (r != null) ...[
                    Text(l.d2Before),
                    ExactDiscountTotals(totals: r.before),
                    DiscountBreakdown(discounts: r.removals),
                    const Divider(),
                    Text(l.d2After),
                    ExactDiscountTotals(totals: r.after),
                    Text(l.d2Replacements),
                    DiscountBreakdown(discounts: r.additions),
                    if (r.resolution.provisional) Text(l.d2Provisional),
                  ],
                  if (w.errorCode != null)
                    Text(localizedDiscountError(l, w.errorCode)),
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
                onPressed: w.busy
                    ? null
                    : () => cubit.previewDiscountChange(request),
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
                        if (success && c.mounted) Navigator.pop(c);
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
