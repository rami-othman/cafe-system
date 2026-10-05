import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/manufacturing/controllers/factory_currency_cubit.dart';
import 'package:windows_application/features/manufacturing/models/factory_currency.dart';
import 'package:windows_application/features/manufacturing/repositories/factory_currency_repository.dart';

void registerFactoryCurrencyFixture(DioApiClient client) {
  if (serviceLocator.isRegistered<FactoryCurrencyCubit>()) {
    serviceLocator.unregister<FactoryCurrencyCubit>();
  }
  serviceLocator.registerFactory<FactoryCurrencyCubit>(
    () => FactoryCurrencyCubit(_FixtureRepository(client)),
  );
}

class _FixtureRepository extends FactoryCurrencyRepository {
  _FixtureRepository(super.api);
  @override
  Future<FactoryCurrencySelection> load(int branchId) async =>
      const FactoryCurrencySelection(rate: '10000');
}
