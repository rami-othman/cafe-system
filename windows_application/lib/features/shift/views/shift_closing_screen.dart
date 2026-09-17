import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shift_route_locations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../pos/controllers/pos_cubit.dart';
import '../controllers/shift_closing_cubit.dart';
import '../controllers/shift_closing_state.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_state_views.dart';
import '../widgets/shift_strings.dart';
import 'shift_closing_step1_operations.dart';
import 'shift_closing_step2_cash.dart';
import 'shift_closing_step3_bar_count.dart';
import 'shift_closing_step4_review.dart';
import 'shift_closing_step5_success.dart';

/// The five-step closing wizard shell: header, stepper, the active step's
/// content, and a sticky previous/next footer with a "saved" indicator.
class ShiftClosingScreen extends StatefulWidget {
  const ShiftClosingScreen({super.key});

  @override
  State<ShiftClosingScreen> createState() => _ShiftClosingScreenState();
}

class _ShiftClosingScreenState extends State<ShiftClosingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ShiftClosingCubit>().load(),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ShiftClosingCubit, ShiftClosingState>(
        listenWhen: (ShiftClosingState previous, ShiftClosingState current) =>
            previous.status != current.status &&
            current.status == ShiftClosingStatus.closed,
        listener: (BuildContext context, ShiftClosingState state) {
          unawaited(context.read<PosCubit>().refreshShiftStatus());
        },
        child: BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
          builder: (BuildContext context, ShiftClosingState state) {
            if (state.status == ShiftClosingStatus.loading) {
              return const SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: ShiftTableSkeleton(label: ShiftStrings.loadingShift),
              );
            }
            if (state.status == ShiftClosingStatus.error) {
              return ShiftErrorView(
                title: ShiftStrings.errorLoadingShift,
                detail: state.errorMessage,
                onRetry: () => context.go(ShiftRouteLocations.current),
              );
            }

            final bool isDone = state.step == ShiftClosingStep.done;

            return Column(
              children: <Widget>[
                if (!isDone) _WizardHeader(state: state),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.xxxl,
                    ),
                    child: switch (state.step) {
                      ShiftClosingStep.operations => const ShiftClosingStep1Operations(),
                      ShiftClosingStep.cashCount => const ShiftClosingStep2Cash(),
                      ShiftClosingStep.barCount => const ShiftClosingStep3BarCount(),
                      ShiftClosingStep.finalReview => const ShiftClosingStep4Review(),
                      ShiftClosingStep.done => const ShiftClosingStep5Success(),
                    },
                  ),
                ),
                if (!isDone) const _WizardFooter(),
              ],
            );
          },
        ),
      );
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.state});

  final ShiftClosingState state;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(ShiftStrings.closingTitle, style: ShiftText.pageTitle)),
            TextButton.icon(
              onPressed: () => context.go(ShiftRouteLocations.current),
              icon: const Icon(Icons.close, size: 16, color: ShiftColors.blockerInk),
              label: Text(
                ShiftStrings.cancelAndReturn,
                style: ShiftText.bodyStrong.copyWith(color: ShiftColors.blockerInk),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Stepper(state: state),
        const SizedBox(height: AppSpacing.lg),
      ],
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.state});

  final ShiftClosingState state;

  static const List<String> _labels = <String>[
    ShiftStrings.step1,
    ShiftStrings.step2,
    ShiftStrings.step3,
    ShiftStrings.step4,
    ShiftStrings.step5,
  ];

  @override
  Widget build(BuildContext context) {
    final int current = state.step.number;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Five Arabic step labels plus connectors need materially more room
        // than the module's general tablet breakpoint — below it the labels
        // must collapse to numbered circles only.
        final bool wide = constraints.maxWidth >= ShiftLayout.desktopBreakpoint;
        final List<Widget> nodes = <Widget>[
          for (int i = 0; i < _labels.length; i++) ...<Widget>[
            _StepNode(
              number: i + 1,
              label: _labels[i],
              isDone: i + 1 < current,
              isCurrent: i + 1 == current,
              compact: !wide,
              onTap: i + 1 < current
                  ? () => context.read<ShiftClosingCubit>().jumpTo(
                      ShiftClosingStep.values[i],
                    )
                  : null,
            ),
            if (i < _labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i + 1 < current ? ShiftColors.matchInk : ShiftColors.border,
                ),
              ),
          ],
        ];
        return Row(children: nodes);
      },
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.number,
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.compact,
    this.onTap,
  });

  final int number;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink) = isDone
        ? (ShiftColors.matchInk, Colors.white)
        : isCurrent
        ? (ShiftColors.ink, Colors.white)
        : (ShiftColors.neutralFill, ShiftColors.inkMuted);

    final Widget circle = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: isDone
          ? Icon(Icons.check, size: 15, color: ink)
          : Text('$number', style: ShiftText.bodyStrong.copyWith(color: ink)),
    );

    return InkWell(
      key: Key('shift-wizard-step-$number'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            circle,
            if (!compact) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                label,
                style: ShiftText.bodyStrong.copyWith(
                  color: isCurrent ? ShiftColors.ink : ShiftColors.inkSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter();

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
    builder: (BuildContext context, ShiftClosingState state) {
      final ShiftClosingCubit cubit = context.read<ShiftClosingCubit>();
      final bool isFirst = state.step.isFirst;
      final bool isLastEditable = state.step == ShiftClosingStep.finalReview;

      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: ShiftColors.surface,
          border: Border(top: BorderSide(color: ShiftColors.border)),
        ),
        child: Row(
          children: <Widget>[
            if (!isFirst)
              ShiftButton(
                buttonKey: const Key('shift-wizard-back'),
                label: ShiftStrings.previous,
                variant: ShiftButtonVariant.secondary,
                icon: Icons.arrow_forward,
                onPressed: cubit.goBack,
              ),
            const SizedBox(width: AppSpacing.md),
            if (state.savedAt != null)
              Expanded(
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.cloud_done_outlined, size: 14, color: ShiftColors.inkMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${ShiftStrings.autoSaved} · ${ShiftFormat.time(state.savedAt!)}',
                        style: ShiftText.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            if (!isLastEditable)
              ShiftButton(
                buttonKey: const Key('shift-wizard-next'),
                label: ShiftStrings.next,
                icon: Icons.arrow_back,
                onPressed: cubit.goNext,
              ),
          ],
        ),
      );
    },
  );
}

/// Shared card chrome used by every wizard step: title + subtitle.
class ShiftWizardStepHeader extends StatelessWidget {
  const ShiftWizardStepHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: ShiftText.sectionTitle),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(subtitle!, style: ShiftText.body),
        ],
      ],
    ),
  );
}

/// Rounded outline chip used for the readiness bullets and small badges the
/// wizard steps share.
class ShiftDot extends StatelessWidget {
  const ShiftDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    margin: const EdgeInsets.only(top: 6),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Card wrapper reused by review-style step sections (labelled section with
/// a title row and a bordered body).
class ShiftReviewSection extends StatelessWidget {
  const ShiftReviewSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ShiftColors.surface,
      borderRadius: AppRadius.card,
      border: Border.all(color: ShiftColors.border),
    ),
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 16, color: ShiftColors.inkMuted),
              const SizedBox(width: 6),
            ],
            Text(title, style: ShiftText.cardTitle),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );
}
