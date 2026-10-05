import 'dart:typed_data';

/// A browser- and desktop-safe product-image payload.
///
/// Uploads intentionally use bytes instead of a filesystem path so the same
/// catalog contract works for browser-selected and Windows-dropped files.
class SelectedProductImage {
  const SelectedProductImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}
