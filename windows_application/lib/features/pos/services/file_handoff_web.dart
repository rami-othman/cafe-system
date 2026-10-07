import 'dart:async';
import 'dart:convert';
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

web.Window? _reservedChatTab;

/// Browsers only allow a new tab straight after a click, and the receipt image
/// is prepared asynchronously first. So the tab is opened empty at click time
/// and pointed at the chat (or closed) once the result is known.
void reserveChatTab() {
  // With the extension installed it opens/uses the WhatsApp tab itself.
  if (_extensionSeen) return;
  try {
    _reservedChatTab = web.window.open('about:blank', '_blank');
  } catch (_) {
    _reservedChatTab = null;
  }
}

bool openReservedChat(String url) {
  final web.Window? tab = _reservedChatTab;
  _reservedChatTab = null;
  if (tab == null) return false;
  try {
    tab.location.href = url;
    return true;
  } catch (_) {
    return false;
  }
}

void releaseChatTab() {
  final web.Window? tab = _reservedChatTab;
  _reservedChatTab = null;
  try {
    tab?.close();
  } catch (_) {}
}

// --- Chrome extension (talks to this page through window.postMessage) --------

const String _fromPage = 'cafe618-pos';
const String _fromExtension = 'cafe618-ext';
bool _extensionSeen = false;

void _postToExtension(Map<String, Object?> message) {
  web.window.postMessage(
    <String, Object?>{'source': _fromPage, ...message}.jsify(),
    web.window.location.origin.toJS,
  );
}

/// Listens for messages from the extension until [onMessage] returns true.
/// Returns a function that removes the listener.
void Function() _listen(bool Function(Map<Object?, Object?> data) onMessage) {
  late final JSFunction listener;
  void remove() => web.window.removeEventListener('message', listener);
  listener = ((web.MessageEvent event) {
    final Object? data = event.data.dartify();
    if (data is! Map || data['source'] != _fromExtension) return;
    if (data['type'] == 'wa-pong') _extensionSeen = true;
    if (onMessage(data)) remove();
  }).toJS;
  web.window.addEventListener('message', listener);
  return remove;
}

/// Asks the page's extension helper whether the extension is installed.
Future<void> startWhatsAppBridge() async {
  await isWhatsAppExtensionConnected();
}

Future<bool> isWhatsAppExtensionConnected() async {
  if (_extensionSeen) return true;
  final Completer<bool> answer = Completer<bool>();
  final void Function() stop = _listen((Map<Object?, Object?> data) {
    if (data['type'] != 'wa-pong') return false;
    if (!answer.isCompleted) answer.complete(true);
    return true;
  });
  _postToExtension(<String, Object?>{'type': 'wa-ping'});
  try {
    return await answer.future.timeout(const Duration(milliseconds: 800));
  } on TimeoutException {
    stop();
    return false;
  }
}

/// Sends [image] to [phone] through the Chrome extension: it opens (or reuses)
/// the WhatsApp Web tab, pastes the image, sends it and comes back to the POS.
Future<ChromeSendResult> sendImageViaChrome({
  required String phone,
  required Uint8List image,
  required String fileName,
}) async {
  if (!await isWhatsAppExtensionConnected()) {
    return const ChromeSendResult(
      ChromeSendStatus.unavailable,
      detail: 'Chrome extension is not connected',
    );
  }
  final String id = DateTime.now().microsecondsSinceEpoch.toString();
  final Completer<Map<Object?, Object?>> result =
      Completer<Map<Object?, Object?>>();
  final void Function() stop = _listen((Map<Object?, Object?> data) {
    final Object? body = data['body'];
    if (data['type'] != 'wa-result' || body is! Map || body['id'] != id) {
      return false;
    }
    if (!result.isCompleted) result.complete(body);
    return true;
  });
  _postToExtension(<String, Object?>{
    'type': 'wa-send',
    'job': <String, Object?>{
      'id': id,
      'phone': phone,
      'fileName': fileName,
      'image': base64Encode(image),
    },
  });
  try {
    final Map<Object?, Object?> body = await result.future.timeout(
      const Duration(seconds: 150),
    );
    final String? detail = body['detail'] as String?;
    return switch (body['status']) {
      'sent' => const ChromeSendResult(ChromeSendStatus.sent),
      'needsLogin' => const ChromeSendResult(ChromeSendStatus.needsLogin),
      'failedBeforeSend' => ChromeSendResult(
        ChromeSendStatus.failedBeforeSend,
        detail: detail,
      ),
      _ => ChromeSendResult(ChromeSendStatus.uncertain, detail: detail),
    };
  } on TimeoutException {
    stop();
    return const ChromeSendResult(
      ChromeSendStatus.uncertain,
      detail: 'No answer from WhatsApp',
    );
  }
}
