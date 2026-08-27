import 'package:flutter/material.dart';

import '../core/constants/app_sizes.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../shared/widgets/app_sidebar.dart';
import '../shared/widgets/app_top_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.activeLabel,
    this.rightPanel,
    this.topBar,
    this.showDefaultTopBar = false,
    this.onRefresh,
    this.textDirection = TextDirection.ltr,
    this.sidebarWidth,
    this.topBarHeight,
    this.sidebarLogoSize,
    this.sidebarPadding,
  });

  final Widget child;
  final String activeLabel;
  final Widget? rightPanel;
  final Widget? topBar;
  final bool showDefaultTopBar;
  final Future<void> Function(BuildContext context)? onRefresh;
  final TextDirection textDirection;
  final double? sidebarWidth;
  final double? topBarHeight;
  final double? sidebarLogoSize;
  final EdgeInsetsGeometry? sidebarPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.shellBackground,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool isLarge = Responsive.isLargeWidth(width);
          final bool isCompact = Responsive.isCompactWidth(width);
          final double rightPanelWidth = isLarge
              ? AppSizes.rightPanelWidth
              : AppSizes.mediumRightPanelWidth;

          final Widget content = Expanded(
            child: Column(
              children: <Widget>[
                if (topBar == null || showDefaultTopBar)
                    AppTopBar(
                      showCartButton: isCompact && rightPanel != null,
                      onRefresh: onRefresh,
                      height: topBarHeight ?? AppSizes.topBarHeight,
                    ),
                if (topBar != null) topBar!,
                Expanded(child: child),
              ],
            ),
          );
          final Widget sidebar = AppSidebar(
            activeLabel: activeLabel,
            isCollapsed: !isLarge,
            textDirection: textDirection,
            expandedWidth: sidebarWidth ?? AppSizes.sidebarWidth,
            logoMarkSize: sidebarLogoSize ?? AppSizes.logoMarkSize,
            padding: sidebarPadding,
          );
          final Widget? panel = !isCompact && rightPanel != null
              ? SizedBox(width: rightPanelWidth, child: rightPanel)
              : null;

          return Directionality(
            textDirection: textDirection,
            child: Row(
              // Row already places its first child at the physical right in RTL.
              // Keeping this order stable prevents a second, manual reversal.
              children: <Widget>[sidebar, content, ?panel],
            ),
          );
        },
      ),
    );
  }
}
