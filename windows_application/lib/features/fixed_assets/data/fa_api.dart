import 'package:intl/intl.dart';

import '../../../core/network/dio_api_client.dart';
import '../../../core/services/service_locator.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/repositories/finance_setup_repository.dart';
import '../../pos/models/branch.dart';

/// Thin JSON helpers shared by the fixed-assets and partners screens. The
/// backend already returns presentation-ready values (decimal strings,
/// Arabic labels), so the screens read maps directly instead of mirroring
/// every payload in a model class.
typedef Json = Map<String, dynamic>;

Json asJson(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Json> asJsonList(dynamic value) {
  if (value is List) return value.map(asJson).toList(growable: false);
  if (value is Map && value['items'] is List) return asJsonList(value['items']);
  return const <Json>[];
}

String str(dynamic value, [String fallback = '']) => value == null ? fallback : '$value';

int? intOf(dynamic value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}');

double numOf(dynamic value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;

final NumberFormat _money = NumberFormat('#,##0.##', 'en');

/// "1234567.5" → "1,234,567.5" (amounts stay LTR digits like the rest of Finance).
String money(dynamic value) => _money.format(numOf(value));

String isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime? parseDate(dynamic value) => value == null ? null : DateTime.tryParse('$value');

/// Branch filter value used by the API: a branch id, or 'company' for the head office (no branch).
const String kCompanyBranch = 'company';
const String kCompanyBranchLabel = 'الإدارة العامة';

/// All calls of the fixed-assets and partners modules.
class FaApi {
  FaApi() : _api = serviceLocator<DioApiClient>(), _repo = serviceLocator<FinanceSetupRepository>();

  final DioApiClient _api;
  final FinanceSetupRepository _repo;

  Future<List<FinancialAccount>> accounts() => _repo.getAccountCatalog();
  Future<List<Branch>> branches() => _repo.getBranches();

  // ---------------------------------------------------------------- assets
  Future<Json> settings() async => asJson(await _api.get('finance/assets/settings'));
  Future<Json> saveSettings(Json data) async => asJson(await _api.put('finance/assets/settings', data: data));

  Future<List<Json>> categories() async => asJsonList(await _api.get('finance/assets/categories'));
  Future<void> saveCategory(Json data, {int? id}) async => id == null
      ? await _api.post('finance/assets/categories', data: data)
      : await _api.patch('finance/assets/categories/$id', data: data);
  Future<void> deleteCategory(int id) async => _api.delete('finance/assets/categories/$id');
  Future<void> seedCategories() async => _api.post('finance/assets/categories/seed-from-chart');

  Future<List<Json>> locations() async => asJsonList(await _api.get('finance/assets/locations'));
  Future<void> saveLocation(Json data, {int? id}) async => id == null
      ? await _api.post('finance/assets/locations', data: data)
      : await _api.patch('finance/assets/locations/$id', data: data);

  Future<Json> register(Json filters) async =>
      asJson(await _api.get('finance/assets', queryParameters: _clean(filters)));
  Future<Json> asset(int id) async => asJson(await _api.get('finance/assets/$id'));
  Future<Json> createAsset(Json data) async => asJson(await _api.post('finance/assets', data: data));
  Future<Json> updateAsset(int id, Json data) async => asJson(await _api.patch('finance/assets/$id', data: data));
  Future<void> deleteAsset(int id) async => _api.delete('finance/assets/$id');
  Future<Json> activate(int id, {bool generateEntry = true, List<Json>? payments}) async => asJson(
    await _api.post('finance/assets/$id/activate', data: <String, dynamic>{'generateEntry': generateEntry, 'payments': ?payments}),
  );
  Future<Json> addition(int id, Json data) async => asJson(await _api.post('finance/assets/$id/additions', data: data));
  Future<Json> maintenance(int id, Json data) async => asJson(await _api.post('finance/assets/$id/maintenance', data: data));
  Future<Json> expense(int id, Json data) async => asJson(await _api.post('finance/assets/$id/expenses', data: data));
  Future<Json> disposal(int id, Json data) async => asJson(await _api.post('finance/assets/$id/disposals', data: data));
  Future<Json> transfer(int id, Json data) async => asJson(await _api.post('finance/assets/$id/transfers', data: data));
  Future<Json> reverseTransaction(int id, int tx) async =>
      asJson(await _api.post('finance/assets/$id/transactions/$tx/reverse'));
  Future<List<Json>> schedule(int id) async => asJsonList(asJson(await _api.get('finance/assets/$id/schedule'))['rows']);
  Future<Json> alerts({int days = 60}) async =>
      asJson(await _api.get('finance/assets/reports/alerts', queryParameters: <String, dynamic>{'days': days}));
  Future<List<Json>> counts() async => asJsonList(await _api.get('finance/assets/counts'));
  Future<Json> count(int id) async => asJson(await _api.get('finance/assets/counts/$id'));
  Future<Json> startCount(Json data) async => asJson(await _api.post('finance/assets/counts', data: _clean(data)));
  Future<Json> scanCount(int id, String code) async =>
      asJson(await _api.post('finance/assets/counts/$id/scan', data: <String, dynamic>{'code': code}));
  Future<Json> setCountLine(int id, int line, Json data) async =>
      asJson(await _api.patch('finance/assets/counts/$id/lines/$line', data: data));
  Future<Json> closeCount(int id) async => asJson(await _api.post('finance/assets/counts/$id/close'));
  Future<Json> cancelCount(int id) async => asJson(await _api.post('finance/assets/counts/$id/cancel'));
  Future<Json> operations(Json filters) async =>
      asJson(await _api.get('finance/assets/reports/operations', queryParameters: _clean(filters)));

  Future<List<Json>> runs() async => asJsonList(await _api.get('finance/assets/depreciation-runs'));
  Future<Json> run(int id) async => asJson(await _api.get('finance/assets/depreciation-runs/$id'));
  Future<Json> previewRun(Json data) async => asJson(await _api.post('finance/assets/depreciation-runs/preview', data: _clean(data)));
  Future<Json> postRun(Json data) async => asJson(await _api.post('finance/assets/depreciation-runs', data: _clean(data)));
  Future<void> reverseRun(int id) async => _api.post('finance/assets/depreciation-runs/$id/reverse');

  // ---------------------------------------------------------------- partners
  Future<List<Json>> partners() async => asJsonList(await _api.get('finance/partners'));
  Future<void> savePartner(Json data, {int? id}) async => id == null
      ? await _api.post('finance/partners', data: data)
      : await _api.patch('finance/partners/$id', data: data);
  Future<List<Json>> linkableUsers() async => asJsonList(await _api.get('finance/partners/linkable-users'));
  Future<List<Json>> portal(String from, String to) async =>
      asJsonList(await _api.get('finance/partners/portal', queryParameters: <String, dynamic>{'dateFrom': from, 'dateTo': to}));
  Future<List<Json>> overview(String from, String to) async => asJsonList(
    await _api.get('finance/partners/overview', queryParameters: <String, dynamic>{'dateFrom': from, 'dateTo': to}),
  );
  Future<Json> ownership(int branchId) async => asJson(await _api.get('finance/partners/branches/$branchId/ownership'));
  Future<Json> setOwnership(int branchId, Json data) async =>
      asJson(await _api.put('finance/partners/branches/$branchId/ownership', data: data));
  Future<Json> saveBranchSettings(int branchId, Json data) async =>
      asJson(await _api.put('finance/partners/branches/$branchId/settings', data: data));
  Future<List<Json>> partnerTransactions({int? partnerId}) async => asJsonList(
    await _api.get('finance/partners/transactions', queryParameters: _clean(<String, dynamic>{'partnerId': partnerId})),
  );
  Future<void> partnerTransaction(int partnerId, Json data) async =>
      _api.post('finance/partners/$partnerId/transactions', data: _clean(data));
  Future<void> reversePartnerTransaction(int id) async => _api.post('finance/partners/transactions/$id/reverse');
  Future<Json> statement(int partnerId, Json filters) async =>
      asJson(await _api.get('finance/partners/$partnerId/statement', queryParameters: _clean(filters)));
  Future<List<Json>> distributions({int? branchId}) async => asJsonList(
    await _api.get('finance/partners/distributions', queryParameters: _clean(<String, dynamic>{'branchId': branchId})),
  );
  Future<Json> distribution(int id) async => asJson(await _api.get('finance/partners/distributions/$id'));
  Future<Json> previewDistribution(Json data) async =>
      asJson(await _api.post('finance/partners/distributions/preview', data: _clean(data)));
  Future<Json> postDistribution(Json data) async =>
      asJson(await _api.post('finance/partners/distributions', data: _clean(data)));
  Future<void> reverseDistribution(int id) async => _api.post('finance/partners/distributions/$id/reverse');

  // ---------------------------------------------------------------- overhead allocation
  Future<List<Json>> overheadAllocations() async => asJsonList(await _api.get('finance/partners/overhead'));
  Future<Json> previewOverhead(Json data) async => asJson(await _api.post('finance/partners/overhead/preview', data: data));
  Future<Json> postOverhead(Json data) async => asJson(await _api.post('finance/partners/overhead', data: data));
  Future<void> reverseOverhead(int id) async => _api.post('finance/partners/overhead/$id/reverse');

  static Json _clean(Json data) {
    final Json out = <String, dynamic>{};
    data.forEach((String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      out[key] = value;
    });
    return out;
  }
}
