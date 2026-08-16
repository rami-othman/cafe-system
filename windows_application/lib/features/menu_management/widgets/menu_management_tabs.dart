import 'package:flutter/widgets.dart';

/// Kept only so isolated legacy screen tests and downstream imports compile.
///
/// Batch 2 moves visible module navigation to MenuModuleNavigation in the
/// AppShell route wrapper. This widget must not render a second navigation
/// system. Remove this compatibility shim during the planned Phase 4K cleanup.
class MenuManagementTabs extends StatelessWidget {
  const MenuManagementTabs({super.key, required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
