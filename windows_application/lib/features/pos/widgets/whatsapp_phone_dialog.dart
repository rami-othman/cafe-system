import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../utils/whatsapp_phone.dart';

/// Asks the cashier for the customer's WhatsApp number. Returns the normalized
/// digits-only number, or null when cancelled.
Future<String?> showWhatsAppPhoneDialog(
  BuildContext context, {
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _WhatsAppPhoneDialog(initialValue: initialValue),
  );
}

class _WhatsAppPhoneDialog extends StatefulWidget {
  const _WhatsAppPhoneDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_WhatsAppPhoneDialog> createState() => _WhatsAppPhoneDialogState();
}

class _WhatsAppPhoneDialogState extends State<_WhatsAppPhoneDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String? phone = normalizeWhatsAppPhone(_controller.text);
    if (phone == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(phone);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.posWhatsAppPhoneTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        decoration: InputDecoration(
          hintText: context.l10n.posWhatsAppPhoneHint,
          errorText: _invalid ? context.l10n.posWhatsAppPhoneInvalid : null,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.posWhatsAppPhoneCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.posWhatsAppPhoneSend),
        ),
      ],
    );
  }
}
