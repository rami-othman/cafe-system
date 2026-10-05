import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/models/inventory_models.dart';
import 'package:windows_application/features/inventory/transfers/controllers/transfer_view_state.dart';

WarehouseTransfer transfer({required int id, required String status}) => WarehouseTransfer(
  id: id, number: 'TR-$id', sourceWarehouseId: 1, sourceWarehouseName: 'Source',
  destinationWarehouseId: 2, destinationWarehouseName: 'Destination', status: status,
  lines: const <WarehouseTransferLine>[],
);

void main() {
  test('filters transfer list by search and server status', () {
    final result = TransferViewState(search: 'TR-2', status: 'approved').filter(<WarehouseTransfer>[
      transfer(id: 1, status: 'draft'), transfer(id: 2, status: 'approved'),
    ]);
    expect(result.single.id, 2);
  });
}
