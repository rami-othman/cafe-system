import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/published_version_cubit.dart';
import '../models/published_version_models.dart';

class VersionCompareDialog extends StatefulWidget {
  const VersionCompareDialog({super.key, required this.scopeKey});

  final String? scopeKey;

  @override
  State<VersionCompareDialog> createState() => _VersionCompareDialogState();
}

class _VersionCompareDialogState extends State<VersionCompareDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<PublishedVersionCubit>().compareSelected());
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<PublishedVersionCubit, PublishedVersionState>(
        listenWhen: (_, state) => state.scopeKey != widget.scopeKey,
        listener: (context, _) => Navigator.of(context).pop(),
        child: AlertDialog(
          title: Text(context.l10n.compareVersions),
          content: SizedBox(
            width: 640,
            child: BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
              builder: (context, state) {
                if (state.comparisonStatus == VersionRequestStatus.loading) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (state.comparisonStatus == VersionRequestStatus.failure) {
                  return _CompareFailure(
                    onRetry: () =>
                        context.read<PublishedVersionCubit>().compareSelected(),
                  );
                }
                final comparison = state.comparison;
                return comparison == null
                    ? const SizedBox.shrink()
                    : _CompareResult(comparison: comparison);
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonClose),
            ),
          ],
        ),
      );
}

class _CompareResult extends StatelessWidget {
  const _CompareResult({required this.comparison});

  final VersionComparison comparison;

  @override
  Widget build(BuildContext context) {
    final sections = <_ChangeSection>[
      _ChangeSection(
        label: context.l10n.versionMenus,
        entries: <_ChangeCount>[
          _ChangeCount(context.l10n.versionsAdded, _count('menusAdded')),
          _ChangeCount(context.l10n.versionsRemoved, _count('menusRemoved')),
          _ChangeCount(context.l10n.versionsChanged, _count('menusChanged')),
        ],
      ),
      _ChangeSection(
        label: context.l10n.versionSections,
        entries: <_ChangeCount>[
          _ChangeCount(context.l10n.versionsAdded, _count('sectionsAdded')),
          _ChangeCount(context.l10n.versionsRemoved, _count('sectionsRemoved')),
        ],
      ),
      _ChangeSection(
        label: context.l10n.versionProducts,
        entries: <_ChangeCount>[
          _ChangeCount(context.l10n.versionsAdded, _count('productsAdded')),
          _ChangeCount(context.l10n.versionsRemoved, _count('productsRemoved')),
          _ChangeCount(context.l10n.versionsChanged, _count('productsChanged')),
        ],
      ),
      _ChangeSection(
        label: context.l10n.versionPricing,
        entries: <_ChangeCount>[
          _ChangeCount(context.l10n.versionChanges, _count('priceChanges')),
        ],
      ),
      _ChangeSection(
        label: context.l10n.versionModifiers,
        entries: <_ChangeCount>[
          _ChangeCount(context.l10n.versionChanges, _count('modifierChanges')),
        ],
      ),
      _ChangeSection(
        label: context.l10n.versionRecipes,
        entries: <_ChangeCount>[
          _ChangeCount(context.l10n.versionChanges, _count('recipeChanges')),
        ],
      ),
      _ChangeSection(
        label: context.l10n.versionSchedules,
        entries: <_ChangeCount>[
          _ChangeCount(context.l10n.versionChanges, _count('scheduleChanges')),
        ],
      ),
    ].where((section) => section.hasChanges).toList(growable: false);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              context.l10n.versionComparisonDirection(
                comparison.fromVersionNumber,
                comparison.toVersionNumber,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          if (comparison.sameChecksum)
            Text(context.l10n.versionNoContentDifferences)
          else ...<Widget>[
            Text(context.l10n.versionChangeCount(_totalChanges)),
            const SizedBox(height: 12),
            ...sections.map((section) => _ChangeRow(section: section)),
          ],
          if (comparison.truncated) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              context.l10n.versionComparisonTruncated,
              style: const TextStyle(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }

  int _count(String key) => comparison.changes[key]?.length ?? 0;

  int get _totalChanges => comparison.changes.values.fold(
    0,
    (total, entries) => total + entries.length,
  );
}

class _ChangeSection {
  const _ChangeSection({required this.label, required this.entries});

  final String label;
  final List<_ChangeCount> entries;
  bool get hasChanges => entries.any((entry) => entry.count > 0);
}

class _ChangeCount {
  const _ChangeCount(this.label, this.count);

  final String label;
  final int count;
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.section});

  final _ChangeSection section;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      children: <Widget>[
        Text(
          section.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          section.entries
              .where((entry) => entry.count > 0)
              .map((entry) => '${entry.count} ${entry.label.toLowerCase()}')
              .join(' · '),
        ),
      ],
    ),
  );
}

class _CompareFailure extends StatelessWidget {
  const _CompareFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const Icon(Icons.error_outline, color: AppColors.danger),
      const SizedBox(width: 8),
      Expanded(child: Text(context.l10n.versionCompareError)),
      TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
    ],
  );
}
