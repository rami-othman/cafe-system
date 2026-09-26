import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/sales/models/sales_profitability.dart';
import 'package:windows_application/features/sales/widgets/sales_profit_summary.dart';

void main() {
  testWidgets('shows posted margin and handles undefined percentage', (
    tester,
  ) async {
    final profit = SalesProfitability.fromJson({
      'netRevenue': '30.00',
      'netCogs': '10.00',
      'grossProfit': '20.00',
      'grossMarginPercent': '66.67',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SalesProfitSummary(profit: profit)),
      ),
    );
    expect(find.text('30.00'), findsOneWidget);
    expect(find.text('10.00'), findsOneWidget);
    expect(find.text('20.00'), findsOneWidget);
    expect(find.text('66.67%'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalesProfitSummary(
            profit: SalesProfitability.fromJson({
              'netRevenue': '0.00',
              'netCogs': '0.00',
              'grossProfit': '0.00',
              'grossMarginPercent': null,
            }),
          ),
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('ليس ربحاً صافياً'), findsOneWidget);
  });
}
