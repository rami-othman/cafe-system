import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/published_version_cubit.dart';

class VersionDetailDialog extends StatelessWidget {
  const VersionDetailDialog({
    super.key,
    required this.onRestore,
    required this.scopeKey,
  });

  final VoidCallback? onRestore;
  final String? scopeKey;

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<PublishedVersionCubit, PublishedVersionState>(
    listenWhen: (_, state) => state.scopeKey != scopeKey,
    listener: (context, _) => Navigator.of(context).pop(),
    child: AlertDialog(
      title: Text(context.l10n.versionDetail),
      content: SizedBox(
        width: 560,
        child: BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
          builder: (context, state) {
            if (state.detailStatus == VersionRequestStatus.loading) {
              return const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.detailStatus == VersionRequestStatus.failure) {
              return _DetailFailure(
                onRetry: () {
                  final version = state.selectedVersion;
                  if (version != null) {
                    context.read<PublishedVersionCubit>().openDetail(version);
                  }
                },
              );
            }
            final detail = state.detail;
            if (detail == null) return const SizedBox.shrink();
            final summary = detail.summary;
            final published = DateTime.tryParse(detail.version.publishedAt);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Text(
                          context.l10n.reviewVersionNumber(
                            detail.version.versionNumber,
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Chip(
                        label: Text(_status(context, detail.version.status)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    published == null
                        ? detail.version.publishedAt
                        : context.l10n.versionPublishedAt(
                            DateFormat.yMMMd(
                              Localizations.localeOf(context).toLanguageTag(),
                            ).add_Hm().format(published.toLocal()),
                          ),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 32,
                      runSpacing: 16,
                      children: <Widget>[
                        _Count(
                          label: context.l10n.versionMenus,
                          value: summary.menuCount,
                        ),
                        _Count(
                          label: context.l10n.versionSections,
                          value: summary.sectionCount,
                        ),
                        _Count(
                          label: context.l10n.versionProducts,
                          value: summary.productCount,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.versionChangeSummary,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail.version.changeSummary?.isNotEmpty == true
                        ? context.l10n.versionChangeSummaryAvailable
                        : context.l10n.versionChangeSummaryUnavailable,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonClose),
        ),
        if (onRestore != null)
          FilledButton(
            onPressed: onRestore,
            child: Text(context.l10n.versionRestoreThisVersion),
          ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Text('$value', style: Theme.of(context).textTheme.titleLarge),
      ),
      Text(label, style: const TextStyle(color: AppColors.textSecondary)),
    ],
  );
}

class _DetailFailure extends StatelessWidget {
  const _DetailFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const Icon(Icons.error_outline, color: AppColors.danger),
      const SizedBox(width: 8),
      Expanded(child: Text(context.l10n.versionDetailLoadError)),
      TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
    ],
  );
}

String _status(BuildContext context, String status) => switch (status) {
  'current' => context.l10n.versionStatusCurrent,
  'superseded' => context.l10n.versionStatusSuperseded,
  'rolled_back' => context.l10n.versionStatusRolledBack,
  _ => status,
};
