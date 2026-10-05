import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/widgets/customer_group_components.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'group archive requires confirmation and does not optimistically change status',
    (tester) async {
      final _Repository repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomerGroupLifecycleActions(
              repository: repository,
              group: _group,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('customer-group-archive')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Archive'), findsWidgets);
      expect(repository.actions, isEmpty);
    },
  );
}

const CustomerGroup _group = CustomerGroup(
  id: 4,
  name: 'VIP',
  lifecycle: CustomerLifecycle.active,
  memberCount: 2,
);

class _Repository implements CustomerManagementRepository {
  final List<String> actions = <String>[];
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
