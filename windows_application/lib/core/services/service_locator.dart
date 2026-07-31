import 'package:get_it/get_it.dart';

import '../network/dio_api_client.dart';
import '../../features/orders/controllers/orders_cubit.dart';
import '../../features/orders/repositories/orders_repository.dart';
import '../../features/pos/controllers/pos_cubit.dart';
import '../../features/pos/repositories/pos_repository.dart';
import '../../features/discounts/controllers/discounts_cubit.dart';
import '../../features/discounts/repositories/discounts_repository.dart';
import '../../features/reports/controllers/daily_report_cubit.dart';
import '../../features/reports/repositories/reports_repository.dart';
import '../../features/menu_management/controllers/product_catalog_cubit.dart';
import '../../features/menu_management/controllers/product_detail_cubit.dart';
import '../../features/menu_management/products/controllers/product_editor_cubit.dart';
import '../../features/menu_management/variants/controllers/variants_cubit.dart';
import '../../features/menu_management/repositories/menu_catalog_repository.dart';

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
    if (!serviceLocator.isRegistered<ReportsRepository>()) {
      serviceLocator.registerLazySingleton<ReportsRepository>(
        () => ReportsRepository(
          apiClient: useBackend ? serviceLocator<DioApiClient>() : null,
        ),
      );
    }
    serviceLocator.registerFactory<DailyReportCubit>(
      () => DailyReportCubit(repository: serviceLocator<ReportsRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<MenuCatalogRepository>()) {
    serviceLocator.registerLazySingleton<MenuCatalogRepository>(
      () => BackendMenuCatalogRepository(serviceLocator<DioApiClient>()),
    );
  }

  if (!serviceLocator.isRegistered<ProductCatalogCubit>()) {
    serviceLocator.registerFactory<ProductCatalogCubit>(
      () => ProductCatalogCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<ProductDetailCubit>()) {
    serviceLocator.registerFactory<ProductDetailCubit>(
      () => ProductDetailCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<ProductEditorCubit>()) {
    serviceLocator.registerFactory<ProductEditorCubit>(
      () => ProductEditorCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<VariantsCubit>()) {
    serviceLocator.registerFactory<VariantsCubit>(
      () => VariantsCubit(repository: serviceLocator<MenuCatalogRepository>()),
    );
  }
}
