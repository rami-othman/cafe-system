import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _windowChannel = MethodChannel('cafe618/window');

Future<void> setApplicationTitle(String title) async {
  if (!Platform.isWindows) return;
  try {
    await _windowChannel.invokeMethod<void>('setTitle', <String, String>{
      'title': title,
    });
  } on MissingPluginException {
    // Widget tests and non-runner embedders do not install the native channel.
  }
}
