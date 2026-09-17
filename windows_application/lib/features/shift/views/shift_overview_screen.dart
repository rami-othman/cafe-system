import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shift_route_locations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../pos/controllers/pos_cubit.dart';
import '../controllers/shift_overview_cubit.dart';
import '../controllers/shift_overview_state.dart';
import '../models/shift_models.dart';
import '../widgets/shift_alerts_readiness.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_identity_header.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_state_views.dart';
import '../widgets/shift_strings.dart';
import '../widgets/shift_summary_cards.dart';

/// The current-shift screen: identity, KPIs, payment breakdown, orders
/// status, cash drawer projection, bar-count preview, alerts, progress and
/// the sticky "start closing" action bar.
class ShiftOverviewScreen extends StatefulWidget {
  const ShiftOverviewScreen({super.key});

  @override
  State<ShiftOverviewScreen> createState() => _ShiftOverviewScreenState();
}

class _ShiftOverviewScreenState extends State<ShiftOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ShiftOverviewCubit>().load(),
    );
  }

  @override
  Widget build(BuildContext context) => BlocListener<ShiftOverviewCubit, ShiftOverviewState>(
    listenWhen: (ShiftOverviewState previous, ShiftOverviewState current) =>
        previous.status != current.status &&
        (current.status == ShiftOverviewStatus.ready || current.status == ShiftOverviewStatus.empty),
    listener: (BuildContext context, ShiftOverviewState state) {
      unawaited(context.read<PosCubit>().refreshShiftStatus());
    },
    child: BlocBuilder<ShiftOverviewCubit, ShiftOverviewState>(
      builder: (BuildContext context, ShiftOverviewState state) => Column(
        children: <Widget>[Expanded(child: _buildBody(context, state))],
      ),
    ),
  );

  Widget _buildBody(BuildContext context, ShiftOverviewState state) {
    switch (state.status) {
      case ShiftOverviewStatus.initial:
      case ShiftOverviewStatus.loading:
        return const SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: ShiftOverviewSkeleton(),
        );
      case ShiftOverviewStatus.error:
        return ShiftErrorView(
          title: ShiftStrings.errorLoadingShift,
          detail: state.errorMessage,
          onRetry: () => context.read<ShiftOverviewCubit>().load(),
        );
      case ShiftOverviewStatus.empty:
        return _NoOpenShiftView(state: state);
      case ShiftOverviewStatus.ready:
        return _ShiftReadyView(state: state);
    }
  }
}

class _ShiftReadyView extends StatelessWidget {
  const _ShiftReadyView({required this.state});

  final ShiftOverviewState state;

  @override
  Widget build(BuildContext context) {
    final ShiftSnapshot snapshot = state.snapshot!;
    final DateTime now = DateTime.now();

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(ShiftStrings.currentTitle, style: ShiftText.pageTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(ShiftStrings.currentSubtitle, style: ShiftText.body),
                const SizedBox(height: AppSpacing.lg),
                ShiftIdentityHeader(identity: snapshot.identity),
                const SizedBox(height: AppSpacing.lg),
                Text(ShiftStrings.kpiSectionTitle, style: ShiftText.sectionTitle),
                const SizedBox(height: AppSpacing.md),
                ShiftKpiGrid(sales: snapshot.sales, payments: snapshot.payments),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool wide = constraints.maxWidth >= ShiftLayout.desktopBreakpoint;
                    final List<Widget> left = <Widget>[
                      PaymentBreakdownCard(breakdown: snapshot.payments),
                      const SizedBox(height: AppSpacing.lg),
                      OrdersStatusCard(orders: snapshot.orders),
                    ];
                    final List<Widget> right = <Widget>[
                      CashDrawerStatusCard(drawer: snapshot.drawer),
                      const SizedBox(height: AppSpacing.lg),
                      BarCountStatusCard(template: snapshot.barCount, now: now),
                    ];
                    if (!wide) {
                      return Column(
                        children: <Widget>[
                          ...left,
                          const SizedBox(height: AppSpacing.lg),
                          ...right,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: Column(children: left)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: Column(children: right)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                ShiftAlertsCard(alerts: state.assessment!.alerts),
                const SizedBox(height: AppSpacing.lg),
                ShiftProgressTrack(steps: state.assessment!.stages),
              ],
            ),
          ),
        ),
        _OverviewActionBar(canClose: state.assessment?.canClose ?? false),
      ],
    );
  }
}

class _OverviewActionBar extends StatelessWidget {
  const _OverviewActionBar({required this.canClose});

  final bool canClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    ),
    decoration: const BoxDecoration(
      color: ShiftColors.surface,
      border: Border(top: BorderSide(color: ShiftColors.border)),
    ),
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < ShiftLayout.tabletBreakpoint;
        final Widget notice = Expanded(
          child: Text(
            ShiftStrings.finishOrdersFirst,
            style: ShiftText.label,
            overflow: TextOverflow.ellipsis,
          ),
        );
        final Widget backButton = ShiftButton(
          label: ShiftStrings.backToPos,
          variant: ShiftButtonVariant.secondary,
          icon: Icons.point_of_sale_outlined,
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        );
        final Widget closeButton = ShiftButton(
          buttonKey: const Key('shift-overview-start-closing'),
          label: ShiftStrings.startClosing,
          icon: Icons.lock_outline,
          onPressed: () => context.go(ShiftRouteLocations.closing),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(ShiftStrings.finishOrdersFirst, style: ShiftText.label),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(child: backButton),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: closeButton),
                ],
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            backButton,
            const SizedBox(width: AppSpacing.lg),
            notice,
            const SizedBox(width: AppSpacing.lg),
            closeButton,
          ],
        );
      },
    ),
  );
}

/// The empty-shift panel: opening form plus continuity from the last shift.
class _NoOpenShiftView extends StatefulWidget {
  const _NoOpenShiftView({required this.state});

  final ShiftOverviewState state;

  @override
  State<_NoOpenShiftView> createState() => _NoOpenShiftViewState();
}

class _NoOpenShiftViewState extends State<_NoOpenShiftView> {
  late final TextEditingController _floatController = TextEditingController(
    text: widget.state.openingFloatInput,
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.state.openingNoteInput,
  );

  @override
  void dispose() {
    _floatController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftOverviewState state = widget.state;
    final DateTime now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: ShiftColors.neutralFill,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.schedule_outlined,
                        color: ShiftColors.inkMuted,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      ShiftStrings.noOpenShift,
                      style: ShiftText.pageTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ShiftStrings.noOpenShiftBody,
                      style: ShiftText.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ShiftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ShiftSectionHeader(
                      title: ShiftStrings.openShiftTitle,
                      icon: Icons.play_circle_outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ShiftFactTile(
                            label: ShiftStrings.branch,
                            value: '618TierFour',
                            numeric: false,
                          ),
                        ),
                        Expanded(
                          child: ShiftFactTile(
                            label: ShiftStrings.cashier,
                            value: 'tf-pos',
                            numeric: false,
                          ),
                        ),
                        Expanded(
                          child: ShiftFactTile(
                            label: ShiftStrings.date,
                            value: ShiftFormat.longDate(now),
                            numeric: false,
                          ),
                        ),
                        Expanded(
                          child: ShiftFactTile(
                            label: ShiftStrings.systemTime,
                            value: ShiftFormat.timeOfDay(now),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ShiftField(
                      label: ShiftStrings.openingFloatLabel,
                      isRequired: true,
                      error: state.openingFloatError,
                      child: ShiftNumberField(
                        fieldKey: const Key('shift-opening-float-field'),
                        controller: _floatController,
                        allowDecimal: true,
                        large: true,
                        hasError: state.openingFloatError != null,
                        hintText: ShiftStrings.openingFloatHint,
                        suffix: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Center(
                            widthFactor: 1,
                            child: Text('ل.س', style: ShiftText.bodyStrong),
                          ),
                        ),
                        onChanged: (String v) =>
                            context.read<ShiftOverviewCubit>().updateOpeningFloat(v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ShiftField(
                      label: ShiftStrings.openingNotes,
                      child: ShiftTextArea(
                        controller: _noteController,
                        hintText: ShiftStrings.openingNotesHint,
                        minLines: 2,
                        onChanged: (String v) =>
                            context.read<ShiftOverviewCubit>().updateOpeningNote(v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ShiftButton(
                      buttonKey: const Key('shift-open-submit-button'),
                      label: ShiftStrings.openShift,
                      icon: Icons.play_arrow_rounded,
                      expand: true,
                      large: true,
                      onPressed: state.isOpeningShift
                          ? null
                          : () => _confirmAndOpen(context),
                    ),
                  ],
                ),
              ),
              if (state.lastShift != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _LastShiftCard(entry: state.lastShift!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndOpen(BuildContext context) async {
    final ShiftOverviewCubit cubit = context.read<ShiftOverviewCubit>();
    final double? amount = cubit.validateOpeningFloat();
    if (amount == null) return;
    if (!context.mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _OpenShiftConfirmDialog(amount: amount),
    );
    if (confirmed == true) await cubit.openShift();
  }
}

class _OpenShiftConfirmDialog extends StatelessWidget {
  const _OpenShiftConfirmDialog({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(ShiftStrings.confirmOpenShift, style: ShiftText.sectionTitle),
            const SizedBox(height: AppSpacing.lg),
            ShiftKeyValueRow(label: ShiftStrings.branch, value: '618TierFour', numeric: false),
            const ShiftKeyValueRow(label: ShiftStrings.cashier, value: 'tf-pos', numeric: false),
            ShiftKeyValueRow(
              label: ShiftStrings.openingFloat,
              value: ShiftFormat.money(amount),
            ),
            ShiftKeyValueRow(
              label: ShiftStrings.openedAt,
              value: ShiftFormat.timeOfDay(DateTime.now()),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: ShiftButton(
                    label: ShiftStrings.back,
                    variant: ShiftButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ShiftButton(
                    buttonKey: const Key('shift-confirm-open-button'),
                    label: ShiftStrings.confirmOpenShift,
                    onPressed: () => Navigator.of(context).pop(true),
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

class _LastShiftCard extends StatelessWidget {
  const _LastShiftCard({required this.entry});

  final ShiftHistoryEntry entry;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ShiftSectionHeader(
          title: ShiftStrings.lastShift,
          icon: Icons.history_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: ShiftFactTile(label: ShiftStrings.shiftNumber, value: entry.shiftNumber),
            ),
            Expanded(
              child: ShiftFactTile(
                label: ShiftStrings.closedAt,
                value: ShiftFormat.timeOfDay(entry.closedAt),
              ),
            ),
            Expanded(
              child: ShiftFactTile(
                label: ShiftStrings.cashDifference,
                value: ShiftFormat.signedMoney(entry.cashDifference),
                valueColor: entry.isBalanced
                    ? ShiftColors.matchInk
                    : entry.isShortage
                    ? ShiftColors.shortageInk
                    : ShiftColors.surplusInk,
              ),
            ),
            Expanded(
              child: ShiftFactTile(
                label: ShiftStrings.netSales,
                value: ShiftFormat.money(entry.netSales),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
