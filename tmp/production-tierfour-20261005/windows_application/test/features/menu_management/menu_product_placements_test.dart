import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/menu_management/menus/controllers/product_placements_cubit.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/menus/models/product_placement.dart';
import 'package:windows_application/features/menu_management/menus/views/product_placements_screen.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  group('placement repository contract', () {
    test(
      'uses placement endpoints, archived query, and mutation-only payloads',
      () async {
        final List<RequestOptions> requests = <RequestOptions>[];
        final BackendMenuCatalogRepository repository =
            BackendMenuCatalogRepository(
              _client((RequestOptions options) {
                requests.add(options);
                return Response<dynamic>(
                  requestOptions: options,
                  data: options.method == 'GET'
                      ? <Map<String, dynamic>>[_placementJson()]
                      : <String, dynamic>{'data': _placementJson()},
                );
              }),
            );
        final ProductPlacementDraft draft = ProductPlacementDraft(
          productId: 11,
          displayNameOverride: 'Latte',
          isFeatured: true,
        );

        await repository.getMenuPlacements(5, includeArchived: true);
        await repository.createProductPlacement(5, draft);
        await repository.updateProductPlacement(9, draft);
        await repository.moveProductPlacement(9, 6, sortOrder: 1);
        await repository
            .reorderSectionPlacements(5, const <PlacementReorderItem>[
              PlacementReorderItem(id: 9, sortOrder: 0),
              PlacementReorderItem(id: 10, sortOrder: 1),
            ]);
        await repository.archiveProductPlacement(9);
        await repository.restoreProductPlacement(9);

        expect(requests.map((r) => r.path), <String>[
          'admin/menu-sections/5/placements',
          'admin/menu-sections/5/placements',
          'admin/menu-item-placements/9',
          'admin/menu-item-placements/9/move',
          'admin/menu-sections/5/placements/reorder',
          'admin/menu-item-placements/9/archive',
          'admin/menu-item-placements/9/restore',
        ]);
        expect(requests.first.queryParameters['includeArchived'], isTrue);
        final Map<String, dynamic> create = Map<String, dynamic>.from(
          requests[1].data! as Map,
        );
        final Map<String, dynamic> update = Map<String, dynamic>.from(
          requests[2].data! as Map,
        );
        expect(create, containsPair('productId', 11));
        expect(update.containsKey('productId'), isFalse);
        for (final Map<String, dynamic> data in <Map<String, dynamic>>[
          create,
          update,
        ]) {
          expect(
            data.keys,
            isNot(
              containsAll(<String>[
                'product',
                'section',
                'tenantId',
                'archivedAt',
                'createdAt',
                'updatedAt',
              ]),
            ),
          );
        }
        expect(requests[3].data, <String, dynamic>{
          'targetSectionId': 6,
          'sortOrder': 1,
        });
        expect(requests[4].data, <String, dynamic>{
          'items': <Map<String, int>>[
            <String, int>{'id': 9, 'sortOrder': 0},
            <String, int>{'id': 10, 'sortOrder': 1},
          ],
        });
        expect(requests[5].data, isNull);
        expect(requests[6].data, isNull);
      },
    );

    test('nested Laravel validation errors are retained', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 422,
                data: <String, dynamic>{
                  'message': 'Validation failed.',
                  'errors': <String, dynamic>{
                    'items.1.id': <String>['Invalid placement.'],
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            ),
          ),
        ),
      );
      await expectLater(
        BackendMenuCatalogRepository(
          DioApiClient(dio: dio),
        ).reorderSectionPlacements(5, const <PlacementReorderItem>[
          PlacementReorderItem(id: 9, sortOrder: 0),
        ]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.validationErrors?['items.1.id']?.single,
            'nested error',
            'Invalid placement.',
          ),
        ),
      );
    });
  });

  group('ProductPlacementsCubit', () {
    test(
      'hydrates every nested bounded placement without section requests',
      () async {
        final repository = _PlacementRepository();
        final cubit = ProductPlacementsCubit(repository: repository);
        final menu = MenuRecord.fromJson(_nestedCompositionMenuJson());

        cubit.hydrate(menu);

        expect(cubit.state.forSection(5).map((item) => item.id), <int>[9, 10]);
        expect(cubit.state.forSection(6).map((item) => item.id), <int>[11]);
        expect(repository.placementFetchCalls, 0);
        expect(repository.menuFetchCalls, 0);
        await cubit.close();
      },
    );

    test(
      'loads under authoritative sections, filters, and preserves the filter on refresh',
      () async {
        final _PlacementRepository repository = _PlacementRepository();
        final ProductPlacementsCubit cubit = ProductPlacementsCubit(
          repository: repository,
        );
        await cubit.load(1);
        expect(cubit.state.forSection(5).map((p) => p.id), <int>[9, 10]);
        expect(repository.placementFetchCalls, 0);
        cubit.setFilter(PlacementFilter.archived);
        expect(cubit.state.forSection(5).map((p) => p.id), <int>[12]);
        cubit.setFilter(PlacementFilter.all);
        await cubit.load(1, refresh: true);
        expect(cubit.state.filter, PlacementFilter.all);
        await cubit.close();
      },
    );

    test(
      'create succeeds, rejects same-section duplicates, and preserves state on failure',
      () async {
        final _PlacementRepository repository = _PlacementRepository();
        final ProductPlacementsCubit cubit = ProductPlacementsCubit(
          repository: repository,
        );
        await cubit.load(1);
        await cubit.create(5, const ProductPlacementDraft(productId: 13));
        expect(repository.createCalls, 1);
        await cubit.create(5, const ProductPlacementDraft(productId: 11));
        expect(repository.createCalls, 1);
        expect(cubit.state.errorMessage, contains('already placed'));
        final int count = cubit.state.placements[5]!.length;
        repository.failCreate = true;
        await cubit.create(5, const ProductPlacementDraft(productId: 14));
        expect(cubit.state.placements[5], hasLength(count));
        expect(cubit.state.fieldErrors['productId'], <String>['Unavailable.']);
        await cubit.close();
      },
    );

    test(
      'picker keeps target duplicates visible, excludes archived Products, and preserves valid inactive Products',
      () async {
        final repository = _PlacementRepository();
        final cubit = ProductPlacementsCubit(repository: repository);
        await cubit.load(1);

        await cubit.searchProducts('', sectionId: 5);
        expect(
          cubit.state.pickerProducts.map((product) => product.id),
          containsAll(<int>[11, 12, 13, 15]),
        );
        expect(
          cubit.state.pickerProducts.map((product) => product.id),
          isNot(contains(14)),
        );
        expect(
          cubit.state.placements[5]!
              .where((placement) => !placement.isArchived)
              .map((placement) => placement.productId),
          contains(11),
        );
        expect(
          cubit.state.placements[6]!
              .where((placement) => !placement.isArchived)
              .map((placement) => placement.productId),
          isNot(contains(11)),
        );
        expect(repository.productListCalls, 1);
        await cubit.close();
      },
    );

    test(
      'batch placement refreshes successes and accurately reports failures',
      () async {
        final repository = _PlacementRepository()..failedProductIds.add(14);
        final cubit = ProductPlacementsCubit(repository: repository);
        await cubit.load(1);

        final result = await cubit.createMany(6, const <int>[13, 14]);

        expect(result.successfulProductIds, <int>[13]);
        expect(result.failedProductIds, <int>[14]);
        expect(result.fullySucceeded, isFalse);
        expect(
          cubit.state.forSection(6).map((placement) => placement.productId),
          contains(13),
        );
        expect(repository.menuFetchCalls, 2);
        await cubit.close();
      },
    );

    test(
      'batch placement reports backend duplicate races without rollback',
      () async {
        final repository = _PlacementRepository()
          ..conflictingProductIds.add(13);
        final cubit = ProductPlacementsCubit(repository: repository);
        await cubit.load(1);

        final result = await cubit.createMany(6, const <int>[13]);

        expect(result.successfulProductIds, isEmpty);
        expect(result.failedProductIds, <int>[13]);
        expect(result.conflictedProductIds, <int>[13]);
        expect(repository.menuFetchCalls, 2);
        await cubit.close();
      },
    );

    test(
      'edits, moves, and rejects same, archived, or foreign-menu targets',
      () async {
        final _PlacementRepository repository = _PlacementRepository();
        final ProductPlacementsCubit cubit = ProductPlacementsCubit(
          repository: repository,
        );
        await cubit.load(1);
        await cubit.update(9, const ProductPlacementDraft(isVisible: false));
        expect(repository.updateCalls, 1);
        final ProductPlacement placement = cubit.state.placements[5]!.first;
        await cubit.move(placement, 6);
        expect(repository.moveTargets, <int>[6]);
        await cubit.move(placement, 5);
        expect(cubit.state.errorMessage, contains('different section'));
        await cubit.move(placement, 7);
        expect(cubit.state.errorMessage, contains('cannot be changed'));
        await cubit.move(placement, 8);
        expect(cubit.state.errorMessage, contains('unavailable'));
        await cubit.close();
      },
    );

    test(
      'reorders complete active list and leaves visible order intact on failure',
      () async {
        final _PlacementRepository repository = _PlacementRepository();
        final ProductPlacementsCubit cubit = ProductPlacementsCubit(
          repository: repository,
        );
        await cubit.load(1);
        await cubit.reorder(5, 0, 1);
        expect(repository.reorderItems.map((i) => i.id), <int>[10, 9]);
        expect(repository.reorderItems.map((i) => i.sortOrder), <int>[0, 1]);
        final List<int> before = cubit.state
            .forSection(5)
            .map((p) => p.id)
            .toList();
        repository.failReorder = true;
        await cubit.reorder(5, 0, 1);
        expect(cubit.state.forSection(5).map((p) => p.id), before);
        await cubit.close();
      },
    );

    test(
      'archives and restores safely, including duplicate conflicts and parent guards',
      () async {
        final _PlacementRepository repository = _PlacementRepository();
        final ProductPlacementsCubit cubit = ProductPlacementsCubit(
          repository: repository,
        );
        await cubit.load(1);
        await cubit.archive(9);
        expect(repository.archiveCalls, 1);
        await cubit.restore(12);
        expect(repository.restoreCalls, 1);
        repository.failRestore = true;
        await cubit.restore(12);
        expect(cubit.state.errorMessage, contains('already placed'));
        await cubit.create(7, const ProductPlacementDraft(productId: 99));
        expect(repository.createCalls, 0);
        await cubit.close();
      },
    );

    test(
      'prevents duplicate submissions and makes an archived menu read-only',
      () async {
        final _PlacementRepository repository = _PlacementRepository()
          ..createCompleter = Completer<ProductPlacement>();
        final ProductPlacementsCubit cubit = ProductPlacementsCubit(
          repository: repository,
        );
        await cubit.load(1);
        final Future<void> first = cubit.create(
          5,
          const ProductPlacementDraft(productId: 13),
        );
        await cubit.create(5, const ProductPlacementDraft(productId: 14));
        expect(repository.createCalls, 1);
        repository.createCompleter!.complete(
          ProductPlacement.fromJson(_placementJson(id: 13, productId: 13)),
        );
        await first;
        await cubit.close();

        final ProductPlacementsCubit archived = ProductPlacementsCubit(
          repository: _PlacementRepository(archivedMenu: true),
        );
        await archived.load(1);
        await archived.create(5, const ProductPlacementDraft(productId: 13));
        expect(archived.state.readOnly, isTrue);
        await archived.close();
      },
    );
  });

  testWidgets(
    'placement screen renders ordered sections, diagnostics, dialogs, and no later-phase controls',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final _PlacementRepository repository = _PlacementRepository();
      repository.data[5]![0] = ProductPlacement.fromJson(<String, dynamic>{
        ..._placementJson(id: 9, productId: 11),
        'product': <String, dynamic>{
          ..._placementJson(productId: 11)['product'] as Map<String, dynamic>,
          'archivedAt': '2026-07-31T10:00:00Z',
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ProductPlacementsCubit>(
              create: (_) => ProductPlacementsCubit(repository: repository),
              child: const ProductPlacementsScreen(menuId: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Coffee')).dy,
        lessThan(tester.getTopLeft(find.text('Tea')).dy),
      );
      expect(find.text('Archived Product'), findsOneWidget);
      expect(find.byTooltip('Move Up'), findsNothing);
      expect(find.text('Add Products'), findsWidgets);
      expect(find.byTooltip('Add Products'), findsWidgets);
      await tester.tap(find.text('Reorder Products'));
      await tester.pump();
      expect(find.byTooltip('Move Up'), findsWidgets);
      expect(find.byTooltip('Move Down'), findsWidgets);
      expect(find.text('Add Products'), findsNothing);
      expect(find.byTooltip('Add Products'), findsNothing);
      expect(find.text('Branch'), findsNothing);
      expect(find.text('Price Override'), findsNothing);
      expect(find.text('Availability'), findsNothing);
      expect(find.text('Preview'), findsNothing);
      expect(find.text('Publish'), findsNothing);
      expect(find.text('Version'), findsNothing);
      await tester.tap(find.byKey(const Key('menu-products-reorder-done')));
      await tester.pump();
      expect(find.text('Add Products'), findsWidgets);
      expect(find.byTooltip('Add Products'), findsWidgets);
    },
  );

  testWidgets(
    'Add Products re-evaluates target-section duplicates, invalidates selections, and reconciles a multi-add',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _BatchNinePlacementRepository();
      final pickerSheet = find.byKey(const Key('menu-products-picker-sheet'));
      Finder pickerProductRow(String name) => find.ancestor(
        of: find.descendant(of: pickerSheet, matching: find.text(name)),
        matching: find.byType(InkWell),
      );
      Finder pickerCheckbox(String name) => find.descendant(
        of: pickerProductRow(name),
        matching: find.byType(Checkbox),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ProductPlacementsCubit>(
              create: (_) => ProductPlacementsCubit(repository: repository),
              child: const ProductPlacementsScreen(menuId: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu-products-add')));
      await tester.pumpAndSettle();
      expect(pickerSheet, findsOneWidget);
      expect(find.text('Add to Section'), findsOneWidget);
      expect(find.text('Selected: 0'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('menu-products-picker-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<Checkbox>(pickerCheckbox('Espresso')).onChanged,
        isNotNull,
      );
      expect(
        tester.widget<Checkbox>(pickerCheckbox('Almond Croissant')).onChanged,
        isNotNull,
      );

      await tester.tap(pickerProductRow('Espresso'));
      await tester.pump();
      expect(find.text('Selected: 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-products-picker-section')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('rami').last);
      await tester.pumpAndSettle();
      expect(find.text('Selected: 0'), findsOneWidget);
      expect(find.text('Already in rami'), findsNWidgets(2));
      expect(
        tester.widget<Checkbox>(pickerCheckbox('Espresso')).onChanged,
        isNull,
      );
      expect(
        tester.widget<Checkbox>(pickerCheckbox('Almond Croissant')).onChanged,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('menu-products-picker-submit')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.createCalls, 0);

      await tester.tap(find.byKey(const Key('menu-products-picker-section')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('coffee').last);
      await tester.pumpAndSettle();
      await tester.tap(pickerProductRow('Latte'));
      await tester.pump();
      expect(find.text('Selected: 1'), findsOneWidget);
      await tester.tap(pickerProductRow('Cold Brew'));
      await tester.pump();
      expect(find.text('Selected: 2'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('menu-products-picker-submit')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('menu-products-picker-submit')));
      await tester.pump();
      expect(repository.createCalls, 2);
      expect(
        find.byKey(const Key('menu-products-picker-sheet')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('menu-products-picker-submit')),
            )
            .onPressed,
        isNull,
      );
      repository.refreshCompleter.complete(repository.menuSnapshot());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-products-picker-sheet')), findsNothing);
      expect(repository.createCalls, 2);
      expect(repository.menuFetchCalls, 2);
      expect(repository.placementFetchCalls, 0);
      expect(
        find.descendant(
          of: find.byKey(const Key('composition-section-5')),
          matching: find.text('Latte'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('composition-section-5')),
          matching: find.text('Cold Brew'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('composition-section-5')),
          matching: find.text('2 Products'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Section Add Products preselects its Section and mirrors in RTL',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ProductPlacementsCubit>(
              create: (_) =>
                  ProductPlacementsCubit(repository: _PlacementRepository()),
              child: const ProductPlacementsScreen(menuId: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('إضافة منتجات').at(1));
      await tester.pumpAndSettle();
      final field = tester.widget<DropdownButtonFormField<int>>(
        find.byKey(const Key('menu-products-picker-section')),
      );
      expect(field.initialValue, 6);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('menu-products-picker-sheet')))
            .dx,
        0,
      );
    },
  );

  testWidgets(
    'renders nested Menu Detail composition counts and reorders within Section A',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _PlacementRepository();
      final menu = MenuRecord.fromJson(_nestedCompositionMenuJson());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ProductPlacementsCubit>(
              create: (_) => ProductPlacementsCubit(repository: repository),
              child: ProductPlacementsScreen(menuId: 1, initialMenu: menu),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Product 11'), findsOneWidget);
      expect(find.text('Product 12'), findsOneWidget);
      expect(find.text('Product 13'), findsOneWidget);
      expect(find.text('2 Products'), findsOneWidget);
      expect(find.text('1 Products'), findsOneWidget);
      expect(repository.menuFetchCalls, 0);
      expect(repository.placementFetchCalls, 0);

      await tester.tap(find.text('Reorder Products'));
      await tester.pump();
      final firstUp = tester.widget<IconButton>(
        find.byKey(const Key('placement-move-up')).first,
      );
      final secondDown = tester.widget<IconButton>(
        find.byKey(const Key('placement-move-down')).at(1),
      );
      expect(firstUp.onPressed, isNull);
      expect(secondDown.onPressed, isNull);

      await tester.tap(find.byKey(const Key('placement-move-down')).first);
      await tester.pumpAndSettle();
      expect(repository.reorderItems.map((item) => item.id), <int>[10, 9]);
      expect(repository.menuFetchCalls, 1);
      expect(repository.placementFetchCalls, 0);
      expect(
        tester.getTopLeft(find.text('Product 12')).dy,
        lessThan(tester.getTopLeft(find.text('Product 11')).dy),
      );
      await tester.tap(find.byKey(const Key('menu-products-reorder-done')));
      await tester.pump();
      expect(find.byTooltip('Move Up'), findsNothing);
    },
  );

  testWidgets('archived menus and archived sections are read-only', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ProductPlacementsCubit>(
            create: (_) => ProductPlacementsCubit(
              repository: _PlacementRepository(archivedMenu: true),
            ),
            child: const ProductPlacementsScreen(menuId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('archived and read-only'), findsOneWidget);
    expect(find.text('Add Products'), findsNothing);
    expect(find.byKey(const Key('menu-products-reorder')), findsNothing);
  });
}

class _PlacementRepository extends MenuCatalogRepository {
  _PlacementRepository({this.archivedMenu = false});
  final bool archivedMenu;
  final Map<int, List<ProductPlacement>> data = <int, List<ProductPlacement>>{
    5: <ProductPlacement>[
      ProductPlacement.fromJson(
        _placementJson(id: 9, productId: 11, sortOrder: 0),
      ),
      ProductPlacement.fromJson(
        _placementJson(id: 10, productId: 12, sortOrder: 1),
      ),
      ProductPlacement.fromJson(
        _placementJson(id: 12, productId: 15, sortOrder: 2, archived: true),
      ),
    ],
    6: <ProductPlacement>[],
    7: <ProductPlacement>[],
  };
  int createCalls = 0,
      updateCalls = 0,
      archiveCalls = 0,
      restoreCalls = 0,
      placementFetchCalls = 0,
      menuFetchCalls = 0,
      productListCalls = 0;
  final List<int> moveTargets = <int>[];
  List<PlacementReorderItem> reorderItems = <PlacementReorderItem>[];
  bool failCreate = false, failReorder = false, failRestore = false;
  final Set<int> failedProductIds = <int>{};
  final Set<int> conflictingProductIds = <int>{};
  Completer<ProductPlacement>? createCompleter;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<MenuRecord> getMenu(int menuId, {bool includeArchived = false}) async {
    menuFetchCalls++;
    return MenuRecord.fromJson(<String, dynamic>{
      ..._menuJson(archived: archivedMenu),
      'placements': data.values
          .expand((items) => items)
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'sectionId': item.sectionId,
              'productId': item.productId,
              'sortOrder': item.sortOrder,
              'isFeatured': item.isFeatured,
              'isVisible': item.isVisible,
              'displayNameOverride': item.displayNameOverride,
              'displayDescriptionOverride': item.displayDescriptionOverride,
              'displayImageOverride': item.displayImageOverride,
              'archivedAt': item.archivedAt?.toIso8601String(),
              if (item.product != null)
                'product': <String, dynamic>{
                  'id': item.product!.id,
                  'name': item.product!.name,
                  'nameAr': item.product!.nameAr,
                  'nameEn': item.product!.nameEn,
                  'description': item.product!.description,
                  'imageUrl': item.product!.imageUrl,
                  'productType': item.product!.productType,
                  'isActive': item.product!.isActive,
                  'variantCount': item.product!.variantCount,
                  'modifierGroupCount': item.product!.modifierGroupCount,
                  'archivedAt': item.product!.archivedAt?.toIso8601String(),
                  if (item.product!.defaultVariant != null)
                    'defaultVariant': <String, dynamic>{
                      'id': item.product!.defaultVariant!.id,
                      'name': item.product!.defaultVariant!.name,
                      'basePrice': item.product!.defaultVariant!.basePrice,
                      'costPrice': item.product!.defaultVariant!.costPrice,
                      'isDefault': item.product!.defaultVariant!.isDefault,
                      'isActive': item.product!.defaultVariant!.isActive,
                      'sortOrder': item.product!.defaultVariant!.sortOrder,
                    },
                },
            },
          )
          .toList(growable: false),
    });
  }

  @override
  Future<List<ProductPlacement>> getMenuPlacements(
    int sectionId, {
    bool includeArchived = false,
  }) async {
    placementFetchCalls++;
    return List<ProductPlacement>.from(
      data[sectionId] ?? const <ProductPlacement>[],
    );
  }

  @override
  Future<ProductPlacement> createProductPlacement(
    int sectionId,
    ProductPlacementDraft draft,
  ) {
    createCalls++;
    if (conflictingProductIds.contains(draft.productId)) {
      return Future<ProductPlacement>.error(
        const ApiException(message: 'This product is already placed.'),
      );
    }
    if (failCreate || failedProductIds.contains(draft.productId)) {
      return Future<ProductPlacement>.error(
        const ApiException(
          message: 'Invalid.',
          validationErrors: <String, List<String>>{
            'productId': <String>['Unavailable.'],
          },
        ),
      );
    }
    if (createCompleter != null) return createCompleter!.future;
    final placement = ProductPlacement.fromJson(
      _placementJson(
        id: 100 + createCalls,
        sectionId: sectionId,
        productId: draft.productId!,
      ),
    );
    data[sectionId] = [...(data[sectionId] ?? const []), placement];
    return Future<ProductPlacement>.value(placement);
  }

  @override
  Future<ProductPlacement> updateProductPlacement(
    int placementId,
    ProductPlacementDraft draft,
  ) async {
    updateCalls++;
    return ProductPlacement.fromJson(_placementJson(id: placementId));
  }

  @override
  Future<ProductPlacement> moveProductPlacement(
    int placementId,
    int targetSectionId, {
    int? sortOrder,
  }) async {
    moveTargets.add(targetSectionId);
    return ProductPlacement.fromJson(
      _placementJson(id: placementId, sectionId: targetSectionId),
    );
  }

  @override
  Future<void> reorderSectionPlacements(
    int sectionId,
    List<PlacementReorderItem> items,
  ) async {
    reorderItems = items;
    if (failReorder) {
      throw const ApiException(message: 'Order rejected.');
    }
    final current = data[sectionId] ?? const <ProductPlacement>[];
    data[sectionId] = [
      for (final item in items)
        _placementWithSortOrder(
          current.firstWhere((placement) => placement.id == item.id),
          item.sortOrder,
        ),
    ];
  }

  @override
  Future<ProductPlacement> archiveProductPlacement(int placementId) async {
    archiveCalls++;
    return ProductPlacement.fromJson(
      _placementJson(id: placementId, archived: true),
    );
  }

  @override
  Future<ProductPlacement> restoreProductPlacement(int placementId) {
    restoreCalls++;
    if (failRestore) {
      return Future<ProductPlacement>.error(
        const ApiException(
          message: 'This product is already placed in this section.',
        ),
      );
    }
    return Future<ProductPlacement>.value(
      ProductPlacement.fromJson(_placementJson(id: placementId)),
    );
  }

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    productListCalls++;
    final query = filter.search.trim().toLowerCase();
    final products =
        <ProductSummary>[
          _pickerProduct(11, 'Espresso', 'إسبريسو'),
          _pickerProduct(12, 'Latte', 'لاتيه'),
          _pickerProduct(13, 'Cold Brew', 'قهوة باردة'),
          _pickerProduct(14, 'Archived', 'مؤرشف', archived: true),
          _pickerProduct(15, 'Inactive', 'غير نشط', active: false),
        ].where((product) {
          return query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              (product.nameAr ?? '').contains(filter.search.trim());
        }).toList();
    return CatalogPage<ProductSummary>(
      items: products,
      meta: CatalogPagination(
        currentPage: page,
        lastPage: 1,
        perPage: perPage,
        total: products.length,
      ),
    );
  }
}

class _BatchNinePlacementRepository extends _PlacementRepository {
  _BatchNinePlacementRepository() {
    data
      ..clear()
      ..addAll(<int, List<ProductPlacement>>{
        5: <ProductPlacement>[],
        6: <ProductPlacement>[
          _batchNinePlacement(id: 9, sectionId: 6, productId: 11),
          _batchNinePlacement(id: 10, sectionId: 6, productId: 12),
        ],
      });
  }

  final Completer<MenuRecord> refreshCompleter = Completer<MenuRecord>();

  @override
  Future<MenuRecord> getMenu(int menuId, {bool includeArchived = false}) {
    menuFetchCalls++;
    return menuFetchCalls == 1
        ? Future.value(menuSnapshot())
        : refreshCompleter.future;
  }

  MenuRecord menuSnapshot() => MenuRecord(
    id: 1,
    name: 'Main',
    nameAr: '',
    nameEn: 'Main',
    description: '',
    descriptionAr: '',
    descriptionEn: '',
    coverImageUrl: '',
    status: 'draft',
    priority: 0,
    sectionCount: 2,
    visibleProductCount: data.values.expand((items) => items).length,
    archivedAt: null,
    createdAt: null,
    updatedAt: null,
    sections: <MenuSectionRecord>[
      _batchNineSection(5, 'coffee', 0),
      _batchNineSection(6, 'rami', 1),
    ],
    placements: data.values.expand((items) => items).toList(growable: false),
  );

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async {
    productListCalls++;
    final query = filter.search.trim().toLowerCase();
    final products =
        <ProductSummary>[
              _batchNineProduct(11, 'Espresso'),
              _batchNineProduct(12, 'Almond Croissant'),
              _batchNineProduct(13, 'Latte'),
              _batchNineProduct(14, 'Cold Brew'),
            ]
            .where(
              (product) =>
                  query.isEmpty || product.name.toLowerCase().contains(query),
            )
            .toList();
    return CatalogPage<ProductSummary>(
      items: products,
      meta: CatalogPagination(
        currentPage: page,
        lastPage: 1,
        perPage: perPage,
        total: products.length,
      ),
    );
  }

  @override
  Future<ProductPlacement> createProductPlacement(
    int sectionId,
    ProductPlacementDraft draft,
  ) async {
    createCalls++;
    final productId = draft.productId!;
    final placement = _batchNinePlacement(
      id: 100 + createCalls,
      sectionId: sectionId,
      productId: productId,
      sortOrder: data[sectionId]?.length ?? 0,
    );
    data[sectionId] = <ProductPlacement>[
      ...(data[sectionId] ?? const <ProductPlacement>[]),
      placement,
    ];
    return placement;
  }
}

MenuSectionRecord _batchNineSection(int id, String name, int sortOrder) =>
    MenuSectionRecord(
      id: id,
      menuId: 1,
      name: name,
      nameAr: '',
      nameEn: name,
      description: '',
      imageUrl: '',
      isActive: true,
      sortOrder: sortOrder,
      placementCount: 0,
      archivedAt: null,
      createdAt: null,
      updatedAt: null,
    );

ProductPlacement _batchNinePlacement({
  required int id,
  required int sectionId,
  required int productId,
  int sortOrder = 0,
}) => ProductPlacement(
  id: id,
  sectionId: sectionId,
  productId: productId,
  sortOrder: sortOrder,
  isFeatured: false,
  isVisible: true,
  displayNameOverride: '',
  displayDescriptionOverride: '',
  displayImageOverride: '',
  archivedAt: null,
  createdAt: null,
  updatedAt: null,
  product: _batchNineProduct(productId, _batchNineProductName(productId)),
);

ProductSummary _batchNineProduct(int id, String name) => ProductSummary(
  id: id,
  name: name,
  nameAr: '',
  nameEn: name,
  description: '',
  imageUrl: '',
  productType: 'standard',
  isActive: true,
  category: null,
  reportingCategory: null,
  kitchenStation: null,
  defaultVariant: null,
  variantCount: 1,
  modifierGroupCount: 0,
  createdAt: null,
  updatedAt: null,
);

String _batchNineProductName(int id) => switch (id) {
  11 => 'Espresso',
  12 => 'Almond Croissant',
  13 => 'Latte',
  14 => 'Cold Brew',
  _ => 'Product $id',
};

ProductSummary _pickerProduct(
  int id,
  String name,
  String nameAr, {
  bool active = true,
  bool archived = false,
}) => ProductSummary.fromJson(<String, dynamic>{
  'id': id,
  'name': name,
  'nameEn': name,
  'nameAr': nameAr,
  'productType': 'standard',
  'isActive': active,
  'variantCount': 1,
  'modifierGroupCount': 0,
  'archivedAt': archived ? '2026-07-31T10:00:00Z' : null,
});

DioApiClient _client(Response<dynamic> Function(RequestOptions) responder) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(responder(options)),
    ),
  );
  return DioApiClient(dio: dio);
}

Map<String, dynamic> _placementJson({
  int id = 9,
  int sectionId = 5,
  int productId = 11,
  int sortOrder = 0,
  bool archived = false,
}) => <String, dynamic>{
  'id': id,
  'sectionId': sectionId,
  'productId': productId,
  'sortOrder': sortOrder,
  'isFeatured': false,
  'isVisible': true,
  'displayNameOverride': '',
  'displayDescriptionOverride': '',
  'displayImageOverride': '',
  'archivedAt': archived ? '2026-07-31T10:00:00Z' : null,
  'product': <String, dynamic>{
    'id': productId,
    'name': 'Product $productId',
    'productType': 'standard',
    'isActive': true,
    'archivedAt': null,
    'variantCount': 1,
    'modifierGroupCount': 0,
    'isStockTracked': false,
    'sortOrder': 0,
  },
};

ProductPlacement _placementWithSortOrder(
  ProductPlacement placement,
  int sortOrder,
) => ProductPlacement(
  id: placement.id,
  sectionId: placement.sectionId,
  productId: placement.productId,
  sortOrder: sortOrder,
  isFeatured: placement.isFeatured,
  isVisible: placement.isVisible,
  displayNameOverride: placement.displayNameOverride,
  displayDescriptionOverride: placement.displayDescriptionOverride,
  displayImageOverride: placement.displayImageOverride,
  archivedAt: placement.archivedAt,
  createdAt: placement.createdAt,
  updatedAt: placement.updatedAt,
  product: placement.product,
);

Map<String, dynamic> _menuJson({bool archived = false}) => <String, dynamic>{
  'id': 1,
  'name': 'Main',
  'nameEn': 'Main',
  'status': archived ? 'archived' : 'draft',
  'archivedAt': archived ? '2026-07-31T10:00:00Z' : null,
  'sections': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5,
      'menuId': 1,
      'name': 'Coffee',
      'isActive': true,
      'sortOrder': 0,
      'placementCount': 3,
    },
    <String, dynamic>{
      'id': 6,
      'menuId': 1,
      'name': 'Tea',
      'isActive': true,
      'sortOrder': 1,
      'placementCount': 0,
    },
    <String, dynamic>{
      'id': 7,
      'menuId': 1,
      'name': 'Archived',
      'isActive': true,
      'sortOrder': 2,
      'placementCount': 0,
      'archivedAt': '2026-07-31T10:00:00Z',
    },
    <String, dynamic>{
      'id': 8,
      'menuId': 2,
      'name': 'Foreign',
      'isActive': true,
      'sortOrder': 3,
      'placementCount': 0,
    },
  ],
};

Map<String, dynamic> _nestedCompositionMenuJson() => <String, dynamic>{
  'id': 1,
  'name': 'Main',
  'nameEn': 'Main',
  'status': 'draft',
  'sections': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5,
      'menuId': 1,
      'name': 'Section A',
      'nameEn': 'Section A',
      'isActive': true,
      'sortOrder': 0,
      // Deliberately inaccurate: composition must use embedded placements.
      'placementCount': 0,
      'placements': <Map<String, dynamic>>[
        _placementJson(id: 9, sectionId: 5, productId: 11, sortOrder: 0),
        _placementJson(id: 10, sectionId: 5, productId: 12, sortOrder: 1),
      ],
    },
    <String, dynamic>{
      'id': 6,
      'menuId': 1,
      'name': 'Section B',
      'nameEn': 'Section B',
      'isActive': true,
      'sortOrder': 1,
      'placementCount': 0,
      'placements': <Map<String, dynamic>>[
        _placementJson(id: 11, sectionId: 6, productId: 13, sortOrder: 0),
      ],
    },
  ],
};
