import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/customer_management/controllers/customer_detail_cubit.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_detail_screen.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_surface.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('renders only authoritative read-only profile fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerDetailCubit>(
          create: (_) => CustomerDetailCubit(_DetailRepository()),
          child: const Scaffold(body: CustomerDetailScreen(customerId: 7)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('C-007'), findsWidgets);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('ada@example.test'), findsOneWidget);
    expect(find.text('Archived Group'), findsOneWidget);
    expect(find.byType(CustomerManagementSurface), findsNWidgets(4));
    expect(
      find.byKey(const Key('customer-detail-information')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('customer-detail-raw-number')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-phones')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-groups')), findsOneWidget);
    expect(find.byKey(const Key('customer-detail-notes')), findsOneWidget);
    expect(find.text('No metrics'), findsNothing);
    expect(find.text('Recent orders'), findsNothing);
    expect(find.text('Orders'), findsNothing);
  });

  testWidgets('renders localized absence values for an incomplete profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerDetailCubit>(
          create: (_) =>
              CustomerDetailCubit(_DetailRepository(incomplete: true)),
          child: const Scaffold(body: CustomerDetailScreen(customerId: 8)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No phone'), findsOneWidget);
    expect(find.text('Not available'), findsNWidgets(4));
  });

  testWidgets('renders a forbidden detail state without retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<CustomerDetailCubit>(
          create: (_) => CustomerDetailCubit(
            _DetailRepository(
              error: const ApiException(
                message: 'forbidden',
                statusCode: 403,
                type: ApiErrorType.forbidden,
              ),
            ),
          ),
          child: const Scaffold(body: CustomerDetailScreen(customerId: 9)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You do not have permission to view this content.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });
}

class _DetailRepository implements CustomerManagementRepository {
  _DetailRepository({this.incomplete = false, this.error});
  final bool incomplete;
  final Object? error;

  @override
  Future<Customer> getCustomer(int id) async {
    if (error != null) throw error!;
    if (incomplete) {
      return Customer(
        id: id,
        customerNumber: 'C-$id',
        name: 'Incomplete',
        lifecycle: CustomerLifecycle.active,
        phones: const <CustomerPhone>[],
        groups: const <CustomerGroupSummary>[],
        allowedActions: const <String>{},
      );
    }
    return const Customer(
      id: 7,
      customerNumber: 'C-007',
      name: 'Ada',
      lifecycle: CustomerLifecycle.archived,
      email: 'ada@example.test',
      birthDate: null,
      notes: 'Note',
      phones: <CustomerPhone>[
        CustomerPhone(id: 1, rawNumber: '+1', type: 'work', isPrimary: true),
        CustomerPhone(id: 2, rawNumber: '+2', type: 'home', isPrimary: false),
      ],
      groups: <CustomerGroupSummary>[
        CustomerGroupSummary(
          id: 1,
          name: 'Archived Group',
          lifecycle: CustomerLifecycle.archived,
        ),
      ],
      allowedActions: <String>{},
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
