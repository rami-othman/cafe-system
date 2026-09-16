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

  testWidgets('mirrors pagination icons in RTL and disables boundary actions', (
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
                lastPage: 1,
                perPage: 25,
                total: 0,
              ),
              onPageChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
  });
}
