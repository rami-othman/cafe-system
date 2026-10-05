import '../../repositories/inventory_repository.dart';

/// Typed ownership point for the gradual transfer extraction. Network calls
/// still reuse the tenant-aware InventoryRepository client.
class TransferRepository {
  const TransferRepository(this._inventory);
  final InventoryRepository _inventory;
  Future<void> action(int id, String action, Map<String, dynamic> data) async {
    await _inventory.transferAction(id, action, data);
  }
  Future<void> receive(int id, Map<String, dynamic> data) =>
      _inventory.receiveTransfer(id, data);
}
