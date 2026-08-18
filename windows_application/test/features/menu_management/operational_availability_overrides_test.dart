import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/operational_availability/controllers/operational_availability_cubit.dart';
import 'package:windows_application/features/menu_management/operational_availability/controllers/operational_availability_state.dart';
import 'package:windows_application/features/menu_management/operational_availability/models/operational_availability_models.dart';
import 'package:windows_application/features/menu_management/operational_availability/views/operational_availability_screen.dart';
import 'package:windows_application/features/menu_management/operational_availability/widgets/clear_operational_override_dialog.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  group('Operational availability contracts', () {
    test(
      'parses product and variant records including an expired temporary row',
      () {
        final OperationalAvailabilityOverride item =
            OperationalAvailabilityOverride.fromJson(<String, dynamic>{
              'id': 7,
              'level': 'variant',
              'productId': 11,
              'productVariantId': 12,
              'branch': <String, dynamic>{
                'id': 1,
                'name': 'Main',
                'timezone': 'Asia/Damascus',
              },
              'channel': 'all',
              'status': 'temporarily_unavailable',
              'remainingQuantity': 0,
              'unavailableUntil': '2026-01-01T10:00:00+03:00',
              'reason': 'Machine service',
              'isExpired': true,
            });
        expect(item.level, OperationalAvailabilityLevel.variant);
        expect(
          item.status,
          OperationalAvailabilityStatus.temporarilyUnavailable,
        );
        expect(item.scopeKey, 'branch:1|channel:all');
        expect(item.isTemporary, isTrue);
        expect(item.isExpired, isTrue);
        expect(item.remainingQuantity, 0);
        // API returns a Branch-local offset, which must not be converted to
        // the workstation wall clock before an edit/save round-trip.
        expect(item.unavailableUntil, DateTime(2026, 1, 1, 10));
      },
    );

    test(
      'serializes only supported mutation fields and keeps Available explicit',
      () {
        final Map<String, dynamic> available =
            const OperationalAvailabilityDraft(
              branchId: 1,
              channel: 'pos',
              status: OperationalAvailabilityStatus.available,
              remainingQuantity: 0,
              unavailableUntil: null,
              reason: 'ignored',
            ).toJson();
        expect(available, <String, dynamic>{
          'branchId': 1,
          'channel': 'pos',
          'status': 'available',
          'remainingQuantity': 0,
        });
        final Map<String, dynamic> temporary = OperationalAvailabilityDraft(
          branchId: 1,
          channel: 'all',
          status: OperationalAvailabilityStatus.temporarilyUnavailable,
          unavailableUntil: DateTime.parse('2026-08-04T10:30:00'),
        ).toJson();
        expect(temporary['unavailableUntil'], isNotNull);
        expect(temporary['unavailableUntil'], '2026-08-04T10:30:00');
        expect(temporary.containsKey('tenantId'), isFalse);
        expect(temporary.containsKey('isExpired'), isFalse);
        expect(temporary.containsKey('productVariantId'), isFalse);
        expect(
          OperationalAvailabilityDraft(
            branchId: 1,
            channel: 'pos',
            status: OperationalAvailabilityStatus.soldOut,
            unavailableUntil: null,
          ).toJson().containsKey('unavailableUntil'),
          isFalse,
        );
        expect(
          () => const OperationalAvailabilityDraft(
            branchId: null,
            channel: 'all',
            status: OperationalAvailabilityStatus.soldOut,
          ).toJson(),
          throwsFormatException,
        );
        expect(
          () => const OperationalAvailabilityDraft(
            branchId: 1,
            channel: 'global',
            status: OperationalAvailabilityStatus.soldOut,
          ).toJson(),
          throwsFormatException,
        );
      },
    );

    test(
      'parses authoritative fallback, explicit Available, source scope, quantity, and expiration',
      () {
        OperationalAvailabilityPreview preview({
          required String status,
          String? level,
          String? scope,
          int? recordId,
          String? until,
        }) => OperationalAvailabilityPreview.fromJson(<String, dynamic>{
          'productId': 11,
          'productVariantId': level == 'variant' ? 12 : null,
          'branchId': 1,
          'channel': 'delivery',
          'isOperationallyAvailable': status == 'available',
          'status': status,
          'matchedLevel': level,
          'matchedScope': scope,
          'matchedRecordId': recordId,
          'remainingQuantity': 2.5,
          'unavailableUntil': until,
          'reason': level == null ? 'no_operational_override' : 'Staff update',
        });

        final OperationalAvailabilityPreview fallback = preview(
          status: 'available',
        );
        final OperationalAvailabilityPreview exactAvailable = preview(
          status: 'available',
          level: 'variant',
          scope: 'exact_channel',
          recordId: 9,
        );
        final OperationalAvailabilityPreview productAll = preview(
          status: 'sold_out',
          level: 'product',
          scope: 'all_channels',
          recordId: 4,
        );
        final OperationalAvailabilityPreview temporary = preview(
          status: 'temporarily_unavailable',
          level: 'variant',
          scope: 'all_channels',
          recordId: 5,
          until: '2030-01-01T10:00:00+03:00',
        );
        expect(fallback.isFallback, isTrue);
        expect(exactAvailable.isExplicitAvailable, isTrue);
        expect(productAll.matchedScope, 'all_channels');
        expect(productAll.status, OperationalAvailabilityStatus.soldOut);
        expect(temporary.isTemporary, isTrue);
        expect(temporary.unavailableUntil, isNotNull);
        expect(temporary.remainingQuantity, 2.5);
      },
    );
  });

  group('OperationalAvailabilityCubit', () {
    test(
      'loads product and selected Variant overrides, then filters scope',
      () async {
        final _OperationalRepository repository = _OperationalRepository();
        final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
          repository: repository,
        );
        await cubit.load(11, variantId: 12);
        expect(cubit.state.status, OperationalAvailabilityLoadStatus.loaded);
        expect(cubit.state.productOverrides, hasLength(1));
        expect(cubit.state.variantOverrides, hasLength(1));
        cubit.selectScope(branchId: 1, channel: 'pos');
        expect(cubit.state.visibleProductOverrides, hasLength(1));
        expect(cubit.state.visibleVariantOverrides, hasLength(1));
        await cubit.close();
      },
    );

    test(
      'invalid route context is ignored while valid scope survives refresh',
      () async {
        final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
          repository: _OperationalRepository(),
        );
        await cubit.load(
          11,
          variantId: 999,
          branchId: 999,
          channel: 'not-a-sales-channel',
        );
        expect(cubit.state.selectedVariantId, isNull);
        expect(cubit.state.selectedBranchId, isNull);
        expect(cubit.state.selectedChannel, isNull);

        await cubit.selectVariant(12);
        cubit.selectScope(branchId: 1, channel: 'pos');
        await cubit.refresh();
        expect(cubit.state.selectedVariantId, 12);
        expect(cubit.state.selectedBranchId, 1);
        expect(cubit.state.selectedChannel, 'pos');
        await cubit.close();
      },
    );

    test(
      'upserts Product, clears only its selected scope, and preserves quantity metadata',
      () async {
        final _OperationalRepository repository = _OperationalRepository();
        final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
          repository: repository,
        );
        await cubit.load(11);
        const OperationalAvailabilityDraft draft = OperationalAvailabilityDraft(
          branchId: 1,
          channel: 'delivery',
          status: OperationalAvailabilityStatus.soldOut,
          remainingQuantity: 0,
          reason: 'No milk',
        );
        expect(await cubit.upsertProduct(draft), isTrue);
        expect(repository.productUpsert?.toJson()['remainingQuantity'], 0);
        expect(repository.productUpsert?.toJson()['status'], 'sold_out');
        await cubit.clearProduct(cubit.state.productOverrides.single);
        expect(repository.clearedProduct, <Object?>[11, 1, 'delivery']);
        await cubit.close();
      },
    );

    test(
      'prevents duplicate scopes, rejects negative quantity, and maps Laravel errors',
      () async {
        final _OperationalRepository repository = _OperationalRepository();
        final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
          repository: repository,
        );
        await cubit.load(11);
        expect(
          await cubit.upsertProduct(
            const OperationalAvailabilityDraft(
              branchId: 1,
              channel: 'all',
              status: OperationalAvailabilityStatus.soldOut,
            ),
          ),
          isFalse,
        );
        expect(cubit.state.fieldErrors['editor'], contains('already exists'));
        expect(
          await cubit.upsertProduct(
            const OperationalAvailabilityDraft(
              branchId: 1,
              channel: 'pos',
              status: OperationalAvailabilityStatus.soldOut,
              remainingQuantity: -1,
            ),
          ),
          isFalse,
        );
        expect(cubit.state.fieldErrors['editor'], contains('zero or greater'));
        repository.failUpsert = true;
        expect(
          await cubit.upsertProduct(
            const OperationalAvailabilityDraft(
              branchId: 1,
              channel: 'delivery',
              status: OperationalAvailabilityStatus.soldOut,
            ),
          ),
          isFalse,
        );
        expect(
          cubit.state.fieldErrors['remainingQuantity'],
          'Remaining quantity is invalid.',
        );
        expect(cubit.state.productOverrides, isNotEmpty);
        await cubit.close();
      },
    );

    test(
      'edits and clears Variant records without affecting Product scope',
      () async {
        final _OperationalRepository repository = _OperationalRepository();
        final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
          repository: repository,
        );
        await cubit.load(11, variantId: 12);
        final OperationalAvailabilityOverride original =
            cubit.state.variantOverrides.single;
        expect(
          await cubit.upsertVariant(
            OperationalAvailabilityDraft(
              branchId: 1,
              channel: 'pos',
              status: OperationalAvailabilityStatus.temporarilyUnavailable,
              unavailableUntil: DateTime(2030, 1, 1),
            ),
            replacingScopeKey: original.scopeKey,
          ),
          isTrue,
        );
        expect(
          cubit.state.variantOverrides.single.status,
          OperationalAvailabilityStatus.temporarilyUnavailable,
        );
        expect(
          cubit.state.productOverrides.single.status,
          OperationalAvailabilityStatus.soldOut,
        );
        expect(
          await cubit.clearVariant(cubit.state.variantOverrides.single),
          isTrue,
        );
        expect(repository.clearedVariant, <Object?>[12, 1, 'pos']);
        expect(cubit.state.productOverrides, isNotEmpty);
        await cubit.close();
      },
    );

    test(
      'clear failure preserves the returned row and stale archive reloads safely',
      () async {
        final _OperationalRepository repository = _OperationalRepository()
          ..failClear = true;
        final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
          repository: repository,
        );
        await cubit.load(11);
        final OperationalAvailabilityOverride row =
            cubit.state.productOverrides.single;
        expect(await cubit.clearProduct(row), isFalse);
        expect(cubit.state.productOverrides, contains(row));

        repository.failClear = false;
        repository.failUpsertNotFound = true;
        expect(
          await cubit.upsertProduct(
            const OperationalAvailabilityDraft(
              branchId: 1,
              channel: 'delivery',
              status: OperationalAvailabilityStatus.soldOut,
            ),
          ),
          isFalse,
        );
        expect(cubit.state.canMutateProduct, isFalse);
        expect(cubit.state.errorMessage, contains('no longer active'));
        await cubit.close();
      },
    );

    test('stale Variant loads and conflicting actions are ignored', () async {
      final _OperationalRepository repository = _OperationalRepository();
      final Completer<List<OperationalAvailabilityOverride>> first =
          Completer<List<OperationalAvailabilityOverride>>();
      final Completer<List<OperationalAvailabilityOverride>> second =
          Completer<List<OperationalAvailabilityOverride>>();
      repository.variantLoader = (int variantId) =>
          variantId == 12 ? first.future : second.future;
      final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
        repository: repository,
      );
      await cubit.load(11);
      final Future<void> old = cubit.selectVariant(12);
      final Future<void> current = cubit.selectVariant(13);
      second.complete(<OperationalAvailabilityOverride>[
        _row(
          const OperationalAvailabilityDraft(
            branchId: 1,
            channel: 'pos',
            status: OperationalAvailabilityStatus.available,
          ),
          OperationalAvailabilityLevel.variant,
          variantId: 13,
        ),
      ]);
      await current;
      first.complete(<OperationalAvailabilityOverride>[_variantRow()]);
      await old;
      expect(cubit.state.selectedVariantId, 13);
      expect(cubit.state.variantOverrides.single.productVariantId, 13);

      final Completer<void> mutation = Completer<void>();
      repository.upsertGate = mutation;
      final Future<bool> saving = cubit.upsertProduct(
        const OperationalAvailabilityDraft(
          branchId: 1,
          channel: 'delivery',
          status: OperationalAvailabilityStatus.soldOut,
        ),
      );
      expect(cubit.state.isMutating, isTrue);
      expect(
        await cubit.clearProduct(cubit.state.productOverrides.single),
        isFalse,
      );
      mutation.complete();
      expect(await saving, isTrue);
      await cubit.close();
    });

    test(
      'archived Product is read-only while archived Variant leaves Product editable',
      () async {
        final _OperationalRepository productArchived = _OperationalRepository()
          ..productArchived = true;
        final OperationalAvailabilityCubit first = OperationalAvailabilityCubit(
          repository: productArchived,
        );
        await first.load(11, variantId: 12);
        expect(first.state.canMutateProduct, isFalse);
        expect(first.state.canMutateVariant, isFalse);
        await first.close();

        final _OperationalRepository variantArchived = _OperationalRepository()
          ..variantArchived = true;
        final OperationalAvailabilityCubit second =
            OperationalAvailabilityCubit(repository: variantArchived);
        await second.load(11, variantId: 12);
        expect(second.state.canMutateProduct, isTrue);
        expect(second.state.canMutateVariant, isFalse);
        await second.close();
      },
    );

    test(
      'uses authoritative previews, ignores stale responses, and retries without losing override rows',
      () async {
        final _OperationalRepository repository = _OperationalRepository();
        final OperationalAvailabilityCubit cubit = OperationalAvailabilityCubit(
          repository: repository,
        );
        await cubit.load(11);
        final Completer<OperationalAvailabilityPreview> old =
            Completer<OperationalAvailabilityPreview>();
        final Completer<OperationalAvailabilityPreview> current =
            Completer<OperationalAvailabilityPreview>();
        repository.previewLoader = (_, branchId, channel) =>
            channel == 'delivery' ? old.future : current.future;

        final Future<void> first = cubit.selectScope(
          branchId: 1,
          channel: 'delivery',
        );
        final Future<void> second = cubit.selectScope(
          branchId: 1,
          channel: 'kiosk',
        );
        current.complete(_preview(11, null, 1, 'kiosk'));
        await second;
        old.complete(_preview(11, null, 1, 'delivery'));
        await first;
        expect(cubit.state.preview?.channel, 'kiosk');

        repository.previewLoader = (_, _, _) =>
            Future<OperationalAvailabilityPreview>.error(
              const ApiException(message: 'timeout'),
            );
        await cubit.selectScope(branchId: 1, channel: 'pos');
        expect(
          cubit.state.previewStatus,
          OperationalAvailabilityPreviewStatus.failure,
        );
        expect(cubit.state.productOverrides, isNotEmpty);
        repository.previewLoader = (_, branchId, channel) =>
            Future<OperationalAvailabilityPreview>.value(
              _preview(11, null, branchId, channel),
            );
        await cubit.retryPreview();
        expect(
          cubit.state.previewStatus,
          OperationalAvailabilityPreviewStatus.loaded,
        );
        await cubit.close();
      },
    );
  });

  testWidgets(
    'screen renders product and Variant sections plus operational metadata',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey<String>('archived-operational-screen'),
          home: BlocProvider<OperationalAvailabilityCubit>(
            create: (_) => OperationalAvailabilityCubit(
              repository: _OperationalRepository(),
            ),
            child: const OperationalAvailabilityScreen(
              productId: 11,
              variantId: 12,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Operational Availability'), findsOneWidget);
      expect(find.text('Product Overrides'), findsOneWidget);
      expect(find.text('Variant Overrides'), findsOneWidget);
      expect(
        find.textContaining('Remaining quantity is operational metadata'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const Key('add-product-operational-override')),
      );
      await tester.tap(
        find.byKey(const Key('add-product-operational-override')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Remaining quantity is operational metadata'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('operational-override-status')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'expired diagnostics, exact clear scope, and archived controls render safely',
    (WidgetTester tester) async {
      final _OperationalRepository repository = _OperationalRepository()
        ..productRows = <OperationalAvailabilityOverride>[
          _row(
            OperationalAvailabilityDraft(
              branchId: 1,
              channel: 'all',
              status: OperationalAvailabilityStatus.temporarilyUnavailable,
              unavailableUntil: DateTime(2020),
            ),
            OperationalAvailabilityLevel.product,
            isExpired: true,
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OperationalAvailabilityCubit>(
            create: (_) => OperationalAvailabilityCubit(repository: repository),
            child: const OperationalAvailabilityScreen(productId: 11),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Temporary'), findsOneWidget);
      final Future<bool?> confirmation = showClearOperationalOverrideDialog(
        tester.element(find.byType(OperationalAvailabilityScreen)),
        override: repository.productRows.single,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('product override for Main · All channels'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await confirmation;

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey<String>('archived-operational-state'),
          home: BlocProvider<OperationalAvailabilityCubit>(
            create: (_) => OperationalAvailabilityCubit(
              repository: _OperationalRepository()..productArchived = true,
            ),
            child: const OperationalAvailabilityScreen(
              productId: 11,
              variantId: 12,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('This Product is archived'), findsOneWidget);
      expect(find.textContaining('Inventory'), findsNothing);
      expect(find.textContaining('Published Versions'), findsNothing);
    },
  );
}

class _OperationalRepository extends MenuCatalogRepository {
  bool productArchived = false;
  bool variantArchived = false;
  bool failUpsert = false;
  bool failUpsertNotFound = false;
  bool failClear = false;
  Future<List<OperationalAvailabilityOverride>> Function(int variantId)?
  variantLoader;
  Completer<void>? upsertGate;
  Future<OperationalAvailabilityPreview> Function(
    int? variantId,
    int branchId,
    String channel,
  )?
  previewLoader;
  OperationalAvailabilityDraft? productUpsert;
  List<Object?>? clearedProduct;
  List<Object?>? clearedVariant;
  List<OperationalAvailabilityOverride> productRows =
      <OperationalAvailabilityOverride>[_productRow()];
  List<OperationalAvailabilityOverride> variantRows =
      <OperationalAvailabilityOverride>[_variantRow()];

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async => throw UnimplementedError();

  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) async => throw UnimplementedError();

  @override
  Future<CatalogPage<CatalogCategory>> listCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) async => throw UnimplementedError();

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => _product(productArchived, variantArchived);
  @override
  Future<List<Branch>> listAssignmentBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Main',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];
  @override
  Future<List<OperationalAvailabilityOverride>> listProductOperationalOverrides(
    int productId,
  ) async => List<OperationalAvailabilityOverride>.from(productRows);
  @override
  Future<List<OperationalAvailabilityOverride>> listVariantOperationalOverrides(
    int variantId,
  ) async =>
      variantLoader?.call(variantId) ??
      List<OperationalAvailabilityOverride>.from(variantRows);
  @override
  Future<OperationalAvailabilityPreview> previewProductOperationalAvailability(
    int productId, {
    required int branchId,
    required String channel,
  }) async =>
      previewLoader?.call(null, branchId, channel) ??
      _preview(productId, null, branchId, channel);
  @override
  Future<OperationalAvailabilityPreview> previewVariantOperationalAvailability(
    int productId,
    int variantId, {
    required int branchId,
    required String channel,
  }) async =>
      previewLoader?.call(variantId, branchId, channel) ??
      _preview(productId, variantId, branchId, channel);
  @override
  Future<OperationalAvailabilityOverride> upsertProductOperationalOverride(
    int productId,
    OperationalAvailabilityDraft draft,
  ) async {
    if (upsertGate != null) await upsertGate!.future;
    if (failUpsertNotFound) {
      productArchived = true;
      throw const ApiException(message: 'Product not found.', statusCode: 404);
    }
    if (failUpsert) {
      throw const ApiException(
        message: 'Validation failed.',
        validationErrors: <String, List<String>>{
          'remainingQuantity': <String>['Remaining quantity is invalid.'],
        },
      );
    }
    productUpsert = draft;
    productRows = <OperationalAvailabilityOverride>[
      _row(draft, OperationalAvailabilityLevel.product),
    ];
    return productRows.single;
  }

  @override
  Future<OperationalAvailabilityOverride> upsertVariantOperationalOverride(
    int variantId,
    OperationalAvailabilityDraft draft,
  ) async {
    variantRows = <OperationalAvailabilityOverride>[
      _row(draft, OperationalAvailabilityLevel.variant),
    ];
    return variantRows.single;
  }

  @override
  Future<void> clearProductOperationalOverride(
    int productId,
    int branchId,
    String channel,
  ) async {
    if (failClear) throw const ApiException(message: 'Clear failed.');
    clearedProduct = <Object?>[productId, branchId, channel];
    productRows = <OperationalAvailabilityOverride>[];
  }

  @override
  Future<void> clearVariantOperationalOverride(
    int variantId,
    int branchId,
    String channel,
  ) async {
    if (failClear) throw const ApiException(message: 'Clear failed.');
    clearedVariant = <Object?>[variantId, branchId, channel];
    variantRows = <OperationalAvailabilityOverride>[];
  }
}

OperationalAvailabilityPreview _preview(
  int productId,
  int? variantId,
  int branchId,
  String channel,
) => OperationalAvailabilityPreview.fromJson(<String, dynamic>{
  'productId': productId,
  'productVariantId': variantId,
  'branchId': branchId,
  'channel': channel,
  'isOperationallyAvailable': variantId != null,
  'status': variantId == null ? 'sold_out' : 'available',
  'matchedLevel': variantId == null ? 'product' : 'variant',
  'matchedScope': variantId == null ? 'all_channels' : 'exact_channel',
  'matchedRecordId': variantId == null ? 1 : 2,
  'remainingQuantity': 0,
  'unavailableUntil': null,
  'reason': 'mocked',
});

OperationalAvailabilityOverride _productRow() => _row(
  const OperationalAvailabilityDraft(
    branchId: 1,
    channel: 'all',
    status: OperationalAvailabilityStatus.soldOut,
  ),
  OperationalAvailabilityLevel.product,
);
OperationalAvailabilityOverride _variantRow() => _row(
  const OperationalAvailabilityDraft(
    branchId: 1,
    channel: 'pos',
    status: OperationalAvailabilityStatus.available,
    remainingQuantity: 0,
  ),
  OperationalAvailabilityLevel.variant,
);
OperationalAvailabilityOverride _row(
  OperationalAvailabilityDraft draft,
  OperationalAvailabilityLevel level, {
  int? variantId,
  bool isExpired = false,
}) => OperationalAvailabilityOverride(
  id: level == OperationalAvailabilityLevel.product ? 1 : 2,
  level: level,
  productId: 11,
  productVariantId: level == OperationalAvailabilityLevel.variant
      ? variantId ?? 12
      : null,
  branchId: 1,
  branchName: 'Main',
  branchTimezone: 'Asia/Damascus',
  channel: draft.channel,
  status: draft.status,
  remainingQuantity: draft.remainingQuantity,
  unavailableUntil: draft.unavailableUntil,
  reason: draft.reason,
  isExpired: isExpired,
  createdAt: null,
  updatedAt: null,
);
ProductDetail _product(bool archived, bool variantArchived) =>
    ProductDetail.fromJson(<String, dynamic>{
      'id': 11,
      'name': 'Latte',
      'productType': 'standard',
      'isActive': true,
      'category': null,
      'reportingCategory': null,
      'kitchenStation': null,
      'defaultVariant': _variant(variantArchived),
      'variantCount': 1,
      'modifierGroupCount': 0,
      'isStockTracked': false,
      'sortOrder': 0,
      'variants': <Map<String, dynamic>>[_variant(variantArchived)],
      'modifierGroups': const <Map<String, dynamic>>[],
      if (archived) 'archivedAt': '2026-08-01T00:00:00Z',
    });
Map<String, dynamic> _variant(bool archived) => <String, dynamic>{
  'id': 12,
  'productId': 11,
  'name': 'Regular',
  'basePrice': 4,
  'isDefault': true,
  'isActive': !archived,
  'sortOrder': 0,
  if (archived) 'archivedAt': '2026-08-01T00:00:00Z',
};
