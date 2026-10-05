import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/widgets/customer_pagination.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('renders an integrated metadata footer with correct states', (
    tester,
  ) async {
    int? requestedPage;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomerPagination(
            meta: const CustomerPageMeta(
              currentPage: 2,
              lastPage: 3,
              perPage: 25,
              total: 51,
            ),
            onPageChanged: (int page) => requestedPage = page,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('customer-management-pagination-footer')),
      findsOneWidget,
    );
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(requestedPage, 3);
  });

  testWidgets('uses direction-aware icons in RTL and respects boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CustomerPagination(
              meta: const CustomerPageMeta(
                currentPage: 1,
                lastPage: 2,
                perPage: 25,
                total: 26,
              ),
              onPageChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CustomerPagination)),
    );
    final Finder previous = find
        .ancestor(
          of: find.byTooltip(l10n.customerManagementPreviousPage),
          matching: find.byType(IconButton),
        )
        .first;
    final Finder next = find
        .ancestor(
          of: find.byTooltip(l10n.customerManagementNextPage),
          matching: find.byType(IconButton),
        )
        .first;
    final Icon previousIcon = tester.widget<Icon>(
      find.descendant(of: previous, matching: find.byType(Icon)),
    );
    final Icon nextIcon = tester.widget<Icon>(
      find.descendant(of: next, matching: find.byType(Icon)),
    );

    expect(previousIcon.icon, Icons.chevron_left);
    expect(nextIcon.icon, Icons.chevron_right);
    expect(tester.widget<IconButton>(previous).onPressed, isNull);
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);
  });
}
