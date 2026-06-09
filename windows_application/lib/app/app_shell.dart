import 'package:flutter/material.dart';

import '../core/constants/app_sizes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/responsive.dart';
import '../shared/widgets/app_sidebar.dart';
import '../shared/widgets/app_top_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, this.rightPanel});

  final Widget child;
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
              AppSidebar(activeLabel: 'POS', isCollapsed: !isLarge),
              Expanded(
                child: Column(
                  children: <Widget>[
                    AppTopBar(showCartButton: isCompact && rightPanel != null),
                    Expanded(child: child),
                  ],
                ),
              ),
              if (!isCompact)
                SizedBox(
                  width: rightPanelWidth,
                  child: rightPanel ?? const _RightPanelPlaceholder(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RightPanelPlaceholder extends StatelessWidget {
  const _RightPanelPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(left: BorderSide(color: AppColors.shellBorder)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(-2, 0),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: AppSpacing.allXl,
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Cart panel will be implemented in POS UI step',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
