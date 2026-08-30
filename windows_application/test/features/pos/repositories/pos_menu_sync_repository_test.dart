import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/pos/models/create_order_request.dart';
import 'package:windows_application/features/pos/models/order_type.dart';
import 'package:windows_application/features/pos/models/pos_menu_runtime_models.dart';
import 'package:windows_application/features/pos/models/pos_published_menu_presenter.dart';
import 'package:windows_application/features/pos/models/pos_menu_sync_result.dart';
import 'package:windows_application/features/pos/controllers/pos_menu_sync_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_menu_sync_state.dart';
import 'package:windows_application/features/pos/repositories/pos_menu_sync_cache.dart';
import 'package:windows_application/features/pos/repositories/pos_menu_sync_repository.dart';

void main() {
  group('POS runtime DTO', () {
    test('preserves published order, localization, money, and constraints', () {
      final PosMenuSyncResponse response = PosMenuSyncResponse.fromJson(
        _newVersionResponse(),
      );

      expect(response.menu!.menus.map((PosStaticMenu item) => item.id), <int>[
        10,
        11,
      ]);
      final placement =
          response.menu!.menus.first.sections.first.products.first;
      expect(placement.placementId, 40);
      expect(placement.productId, 25);
      expect(placement.name.resolve('ar'), 'لاتيه');
      expect(placement.variants.single.effectivePrice, 4.5);
      expect(placement.modifierGroups.single.minSelections, 1);
      expect(placement.modifierGroups.single.options.single.priceDelta, 0.5);
    });

    test(
      'published presenter preserves menu, section, and placement order',
      () {
        final PosMenuSyncResponse response = PosMenuSyncResponse.fromJson(
          _newVersionResponse(),
        );
        final PosPublishedMenuPresenter presenter = PosPublishedMenuPresenter(
          PosPublishedRuntimeMenu(
            context: response.context,
            version: response.version!,
            menu: response.menu!,
            runtime: response.runtime,
          ),
          languageCode: 'en',
        );

        expect(presenter.menus.map((PosStaticMenu menu) => menu.id), <int>[
          10,
          11,
        ]);
        expect(
          presenter.menus.first.sections.map(
            (PosStaticSection section) => section.id,
          ),
          <int>[20],
        );
        final products = presenter.productsForMenu(presenter.menus.first);
        expect(products.single.placementId, 40);
        expect(products.single.backendId, 25);
        expect(products.single.defaultVariantId, 30);
        expect(products.single.price, 4.5);
      },
    );

    test('rejects a future runtime contract without parsing it as v1', () {
      final Map<String, dynamic> response = _newVersionResponse();
      (response['version'] as Map<String, dynamic>)['runtimeContractVersion'] =
          2;

      expect(
        () => PosMenuSyncResponse.fromJson(response),
        throwsA(isA<PosMenuContractException>()),
      );
    });
  });

  group('POS menu sync repository', () {
    late MemoryPosMenuSyncCache cache;
    late _SyncApiClient api;
    late PosMenuSyncRepository repository;

    setUp(() {
      cache = MemoryPosMenuSyncCache();
      api = _SyncApiClient(<Object?>[]);
      repository = PosMenuSyncRepository(apiClient: api, cache: cache);
    });

    test(
      'caches a new version and merges fresh runtime by placement identity',
      () async {
        api.responses.add(_newVersionResponse());

        final PosMenuSyncResult result = await repository.sync(branchId: 1);

        expect(result, isA<PosMenuSyncUpdated>());
        final updated = result as PosMenuSyncUpdated;
        expect(updated.menu.version.id, 12);
        expect(updated.menu.runtimeForPlacement(40)!.isSellable, isTrue);
        expect(
          updated.menu
              .runtimeForVariant(placementId: 40, variantId: 30)!
              .isSellable,
          isTrue,
        );
        expect(api.queries.single['knownVersionId'], isNull);
      },
    );

    test(
      'uses cached static projection for up-to-date response and fresh sold-out runtime',
      () async {
        api.responses.addAll(<Object?>[
          _newVersionResponse(),
          _upToDateResponse(sellable: false),
        ]);
        await repository.sync(branchId: 1);

        final PosMenuSyncResult result = await repository.sync(branchId: 1);

        expect(result, isA<PosMenuSyncUpToDate>());
        final current = result as PosMenuSyncUpToDate;
        expect(
          current
              .menu
              .menu
              .menus
              .first
              .sections
              .first
              .products
              .first
              .placementId,
          40,
        );
        expect(current.menu.runtimeForPlacement(40)!.isSellable, isFalse);
        expect(api.queries.last['knownVersionId'], 12);
      },
    );

    test(
      'retries once without known version when up-to-date cache is missing',
      () async {
        api.responses.addAll(<Object?>[
          _upToDateResponse(),
          _newVersionResponse(),
        ]);

        final PosMenuSyncResult result = await repository.sync(branchId: 1);

        expect(result, isA<PosMenuSyncUpdated>());
        expect(api.queries, hasLength(2));
        expect(
          api.queries.every(
            (Map<String, dynamic> query) =>
                !query.containsKey('knownVersionId'),
          ),
          isTrue,
        );
      },
    );

    test(
      'does not share a branch cache and represents no publication explicitly',
      () async {
        api.responses.addAll(<Object?>[
          _newVersionResponse(),
          _noPublicationResponse(2),
        ]);
        await repository.sync(branchId: 1);

        final PosMenuSyncResult branchTwo = await repository.sync(branchId: 2);

        expect(branchTwo, isA<PosMenuSyncNoPublication>());
        expect(api.queries.last['branchId'], 2);
        expect(api.queries.last.containsKey('knownVersionId'), isFalse);
      },
    );

    test('keeps usable cache available after network failure', () async {
      api.responses.addAll(<Object?>[
        _newVersionResponse(),
        const ApiException(message: 'offline'),
      ]);
      await repository.sync(branchId: 1);

      final PosMenuSyncResult result = await repository.sync(branchId: 1);

      expect(result, isA<PosMenuSyncUsingCachedAfterFailure>());
      expect(
        (result as PosMenuSyncUsingCachedAfterFailure).menu.version.id,
        12,
      );
    });

    test(
      'does not overwrite a valid cache after malformed newer data',
      () async {
        final Map<String, dynamic> invalid = _newVersionResponse(versionId: 13);
        (invalid['version'] as Map<String, dynamic>)['runtimeContractVersion'] =
            2;
        api.responses.addAll(<Object?>[
          _newVersionResponse(),
          invalid,
          _upToDateResponse(),
        ]);
        await repository.sync(branchId: 1);

        final PosMenuSyncResult failed = await repository.sync(branchId: 1);
        final PosMenuSyncResult recovered = await repository.sync(branchId: 1);

        expect(failed, isA<PosMenuSyncUsingCachedAfterFailure>());
        expect(recovered, isA<PosMenuSyncUpToDate>());
        expect((recovered as PosMenuSyncUpToDate).menu.version.id, 12);
      },
    );
  });

  group('POS menu offline runtime', () {
    late MemoryPosMenuSyncCache cache;
    late _SyncApiClient api;
    late PosMenuSyncRepository repository;

    setUp(() {
      cache = MemoryPosMenuSyncCache();
      api = _SyncApiClient(<Object?>[]);
      repository = PosMenuSyncRepository(apiClient: api, cache: cache);
    });

    test(
      'a cached menu refresh does not disable checkout before a failure exists',
      () {
        expect(
          const PosMenuSyncState(
            status: PosMenuSyncStatus.syncingWithUsableCache,
          ).isBackendReachable,
          isTrue,
        );
      },
    );

    test(
      'keeps active version and stages newest version while cart is active',
      () async {
        api.responses.addAll(<Object?>[
          _newVersionResponse(versionId: 12),
          _newVersionResponse(versionId: 13),
          _newVersionResponse(versionId: 14),
        ]);
        final PosMenuSyncCubit cubit = PosMenuSyncCubit(repository: repository);
        addTearDown(cubit.close);

        await cubit.sync(1, hasActiveCart: false);
        await cubit.sync(1, hasActiveCart: true);
        await cubit.sync(1, hasActiveCart: true);

        expect(cubit.state.status, PosMenuSyncStatus.pendingVersion);
        expect(cubit.state.activeVersionId, 12);
        expect(cubit.state.pendingVersionId, 14);

        cubit.activatePendingIfSafe(hasActiveCart: false);
        expect(cubit.state.status, PosMenuSyncStatus.onlineFresh);
        expect(cubit.state.activeVersionId, 14);
        expect(cubit.state.pendingMenu, isNull);
      },
    );

    test(
      'keeps cached menu usable and marks network loss explicitly',
      () async {
        api.responses.add(_newVersionResponse());
        await repository.sync(branchId: 1);
        api.responses.add(const ApiException(message: 'offline'));
        final PosMenuSyncCubit cubit = PosMenuSyncCubit(repository: repository);
        addTearDown(cubit.close);

        await cubit.sync(1, hasActiveCart: false);

        expect(cubit.state.status, PosMenuSyncStatus.offlineUsingCache);
        expect(cubit.state.activeVersionId, 12);
        expect(cubit.state.isBackendReachable, isFalse);
      },
    );
  });

  test(
    'file cache round-trip preserves published order and static scope',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'cafe618-pos-menu-cache-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final PosMenuCacheScope scope = const PosMenuCacheScope(
        tenantIdentity: 'tenant-test',
        branchId: 1,
      );
      final PosMenuSyncResponse response = PosMenuSyncResponse.fromJson(
        _newVersionResponse(),
      );
      final FilePosMenuSyncCache cache = FilePosMenuSyncCache(
        directoryProvider: () async => directory,
      );

      await cache.write(
        PosCachedMenu(
          scope: scope,
          context: response.context,
          version: response.version!,
          menu: response.menu!,
          syncedAt: DateTime.utc(2026, 8, 29),
          runtime: response.runtime,
        ),
      );
      final PosCachedMenu? restored = await cache.read(scope);

      expect(restored, isNotNull);
      expect(restored!.menu.menus.map((PosStaticMenu item) => item.id), <int>[
        10,
        11,
      ]);
      expect(restored.version.id, 12);
      expect(restored.runtime?.placements.single.isSellable, isTrue);
    },
  );

  group('snapshot-aware order serialization', () {
    test('sends published identities and no client price', () {
      final Map<String, dynamic> json = CreateOrderRequest(
        branchId: 1,
        orderType: OrderType.takeaway,
        publishedMenuVersionId: 12,
        items: const <AddOrderItemRequest>[
          AddOrderItemRequest(
            productId: 25,
            placementId: 40,
            variantId: 30,
            modifierOptionIds: <int>[71],
            quantity: 2,
          ),
        ],
      ).toJson();

      expect(json['publishedMenuVersionId'], 12);
      expect(json['items'], <Map<String, dynamic>>[
        <String, dynamic>{
          'productId': 25,
          'quantity': 2,
          'modifiers': <Object?>[],
          'placementId': 40,
          'variantId': 30,
          'modifierOptionIds': <int>[71],
        },
      ]);
      expect((json['items'] as List).single.containsKey('price'), isFalse);
    });

    test('keeps the legacy request shape when no snapshot identity exists', () {
      final Map<String, dynamic> json = CreateOrderRequest(
        branchId: 1,
        orderType: OrderType.dineIn,
        items: const <AddOrderItemRequest>[
          AddOrderItemRequest(productId: 25, quantity: 1),
        ],
      ).toJson();

      expect(json.containsKey('publishedMenuVersionId'), isFalse);
      final Map<String, dynamic> item =
          (json['items'] as List).single as Map<String, dynamic>;
      expect(item.containsKey('placementId'), isFalse);
      expect(item.containsKey('variantId'), isFalse);
      expect(item.containsKey('modifierOptionIds'), isFalse);
    });
  });
}

class _SyncApiClient extends DioApiClient {
  _SyncApiClient(this.responses) : super(dio: Dio());

  final List<Object?> responses;
  final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    expect(path, 'pos/menu-sync');
    queries.add(Map<String, dynamic>.from(queryParameters!));
    final Object? response = responses.removeAt(0);
    if (response is Exception) throw response;
    return response;
  }
}

Map<String, dynamic> _newVersionResponse({int versionId = 12}) =>
    <String, dynamic>{
      'context': _context(1),
      'upToDate': false,
      'version': _version(versionId),
      'menu': <String, dynamic>{
        'menus': <Object?>[
          <String, dynamic>{
            'id': 10,
            'scopeOrder': 0,
            'name': _text('Breakfast'),
            'description': _text('Morning menu'),
            'coverImageUrl': null,
            'sections': <Object?>[
              <String, dynamic>{
                'id': 20,
                'name': _text('Coffee'),
                'description': _text(null),
                'imageUrl': null,
                'sortOrder': 0,
                'products': <Object?>[_placement()],
              },
            ],
          },
          <String, dynamic>{
            'id': 11,
            'scopeOrder': 1,
            'name': _text('Afternoon'),
            'description': _text(null),
            'coverImageUrl': null,
            'sections': <Object?>[],
          },
        ],
      },
      'runtime': _runtime(),
    };

Map<String, dynamic> _upToDateResponse({bool sellable = true}) =>
    <String, dynamic>{
      'context': _context(1),
      'upToDate': true,
      'version': _version(12),
      'menu': null,
      'runtime': _runtime(sellable: sellable),
    };

Map<String, dynamic> _noPublicationResponse(int branchId) => <String, dynamic>{
  'context': _context(branchId),
  'upToDate': false,
  'version': null,
  'menu': null,
  'runtime': null,
};

Map<String, dynamic> _context(int branchId) => <String, dynamic>{
  'branchId': branchId,
  'channel': 'pos',
  'timezone': 'Asia/Damascus',
  'currency': 'SYP',
};

Map<String, dynamic> _version(int id) => <String, dynamic>{
  'id': id,
  'versionNumber': id,
  'publishedAt': '2026-08-29T10:00:00+03:00',
  'sourceSchemaVersion': 3,
  'runtimeContractVersion': 1,
};

Map<String, dynamic> _text(String? value) => <String, dynamic>{
  'default': value,
  'ar': value == 'Latte' ? 'لاتيه' : null,
  'en': value,
};

Map<String, dynamic> _placement() => <String, dynamic>{
  'placementId': 40,
  'productId': 25,
  'name': _text('Latte'),
  'description': _text('Published only'),
  'imageUrl': null,
  'sortOrder': 0,
  'isFeatured': false,
  'isVisible': true,
  'variants': <Object?>[
    <String, dynamic>{
      'id': 30,
      'name': _text('Regular'),
      'sku': 'LATTE-R',
      'barcode': null,
      'sortOrder': 0,
      'isDefault': true,
      'basePrice': '4.00',
      'effectivePrice': '4.50',
    },
  ],
  'modifierGroups': <Object?>[
    <String, dynamic>{
      'id': 70,
      'name': _text('Milk'),
      'selectionType': 'multiple',
      'isRequired': true,
      'minSelections': 1,
      'maxSelections': 1,
      'allowQuantity': false,
      'sortOrder': 0,
      'options': <Object?>[
        <String, dynamic>{
          'id': 71,
          'name': _text('Oat'),
          'priceDelta': '0.50',
          'isDefault': false,
          'isAvailable': true,
          'sortOrder': 0,
        },
      ],
    },
  ],
};

Map<String, dynamic> _runtime({bool sellable = true}) => <String, dynamic>{
  'evaluatedAt': '2026-08-29T10:01:00+03:00',
  'menus': <Object?>[
    <String, dynamic>{
      'menuId': 10,
      'isScheduledAvailable': true,
      'reason': 'matched_rule',
    },
  ],
  'placements': <Object?>[
    <String, dynamic>{
      'placementId': 40,
      'productId': 25,
      'isScheduledAvailable': true,
      'isOperationallyAvailable': sellable,
      'isSellable': sellable,
      'reason': sellable ? null : 'sold_out',
    },
  ],
  'variants': <Object?>[
    <String, dynamic>{
      'placementId': 40,
      'productId': 25,
      'variantId': 30,
      'isScheduledAvailable': true,
      'isOperationallyAvailable': sellable,
      'isSellable': sellable,
      'reason': sellable ? null : 'sold_out',
      'operationalStatus': sellable ? 'available' : 'sold_out',
      'remainingQuantity': null,
      'unavailableUntil': null,
    },
  ],
};
