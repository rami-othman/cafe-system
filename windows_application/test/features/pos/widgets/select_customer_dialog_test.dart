import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/models/customer.dart';
import 'package:windows_application/features/pos/widgets/select_customer_dialog.dart';

void main() {
  testWidgets('customer dialog footer labels stay on one line', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(529, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectCustomerDialog(
            customers: _customers,
            selectedCustomer: _customers[0],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_textHeight(tester, _footerTextFinder('Cancel')), lessThan(24));
    expect(
      _textHeight(tester, _footerTextFinder('Select Customer')),
      lessThan(24),
    );
  });

  testWidgets('select is disabled when the selected customer is filtered out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectCustomerDialog(
            customers: _customers,
            selectedCustomer: _customers[0],
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('customer-search')),
      'Janet',
    );
    await tester.pump();

    final FilledButton selectButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('confirm-customer-selection')),
    );

    expect(find.text('Janet Smith'), findsOneWidget);
    expect(find.text('Jane Doe'), findsNothing);
    expect(selectButton.onPressed, isNull);
  });

  testWidgets('search failures remain distinct and preserve the old results', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectCustomerDialog(
            customers: _customers,
            selectedCustomer: _customers[0],
            onSearch: (String query) async {
              throw const ApiException(
                message: 'server detail must stay hidden',
                type: ApiErrorType.server,
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('customer-search')),
      'Alice',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(
      find.text('Customer search is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(find.text('server detail must stay hidden'), findsNothing);
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('stale search responses cannot replace a newer result', (
    WidgetTester tester,
  ) async {
    final Completer<List<Customer>> first = Completer<List<Customer>>();
    final Completer<List<Customer>> second = Completer<List<Customer>>();
    Future<List<Customer>> search(String query) {
      return query == 'first' ? first.future : second.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectCustomerDialog(
            customers: _customers,
            selectedCustomer: _customers[0],
            onSearch: search,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('customer-search')),
      'first',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(const ValueKey<String>('customer-search')),
      'second',
    );
    await tester.pump(const Duration(milliseconds: 400));

    second.complete(<Customer>[_customers[1]]);
    await tester.pump();
    first.complete(<Customer>[_customers[2]]);
    await tester.pump();

    expect(find.text('Janet Smith'), findsOneWidget);
    expect(find.text('Jane Williams'), findsNothing);
  });
}

Finder _footerTextFinder(String text) {
  final Finder buttonFinder = switch (text) {
    'Cancel' => find.byType(OutlinedButton),
    'Select Customer' => find.byKey(
      const ValueKey<String>('confirm-customer-selection'),
    ),
    _ => find.byType(ButtonStyleButton),
  };

  return find.descendant(of: buttonFinder, matching: find.text(text));
}

double _textHeight(WidgetTester tester, Finder finder) {
  return tester.getSize(finder).height;
}

const List<Customer> _customers = <Customer>[
  Customer(
    id: 'customer-1',
    name: 'Jane Doe',
    phone: '+1 (555) 019-8234',
    tier: 'VIP',
    points: 1450,
  ),
  Customer(
    id: 'customer-2',
    name: 'Janet Smith',
    phone: '+1 (555) 342-9901',
    tier: 'REGULAR',
    points: 320,
  ),
  Customer(
    id: 'customer-3',
    name: 'Jane Williams',
    phone: '+1 (555) 781-2245',
    tier: 'NEW',
    points: 50,
  ),
];
