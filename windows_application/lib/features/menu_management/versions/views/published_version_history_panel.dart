// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../controllers/published_version_cubit.dart';
import '../models/published_version_models.dart';

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
    _sync();
  }

  @override
  void didUpdateWidget(covariant PublishedVersionHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId ||
        oldWidget.channel != widget.channel)
      _sync();
  }

  void _sync() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted)
      context.read<PublishedVersionCubit>().setContext(
        widget.branchId,
        widget.channel,
      );
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
          AppCard(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  context.l10n.versionHistory,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _detail('Branch', widget.branchName),
                _detail('Sales channel', widget.channel),
                if (state.currentVersion != null)
                  _detail(
                    'Current Version',
                    'v${state.currentVersion!.versionNumber}',
                    technical: true,
                  ),
                OutlinedButton.icon(
                  onPressed: state.historyStatus == VersionRequestStatus.loading
                      ? null
                      : cubit.refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.commonRefresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (state.rollbackResult != null)
            _rollbackMessage(state.rollbackResult!),
          if (state.historyStatus == VersionRequestStatus.loading &&
              history == null)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.historyError != null && history == null)
            _error(state.historyError!, cubit.refresh)
          else if (history == null || history.items.isEmpty)
            const AppCard(
              child: Text(
                'No published Menu Versions exist for this Branch and Channel.',
              ),
            )
          else ...<Widget>[
            if (state.historyError != null)
              _error(state.historyError!, cubit.refresh),
            ...history.items.map(
              (version) => _VersionRow(
                version: version,
                onDetails: () => _showDetail(context, version),
                onCompare: () => _showComparison(context, version),
                onRollback: version.isCurrent || version.status == 'current'
                    ? null
                    : () => _showRollback(context, version),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed:
                      history.hasPrevious &&
                          state.historyStatus != VersionRequestStatus.loading
                      ? cubit.previousPage
                      : null,
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 12),
                Text('Page ${history.page}'),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed:
                      history.hasNext &&
                          state.historyStatus != VersionRequestStatus.loading
                      ? cubit.nextPage
                      : null,
                  child: const Text('Next'),
                ),
              ],
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
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _DetailDialog()),
    );
  }

  Future<void> _showComparison(
    BuildContext context,
    PublishedVersion source,
  ) async {
    final cubit = context.read<PublishedVersionCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ComparisonDialog(source: source),
      ),
    );
  }

  Future<void> _showRollback(
    BuildContext context,
    PublishedVersion target,
  ) async {
    final cubit = context.read<PublishedVersionCubit>();
    cubit.beginRollback(target);
    await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _RollbackDialog(
          target: target,
          branchName: widget.branchName,
          channel: widget.channel,
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.version,
    required this.onDetails,
    required this.onCompare,
    this.onRollback,
  });
  final PublishedVersion version;
  final VoidCallback onDetails;
  final VoidCallback onCompare;
  final VoidCallback? onRollback;
  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                'v${version.versionNumber}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _status(version.status),
            if (version.isCurrent || version.status == 'current')
              Chip(label: Text(context.l10n.versionStatusCurrent)),
            if (version.publicationStatus != null)
              Text('Publication: ${_label(version.publicationStatus!)}'),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: <Widget>[
            _detail(
              'Published',
              version.publishedAt.isEmpty ? '-' : version.publishedAt,
              technical: true,
            ),
            _detail(
              'Checksum',
              _shortChecksum(version.checksum),
              technical: true,
              tooltip: version.checksum,
            ),
            if (version.publicationId != null)
              _detail(
                'Publication ID',
                '${version.publicationId}',
                technical: true,
              ),
            if (version.changeSummary != null &&
                version.changeSummary!.isNotEmpty)
              _detail(
                'Change summary',
                version.changeSummary!.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join(' · '),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: <Widget>[
            TextButton(
              onPressed: onDetails,
              child: Text(context.l10n.versionDetail),
            ),
            TextButton(
              onPressed: onCompare,
              child: Text(context.l10n.compareVersions),
            ),
            if (onRollback != null)
              TextButton(
                onPressed: onRollback,
                child: Text(context.l10n.versionRollback),
              ),
          ],
        ),
      ],
    ),
  );
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.versionDetail),
    content: SizedBox(
      width: 650,
      child: BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
        builder: (context, state) {
          if (state.detailStatus == VersionRequestStatus.loading)
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          if (state.detailError != null) return Text(state.detailError!);
          final detail = state.detail;
          if (detail == null)
            return const Text('Version detail is unavailable.');
          final s = detail.summary;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: <Widget>[
                    _detail(
                      'Version',
                      'v${detail.version.versionNumber}',
                      technical: true,
                    ),
                    _detail('Status', _label(detail.version.status)),
                    _detail(
                      'Branch',
                      '${detail.version.branchId ?? '-'}',
                      technical: true,
                    ),
                    _detail('Channel', detail.version.channel ?? '-'),
                    _detail(
                      'Published',
                      detail.version.publishedAt,
                      technical: true,
                    ),
                    _detail(
                      'Checksum',
                      detail.version.checksum,
                      technical: true,
                    ),
                    if (detail.version.publicationId != null)
                      _detail(
                        'Publication ID',
                        '${detail.version.publicationId}',
                        technical: true,
                      ),
                    if (detail.version.publicationStatus != null)
                      _detail(
                        'Publication status',
                        _label(detail.version.publicationStatus!),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Immutable Snapshot summary',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: <Widget>[
                    _detail('Menus', '${s.menuCount}'),
                    _detail('Sections', '${s.sectionCount}'),
                    _detail('Products', '${s.productCount}'),
                    _detail('Variants', '${s.variantCount}'),
                    _detail('Modifier Groups', '${s.modifierGroupCount}'),
                  ],
                ),
                const SizedBox(height: 18),
                if (state.payloadStatus == VersionRequestStatus.loading)
                  const Center(child: CircularProgressIndicator())
                else if (detail.payload == null) ...<Widget>[
                  const Text(
                    'Snapshot payload is diagnostic, read-only, and is not used for POS Sync.',
                  ),
                  TextButton.icon(
                    onPressed: context
                        .read<PublishedVersionCubit>()
                        .loadPayload,
                    icon: const Icon(Icons.data_object),
                    label: const Text('Load Snapshot Payload'),
                  ),
                ] else ...<Widget>[
                  const Text(
                    'Immutable historical Snapshot payload (read-only)',
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 300),
                      color: AppColors.surfaceAlt,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          JsonEncoder.withIndent('  ').convert(detail.payload),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (state.payloadError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.payloadError!,
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonClose),
      ),
    ],
  );
}

class _ComparisonDialog extends StatelessWidget {
  const _ComparisonDialog({required this.source});
  final PublishedVersion source;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${context.l10n.compareVersions} v${source.versionNumber}'),
    content: SizedBox(
      width: 680,
      child: BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
        builder: (context, state) {
          final cubit = context.read<PublishedVersionCubit>();
          final items =
              state.history?.items
                  .where((item) => item.id != source.id)
                  .toList() ??
              const <PublishedVersion>[];
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<PublishedVersion>(
                  initialValue: state.comparisonTarget,
                  decoration: const InputDecoration(
                    labelText: 'Comparison Version',
                  ),
                  items: items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text('v${item.versionNumber}'),
                        ),
                      )
                      .toList(),
                  onChanged: cubit.selectComparisonTarget,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      state.comparisonTarget == null ||
                          state.comparisonStatus == VersionRequestStatus.loading
                      ? null
                      : () => cubit.compare(source),
                  child: Text(context.l10n.compareVersions),
                ),
                if (state.comparisonStatus == VersionRequestStatus.loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state.comparisonError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      state.comparisonError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                if (state.comparison != null)
                  _comparisonResult(state.comparison!),
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
    ],
  );
}

class _RollbackDialog extends StatefulWidget {
  const _RollbackDialog({
    required this.target,
    required this.branchName,
    required this.channel,
  });
  final PublishedVersion target;
  final String branchName;
  final String channel;
  @override
  State<_RollbackDialog> createState() => _RollbackDialogState();
}

class _RollbackDialogState extends State<_RollbackDialog> {
  final TextEditingController controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.versionNewRollback),
    content: SizedBox(
      width: 520,
      child: BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
        builder: (context, state) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Target Version: v${widget.target.versionNumber}'),
              Text(
                'Current Version: ${state.currentVersion == null ? '-' : 'v${state.currentVersion!.versionNumber}'}',
              ),
              Text('Branch: ${widget.branchName}'),
              Text('Channel: ${widget.channel}'),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  'Published: ${widget.target.publishedAt}\nChecksum: ${widget.target.checksum}',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Rollback will create a new immutable Version using the selected historical Snapshot. The historical Version itself will not be modified or reactivated.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: context.l10n.versionRollbackReason,
                ),
              ),
              if (state.rollbackError != null)
                Text(
                  state.rollbackError!,
                  style: const TextStyle(color: AppColors.danger),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: <Widget>[
      BlocBuilder<PublishedVersionCubit, PublishedVersionState>(
        builder: (context, state) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              onPressed: state.rollbackStatus == RollbackStatus.submitting
                  ? null
                  : () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: state.rollbackStatus == RollbackStatus.submitting
                  ? null
                  : () async {
                      await context.read<PublishedVersionCubit>().rollback(
                        controller.text,
                      );
                      if (context.mounted &&
                          context
                                  .read<PublishedVersionCubit>()
                                  .state
                                  .rollbackStatus !=
                              RollbackStatus.failure) {
                        Navigator.pop(context);
                      }
                    },
              child: Text(
                state.rollbackStatus == RollbackStatus.submitting
                    ? 'Creating…'
                    : context.l10n.versionNewRollback,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _comparisonResult(VersionComparison result) => Padding(
  padding: const EdgeInsets.only(top: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (result.sameChecksum)
        const Text(
          'These Versions have identical semantic Snapshot content.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      if (result.truncated)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Only a bounded subset of differences is displayed; this comparison is not exhaustive.',
            style: TextStyle(color: AppColors.warning),
          ),
        ),
      ...result.changes.entries
          .where((entry) => entry.value.isNotEmpty)
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _comparisonLabel(entry.key),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(entry.value.join(', ')),
                  ),
                ],
              ),
            ),
          ),
      if (!result.sameChecksum &&
          result.changes.values.every((entries) => entries.isEmpty))
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('No bounded structural differences were returned.'),
        ),
    ],
  ),
);
Widget _rollbackMessage(RollbackResult result) => AppCard(
  margin: const EdgeInsets.only(bottom: 12),
  child: Text(
    result.noChanges
        ? 'The selected Version matches the current published content. No new Version was created.'
        : 'Rollback successful. Source v${result.sourceVersionNumber} created new current Version v${result.versionNumber}. Publication ID: ${result.publicationId ?? '-'}',
  ),
);
Widget _error(String message, VoidCallback retry) => AppCard(
  margin: const EdgeInsets.only(bottom: 12),
  child: Row(
    children: <Widget>[
      const Icon(Icons.error_outline, color: AppColors.danger),
      const SizedBox(width: 8),
      Expanded(child: Text(message)),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  ),
);
Widget _status(String value) => Chip(label: Text(_label(value)));
Widget _detail(
  String label,
  String value, {
  bool technical = false,
  String? tooltip,
}) => SizedBox(
  width: technical ? 230 : 160,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      Directionality(
        textDirection: technical ? TextDirection.ltr : TextDirection.ltr,
        child: Tooltip(
          message: tooltip ?? value,
          child: Text(value, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
  ),
);
String _shortChecksum(String checksum) =>
    checksum.length <= 14 ? checksum : '${checksum.substring(0, 12)}…';
String _label(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
String _comparisonLabel(String key) =>
    <String, String>{
      'menusAdded': 'Menus added',
      'menusRemoved': 'Menus removed',
      'menusChanged': 'Menus changed',
      'sectionsAdded': 'Sections added',
      'sectionsRemoved': 'Sections removed',
      'productsAdded': 'Products added',
      'productsRemoved': 'Products removed',
      'productsChanged': 'Products changed',
      'priceChanges': 'Price changes',
      'modifierChanges': 'Modifier changes',
      'scheduleChanges': 'Schedule changes',
    }[key] ??
    key;
