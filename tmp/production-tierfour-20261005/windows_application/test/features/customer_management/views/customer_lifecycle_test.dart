import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/widgets/customer_lifecycle_actions.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'shows a localized named consequence dialog and disables conflicting actions during progress',
    (tester) async {
      final _WidgetLifecycleRepository repository = _WidgetLifecycleRepository(
        defer: true,
      );
      await tester.pumpWidget(
        _app(repository, _customer(CustomerLifecycle.active)),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('customer-lifecycle-deactivate')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('customer-lifecycle-activate')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('customer-lifecycle-deactivate')));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate Ada Lovelace?'), findsOneWidget);
      expect(
        find.textContaining('no longer be available for new operational use'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('customer-lifecycle-confirm')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('customer-lifecycle-deactivate')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.actions, <String>['deactivate']);
      repository.complete(_customer(CustomerLifecycle.inactive));
      await tester.pumpAndSettle();
      expect(find.text('Inactive'), findsNWidgets(2));
    },
  );

  testWidgets(
    'restoring an archived customer leaves it Inactive and keeps Activate explicit',
    (tester) async {
      final _WidgetLifecycleRepository repository = _WidgetLifecycleRepository(
        response: _customer(CustomerLifecycle.inactive),
      );
      await tester.pumpWidget(
        _app(repository, _customer(CustomerLifecycle.archived)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('customer-lifecycle-restore')));
      await tester.pumpAndSettle();
      expect(find.text('Restore Ada Lovelace?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('customer-lifecycle-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Inactive'), findsNWidgets(2));
      expect(
        find.byKey(const Key('customer-lifecycle-activate')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('customer-lifecycle-restore')), findsNothing);
    },
  );

  testWidgets(
    'announces a retry-safe localized failure and restores focus to the failed action',
    (tester) async {
      final _WidgetLifecycleRepository repository = _WidgetLifecycleRepository(
        error: StateError('offline'),
      );
      await tester.pumpWidget(
        _app(repository, _customer(CustomerLifecycle.active)),
      );
      await tester.pump();
      final Finder action = find.byKey(
        const Key('customer-lifecycle-deactivate'),
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('customer-lifecycle-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('The request could not be completed.'), findsOneWidget);
      expect(
        find.textContaining('Your customer was not changed'),
        findsOneWidget,
      );
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        contains('customer-lifecycle-deactivate'),
      );
    },
  );
}

Widget _app(_WidgetLifecycleRepository repository, Customer customer) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomerLifecycleActions(
          repository: repository,
          customer: customer,
        ),
      ),
    );

class _WidgetLifecycleRepository implements CustomerManagementRepository {
  _WidgetLifecycleRepository({this.response, this.error, this.defer = false});
  final Customer? response;
  final Object? error;
  final bool defer;
  final List<String> actions = <String>[];
  final Completer<Customer> _pending = Completer<Customer>();

  @override
  Future<Customer> changeCustomerLifecycle(int customerId, String action) {
    actions.add(action);
    if (error != null) return Future<Customer>.error(error!);
    if (defer) return _pending.future;
    return Future<Customer>.value(
      response ?? _customer(CustomerLifecycle.inactive),
    );
  }

  void complete(Customer customer) => _pending.complete(customer);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Customer _customer(CustomerLifecycle lifecycle) => Customer(
  id: 7,
  customerNumber: 'C-000007',
  name: 'Ada Lovelace',
  lifecycle: lifecycle,
  phones: const <CustomerPhone>[],
  groups: const <CustomerGroupSummary>[],
  allowedActions: const <String>{
    'activate',
    'deactivate',
    'archive',
    'restore',
  },
);
