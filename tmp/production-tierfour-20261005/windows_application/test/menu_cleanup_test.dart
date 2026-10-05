import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  testWidgets('sidebar no longer exposes the retired Menu destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppSidebar(activeLabel: 'POS')),
      ),
    );

    expect(find.text('Menu'), findsNothing);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Discounts'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });
}
