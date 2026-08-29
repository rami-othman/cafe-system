import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The leave policy currently owned by the visible editor.
///
/// Editors register this policy for their lifetime. Shell navigation consults
/// it before replacing the current route, keeping route changes and browser
/// back actions on the same editor-owned confirmation path.
class UnsavedNavigationGuard {
  const UnsavedNavigationGuard({
    required this.isDirty,
    required this.confirmLeave,
  });

  final bool Function() isDirty;
  final Future<bool> Function() confirmLeave;
}

class UnsavedNavigationController extends ChangeNotifier {
  UnsavedNavigationGuard? _guard;
  bool _confirming = false;

  VoidCallback register(UnsavedNavigationGuard guard) {
    _guard = guard;
    return () {
      if (identical(_guard, guard)) {
        _guard = null;
      }
    };
  }

  /// The first requested destination wins while a discard confirmation is
  /// visible. This prevents duplicate dialogs and competing route changes.
  void go(BuildContext context, String location) {
    if (_confirming) return;
    final UnsavedNavigationGuard? guard = _guard;
    if (guard == null || !guard.isDirty()) {
      context.go(location);
      return;
    }
    _confirmAndGo(context, guard, location);
  }

  Future<void> _confirmAndGo(
    BuildContext context,
    UnsavedNavigationGuard guard,
    String location,
  ) async {
    _confirming = true;
    try {
      final bool approved = await guard.confirmLeave();
      if (approved && context.mounted && identical(_guard, guard)) {
        context.go(location);
      }
    } finally {
      _confirming = false;
    }
  }
}

class UnsavedNavigationScope
    extends InheritedNotifier<UnsavedNavigationController> {
  const UnsavedNavigationScope({
    super.key,
    required UnsavedNavigationController controller,
    required super.child,
  }) : super(notifier: controller);

  static UnsavedNavigationController of(BuildContext context) {
    final UnsavedNavigationScope? scope = context
        .dependOnInheritedWidgetOfExactType<UnsavedNavigationScope>();
    assert(scope != null, 'UnsavedNavigationScope is missing.');
    return scope!.notifier!;
  }

  static UnsavedNavigationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<UnsavedNavigationScope>()
      ?.notifier;
}

extension GuardedNavigationContext on BuildContext {
  void guardedGo(String location) {
    final UnsavedNavigationController? controller =
        UnsavedNavigationScope.maybeOf(this);
    if (controller == null) {
      go(location);
      return;
    }
    controller.go(this, location);
  }
}
