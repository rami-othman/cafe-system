import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';

void main() {
  test('canonical backend transfer statuses map to Arabic presentation labels', () {
    expect(TransferStatus.fromValue('submitted'), TransferStatus.submitted);
    expect(TransferStatus.fromValue('partially_received').arabicLabel, 'مستلم جزئياً / قيد النقل');
    expect(TransferStatus.fromValue('closed_shortage').isTerminal, isTrue);
  });

  test('transfer page parses pagination, KPI metadata, and typed status', () {
    final page = WarehouseTransfersPage.fromJson(<String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 8,
          'number': 'TR-0008',
          'sourceWarehouseId': 1,
          'sourceWarehouseName': 'المستودع الرئيسي',
          'destinationWarehouseId': 2,
          'destinationWarehouseName': 'البار',
          'status': 'dispatched',
        },
      ],
      'meta': <String, dynamic>{'currentPage': 2, 'lastPage': 3, 'total': 51, 'perPage': 25, 'kpis': <String, dynamic>{'inTransit': 4}},
    });
    expect(page.meta.currentPage, 2);
    expect(page.meta.kpis['inTransit'], 4);
    expect(page.items.single.statusType, TransferStatus.dispatched);
  });

  test('transfer parses source/destination branch id and name, nullable for a central warehouse', () {
    final branchToBranch = WarehouseTransfer.fromJson(<String, dynamic>{
      'id': 9,
      'number': 'TR-0009',
      'sourceWarehouseId': 1,
      'sourceWarehouseName': 'Downtown — Main Store',
      'sourceBranchId': 11,
      'sourceBranchName': 'Downtown',
      'destinationWarehouseId': 2,
      'destinationWarehouseName': 'Mall — Bar',
      'destinationBranchId': 12,
      'destinationBranchName': 'Mall',
      'status': 'draft',
    });
    expect(branchToBranch.sourceBranchId, 11);
    expect(branchToBranch.sourceBranchName, 'Downtown');
    expect(branchToBranch.destinationBranchId, 12);
    expect(branchToBranch.destinationBranchName, 'Mall');

    final centralToBranch = WarehouseTransfer.fromJson(<String, dynamic>{
      'id': 10,
      'number': 'TR-0010',
      'sourceWarehouseId': 3,
      'sourceWarehouseName': 'Central Warehouse',
      'sourceBranchId': null,
      'sourceBranchName': null,
      'destinationWarehouseId': 2,
      'destinationWarehouseName': 'Mall — Bar',
      'destinationBranchId': 12,
      'destinationBranchName': 'Mall',
      'status': 'draft',
    });
    expect(centralToBranch.sourceBranchId, isNull);
    expect(centralToBranch.sourceBranchName, isNull);
    expect(centralToBranch.sourceWarehouseName, 'Central Warehouse');
  });
}
