import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';

import '../models/selected_product_image.dart';

class ProductImageDropTarget extends StatelessWidget {
  const ProductImageDropTarget({
    required this.child,
    required this.onDrop,
    super.key,
  });

  final Widget child;
  final ValueChanged<SelectedProductImage> onDrop;

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragDone: (DropDoneDetails detail) async {
      if (detail.files.isEmpty) return;
      final file = detail.files.first;
      onDrop(
        SelectedProductImage(
          bytes: await file.readAsBytes(),
          filename: file.name,
          mimeType: _mimeTypeFor(file.name),
        ),
      );
    },
    child: child,
  );
}

String _mimeTypeFor(String filename) {
  final String extension = filename.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'application/octet-stream',
  };
}
