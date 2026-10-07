import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'file_handoff_types.dart';
import 'whatsapp_extension_bridge.dart' as bridge;

/// Saves the PNG to a temp file and puts the image on the Windows clipboard so
/// the cashier can paste it (Ctrl+V) straight into the WhatsApp chat.
Future<FileHandoffResult> handOffImage(Uint8List bytes, String fileName) async {
  try {
    final Directory dir = await getTemporaryDirectory();
    final String safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final File file = File('${dir.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(bytes, flush: true);
    if (!Platform.isWindows) return FileHandoffResult.failed;
    final String escaped = file.path.replaceAll("'", "''");
    final ProcessResult result = await Process.run('powershell', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-STA',
      '-Command',
      'Add-Type -AssemblyName System.Windows.Forms,System.Drawing; '
          "\$img = [System.Drawing.Image]::FromFile('$escaped'); "
          '[System.Windows.Forms.Clipboard]::SetImage(\$img); '
          '\$img.Dispose()',
    ]);
    return result.exitCode == 0
        ? FileHandoffResult.copiedToClipboard
        : FileHandoffResult.failed;
  } catch (_) {
    return FileHandoffResult.failed;
  }
}

Future<void> startWhatsAppBridge() => bridge.startWhatsAppBridge();

Future<bool> isWhatsAppExtensionConnected() => bridge.isWhatsAppExtensionConnected();

/// Sends [image] to [phone] through the user's own WhatsApp Web tab (via the
/// Chrome extension), with no manual step. See whatsapp_extension_bridge.dart.
Future<ChromeSendResult> sendImageViaChrome({
  required String phone,
  required Uint8List image,
  required String fileName,
}) =>
    bridge.sendViaChromeExtension(phone: phone, image: image, fileName: fileName);

/// Opens [url] in Google Chrome when it is installed (Windows); false otherwise
/// so the caller can fall back to the default browser.
Future<bool> openInChrome(String url) async {
  if (!Platform.isWindows) return false;
  final List<String> roots = <String?>[
    Platform.environment['ProgramFiles'],
    Platform.environment['ProgramFiles(x86)'],
    Platform.environment['LOCALAPPDATA'],
  ].whereType<String>().toList();
  for (final String root in roots) {
    final File chrome = File('$root\\Google\\Chrome\\Application\\chrome.exe');
    if (await chrome.exists()) {
      try {
        await Process.start(chrome.path, <String>[
          url,
        ], mode: ProcessStartMode.detached);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
  return false;
}
