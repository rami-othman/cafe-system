import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../models/published_version_models.dart';

class VersionHistoryRow extends StatelessWidget {
  const VersionHistoryRow({
    super.key,
    required this.version,
    required this.selectedForComparison,
    required this.comparisonSelectionFull,
    required this.onToggleComparison,
    required this.onView,
    required this.onRestore,
  });

  final PublishedVersion version;
  final bool selectedForComparison;
  final bool comparisonSelectionFull;
  final VoidCallback onToggleComparison;
  final VoidCallback onView;
  final VoidCallback? onRestore;

  bool get _isCurrent => version.isCurrent || version.status == 'current';

  @override
  Widget build(BuildContext context) {
    final changeCount = _changeCount(version.changeSummary);
    final int? sourceVersion = _sourceVersion(version.changeSummary);
    final canSelect = selectedForComparison || !comparisonSelectionFull;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Checkbox(
            value: selectedForComparison,
            onChanged: canSelect ? (_) => onToggleComparison() : null,
            semanticLabel: context.l10n.versionSelectForCompare(
              version.versionNumber,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        context.l10n.reviewVersionNumber(version.versionNumber),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_isCurrent)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(context.l10n.versionStatusCurrent),
                      )
                    else if (version.status.isNotEmpty)
                      Text(
                        _statusLabel(context, version.status),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _publishedAt(context, version.publishedAt),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (changeCount != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    sourceVersion == null
                        ? context.l10n.versionChangeCount(changeCount)
                        : context.l10n.versionChangesSince(
                            changeCount,
                            sourceVersion,
                          ),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: <Widget>[
                    TextButton(
                      onPressed: onView,
                      child: Text(context.l10n.versionView),
                    ),
                    if (onRestore != null)
                      TextButton(
                        onPressed: onRestore,
                        child: Text(context.l10n.commonRestore),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _publishedAt(BuildContext context, String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? '—' : value;
  return DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_Hm().format(date.toLocal());
}

String _statusLabel(BuildContext context, String status) => switch (status) {
  'superseded' => context.l10n.versionStatusSuperseded,
  'rolled_back' => context.l10n.versionStatusRolledBack,
  _ => status,
};

int? _changeCount(Map<String, dynamic>? summary) {
  if (summary == null) return null;
  for (final key in <String>['changeCount', 'changesCount', 'totalChanges']) {
    final value = summary[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
  }
  return null;
}

int? _sourceVersion(Map<String, dynamic>? summary) {
  final value = summary?['sourceVersionNumber'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
