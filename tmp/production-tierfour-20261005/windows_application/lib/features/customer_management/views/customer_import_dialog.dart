import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../controllers/customer_import_cubit.dart';
import '../controllers/customer_import_state.dart';
import '../models/customer_failure.dart';
import '../models/customer_import_models.dart';
import '../repositories/customer_import_repository.dart';
import '../widgets/customer_management_visual_tokens.dart';

Future<bool?> showCustomerImportDialog(
  BuildContext context, {
  required CustomerImportRepository repository,
  required Future<void> Function() onCompleted,
}) => showDialog<bool>(
  context: context,
  builder: (_) => BlocProvider<CustomerImportCubit>(
    create: (_) => CustomerImportCubit(repository),
    child: _CustomerImportDialog(onCompleted: onCompleted),
  ),
);

class _CustomerImportDialog extends StatefulWidget {
  const _CustomerImportDialog({required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  State<_CustomerImportDialog> createState() => _CustomerImportDialogState();
}

class _CustomerImportDialogState extends State<_CustomerImportDialog> {
  bool _createMissingGroups = false;

  Future<void> _pickFile(BuildContext context) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
      withData: true,
    );
    if (!context.mounted || result == null) return;
    final PlatformFile file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showFailure(
        context,
        const CustomerFailure(kind: CustomerFailureKind.validation),
      );
      return;
    }
    await context.read<CustomerImportCubit>().preview(
      bytes: bytes,
      filename: file.name,
    );
  }

  Future<void> _commit(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.customerImportConfirmTitle),
        content: Text(l10n.customerImportConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.customerImportConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<CustomerImportCubit>().commit(
        createMissingGroups: _createMissingGroups,
      );
    }
  }

  Future<void> _download(BuildContext context) async {
    final Uint8List? bytes = await context
        .read<CustomerImportCubit>()
        .downloadErrors();
    if (!context.mounted || bytes == null || bytes.isEmpty) return;
    await FilePicker.platform.saveFile(
      dialogTitle: AppLocalizations.of(context).customerImportDownloadErrors,
      fileName: 'customer-import-errors.csv',
      bytes: bytes,
    );
  }

  void _showFailure(BuildContext context, CustomerFailure failure) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String message = switch (failure.code) {
      'CUSTOMER_IMPORT_FILE_TOO_LARGE' ||
      'CUSTOMER_IMPORT_TOO_MANY_ROWS' ||
      'CUSTOMER_IMPORT_UNSUPPORTED_ENCODING' ||
      'CUSTOMER_IMPORT_DELIMITER_UNDETECTABLE' ||
      'CUSTOMER_IMPORT_REQUIRED_COLUMN_MISSING' ||
      'CUSTOMER_IMPORT_AMBIGUOUS_COLUMNS' =>
        l10n.customerImportValidationFailed,
      'CUSTOMER_IMPORT_ALREADY_COMPLETED' =>
        l10n.customerImportAlreadyCompleted,
      _ when failure.kind == CustomerFailureKind.forbidden =>
        l10n.errorPermissionDenied,
      _ => l10n.customerImportGenericFailure,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
      child: BlocConsumer<CustomerImportCubit, CustomerImportState>(
        listener: (BuildContext context, CustomerImportState state) {
          if (state.status == CustomerImportCubitStatus.success &&
              state.importStatus?.isTerminal == true) {
            widget.onCompleted();
          }
          if (state.status == CustomerImportCubitStatus.failure &&
              state.failure != null) {
            _showFailure(context, state.failure!);
          }
        },
        builder: (BuildContext context, CustomerImportState state) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          final CustomerImportStatus? import = state.importStatus;
          final bool busy =
              state.status == CustomerImportCubitStatus.previewing ||
              state.status == CustomerImportCubitStatus.committing ||
              state.status == CustomerImportCubitStatus.polling;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.customerImportTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.commonClose,
                      onPressed: busy
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l10n.customerImportDescription),
                const SizedBox(height: 20),
                if (busy) const LinearProgressIndicator(minHeight: 2),
                if (busy) const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: import == null
                        ? _EmptyImportState(onPick: () => _pickFile(context))
                        : _PreviewContent(
                            import: import,
                            createMissingGroups: _createMissingGroups,
                            onCreateMissingGroupsChanged: (bool value) =>
                                setState(() => _createMissingGroups = value),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (import != null && import.errorReportAvailable)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: busy ? null : () => _download(context),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(l10n.customerImportDownloadErrors),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: busy ? null : () => _pickFile(context),
                      child: Text(
                        import == null
                            ? l10n.customerImportSelectFile
                            : l10n.customerImportChooseAnother,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (import != null && import.status == 'preview_ready')
                      FilledButton(
                        onPressed: busy ? null : () => _commit(context),
                        child: Text(l10n.customerImportStart),
                      ),
                    if (import != null && import.isTerminal) ...<Widget>[
                      if (import.status == 'completed_with_errors')
                        Text(l10n.customerImportCompletedWithErrors),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.commonClose),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _EmptyImportState extends StatelessWidget {
  const _EmptyImportState({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.upload_file_outlined,
            size: 44,
            color: CustomerManagementVisualTokens.accent,
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).customerImportSelectFile),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('customer-import-select-file'),
            onPressed: onPick,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(AppLocalizations.of(context).customerImportSelectFile),
          ),
        ],
      ),
    ),
  );
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.import,
    required this.createMissingGroups,
    required this.onCreateMissingGroupsChanged,
  });
  final CustomerImportStatus import;
  final bool createMissingGroups;
  final ValueChanged<bool> onCreateMissingGroupsChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CustomerImportCounts counts = import.counts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(import.filename, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(l10n.customerImportDetected(import.encoding, import.delimiter)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Metric(label: l10n.customerImportTotal, value: counts.total),
            _Metric(label: l10n.customerImportReady, value: counts.ready),
            _Metric(label: l10n.customerImportWarnings, value: counts.warnings),
            _Metric(label: l10n.customerImportRejected, value: counts.rejected),
            _Metric(
              label: l10n.customerImportDuplicateCandidates,
              value: counts.duplicateCandidates,
            ),
          ],
        ),
        if (import.missingGroups.isNotEmpty)
          CheckboxListTile(
            key: const Key('customer-import-create-missing-groups'),
            value: createMissingGroups,
            onChanged: (bool? value) =>
                onCreateMissingGroupsChanged(value == true),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.customerImportCreateMissingGroups),
            subtitle: Text(import.missingGroups.join(', ')),
          ),
        if (import.issues.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.customerImportIssues,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final CustomerImportIssue issue in import.issues.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text('${issue.rowNumber}'),
              title: Text(issue.name ?? l10n.customerImportUnnamedRow),
              subtitle: Text(
                <String>[...issue.warnings, ...issue.errors].join(', '),
              ),
            ),
        ],
        if (import.isTerminal) ...<Widget>[
          const Divider(height: 28),
          Text(
            l10n.customerImportSummary,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            l10n.customerImportCountsSummary(
              counts.createdCustomers,
              counts.skippedCustomers,
              counts.failedRows,
              counts.createdGroups,
              counts.createdMemberships,
            ),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 112),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CustomerManagementVisualTokens.surface,
      border: Border.all(color: CustomerManagementVisualTokens.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        Text(label),
      ],
    ),
  );
}
