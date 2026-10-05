import 'package:flutter/widgets.dart';

import '../models/selected_product_image.dart';

/// Browser file selection remains available through FilePicker. Native drag
/// and drop is supplied by the Windows conditional implementation.
class ProductImageDropTarget extends StatelessWidget {
  const ProductImageDropTarget({
    required this.child,
    required this.onDrop,
    super.key,
  });

  final Widget child;
  final ValueChanged<SelectedProductImage> onDrop;

  @override
  Widget build(BuildContext context) => child;
}
