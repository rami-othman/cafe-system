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
    this.onRefresh,
    this.textDirection = TextDirection.ltr,
    this.sidebarWidth,
    this.topBarHeight,
  });

  final Widget child;
  final String activeLabel;
  final Widget? rightPanel;
  final Widget? topBar;
  final Future<void> Function(BuildContext context)? onRefresh;
  final TextDirection textDirection;
  final double? sidebarWidth;
  final double? topBarHeight;

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
                topBar ??
                    AppTopBar(
                      showCartButton: isCompact && rightPanel != null,
                      onRefresh: onRefresh,
                      height: topBarHeight ?? AppSizes.topBarHeight,
                    ),
                Expanded(child: child),
              ],
            ),
          );
          final Widget sidebar = AppSidebar(
            activeLabel: activeLabel,
            isCollapsed: !isLarge,
            textDirection: textDirection,
            expandedWidth: sidebarWidth ?? AppSizes.sidebarWidth,
          );
          final Widget? panel = !isCompact && rightPanel != null
              ? SizedBox(width: rightPanelWidth, child: rightPanel)
              : null;

          return Directionality(
            textDirection: textDirection,
            child: Row(
              children: textDirection == TextDirection.rtl
                  ? <Widget>[content, sidebar, ?panel]
                  : <Widget>[sidebar, content, ?panel],
            ),
          );
        },
      ),
    );
  }
}
