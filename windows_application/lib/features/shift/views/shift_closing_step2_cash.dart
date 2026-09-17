import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../controllers/shift_closing_cubit.dart';
import '../controllers/shift_closing_state.dart';
import '../models/shift_models.dart';
import '../repositories/shift_mock_repository.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_strings.dart';
import 'shift_closing_screen.dart';

/// Step 2 — the cash drawer count. Shows the direct-amount field or the
/// denomination counter, reveals the reconciliation only once an actual
/// amount exists, and requires a reason once a real difference appears.
class ShiftClosingStep2Cash extends StatefulWidget {
  const ShiftClosingStep2Cash({super.key});

  @override
  State<ShiftClosingStep2Cash> createState() => _ShiftClosingStep2CashState();
}

class _ShiftClosingStep2CashState extends State<ShiftClosingStep2Cash> {
  late TextEditingController _amountController;
  late final TextEditingController _reasonDetailController;
  final Map<int, TextEditingController> _denomControllers = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final ShiftClosingState state = context.read<ShiftClosingCubit>().state;
    _amountController = TextEditingController(text: state.cashActualInput);
    _reasonDetailController = TextEditingController(text: state.cashReasonDetail);
    for (final int d in ShiftMockData.denominations) {
      _denomControllers[d] = TextEditingController(text: state.denominationCounts[d] ?? '');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonDetailController.dispose();
    for (final TextEditingController c in _denomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
    builder: (BuildContext context, ShiftClosingState state) {
      final ShiftClosingCubit cubit = context.read<ShiftClosingCubit>();
      final CashCountResult? cash = state.cashCount;

      if (_amountController.text != state.cashActualInput &&
          !_amountController.value.selection.isValid) {
        _amountController.text = state.cashActualInput;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftWizardStepHeader(
            title: ShiftStrings.cashCountTitle,
            subtitle: ShiftStrings.cashCountSubtitle,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ShiftSegmentedControl<CashCountMode>(
                  selected: state.cashMode,
                  segments: const <ShiftSegment<CashCountMode>>[
                    ShiftSegment(
                      value: CashCountMode.direct,
                      label: ShiftStrings.enterAmountDirectly,
                      icon: Icons.edit_outlined,
                    ),
                    ShiftSegment(
                      value: CashCountMode.denominations,
                      label: ShiftStrings.countByDenomination,
                      icon: Icons.calculate_outlined,
                    ),
                  ],
                  onChanged: cubit.setCashMode,
                ),
                const SizedBox(height: AppSpacing.lg),
                ShiftField(
                  label: ShiftStrings.actualCashLabel,
                  isRequired: true,
                  error: state.cashActualError,
                  child: ShiftNumberField(
                    fieldKey: const Key('shift-cash-actual-field'),
                    controller: _amountController,
                    allowDecimal: true,
                    large: true,
                    hasError: state.cashActualError != null,
                    hintText: '0',
                    suffix: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Center(widthFactor: 1, child: _CurrencySuffix()),
                    ),
                    onChanged: cubit.updateActualCash,
                  ),
                ),
                if (state.cashMode == CashCountMode.denominations) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _DenominationPanel(
                    state: state,
                    controllers: _denomControllers,
                    cubit: cubit,
                  ),
                ],
                if (cash != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _Reconciliation(cash: cash, state: state, cubit: cubit),
                ],
                if (state.requiresCashReason) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _ReasonSection(
                    state: state,
                    cubit: cubit,
                    controller: _reasonDetailController,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _CurrencySuffix extends StatelessWidget {
  const _CurrencySuffix();

  @override
  Widget build(BuildContext context) =>
      Text(ShiftFormat.currencySuffix, style: ShiftText.bodyStrong);
}

class _DenominationPanel extends StatelessWidget {
  const _DenominationPanel({
    required this.state,
    required this.controllers,
    required this.cubit,
  });

  final ShiftClosingState state;
  final Map<int, TextEditingController> controllers;
  final ShiftClosingCubit cubit;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final int denom in ShiftMockData.denominations)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 90,
                  child: ShiftValue(ShiftFormat.amount(denom), style: ShiftText.bodyStrong),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('×', style: ShiftText.body),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 76,
                  child: ShiftNumberField(
                    fieldKey: Key('shift-denom-field-$denom'),
                    controller: controllers[denom]!,
                    textAlign: TextAlign.center,
                    hintText: '0',
                    onChanged: (String v) => cubit.updateDenomination(denom, v),
                  ),
                ),
                const Spacer(),
                ShiftValue(
                  ShiftFormat.money((int.tryParse(controllers[denom]!.text) ?? 0) * denom),
                  style: ShiftText.bodyStrong,
                ),
              ],
            ),
          ),
        const ShiftDividerLine(),
        ShiftKeyValueRow(
          label: ShiftStrings.countedTotal,
          value: ShiftFormat.money(state.denominationTotal),
          emphasize: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        ShiftButton(
          key: const Key('shift-apply-denomination-total'),
          label: ShiftStrings.applyCountedAmount,
          expand: true,
          onPressed: cubit.applyDenominationTotal,
        ),
      ],
    ),
  );
}

class _Reconciliation extends StatelessWidget {
  const _Reconciliation({required this.cash, required this.state, required this.cubit});

  final CashCountResult cash;
  final ShiftClosingState state;
  final ShiftClosingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final ShiftTone tone = cash.isBalanced
        ? ShiftTone.success
        : cash.isShortage
        ? ShiftTone.warning
        : ShiftTone.surplus;
    final String label = cash.isBalanced
        ? ShiftStrings.cashMatched
        : cash.isShortage
        ? ShiftStrings.cashShortage
        : ShiftStrings.cashSurplus;

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftSectionHeader(
            title: ShiftStrings.cashReconciliation,
            icon: Icons.balance_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          ShiftKeyValueRow(
            label: ShiftStrings.expectedCash,
            value: ShiftFormat.money(cash.expected),
          ),
          ShiftKeyValueRow(
            label: ShiftStrings.actualCash,
            value: ShiftFormat.money(cash.actual),
          ),
          const ShiftDividerLine(),
          ShiftKeyValueRow(
            label: ShiftStrings.cashDifference,
            value: ShiftFormat.signedMoney(cash.difference),
            valueColor: tone.ink,
            emphasize: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          ShiftBadge(label: label, tone: tone),
        ],
      ),
    );
  }
}

class _ReasonSection extends StatelessWidget {
  const _ReasonSection({required this.state, required this.cubit, required this.controller});

  final ShiftClosingState state;
  final ShiftClosingCubit cubit;
  final TextEditingController controller;

  static const List<(CashDifferenceReason, String)> _reasons = <(CashDifferenceReason, String)>[
    (CashDifferenceReason.changeError, ShiftStrings.reasonChangeError),
    (CashDifferenceReason.unrecordedTransaction, ShiftStrings.reasonUnrecordedTransaction),
    (CashDifferenceReason.unrecordedWithdrawal, ShiftStrings.reasonUnrecordedWithdrawal),
    (CashDifferenceReason.unrecordedExpense, ShiftStrings.reasonUnrecordedExpense),
    (CashDifferenceReason.unknownSurplus, ShiftStrings.reasonUnknownSurplus),
    (CashDifferenceReason.unknownShortage, ShiftStrings.reasonUnknownShortage),
    (CashDifferenceReason.other, ShiftStrings.reasonOther),
  ];

  @override
  Widget build(BuildContext context) => ShiftField(
    label: ShiftStrings.cashDifferenceReason,
    isRequired: true,
    error: state.cashReasonError,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final (CashDifferenceReason reason, String label) in _reasons)
              ShiftFilterChip(
                label: label,
                isSelected: state.cashReason == reason,
                onTap: () => cubit.selectCashReason(reason),
              ),
          ],
        ),
        if (state.cashReason == CashDifferenceReason.other) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          ShiftField(
            label: ShiftStrings.additionalDetails,
            isRequired: true,
            error: state.cashReasonDetailError,
            child: ShiftTextArea(
              controller: controller,
              hintText: ShiftStrings.additionalDetailsHint,
              minLines: 2,
              hasError: state.cashReasonDetailError != null,
              onChanged: cubit.updateCashReasonDetail,
            ),
          ),
        ],
      ],
    ),
  );
}
