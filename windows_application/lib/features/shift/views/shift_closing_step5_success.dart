import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shift_route_locations.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/shift_closing_cubit.dart';
import '../controllers/shift_closing_state.dart';
import '../models/shift_models.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_strings.dart';

/// Step 5 — sealed. A receipt-style summary of the closed shift with
/// print / view-report / back-to-history actions.
class ShiftClosingStep5Success extends StatelessWidget {
  const ShiftClosingStep5Success({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
    builder: (BuildContext context, ShiftClosingState state) {
      final ShiftClosingResult result = state.result!;
      final ShiftSnapshot snapshot = result.snapshot;

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ShiftCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: ShiftColors.matchFill,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: ShiftColors.matchInk,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    ShiftStrings.closedSuccessfully,
                    style: ShiftText.pageTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ShiftStrings.closedSuccessfullyBody,
                    style: ShiftText.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: ShiftColors.subtleFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ShiftColors.border),
                    ),
                    child: Column(
                      children: <Widget>[
                        _row(ShiftStrings.shiftNumber, snapshot.identity.shiftNumber),
                        _row(ShiftStrings.branch, snapshot.identity.branchName, numeric: false),
                        _row(ShiftStrings.cashier, snapshot.identity.cashierName, numeric: false),
                        _row(
                          ShiftStrings.openedAt,
                          ShiftFormat.timeOfDay(snapshot.identity.openedAt),
                        ),
                        _row(ShiftStrings.closedAt, ShiftFormat.timeOfDay(result.closedAt)),
                        _row(ShiftStrings.duration, ShiftFormat.humanDuration(result.duration)),
                        const ShiftDividerLine(),
                        _row(ShiftStrings.orderCount, ShiftFormat.count(snapshot.sales.orderCount)),
                        _row(ShiftStrings.netSales, ShiftFormat.money(snapshot.sales.netSales)),
                        _row(ShiftStrings.cashSales, ShiftFormat.money(snapshot.drawer.cashSales)),
                        _row(ShiftStrings.actualCash, ShiftFormat.money(result.cash.actual)),
                        _row(
                          ShiftStrings.cashDifference,
                          ShiftFormat.signedMoney(result.cash.difference),
                          color: result.cash.isBalanced
                              ? ShiftColors.matchInk
                              : ShiftColors.shortageInk,
                        ),
                        _row(
                          ShiftStrings.barDifferenceCount,
                          ShiftFormat.count(snapshot.barCount.differenceItems),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: <Widget>[
                      ShiftButton(
                        label: ShiftStrings.printShiftReport,
                        variant: ShiftButtonVariant.secondary,
                        icon: Icons.print_outlined,
                        onPressed: () =>
                            context.push(ShiftRouteLocations.report(snapshot.identity.shiftNumber)),
                      ),
                      ShiftButton(
                        buttonKey: const Key('shift-success-view-report'),
                        label: ShiftStrings.viewReport,
                        icon: Icons.description_outlined,
                        onPressed: () =>
                            context.push(ShiftRouteLocations.report(snapshot.identity.shiftNumber)),
                      ),
                      ShiftButton(
                        label: ShiftStrings.backToHistory,
                        variant: ShiftButtonVariant.quiet,
                        icon: Icons.history_outlined,
                        onPressed: () => context.go(ShiftRouteLocations.history),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _row(String label, String value, {bool numeric = true, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label, style: ShiftText.body)),
        if (numeric)
          ShiftValue(value, style: ShiftText.bodyStrong, color: color)
        else
          Text(value, style: ShiftText.bodyStrong.copyWith(color: color)),
      ],
    ),
  );
}
