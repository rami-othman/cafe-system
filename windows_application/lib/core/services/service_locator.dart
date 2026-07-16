import 'package:get_it/get_it.dart';

import '../network/dio_api_client.dart';
import '../../features/menu/controllers/menu_cubit.dart';
import '../../features/menu/repositories/menu_repository.dart';
import '../../features/menu/repositories/mock_menu_repository.dart';
import '../../features/orders/controllers/orders_cubit.dart';
import '../../features/orders/repositories/orders_repository.dart';
import '../../features/pos/controllers/pos_cubit.dart';
import '../../features/pos/repositories/pos_repository.dart';
import '../../features/discounts/controllers/discounts_cubit.dart';
import '../../features/discounts/repositories/discounts_repository.dart';
import '../../features/reports/controllers/daily_report_cubit.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator({bool useBackend = true}) {
  if (!serviceLocator.isRegistered<DioApiClient>()) {
    serviceLocator.registerLazySingleton<DioApiClient>(DioApiClient.new);
  }

  if (!serviceLocator.isRegistered<PosRepository>()) {
    serviceLocator.registerLazySingleton<PosRepository>(
      () => useBackend
          ? PosRepository(apiClient: serviceLocator<DioApiClient>())
          : PosRepository(),
    );
  }

  if (!serviceLocator.isRegistered<PosCubit>()) {
    serviceLocator.registerFactory<PosCubit>(
      () => PosCubit(repository: serviceLocator<PosRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<OrdersRepository>()) {
    serviceLocator.registerLazySingleton<OrdersRepository>(
      () => useBackend
          ? OrdersRepository(apiClient: serviceLocator<DioApiClient>())
          : const OrdersRepository(),
    );
  }

  if (!serviceLocator.isRegistered<OrdersCubit>()) {
    serviceLocator.registerFactory<OrdersCubit>(
      () => OrdersCubit(repository: serviceLocator<OrdersRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<MenuRepository>()) {
    serviceLocator.registerLazySingleton<MenuRepository>(
      MockMenuRepository.new,
    );
  }

  if (!serviceLocator.isRegistered<MenuCubit>()) {
    serviceLocator.registerFactory<MenuCubit>(
      () => MenuCubit(repository: serviceLocator<MenuRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<DiscountsRepository>()) {
    serviceLocator.registerLazySingleton<DiscountsRepository>(
      () => DiscountsApiRepository(serviceLocator<DioApiClient>()),
    );
  }

  if (!serviceLocator.isRegistered<DiscountsCubit>()) {
    serviceLocator.registerFactory<DiscountsCubit>(
      () => DiscountsCubit(repository: serviceLocator<DiscountsRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<DailyReportCubit>()) {
    serviceLocator.registerFactory<DailyReportCubit>(DailyReportCubit.new);
  }
}
