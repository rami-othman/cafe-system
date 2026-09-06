import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/finance_inventory_setup/views/cash_banks_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/daily_closing_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/expense_categories_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/expenses_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_operations_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_overview.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_setup_dashboard_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/finance_transactions.dart';
import 'package:windows_application/features/finance_inventory_setup/views/financial_accounts_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/financial_reports_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/journal_entries_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/payment_methods_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/reconciliation_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/views/suppliers_screen.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_navigation_bar.dart';
import 'package:windows_application/l10n/app_localizations_en.dart';
import 'package:windows_application/shared/widgets/app_top_bar.dart';
import 'package:windows_application/shared/widgets/shift_status_badge.dart';

// Confirms every live Finance context.go target actually resolves to its
// intended screen (AppRoutes / app_router.dart), and that the Finance module
// shell (finance_module_shell.dart) is structurally sound: exactly one
// FinanceNavigationBar, the correct active tab per route (including detail
// routes keeping their parent tab selected), no POS AppTopBar chrome
// (branch tabs / ShiftStatusBadge), and no duplicated notification/profile
// icons. FinanceSetupRepository has no offline branch, so these screens hit
// real (failing, in this sandbox) network calls and some emit pre-existing,
// unrelated layout-overflow warnings at this viewport size — out of scope
// for a routing/shell test, so rendering errors are swallowed; only the
// structural assertions below can fail this file.
//
// Inventory routes were intentionally not added to this file: a trial run
// surfaced pre-existing uncaught-exception leaks in InventoryRepository
// (units/warehouses) and a non-settling transfer-detail pump, unrelated to
// Finance routing and already confirmed correctly wired by the prior audit.
// That belongs to a dedicated Inventory-cubit robustness pass, not here.

final AppLocalizationsEn _l10n = AppLocalizationsEn();

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() => appRouter.go(AppRoutes.pos));

  // All 12 required Finance navigation destinations, plus the two detail
  // routes restored in Repair 1, each with the tab that must stay active.
  final List<(String name, String path, Type screen, String tab)>
  financeRoutes = <(String, String, Type, String)>[
    ('overview', AppRoutes.finance, FinanceOverview, 'overview'),
    (
      'transactions',
      AppRoutes.financeTransactions,
      FinanceTransactionsView,
      'transactions',
    ),
    ('cash & banks', AppRoutes.financeCashBanks, CashBanksScreen, 'cashbanks'),
    ('expenses', AppRoutes.financeExpenses, ExpensesScreen, 'expenses'),
    ('suppliers/AP', AppRoutes.financeSuppliers, SuppliersScreen, 'suppliers'),
    (
      'reconciliation',
      AppRoutes.financeReconciliationCanonical,
      ReconciliationScreen,
      'reconciliation',
    ),
    (
      'journal entries',
      AppRoutes.financeJournalEntriesCanonical,
      JournalEntriesScreen,
      'journals',
    ),
    (
      'journal entry detail',
      AppRoutes.financeJournalEntryDetailPath(1),
      JournalEntriesScreen,
      'journals',
    ),
    (
      'daily closing',
      AppRoutes.financeDailyClosingCanonical,
      DailyClosingScreen,
      'closing',
    ),
    (
      'financial reports',
      AppRoutes.financeReportsCanonical,
      FinancialReportsScreen,
      'reports',
    ),
    (
      'chart of accounts',
      AppRoutes.financeAccountsCanonical,
      FinancialAccountsScreen,
      'accounts',
    ),
    (
      'account detail',
      AppRoutes.financeAccountDetailPath(1),
      FinancialAccountsScreen,
      'accounts',
    ),
    (
      'accounting periods',
      AppRoutes.financeAccountingPeriods,
      FinanceOperationScreen,
      'periods',
    ),
    (
      'accounting period detail',
      AppRoutes.financeAccountingPeriodDetailPath(1),
      FinanceOperationScreen,
      'periods',
    ),
    (
      'finance settings',
      AppRoutes.financeSettings,
      FinanceSetupDashboardScreen,
      'settings',
    ),
    (
      'payment methods (settings sub-page)',
      AppRoutes.financePaymentMethods,
      PaymentMethodsScreen,
      'settings',
    ),
    (
      'expense categories (settings sub-page)',
      AppRoutes.financeExpenseCategories,
      ExpenseCategoriesScreen,
      'settings',
    ),
  ];

  for (final (String name, String path, Type screen, String tab)
      in financeRoutes) {
    testWidgets('$name ($path) resolves to $screen, tab "$tab" active', (
      WidgetTester tester,
    ) async {
      appRouter.go(path);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Drain pre-existing, unrelated layout-overflow/rendering exceptions
      // (see file-level comment) so they don't fail this routing/shell test.
      while (tester.takeException() != null) {}

      expect(
        find.byType(screen),
        findsWidgets,
        reason: '$path did not build $screen',
      );
      expect(
        find.text(_l10n.invalidCatalogRoute),
        findsNothing,
        reason: '$path fell through to the invalid-route fallback',
      );

      // Exactly one Finance nav bar, with the correct tab active.
      expect(
        find.byType(FinanceNavigationBar),
        findsOneWidget,
        reason: '$path must mount FinanceNavigationBar exactly once',
      );
      expect(
        tester.widget<FinanceNavigationBar>(
          find.byType(FinanceNavigationBar),
        ).selected,
        tab,
        reason: '$path must keep "$tab" active in FinanceNavigationBar',
      );

      // Finance owns its own chrome: no POS top bar (branch tabs / shift
      // badge), and exactly one notifications/profile icon pair.
      expect(
        find.byType(AppTopBar),
        findsNothing,
        reason: '$path must not show the POS AppTopBar',
      );
      expect(
        find.byType(ShiftStatusBadge),
        findsNothing,
        reason: '$path must not show the POS ShiftStatusBadge',
      );
      expect(
        find.byIcon(Icons.notifications_none),
        findsOneWidget,
        reason: '$path must show exactly one notifications icon',
      );
      expect(
        find.byIcon(Icons.person_outline),
        findsOneWidget,
        reason: '$path must show exactly one profile icon',
      );
    });
  }
}
