import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_form_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_drafts.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/models/customer_queries.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_form_screen.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_surface.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'create form supports zero phones and does not display a customer number',
    (tester) async {
      await tester.pumpWidget(_host(_FormRepository()));
      await tester.pumpAndSettle();

      expect(find.text('New Customer'), findsOneWidget);
      expect(find.byKey(const Key('customer-number')), findsNothing);
      expect(find.byKey(const Key('customer-phone-row')), findsNothing);
      expect(find.byKey(const Key('customer-form-save')), findsOneWidget);
      expect(find.byType(CustomerManagementSurface), findsOneWidget);
      expect(find.byKey(const Key('customer-form-surface')), findsOneWidget);
      expect(find.text('Customer information'), findsOneWidget);
      expect(find.text('Phone numbers'), findsOneWidget);
      expect(find.text('Customer groups'), findsOneWidget);
      expect(find.text('Notes'), findsWidgets);
    },
  );

  testWidgets(
    'edit form loads direct identity, keeps customer number read-only, and shows archived group',
    (tester) async {
      await tester.pumpWidget(_host(_FormRepository(), customerId: 7));
      await tester.pumpAndSettle();

      expect(find.text('Edit Customer'), findsOneWidget);
      expect(find.text('C-000007'), findsOneWidget);
      expect(find.byKey(const Key('customer-number')), findsOneWidget);
      expect(find.byKey(const Key('customer-number-field')), findsNothing);
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Archived group retained'), findsOneWidget);
    },
  );

  testWidgets(
    'phone controls preserve raw text and expose primary/type changes',
    (tester) async {
      await tester.pumpWidget(_host(_FormRepository()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-name-field')),
        'Ada',
      );
      await tester.ensureVisible(find.byKey(const Key('customer-add-phone')));
      await tester.tap(find.byKey(const Key('customer-add-phone')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('customer-phone-0-raw')),
        '+963 (999) 1',
      );

      expect(find.byKey(const Key('customer-phone-0-primary')), findsOneWidget);
      expect(find.byKey(const Key('customer-phone-0-type')), findsOneWidget);
      expect(find.text('+963 (999) 1'), findsOneWidget);
    },
  );

  testWidgets(
    'local validation and backend errors remain visible without losing input',
    (tester) async {
      final _FormRepository repository = _FormRepository(
        submitError: const ApiException(
          message: 'validation',
          statusCode: 422,
          type: ApiErrorType.validation,
          validationErrors: <String, List<String>>{
            'name': <String>['Name is invalid'],
          },
        ),
      );
      await tester.pumpWidget(_host(repository));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-name-field')),
        'Ada',
      );
      await tester.tap(find.byKey(const Key('customer-form-save')));
      await tester.pumpAndSettle();

      expect(find.text('Review the highlighted fields.'), findsNWidgets(2));
      expect(find.text('Ada'), findsOneWidget);
    },
  );

  testWidgets('forbidden edit state is distinct from loading and not-found', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FormRepository(
          loadError: const ApiException(
            message: 'forbidden',
            statusCode: 403,
            type: ApiErrorType.forbidden,
          ),
        ),
        customerId: 7,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You do not have permission to view this content.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-form-save')), findsNothing);
  });

  testWidgets(
    'successful create navigates to the returned customer detail route',
    (tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/customers/new',
        routes: <RouteBase>[
          GoRoute(
            path: '/customers/new',
            builder: (context, state) => BlocProvider<CustomerFormCubit>(
              create: (_) => CustomerFormCubit(_FormRepository()),
              child: const Scaffold(body: CustomerFormScreen()),
            ),
          ),
          GoRoute(
            path: '/customers/:id',
            builder: (context, state) =>
                Text('Saved detail ${state.pathParameters['id']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-name-field')),
        'Ada',
      );
      await tester.tap(find.byKey(const Key('customer-form-save')));
      await tester.pumpAndSettle();

      expect(find.text('Saved detail 22'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps primary form actions reachable at a narrow keyboard width',
    (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_host(_FormRepository()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customer-name-field')),
        'Ada',
      );

      expect(find.byKey(const Key('customer-form-cancel')), findsOneWidget);
      expect(find.byKey(const Key('customer-form-save')), findsOneWidget);
    },
  );
}

Widget _host(_FormRepository repository, {int? customerId}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<CustomerFormCubit>(
    create: (_) => CustomerFormCubit(repository),
    child: Scaffold(body: CustomerFormScreen(customerId: customerId)),
  ),
);

class _FormRepository implements CustomerManagementRepository {
  _FormRepository({this.loadError, this.submitError});
  final Object? loadError;
  final Object? submitError;

  @override
  Future<Customer> getCustomer(int id) async {
    if (loadError != null) throw loadError!;
    return _customer;
  }

  @override
  Future<CustomerPage<CustomerGroup>> listGroups(
    CustomerGroupListQuery query,
  ) async => const CustomerPage<CustomerGroup>(
    items: <CustomerGroup>[_activeGroup],
    meta: CustomerPageMeta(currentPage: 1, lastPage: 1, perPage: 100, total: 1),
  );

  @override
  Future<Customer> createCustomer(CustomerDraft draft) async {
    if (submitError != null) throw submitError!;
    return _created;
  }

  @override
  Future<Customer> updateCustomer(int id, CustomerDraft draft) async {
    if (submitError != null) throw submitError!;
    return _created;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const CustomerGroup _activeGroup = CustomerGroup(
  id: 3,
  name: 'VIP',
  lifecycle: CustomerLifecycle.active,
  memberCount: 1,
);

const Customer _customer = Customer(
  id: 7,
  customerNumber: 'C-000007',
  name: 'Ada',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[
    CustomerPhone(id: 1, rawNumber: '+1', type: 'mobile', isPrimary: true),
  ],
  groups: <CustomerGroupSummary>[
    CustomerGroupSummary(
      id: 9,
      name: 'Archived',
      lifecycle: CustomerLifecycle.archived,
    ),
  ],
  allowedActions: <String>{'update'},
);

const Customer _created = Customer(
  id: 22,
  customerNumber: 'C-000022',
  name: 'Ada',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{'update'},
);
