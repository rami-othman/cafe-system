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
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
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
                  if (result.closeExecutedAt != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'تاريخ الفترة: ${result.closingDate?.toIso8601String().substring(0, 10)} — تم التنفيذ: ${ShiftFormat.longDate(result.closeExecutedAt!)}',
                    ),
                  ],
                  if (result.continuationShiftId != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    const ShiftNotice(
                      message:
                          'وردية المتابعة مفتوحة على نفس الصندوق، وحركات الفترة اللاحقة محفوظة فيها.',
                      tone: ShiftTone.accent,
                    ),
                    TextButton(
                      onPressed: () => context.go(ShiftRouteLocations.current),
                      child: const Text('فتح وردية المتابعة'),
                    ),
                  ],
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
                        _row(
                          ShiftStrings.shiftNumber,
                          snapshot.identity.shiftNumber,
                        ),
                        _row(
                          ShiftStrings.branch,
                          snapshot.identity.branchName,
                          numeric: false,
                        ),
                        _row(
                          ShiftStrings.cashier,
                          snapshot.identity.cashierName,
                          numeric: false,
                        ),
                        _row(
                          ShiftStrings.openedAt,
                          ShiftFormat.timeOfDay(snapshot.identity.openedAt),
                        ),
                        _row(
                          ShiftStrings.closedAt,
                          ShiftFormat.timeOfDay(result.closedAt),
                        ),
                        _row(
                          ShiftStrings.duration,
                          ShiftFormat.humanDuration(result.duration),
                        ),
                        const ShiftDividerLine(),
                        _row(
                          ShiftStrings.orderCount,
                          ShiftFormat.count(snapshot.sales.orderCount),
                        ),
                        _row(
                          ShiftStrings.salesTotal,
                          ShiftFormat.money(snapshot.sales.salesTotal),
                        ),
                        _row(
                          ShiftStrings.netSales,
                          ShiftFormat.money(snapshot.sales.salesNet),
                        ),
                        _row(
                          ShiftStrings.cashSales,
                          ShiftFormat.money(snapshot.drawer.cashSales),
                        ),
                        _row(
                          ShiftStrings.actualCash,
                          ShiftFormat.money(result.cash.actual),
                        ),
                        _row(
                          ShiftStrings.cashDifference,
                          ShiftFormat.signedMoney(result.cash.difference),
                          color: result.cash.isBalanced
                              ? ShiftColors.matchInk
                              : ShiftColors.shortageInk,
                        ),
                        if (result.variance != null &&
                            !result.variance!.isZero)
                          _row(
                            ShiftStrings.cashDifferenceAccount,
                            result.variance!.accountCode == null
                                ? ShiftStrings.notApplicable
                                : result.variance!.journalEntryId == null
                                ? '${result.variance!.accountCode} — ${result.variance!.accountName ?? ''}'
                                : ShiftStrings.variancePosted(
                                    result.variance!.accountCode!,
                                    result.variance!.accountName ?? '',
                                    result.variance!.journalEntryId!,
                                  ),
                            numeric: false,
                          ),
                        if (result.transfer != null) ...<Widget>[
                          _row(
                            ShiftStrings.closeTransferDestination,
                            result.transfer!.wasSkipped
                                ? (result.transfer!.skippedReason ??
                                      ShiftStrings.notApplicable)
                                : (result.transfer!.destinationName ??
                                      ShiftStrings.notApplicable),
                            numeric: false,
                          ),
                          if (!result.transfer!.wasSkipped)
                            _row(
                              ShiftStrings.closeTransferAmount,
                              ShiftFormat.money(result.transfer!.amount ?? 0),
                            ),
                        ],
                        _row(
                          ShiftStrings.barDifferenceCount,
                          ShiftFormat.count(snapshot.barCount.differenceItems),
                        ),
                      ],
                    ),
                  ),
                  if ((result.unexplainedCash).abs() > kShiftEpsilon) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    ShiftNotice(
                      tone: ShiftTone.warning,
                      message: ShiftStrings.unexplainedCashWarning(
                        ShiftFormat.money(result.unexplainedCash.abs()),
                      ),
                      action: TextButton(
                        onPressed: () =>
                            context.go('/finance/cash-banks'),
                        child: const Text(ShiftStrings.openDrawerLedger),
                      ),
                    ),
                  ],
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
                        onPressed: () => context.push(
                          ShiftRouteLocations.report(
                            snapshot.identity.shiftNumber,
                          ),
                        ),
                      ),
                      ShiftButton(
                        buttonKey: const Key('shift-success-view-report'),
                        label: ShiftStrings.viewReport,
                        icon: Icons.description_outlined,
                        onPressed: () => context.push(
                          ShiftRouteLocations.report(
                            snapshot.identity.shiftNumber,
                          ),
                        ),
                      ),
                      ShiftButton(
                        label: ShiftStrings.backToHistory,
                        variant: ShiftButtonVariant.quiet,
                        icon: Icons.history_outlined,
                        onPressed: () =>
                            context.go(ShiftRouteLocations.history),
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

  Widget _row(
    String label,
    String value, {
    bool numeric = true,
    Color? color,
  }) => Padding(
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
