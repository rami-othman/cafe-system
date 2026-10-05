import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'shift_design.dart';
import 'shift_primitives.dart';
import 'shift_strings.dart';

/// Loading, empty and error surfaces for the module.
///
/// The loading state is a structural skeleton rather than a spinner: it
/// reserves the same blocks the loaded screen will show, so the layout does
/// not jump when data arrives.

class ShiftSkeletonBox extends StatefulWidget {
  const ShiftSkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 6,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShiftSkeletonBox> createState() => _ShiftSkeletonBoxState();
}

class _ShiftSkeletonBoxState extends State<ShiftSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
    child: Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: ShiftColors.skeleton,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Skeleton for the current-shift screen.
class ShiftOverviewSkeleton extends StatelessWidget {
  const ShiftOverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: ShiftStrings.loadingShift,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ShiftSkeletonBox(height: 26, width: 220),
        const SizedBox(height: AppSpacing.sm),
        const ShiftSkeletonBox(height: 14, width: 340),
        const SizedBox(height: AppSpacing.xl),
        const ShiftCard(
          child: Row(
            children: <Widget>[
              Expanded(child: ShiftSkeletonBox(height: 44)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: ShiftSkeletonBox(height: 44)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: ShiftSkeletonBox(height: 44)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: ShiftSkeletonBox(height: 44)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 700
                ? 3
                : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 2.3,
              children: const <Widget>[
                ShiftCard(child: ShiftSkeletonBox(height: 52)),
                ShiftCard(child: ShiftSkeletonBox(height: 52)),
                ShiftCard(child: ShiftSkeletonBox(height: 52)),
                ShiftCard(child: ShiftSkeletonBox(height: 52)),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const ShiftCard(child: ShiftSkeletonBox(height: 120)),
        const SizedBox(height: AppSpacing.md),
        Text(ShiftStrings.loadingShift, style: ShiftText.label),
      ],
    ),
  );
}

/// Skeleton rows for a table-driven screen.
class ShiftTableSkeleton extends StatelessWidget {
  const ShiftTableSkeleton({super.key, this.rows = 6, this.label});

  final int rows;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ShiftCard(child: ShiftSkeletonBox(height: 40)),
        const SizedBox(height: AppSpacing.md),
        ShiftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              Container(height: 44, color: ShiftColors.headerFill),
              for (int i = 0; i < rows; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: ShiftSkeletonBox(height: 20),
                ),
            ],
          ),
        ),
        if (label != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(label!, style: ShiftText.label),
        ],
      ],
    ),
  );
}

/// Full-surface error state with a retry affordance.
class ShiftErrorView extends StatelessWidget {
  const ShiftErrorView({
    super.key,
    required this.title,
    required this.onRetry,
    this.detail,
  });

  final String title;
  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ShiftCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: ShiftColors.blockerFill,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: ShiftColors.blockerInk,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ShiftText.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail ?? ShiftStrings.errorHint,
              textAlign: TextAlign.center,
              style: ShiftText.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            ShiftButton(
              buttonKey: const Key('shift-error-retry'),
              label: ShiftStrings.retry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Neutral empty state for filtered lists.
class ShiftEmptyView extends StatelessWidget {
  const ShiftEmptyView({
    super.key,
    required this.title,
    this.detail,
    this.action,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? detail;
  final Widget? action;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ShiftColors.neutralFill,
                borderRadius: AppRadius.panel,
              ),
              child: Icon(icon, color: ShiftColors.inkMuted, size: 24),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ShiftText.cardTitle,
            ),
            if (detail != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(detail!, textAlign: TextAlign.center, style: ShiftText.body),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    ),
  );
}
