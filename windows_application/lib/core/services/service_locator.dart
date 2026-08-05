import 'package:get_it/get_it.dart';

import '../../app/localization/app_locale_cubit.dart';
import '../../app/localization/app_locale_repository.dart';
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
import '../../features/menu_management/controllers/product_lifecycle_cubit.dart';
import '../../features/menu_management/products/controllers/product_editor_cubit.dart';
import '../../features/menu_management/variants/controllers/variants_cubit.dart';
import '../../features/menu_management/pricing/controllers/variant_price_overrides_cubit.dart';
import '../../features/menu_management/availability/controllers/availability_cubit.dart';
import '../../features/menu_management/operational_availability/controllers/operational_availability_cubit.dart';
import '../../features/menu_management/repositories/menu_catalog_repository.dart';
import '../../features/menu_management/modifiers/controllers/modifier_library_cubit.dart';
import '../../features/menu_management/modifiers/controllers/modifier_group_detail_cubit.dart';
import '../../features/menu_management/modifiers/controllers/modifier_group_editor_cubit.dart';
import '../../features/menu_management/products/controllers/product_modifier_assignments_cubit.dart';
import '../../features/menu_management/menus/controllers/menu_list_cubit.dart';
import '../../features/menu_management/menus/controllers/menu_detail_cubit.dart';
import '../../features/menu_management/menus/controllers/menu_editor_cubit.dart';
import '../../features/menu_management/menus/controllers/product_placements_cubit.dart';
import '../../features/menu_management/assignments/controllers/menu_assignments_cubit.dart';
import '../../features/menu_management/review/controllers/menu_review_cubit.dart';
import '../../features/menu_management/versions/controllers/published_version_cubit.dart';
import '../../features/menu_management/catalog_setup/controllers/catalog_setup_cubit.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator({bool useBackend = true}) {
  if (!serviceLocator.isRegistered<AppLocaleRepository>()) {
    serviceLocator.registerLazySingleton<AppLocaleRepository>(
      SharedPreferencesAppLocaleRepository.new,
    );
  }
  if (!serviceLocator.isRegistered<AppLocaleCubit>()) {
    serviceLocator.registerFactory<AppLocaleCubit>(
      () => AppLocaleCubit(repository: serviceLocator<AppLocaleRepository>()),
    );
  }

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
  if (!serviceLocator.isRegistered<ProductLifecycleCubit>()) {
    serviceLocator.registerFactory<ProductLifecycleCubit>(
      () => ProductLifecycleCubit(
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
  if (!serviceLocator.isRegistered<VariantPriceOverridesCubit>()) {
    serviceLocator.registerFactory<VariantPriceOverridesCubit>(
      () => VariantPriceOverridesCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<AvailabilityCubit>()) {
    serviceLocator.registerFactory<AvailabilityCubit>(
      () => AvailabilityCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<OperationalAvailabilityCubit>()) {
    serviceLocator.registerFactory<OperationalAvailabilityCubit>(
      () => OperationalAvailabilityCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<ModifierLibraryCubit>()) {
    serviceLocator.registerFactory<ModifierLibraryCubit>(
      () => ModifierLibraryCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<ModifierGroupDetailCubit>()) {
    serviceLocator.registerFactory<ModifierGroupDetailCubit>(
      () => ModifierGroupDetailCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<ModifierGroupEditorCubit>()) {
    serviceLocator.registerFactory<ModifierGroupEditorCubit>(
      () => ModifierGroupEditorCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<ProductModifierAssignmentsCubit>()) {
    serviceLocator.registerFactory<ProductModifierAssignmentsCubit>(
      () => ProductModifierAssignmentsCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<MenuListCubit>()) {
    serviceLocator.registerFactory<MenuListCubit>(
      () => MenuListCubit(repository: serviceLocator<MenuCatalogRepository>()),
    );
  }
  if (!serviceLocator.isRegistered<MenuAssignmentsCubit>()) {
    serviceLocator.registerFactory<MenuAssignmentsCubit>(
      () => MenuAssignmentsCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<MenuReviewCubit>()) {
    serviceLocator.registerFactory<MenuReviewCubit>(
      () =>
          MenuReviewCubit(repository: serviceLocator<MenuCatalogRepository>()),
    );
  }
  if (!serviceLocator.isRegistered<PublishedVersionCubit>()) {
    serviceLocator.registerFactory<PublishedVersionCubit>(
      () => PublishedVersionCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<CatalogSetupCubit>()) {
    serviceLocator.registerFactory<CatalogSetupCubit>(
      () => CatalogSetupCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
  if (!serviceLocator.isRegistered<MenuDetailCubit>()) {
    serviceLocator.registerFactory<MenuDetailCubit>(
      () =>
          MenuDetailCubit(repository: serviceLocator<MenuCatalogRepository>()),
    );
  }
  if (!serviceLocator.isRegistered<MenuEditorCubit>()) {
    serviceLocator.registerFactory<MenuEditorCubit>(
      () =>
          MenuEditorCubit(repository: serviceLocator<MenuCatalogRepository>()),
    );
  }
  if (!serviceLocator.isRegistered<ProductPlacementsCubit>()) {
    serviceLocator.registerFactory<ProductPlacementsCubit>(
      () => ProductPlacementsCubit(
        repository: serviceLocator<MenuCatalogRepository>(),
      ),
    );
  }
}
