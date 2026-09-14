import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';
import 'package:windows_application/features/inventory/views/widgets/inventory_item_widgets.dart';
import 'package:windows_application/features/operational_context/controllers/operational_branch_cubit.dart';
import 'package:windows_application/features/operational_context/repositories/operational_branch_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

class _FakeOperationalBranchCubit extends OperationalBranchCubit {
  _FakeOperationalBranchCubit(int? selectedBranchId)
    : super(repository: const _NoopBranchReader()) {
    emit(state.copyWith(selectedBranchId: selectedBranchId));
  }
}

class _NoopBranchReader implements OperationalBranchReader {
  const _NoopBranchReader();
  @override
  Future<List<Branch>> getActiveBranches() async => const <Branch>[];
}

void main() {
  testWidgets('renders item filters and server-status badges in RTL', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final TextEditingController search = TextEditingController();
    addTearDown(search.dispose);
    final _FakeOperationalBranchCubit branchCubit = _FakeOperationalBranchCubit(
      1,
    );
    addTearDown(branchCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<OperationalBranchCubit>.value(
          value: branchCubit,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                children: <Widget>[
                  ItemFilters(
                    searchController: search,
                    category: '',
                    type: 'packaging',
                    stockStatus: 'low_stock',
                    warehouseId: null,
                    categories: const <String>['Dairy'],
                    warehouses: const <WarehouseLocation>[
                      WarehouseLocation(
                        id: 1,
                        branchId: 1,
                        name: 'main',
                        displayName: 'المخزن الرئيسي',
                        code: 'MAIN',
                        type: 'main_store',
                        typeLabel: 'مخزن رئيسي',
                        isActive: true,
                        isLegacy: false,
                      ),
                    ],
                    onSearch: (_) {},
                    onCategoryChanged: (_) {},
                    onTypeChanged: (_) {},
                    onStatusChanged: (_) {},
                    onWarehouseChanged: (_) {},
                    onClear: () {},
                  ),
                  const ItemStatusBadge(status: 'out_of_stock'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ابحث بالاسم أو SKU أو الباركود'), findsOneWidget);
    expect(find.text('حالة المخزون'), findsOneWidget);
    expect(find.text('نافد المخزون'), findsOneWidget);
    expect(find.text('المخزن الرئيسي'), findsNothing);
  });

  test('parses item-management fields supplied by the server', () {
    final InventoryItem item = InventoryItem.fromJson(<String, dynamic>{
      'id': 7,
      'displayName': 'Milk',
      'sku': 'MILK-1',
      'unit': 'liter',
      'purchaseUnit': 'box',
      'consumptionUnit': 'liter',
      'itemType': 'stock_item',
      'category': 'Dairy',
      'totalQuantity': '24.000',
      'availableQuantity': '24.000',
      'latestUnitCost': '2.0000',
      'lastPurchaseCost': '2.2500',
      'stockStatus': 'active',
      'lastUpdatedAt': '2026-08-24T10:00:00Z',
      'trackExpiry': true,
      'trackBatch': true,
      'warehouseIds': <int>[1, 2],
      'isActive': true,
    });
    expect(item.purchaseUnit, 'box');
    expect(item.warehouseIds, <int>[1, 2]);
    expect(item.stockStatus, 'active');
  });
}
