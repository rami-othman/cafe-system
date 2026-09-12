import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/widgets/customer_group_components.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('keeps a long group name available through tooltip semantics', (
    tester,
  ) async {
    const String longName =
        'Arabic and English group name that must remain discoverable';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 420,
          child: CustomerGroupTable(
            groups: <CustomerGroup>[
              const CustomerGroup(
                id: 4,
                name: longName,
                lifecycle: CustomerLifecycle.active,
                memberCount: 2,
              ),
            ],
            onView: (_) {},
            onEdit: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(longName), findsOneWidget);
    expect(find.bySemanticsLabel(longName), findsOneWidget);
  });

  testWidgets('keeps group record actions reachable at narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 420,
          child: CustomerGroupTable(
            groups: <CustomerGroup>[
              const CustomerGroup(
                id: 4,
                name: 'VIP',
                lifecycle: CustomerLifecycle.active,
                memberCount: 2,
              ),
            ],
            onView: (_) {},
            onEdit: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('View'));
    expect(find.byTooltip('View'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps mixed-direction group values usable in Arabic RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 420,
            child: CustomerGroupTable(
              groups: const <CustomerGroup>[
                CustomerGroup(
                  id: 4,
                  name: 'مجموعة VIP',
                  lifecycle: CustomerLifecycle.active,
                  memberCount: 2,
                ),
              ],
              onView: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مجموعة VIP'), findsOneWidget);
    expect(find.byTooltip('عرض'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
