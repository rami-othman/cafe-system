import 'dart:typed_data';

import 'file_handoff_types.dart';

Future<FileHandoffResult> handOffImage(Uint8List bytes, String fileName) async =>
    FileHandoffResult.failed;

Future<bool> openInChrome(String url) async => false;

void reserveChatTab() {}

bool openReservedChat(String url) => false;

void releaseChatTab() {}

Future<void> startWhatsAppBridge() async {}

Future<bool> isWhatsAppExtensionConnected() async => false;

Future<ChromeSendResult> sendImageViaChrome({
  required String phone,
  required Uint8List image,
  required String fileName,
}) async => const ChromeSendResult(ChromeSendStatus.unavailable);
