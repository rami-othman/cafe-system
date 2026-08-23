import '../../../core/network/dio_api_client.dart';
import '../../pos/models/branch.dart';
import '../../pos/models/json_helpers.dart';
import '../models/finance_setup_models.dart';

class FinanceSetupRepository {
  const FinanceSetupRepository(this._api);
  final DioApiClient _api;

  Future<SetupStatus> getSetupStatus() async => SetupStatus.fromJson(
    Map<String, dynamic>.from(await _api.get('finance/setup-status') as Map),
  );
  Future<List<Branch>> getBranches() async => readMapList(
    await _api.get('branches'),
  ).map(Branch.fromJson).toList(growable: false);
  Future<List<WarehouseLocation>> getWarehouses({String? search}) async =>
      readMapList(
            await _api.get(
              'warehouses',
              queryParameters: _query(<String, dynamic>{
                'search': search,
                'perPage': 100,
                'status': 'active',
              }),
            ),
          )
          .map(WarehouseLocation.fromJson)
          .where((WarehouseLocation warehouse) => !warehouse.isLegacy)
          .toList(growable: false);
  Future<List<FinancialAccount>> getAccounts({String? search}) async =>
      readMapList(
        await _api.get(
          'finance/accounts',
          queryParameters: _query(<String, dynamic>{
            'search': search,
            'perPage': 200,
          }),
        ),
      ).map(FinancialAccount.fromJson).toList(growable: false);
  Future<List<JournalEntry>> getJournalEntries() async => readMapList(
    await _api.get(
      'finance/journal-entries',
      queryParameters: const <String, dynamic>{'perPage': 100},
    ),
  ).map(JournalEntry.fromJson).toList(growable: false);
  Future<WarehouseLocation> saveWarehouse(
    Map<String, dynamic> payload, {
    int? id,
  }) async => WarehouseLocation.fromJson(
    Map<String, dynamic>.from(
      id == null
          ? await _api.post('warehouses', data: payload)
          : await _api.patch('warehouses/$id', data: payload) as Map,
    ),
  );
  Future<WarehouseLocation> setWarehouseStatus(int id, bool isActive) async =>
      WarehouseLocation.fromJson(
        Map<String, dynamic>.from(
          await _api.patch(
                'warehouses/$id/status',
                data: <String, dynamic>{'isActive': isActive},
              )
              as Map,
        ),
      );
  Future<FinancialAccount> saveAccount(
    Map<String, dynamic> payload, {
    int? id,
  }) async => FinancialAccount.fromJson(
    Map<String, dynamic>.from(
      id == null
          ? await _api.post('finance/accounts', data: payload)
          : await _api.patch('finance/accounts/$id', data: payload) as Map,
    ),
  );
  Future<FinancialAccount> setAccountStatus(int id, bool isActive) async =>
      FinancialAccount.fromJson(
        Map<String, dynamic>.from(
          await _api.patch(
                'finance/accounts/$id/status',
                data: <String, dynamic>{'isActive': isActive},
              )
              as Map,
        ),
      );
  Future<JournalEntry> createDraft(Map<String, dynamic> payload) async =>
      JournalEntry.fromJson(
        Map<String, dynamic>.from(
          await _api.post('finance/journal-entries', data: payload) as Map,
        ),
      );
  Future<JournalEntry> getJournalEntry(int id) async => JournalEntry.fromJson(
    Map<String, dynamic>.from(
      await _api.get('finance/journal-entries/$id') as Map,
    ),
  );
  Future<JournalEntry> postJournalEntry(int id) async => JournalEntry.fromJson(
    Map<String, dynamic>.from(
      await _api.post('finance/journal-entries/$id/post') as Map,
    ),
  );

  Map<String, dynamic>? _query(Map<String, dynamic> values) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(values)
      ..removeWhere((String _, dynamic value) => value == null || value == '');
    return result.isEmpty ? null : result;
  }
}
