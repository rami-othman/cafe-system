import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Renders the receipt paper behind [boundaryKey] into a PNG, exactly as the
/// cashier sees it (Flutter does the Arabic shaping).
Future<Uint8List> buildReceiptPng(GlobalKey boundaryKey) async {
  final RenderObject? renderObject = boundaryKey.currentContext
      ?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError('Receipt is not on screen.');
  }
  final ui.Image image = await renderObject.toImage(pixelRatio: 3);
  try {
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (data == null) throw StateError('Could not render the receipt.');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
