import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/finance_inventory_setup/widgets/finance_paginated_table.dart';

void main() {
  testWidgets('shows ten Finance table rows and moves to the next page', (
    WidgetTester tester,
  ) async {
    final List<DataRow> rows = List<DataRow>.generate(
      11,
      (int index) =>
          DataRow(cells: <DataCell>[DataCell(Text('row-${index + 1}'))]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancePaginatedTable(
            minWidth: 320,
            columns: const <DataColumn>[DataColumn(label: Text('Row'))],
            rows: rows,
          ),
        ),
      ),
    );

    expect(find.text('row-10'), findsOneWidget);
    expect(find.text('row-11'), findsNothing);

    final Finder nextPage = find.byIcon(Icons.chevron_left);
    await tester.ensureVisible(nextPage);
    await tester.tap(nextPage);
    await tester.pump();

    expect(find.text('row-10'), findsNothing);
    expect(find.text('row-11'), findsOneWidget);
  });
}
