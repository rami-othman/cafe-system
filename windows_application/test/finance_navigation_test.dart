import 'package:windows_application/shared/widgets/app_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Finance is a first-class RTL sidebar destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 320,
            height: 900,
            child: AppSidebar(
              activeLabel: 'المالية',
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
    );

    expect(find.text('المالية'), findsOneWidget);
    expect(
      find.byIcon(Icons.account_balance_wallet_outlined),
      findsNWidgets(2),
    );
  });
}
