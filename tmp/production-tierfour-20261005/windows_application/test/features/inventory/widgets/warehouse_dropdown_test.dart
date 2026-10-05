import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';
import 'package:windows_application/features/inventory/widgets/warehouse_dropdown.dart';
import 'package:windows_application/features/operational_context/controllers/operational_branch_cubit.dart';
import 'package:windows_application/features/operational_context/repositories/operational_branch_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

class _NoopBranchReader implements OperationalBranchReader {
  const _NoopBranchReader();
  @override
  Future<List<Branch>> getActiveBranches() async => const <Branch>[];
}

/// [OperationalBranchCubit.selectBranch] only accepts a branch id already
/// present in `state.branches` (populated by `loadBranches`, which needs a
/// real repository round-trip). Tests here only care about the *effect* of
/// `selectedBranchId` changing, so this fake emits it directly.
class _FakeBranchCubit extends OperationalBranchCubit {
  _FakeBranchCubit(int? selectedBranchId)
    : super(repository: const _NoopBranchReader()) {
    emit(state.copyWith(selectedBranchId: selectedBranchId));
  }

  void setSelectedBranch(int? branchId) =>
      emit(state.copyWith(selectedBranchId: branchId));

  void setFactory() => emit(
    state.copyWith(
      branches: [
        Branch.fromJson({
          'id': 1,
          'name': 'المعمل',
          'branchType': 'factory',
          'defaultWarehouseId': 10,
        }),
      ],
    ),
  );
}

WarehouseLocation _warehouse({
  required int id,
  required int? branchId,
  required String name,
}) => WarehouseLocation(
  id: id,
  branchId: branchId,
  branchName: null,
  name: name,
  displayName: name,
  code: 'W$id',
  type: 'branch',
  typeLabel: 'Warehouse',
  isActive: true,
  isLegacy: false,
);

void main() {
  testWidgets(
    'factory warehouse options exclude shared and foreign warehouses',
    (tester) async {
      final cubit = _FakeBranchCubit(1);
      cubit.setFactory();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OperationalBranchCubit>.value(
            value: cubit,
            child: Scaffold(
              body: WarehouseDropdown(
                value: 10,
                warehouses: [
                  _warehouse(id: 10, branchId: 1, name: 'مخزن المعمل'),
                  _warehouse(id: 20, branchId: null, name: 'المخزن المشترك'),
                  _warehouse(id: 30, branchId: 2, name: 'مخزن فرع آخر'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      expect(find.text('مخزن المعمل'), findsWidgets);
      expect(find.text('المخزن المشترك'), findsNothing);
      expect(find.text('مخزن فرع آخر'), findsNothing);
    },
  );
  group('WarehouseDropdown', () {
    testWidgets(
      'a value not present in the current options is shown as "all", not a crash',
      (WidgetTester tester) async {
        final _FakeBranchCubit branchCubit = _FakeBranchCubit(1);
        addTearDown(branchCubit.close);

        // value: 999 belongs to no warehouse in the list at all - this is the
        // exact shape of bug found in the audit (a stale/foreign id fed
        // straight into a raw DropdownButtonFormField throws Flutter's "there
        // should be exactly one item with this value" assertion).
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<OperationalBranchCubit>.value(
              value: branchCubit,
              child: Scaffold(
                body: WarehouseDropdown(
                  value: 999,
                  warehouses: <WarehouseLocation>[
                    _warehouse(id: 1, branchId: 1, name: 'Bar'),
                    _warehouse(id: 2, branchId: 1, name: 'Kitchen'),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('كل مخازن الفرع'), findsOneWidget);
      },
    );

    testWidgets(
      'two warehouses sharing a name under different branches keep distinct ids',
      (WidgetTester tester) async {
        final _FakeBranchCubit branchCubit = _FakeBranchCubit(1);
        addTearDown(branchCubit.close);

        int? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<OperationalBranchCubit>.value(
              value: branchCubit,
              child: Scaffold(
                body: WarehouseDropdown(
                  value: null,
                  warehouses: <WarehouseLocation>[
                    // Same display name, different branch/id - only the
                    // branch-1 one should be selectable while branch 1 is
                    // active, and it must resolve to id 10, never id 20.
                    _warehouse(id: 10, branchId: 1, name: 'Main Store'),
                    _warehouse(id: 20, branchId: 2, name: 'Main Store'),
                  ],
                  onChanged: (int? value) => selected = value,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DropdownButtonFormField<int?>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Main Store').last);
        await tester.pumpAndSettle();

        expect(selected, 10);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('only the active branch\'s warehouses are offered', (
      WidgetTester tester,
    ) async {
      final _FakeBranchCubit branchCubit = _FakeBranchCubit(1);
      addTearDown(branchCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OperationalBranchCubit>.value(
            value: branchCubit,
            child: Scaffold(
              body: WarehouseDropdown(
                value: null,
                warehouses: <WarehouseLocation>[
                  _warehouse(id: 1, branchId: 1, name: 'Bar'),
                  _warehouse(id: 2, branchId: 2, name: 'Airport Bar'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();

      expect(find.text('Bar'), findsOneWidget);
      expect(find.text('Airport Bar'), findsNothing);
    });
  });

  group('BranchChangeReload', () {
    testWidgets(
      'fires exactly when the active branch id changes, not on unrelated state updates',
      (WidgetTester tester) async {
        final _FakeBranchCubit branchCubit = _FakeBranchCubit(1);
        addTearDown(branchCubit.close);

        int callCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<OperationalBranchCubit>.value(
              value: branchCubit,
              child: BranchChangeReload(
                onBranchChanged: () => callCount++,
                child: const SizedBox(),
              ),
            ),
          ),
        );
        expect(callCount, 0);

        branchCubit.setSelectedBranch(1); // same branch again - must not fire.
        await tester.pump();
        expect(callCount, 0);

        branchCubit.setSelectedBranch(
          2,
        ); // an actual branch change - must fire.
        await tester.pump();
        expect(callCount, 1);
      },
    );
  });
}
