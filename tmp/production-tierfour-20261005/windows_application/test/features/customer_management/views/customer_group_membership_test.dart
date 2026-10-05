import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_membership_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/widgets/customer_group_components.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('candidate selection is represented by accessible checkboxes', (
    tester,
  ) async {
    final _Repository repository = _Repository();
    final CustomerGroupMembershipCubit cubit = CustomerGroupMembershipCubit(
      repository,
      groupId: 4,
    );
    await cubit.loadCandidates();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomerGroupCandidateDialog(cubit: cubit, onDone: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.byKey(const Key('customer-group-add-confirm')), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(cubit.state.selectedCustomerIds, <int>{9});
    expect(find.text('Add 1 member'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-group-candidate-search')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await cubit.close();
  });
}

class _Repository implements CustomerManagementRepository {
  @override
  Future<CustomerPage<Customer>> listEligibleMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) async => const CustomerPage<Customer>(
    items: <Customer>[
      Customer(
        id: 9,
        customerNumber: 'C-000009',
        name: 'Candidate',
        lifecycle: CustomerLifecycle.active,
        phones: <CustomerPhone>[],
        groups: <CustomerGroupSummary>[],
        allowedActions: <String>{},
      ),
    ],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 1),
  );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
