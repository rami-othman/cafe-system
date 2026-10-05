import '../models/transfer_models.dart';

class TransferViewState {
  const TransferViewState({this.search = '', this.status, this.sourceId, this.destinationId});
  final String search; final String? status; final int? sourceId; final int? destinationId;
  List<WarehouseTransfer> filter(List<WarehouseTransfer> source) => source.where((transfer) {
    final term = search.trim().toLowerCase();
    return (term.isEmpty || transfer.number.toLowerCase().contains(term) || transfer.sourceWarehouseName.toLowerCase().contains(term) || transfer.destinationWarehouseName.toLowerCase().contains(term)) && (status == null || transfer.status == status) && (sourceId == null || transfer.sourceWarehouseId == sourceId) && (destinationId == null || transfer.destinationWarehouseId == destinationId);
  }).toList(growable: false);
}
