import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_detail_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_list_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_failure.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_group_detail_screen.dart';
import 'package:windows_application/features/customer_management/views/customer_group_list_screen.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_state_panel.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('renders the localized empty action for a group collection', (
    tester,
  ) async {
    await tester.pumpWidget(_groupListHost(_StateMatrixRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No customer groups yet.'), findsOneWidget);
    expect(find.text('New Group'), findsNWidgets(2));
    expect(find.text('New Customer'), findsNothing);
  });

  testWidgets('maps validation failures to the localized validation state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CustomerManagementStatePanel(
          failure: const CustomerFailure(kind: CustomerFailureKind.validation),
          onRetry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review the highlighted fields.'), findsOneWidget);
    expect(find.text('The request could not be completed.'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('forbidden and not-found states do not expose retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CustomerManagementStatePanel(
          failure: CustomerFailure(kind: CustomerFailureKind.forbidden),
          onRetry: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    await tester.pumpWidget(
      _host(
        const CustomerManagementStatePanel(
          failure: CustomerFailure(kind: CustomerFailureKind.notFound),
          onRetry: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Record not found'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('empty and filtered no-results keep distinct actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CustomerManagementStatePanel(
          empty: true,
          onCreate: _noop,
          onCreateLabel: 'New Customer',
        ),
      ),
    );
    expect(find.text('New Customer'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);

    await tester.pumpWidget(
      _host(CustomerManagementStatePanel(noResults: true, onClear: _noop)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear filters'), findsOneWidget);
    expect(find.text('New Customer'), findsNothing);
  });

  testWidgets(
    'offers retry for a failed member refresh without empty fallback',
    (tester) async {
      final _StateMatrixRepository repository = _StateMatrixRepository(
        memberFailureRequests: <int>{1},
      );
      await tester.pumpWidget(_groupDetailHost(repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('The request could not be completed.'), findsOneWidget);
      expect(find.text('No matching results.'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}

void _noop() {}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Widget _groupListHost(_StateMatrixRepository repository) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: BlocProvider<CustomerGroupListCubit>(
      create: (_) => CustomerGroupListCubit(repository),
      child: CustomerGroupListScreen(repository: repository),
    ),
  ),
);

Widget _groupDetailHost(_StateMatrixRepository repository) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<CustomerGroupDetailCubit>(
          create: (_) => CustomerGroupDetailCubit(repository),
        ),
      ],
      child: CustomerGroupDetailScreen(groupId: 4, repository: repository),
    ),
  ),
);

class _StateMatrixRepository implements CustomerManagementRepository {
  _StateMatrixRepository({this.memberFailureRequests = const <int>{}});

  final Set<int> memberFailureRequests;
  int _memberRequest = 0;

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async => const CustomerPage<CustomerGroup>(
    items: <CustomerGroup>[],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 0),
  );

  @override
  Future<CustomerGroup> getGroup(int groupId) async => const CustomerGroup(
    id: 4,
    name: 'VIP',
    lifecycle: CustomerLifecycle.active,
    memberCount: 1,
  );

  @override
  Future<CustomerPage<Customer>> listGroupMembers(
    int groupId,
    CustomerGroupListQuery query,
  ) async {
    final int request = _memberRequest++;
    if (memberFailureRequests.contains(request)) {
      throw StateError('offline');
    }
    return const CustomerPage<Customer>(
      items: <Customer>[],
      meta: CustomerPageMeta(
        currentPage: 1,
        lastPage: 1,
        perPage: 25,
        total: 0,
      ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
