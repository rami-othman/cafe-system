import 'package:flutter/widgets.dart';

import '../constants/app_sizes.dart';

abstract final class Responsive {
  static bool isLargeWidth(double width) {
    return width >= AppSizes.mediumBreakpoint;
  }

  static bool isMediumWidth(double width) {
    return width >= AppSizes.compactBreakpoint &&
        width < AppSizes.mediumBreakpoint;
  }

  static bool isCompactWidth(double width) {
    return width < AppSizes.compactBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= AppSizes.desktopBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return width >= AppSizes.tabletBreakpoint &&
        width < AppSizes.desktopBreakpoint;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < AppSizes.tabletBreakpoint;
  }
}
