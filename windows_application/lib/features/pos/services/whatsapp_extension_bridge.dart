import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'file_handoff_types.dart';

// Local bridge between the POS app and the "Cafe 618 WhatsApp Sender" Chrome
// extension (see /whatsapp_chrome_extension). The extension runs inside the
// user's own WhatsApp Web tab and polls this server; the app queues a receipt
// and waits for the extension to report what happened.
//
// Loopback only. Every request must carry the X-Cafe-Client header, which a
// web page cannot add without a CORS preflight that this server refuses.

const int _bridgePort = 47618;
const String _clientHeader = 'x-cafe-client';
const String _clientValue = 'whatsapp-bridge';

// A hidden WhatsApp tab may be throttled by Chrome to about one poll a minute.
const Duration _connectedWindow = Duration(seconds: 75);
const Duration _pickupTimeout = Duration(seconds: 75);
const Duration _resultTimeout = Duration(seconds: 150);

/// Starts the local server early so the extension can connect before a send.
Future<void> startWhatsAppBridge() async {
  if (Platform.isWindows) await _Bridge.instance.start();
}

/// True when a WhatsApp Web tab with the extension polled recently.
Future<bool> isWhatsAppExtensionConnected() async =>
    Platform.isWindows && await _Bridge.instance.start() && _Bridge.instance.connected;

Future<ChromeSendResult> sendViaChromeExtension({
  required String phone,
  required Uint8List image,
  required String fileName,
}) => _Bridge.instance.send(phone: phone, image: image, fileName: fileName);

class _Job {
  _Job(this.id, this.phone, this.fileName, this.image);

  final String id;
  final String phone;
  final String fileName;
  final String image; // base64 PNG

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'phone': phone,
    'fileName': fileName,
    'image': image,
  };
}

class _Bridge {
  _Bridge._();

  static final _Bridge instance = _Bridge._();

  HttpServer? _server;
  DateTime? _lastPoll;
  int _nextId = 0;
  final Queue<_Job> _queue = Queue<_Job>();
  final Map<String, Completer<ChromeSendResult>> _waiting =
      <String, Completer<ChromeSendResult>>{};

  bool get connected {
    final DateTime? last = _lastPoll;
    return last != null && DateTime.now().difference(last) < _connectedWindow;
  }

  Future<ChromeSendResult> send({
    required String phone,
    required Uint8List image,
    required String fileName,
  }) async {
    if (!Platform.isWindows) {
      return const ChromeSendResult(ChromeSendStatus.unavailable);
    }
    if (!await start()) {
      return const ChromeSendResult(
        ChromeSendStatus.unavailable,
        detail: 'Could not start the local bridge',
      );
    }
    // Never opens tabs: with no WhatsApp tab polling the caller opens exactly one.
    if (!connected) {
      return const ChromeSendResult(
        ChromeSendStatus.unavailable,
        detail: 'Chrome extension is not connected',
      );
    }

    final _Job job = _Job(
      '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
      phone,
      fileName,
      base64Encode(image),
    );
    final Completer<ChromeSendResult> completer =
        Completer<ChromeSendResult>();
    _waiting[job.id] = completer;
    _queue.add(job);
    // Never picked up: nothing was sent, so the caller may fall back.
    Timer(_pickupTimeout, () {
      if (_queue.remove(job)) {
        _waiting.remove(job.id)?.complete(
          const ChromeSendResult(
            ChromeSendStatus.unavailable,
            detail: 'The WhatsApp tab did not respond',
          ),
        );
      }
    });
    return completer.future.timeout(
      _resultTimeout,
      onTimeout: () {
        _waiting.remove(job.id);
        return const ChromeSendResult(
          ChromeSendStatus.uncertain,
          detail: 'No answer from the WhatsApp tab',
        );
      },
    );
  }

  Future<bool> start() async {
    if (_server != null) return true;
    try {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _bridgePort,
      );
      _server = server;
      server.listen(_handle, onError: (Object _) {});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    try {
      final String? origin = request.headers.value('origin');
      final bool fromExtension =
          origin != null && origin.startsWith('chrome-extension://');
      if (request.method == 'OPTIONS') {
        if (fromExtension) {
          response.headers
            ..set('Access-Control-Allow-Origin', origin)
            ..set('Access-Control-Allow-Headers', 'x-cafe-client, content-type')
            ..set('Access-Control-Allow-Methods', 'GET, POST');
          response.statusCode = 204;
        } else {
          response.statusCode = 403;
        }
      } else if (request.headers.value(_clientHeader) != _clientValue) {
        response.statusCode = 403;
      } else {
        if (fromExtension) {
          response.headers.set('Access-Control-Allow-Origin', origin);
        }
        final String path = request.uri.path;
        if (request.method == 'GET' && path == '/wa/next') {
          _lastPoll = DateTime.now();
          final _Job? job = _queue.isEmpty ? null : _queue.removeFirst();
          if (job == null) {
            response.statusCode = 204;
          } else {
            response.headers.contentType = ContentType.json;
            response.write(jsonEncode(job.toJson()));
          }
        } else if (request.method == 'POST' && path == '/wa/result') {
          final dynamic body = jsonDecode(
            await utf8.decoder.bind(request).join(),
          );
          if (body is Map) {
            _complete(
              '${body['id']}',
              '${body['status']}',
              body['detail'] is String ? body['detail'] as String : null,
            );
          }
          response.statusCode = 200;
        } else {
          response.statusCode = 404;
        }
      }
    } catch (_) {
      try {
        response.statusCode = 500;
      } catch (_) {}
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  void _complete(String id, String status, String? detail) {
    final Completer<ChromeSendResult>? completer = _waiting.remove(id);
    if (completer == null || completer.isCompleted) return;
    completer.complete(
      ChromeSendResult(switch (status) {
        'sent' => ChromeSendStatus.sent,
        'needsLogin' => ChromeSendStatus.needsLogin,
        'failedBeforeSend' => ChromeSendStatus.failedBeforeSend,
        _ => ChromeSendStatus.uncertain,
      }, detail: detail),
    );
  }
}
