import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/pricing/configured_price_validation.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    setupServiceLocator(useBackend: false);
    serviceLocator.unregister<MenuCatalogRepository>();
    serviceLocator.registerLazySingleton<MenuCatalogRepository>(
      _RouteRepository.new,
    );
  });

  group('Menu Management route IDs', () {
    test('accepts valid product and nested IDs', () {
      expect(parsePositiveRouteId('42'), 42);
      expect(parsePositiveRouteId('7'), 7);
    });

    test(
      'rejects malformed, zero, negative, and absent IDs without parsing exceptions',
      () {
        for (final String? value in <String?>['abc', '0', '-1', null, '4.2']) {
          expect(parsePositiveRouteId(value), isNull);
        }
      },
    );
  });

  testWidgets(
    'Arabic localized product workspace entity values remain RTL-safe',
    (tester) async {
      final ProductDetail product = ProductDetail.fromJson(<String, dynamic>{
        'id': 42,
        'name': 'Latte',
        'nameAr': 'لاتيه',
        'nameEn': 'Latte',
        'productType': 'standard',
        'isActive': true,
        'category': <String, dynamic>{
          'id': 1,
          'name': 'Coffee',
          'nameAr': 'قهوة',
          'nameEn': 'Coffee',
          'isActive': true,
        },
        'reportingCategory': <String, dynamic>{
          'id': 2,
          'name': 'Beverages',
          'nameAr': 'مشروبات',
          'nameEn': 'Beverages',
          'code': 'BEV',
          'isActive': true,
        },
        'kitchenStation': <String, dynamic>{
          'id': 3,
          'name': 'Bar',
          'nameAr': 'البار',
          'nameEn': 'Bar',
          'code': 'BAR',
          'isActive': true,
        },
        'defaultVariant': <String, dynamic>{
          'id': 4,
          'name': 'Regular',
          'nameAr': 'عادي',
          'nameEn': 'Regular',
          'basePrice': 5,
          'isDefault': true,
          'isActive': true,
          'sortOrder': 0,
        },
        'variantCount': 1,
        'modifierGroupCount': 0,
        'isStockTracked': false,
        'sortOrder': 0,
        'variants': <Map<String, dynamic>>[],
        'modifierGroups': <Map<String, dynamic>>[],
      });
      const Locale ar = Locale('ar');
      expect(product.displayName(ar), 'لاتيه');
      expect(product.category!.displayName(ar), 'قهوة');
      expect(product.reportingCategory!.displayName(ar), 'مشروبات');
      expect(product.kitchenStation!.displayName(ar), 'البار');
      expect(product.defaultVariant!.displayName(ar), 'عادي');
      expect(product.category!.displayName(const Locale('en')), 'Coffee');
      final CatalogCategory fallback = CatalogCategory.fromJson(
        <String, dynamic>{'id': 5, 'name': 'Fallback', 'isActive': true},
      );
      expect(fallback.displayName(ar), 'Fallback');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            child: SizedBox(
              width: 180,
              child: Text('لاتيه قهوة مشروبات البار عادي'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configured selling-price validation is localized in English and Arabic',
    (tester) async {
      for (final (Locale locale, String message) in <(Locale, String)>[
        (const Locale('en'), 'Selling price must be greater than zero.'),
        (const Locale('ar'), 'يجب أن يكون سعر البيع أكبر من صفر.'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Text(
                localizedConfiguredPriceError(
                  context,
                  configuredSellPriceMustBePositive,
                )!,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(message), findsOneWidget);
      }
    },
  );

  testWidgets(
    'actual GoRouter keeps the Menu Management shell stable for valid and invalid IDs',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const App());
      await tester.pump();
      appRouter.go('/menu-management/products/42');
      await tester.pump();
      expect(tester.takeException(), isNull);

      appRouter.go('/menu-management/products/42/variants');
      await tester.pump();
      expect(tester.takeException(), isNull);

      for (final String invalid in <String>['abc', '0', '-1']) {
        appRouter.go('/menu-management/products/$invalid');
        await tester.pump();
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is Text &&
                <String>[
                  'The requested catalog route is invalid.',
                  'مسار الكتالوج المطلوب غير صالح.',
                ].contains(widget.data),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}

class _RouteRepository extends MenuCatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => ProductDetail.fromJson(<String, dynamic>{
    'id': productId,
    'name': 'Latte',
    'productType': 'standard',
    'isActive': true,
    'category': null,
    'reportingCategory': null,
    'kitchenStation': null,
    'defaultVariant': <String, dynamic>{
      'id': 1,
      'name': 'Regular',
      'basePrice': 5,
      'isDefault': true,
      'isActive': true,
      'sortOrder': 0,
    },
    'variantCount': 1,
    'modifierGroupCount': 0,
    'isStockTracked': false,
    'sortOrder': 0,
    'variants': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'productId': productId,
        'name': 'Regular',
        'basePrice': 5,
        'isDefault': true,
        'isActive': true,
        'sortOrder': 0,
      },
    ],
    'modifierGroups': const <Map<String, dynamic>>[],
  });
}
