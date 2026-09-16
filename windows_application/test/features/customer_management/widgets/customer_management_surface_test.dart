import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:windows_application/features/customer_management/widgets/customer_management_surface.dart';

void main() {
  testWidgets('renders bordered header, body, and footer slots', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomerManagementSurface(
            header: Text('Filters'),
            body: Text('Rows'),
            footer: Text('Page 1'),
          ),
        ),
      ),
    );

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Rows'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps readable content constrained without changing slots', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomerManagementSurface(
            readable: true,
            body: SizedBox(key: Key('surface-body'), height: 40),
          ),
        ),
      ),
    );

    final BoxConstraints constraints = tester
        .renderObject<RenderBox>(find.byKey(const Key('surface-body')))
        .constraints;
    expect(constraints.maxWidth, lessThanOrEqualTo(720));
  });
}
