import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:windows_application/features/customer_management/widgets/customer_management_page_header.dart';

void main() {
  Widget harness({required double width}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Scaffold(
        body: CustomerManagementPageHeader(
          title: 'Customers',
          description: 'Manage customer records.',
          breadcrumbs: const <String>['Customers', 'Details'],
          primaryAction: FilledButton(
            onPressed: () {},
            child: const Text('Create'),
          ),
          secondaryAction: OutlinedButton(
            onPressed: () {},
            child: const Text('Cancel'),
          ),
        ),
      ),
    ),
  );

  testWidgets('renders hierarchy and actions with semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(width: 1000));
    expect(
      find.byKey(const ValueKey<String>('customer-management-page-title')),
      findsOneWidget,
    );
    expect(find.text('Manage customer records.'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('stacks primary and secondary actions on a narrow width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(width: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
