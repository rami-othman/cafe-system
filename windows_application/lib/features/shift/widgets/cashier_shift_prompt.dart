import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../pos/controllers/pos_cubit.dart';
import '../../pos/controllers/pos_state.dart';
import '../controllers/shift_overview_cubit.dart';
import '../controllers/shift_overview_state.dart';
import '../repositories/shift_repository.dart';
import '../views/shift_overview_screen.dart';
import 'shift_design.dart';

/// Presents the opening form once per branch in this authenticated session.
/// Dismissing it permits browsing; the server still enforces the shift rule.
class CashierShiftPrompt extends StatefulWidget {
  const CashierShiftPrompt({
    super.key,
    required this.isCashier,
    required this.cashierName,
    required this.repository,
    required this.child,
  });

  final bool isCashier;
  final String cashierName;
  final ShiftRepository repository;
  final Widget child;

  @override
  State<CashierShiftPrompt> createState() => _CashierShiftPromptState();
}

class _CashierShiftPromptState extends State<CashierShiftPrompt> {
  final Set<int> _promptedBranches = <int>{};
  bool _dialogOpen = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePrompt();
  }

  bool _needsShift(PosState state) =>
      widget.isCashier &&
      !state.isLoading &&
      state.errorMessage == null &&
      state.branches.any((branch) => branch.id == state.branchId) &&
      state.shiftId == null;

  void _schedulePrompt() {
    if (_scheduled || !widget.isCashier) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final PosState state = context.read<PosCubit>().state;
      if (_needsShift(state) && !_promptedBranches.contains(state.branchId)) {
        unawaited(_showOpening());
      }
    });
  }

  Future<void> _showOpening() async {
    if (_dialogOpen || !mounted) return;
    final PosCubit pos = context.read<PosCubit>();
    final PosState state = pos.state;
    if (!_needsShift(state)) return;
    _dialogOpen = true;
    _promptedBranches.add(state.branchId);
    final String branchName = state.branches
        .firstWhere((branch) => branch.id == state.branchId)
        .name;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<PosCubit>.value(value: pos),
          BlocProvider<ShiftOverviewCubit>(
            create: (_) => ShiftOverviewCubit(
              repository: widget.repository,
              branchId: state.branchId,
            ),
          ),
        ],
        child: _ShiftOpeningDialog(
          branchName: branchName,
          cashierName: widget.cashierName,
        ),
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<PosCubit, PosState>(
    listenWhen: (previous, current) =>
        previous.branchId != current.branchId ||
        previous.shiftId != current.shiftId ||
        previous.isLoading != current.isLoading ||
        previous.errorMessage != current.errorMessage,
    listener: (_, _) => _schedulePrompt(),
    builder: (context, state) {
      final bool ar = Localizations.localeOf(context).languageCode == 'ar';
      return Column(
        children: [
          if (_needsShift(state))
            Material(
              color: ShiftColors.neutralFill,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        ar
                            ? 'افتح ورديتك لإنشاء السندات وتنفيذ العمليات المالية. يمكنك التصفح حالياً.'
                            : 'Open your shift to create documents and process transactions. You can browse for now.',
                      ),
                    ),
                    TextButton(
                      key: const Key('cashier-open-shift'),
                      onPressed: _showOpening,
                      child: Text(ar ? 'فتح الوردية' : 'Open shift'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      );
    },
  );
}

class _ShiftOpeningDialog extends StatelessWidget {
  const _ShiftOpeningDialog({
    required this.branchName,
    required this.cashierName,
  });

  final String branchName;
  final String cashierName;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ShiftOverviewCubit, ShiftOverviewState>(
        listenWhen: (previous, current) =>
            previous.status != current.status && current.hasOpenShift,
        listener: (context, _) => Navigator.of(context).pop(),
        builder: (context, state) => PopScope(
          canPop: !state.isOpeningShift,
          child: Dialog(
            key: const Key('cashier-shift-opening-dialog'),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
            child: SizedBox(
              width: 720,
              height: MediaQuery.sizeOf(context).height * .85,
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      key: const Key('cashier-shift-dismiss'),
                      tooltip:
                          Localizations.localeOf(context).languageCode == 'ar'
                          ? 'إغلاق ومتابعة التصفح'
                          : 'Close and browse',
                      onPressed: state.isOpeningShift
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Expanded(
                    child: ShiftOverviewScreen(
                      openingOnly: true,
                      branchName: branchName,
                      cashierName: cashierName,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
