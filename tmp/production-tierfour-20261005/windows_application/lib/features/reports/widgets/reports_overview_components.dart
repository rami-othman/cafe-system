import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

/// The common white, bordered report surface used by the overview and the
/// detailed report pages that follow it.
class ReportsOverviewSectionCard extends StatelessWidget {
  const ReportsOverviewSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            if (trailing case final Widget trailing) trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    ),
  );
}

/// A deliberately neutral skeleton surface that mirrors the overview's
/// report cards without implying that data is available.
class ReportsOverviewSkeletonCard extends StatelessWidget {
  const ReportsOverviewSkeletonCard({
    super.key,
    required this.height,
    this.widthFactor = .38,
  });

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: Padding(
      padding: AppSpacing.allLg,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: AppSpacing.xs,
            decoration: const BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.control,
            ),
          ),
        ),
      ),
    ),
  );
}
