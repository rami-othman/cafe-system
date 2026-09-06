import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import 'finance_design.dart';
import 'finance_navigation_bar.dart';

/// The single Finance module frame, mounted once by the router for every
/// `/finance/*` route. Owns everything that must never be duplicated per
/// page: the workspace background, the notifications/profile row, the
/// breadcrumb, and the one [FinanceNavigationBar] instance. Screens
/// underneath provide only their own content (optionally via [FinanceShell]
/// for a page title/actions row) — never another copy of this chrome.
///
/// Direction follows the ambient (locale-driven) [Directionality] from
/// [MaterialApp] — Arabic renders RTL, English renders LTR. Nothing here
/// forces a physical direction; the module has no numeric/code content of
/// its own that would need an LTR exception.
class FinanceModuleShell extends StatelessWidget {
  const FinanceModuleShell({
    super.key,
    required this.currentSection,
    required this.selectedTab,
    required this.child,
  });

  final String currentSection;
  final String selectedTab;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FinanceColors.workspace,
    child: Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FinanceSpace.pageX,
            FinanceSpace.md,
            FinanceSpace.pageX,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.financeBreadcrumb(
                    context.l10n.navigationFinance,
                    currentSection,
                  ),
                  style: FinanceText.small,
                ),
              ),
              const Icon(
                Icons.notifications_none,
                color: FinanceColors.primary,
              ),
              const SizedBox(width: FinanceSpace.md),
              const Icon(Icons.person_outline, color: FinanceColors.primary),
            ],
          ),
        ),
        const SizedBox(height: FinanceSpace.md),
        FinanceNavigationBar(selected: selectedTab),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FinanceSpace.pageX,
              FinanceSpace.xl,
              FinanceSpace.pageX,
              28,
            ),
            child: child,
          ),
        ),
      ],
    ),
  );
}
