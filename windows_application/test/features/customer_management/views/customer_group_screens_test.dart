import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_list_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_detail_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_group_detail_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_group_list_screen.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_scaffold.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('customer management keeps stable customer and group tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CustomerManagementScaffold(
            groupsSelected: true,
            child: Text('groups'),
          ),
        ),
      ),
    );
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Customer Groups'), findsOneWidget);
  });

  testWidgets('group list presents authoritative count metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerGroupListCubit>(
          create: (_) => CustomerGroupListCubit(_Repository()),
          child: Scaffold(
            body: CustomerGroupListScreen(repository: _Repository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 group'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('VIP description'), findsNothing);
  });

  testWidgets('group detail presents identity, date, members, and actions', (
    tester,
  ) async {
    final _Repository repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerGroupDetailCubit>(
          create: (_) => CustomerGroupDetailCubit(repository),
          child: Scaffold(
            body: SizedBox(
              width: 500,
              height: 800,
              child: CustomerGroupDetailScreen(
                groupId: 1,
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-group-identity-surface')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-group-created-at')), findsOneWidget);
    expect(
      find.byKey(const Key('customer-group-members-surface')),
      findsOneWidget,
    );
    expect(find.text('12 members'), findsOneWidget);
    expect(find.byKey(const Key('customer-group-add-members')), findsOneWidget);
    expect(find.text('VIP description'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements CustomerManagementRepository {
  @override
  Future<CustomerPage<CustomerGroup>> listGroups(_) async =>
      const CustomerPage<CustomerGroup>(
        items: <CustomerGroup>[
          CustomerGroup(
            id: 1,
            name: 'VIP',
            lifecycle: CustomerLifecycle.active,
            memberCount: 12,
          ),
        ],
        meta: CustomerPageMeta(
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 1,
        ),
      );

  @override
  Future<CustomerGroup> getGroup(int groupId) async => const CustomerGroup(
    id: 1,
    name: 'VIP',
    lifecycle: CustomerLifecycle.active,
    memberCount: 12,
    createdAt: null,
  );

  @override
  Future<CustomerPage<Customer>> listGroupMembers(int groupId, query) async =>
      const CustomerPage<Customer>(
        items: <Customer>[],
        meta: CustomerPageMeta(
          currentPage: 1,
          lastPage: 1,
          perPage: 25,
          total: 0,
        ),
      );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
