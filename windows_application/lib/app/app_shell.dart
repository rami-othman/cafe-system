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
    this.prioritizeContentWidth = false,
  });

  final Widget child;
  final String activeLabel;
  final Widget? rightPanel;
  final Widget? topBar;
  final Future<void> Function(BuildContext context)? onRefresh;
  final bool prioritizeContentWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.shellBackground,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool isLarge =
              Responsive.isLargeWidth(width) &&
              (!prioritizeContentWidth ||
                  width >= AppSizes.menuModuleSidebarExpandedBreakpoint);
          final bool isCompact = Responsive.isCompactWidth(width);
          final double rightPanelWidth = isLarge
              ? AppSizes.rightPanelWidth
              : AppSizes.mediumRightPanelWidth;

          return Row(
            children: <Widget>[
              AppSidebar(activeLabel: activeLabel, isCollapsed: !isLarge),
              Expanded(
                child: Column(
                  children: <Widget>[
                    topBar ??
                        AppTopBar(
                          showCartButton: isCompact && rightPanel != null,
                          onRefresh: onRefresh,
                        ),
                    Expanded(child: child),
                  ],
                ),
              ),
              if (!isCompact && rightPanel != null)
                SizedBox(width: rightPanelWidth, child: rightPanel),
            ],
          );
        },
      ),
    );
  }
}
