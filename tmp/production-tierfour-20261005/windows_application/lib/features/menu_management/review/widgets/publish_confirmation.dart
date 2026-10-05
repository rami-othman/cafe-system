import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/menu_review_cubit.dart';

class PublishConfirmation {
  const PublishConfirmation._();

  static Future<bool> show({
    required BuildContext context,
    required MenuReviewState state,
  }) async {
    final String? scopeKey = state.publishingScopeKey;
    if (scopeKey == null) return false;
    final MenuReviewCubit cubit = context.read<MenuReviewCubit>();
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => BlocProvider.value(
            value: cubit,
            child: BlocListener<MenuReviewCubit, MenuReviewState>(
              listenWhen: (_, current) =>
                  current.publishingScopeKey != scopeKey,
              listener: (_, _) => Navigator.of(dialogContext).pop(false),
              child: _PublishConfirmationDialog(
                branch: state.selectedBranch?.name ?? '-',
                channel: _channelLabel(dialogContext, state.channel),
                version: state.currentVersion?.versionNumber,
                warnings: state.validation?.warningCount ?? 0,
              ),
            ),
          ),
        ) ??
        false;
  }
}

class _PublishConfirmationDialog extends StatelessWidget {
  const _PublishConfirmationDialog({
    required this.branch,
    required this.channel,
    required this.version,
    required this.warnings,
  });

  final String branch;
  final String channel;
  final int? version;
  final int warnings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.reviewPublishConfirmTitle(branch, channel)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.reviewPublishImmutableExplanation,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Detail(
                label: l10n.reviewPublishCurrentVersion,
                value: version == null
                    ? l10n.reviewNotPublishedYet
                    : l10n.reviewVersionNumber(version!),
              ),
              const SizedBox(height: AppSpacing.md),
              _Detail(label: l10n.reviewWarnings, value: '$warnings'),
              if (warnings > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: AppSpacing.allMd,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0D9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.reviewPublishWarningsCanProceed(warnings),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.reviewPublishAction),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
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
