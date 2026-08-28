import 'package:flutter/material.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/menu_review_cubit.dart';
import '../models/review_models.dart';
import '../presentation/validation_issue_presentation.dart';
import 'readiness_issue_browser.dart';

class ReadinessSummary extends StatelessWidget {
  const ReadinessSummary({
    super.key,
    required this.state,
    required this.onCheckAgain,
    required this.onAssignments,
    required this.onIssueNavigate,
    required this.onIssueFiltersChanged,
  });

  final MenuReviewState state;
  final VoidCallback onCheckAgain;
  final VoidCallback onAssignments;
  final void Function(ValidationIssue issue, ReadinessIssueAction action)
  onIssueNavigate;
  final void Function({ValidationSeverity? severity, String? search})
  onIssueFiltersChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.reviewReadiness,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
            final action = _CheckAgainButton(
              loading: state.validationStatus == ReviewRequestStatus.loading,
              onPressed: onCheckAgain,
            );
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[heading, const SizedBox(height: 10), action],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: heading),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        switch (state.validationStatus) {
          ReviewRequestStatus.loading => const _ReadinessSkeleton(),
          ReviewRequestStatus.failure => _ReadinessError(onRetry: onCheckAgain),
          _ => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Result(
                result: state.validation,
                branch: state.selectedBranch?.name ?? '',
                channel: _channelLabel(context, state.channel),
                onAssignments: onAssignments,
              ),
              if (state.validation != null &&
                  state.validation!.issues.isNotEmpty)
                ReadinessIssueBrowser(
                  validation: state.validation!,
                  severityFilter: state.severityFilter,
                  search: state.search,
                  onFiltersChanged:
                      ({ValidationSeverity? severity, String? search}) =>
                          onIssueFiltersChanged(
                            severity: severity,
                            search: search,
                          ),
                  onNavigate: onIssueNavigate,
                ),
            ],
          ),
        },
      ],
    );
  }
}

class _CheckAgainButton extends StatelessWidget {
  const _CheckAgainButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: loading ? null : onPressed,
    icon: const Icon(Icons.refresh, size: 18),
    label: Text(context.l10n.reviewCheckAgain),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: AppSpacing.horizontalMd,
      visualDensity: VisualDensity.compact,
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.branch,
    required this.channel,
    required this.onAssignments,
  });

  final MenuValidationResult? result;
  final String branch;
  final String channel;
  final VoidCallback onAssignments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (result == null) return const SizedBox.shrink();
    final noAssignedMenu = result!.issues.any(
      (ValidationIssue issue) => issue.code == 'NO_ASSIGNED_MENU',
    );
    if (noAssignedMenu) {
      return _ContainedReadinessState(
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.danger,
        title: l10n.reviewNoMenusAssigned,
        message: l10n.reviewNoMenusAssignedHelp(branch, channel),
        action: ElevatedButton(
          onPressed: onAssignments,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: AppSpacing.horizontalMd,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(l10n.reviewGoToAssignments),
        ),
      );
    }

    final blocked = result!.errorCount > 0;
    final warnings = result!.warningCount;
    return _ReadinessStatusSurface(
      blocked: blocked,
      errors: result!.errorCount,
      warnings: warnings,
      title: blocked ? l10n.reviewNeedsAttention : l10n.reviewReadyToPublish,
      message: blocked
          ? l10n.reviewFixBlockingErrors
          : warnings > 0
          ? l10n.reviewWarningsToReview(warnings)
          : l10n.reviewNoIssuesForScope(branch, channel),
    );
  }
}

class _ReadinessStatusSurface extends StatelessWidget {
  const _ReadinessStatusSurface({
    required this.blocked,
    required this.errors,
    required this.warnings,
    required this.title,
    required this.message,
  });

  final bool blocked;
  final int errors;
  final int warnings;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final accent = blocked ? AppColors.danger : AppColors.success;
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: blocked ? const Color(0xFFFFE1DE) : const Color(0xFFE3F5E8),
        border: Border.all(
          color: blocked ? const Color(0xFFFFD2CF) : const Color(0xFFCDEBD3),
        ),
        borderRadius: AppRadius.card,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final status = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                blocked
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: accent,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          );
          final counts = Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ReadinessCount(
                label: context.l10n.reviewErrors,
                count: errors,
                color: errors > 0 ? AppColors.danger : AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.lg),
              _ReadinessCount(
                label: context.l10n.reviewWarnings,
                count: warnings,
                color: warnings > 0 ? AppColors.warning : AppColors.textPrimary,
              ),
            ],
          );
          if (constraints.maxWidth < 590) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                status,
                const SizedBox(height: AppSpacing.md),
                counts,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: status),
              const SizedBox(width: AppSpacing.lg),
              counts,
            ],
          );
        },
      ),
    );
  }
}

class _ReadinessCount extends StatelessWidget {
  const _ReadinessCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count $label',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _ContainedReadinessState extends StatelessWidget {
  const _ContainedReadinessState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: iconColor.withValues(alpha: .28)),
      borderRadius: AppRadius.card,
    ),
    child: Padding(
      padding: AppSpacing.allLg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                action,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReadinessSkeleton extends StatelessWidget {
  const _ReadinessSkeleton();

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _bar(180, 18),
          const SizedBox(height: AppSpacing.sm),
          _bar(360, 14),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          _bar(220, 14),
          const SizedBox(height: AppSpacing.sm),
          _bar(300, 14),
        ],
      ),
    ),
  );

  Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _ReadinessError extends StatelessWidget {
  const _ReadinessError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _ContainedReadinessState(
    icon: Icons.warning_amber_rounded,
    iconColor: AppColors.danger,
    title: context.l10n.reviewReadinessLoadError,
    message: context.l10n.reviewTryAgain,
    action: OutlinedButton(
      onPressed: onRetry,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: AppSpacing.horizontalMd,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(context.l10n.commonRetry),
    ),
  );
}

String _channelLabel(BuildContext context, String value) => switch (value) {
  'pos' => context.l10n.salesChannelPos,
  'online_ordering' => context.l10n.salesChannelOnline,
  _ =>
    value
        .split('_')
        .map(
          (String word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' '),
};
