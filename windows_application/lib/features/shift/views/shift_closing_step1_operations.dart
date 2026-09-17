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
import '../widgets/shift_identity_header.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_strings.dart';
import '../widgets/shift_summary_cards.dart';
import 'shift_closing_screen.dart';

/// Step 1 — a complete operations review before any counting starts:
/// identity, sales, payments, order validation, pending operations, and a
/// readiness snapshot of what step 2/3 still owe.
class ShiftClosingStep1Operations extends StatelessWidget {
  const ShiftClosingStep1Operations({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
    builder: (BuildContext context, ShiftClosingState state) {
      final ShiftSnapshot snapshot = state.snapshot!;
      final ShiftAssessment assessment = state.assessment!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftWizardStepHeader(title: ShiftStrings.operationsReview),
          ShiftIdentityHeader(identity: snapshot.identity, compact: true),
          const SizedBox(height: AppSpacing.lg),
          ShiftReviewSection(
            title: ShiftStrings.salesSummary,
            icon: Icons.trending_up,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth >= ShiftLayout.desktopBreakpoint
                    ? 6
                    : constraints.maxWidth >= ShiftLayout.tabletBreakpoint
                    ? 3
                    : 2;
                final List<(String, String)> rows = <(String, String)>[
                  (ShiftStrings.grossSales, ShiftFormat.money(snapshot.sales.grossSales)),
                  (ShiftStrings.totalDiscounts, ShiftFormat.money(snapshot.sales.discounts)),
                  (ShiftStrings.totalRefunds, ShiftFormat.money(snapshot.sales.refunds)),
                  (ShiftStrings.netSales, ShiftFormat.money(snapshot.sales.netSales)),
                  (ShiftStrings.orderCount, ShiftFormat.count(snapshot.sales.orderCount)),
                  (
                    ShiftStrings.averageOrder,
                    ShiftFormat.money(snapshot.sales.averageOrderValue),
                  ),
                ];
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 2.4,
                  children: <Widget>[
                    for (final (String label, String value) in rows)
                      ShiftFactTile(label: label, value: value),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PaymentBreakdownCard(breakdown: snapshot.payments),
          const SizedBox(height: AppSpacing.lg),
          ShiftReviewSection(
            title: ShiftStrings.ordersValidation,
            icon: Icons.assignment_turned_in_outlined,
            child: OrdersStatusCard(orders: snapshot.orders),
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftReviewSection(
            title: ShiftStrings.pendingOperations,
            icon: Icons.pending_actions_outlined,
            child: snapshot.pendingOperations.isEmpty
                ? const ShiftNotice(
                    tone: ShiftTone.success,
                    message: ShiftStrings.noPendingOperations,
                  )
                : Column(
                    children: <Widget>[
                      for (final PendingOperation op in snapshot.pendingOperations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ShiftNotice(
                            tone: op.blocking ? ShiftTone.blocker : ShiftTone.warning,
                            message:
                                '${ShiftAssessment.pendingLabel(op.kind)} — ${op.reference}',
                            detail: op.amount == null
                                ? op.detail
                                : '${op.detail} · ${ShiftFormat.money(op.amount!)}',
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ShiftReadinessChecklist(items: assessment.readiness),
        ],
      );
    },
  );
}
