import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/published_version_cubit.dart';
import '../models/published_version_models.dart';
import '../widgets/restore_version_dialog.dart';
import '../widgets/version_compare_dialog.dart';
import '../widgets/version_detail_dialog.dart';
import '../widgets/version_history_row.dart';

class PublishedVersionHistoryPanel extends StatefulWidget {
  const PublishedVersionHistoryPanel({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.channel,
  });

  final int? branchId;
  final String branchName;
  final String channel;

  @override
  State<PublishedVersionHistoryPanel> createState() =>
      _PublishedVersionHistoryPanelState();
}

class _PublishedVersionHistoryPanelState
    extends State<PublishedVersionHistoryPanel> {
  @override
  void initState() {
    super.initState();
    _syncContext();
  }

  @override
  void didUpdateWidget(covariant PublishedVersionHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId ||
        oldWidget.channel != widget.channel) {
      _syncContext();
    }
  }

  void _syncContext() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      unawaited(
        context.read<PublishedVersionCubit>().setContext(
          widget.branchId,
          widget.channel,
        ),
      );
    }
  });

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
    builder: (context, state) {
      final cubit = context.read<PublishedVersionCubit>();
      final history = state.history;
      return ListView(
        padding: const EdgeInsets.only(top: 20),
        children: <Widget>[
          _HistoryHeader(
            branchName: widget.branchName,
            channel: widget.channel,
            selectionCount: state.comparisonSelection.length,
            comparing: state.comparisonStatus == VersionRequestStatus.loading,
            onCompare: state.comparisonSelection.length == 2
                ? () => _showCompare(context)
                : null,
            onRefresh: state.historyStatus == VersionRequestStatus.loading
                ? null
                : cubit.refresh,
          ),
          const SizedBox(height: 12),
          if (state.rollbackResult != null) ...<Widget>[
            _RestoreResultBanner(result: state.rollbackResult!),
            const SizedBox(height: 12),
          ],
          if (state.historyStatus == VersionRequestStatus.loading &&
              history == null)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.historyStatus == VersionRequestStatus.failure &&
              history == null)
            _HistoryFailure(onRetry: cubit.refresh)
          else if (history == null || history.items.isEmpty)
            _HistoryEmpty(
              branchName: widget.branchName,
              channel: widget.channel,
            )
          else ...<Widget>[
            if (state.historyStatus ==
                VersionRequestStatus.failure) ...<Widget>[
              _HistoryFailure(onRetry: cubit.refresh),
              const SizedBox(height: 12),
            ],
            ...history.items.map(
              (version) => VersionHistoryRow(
                version: version,
                selectedForComparison: state.comparisonSelection.any(
                  (selected) => selected.id == version.id,
                ),
                comparisonSelectionFull: state.comparisonSelection.length == 2,
                onToggleComparison: () =>
                    cubit.toggleComparisonSelection(version),
                onView: () => _showDetail(context, version),
                onRestore: version.isCurrent || version.status == 'current'
                    ? null
                    : () => _showRestore(context, version),
              ),
            ),
            const SizedBox(height: 8),
            _Pagination(
              page: history.page,
              hasPrevious: history.hasPrevious,
              hasNext: history.hasNext,
              loading: state.historyStatus == VersionRequestStatus.loading,
              onPrevious: cubit.previousPage,
              onNext: cubit.nextPage,
            ),
          ],
        ],
      );
    },
  );

  Future<void> _showDetail(
    BuildContext context,
    PublishedVersion version,
  ) async {
    final cubit = context.read<PublishedVersionCubit>();
    unawaited(cubit.openDetail(version));
    await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: VersionDetailDialog(
          scopeKey: cubit.state.scopeKey,
          onRestore: version.isCurrent || version.status == 'current'
              ? null
              : () {
                  Navigator.pop(context);
                  _showRestore(context, version);
                },
        ),
      ),
    );
  }

  Future<void> _showCompare(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<PublishedVersionCubit>(),
      child: VersionCompareDialog(
        scopeKey: context.read<PublishedVersionCubit>().state.scopeKey,
      ),
    ),
  );

  Future<void> _showRestore(
    BuildContext context,
    PublishedVersion target,
  ) async {
    final cubit = context.read<PublishedVersionCubit>();
    cubit.beginRollback(target);
    await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: RestoreVersionDialog(
          target: target,
          scopeKey: cubit.state.scopeKey,
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.branchName,
    required this.channel,
    required this.selectionCount,
    required this.comparing,
    required this.onCompare,
    required this.onRefresh,
  });

  final String branchName;
  final String channel;
  final int selectionCount;
  final bool comparing;
  final VoidCallback? onCompare;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          context.l10n.versionHistory,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '$branchName · $channel',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        FilledButton.icon(
          onPressed: comparing ? null : onCompare,
          icon: const Icon(Icons.compare_arrows),
          label: Text(context.l10n.versionCompareSelected(selectionCount)),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.commonRefresh),
        ),
      ],
    ),
  );
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.branchName, required this.channel});

  final String branchName;
  final String channel;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.versionHistoryEmptyTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(context.l10n.versionHistoryEmptyDescription(branchName, channel)),
      ],
    ),
  );
}

class _HistoryFailure extends StatelessWidget {
  const _HistoryFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(context.l10n.versionHistoryLoadError)),
        TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
      ],
    ),
  );
}

class _RestoreResultBanner extends StatelessWidget {
  const _RestoreResultBanner({required this.result});

  final RollbackResult result;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        Icon(
          result.noChanges ? Icons.info_outline : Icons.check_circle_outline,
          color: result.noChanges ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            result.noChanges
                ? context.l10n.versionRestoreNoChanges(
                    result.sourceVersionNumber,
                  )
                : context.l10n.versionRestoreSuccess(
                    result.versionNumber,
                    result.sourceVersionNumber,
                  ),
          ),
        ),
      ],
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.hasPrevious,
    required this.hasNext,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final bool hasPrevious;
  final bool hasNext;
  final bool loading;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      OutlinedButton(
        onPressed: hasPrevious && !loading ? onPrevious : null,
        child: Text(context.l10n.versionPreviousPage),
      ),
      const SizedBox(width: 12),
      Text(context.l10n.versionPage(page)),
      const SizedBox(width: 12),
      OutlinedButton(
        onPressed: hasNext && !loading ? onNext : null,
        child: Text(context.l10n.versionNextPage),
      ),
    ],
  );
}
