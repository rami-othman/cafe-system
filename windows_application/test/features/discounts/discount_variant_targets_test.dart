import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/discounts/controllers/discount_targets_cubit.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_detail.dart';
import 'package:windows_application/features/discounts/models/discount_form_references.dart';
import 'package:windows_application/features/discounts/models/discount_product_selection.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/discounts/widgets/discount_product_targets.dart';
import 'package:windows_application/l10n/app_localizations.dart';

const product = DiscountFormReference(
  id: 1,
  name: 'Coffee',
  nameAr: 'قهوة',
  isActive: true,
);
const variant = DiscountFormReference(
  id: 101,
  name: 'Large',
  nameAr: 'كبير',
  isActive: true,
);
const unavailable = DiscountFormReference(
  id: 102,
  name: 'Old size',
  isActive: true,
  archivedAt: '2026-10-01',
);
DiscountUpsertRequest request(
  String scope,
  List<DiscountProductSelection> selections,
) => DiscountUpsertRequest(
  name: 'Policy',
  applicationMode: 'manual',
  type: 'fixed',
  scope: scope,
  value: 0,
  isActive: true,
  appliesToAllBranches: true,
  targetProductIds: [1, 2],
  productVariantSelections: selections,
);
void main() {
  test(
    'full detail roundtrip strips metadata, preserves policy fields and normalizes time',
    () {
      final input = <String, dynamic>{
        'id': 1,
        'name': 'Policy',
        'applicationMode': 'code',
        'code': 'CODE',
        'type': 'fixed',
        'scope': 'product',
        'value': '0.00',
        'fixedAmountBasis': 'per_unit',
        'isActive': true,
        'appliesToAllBranches': false,
        'branchIds': [3],
        'targetProductIds': [1, 2],
        'targetCategoryIds': [],
        'description': 'description',
        'conditions': 'conditions',
        'startDate': '2026-10-01',
        'endDate': null,
        'startTime': '22:00:00',
        'endTime': '02:00:00',
        'activeDays': ['Mon'],
        'minimumOrderAmount': '0.00',
        'maximumDiscountAmount': null,
        'usageLimit': 10,
        'usageLimitPerCustomer': 2,
        'perCustomerDailyUsageLimit': 1,
        'customerEligibilityMode': 'selected_customers',
        'customerIds': [7],
        'customerGroupIds': [8],
        'paymentMethodIds': [9],
        'channelKeys': ['pos'],
        'bundleRequirements': [
          {'productId': 1, 'quantity': 2},
        ],
        'productVariantSelections': [
          {
            'productId': 1,
            'variantMode': 'selected',
            'variantIds': [101],
            'product': {
              'id': 1,
              'name': 'Coffee',
              'isActive': true,
              'archivedAt': null,
            },
            'variants': [
              {
                'id': 101,
                'name': 'Large',
                'isActive': true,
                'archivedAt': null,
              },
            ],
          },
          {'productId': 2, 'variantMode': 'all', 'variantIds': []},
        ],
      };
      final json = DiscountDetail.fromJson(input).toUpsertRequest().toJson();
      for (final key in [
        'name',
        'applicationMode',
        'code',
        'type',
        'scope',
        'fixedAmountBasis',
        'isActive',
        'appliesToAllBranches',
        'branchIds',
        'targetProductIds',
        'description',
        'conditions',
        'startDate',
        'endDate',
        'activeDays',
        'usageLimit',
        'usageLimitPerCustomer',
        'perCustomerDailyUsageLimit',
        'customerEligibilityMode',
        'customerIds',
        'customerGroupIds',
        'paymentMethodIds',
        'channelKeys',
        'bundleRequirements',
      ]) {
        expect(json[key], input[key], reason: key);
      }
      expect(json['startTime'], '22:00');
      expect(json['endTime'], '02:00');
      expect(json['value'], 0);
      expect(json['maximumDiscountAmount'], isNull);
      expect(json['productVariantSelections'], [
        {
          'productId': 1,
          'variantMode': 'selected',
          'variantIds': [101],
        },
        {'productId': 2, 'variantMode': 'all', 'variantIds': []},
      ]);
    },
  );
  for (final scope in ['order', 'category', 'bundle']) {
    test('$scope omits selections entirely', () {
      expect(
        request(scope, []).toJson().containsKey('productVariantSelections'),
        isFalse,
      );
    });
  }
  test(
    'empty selected, duplicate IDs, missing parents and all with IDs reject',
    () {
      for (final s in [
        const DiscountProductSelection(productId: 1, variantMode: 'selected'),
        const DiscountProductSelection(
          productId: 1,
          variantMode: 'selected',
          variantIds: [101, 101],
        ),
        const DiscountProductSelection(productId: 1, variantIds: [101]),
      ]) {
        expect(
          () => request('product', [
            s,
            const DiscountProductSelection(productId: 2),
          ]).toJson(),
          throwsArgumentError,
        );
      }
      expect(
        () => request('product', [
          const DiscountProductSelection(productId: 1),
        ]).toJson(),
        throwsArgumentError,
      );
    },
  );
  test('legacy detail defaults every product visibly to all', () {
    final detail = DiscountDetail.fromJson({
      'id': 1,
      'scope': 'product',
      'targetProductIds': [1, 2],
    });
    expect(detail.effectiveProductSelections.map((s) => s.variantMode), [
      'all',
      'all',
    ]);
    expect(
      detail.toUpsertRequest().toJson()['productVariantSelections'],
      hasLength(2),
    );
  });
  test(
    'unavailable selections persist until deliberate removal; selected to all clears IDs',
    () {
      final c = DiscountTargetsCubit(_Repository());
      addTearDown(c.close);
      c.hydrate([
        const DiscountProductSelection(
          productId: 1,
          product: product,
          variantMode: 'selected',
          variantIds: [101, 102],
          variants: [variant, unavailable],
        ),
      ]);
      expect(c.state.isValid, isFalse);
      expect(c.state.selections[1]!.variantIds, [101, 102]);
      c.setVariants(1, {101});
      expect(c.state.isValid, isTrue);
      c.setMode(1, 'all');
      expect(c.state.selections[1]!.variantIds, isEmpty);
      c.removeProduct(1);
      expect(c.state.selections, isEmpty);
    },
  );
  test('inactive and archived parent products both block save', () {
    for (final p in [
      const DiscountFormReference(id: 1, name: 'Old', isActive: false),
      const DiscountFormReference(
        id: 1,
        name: 'Old',
        isActive: true,
        archivedAt: 'date',
      ),
    ]) {
      expect(
        () => request('product', [
          DiscountProductSelection(productId: 1, product: p),
          const DiscountProductSelection(productId: 2),
        ]).toJson(),
        throwsArgumentError,
      );
    }
  });
  for (final id in [0, 1]) {
    test(
      '${id == 0 ? 'product' : 'variant'} search/paging keeps selections beyond 100',
      () async {
        final repo = _Repository();
        final c = DiscountTargetsCubit(repo);
        addTearDown(c.close);
        c.hydrate([
          const DiscountProductSelection(
            productId: 1,
            product: product,
            variantMode: 'selected',
            variantIds: [101],
            variants: [variant],
          ),
        ]);
        final first = c.load(productId: id, search: ' coffee ', page: 2);
        expect(repo.calls.last, (id, 'coffee', 2));
        repo.pending.last.complete(
          const DiscountReferencePage(
            items: [
              DiscountFormReference(id: 120, name: 'Later', isActive: true),
            ],
            currentPage: 2,
            lastPage: 6,
            total: 120,
          ),
        );
        await first;
        expect(c.state.pages[id]!.page.currentPage, 2);
        expect(c.state.selections[1]!.variantIds, [101]);
        if (id == 0) {
          c.setProducts({1, 120});
        } else {
          c.setVariants(1, {101, 120});
        }
        final next = c.load(productId: id, search: 'other', page: 1);
        repo.pending.last.complete(const DiscountReferencePage());
        await next;
        expect(
          id == 0
              ? c.state.selections.containsKey(120)
              : c.state.selections[1]!.variantIds.contains(120),
          isTrue,
        );
      },
    );
    test(
      '${id == 0 ? 'product' : 'variant'} stale response and retry/forbidden',
      () async {
        final repo = _Repository();
        final c = DiscountTargetsCubit(repo);
        addTearDown(c.close);
        c.hydrate([const DiscountProductSelection(productId: 1)]);
        final old = c.load(productId: id, search: 'old');
        final fresh = c.load(productId: id, search: 'new', page: 2);
        repo.pending[1].complete(
          const DiscountReferencePage(currentPage: 2, lastPage: 2),
        );
        await fresh;
        repo.pending[0].complete(const DiscountReferencePage(items: [product]));
        await old;
        expect(c.state.pages[id]!.search, 'new');
        expect(c.state.pages[id]!.page.currentPage, 2);
        expect(c.state.pages[id]!.page.items, isEmpty);
        final failed = c.load(productId: id);
        repo.pending.last.completeError(
          const ApiException(message: 'RAW SECRET', statusCode: 403),
        );
        await failed;
        expect(c.state.pages[id]!.error, 'forbidden');
        final retry = c.load(productId: id);
        repo.pending.last.complete(
          const DiscountReferencePage(items: [variant]),
        );
        await retry;
        expect(c.state.pages[id]!.error, isNull);
      },
    );
  }
  test(
    'scope reset and product removal reject in-flight variant responses',
    () async {
      final repo = _Repository();
      final c = DiscountTargetsCubit(repo);
      addTearDown(c.close);
      c.hydrate([const DiscountProductSelection(productId: 1)]);
      final load = c.load(productId: 1);
      c.removeProduct(1);
      repo.pending.last.complete(const DiscountReferencePage(items: [variant]));
      await load;
      expect(c.state.pages.containsKey(1), isFalse);
      final products = c.load();
      c.clear();
      repo.pending.last.complete(const DiscountReferencePage(items: [product]));
      await products;
      expect(c.state.pages, isEmpty);
    },
  );
  test('duplicate submissions invoke repository once', () async {
    final repo = _Repository();
    final c = DiscountsCubit(repository: repo);
    addTearDown(c.close);
    final saving = c.createDiscount(request('order', []));
    expect(await c.createDiscount(request('order', [])), isFalse);
    expect(repo.saves, 1);
    repo.save.completeError(StateError('RAW'));
    expect(await saving, isFalse);
    expect(c.state.errorMessage, DiscountsCubit.requestFailed);
  });
  for (final locale in ['en', 'ar']) {
    for (final size in [const Size(1280, 900), const Size(420, 700)]) {
      testWidgets('$locale targets interaction, RTL and layout ${size.width}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repository();
        final c = DiscountTargetsCubit(repo);
        addTearDown(c.close);
        c.hydrate([
          const DiscountProductSelection(
            productId: 1,
            product: product,
            variantMode: 'selected',
            variantIds: [101, 102],
            variants: [variant, unavailable],
          ),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: DiscountProductTargets(
                    controller: c,
                    enabled: true,
                    onChanged: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          Directionality.of(
            tester.element(find.byType(DiscountProductTargets)),
          ),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('discount-variants-selector-1')));
        await tester.pump();
        repo.pending.last.complete(
          const DiscountReferencePage(
            items: [variant],
            currentPage: 1,
            lastPage: 2,
            total: 101,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const Key('discount-reference-search')),
          'large',
        );
        await tester.pump();
        expect(repo.calls.last, (1, 'large', 1));
        repo.pending.last.complete(
          const DiscountReferencePage(items: [variant]),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'ar' ? 'تم' : 'Done').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('discount-variant-mode-1-all')));
        await tester.pump();
        expect(c.state.selections[1]!.variantIds, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('discount-remove-product-1')));
        await tester.pump();
        expect(c.state.selections, isEmpty);
      });
    }
  }
}

class _Repository extends DiscountsRepository {
  final calls = <(int, String, int)>[];
  final pending = <Completer<DiscountReferencePage>>[];
  final save = Completer<DiscountListItem>();
  int saves = 0;
  Future<DiscountReferencePage> load(int id, String search, int page) {
    calls.add((id, search, page));
    final c = Completer<DiscountReferencePage>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<DiscountReferencePage> getProducts({
    String search = '',
    int page = 1,
  }) => load(0, search, page);
  @override
  Future<DiscountReferencePage> getVariants(
    int productId, {
    String search = '',
    int page = 1,
  }) => load(productId, search, page);
  @override
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request) {
    saves++;
    return save.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
