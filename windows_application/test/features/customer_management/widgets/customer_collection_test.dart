import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/widgets/customer_collection.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_surface.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('table actions do not overflow a constrained action cell', (
    tester,
  ) async {
    final List<FlutterErrorDetails> layoutErrors = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        layoutErrors.add(details);
      }
    };
    addTearDown(() => FlutterError.onError = previousHandler);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 760,
            child: CustomerCollection(
              customers: <Customer>[_customer],
              onSelected: (_) {},
              onEdit: (_) {},
              lifecycleRepository: _LifecycleRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = previousHandler;
    expect(layoutErrors, isEmpty);
  });

  testWidgets('switches from table to cards at the exact 760 breakpoint', (
    tester,
  ) async {
    Future<void> pumpAt(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 500,
              child: CustomerCollection(
                customers: const <Customer>[_customer],
                onSelected: (_) {},
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

    await pumpAt(759);
    expect(find.byType(CustomerManagementSurface), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('keeps long bilingual values reachable through semantics', (
    tester,
  ) async {
    const Customer customer = Customer(
      id: 8,
      customerNumber: 'C-000008',
      name: 'عميل طويل للغاية للاختبار',
      lifecycle: CustomerLifecycle.active,
      phones: <CustomerPhone>[
        CustomerPhone(
          id: 8,
          rawNumber: '+963-11-000-0000-EXT-888',
          type: 'mobile',
          isPrimary: true,
        ),
      ],
      groups: <CustomerGroupSummary>[],
      allowedActions: <String>{},
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: CustomerCollection(
                customers: const <Customer>[customer],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(customer.name), findsOneWidget);
    expect(find.text('+963-11-000-0000-EXT-888'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const Customer _customer = Customer(
  id: 1,
  customerNumber: 'C-000001',
  name: 'Ada Lovelace',
  lifecycle: CustomerLifecycle.active,
  phones: <CustomerPhone>[],
  groups: <CustomerGroupSummary>[],
  allowedActions: <String>{'update', 'deactivate', 'archive'},
);

class _LifecycleRepository implements CustomerManagementRepository {
  @override
  Future<Customer> changeCustomerLifecycle(int customerId, String action) =>
      Future<Customer>.value(_customer);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
