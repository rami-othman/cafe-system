import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class DesktopPageLayout extends StatelessWidget {
  const DesktopPageLayout({
    super.key,
    required this.child,
    this.padding = AppSpacing.allXl,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.contentBackground,
      child: Padding(padding: padding, child: child),
    );
  }
}
