import 'dart:typed_data';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../repositories/pos_repository.dart';
import 'file_handoff.dart';

enum WhatsAppSendStatus {
  /// Sent by the backend through the WhatsApp Cloud API.
  sentViaApi,

  /// Sent through the app's own Chrome window (no manual step).
  sentViaChrome,

  /// The app's Chrome window needs the one-time WhatsApp QR login.
  needsLogin,

  /// Send was pressed in Chrome but not confirmed; check the chat.
  uncertain,

  /// Chat opened in the browser and the image is on the clipboard (Ctrl+V).
  manualClipboard,

  /// Chat opened in the browser and the image was downloaded (drag it in).
  manualDownload,

  /// Chat opened but the image could not be prepared.
  manualChatOnly,

  failed,
}

class WhatsAppSendOutcome {
  const WhatsAppSendOutcome(this.status, {this.detail});

  final WhatsAppSendStatus status;

  /// Why it failed (server message / status), for diagnostics.
  final String? detail;
}

/// Sends a receipt image to a customer. Uses the backend's WhatsApp Cloud API when
/// it is configured; otherwise opens the WhatsApp Web chat in the browser and
/// hands the image to the cashier to attach.
class ReceiptWhatsAppSender {
  const ReceiptWhatsAppSender(this.repository);

  final PosRepository repository;

  /// The backend answers this when no Cloud API credentials are set up.
  static const String notConfiguredCode = 'whatsapp_not_configured';

  Future<WhatsAppSendOutcome> send({
    required int? orderId,
    required String phone,
    required Uint8List image,
    required String fileName,
  }) async {
    if (orderId != null) {
      try {
        await repository.sendReceiptViaWhatsApp(
          orderId: orderId,
          phone: phone,
          imageBytes: image,
          fileName: fileName,
        );
        return const WhatsAppSendOutcome(WhatsAppSendStatus.sentViaApi);
      } on ApiException catch (error) {
        // Only the "not configured" answer falls back to the manual flow: any
        // other failure may have reached WhatsApp, so never send twice.
        // 503 is the backend's "not configured" answer (the client does not
        // always keep the body's code for 5xx); 404/405 mean this backend has
        // no WhatsApp route. In all three nothing was sent.
        final bool nothingSent =
            error.code == notConfiguredCode ||
            error.statusCode == 503 ||
            error.statusCode == 404 ||
            error.statusCode == 405;
        if (!nothingSent) {
          return WhatsAppSendOutcome(
            WhatsAppSendStatus.failed,
            detail: '${error.statusCode ?? ''} ${error.message}'.trim(),
          );
        }
      }
    }

    // No Cloud API. If the Chrome extension is running in the cashier's own
    // WhatsApp tab, it opens the chat in THAT tab and sends. This never opens a
    // new tab: tabs are only opened below when no extension is listening.
    String? detail = 'Chrome extension is not connected';
    if (await isWhatsAppExtensionConnected()) {
      final ChromeSendResult auto = await sendImageViaChrome(
        phone: phone,
        image: image,
        fileName: fileName,
      );
      switch (auto.status) {
        case ChromeSendStatus.sent:
          return const WhatsAppSendOutcome(WhatsAppSendStatus.sentViaChrome);
        case ChromeSendStatus.needsLogin:
          return const WhatsAppSendOutcome(WhatsAppSendStatus.needsLogin);
        case ChromeSendStatus.uncertain:
          return WhatsAppSendOutcome(
            WhatsAppSendStatus.uncertain,
            detail: auto.detail,
          );
        case ChromeSendStatus.unavailable:
        case ChromeSendStatus.failedBeforeSend:
          // The extension already has the chat open in the existing tab: only
          // put the image on the clipboard, never open another tab.
          detail = auto.detail;
          final FileHandoffResult handoff = await handOffImage(image, fileName);
          return WhatsAppSendOutcome(_manualStatus(handoff), detail: detail);
      }
    }

    // No extension: open exactly one chat tab with the image on the clipboard.
    final FileHandoffResult handoff = await handOffImage(image, fileName);
    // No pre-filled text: the message is the image itself (Ctrl+V in the chat).
    final Uri chat = Uri.https('web.whatsapp.com', '/send', <String, String>{
      'phone': phone,
    });
    final bool opened = await openInChrome(chat.toString()) || await _open(chat);
    if (!opened) {
      return WhatsAppSendOutcome(WhatsAppSendStatus.failed, detail: detail);
    }
    return WhatsAppSendOutcome(_manualStatus(handoff), detail: detail);
  }

  static WhatsAppSendStatus _manualStatus(FileHandoffResult handoff) {
    return switch (handoff) {
      FileHandoffResult.copiedToClipboard => WhatsAppSendStatus.manualClipboard,
      FileHandoffResult.downloaded => WhatsAppSendStatus.manualDownload,
      FileHandoffResult.failed => WhatsAppSendStatus.manualChatOnly,
    };
  }

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
