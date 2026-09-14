import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/widgets/customer_group_components.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_surface.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'group records switch to cards below 760 without unsupported data',
    (tester) async {
      Future<void> pumpAt(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 500,
                child: CustomerGroupTable(
                  groups: const <CustomerGroup>[_group],
                  onView: (_) {},
                  onEdit: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpAt(760);
      expect(find.byType(CustomerManagementSurface), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('VIP group description'), findsNothing);

      await pumpAt(759);
      expect(find.byType(CustomerManagementSurface), findsOneWidget);
      expect(find.byKey(const Key('customer-group-card-4')), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
    },
  );

  testWidgets('member records retain raw identity and supported actions', (
    tester,
  ) async {
    await tester.pumpWidget(_memberTableHost(const Size(760, 500)));
    await tester.pumpAndSettle();

    expect(find.text('C-000009'), findsOneWidget);
    expect(find.text('+963 11 999'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Customer number'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.byTooltip('View'), findsOneWidget);
    expect(find.byTooltip('Remove member'), findsOneWidget);
    expect(find.text('Last visit'), findsNothing);
  });

  testWidgets('group records show only a server-provided creation date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 760,
            height: 500,
            child: CustomerGroupTable(
              groups: <CustomerGroup>[_datedGroup],
              onView: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Created'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-group-created-at-5')),
      findsOneWidget,
    );
    expect(find.text('VIP group description'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 759,
            height: 500,
            child: CustomerGroupTable(
              groups: <CustomerGroup>[_datedGroup],
              onView: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-group-card-5')), findsOneWidget);
    expect(
      find.byKey(const Key('customer-group-created-at-5')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic group dates keep one isolated day-month-year value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 760,
            height: 500,
            child: CustomerGroupTable(
              groups: <CustomerGroup>[_datedGroup],
              onView: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Text date = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('customer-group-created-at-5')),
        matching: find.byType(Text),
      ),
    );
    expect(date.data, '\u206601/03/2026\u2069');
    expect(date.textDirection, TextDirection.ltr);
  });

  testWidgets('member collection switches to reachable cards below 760', (
    tester,
  ) async {
    await tester.pumpWidget(_memberTableHost(const Size(759, 500)));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNothing);
    expect(
      find.byKey(const Key('customer-group-member-card-9')),
      findsOneWidget,
    );
    expect(find.byTooltip('View'), findsOneWidget);
    expect(find.byTooltip('Remove member'), findsOneWidget);
    expect(find.text('Customer number'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member pagination stays inside the collection surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _memberTableHost(
        const Size(760, 500),
        meta: CustomerPageMeta(
          currentPage: 2,
          lastPage: 3,
          perPage: 25,
          total: 51,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-management-pagination-footer')),
      findsOneWidget,
    );
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.byType(CustomerManagementSurface), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _memberTableHost(Size size, {CustomerPageMeta? meta}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SizedBox(
      width: size.width,
      height: size.height,
      child: CustomerGroupMemberTable(
        members: const <Customer>[_customer],
        meta: meta,
        onView: (_) {},
        onRemove: (_) {},
        onPageChanged: (_) {},
      ),
    ),
  ),
);

const CustomerGroup _group = CustomerGroup(
  id: 4,
  name: 'VIP',
  lifecycle: CustomerLifecycle.active,
  memberCount: 12,
);

final CustomerGroup _datedGroup = CustomerGroup(
  id: 5,
  name: 'Dated VIP',
  lifecycle: CustomerLifecycle.archived,
  memberCount: 3,
  createdAt: DateTime.utc(2026, 3, 1),
);

const Customer _customer = Customer(
  id: 9,
  customerNumber: 'C-000009',
  name: 'Member',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[
    CustomerPhone(
      id: 9,
      rawNumber: '+963 11 999',
      type: 'mobile',
      isPrimary: true,
    ),
  ],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{},
);
