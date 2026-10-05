import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/published_version_cubit.dart';
import '../models/published_version_models.dart';

class RestoreVersionDialog extends StatefulWidget {
  const RestoreVersionDialog({
    super.key,
    required this.target,
    required this.scopeKey,
  });

  final PublishedVersion target;
  final String? scopeKey;

  @override
  State<RestoreVersionDialog> createState() => _RestoreVersionDialogState();
}

class _RestoreVersionDialogState extends State<RestoreVersionDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<PublishedVersionCubit, PublishedVersionState>(
        listenWhen: (_, state) => state.scopeKey != widget.scopeKey,
        listener: (context, _) => Navigator.of(context).pop(),
        child: AlertDialog(
          title: Text(
            context.l10n.versionRestoreTitle(widget.target.versionNumber),
          ),
          content: SizedBox(
            width: 540,
            child: BlocConsumer<PublishedVersionCubit, PublishedVersionState>(
              listenWhen: (previous, current) =>
                  previous.rollbackStatus == RollbackStatus.submitting &&
                  (current.rollbackStatus == RollbackStatus.success ||
                      current.rollbackStatus == RollbackStatus.noChanges),
              listener: (context, state) {
                Navigator.pop(context);
                showDialog<void>(
                  context: context,
                  builder: (_) =>
                      RestoreResultDialog(result: state.rollbackResult!),
                );
              },
              builder: (context, state) {
                final submitting =
                    state.rollbackStatus == RollbackStatus.submitting;
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.versionRestoreExplanation(
                          widget.target.versionNumber,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reasonController,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 4,
                        enabled: !submitting,
                        decoration: InputDecoration(
                          labelText: context.l10n.versionRestoreReason,
                          hintText: context.l10n.versionRestoreReasonHint,
                        ),
                      ),
                      if (state.rollbackStatus == RollbackStatus.failure)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.l10n.versionRestoreError,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
              builder: (context, state) {
                final submitting =
                    state.rollbackStatus == RollbackStatus.submitting;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(context.l10n.commonCancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: submitting
                          ? null
                          : () => context
                                .read<PublishedVersionCubit>()
                                .rollback(_reasonController.text),
                      child: Text(
                        submitting
                            ? context.l10n.versionRestoring
                            : context.l10n.versionRestoreAsNewVersion,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class RestoreResultDialog extends StatelessWidget {
  const RestoreResultDialog({super.key, required this.result});

  final RollbackResult result;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.versionRestoreResultTitle),
    content: Text(
      result.noChanges
          ? context.l10n.versionRestoreNoChanges(result.sourceVersionNumber)
          : context.l10n.versionRestoreSuccess(
              result.versionNumber,
              result.sourceVersionNumber,
            ),
    ),
    actions: <Widget>[
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonClose),
      ),
    ],
  );
}
