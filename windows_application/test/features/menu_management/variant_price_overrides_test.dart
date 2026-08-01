import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/variant_price_overrides_cubit.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/variant_price_overrides_state.dart';
import 'package:windows_application/features/menu_management/pricing/models/variant_price_models.dart';
import 'package:windows_application/features/menu_management/pricing/views/variant_price_overrides_screen.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/pos/models/branch.dart';

void main() {
  group('Variant price override contracts', () {
    test('parses overrides and serializes supported complete-sync fields', () {
      final VariantPriceOverride override =
          VariantPriceOverride.fromJson(<String, dynamic>{
            'id': 5,
            'scopeType': 'branch_channel',
            'branchId': 7,
            'channel': 'delivery',
            'overridePrice': 4.5,
            'isActive': true,
          });
      final Map<String, dynamic> json = VariantPriceOverrideDraft.fromOverride(
        override,
      ).toJson();
      expect(override.price.wireValue, '4.50');
      expect(json, <String, dynamic>{
        'scopeType': 'branch_channel',
        'branchId': 7,
        'channel': 'delivery',
        'overridePrice': '4.50',
      });
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('scopeKey'), isFalse);
      expect(json.containsKey('tenantId'), isFalse);
    });

    test('supports branch-only and channel-only decimal-safe payloads', () {
      expect(
        VariantPriceOverrideDraft(
          scope: PriceOverrideScope.branch,
          branchId: 2,
          channel: null,
          price: PriceAmount.parse('0'),
        ).toJson(),
        <String, dynamic>{
          'scopeType': 'branch',
          'branchId': 2,
          'channel': null,
          'overridePrice': '0.00',
        },
      );
      expect(
        VariantPriceOverrideDraft(
          scope: PriceOverrideScope.channel,
          branchId: null,
          channel: 'pos',
          price: PriceAmount.parse('1.2'),
        ).toJson()['overridePrice'],
        '1.20',
      );
    });

    test('parses actual effective-price matchedScope values', () {
      final EffectiveVariantPrice value =
          EffectiveVariantPrice.fromJson(<String, dynamic>{
            'variantId': 2,
            'basePrice': 4,
            'effectivePrice': 5,
            'matchedScope': 'branch_channel',
            'matchedOverrideId': 9,
            'branchId': 3,
            'channel': 'delivery',
          });
      expect(value.sourceLabel, 'Branch + Channel Override');
      expect(value.effectivePrice.wireValue, '5.00');
    });
  });

  group('VariantPriceOverridesCubit', () {
    test(
      'loads authoritative draft, prevents duplicate scope, and tracks dirty state',
      () async {
        final _PricingRepository repository = _PricingRepository();
        final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
          repository: repository,
        );
        await cubit.load(11, 1);
        expect(cubit.state.status, VariantPriceOverridesStatus.loaded);
        expect(cubit.state.isAuthoritative, isTrue);
        expect(cubit.state.isDirty, isFalse);
        expect(cubit.addOrUpdate(_branchDraft('5.00')), isFalse);
        expect(cubit.state.fieldErrors['scopeType'], contains('Duplicate'));
        expect(cubit.addOrUpdate(_channelDraft('4.25')), isTrue);
        expect(cubit.state.isDirty, isTrue);
        await cubit.close();
      },
    );

    test(
      'complete sync sends full draft and save failure preserves it',
      () async {
        final _PricingRepository repository = _PricingRepository()
          ..syncError = true;
        final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
          repository: repository,
        );
        await cubit.load(11, 1);
        cubit.addOrUpdate(_channelDraft('4.25'));
        final List<VariantPriceOverrideDraft> before = cubit.state.draft;
        expect(await cubit.save(), isFalse);
        expect(repository.lastSync, before);
        expect(cubit.state.draft, before);
        expect(
          cubit.state.fieldErrors['overridePrice'],
          'The override price is invalid.',
        );
        await cubit.close();
      },
    );

    test(
      'archived variants are read-only and override-load failure blocks sync',
      () async {
        final _PricingRepository archived = _PricingRepository()
          ..archived = true;
        final VariantPriceOverridesCubit archivedCubit =
            VariantPriceOverridesCubit(repository: archived);
        await archivedCubit.load(11, 1);
        expect(archivedCubit.state.isReadOnly, isTrue);
        expect(archivedCubit.addOrUpdate(_channelDraft('3')), isFalse);
        await archivedCubit.close();

        final _PricingRepository failing = _PricingRepository()
          ..loadError = true;
        final VariantPriceOverridesCubit failingCubit =
            VariantPriceOverridesCubit(repository: failing);
        await failingCubit.load(11, 1);
        expect(failingCubit.state.isAuthoritative, isFalse);
        expect(failingCubit.addOrUpdate(_channelDraft('3')), isFalse);
        await failingCubit.close();
      },
    );

    test('uses backend effective prices and ignores stale responses', () async {
      final _PricingRepository repository = _PricingRepository();
      final Completer<EffectiveVariantPrice> first =
          Completer<EffectiveVariantPrice>();
      final Completer<EffectiveVariantPrice> second =
          Completer<EffectiveVariantPrice>();
      final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
        repository: repository,
      );
      await cubit.load(11, 1);
      repository.effectiveResponses = <Future<EffectiveVariantPrice>>[
        first.future,
        second.future,
      ];
      final Future<void> old = cubit.selectEffectiveContext(
        branchId: 2,
        channel: 'delivery',
      );
      final Future<void> current = cubit.selectEffectiveContext(
        branchId: 2,
        channel: 'pos',
      );
      second.complete(_effective('channel', 425));
      await current;
      first.complete(_effective('branch', 450));
      await old;
      expect(cubit.state.effectivePrice!.matchedScope, 'channel');
      expect(cubit.state.effectiveChannel, 'pos');
      await cubit.close();
    });
  });

  testWidgets(
    'pricing screen renders base price, override data, and diagnostic',
    (WidgetTester tester) async {
      final _PricingRepository repository = _PricingRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<VariantPriceOverridesCubit>(
            create: (_) => VariantPriceOverridesCubit(repository: repository),
            child: const VariantPriceOverridesScreen(
              productId: 11,
              variantId: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Price Overrides'), findsOneWidget);
      expect(find.text('USD 4.00'), findsWidgets);
      expect(find.text('Branch'), findsWidgets);
      expect(find.byKey(const Key('add-channel-override')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Effective Price Diagnostic'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Effective Price Diagnostic'), findsOneWidget);
    },
  );
}

VariantPriceOverrideDraft _branchDraft(String price) =>
    VariantPriceOverrideDraft(
      scope: PriceOverrideScope.branch,
      branchId: 2,
      channel: null,
      price: PriceAmount.parse(price),
    );
VariantPriceOverrideDraft _channelDraft(String price) =>
    VariantPriceOverrideDraft(
      scope: PriceOverrideScope.channel,
      branchId: null,
      channel: 'delivery',
      price: PriceAmount.parse(price),
    );
EffectiveVariantPrice _effective(String scope, int cents) =>
    EffectiveVariantPrice(
      variantId: 1,
      basePrice: PriceAmount.parse('4'),
      effectivePrice: PriceAmount.parse(
        '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}',
      ),
      matchedScope: scope,
      matchedOverrideId: 4,
      branchId: 2,
      channel: 'delivery',
    );

class _PricingRepository extends MenuCatalogRepository {
  bool archived = false;
  bool loadError = false;
  bool syncError = false;
  List<VariantPriceOverrideDraft> lastSync =
      const <VariantPriceOverrideDraft>[];
  List<Future<EffectiveVariantPrice>> effectiveResponses =
      <Future<EffectiveVariantPrice>>[];
  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => _product(archived);
  @override
  Future<VariantPriceOverridesSnapshot> listVariantPriceOverrides(
    int variantId,
  ) async {
    if (loadError) {
      throw const ApiException(message: 'Could not load overrides.');
    }
    return VariantPriceOverridesSnapshot(
      variantId: 1,
      basePrice: PriceAmount.parse('4'),
      overrides: <VariantPriceOverride>[
        VariantPriceOverride(
          id: 1,
          scope: PriceOverrideScope.branch,
          branchId: 2,
          channel: null,
          price: PriceAmount.parse('4.50'),
          isActive: true,
        ),
      ],
    );
  }

  @override
  Future<List<Branch>> listAssignmentBranches() async => <Branch>[
    const Branch(
      id: 2,
      name: 'Downtown',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];
  @override
  Future<VariantPriceOverridesSnapshot> syncVariantPriceOverrides(
    int variantId,
    List<VariantPriceOverrideDraft> overrides,
  ) async {
    lastSync = overrides;
    if (syncError) {
      throw const ApiException(
        message: 'Validation failed.',
        validationErrors: <String, List<String>>{
          'overrides.1.overridePrice': <String>[
            'The override price is invalid.',
          ],
        },
      );
    }
    return await listVariantPriceOverrides(variantId);
  }

  @override
  Future<EffectiveVariantPrice> getEffectiveVariantPrice(
    int variantId, {
    int? branchId,
    String? channel,
  }) => effectiveResponses.isEmpty
      ? Future<EffectiveVariantPrice>.value(_effective('base', 400))
      : effectiveResponses.removeAt(0);
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
}

ProductDetail _product(bool archived) =>
    ProductDetail.fromJson(<String, dynamic>{
      'id': 11,
      'name': 'Latte',
      'productType': 'standard',
      'isActive': true,
      'category': null,
      'reportingCategory': null,
      'kitchenStation': null,
      'defaultVariant': _variant(1, archived),
      'variantCount': 1,
      'modifierGroupCount': 0,
      'isStockTracked': false,
      'sortOrder': 0,
      'variants': <Map<String, dynamic>>[_variant(1, archived)],
      'modifierGroups': const <Map<String, dynamic>>[],
    });
Map<String, dynamic> _variant(int id, bool archived) => <String, dynamic>{
  'id': id,
  'productId': 11,
  'name': 'Regular',
  'basePrice': 4,
  'isDefault': true,
  'isActive': !archived,
  'sortOrder': 0,
  if (archived) 'archivedAt': '2026-08-01T00:00:00Z',
};
