import 'package:flutter/material.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ReviewWorkflowTabs extends StatelessWidget {
  const ReviewWorkflowTabs({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final TabController controller;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TabBar(
      controller: controller,
      isScrollable: true,
      onTap: onTap,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.border,
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      labelPadding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm,
        end: AppSpacing.lg,
      ),
      tabs: <Widget>[
        Tab(text: l10n.reviewReadinessTab),
        Tab(text: l10n.reviewPreviewTab),
        Tab(text: l10n.reviewPublishTab),
        Tab(text: l10n.reviewVersionsTab),
      ],
    );
  }
}
