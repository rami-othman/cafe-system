import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
import 'discount_engine_widgets.dart';

class QuotedPaymentDialog extends StatefulWidget {
  const QuotedPaymentDialog({super.key});
  @override
  State<QuotedPaymentDialog> createState() => _QuotedPaymentDialogState();
}

class _QuotedPaymentDialogState extends State<QuotedPaymentDialog> {
  final _amount = TextEditingController();
  String? _shownQuote, _shownTotal;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PosCubit>().obtainPaymentQuote(null);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => BlocBuilder<PosCubit, PosState>(
    builder: (c, state) {
      final w = state.discounts,
          q = w.quote,
          l = c.l10n,
          cubit = c.read<PosCubit>();
      if (q != null && q.quoteId != _shownQuote) {
        _shownQuote = q.quoteId;
        // A refreshed quote (e.g. discounts changed) replaces an amount that
        // was only the previous total; a typed cash amount is kept.
        if (_amount.text.isEmpty || _amount.text == _shownTotal) {
          _amount.text = q.resolution.totals.total;
        }
        _shownTotal = q.resolution.totals.total;
      }
      final waiting = w.busy || state.isPaymentSubmitting;
      final uncertain = state.uncertainPaymentOrderId != null;
      final canPay =
          q != null &&
          !q.resolution.provisional &&
          (q.paymentMethodId != null || q.resolution.totals.total == '0.00') &&
          !waiting &&
          !uncertain &&
          w.totalsResolved &&
          !state.isCartMutationInProgress &&
          RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(_amount.text.trim());
      return PopScope(
        canPop: !waiting,
        child: AlertDialog(
          title: Text(l.d2Quote),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (waiting) const LinearProgressIndicator(),
                  DropdownButtonFormField<int>(
                    key: ValueKey('quoted-tender-${q?.quoteId}'),
                    initialValue: q?.paymentMethodId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.d2ChooseTender),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(l.d2ZeroBalance),
                      ),
                      for (final m in w.paymentMethods)
                        DropdownMenuItem(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: waiting || uncertain
                        ? null
                        : (id) => cubit.obtainPaymentQuote(id),
                  ),
                  if (q != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    ExactDiscountTotals(totals: q.resolution.totals),
                    if (q.resolution.discounts.isNotEmpty ||
                        q.resolution.excluded.isNotEmpty)
                      DiscountResolutionSummary(resolution: q.resolution),
                    if (q.resolution.provisional) Text(l.d2Provisional),
                  ],
                  TextField(
                    key: const Key('quoted-amount'),
                    controller: _amount,
                    enabled: !waiting && !uncertain,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l.posAmountReceived),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (w.errorCode != null)
                    Text(localizedDiscountError(l, w.errorCode)),
                  if (uncertain) Text(l.d2Uncertain),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: waiting ? null : () => Navigator.pop(c),
              child: Text(l.commonCancel),
            ),
            if (uncertain)
              TextButton(
                onPressed: waiting
                    ? null
                    : () async {
                        await cubit.checkUncertainPaymentStatus();
                        if (c.mounted && cubit.state.currentOrderId == null) {
                          Navigator.pop(c);
                        }
                      },
                child: Text(l.d2Recover),
              )
            else if (q == null)
              TextButton(
                onPressed: waiting
                    ? null
                    : () => cubit.obtainPaymentQuote(null),
                child: Text(l.commonRetry),
              )
            else
              FilledButton(
                key: const Key('quoted-payment-confirm'),
                onPressed: canPay
                    ? () async {
                        final result = await cubit.confirmQuotedPayment(
                          q.quoteId,
                          _amount.text.trim(),
                        );
                        if (result == PaymentCompletionStatus.completed &&
                            c.mounted) {
                          Navigator.pop(c);
                        }
                      }
                    : null,
                child: Text(l.d2QuoteConfirm),
              ),
          ],
        ),
      );
    },
  );
}
