import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_handoff_types.dart';

/// On the web a file cannot be put on the clipboard, so the image is downloaded
/// and the cashier drags it into the WhatsApp chat.
Future<FileHandoffResult> handOffImage(Uint8List bytes, String fileName) async {
  try {
    final web.Blob blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final String url = web.URL.createObjectURL(blob);
    final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    anchor.click();
    web.URL.revokeObjectURL(url);
    return FileHandoffResult.downloaded;
  } catch (_) {
    return FileHandoffResult.failed;
  }
}

Future<bool> openInChrome(String url) async => false;

Future<void> startWhatsAppBridge() async {}

Future<bool> isWhatsAppExtensionConnected() async => false;

Future<ChromeSendResult> sendImageViaChrome({
  required String phone,
  required Uint8List image,
  required String fileName,
}) async => const ChromeSendResult(ChromeSendStatus.unavailable);
