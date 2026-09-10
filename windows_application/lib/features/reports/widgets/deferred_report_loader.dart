import 'package:flutter/widgets.dart';

/// Starts I/O only after the route has painted its shell, title, and filters.
/// This preserves an immediate route transition on Windows even when a future
/// report endpoint is slow.
class DeferredReportLoader extends StatefulWidget {
  const DeferredReportLoader({super.key, required this.load, required this.child});

  final Future<void> Function() load;
  final Widget child;

  @override
  State<DeferredReportLoader> createState() => _DeferredReportLoaderState();
}

class _DeferredReportLoaderState extends State<DeferredReportLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.load();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
