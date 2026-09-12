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
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
    },
  );

  testWidgets('member records retain raw identity and supported actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomerGroupMemberTable(
            members: const <Customer>[_customer],
            onView: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('C-000009'), findsOneWidget);
    expect(find.text('+963 11 999'), findsOneWidget);
    expect(find.byTooltip('View'), findsOneWidget);
    expect(find.byTooltip('Remove member'), findsOneWidget);
    expect(find.text('Last visit'), findsNothing);
  });
}

const CustomerGroup _group = CustomerGroup(
  id: 4,
  name: 'VIP',
  lifecycle: CustomerLifecycle.active,
  memberCount: 12,
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
