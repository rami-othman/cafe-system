import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/pos_print_state.dart';

Future<void> showPosPrintFailure({
  required BuildContext context,
  required PosPrintOutcome outcome,
  required Future<PosPrintOutcome> Function() retry,
}) async {
  final PosPrintFailure? failure = outcome.failure;
  if (failure == null) return;
  final GoRouter router = GoRouter.of(context);
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => _PosPrintFailureDialog(
      failure: failure,
      retry: retry,
      onPrinterSetup: () => router.go('/settings'),
    ),
  );
}

class _PosPrintFailureDialog extends StatefulWidget {
  const _PosPrintFailureDialog({
    required this.failure,
    required this.retry,
    required this.onPrinterSetup,
  });

  final PosPrintFailure failure;
  final Future<PosPrintOutcome> Function() retry;
  final VoidCallback onPrinterSetup;

  @override
  State<_PosPrintFailureDialog> createState() => _PosPrintFailureDialogState();
}

class _PosPrintFailureDialogState extends State<_PosPrintFailureDialog> {
  late PosPrintFailure _failure = widget.failure;
  bool _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    final PosPrintOutcome outcome = await widget.retry();
    if (!mounted) return;
    if (outcome.failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _failure = outcome.failure!;
      _isRetrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.posPrint),
      content: Text(_message(l10n, _failure)),
      actions: <Widget>[
        TextButton(
          onPressed: _isRetrying ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.posClose),
        ),
        if (_canOpenPrinterSetup(_failure))
          TextButton(
            onPressed: _isRetrying ? null : widget.onPrinterSetup,
            child: Text(l10n.posPrinterSetup),
          ),
        FilledButton(
          onPressed: _isRetrying ? null : _retry,
          child: _isRetrying
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.posRetryPrint),
        ),
      ],
    );
  }
}

bool _canOpenPrinterSetup(PosPrintFailure failure) => switch (failure) {
  PosPrintFailure.printerNotConfigured ||
  PosPrintFailure.invalidConfiguration ||
  PosPrintFailure.configurationUnavailable => true,
  _ => false,
};

String _message(AppLocalizations l10n, PosPrintFailure failure) =>
    switch (failure) {
      PosPrintFailure.orderRequired => l10n.posPrintOrderRequired,
      PosPrintFailure.itemsRequired => l10n.posPrintItemsRequired,
      PosPrintFailure.preBillUnavailable => l10n.posPreBillUnavailable,
      PosPrintFailure.printerNotConfigured => l10n.posPrintPrinterNotConfigured,
      PosPrintFailure.invalidConfiguration => l10n.posPrintInvalidConfiguration,
      PosPrintFailure.configurationUnavailable =>
        l10n.posPrintConfigurationUnavailable,
      PosPrintFailure.receiptUnavailable => l10n.posPrintReceiptUnavailable,
      PosPrintFailure.renderingFailed => l10n.posPrintRenderingFailed,
      PosPrintFailure.printerUnreachable => l10n.posPrintUnreachable,
      PosPrintFailure.printerTimeout => l10n.posPrintTimeout,
      PosPrintFailure.printerUnsupported => l10n.posPrintUnsupported,
      PosPrintFailure.printerFailed => l10n.posPrintFailed,
    };
