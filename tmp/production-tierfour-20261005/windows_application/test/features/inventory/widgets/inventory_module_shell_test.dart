import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/widgets/inventory_module_shell.dart';
import 'package:windows_application/features/operational_context/controllers/operational_branch_cubit.dart';
import 'package:windows_application/features/operational_context/repositories/operational_branch_repository.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

class _BranchReader implements OperationalBranchReader {
  const _BranchReader();

  @override
  Future<List<Branch>> getActiveBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Main Branch',
      currency: 'USD',
      timezone: 'UTC',
      isActive: true,
      taxRate: 0,
    ),
    Branch(
      id: 2,
      name: 'Airport',
      currency: 'USD',
      timezone: 'UTC',
      isActive: true,
      taxRate: 0,
    ),
  ];
}

class _FakePosCubit extends PosCubit {
  _FakePosCubit() : super(repository: PosRepository());

  void setBranch(int branchId) => emit(state.copyWith(branchId: branchId));
}

void main() {
  testWidgets(
    'inventory shell resolves its branch provider and follows the POS branch',
    (WidgetTester tester) async {
      final _FakePosCubit posCubit = _FakePosCubit();
      final OperationalBranchCubit branchCubit = OperationalBranchCubit(
        repository: const _BranchReader(),
      );
      addTearDown(posCubit.close);
      addTearDown(branchCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<PosCubit>.value(value: posCubit),
            BlocProvider<OperationalBranchCubit>.value(value: branchCubit),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: InventoryModuleShell(
                selectedTab: 'overview',
                child: Text('inventory body'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(branchCubit.state.selectedBranchId, 1);

      posCubit.setBranch(2);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(branchCubit.state.selectedBranchId, 2);
    },
  );
}
