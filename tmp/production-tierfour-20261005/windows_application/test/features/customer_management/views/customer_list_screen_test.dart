import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_list_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_list_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'renders authoritative collection fields and no Phase 4 columns',
    (tester) async {
      final _ListRepository repository = _ListRepository(page: _page);
      await tester.pumpWidget(_host(repository));
      await tester.pump();
      expect(find.text('C-001'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('+963 11 123'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('1 customer'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.text('Last visit'), findsNothing);
      expect(find.text('Order count'), findsNothing);
      expect(find.text('Spend'), findsNothing);
    },
  );

  testWidgets('renders explicit no phone and server pagination', (
    tester,
  ) async {
    final _ListRepository repository = _ListRepository(page: _noPhonePage);
    await tester.pumpWidget(_host(repository));
    await tester.pump();
    expect(find.text('No phone'), findsOneWidget);
    expect(find.text('Page 2 of 3'), findsOneWidget);
  });

  testWidgets('offers both status and real group filters', (tester) async {
    final _ListRepository repository = _ListRepository(page: _page);
    await tester.pumpWidget(_host(repository));
    await tester.pump();
    expect(
      find.byWidgetPredicate((widget) => widget is DropdownButtonFormField),
      findsNWidgets(2),
    );
  });

  testWidgets('uses the narrow record layout at a representative web width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_host(_ListRepository(page: _page)));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
  });

  testWidgets('distinguishes an unfiltered empty collection', (tester) async {
    await tester.pumpWidget(_host(_ListRepository(page: _emptyPage)));
    await tester.pumpAndSettle();

    expect(find.text('No customers yet.'), findsOneWidget);
    expect(find.text('New Customer'), findsNWidgets(2));
    expect(find.text('No matching results.'), findsNothing);
  });

  testWidgets('renders forbidden collection access without an empty fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _ListRepository(
          error: const ApiException(
            message: 'forbidden',
            statusCode: 403,
            type: ApiErrorType.forbidden,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You do not have permission to view this content.'),
      findsOneWidget,
    );
    expect(find.text('No customers yet.'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('retries a failed collection with the same real repository', (
    tester,
  ) async {
    final _ListRepository repository = _ListRepository(
      errors: <Object>[StateError('network')],
      pages: <CustomerPage<Customer>>[_page],
    );
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    expect(find.text('The request could not be completed.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });
}

Widget _host(_ListRepository repository) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<CustomerListCubit>(
    create: (_) => CustomerListCubit(repository),
    child: const Scaffold(body: CustomerListScreen()),
  ),
);

const Customer _customer = Customer(
  id: 1,
  customerNumber: 'C-001',
  name: 'Ada Lovelace',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[
    CustomerPhone(
      id: 1,
      rawNumber: '+963 11 123',
      type: 'mobile',
      isPrimary: true,
    ),
  ],
  groups: <CustomerGroupSummary>[
    CustomerGroupSummary(
      id: 1,
      name: 'VIP',
      lifecycle: CustomerLifecycle.active,
    ),
  ],
  allowedActions: <String>{'update'},
);
const Customer _noPhone = Customer(
  id: 2,
  customerNumber: 'C-002',
  name: 'No Phone',
  lifecycle: CustomerLifecycle.archived,
  phones: <CustomerPhone>[],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{},
);
const CustomerPage<Customer> _page = CustomerPage<Customer>(
  items: <Customer>[_customer],
  meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 1),
);
const CustomerPage<Customer> _noPhonePage = CustomerPage<Customer>(
  items: <Customer>[_noPhone],
  meta: CustomerPageMeta(currentPage: 2, lastPage: 3, perPage: 25, total: 51),
);
const CustomerPage<Customer> _emptyPage = CustomerPage<Customer>(
  items: <Customer>[],
  meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 25, total: 0),
);

class _ListRepository implements CustomerManagementRepository {
  _ListRepository({
    this.page,
    this.error,
    this.errors = const <Object>[],
    this.pages = const <CustomerPage<Customer>>[],
  });
  final CustomerPage<Customer>? page;
  final Object? error;
  final List<Object> errors;
  final List<CustomerPage<Customer>> pages;
  int _request = 0;

  @override
  Future<CustomerPage<Customer>> listCustomers(_) async {
    if (_request < errors.length) throw errors[_request++];
    if (pages.isNotEmpty) return pages[_request++ - errors.length];
    if (error != null) throw error!;
    return page!;
  }

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(_) async =>
      const CustomerPage<CustomerGroup>(
        items: <CustomerGroup>[
          CustomerGroup(
            id: 9,
            name: 'Authoritative group',
            lifecycle: CustomerLifecycle.active,
            memberCount: 0,
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
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
