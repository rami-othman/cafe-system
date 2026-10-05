import '../../pos/models/json_helpers.dart';

/// `POST /manufacturing/conversions` and `GET .../conversions/{id}` response.
/// The exact field shape is not documented beyond the controller/request
/// contract (`ManufacturingConversionController`), so every field is parsed
/// defensively and the raw backend response is otherwise treated as opaque -
/// this model renders whatever the API actually returns rather than assuming
/// a KPI list the backend does not expose.
class ManufacturingConversionResult {
  const ManufacturingConversionResult({
    required this.id,
    required this.warehouseId,
    required this.sourceItemId,
    required this.sourceQty,
    required this.targetItemId,
    required this.resultQty,
    this.sourceItemName,
    this.targetItemName,
    this.resultUnitCost,
    this.totalCost,
    this.date,
    this.status,
  });

  final String id;
  final int warehouseId;
  final int sourceItemId;
  final String sourceQty;
  final int targetItemId;
  final String resultQty;
  final String? sourceItemName;
  final String? targetItemName;
  final String? resultUnitCost;
  final String? totalCost;
  final String? date;
  final String? status;

  factory ManufacturingConversionResult.fromJson(
    Map<String, dynamic> json,
  ) => ManufacturingConversionResult(
    id: readString(json['id'], fallback: readString(json['recordId'])),
    warehouseId: readInt(json['warehouseId']) ?? 0,
    sourceItemId: readInt(json['sourceItemId']) ?? 0,
    sourceQty: readString(json['sourceQty'], fallback: '0'),
    targetItemId: readInt(json['targetItemId']) ?? 0,
    resultQty: readString(json['resultQty'], fallback: '0'),
    sourceItemName: readString(json['sourceItemName']).isEmpty
        ? null
        : readString(json['sourceItemName']),
    targetItemName: readString(json['targetItemName']).isEmpty
        ? null
        : readString(json['targetItemName']),
    resultUnitCost: json['resultUnitCost'] == null
        ? null
        : readString(json['resultUnitCost']),
    totalCost: json['totalCost'] == null ? null : readString(json['totalCost']),
    date: readString(json['date']).isEmpty ? null : readString(json['date']),
    status: readString(json['status']).isEmpty
        ? null
        : readString(json['status']),
  );
}
