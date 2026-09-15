/// Standalone route path constants for the shift-close/bar-check flow, kept
/// dependency-free (like customer_management_route_locations.dart) so both
/// the router and shared widgets (e.g. the top bar's shift badge) can
/// reference them without a circular import on app_router.dart.
abstract final class ShiftCloseRouteLocations {
  static const String shiftClose = '/shift-close';
}
