import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'inventory_navigation_bar.dart';

/// Shared inventory frame. The navigation is outside the expanded page body,
/// which keeps it fixed while dashboards, tables, and forms scroll.
class InventoryModuleShell extends StatelessWidget {
  const InventoryModuleShell({
    super.key,
    required this.selectedTab,
    required this.child,
  });

  final String selectedTab;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.contentBackground,
    child: Column(
      children: <Widget>[
        InventoryNavigationBar(selected: selectedTab),
        Expanded(child: child),
      ],
    ),
  );
}
