import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../controllers/shift_closing_cubit.dart';
import '../controllers/shift_closing_state.dart';
import '../models/shift_assessment.dart';
import '../models/shift_models.dart';
import '../widgets/shift_alerts_readiness.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_strings.dart';
import 'shift_closing_screen.dart';

/// Step 4 — the closing control center: every section the cashier and the
/// manager need to see before sealing the shift, a readiness checklist, and
/// the confirmation dialog gate.
class ShiftClosingStep4Review extends StatefulWidget {
  const ShiftClosingStep4Review({super.key});

  @override
  State<ShiftClosingStep4Review> createState() => _ShiftClosingStep4ReviewState();
}

class _ShiftClosingStep4ReviewState extends State<ShiftClosingStep4Review> {
  late final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
    builder: (BuildContext context, ShiftClosingState state) {
      final ShiftClosingCubit cubit = context.read<ShiftClosingCubit>();
      final ShiftSnapshot snapshot = state.snapshot!;
      final CashCountResult cash = state.cashCount!;
      final BarCountTemplate bar = state.barTemplate!;
      final ShiftAssessment assessment = state.assessment!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftWizardStepHeader(title: ShiftStrings.finalReviewTitle),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= ShiftLayout.desktopBreakpoint;
              final List<Widget> sections = <Widget>[
                ShiftReviewSection(
                  title: ShiftStrings.salesSummary,
                  icon: Icons.trending_up,
                  child: Column(
                    children: <Widget>[
                      ShiftKeyValueRow(
                        label: ShiftStrings.grossSales,
                        value: ShiftFormat.money(snapshot.sales.grossSales),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.totalDiscounts,
                        value: ShiftFormat.money(snapshot.sales.discounts),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.totalRefunds,
                        value: ShiftFormat.money(snapshot.sales.refunds),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.netSales,
                        value: ShiftFormat.money(snapshot.sales.netSales),
                        emphasize: true,
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.orderCount,
                        value: ShiftFormat.count(snapshot.sales.orderCount),
                      ),
                    ],
                  ),
                ),
                ShiftReviewSection(
                  title: ShiftStrings.cashDrawer,
                  icon: Icons.point_of_sale_outlined,
                  child: Column(
                    children: <Widget>[
                      ShiftKeyValueRow(
                        label: ShiftStrings.openingFloat,
                        value: ShiftFormat.money(snapshot.drawer.openingFloat),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.expectedCash,
                        value: ShiftFormat.money(cash.expected),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.actualCash,
                        value: ShiftFormat.money(cash.actual),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.cashDifference,
                        value: ShiftFormat.signedMoney(cash.difference),
                        valueColor: cash.isBalanced
                            ? ShiftColors.matchInk
                            : cash.isShortage
                            ? ShiftColors.shortageInk
                            : ShiftColors.surplusInk,
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
                ShiftReviewSection(
                  title: ShiftStrings.barCount,
                  icon: Icons.inventory_2_outlined,
                  child: Column(
                    children: <Widget>[
                      ShiftKeyValueRow(
                        label: ShiftStrings.itemsToCount,
                        value: ShiftFormat.count(bar.totalItems),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.statusMatch,
                        value: ShiftFormat.count(bar.matchedItems),
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.statusShortage,
                        value: ShiftFormat.count(bar.shortageItems),
                        valueColor: bar.shortageItems > 0 ? ShiftColors.shortageInk : null,
                      ),
                      ShiftKeyValueRow(
                        label: ShiftStrings.statusSurplus,
                        value: ShiftFormat.count(bar.surplusItems),
                        valueColor: bar.surplusItems > 0 ? ShiftColors.surplusInk : null,
                      ),
                      if (bar.differenceLines.isNotEmpty) ...<Widget>[
                        const ShiftDividerLine(),
                        for (final BarCountLine line in bar.differenceLines)
                          ShiftKeyValueRow(
                            label: line.name,
                            value: ShiftFormat.signedQuantity(
                              line.difference!,
                              line.decimals,
                            ),
                            valueColor: line.status == BarCountStatus.shortage
                                ? ShiftColors.shortageInk
                                : ShiftColors.surplusInk,
                          ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(ShiftStrings.noDifferences, style: ShiftText.label),
                        ),
                    ],
                  ),
                ),
              ];

              if (!wide) {
                return Column(
                  children: <Widget>[
                    for (final Widget s in sections) ...<Widget>[
                      s,
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < sections.length; i++) ...<Widget>[
                      Expanded(child: sections[i]),
                      if (i < sections.length - 1) const SizedBox(width: AppSpacing.lg),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftReadinessChecklist(items: assessment.readiness),
          const SizedBox(height: AppSpacing.lg),
          ShiftField(
            label: ShiftStrings.closingNotes,
            helper: ShiftStrings.closingNotesSaved,
            child: ShiftTextArea(
              controller: _notesController,
              hintText: ShiftStrings.closingNotesHint,
              onChanged: cubit.updateClosingNotes,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ShiftButton(
              buttonKey: const Key('shift-open-confirm-close'),
              label: ShiftStrings.confirmCloseShift,
              icon: Icons.lock_outline,
              large: true,
              onPressed: assessment.canClose
                  ? () => _openConfirmDialog(context, snapshot, cash, bar)
                  : null,
            ),
          ),
        ],
      );
    },
  );

  Future<void> _openConfirmDialog(
    BuildContext context,
    ShiftSnapshot snapshot,
    CashCountResult cash,
    BarCountTemplate bar,
  ) async {
    final ShiftClosingCubit cubit = context.read<ShiftClosingCubit>();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider<ShiftClosingCubit>.value(
        value: cubit,
        child: _ConfirmCloseDialog(snapshot: snapshot, cash: cash, bar: bar),
      ),
    );
  }
}

class _ConfirmCloseDialog extends StatefulWidget {
  const _ConfirmCloseDialog({required this.snapshot, required this.cash, required this.bar});

  final ShiftSnapshot snapshot;
  final CashCountResult cash;
  final BarCountTemplate bar;

  @override
  State<_ConfirmCloseDialog> createState() => _ConfirmCloseDialogState();
}

class _ConfirmCloseDialogState extends State<_ConfirmCloseDialog> {
  bool _acknowledged = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(ShiftStrings.confirmCloseShift, style: ShiftText.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            ShiftKeyValueRow(
              label: ShiftStrings.shiftNumber,
              value: widget.snapshot.identity.shiftNumber,
            ),
            ShiftKeyValueRow(
              label: ShiftStrings.cashier,
              value: widget.snapshot.identity.cashierName,
              numeric: false,
            ),
            ShiftKeyValueRow(
              label: ShiftStrings.netSales,
              value: ShiftFormat.money(widget.snapshot.sales.netSales),
            ),
            ShiftKeyValueRow(
              label: ShiftStrings.actualCash,
              value: ShiftFormat.money(widget.cash.actual),
            ),
            ShiftKeyValueRow(
              label: ShiftStrings.cashDifference,
              value: ShiftFormat.signedMoney(widget.cash.difference),
              valueColor: widget.cash.isBalanced
                  ? ShiftColors.matchInk
                  : ShiftColors.shortageInk,
            ),
            ShiftKeyValueRow(
              label: ShiftStrings.barDifferenceCount,
              value: ShiftFormat.count(widget.bar.differenceItems),
            ),
            const SizedBox(height: AppSpacing.md),
            const ShiftNotice(
              tone: ShiftTone.warning,
              message: ShiftStrings.closeShiftIrreversible,
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => setState(() => _acknowledged = !_acknowledged),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Checkbox(
                    key: const Key('shift-close-acknowledge-checkbox'),
                    value: _acknowledged,
                    onChanged: (bool? v) => setState(() => _acknowledged = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        ShiftStrings.confirmReviewedAcknowledgement,
                        style: ShiftText.bodyStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: ShiftButton(
                    label: ShiftStrings.backToReview,
                    variant: ShiftButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ShiftButton(
                    buttonKey: const Key('shift-close-confirm-button'),
                    label: ShiftStrings.closeShift,
                    onPressed: !_acknowledged || _submitting
                        ? null
                        : () async {
                            setState(() => _submitting = true);
                            await context.read<ShiftClosingCubit>().closeShift();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
