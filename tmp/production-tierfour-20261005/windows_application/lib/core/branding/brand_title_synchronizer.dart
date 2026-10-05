import 'package:flutter/widgets.dart';

import 'app_brand.dart';
import 'app_title_service.dart';

class BrandTitleSynchronizer extends StatefulWidget {
  const BrandTitleSynchronizer({
    super.key,
    required this.identity,
    required this.child,
  });

  final BrandIdentity identity;
  final Widget child;

  @override
  State<BrandTitleSynchronizer> createState() => _BrandTitleSynchronizerState();
}

class _BrandTitleSynchronizerState extends State<BrandTitleSynchronizer> {
  @override
  void initState() {
    super.initState();
    _synchronize();
  }

  @override
  void didUpdateWidget(BrandTitleSynchronizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity.windowTitle != widget.identity.windowTitle) {
      _synchronize();
    }
  }

  void _synchronize() {
    setApplicationTitle(widget.identity.windowTitle);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
