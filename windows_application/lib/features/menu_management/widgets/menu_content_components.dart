import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class ContentSection extends StatelessWidget {
  const ContentSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.trailingAction,
  });

  final String title;
  final Widget child;
  final String? description;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: AppRadius.card,
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: AppSpacing.allXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (description != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingAction != null) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                trailingAction!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  );
}

class EntityMetric {
  const EntityMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class EntityStatus {
  const EntityStatus({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;
}

class EntityRowAction {
  const EntityRowAction({
    required this.label,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
}

class EntityListRow extends StatelessWidget {
  const EntityListRow({
    super.key,
    required this.title,
    required this.status,
    this.leading,
    this.summary,
    this.metrics = const <EntityMetric>[],
    this.actions = const <EntityRowAction>[],
    this.onTap,
  });

  final Widget? leading;
  final String title;
  final String? summary;
  final List<EntityMetric> metrics;
  final EntityStatus status;
  final List<EntityRowAction> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool showMetrics =
            constraints.maxWidth >= AppSizes.menuEntityRowMetricsBreakpoint;
        final Widget content = Padding(
          padding: AppSpacing.allLg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    if (summary != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        summary!,
                        maxLines: showMetrics ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showMetrics && metrics.isNotEmpty) ...<Widget>[
                const SizedBox(width: AppSpacing.lg),
                _Metrics(metrics: metrics),
              ],
              const SizedBox(width: AppSpacing.md),
              _Status(status: status),
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                PopupMenuButton<EntityRowAction>(
                  tooltip: 'More actions for $title',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (EntityRowAction action) => action.onSelected(),
                  itemBuilder: (BuildContext context) => actions
                      .map(
                        (EntityRowAction action) =>
                            PopupMenuItem<EntityRowAction>(
                              value: action,
                              child: Row(
                                children: <Widget>[
                                  if (action.icon != null) ...<Widget>[
                                    Icon(action.icon, size: 18),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
                                  Text(action.label),
                                ],
                              ),
                            ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        );
        return Semantics(
          button: onTap != null,
          label: '$title, ${status.label}',
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.card,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: AppRadius.card,
                ),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics});

  final List<EntityMetric> metrics;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.lg,
    children: metrics
        .map(
          (EntityMetric metric) => Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(metric.label, style: Theme.of(context).textTheme.labelSmall),
              Text(metric.value, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        )
        .toList(),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.status});

  final EntityStatus status;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Status: ${status.label}',
    child: Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: (status.color ?? AppColors.textSecondary).withValues(alpha: .12),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(status.icon, size: 16, color: status.color),
          const SizedBox(width: AppSpacing.xs),
          Text(status.label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}

class DetailsDisclosure extends StatelessWidget {
  const DetailsDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    minTileHeight: 48,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.control,
      side: BorderSide(color: AppColors.border),
    ),
    collapsedShape: const RoundedRectangleBorder(
      borderRadius: AppRadius.control,
      side: BorderSide(color: AppColors.border),
    ),
    backgroundColor: AppColors.surface,
    collapsedBackgroundColor: AppColors.surface,
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    childrenPadding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    children: <Widget>[child],
  );
}

class EmptyStateAction {
  const EmptyStateAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.primaryAction,
    this.recoveryAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final EmptyStateAction? primaryAction;
  final EmptyStateAction? recoveryAction;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title. $message',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: AppSpacing.allXxl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (primaryAction != null || recoveryAction != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    if (recoveryAction != null)
                      OutlinedButton(
                        onPressed: recoveryAction!.onPressed,
                        child: Text(recoveryAction!.label),
                      ),
                    if (primaryAction != null)
                      ElevatedButton(
                        onPressed: primaryAction!.onPressed,
                        child: Text(primaryAction!.label),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
