import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/pos/widgets/pos_cart_panel.dart';

void main() {
  testWidgets('table selector displays loaded tables and clears for takeaway', (
    WidgetTester tester,
  ) async {
    final PosCubit cubit = PosCubit(repository: PosRepository());
    addTearDown(cubit.close);
    await cubit.loadInitialData();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PosCubit>.value(
            value: cubit,
            child: const PosCartPanel(),
          ),
        ),
      ),
    );

    expect(find.text('Select table'), findsOneWidget);
    expect(find.text('12'), findsNothing);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('Table 12 (12)'), findsOneWidget);

    await tester.tap(find.text('Table 12 (12)'));
    await tester.pumpAndSettle();
    expect(cubit.state.selectedTable?.id, 1);

    await tester.tap(find.text('TAKEAWAY'));
    await tester.pumpAndSettle();
    expect(cubit.state.selectedTable, isNull);
    expect(find.text('Select table'), findsNothing);
  });
}
