import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shift_route_locations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'shift_design.dart';
import 'shift_strings.dart';

/// The single Shift module frame, mounted once by the router for every
/// `/shift/*` route.
///
/// It owns the workspace background and the module's only sub-navigation
/// (الوردية الحالية / سجل الورديات). The closing wizard and the report
/// deliberately hide the tabs: both are linear flows where leaving mid-way
/// would drop counted work, so they present their own back affordance
/// instead.
class ShiftModuleShell extends StatelessWidget {
  const ShiftModuleShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  bool get _showTabs => ShiftRouteLocations.showsModuleTabs(location);

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ShiftColors.workspace,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_showTabs) ShiftModuleTabs(location: location),
        Expanded(child: child),
      ],
    ),
  );
}

class ShiftModuleTabs extends StatelessWidget {
  const ShiftModuleTabs({super.key, required this.location});

  final String location;

  static const List<_ShiftTab> _tabs = <_ShiftTab>[
    _ShiftTab(
      id: 'current',
      label: ShiftStrings.tabCurrent,
      icon: Icons.schedule_outlined,
      path: ShiftRouteLocations.current,
    ),
    _ShiftTab(
      id: 'history',
      label: ShiftStrings.tabHistory,
      icon: Icons.history_outlined,
      path: ShiftRouteLocations.history,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final String activeId = ShiftRouteLocations.activeTabFor(location);
    return Container(
      decoration: const BoxDecoration(
        color: ShiftColors.surface,
        border: Border(bottom: BorderSide(color: ShiftColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final _ShiftTab tab in _tabs)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: _TabButton(
                  tab: tab,
                  isActive: tab.id == activeId,
                  onTap: () => context.go(tab.path),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _ShiftTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: isActive ? ShiftColors.headerFill : Colors.transparent,
    borderRadius: AppRadius.control,
    child: InkWell(
      key: Key('shift-tab-${tab.id}'),
      borderRadius: AppRadius.control,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: ShiftLayout.touchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              tab.icon,
              size: 16,
              color: isActive ? ShiftColors.ink : ShiftColors.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: ShiftText.bodyStrong.copyWith(
                color: isActive ? ShiftColors.ink : ShiftColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShiftTab {
  const _ShiftTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
  });

  final String id;
  final String label;
  final IconData icon;
  final String path;
}
