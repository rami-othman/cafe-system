import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
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

  testWidgets('keeps every desktop group action keyboard reachable', (
    tester,
  ) async {
    int viewCount = 0;
    int editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 760,
          child: CustomerGroupTable(
            groups: <CustomerGroup>[
              const CustomerGroup(
                id: 4,
                name: 'VIP',
                lifecycle: CustomerLifecycle.active,
                memberCount: 2,
              ),
            ],
            repository: _Repository(),
            onView: (_) => viewCount++,
            onEdit: (_) => editCount++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CustomerGroupTable)),
    );
    final Finder trigger = find.byTooltip(l10n.cmvpOpenActions);
    expect(trigger, findsOneWidget);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n.customerManagementView),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.bySemanticsLabel(l10n.customerManagementEdit),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.bySemanticsLabel(l10n.customerManagementArchive),
      findsAtLeastNWidgets(1),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(viewCount, 1);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(editCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps supported group card actions reachable at narrow width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          width: 420,
          height: 800,
          child: CustomerGroupTable(
            groups: const <CustomerGroup>[
              CustomerGroup(
                id: 4,
                name: 'VIP',
                lifecycle: CustomerLifecycle.active,
                memberCount: 2,
              ),
            ],
            repository: _Repository(),
            onView: _ignoreGroup,
            onEdit: _ignoreGroup,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CustomerGroupTable)),
    );
    expect(find.byTooltip(l10n.customerManagementView), findsOneWidget);
    expect(find.byTooltip(l10n.customerManagementEdit), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.cmvpOpenActions));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n.customerManagementArchive),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps RTL overflow actions semantic and restores focus', (
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
            width: 760,
            child: CustomerGroupTable(
              groups: const <CustomerGroup>[
                CustomerGroup(
                  id: 4,
                  name: 'مجموعة VIP',
                  lifecycle: CustomerLifecycle.active,
                  memberCount: 2,
                ),
              ],
              repository: _Repository(),
              onView: _ignoreGroup,
              onEdit: _ignoreGroup,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CustomerGroupTable)),
    );
    final Finder trigger = find.byTooltip(l10n.cmvpOpenActions);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n.customerManagementView),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.bySemanticsLabel(l10n.customerManagementEdit),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.bySemanticsLabel(l10n.customerManagementArchive),
      findsAtLeastNWidgets(1),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.binding.focusManager.primaryFocus?.context, isNotNull);

    expect(find.text('مجموعة VIP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _ignoreGroup(CustomerGroup _) {}

class _Repository implements CustomerManagementRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
