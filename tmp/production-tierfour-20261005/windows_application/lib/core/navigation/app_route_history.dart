import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'unsaved_navigation_guard.dart';

/// Records visible routes because module tabs use `go`, which replaces the
/// Navigator stack and makes `canPop` insufficient for Back.
class AppRouteHistory extends ChangeNotifier {
  GoRouter? _router;
  final List<String> _locations = <String>[];

  bool get canGoBack => _locations.length > 1;

  void attach(GoRouter router) {
    if (identical(_router, router)) {
      _recordCurrent();
      return;
    }
    _router?.routeInformationProvider.removeListener(_recordCurrent);
    _router = router;
    _locations.clear();
    router.routeInformationProvider.addListener(_recordCurrent);
    _recordCurrent();
  }

  void _recordCurrent() {
    final String? location = _router?.routeInformationProvider.value.uri.toString();
    if (location == null || location.isEmpty) return;
    if (_locations.isNotEmpty && _locations.last == location) return;
    if (_locations.length > 1 && _locations[_locations.length - 2] == location) {
      _locations.removeLast();
    } else {
      _locations.add(location);
    }
    notifyListeners();
  }

  void goBack(BuildContext context) {
    if (!canGoBack) return;
    context.guardedGo(_locations[_locations.length - 2]);
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_recordCurrent);
    super.dispose();
  }
}

final AppRouteHistory appRouteHistory = AppRouteHistory();
