enum FileHandoffResult { copiedToClipboard, downloaded, failed }

enum ChromeSendStatus {
  /// Image pasted into the chat and sent.
  sent,

  /// WhatsApp Web shows the QR code: the cashier must link the dedicated
  /// Chrome window once.
  needsLogin,

  /// Not Windows / Chrome missing: use the manual flow.
  unavailable,

  /// Stopped before pressing send: nothing went out, safe to fall back.
  failedBeforeSend,

  /// Send was pressed but not confirmed: do not retry blindly.
  uncertain,
}

class ChromeSendResult {
  const ChromeSendResult(this.status, {this.detail});

  final ChromeSendStatus status;
  final String? detail;
}
