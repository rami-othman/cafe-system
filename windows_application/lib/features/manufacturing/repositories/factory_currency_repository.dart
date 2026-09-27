import '../../../core/network/dio_api_client.dart';
import '../models/factory_currency.dart';

class FactoryCurrencyRepository {
  const FactoryCurrencyRepository(this._api);
  final DioApiClient _api;
  Future<FactoryCurrencySelection> load(int branchId) async {
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      await _api.get(
            'manufacturing/currency-settings',
            queryParameters: <String, dynamic>{
              'branchId': branchId,
              'scopeBranchId': branchId,
            },
          )
          as Map,
    );
    return FactoryCurrencySelection(
      currency: data['defaultCurrency'] as String? ?? 'SYP',
      rate: '${data['usdToSyp'] ?? ''}',
    );
  }

  Future<void> save(int branchId, FactoryCurrencySelection selection) async {
    await _api.put(
      'manufacturing/currency-settings',
      data: <String, dynamic>{
        'branchId': branchId,
        'scopeBranchId': branchId,
        'defaultCurrency': selection.currency,
        'usdToSyp': selection.rate,
      },
    );
  }
}
