import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'manufacturing_navigation_bar.dart';

/// Shared Manufacturing frame, mirroring [InventoryModuleShell]: a fixed
/// navigation bar above a scrollable page body. Phase 1 only ever mounts the
/// Overview tab; the other tabs render as disabled placeholders inside
/// [ManufacturingNavigationBar] rather than routing anywhere.
class ManufacturingModuleShell extends StatelessWidget {
  const ManufacturingModuleShell({
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
        ManufacturingNavigationBar(selected: selectedTab),
        Expanded(child: child),
      ],
    ),
  );
}
