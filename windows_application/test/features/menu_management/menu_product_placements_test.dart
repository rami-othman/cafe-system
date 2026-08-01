import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
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
      'loads under authoritative sections, filters, and preserves the filter on refresh',
      () async {
        final _PlacementRepository repository = _PlacementRepository();
        final ProductPlacementsCubit cubit = ProductPlacementsCubit(
          repository: repository,
        );
        await cubit.load(1);
        expect(cubit.state.forSection(5).map((p) => p.id), <int>[9, 10]);
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
          home: BlocProvider<ProductPlacementsCubit>(
            create: (_) => ProductPlacementsCubit(repository: repository),
            child: const ProductPlacementsScreen(menuId: 1),
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
      expect(find.textContaining('Product archived'), findsOneWidget);
      expect(find.byTooltip('Move Up'), findsWidgets);
      expect(find.byTooltip('Move Down'), findsWidgets);
      expect(find.text('Branch'), findsNothing);
      expect(find.text('Price Override'), findsNothing);
      expect(find.text('Availability'), findsNothing);
      expect(find.text('Preview'), findsNothing);
      expect(find.text('Publish'), findsNothing);
      expect(find.text('Version'), findsNothing);
      await tester.tap(find.text('Add Product').first);
      await tester.pump();
      expect(find.text('Add Product'), findsWidgets);
    },
  );

  testWidgets('archived menus and archived sections are read-only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ProductPlacementsCubit>(
          create: (_) => ProductPlacementsCubit(
            repository: _PlacementRepository(archivedMenu: true),
          ),
          child: const ProductPlacementsScreen(menuId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('archived and read-only'), findsOneWidget);
    expect(find.text('Add Product'), findsNothing);
    expect(find.textContaining('This section is archived'), findsOneWidget);
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
  int createCalls = 0, updateCalls = 0, archiveCalls = 0, restoreCalls = 0;
  final List<int> moveTargets = <int>[];
  List<PlacementReorderItem> reorderItems = <PlacementReorderItem>[];
  bool failCreate = false, failReorder = false, failRestore = false;
  Completer<ProductPlacement>? createCompleter;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<MenuRecord> getMenu(
    int menuId, {
    bool includeArchived = false,
  }) async => MenuRecord.fromJson(_menuJson(archived: archivedMenu));
  @override
  Future<List<ProductPlacement>> getMenuPlacements(
    int sectionId, {
    bool includeArchived = false,
  }) async => List<ProductPlacement>.from(
    data[sectionId] ?? const <ProductPlacement>[],
  );
  @override
  Future<ProductPlacement> createProductPlacement(
    int sectionId,
    ProductPlacementDraft draft,
  ) {
    createCalls++;
    if (failCreate) {
      return Future<ProductPlacement>.error(
        const ApiException(
          message: 'Invalid.',
          validationErrors: <String, List<String>>{
            'productId': <String>['Unavailable.'],
          },
        ),
      );
    }
    return createCompleter?.future ??
        Future<ProductPlacement>.value(
          ProductPlacement.fromJson(
            _placementJson(
              id: 13,
              sectionId: sectionId,
              productId: draft.productId!,
            ),
          ),
        );
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
  }) => throw UnimplementedError();
}

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
