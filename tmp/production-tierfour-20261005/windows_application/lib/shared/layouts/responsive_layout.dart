import 'package:flutter/widgets.dart';

import '../../core/utils/responsive.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.desktop,
    this.tablet,
    this.mobile,
  });

  final Widget desktop;
  final Widget? tablet;
  final Widget? mobile;

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return desktop;
    }

    if (Responsive.isTablet(context)) {
      return tablet ?? desktop;
    }

    return mobile ?? tablet ?? desktop;
  }
}
