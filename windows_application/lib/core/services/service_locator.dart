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
import '../../features/reports/controllers/reports_overview_cubit.dart';
import '../../features/reports/repositories/reports_repository.dart';
import '../../features/finance_inventory_setup/controllers/finance_setup_cubit.dart';
import '../../features/finance_inventory_setup/repositories/finance_setup_repository.dart';
import '../../features/inventory/controllers/inventory_cubit.dart';
import '../../features/inventory/repositories/inventory_repository.dart';
import '../../features/operational_context/controllers/operational_branch_cubit.dart';
import '../../features/operational_context/repositories/operational_branch_repository.dart';

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

  if (!serviceLocator.isRegistered<ReportsOverviewCubit>()) {
    if (!serviceLocator.isRegistered<ReportsRepository>()) {
      serviceLocator.registerLazySingleton<ReportsRepository>(
        () => ReportsRepository(
          apiClient: useBackend ? serviceLocator<DioApiClient>() : null,
        ),
      );
    }
    serviceLocator.registerFactory<ReportsOverviewCubit>(
      () =>
          ReportsOverviewCubit(repository: serviceLocator<ReportsRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<FinanceSetupRepository>()) {
    serviceLocator.registerLazySingleton<FinanceSetupRepository>(
      () => FinanceSetupRepository(serviceLocator<DioApiClient>()),
    );
  }

  if (!serviceLocator.isRegistered<FinanceSetupCubit>()) {
    serviceLocator.registerFactory<FinanceSetupCubit>(
      () => FinanceSetupCubit(
        repository: serviceLocator<FinanceSetupRepository>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<InventoryRepository>()) {
    serviceLocator.registerLazySingleton<InventoryRepository>(
      () => InventoryRepository(serviceLocator<DioApiClient>()),
    );
  }
  if (!serviceLocator.isRegistered<InventoryCubit>()) {
    serviceLocator.registerFactory<InventoryCubit>(
      () => InventoryCubit(repository: serviceLocator<InventoryRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<OperationalBranchRepository>()) {
    serviceLocator.registerLazySingleton<OperationalBranchRepository>(
      () => OperationalBranchRepository(
        apiClient: useBackend ? serviceLocator<DioApiClient>() : null,
      ),
    );
  }
  if (!serviceLocator.isRegistered<OperationalBranchCubit>()) {
    serviceLocator.registerFactory<OperationalBranchCubit>(
      () => OperationalBranchCubit(
        repository: serviceLocator<OperationalBranchRepository>(),
      ),
    );
  }
}
