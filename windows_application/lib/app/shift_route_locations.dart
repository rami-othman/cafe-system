/// Standalone route path constants for the Shift module, kept
/// dependency-free (like `shift_close_route_locations.dart`) so the router,
/// the sidebar and the module shell can all reference them without a
/// circular import on `app_router.dart`.
abstract final class ShiftRouteLocations {
  static const String root = '/shift';
  static const String current = '/shift/current';
  static const String history = '/shift/history';
  static const String closing = '/shift/closing';
  static const String reportPattern = '/shift/report/:shiftNumber';

  static String report(String shiftNumber) => '/shift/report/$shiftNumber';

  /// Module sub-navigation is shown for the two browsing tabs only. The
  /// closing wizard and the report are linear flows that own their own
  /// back affordance.
  static bool showsModuleTabs(String location) =>
      location == current ||
      location == history ||
      location == root ||
      location.isEmpty;

  static String activeTabFor(String location) =>
      location.startsWith(history) ? 'history' : 'current';

  static bool isShiftLocation(String location) =>
      location == root || location.startsWith('$root/');
}
