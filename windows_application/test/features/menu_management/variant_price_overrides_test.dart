import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/variant_price_overrides_cubit.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/variant_price_overrides_state.dart';
import 'package:windows_application/features/menu_management/pricing/models/variant_price_models.dart';
import 'package:windows_application/features/menu_management/pricing/configured_price_validation.dart';
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
        'isActive': true,
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
          price: PriceAmount.parse('0.01'),
        ).toJson(),
        <String, dynamic>{
          'scopeType': 'branch',
          'branchId': 2,
          'channel': null,
          'overridePrice': '0.01',
          'isActive': true,
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

  test('editing preserves an inactive override lifecycle state', () {
    final VariantPriceOverride inactive =
        VariantPriceOverride.fromJson(<String, dynamic>{
          'id': 5,
          'scopeType': 'branch',
          'branchId': 7,
          'overridePrice': '4.50',
          'isActive': false,
        });
    expect(
      VariantPriceOverrideDraft.fromOverride(inactive).toJson()['isActive'],
      isFalse,
    );
  });

  test(
    'override editor rejects zero and negative configured replacement prices',
    () async {
      final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
        repository: _PricingRepository(),
      );
      await cubit.load(11, 1);
      expect(cubit.addOrUpdate(_channelDraft('0.00')), isFalse);
      expect(
        cubit.state.fieldErrors['editor'],
        configuredSellPriceMustBePositive,
      );
      expect(() => PriceAmount.parse('-1.00'), throwsFormatException);
      await cubit.close();
    },
  );

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
      'successful saves release editing and retain independent scoped rules',
      () async {
        final _PricingRepository repository = _PricingRepository(
          overrides: const <VariantPriceOverride>[],
        );
        final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
          repository: repository,
        );
        await cubit.load(11, 1);

        expect(
          cubit.addOrUpdate(_branchChannelDraft(2, 'pos', '2.50')),
          isTrue,
        );
        expect(await cubit.save(), isTrue);
        expect(cubit.state.canEdit, isTrue);
        expect(cubit.state.isSaving, isFalse);

        expect(
          cubit.addOrUpdate(_branchChannelDraft(3, 'waiter_app', '3.25')),
          isTrue,
        );
        expect(await cubit.save(), isTrue);
        expect(repository.lastSync, hasLength(2));
        expect(
          repository.lastSync.map((rule) => rule.scopeKey),
          containsAll(<String>[
            'branch:2|channel:pos',
            'branch:3|channel:waiter_app',
          ]),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      expect(find.textContaining('Selling price'), findsOneWidget);
      expect(find.text('USD 4.00'), findsWidgets);
      expect(find.text('Branch'), findsWidgets);
      expect(find.byKey(const Key('change-price')), findsOneWidget);
      expect(find.byKey(const Key('more-price-rules')), findsOneWidget);
      expect(find.byKey(const Key('add-price')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('toggle-price-rules')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-price-rules')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-price')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('add-price')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-price')));
      await tester.pumpAndSettle();
      expect(find.text('Set Selling Price'), findsOneWidget);
      expect(find.text('Applies to'), findsOneWidget);
      expect(find.text('Branch + Channel'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Effective selling price'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Effective selling price'), findsOneWidget);
    },
  );

  testWidgets('Change Price opens a new scoped rule when no rules exist', (
    WidgetTester tester,
  ) async {
    final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
      repository: _PricingRepository(overrides: const <VariantPriceOverride>[]),
    );
    await _pumpPricingScreen(tester, cubit);
    await _selectContext(tester, cubit, branchId: 3, channel: 'waiter_app');

    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('change-price')),
    );
    expect(button.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('change-price')));
    await tester.pumpAndSettle();
    expect(find.text('Set Selling Price'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('override-price')))
          .controller!
          .text,
      isEmpty,
    );
    await cubit.close();
  });

  testWidgets(
    'an existing Downtown POS rule does not prevent adding Mall Waiter App',
    (WidgetTester tester) async {
      final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
        repository: _PricingRepository(
          overrides: <VariantPriceOverride>[
            _branchChannelOverride(2, 'pos', '2.50'),
          ],
        ),
      );
      await _pumpPricingScreen(tester, cubit);
      await _selectContext(tester, cubit, branchId: 3, channel: 'waiter_app');

      await tester.tap(find.byKey(const Key('toggle-price-rules')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-price')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('add-price')));
      await tester.tap(find.byKey(const Key('add-price')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('override-price')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(find.byKey(const Key('override-price')), '3.25');
      final savePrice = find.widgetWithText(FilledButton, 'Save Price');
      await tester.ensureVisible(savePrice);
      await tester.tap(savePrice);
      await tester.pumpAndSettle();

      expect(cubit.state.draft, hasLength(2));
      expect(
        cubit.state.draft.map((rule) => rule.scopeKey),
        containsAll(<String>[
          'branch:2|channel:pos',
          'branch:3|channel:waiter_app',
        ]),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('change-price')))
            .onPressed,
        isNotNull,
      );
      expect(find.byKey(const Key('add-price')), findsOneWidget);
      await cubit.close();
    },
  );

  testWidgets('Change Price edits an exact current-context rule', (
    WidgetTester tester,
  ) async {
    final _PricingRepository repository = _PricingRepository(
      overrides: <VariantPriceOverride>[
        _branchChannelOverride(2, 'pos', '2.50'),
      ],
    );
    final VariantPriceOverridesCubit cubit = VariantPriceOverridesCubit(
      repository: repository,
    );
    await _pumpPricingScreen(tester, cubit);
    await _selectContext(tester, cubit, branchId: 2, channel: 'pos');

    await tester.tap(find.byKey(const Key('change-price')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('override-price')))
          .controller!
          .text,
      '2.50',
    );
    await tester.enterText(find.byKey(const Key('override-price')), '2.75');
    final savePrice = find.widgetWithText(FilledButton, 'Save Price');
    await tester.ensureVisible(savePrice);
    await tester.tap(savePrice);
    await tester.pumpAndSettle();

    expect(repository.lastSync, hasLength(1));
    expect(repository.lastSync.single.price.wireValue, '2.75');
    expect(repository.lastSync.single.scopeKey, 'branch:2|channel:pos');
    await cubit.close();
  });
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
VariantPriceOverrideDraft _branchChannelDraft(
  int branchId,
  String channel,
  String price,
) => VariantPriceOverrideDraft(
  scope: PriceOverrideScope.branchChannel,
  branchId: branchId,
  channel: channel,
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

Future<void> _pumpPricingScreen(
  WidgetTester tester,
  VariantPriceOverridesCubit cubit,
) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<VariantPriceOverridesCubit>.value(
        value: cubit,
        child: const VariantPriceOverridesScreen(productId: 11, variantId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectContext(
  WidgetTester tester,
  VariantPriceOverridesCubit cubit, {
  required int branchId,
  required String channel,
}) async {
  await cubit.selectEffectiveContext(branchId: branchId, channel: channel);
  await tester.pumpAndSettle();
}

class _PricingRepository extends MenuCatalogRepository {
  _PricingRepository({List<VariantPriceOverride>? overrides})
    : _overrides = List<VariantPriceOverride>.from(
        overrides ?? <VariantPriceOverride>[_downtownBranchRule()],
      );

  bool archived = false;
  bool loadError = false;
  bool syncError = false;
  List<VariantPriceOverride> _overrides;
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
      overrides: _overrides,
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
    const Branch(
      id: 3,
      name: 'Mall',
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
    _overrides = <VariantPriceOverride>[
      for (var index = 0; index < overrides.length; index++)
        VariantPriceOverride(
          id: index + 1,
          scope: overrides[index].scope,
          branchId: overrides[index].branchId,
          channel: overrides[index].channel,
          price: overrides[index].price,
          isActive: overrides[index].isActive,
        ),
    ];
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

VariantPriceOverride _downtownBranchRule() => VariantPriceOverride(
  id: 1,
  scope: PriceOverrideScope.branch,
  branchId: 2,
  channel: null,
  price: PriceAmount.parse('4.50'),
  isActive: true,
);

VariantPriceOverride _branchChannelOverride(
  int branchId,
  String channel,
  String price,
) => VariantPriceOverride(
  id: 1,
  scope: PriceOverrideScope.branchChannel,
  branchId: branchId,
  channel: channel,
  price: PriceAmount.parse(price),
  isActive: true,
);
