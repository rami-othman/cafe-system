import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class CustomerConfirmationDialog extends StatelessWidget {
  const CustomerConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.confirmButtonKey,
    this.isPending = false,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final Key? confirmButtonKey;
  final bool isPending;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('customer-confirmation-dialog'),
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          key: const Key('customer-confirmation-cancel'),
          onPressed: isPending ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cmvpDialogCancel),
        ),
        FilledButton(
          key: confirmButtonKey ?? const Key('customer-confirmation-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: isPending ? null : () => Navigator.of(context).pop(true),
          child: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.cmvpSubmitting),
                  ],
                )
              : Text(confirmLabel),
        ),
      ],
    );
  }
}
