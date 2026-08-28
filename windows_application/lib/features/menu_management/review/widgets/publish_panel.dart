import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/menu_review_cubit.dart';
import '../models/review_models.dart';
import 'current_version_summary.dart';
import 'publish_confirmation.dart';

class PublishPanel extends StatelessWidget {
  const PublishPanel({
    super.key,
    required this.state,
    required this.cubit,
    required this.onReviewReadiness,
    required this.onAssignments,
    required this.onViewVersions,
  });

  final MenuReviewState state;
  final MenuReviewCubit cubit;
  final VoidCallback onReviewReadiness;
  final VoidCallback onAssignments;
  final VoidCallback onViewVersions;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
    children: <Widget>[
      Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: switch (state.publicationStatus) {
            PublicationActionStatus.success ||
            PublicationActionStatus.noChanges => _PublishResultState(
              state: state,
              onViewVersions: onViewVersions,
            ),
            PublicationActionStatus.validationBlocked => _RevalidationFailure(
              onReviewIssues: onReviewReadiness,
            ),
            PublicationActionStatus.failure => _NetworkFailure(
              onRetry: cubit.publish,
            ),
            _ => _PublishReadinessSurface(
              state: state,
              cubit: cubit,
              onReviewReadiness: onReviewReadiness,
              onAssignments: onAssignments,
              onViewVersions: onViewVersions,
            ),
          },
        ),
      ),
    ],
  );
}

class _PublishReadinessSurface extends StatelessWidget {
  const _PublishReadinessSurface({
    required this.state,
    required this.cubit,
    required this.onReviewReadiness,
    required this.onAssignments,
    required this.onViewVersions,
  });

  final MenuReviewState state;
  final MenuReviewCubit cubit;
  final VoidCallback onReviewReadiness;
  final VoidCallback onAssignments;
  final VoidCallback onViewVersions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validation = state.validation;
    final ready =
        state.validationStatus == ReviewRequestStatus.loaded &&
        validation != null;
    final noAssignedMenu =
        validation?.issues.any(
          (ValidationIssue issue) => issue.code == 'NO_ASSIGNED_MENU',
        ) ??
        false;
    final blocked = ready && (!validation.canPublish || noAssignedMenu);
    final publishing =
        state.publicationStatus == PublicationActionStatus.publishing;
    final canPublish = ready && !blocked && !publishing;
    final branch = state.selectedBranch?.name ?? '-';
    final channel = _channelLabel(context, state.channel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.reviewPublishQuestion(branch, channel),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.reviewPublishScopeHelp,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              CurrentVersionSummary(
                state: state,
                onRetry: cubit.loadCurrentVersion,
                onViewVersions: onViewVersions,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _ReadinessCounts(
                errors: validation?.errorCount,
                warnings: validation?.warningCount,
                loading: state.validationStatus == ReviewRequestStatus.loading,
              ),
              const SizedBox(height: AppSpacing.md),
              if (!ready)
                _StatusBanner(
                  color: AppColors.textMuted,
                  background: AppColors.surfaceAlt,
                  icon: Icons.hourglass_top_rounded,
                  title: l10n.reviewPublishCheckingReadiness,
                  message: l10n.reviewPublishWaitForReadiness,
                )
              else if (noAssignedMenu)
                _StatusBanner(
                  color: AppColors.danger,
                  background: const Color(0xFFFFE5E3),
                  icon: Icons.warning_amber_rounded,
                  title: l10n.reviewNoMenusAssigned,
                  message: l10n.reviewPublishNoAssignedMenu,
                  action: OutlinedButton(
                    onPressed: onAssignments,
                    child: Text(l10n.reviewGoToAssignments),
                  ),
                )
              else if (blocked)
                _StatusBanner(
                  color: AppColors.danger,
                  background: const Color(0xFFFFE5E3),
                  icon: Icons.cancel_outlined,
                  title: l10n.reviewPublishCannotPublish,
                  message: l10n.reviewFixBlockingErrors,
                  action: OutlinedButton(
                    onPressed: onReviewReadiness,
                    child: Text(l10n.reviewPublishReviewErrors),
                  ),
                )
              else if (validation.warningCount > 0)
                _StatusBanner(
                  color: AppColors.warning,
                  background: const Color(0xFFFFF0D9),
                  icon: Icons.warning_amber_rounded,
                  title: l10n.reviewReadyToPublish,
                  message: l10n.reviewPublishWarningsCanProceed(
                    validation.warningCount,
                  ),
                )
              else
                _StatusBanner(
                  color: AppColors.success,
                  background: const Color(0xFFE3F5E8),
                  icon: Icons.check_circle_outline,
                  title: l10n.reviewReadyToPublish,
                  message: l10n.reviewPublishCleanReady,
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: canPublish
                    ? () => _confirm(context, state, cubit)
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: AppColors.primary,
                ),
                icon: publishing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.publish_outlined),
                label: Text(
                  publishing
                      ? l10n.reviewPublishPublishing
                      : l10n.reviewPublishAction,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    MenuReviewState state,
    MenuReviewCubit cubit,
  ) async {
    final bool confirmed = await PublishConfirmation.show(
      context: context,
      state: state,
    );
    if (!context.mounted || !confirmed) return;
    if (cubit.state.publishingScopeKey != state.publishingScopeKey) return;
    cubit.publish();
  }
}

class _PublishResultState extends StatelessWidget {
  const _PublishResultState({
    required this.state,
    required this.onViewVersions,
  });

  final MenuReviewState state;
  final VoidCallback onViewVersions;

  @override
  Widget build(BuildContext context) {
    final result = state.lastPublication!;
    final noChanges =
        state.publicationStatus == PublicationActionStatus.noChanges;
    final l10n = context.l10n;
    return _Surface(
      color: noChanges ? const Color(0xFFF0F7F1) : const Color(0xFFE3F5E8),
      borderColor: const Color(0xFFCDEBD3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            noChanges ? Icons.check_circle_outline : Icons.task_alt,
            color: AppColors.success,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            noChanges
                ? l10n.reviewPublishAlreadyUpToDate
                : l10n.reviewPublishSuccess,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (noChanges)
            Text(
              l10n.reviewPublishNoChanges(result.version.versionNumber),
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else ...<Widget>[
            Text(
              l10n.reviewVersionNumber(result.version.versionNumber),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _publishedAt(context, result.version.publishedAt),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.reviewPublishCurrentForScope(
                state.selectedBranch?.name ?? '-',
                _channelLabel(context, state.channel),
              ),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onViewVersions,
            child: Text(l10n.reviewViewVersions),
          ),
        ],
      ),
    );
  }
}

class _RevalidationFailure extends StatelessWidget {
  const _RevalidationFailure({required this.onReviewIssues});

  final VoidCallback onReviewIssues;

  @override
  Widget build(BuildContext context) => _Surface(
    color: const Color(0xFFFFE5E3),
    borderColor: const Color(0xFFFFD2CF),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.danger,
          size: 32,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.reviewPublishRevalidationFailedTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.danger,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.reviewPublishRevalidationFailedMessage,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: onReviewIssues,
          child: Text(context.l10n.reviewPublishReviewIssues),
        ),
      ],
    ),
  );
}

class _NetworkFailure extends StatelessWidget {
  const _NetworkFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _Surface(
    color: const Color(0xFFFFE5E3),
    borderColor: const Color(0xFFFFD2CF),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.reviewPublishRequestFailed,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.danger,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: onRetry,
          child: Text(context.l10n.reviewPublishTryAgain),
        ),
      ],
    ),
  );
}

class _ReadinessCounts extends StatelessWidget {
  const _ReadinessCounts({
    required this.errors,
    required this.warnings,
    required this.loading,
  });

  final int? errors;
  final int? warnings;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.card,
    ),
    child: loading
        ? Text(context.l10n.reviewPublishCheckingReadiness)
        : Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Count(
                count: errors ?? 0,
                label: context.l10n.reviewErrors,
                color: (errors ?? 0) > 0
                    ? AppColors.danger
                    : AppColors.textPrimary,
              ),
              _Count(
                count: warnings ?? 0,
                label: context.l10n.reviewWarnings,
                color: (warnings ?? 0) > 0
                    ? AppColors.warning
                    : AppColors.textPrimary,
              ),
            ],
          ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.count, required this.label, required this.color});

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: DefaultTextStyle.of(context).style,
      children: <InlineSpan>[
        TextSpan(
          text: '$count ',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        TextSpan(text: label),
      ],
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.color,
    required this.background,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Color color;
  final Color background;
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(color: background, borderRadius: AppRadius.card),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 24),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: borderColor),
      borderRadius: AppRadius.card,
    ),
    child: Padding(padding: AppSpacing.allLg, child: child),
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

String _publishedAt(BuildContext context, String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? '-' : value;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return context.l10n.reviewPublishedAt(
    DateFormat.yMMMd(locale).add_Hm().format(date.toLocal()),
  );
}
