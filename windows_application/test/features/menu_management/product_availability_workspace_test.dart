import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/availability/controllers/availability_cubit.dart';
import 'package:windows_application/features/menu_management/availability/models/availability_models.dart';
import 'package:windows_application/features/menu_management/availability/widgets/product_availability_workspace.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/operational_availability/controllers/operational_availability_cubit.dart';
import 'package:windows_application/features/menu_management/operational_availability/models/operational_availability_models.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/variant_price_overrides_cubit.dart';
import 'package:windows_application/features/menu_management/pricing/models/variant_price_models.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';

import '../../support/menu_management_test_harness.dart';

void main() {
  testWidgets('keeps the three selling summaries aligned at desktop width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _WorkspaceRepository();
    final schedule = AvailabilityCubit(repository: repository);
    final prices = VariantPriceOverridesCubit(repository: repository);
    final operational = OperationalAvailabilityCubit(repository: repository);
    await Future.wait<void>(<Future<void>>[
      schedule.load(11, variantId: 12),
      prices.load(11, 12, branchId: 1, channel: 'pos'),
      operational.load(11, variantId: 12, branchId: 1, channel: 'pos'),
    ]);
    addTearDown(() async {
      await schedule.close();
      await prices.close();
      await operational.close();
    });

    await pumpMenuManagementHarness(
      tester,
      child: ProductAvailabilityWorkspace(
        product: repository.product,
        availabilityCubit: schedule,
        priceCubit: prices,
        operationalCubit: operational,
      ),
    );
    await tester.pumpAndSettle();

    final pricing = tester.getCenter(find.text('Manage pricing'));
    final scheduleAction = tester.getCenter(find.text('Manage schedule'));
    final availability = tester.getCenter(find.text('Manage availability'));
    expect(pricing.dy, closeTo(scheduleAction.dy, 1));
    expect(pricing.dy, closeTo(availability.dy, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders live price, schedule, and operational summaries inline',
    (tester) async {
      final repository = _WorkspaceRepository();
      final schedule = AvailabilityCubit(repository: repository);
      final prices = VariantPriceOverridesCubit(repository: repository);
      final operational = OperationalAvailabilityCubit(repository: repository);
      await Future.wait<void>(<Future<void>>[
        schedule.load(11, variantId: 12),
        prices.load(11, 12, branchId: 1, channel: 'pos'),
        operational.load(11, variantId: 12, branchId: 1, channel: 'pos'),
      ]);
      addTearDown(() async {
        await schedule.close();
        await prices.close();
        await operational.close();
      });

      await pumpMenuManagementHarness(
        tester,
        child: ProductAvailabilityWorkspace(
          product: repository.product,
          availabilityCubit: schedule,
          priceCubit: prices,
          operationalCubit: operational,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selling price'), findsOneWidget);
      expect(find.text('USD 5.50'), findsWidgets);
      expect(find.text('Branch price'), findsOneWidget);
      expect(find.text('No schedule restrictions'), findsOneWidget);
      expect(find.text('Available now'), findsWidgets);
      expect(find.text('Effective selling result'), findsOneWidget);
      expect(repository.previewRequests, isNotEmpty);
      expect(repository.effectiveRequests, isNotEmpty);
      expect(repository.operationalRequests, isNotEmpty);
    },
  );

  testWidgets('uses manager-facing summary errors and offers retry', (
    tester,
  ) async {
    final repository = _PriceErrorWorkspaceRepository();
    final schedule = AvailabilityCubit(repository: repository);
    final prices = VariantPriceOverridesCubit(repository: repository);
    final operational = OperationalAvailabilityCubit(repository: repository);
    await Future.wait<void>(<Future<void>>[
      schedule.load(11, variantId: 12),
      prices.load(11, 12, branchId: 1, channel: 'pos'),
      operational.load(11, variantId: 12, branchId: 1, channel: 'pos'),
    ]);
    addTearDown(() async {
      await schedule.close();
      await prices.close();
      await operational.close();
    });

    await pumpMenuManagementHarness(
      tester,
      child: ProductAvailabilityWorkspace(
        product: repository.product,
        availabilityCubit: schedule,
        priceCubit: prices,
        operationalCubit: operational,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Availability could not be loaded.'), findsWidgets);
    expect(find.textContaining('price resolver failed'), findsNothing);
    final attemptsBeforeRetry = repository.effectiveAttempts;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.effectiveAttempts, greaterThan(attemptsBeforeRetry));
  });

  testWidgets('uses Arabic manager-facing labels in the inline workspace', (
    tester,
  ) async {
    final repository = _WorkspaceRepository();
    final schedule = AvailabilityCubit(repository: repository);
    final prices = VariantPriceOverridesCubit(repository: repository);
    final operational = OperationalAvailabilityCubit(repository: repository);
    await Future.wait<void>(<Future<void>>[
      schedule.load(11, variantId: 12),
      prices.load(11, 12, branchId: 1, channel: 'pos'),
      operational.load(11, variantId: 12, branchId: 1, channel: 'pos'),
    ]);
    addTearDown(() async {
      await schedule.close();
      await prices.close();
      await operational.close();
    });

    await pumpMenuManagementHarness(
      tester,
      locale: const Locale('ar'),
      child: ProductAvailabilityWorkspace(
        product: repository.product,
        availabilityCubit: schedule,
        priceCubit: prices,
        operationalCubit: operational,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إتاحة البيع'), findsOneWidget);
    expect(find.text('سعر البيع'), findsOneWidget);
    expect(find.text('متاح الآن'), findsWidgets);
  });

  testWidgets('context changes refresh all authoritative inline results', (
    tester,
  ) async {
    final repository = _WorkspaceRepository();
    final schedule = AvailabilityCubit(repository: repository);
    final prices = VariantPriceOverridesCubit(repository: repository);
    final operational = OperationalAvailabilityCubit(repository: repository);
    await Future.wait<void>(<Future<void>>[
      schedule.load(11, variantId: 12),
      prices.load(11, 12, branchId: 1, channel: 'pos'),
      operational.load(11, variantId: 12, branchId: 1, channel: 'pos'),
    ]);
    addTearDown(() async {
      await schedule.close();
      await prices.close();
      await operational.close();
    });
    await pumpMenuManagementHarness(
      tester,
      child: ProductAvailabilityWorkspace(
        product: repository.product,
        availabilityCubit: schedule,
        priceCubit: prices,
        operationalCubit: operational,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('availability-workspace-variant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large').last);
    await tester.pumpAndSettle();
    expect(repository.effectiveRequests.last, <Object?>[13, 1, 'pos']);
    expect(repository.operationalRequests.last, <Object?>[13, 1, 'pos']);

    await tester.tap(find.byKey(const Key('availability-workspace-branch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Airport').last);
    await tester.pumpAndSettle();
    expect(repository.effectiveRequests.last, <Object?>[13, 2, 'pos']);
    expect(repository.previewRequests.last, <Object?>[13, 2, 'pos']);

    await tester.tap(find.byKey(const Key('availability-workspace-channel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delivery').last);
    await tester.pumpAndSettle();
    expect(repository.effectiveRequests.last, <Object?>[13, 2, 'delivery']);
    expect(repository.operationalRequests.last, <Object?>[13, 2, 'delivery']);
  });
}

class _WorkspaceRepository extends MenuCatalogRepository {
  final List<Object?> previewRequests = <Object?>[];
  final List<Object?> effectiveRequests = <Object?>[];
  final List<Object?> operationalRequests = <Object?>[];

  ProductDetail get product => ProductDetail.fromJson(<String, dynamic>{
    'id': 11,
    'name': 'Latte',
    'nameAr': 'لاتيه',
    'productType': 'standard',
    'isActive': true,
    'category': null,
    'reportingCategory': null,
    'kitchenStation': null,
    'defaultVariant': _variant(),
    'variantCount': 1,
    'modifierGroupCount': 0,
    'isStockTracked': false,
    'sortOrder': 0,
    'variants': <Map<String, dynamic>>[_variant(), _variant(13, 'Large')],
    'modifierGroups': const <Map<String, dynamic>>[],
  });

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => product;
  @override
  Future<List<Branch>> listAssignmentBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Downtown',
      currency: 'USD',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
    Branch(
      id: 2,
      name: 'Airport',
      currency: 'USD',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];
  @override
  Future<ProductAvailabilityRulesSnapshot> listProductAvailabilityRules(
    int productId,
  ) async => const ProductAvailabilityRulesSnapshot(
    productId: 11,
    rules: <AvailabilityRule>[],
  );
  @override
  Future<AvailabilityPreview> previewProductAvailability(
    int productId, {
    int? variantId,
    int? branchId,
    String? channel,
    required String dateTime,
  }) async {
    previewRequests.add(<Object?>[variantId, branchId, channel]);
    return AvailabilityPreview.fromJson(<String, dynamic>{
      'isScheduledAvailable': true,
      'reason': 'no_schedule_restriction',
      'matchedRuleId': null,
      'matchedScope': null,
      'matchedLevel': null,
      'productVariantId': variantId,
      'branchId': branchId,
      'channel': channel,
      'timezone': 'Asia/Damascus',
    });
  }

  @override
  Future<VariantPriceOverridesSnapshot> listVariantPriceOverrides(
    int variantId,
  ) async => VariantPriceOverridesSnapshot(
    variantId: variantId,
    basePrice: PriceAmount.parse('5.00'),
    overrides: const <VariantPriceOverride>[],
  );
  @override
  Future<EffectiveVariantPrice> getEffectiveVariantPrice(
    int variantId, {
    int? branchId,
    String? channel,
  }) async {
    effectiveRequests.add(<Object?>[variantId, branchId, channel]);
    return EffectiveVariantPrice(
      variantId: variantId,
      basePrice: PriceAmount.parse('5.00'),
      effectivePrice: PriceAmount.parse('5.50'),
      matchedScope: 'branch',
      matchedOverrideId: 1,
      branchId: branchId,
      channel: channel,
    );
  }

  @override
  Future<List<OperationalAvailabilityOverride>> listProductOperationalOverrides(
    int productId,
  ) async => const <OperationalAvailabilityOverride>[];
  @override
  Future<List<OperationalAvailabilityOverride>> listVariantOperationalOverrides(
    int variantId,
  ) async => const <OperationalAvailabilityOverride>[];
  @override
  Future<OperationalAvailabilityPreview> previewVariantOperationalAvailability(
    int productId,
    int variantId, {
    required int branchId,
    required String channel,
  }) async {
    operationalRequests.add(<Object?>[variantId, branchId, channel]);
    return _availablePreview(variantId, branchId, channel);
  }

  @override
  Future<OperationalAvailabilityPreview> previewProductOperationalAvailability(
    int productId, {
    required int branchId,
    required String channel,
  }) async {
    operationalRequests.add(<Object?>[null, branchId, channel]);
    return _availablePreview(null, branchId, channel);
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

class _PriceErrorWorkspaceRepository extends _WorkspaceRepository {
  int effectiveAttempts = 0;

  @override
  Future<EffectiveVariantPrice> getEffectiveVariantPrice(
    int variantId, {
    int? branchId,
    String? channel,
  }) async {
    effectiveAttempts++;
    throw StateError('price resolver failed');
  }
}

Map<String, dynamic> _variant([int id = 12, String name = 'Regular']) =>
    <String, dynamic>{
      'id': id,
      'productId': 11,
      'name': name,
      'nameAr': name == 'Large' ? 'كبير' : 'عادي',
      'basePrice': 5,
      'isDefault': id == 12,
      'isActive': true,
      'sortOrder': 0,
    };

OperationalAvailabilityPreview _availablePreview(
  int? variantId,
  int branchId,
  String channel,
) => OperationalAvailabilityPreview.fromJson(<String, dynamic>{
  'productId': 11,
  'productVariantId': variantId,
  'branchId': branchId,
  'channel': channel,
  'isOperationallyAvailable': true,
  'status': 'available',
  'matchedLevel': null,
  'matchedScope': null,
  'matchedRecordId': null,
  'remainingQuantity': null,
  'unavailableUntil': null,
  'reason': 'no_operational_override',
});
