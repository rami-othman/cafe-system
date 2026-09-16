import '../../../core/network/dio_api_client.dart';
import '../../pos/models/json_helpers.dart';
import '../models/bar_check_session.dart';

/// Dedicated, minimal data access for the cashier shift-close and own-shift
/// bar-check flow. Deliberately independent of InventoryRepository/
/// InventoryCubit: a cashier never needs the full Inventory Center, only
/// these few scoped endpoints (each independently authorized server-side —
/// see BarCheckAccess on the API). Business logic (variances, approvals,
/// posting) stays on the backend; this layer only moves data.
class ShiftCloseRepository {
  ShiftCloseRepository(this._api);

  final DioApiClient _api;

  Future<Map<String, dynamic>> closeShift({
    required int shiftId,
    required double closingCash,
    String? note,
  }) async {
    final dynamic response = await _api.post(
      'shifts/$shiftId/close',
      data: <String, dynamic>{
        'closingCash': closingCash,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// The warehouseId of the active, required-for-shift-close bar-check
  /// template for the given branch, or null when none applies. Cashiers only
  /// ever see templates scoped to their own accessible branch (server-enforced).
  Future<int?> requiredTemplateWarehouseForBranch(int branchId) async {
    final dynamic response = await _api.get('inventory/bar-check-templates');
    for (final Map<String, dynamic> template in readMapList(response)) {
      final bool active = readBool(template['active']);
      final bool required = readBool(template['requiredForShiftClose']);
      final int templateBranchId = readInt(template['branchId']) ?? 0;
      if (active && required && templateBranchId == branchId) {
        return readInt(template['warehouseId']);
      }
    }
    return null;
  }

  Future<BarCheckSession> startBarCheck({
    required int shiftId,
    required int warehouseId,
  }) async {
    final dynamic response = await _api.post(
      'inventory/bar-checks',
      data: <String, dynamic>{'shiftId': shiftId, 'warehouseId': warehouseId},
    );
    final int stockCountId =
        readInt(Map<String, dynamic>.from(response as Map)['stockCountId']) ??
        0;
    return getCount(stockCountId);
  }

  Future<BarCheckSession> getCount(int countId) async {
    final dynamic response = await _api.get('inventory/counts/$countId');
    return BarCheckSession.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BarCheckSession> upsertLine({
    required int countId,
    required int itemId,
    required String countedQuantity,
    required String unit,
    String? reason,
  }) async {
    final dynamic response = await _api.put(
      'inventory/counts/$countId/lines',
      data: <String, dynamic>{
        'itemId': itemId,
        'countedQuantity': countedQuantity,
        'unit': unit,
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      },
    );
    return BarCheckSession.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<BarCheckSession> transition(int countId, String action) async {
    final dynamic response = await _api.post(
      'inventory/counts/$countId/$action',
    );
    return BarCheckSession.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
