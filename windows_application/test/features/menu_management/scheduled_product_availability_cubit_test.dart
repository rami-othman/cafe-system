// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/availability/controllers/availability_cubit.dart';
import 'package:windows_application/features/menu_management/availability/controllers/availability_state.dart';
import 'package:windows_application/features/menu_management/availability/models/availability_models.dart';
import 'package:windows_application/features/menu_management/availability/views/availability_screen.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  group('scheduled availability cubit', () {
    test('loads authoritatively with Product selected by default', () async {
      final repository = _AvailabilityRepository();
      final cubit = AvailabilityCubit(repository: repository);

      await cubit.load(11);

      expect(cubit.state.status, AvailabilityStatus.loaded);
      expect(cubit.state.isAuthoritative, isTrue);
      expect(cubit.state.selectedVariantId, isNull);
      expect(cubit.state.exactRules, hasLength(1));
      expect(cubit.state.canEdit, isTrue);
    });

    test(
      'preselects a valid Variant and separates exact and inherited rules',
      () async {
        final cubit = AvailabilityCubit(repository: _AvailabilityRepository());
        await cubit.load(11, variantId: 12);
        cubit.selectContext(branchId: 1, channel: 'pos');

        expect(cubit.state.selectedVariantId, 12);
        expect(cubit.state.exactRules.single.productVariantId, 12);
        expect(
          cubit.state.inheritedRules.map((item) => item.id),
          containsAll(<int>[1, 2]),
        );
        expect(
          cubit.state.inheritedRules.map((item) => item.id),
          isNot(contains(3)),
        );
      },
    );

    test(
      'adds, edits and removes an exact Variant rule without losing other scopes',
      () async {
        final repository = _AvailabilityRepository();
        final cubit = AvailabilityCubit(repository: repository);
        await cubit.load(11, variantId: 12);
        cubit.selectContext(branchId: 1, channel: 'pos');
        const added = AvailabilityRuleDraft(
          productVariantId: 12,
          branchId: 1,
          channel: 'pos',
          dayOfWeek: 4,
          startTime: '18:00',
          endTime: '02:00',
          startDate: null,
          endDate: null,
          priority: 4,
          isActive: true,
        );

        expect(cubit.addOrUpdate(added), isTrue);
        expect(cubit.state.isDirty, isTrue);
        expect(await cubit.save(), isTrue);
        expect(repository.lastSync, hasLength(4));
        expect(
          repository.lastSync.where((r) => r.productVariantId == null),
          hasLength(2),
        );
        expect(
          repository.lastSync.where((r) => r.productVariantId == 12),
          hasLength(2),
        );

        cubit.remove(added.identity);
        expect(
          cubit.state.draft.any((r) => r.identity == added.identity),
          isFalse,
        );
      },
    );

    test(
      'Product edits preserve Variant rules and duplicate submission is rejected',
      () async {
        final repository = _AvailabilityRepository();
        final cubit = AvailabilityCubit(repository: repository);
        await cubit.load(11);
        const replacement = AvailabilityRuleDraft(
          productVariantId: null,
          branchId: null,
          channel: null,
          dayOfWeek: 1,
          startTime: '07:00',
          endTime: '12:00',
          startDate: null,
          endDate: null,
          priority: 8,
          isActive: false,
        );
        expect(
          cubit.addOrUpdate(
            replacement,
            replacingIdentity: 'null|null|null|1|07:00|12:00|null|null',
          ),
          isTrue,
        );
        expect(cubit.addOrUpdate(replacement), isFalse);
        expect(cubit.state.fieldErrors['editor'], contains('Duplicate'));
        expect(await cubit.save(), isTrue);
        expect(
          repository.lastSync.where((r) => r.productVariantId == 12),
          hasLength(1),
        );
      },
    );

    test(
      'load and save failures preserve the local draft and block mutation',
      () async {
        final repository = _AvailabilityRepository();
        final cubit = AvailabilityCubit(repository: repository);
        repository.loadError = true;
        await cubit.load(11);
        expect(cubit.state.isAuthoritative, isFalse);
        expect(cubit.addOrUpdate(_globalDraft()), isFalse);

        repository.loadError = false;
        await cubit.load(11);
        expect(cubit.addOrUpdate(_globalDraft(day: 5, priority: 9)), isTrue);
        final before = cubit.state.draft;
        repository.syncError = true;
        expect(await cubit.save(), isFalse);
        expect(cubit.state.draft, before);
        expect(cubit.state.fieldErrors['startTime'], 'Invalid start time.');
      },
    );

    test(
      'a failed authoritative reload after sync does not report success or remain saving',
      () async {
        final repository = _AvailabilityRepository();
        final cubit = AvailabilityCubit(repository: repository);
        await cubit.load(11);
        expect(cubit.addOrUpdate(_globalDraft(day: 5, priority: 9)), isTrue);
        repository.failReloadAfterSync = true;

        expect(await cubit.save(), isFalse);
        expect(cubit.state.isAuthoritative, isFalse);
        expect(cubit.state.isSaving, isFalse);
        expect(cubit.state.successMessage, isNull);
      },
    );

    test(
      'Product and archived Variant lifecycle safeguards are scoped correctly',
      () async {
        final repository = _AvailabilityRepository();
        final cubit = AvailabilityCubit(repository: repository);
        repository.productArchived = true;
        await cubit.load(11);
        expect(cubit.state.isReadOnly, isTrue);
        expect(cubit.state.canEdit, isFalse);

        repository.productArchived = false;
        repository.variantArchived = true;
        await cubit.load(11);
        expect(cubit.state.canEdit, isTrue);
        cubit.selectContext(variantId: 12);
        expect(cubit.state.isReadOnly, isTrue);
        cubit.selectContext(clearVariant: true);
        expect(cubit.state.canEdit, isTrue);
      },
    );

    test(
      'preview forwards selected context, preserves draft on error, and ignores stale responses',
      () async {
        final repository = _AvailabilityRepository();
        final cubit = AvailabilityCubit(repository: repository);
        await cubit.load(11, variantId: 12);
        cubit.selectContext(branchId: 1, channel: 'pos');
        expect(
          cubit.addOrUpdate(
            const AvailabilityRuleDraft(
              productVariantId: 12,
              branchId: 1,
              channel: 'pos',
              dayOfWeek: 2,
              startTime: null,
              endTime: null,
              startDate: null,
              endDate: null,
              priority: 2,
              isActive: true,
            ),
          ),
          isTrue,
        );
        final before = cubit.state.draft;
        final first = Completer<AvailabilityPreview>();
        final second = Completer<AvailabilityPreview>();
        repository.previewResponses = <Future<AvailabilityPreview>>[
          first.future,
          second.future,
        ];

        final p1 = cubit.preview(DateTime(2026, 8, 4, 9));
        final p2 = cubit.preview(DateTime(2026, 8, 4, 10));
        first.complete(_preview('outside_schedule'));
        second.complete(_preview('matched_rule'));
        await Future.wait(<Future<void>>[p1, p2]);
        expect(repository.previewVariantId, 12);
        expect(repository.previewBranchId, 1);
        expect(repository.previewChannel, 'pos');
        expect(repository.previewDateTime, '2026-08-04T10:00:00');
        expect(cubit.state.preview?.reason, 'matched_rule');

        repository.previewResponses = <Future<AvailabilityPreview>>[
          Future<AvailabilityPreview>.error(
            const ApiException(message: 'Preview failed.'),
          ),
        ];
        await cubit.preview(DateTime(2026, 8, 4, 11));
        expect(cubit.state.previewError, 'Preview failed.');
        expect(cubit.state.draft, before);
      },
    );
    test('customizing an inherited Variant adds a Variant rule, not a Product rule', () async {
      final repository = _AvailabilityRepository();
      final cubit = AvailabilityCubit(repository: repository);
      await cubit.load(11, variantId: 12);
      cubit.selectContext(clearBranch: true, clearChannel: true);

      expect(cubit.state.exactRules, isEmpty);
      expect(cubit.state.inheritedRules, isNotEmpty);
      const customized = AvailabilityRuleDraft(
        productVariantId: 12,
        branchId: null,
        channel: null,
        dayOfWeek: 1,
        startTime: '07:00',
        endTime: '22:00',
        startDate: null,
        endDate: null,
        priority: 0,
        isActive: true,
      );

      expect(cubit.addOrUpdate(customized), isTrue);
      expect(await cubit.save(), isTrue);
      expect(
        repository.lastSync.where((rule) => rule.productVariantId == null),
        hasLength(2),
      );
      expect(repository.lastSync, contains(customized));
    });

    test('accepts and persists a 22:00 to 02:00 overnight Variant rule', () async {
      final repository = _AvailabilityRepository();
      final cubit = AvailabilityCubit(repository: repository);
      await cubit.load(11, variantId: 12);
      cubit.selectContext(clearBranch: true, clearChannel: true);
      const overnight = AvailabilityRuleDraft(
        productVariantId: 12,
        branchId: null,
        channel: null,
        dayOfWeek: 1,
        startTime: '22:00',
        endTime: '02:00',
        startDate: null,
        endDate: null,
        priority: 0,
        isActive: true,
      );

      expect(overnight.isOvernight, isTrue);
      expect(cubit.addOrUpdate(overnight), isTrue);
      expect(await cubit.save(), isTrue);
      expect(repository.lastSync, contains(overnight));
    });

    test('global preview is forwarded without a Branch id', () async {
      final repository = _AvailabilityRepository();
      final cubit = AvailabilityCubit(repository: repository);
      await cubit.load(11);

      await cubit.preview(DateTime(2026, 8, 4, 10));

      expect(repository.previewBranchId, isNull);
      expect(repository.previewDateTime, '2026-08-04T10:00:00');
    });
  });

  group('scheduled availability screen', () {
    testWidgets(
      'renders the regular availability hierarchy',
      (tester) async {
        final repository = _AvailabilityRepository();
        await tester.pumpWidget(
          _screen(repository, variantId: 12, branchId: 1, channel: 'pos'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Regular availability'), findsOneWidget);
        expect(find.text('Advanced Schedule Rules'), findsOneWidget);
        expect(find.text('Check Availability'), findsOneWidget);
        expect(find.byKey(const Key('edit-selling-hours')), findsOneWidget);
      },
    );

    testWidgets('sanitizes invalid query context and archives are read-only', (
      tester,
    ) async {
      final repository = _AvailabilityRepository()..productArchived = true;
      await tester.pumpWidget(
        _screen(repository, variantId: 999, branchId: 999, channel: 'invalid'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('archived'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('edit-selling-hours')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('edit-selling-hours')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('All branches'), findsOneWidget);
    });
  });
}

Widget _screen(
  _AvailabilityRepository repository, {
  int? variantId,
  int? branchId,
  String? channel,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<AvailabilityCubit>(
    create: (_) => AvailabilityCubit(repository: repository),
    child: AvailabilityScreen(
      productId: 11,
      variantId: variantId,
      branchId: branchId,
      channel: channel,
    ),
  ),
);

AvailabilityRuleDraft _globalDraft({int day = 1, int priority = 0}) =>
    AvailabilityRuleDraft(
      productVariantId: null,
      branchId: null,
      channel: null,
      dayOfWeek: day,
      startTime: '07:00',
      endTime: '12:00',
      startDate: null,
      endDate: null,
      priority: priority,
      isActive: true,
    );

AvailabilityPreview _preview(String reason) => AvailabilityPreview(
  isScheduledAvailable: reason != 'outside_schedule',
  reason: reason,
  matchedRuleId: reason == 'matched_rule' ? 3 : null,
  matchedScope: 'branch_channel',
  matchedLevel: 'variant',
  productVariantId: 12,
  branchId: 1,
  channel: 'pos',
  timezone: 'Asia/Damascus',
);

class _AvailabilityRepository extends MenuCatalogRepository {
  bool productArchived = false;
  bool variantArchived = false;
  bool loadError = false;
  bool syncError = false;
  bool failReloadAfterSync = false;
  bool _didSync = false;
  List<AvailabilityRuleDraft> lastSync = const <AvailabilityRuleDraft>[];
  List<Future<AvailabilityPreview>> previewResponses =
      <Future<AvailabilityPreview>>[];
  int? previewVariantId;
  int? previewBranchId;
  String? previewChannel;
  String? previewDateTime;

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => _product(productArchived, variantArchived);
  @override
  Future<ProductAvailabilityRulesSnapshot> listProductAvailabilityRules(
    int productId,
  ) async {
    if (loadError || (failReloadAfterSync && _didSync))
      throw const ApiException(message: 'Could not load rules.');
    return ProductAvailabilityRulesSnapshot(productId: 11, rules: _rules());
  }

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
  Future<ProductAvailabilityRulesSnapshot> syncProductAvailabilityRules(
    int productId,
    List<AvailabilityRuleDraft> rules,
  ) async {
    lastSync = List<AvailabilityRuleDraft>.unmodifiable(rules);
    _didSync = true;
    if (syncError)
      throw const ApiException(
        message: 'Validation failed.',
        validationErrors: <String, List<String>>{
          'rules.0.startTime': <String>['Invalid start time.'],
        },
      );
    return ProductAvailabilityRulesSnapshot(productId: 11, rules: _rules());
  }

  @override
  Future<AvailabilityPreview> previewProductAvailability(
    int productId, {
    int? variantId,
    int? branchId,
    String? channel,
    required String dateTime,
  }) {
    previewVariantId = variantId;
    previewBranchId = branchId;
    previewChannel = channel;
    previewDateTime = dateTime;
    return previewResponses.isEmpty
        ? Future<AvailabilityPreview>.value(_preview('no_schedule_restriction'))
        : previewResponses.removeAt(0);
  }

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

List<AvailabilityRule> _rules() => <AvailabilityRule>[
  AvailabilityRule(
    id: 1,
    productVariantId: null,
    branchId: null,
    channel: null,
    dayOfWeek: 1,
    startTime: '07:00',
    endTime: '12:00',
    startDate: null,
    endDate: null,
    priority: 0,
    isActive: true,
  ),
  AvailabilityRule(
    id: 2,
    productVariantId: null,
    branchId: 1,
    channel: null,
    dayOfWeek: null,
    startTime: '08:00',
    endTime: '16:00',
    startDate: null,
    endDate: null,
    priority: 1,
    isActive: true,
  ),
  AvailabilityRule(
    id: 3,
    productVariantId: 12,
    branchId: 1,
    channel: 'pos',
    dayOfWeek: 2,
    startTime: '10:00',
    endTime: '12:00',
    startDate: null,
    endDate: null,
    priority: 2,
    isActive: true,
  ),
];

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
