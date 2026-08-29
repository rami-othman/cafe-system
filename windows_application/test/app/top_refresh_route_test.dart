import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/features/menu_management/controllers/product_catalog_cubit.dart';
import 'package:windows_application/features/menu_management/menus/controllers/menu_list_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  testWidgets(
    'top Refresh uses the current Menus route instead of a stale Products callback',
    (tester) async {
      final _CountingRepository repository = _CountingRepository();
      final ProductCatalogCubit products = ProductCatalogCubit(
        repository: repository,
      );
      final MenuListCubit menus = MenuListCubit(repository: repository);
      addTearDown(products.close);
      addTearDown(menus.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ProductCatalogCubit>.value(value: products),
            BlocProvider<MenuListCubit>.value(value: menus),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  // Products was the previous route. Resolve again after
                  // navigation, exactly as the shell does for Menus.
                  final previous = refreshActionForMatchedLocation(
                    AppRoutes.menuManagementProducts,
                  );
                  expect(previous, isNotNull);
                  final current = refreshActionForMatchedLocation(
                    AppRoutes.menuManagementMenus,
                  );
                  await current!(context);
                },
                child: const Text('Refresh'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Refresh'));
      await tester.pump();

      expect(repository.menuRefreshes, 1);
      expect(repository.productRefreshes, 0);
    },
  );
}

class _CountingRepository extends MenuCatalogRepository {
  int productRefreshes = 0;
  int menuRefreshes = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    productRefreshes++;
    return const CatalogPage<ProductSummary>(
      items: <ProductSummary>[],
      meta: CatalogPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 0,
      ),
    );
  }

  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    menuRefreshes++;
    return const CatalogPage<MenuRecord>(
      items: <MenuRecord>[],
      meta: CatalogPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 0,
      ),
    );
  }
}
