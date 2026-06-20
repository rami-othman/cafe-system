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
  });

  final Widget child;
  final String activeLabel;
  final Widget? rightPanel;

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

          return Row(
            children: <Widget>[
              AppSidebar(activeLabel: activeLabel, isCollapsed: !isLarge),
              Expanded(
                child: Column(
                  children: <Widget>[
                    AppTopBar(showCartButton: isCompact && rightPanel != null),
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
