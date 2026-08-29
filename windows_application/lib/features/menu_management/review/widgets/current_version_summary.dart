import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/menu_review_cubit.dart';

class CurrentVersionSummary extends StatelessWidget {
  const CurrentVersionSummary({
    super.key,
    required this.state,
    required this.onViewVersions,
    required this.onRetry,
    this.compact = false,
  });

  final MenuReviewState state;
  final VoidCallback onViewVersions;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.currentVersionStatus == ReviewRequestStatus.loading) {
      return const _VersionSurface(child: _VersionSkeleton());
    }
    if (state.currentVersionStatus == ReviewRequestStatus.failure) {
      return _VersionSurface(child: _VersionFailure(onRetry: onRetry));
    }

    final version = state.currentVersion;
    if (version == null) {
      return _VersionSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Eyebrow(label: l10n.reviewCurrentlyPublished),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.reviewNotPublishedYet,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.reviewNoCurrentVersion,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return _VersionSurface(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Eyebrow(label: l10n.reviewCurrentlyPublished),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      l10n.reviewVersionNumber(version.versionNumber),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _CurrentPill(label: l10n.versionStatusCurrent),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _publishedAt(context, version.publishedAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _CompactAction(
                label: l10n.reviewViewVersions,
                onPressed: onViewVersions,
              ),
              _CompactAction(
                label: l10n.compareVersions,
                onPressed: onViewVersions,
              ),
            ],
          );

          if (compact) return summary;
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                summary,
                const SizedBox(height: AppSpacing.md),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.lg),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _VersionSurface extends StatelessWidget {
  const _VersionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    child: Padding(padding: AppSpacing.allLg, child: child),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _CurrentPill extends StatelessWidget {
  const _CurrentPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 3,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFE3F5E8),
      borderRadius: AppRadius.pillRadius,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.success,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: AppSpacing.horizontalMd,
      visualDensity: VisualDensity.compact,
    ),
    child: Text(label),
  );
}

class _VersionFailure extends StatelessWidget {
  const _VersionFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Eyebrow(label: l10n.reviewCurrentlyPublished),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.reviewCurrentVersionLoadError,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _CompactAction(label: l10n.commonRetry, onPressed: onRetry),
      ],
    );
  }
}

class _VersionSkeleton extends StatelessWidget {
  const _VersionSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _bar(132, 12),
      const SizedBox(height: AppSpacing.sm),
      _bar(216, 20),
      const SizedBox(height: AppSpacing.xs),
      _bar(254, 14),
    ],
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

String _publishedAt(BuildContext context, String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? '-' : value;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return context.l10n.reviewPublishedAt(
    DateFormat.yMMMd(locale).add_Hm().format(date.toLocal()),
  );
}
