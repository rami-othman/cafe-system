import 'package:flutter/widgets.dart';

/// Refresh callback of the page currently shown inside the app shell.
///
/// Route-scoped cubits are provided below the shell, so the top bar's own
/// context cannot look them up. The page registers its refresh here instead.
abstract final class ShellPageRefresh {
  static Object? _owner;
  static Future<void> Function()? _handler;

  static void register(Object owner, Future<void> Function() handler) {
    _owner = owner;
    _handler = handler;
  }

  /// Only the page that registered can clear it, so a page that mounts before
  /// the previous one disposes is never left without a handler.
  static void unregister(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _handler = null;
  }

  static Future<void> run() async => _handler?.call();
}

/// Registers [refresh] with [ShellPageRefresh] while mounted. Place it below
/// the page's providers: [refresh] receives a context that can reach them.
class RegisterShellRefresh extends StatefulWidget {
  const RegisterShellRefresh({
    super.key,
    required this.refresh,
    required this.child,
  });

  final Future<void> Function(BuildContext context) refresh;
  final Widget child;

  @override
  State<RegisterShellRefresh> createState() => _RegisterShellRefreshState();
}

class _RegisterShellRefreshState extends State<RegisterShellRefresh> {
  @override
  void initState() {
    super.initState();
    ShellPageRefresh.register(this, () => widget.refresh(context));
  }

  @override
  void dispose() {
    ShellPageRefresh.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
