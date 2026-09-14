import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_module_tabs.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_scaffold.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('owns the module background, tabs, and child identity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CustomerManagementScaffold(
            groupsSelected: true,
            child: Text('route-child'),
          ),
        ),
      ),
    );

    expect(find.byType(CustomerManagementModuleTabs), findsOneWidget);
    expect(find.text('route-child'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not recreate the supplied route child when resized', (
    WidgetTester tester,
  ) async {
    final Key childKey = UniqueKey();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomerManagementScaffold(
            groupsSelected: false,
            child: SizedBox(key: childKey),
          ),
        ),
      ),
    );
    expect(find.byKey(childKey), findsOneWidget);
    tester.view.physicalSize = const Size(500, 800);
    await tester.pump();
    expect(find.byKey(childKey), findsOneWidget);
    tester.view.resetPhysicalSize();
  });

  testWidgets(
    'keeps the same route child across narrow RTL locale and direction changes',
    (WidgetTester tester) async {
      final Key childKey = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomerManagementScaffold(
              groupsSelected: false,
              child: SizedBox(key: childKey),
            ),
          ),
        ),
      );
      expect(find.byKey(childKey), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('customer-management-scaffold-content'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: CustomerManagementScaffold(
                groupsSelected: true,
                child: SizedBox(key: childKey),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(childKey), findsOneWidget);
      expect(find.text('مجموعات العملاء'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
