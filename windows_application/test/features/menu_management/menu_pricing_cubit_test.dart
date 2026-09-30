import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/menu_pricing_cubit.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/menu_pricing_state.dart';
import 'package:windows_application/features/menu_management/pricing/models/menu_price_adjustment_models.dart';
import 'package:windows_application/features/menu_management/pricing/models/menu_pricing_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  group('MenuPricingCubit', () {
    test(
      'draft changes invalidate a late preview without replacing drafts',
      () async {
        final preview = Completer<MenuPriceAdjustment>();
        final repository = _PricingRepository(preview: preview.future);
        final cubit = MenuPricingCubit(repository: repository);
        await cubit.load(menuId: 1, branchId: 2, channel: 'pos');
        cubit.setDraft(const ManualPriceDraft.set(10, '12.00'));
        final pending = cubit.previewManual();
        cubit.setDraft(const ManualPriceDraft.set(10, '13.00'));
        preview.complete(_preview());
        expect(await pending, isFalse);
        expect(cubit.state.drafts[10]!.price, '13.00');
        expect(cubit.state.review, isNull);
      },
    );

    test(
      'context changes require discard and clear prior overview/drafts',
      () async {
        final repository = _PricingRepository();
        final cubit = MenuPricingCubit(repository: repository);
        await cubit.load(menuId: 1, branchId: 2, channel: 'pos');
        cubit.setDraft(const ManualPriceDraft.set(10, '12.00'));
        expect(
          await cubit.load(menuId: 3, branchId: 2, channel: 'pos'),
          isFalse,
        );
        expect(cubit.state.status, MenuPricingStatus.contextDiscardRequired);
        await cubit.discardAndLoad(menuId: 3, branchId: 2, channel: 'pos');
        expect(
          cubit.state.contextKey,
          const MenuPricingContextKey(3, 2, 'pos'),
        );
        expect(cubit.state.drafts, isEmpty);
      },
    );

    test('browsing changes preserve same-context drafts', () async {
      final repository = _PricingRepository();
      final cubit = MenuPricingCubit(repository: repository);
      await cubit.load(menuId: 1, branchId: 2, channel: 'pos');
      cubit.setDraft(const ManualPriceDraft.set(10, '12.00'));
      await cubit.load(
        menuId: 1,
        branchId: 2,
        channel: 'pos',
        search: 'coffee',
        categoryId: 4,
        page: 2,
      );
      expect(cubit.state.drafts[10]!.price, '12.00');
    });

    test(
      'duplicate apply is single-flight and uses displayed fingerprint',
      () async {
        final apply = Completer<MenuPriceAdjustment>();
        final repository = _PricingRepository(apply: apply.future);
        final cubit = MenuPricingCubit(repository: repository);
        await cubit.load(menuId: 1, branchId: 2, channel: 'pos');
        await cubit.previewBulk(
          operation: 'fixed_increase',
          amount: '1',
          roundingMode: 'no_rounding',
        );
        final review = cubit.state.review!;
        final first = cubit.apply(
          adjustmentId: review.id,
          fingerprint: review.fingerprint,
          acknowledgeOppositeDirection: false,
        );
        final second = cubit.apply(
          adjustmentId: review.id,
          fingerprint: review.fingerprint,
          acknowledgeOppositeDirection: false,
        );
        expect(await second, isFalse);
        expect(repository.applyCalls, 1);
        apply.complete(_preview(status: 'applied'));
        expect(await first, isTrue);
      },
    );

    test('uncertain apply recovers the original stored adjustment', () async {
      final repository = _PricingRepository(
        applyError: const ApiException(
          message: 'timeout',
          type: ApiErrorType.receiveTimeout,
        ),
        recovery: _preview(status: 'applied'),
      );
      final cubit = MenuPricingCubit(repository: repository);
      await cubit.load(menuId: 1, branchId: 2, channel: 'pos');
      await cubit.previewBulk(
        operation: 'fixed_increase',
        amount: '1',
        roundingMode: 'no_rounding',
      );
      final review = cubit.state.review!;
      expect(
        await cubit.apply(
          adjustmentId: review.id,
          fingerprint: review.fingerprint,
          acknowledgeOppositeDirection: false,
        ),
        isFalse,
      );
      expect(cubit.state.status, MenuPricingStatus.uncertain);
      expect(await cubit.recover(), isTrue);
      expect(repository.recoveredId, review.id);
      expect(cubit.state.hasSavedHandoff, isTrue);
    });

    test(
      'failed recovery preserves the unresolved adjustment and context lock',
      () async {
        final repository = _PricingRepository(
          applyError: const ApiException(
            message: 'timeout',
            type: ApiErrorType.receiveTimeout,
          ),
          recoveryError: const ApiException(
            message: 'lookup timeout',
            type: ApiErrorType.receiveTimeout,
          ),
        );
        final cubit = MenuPricingCubit(repository: repository);
        await cubit.load(menuId: 1, branchId: 2, channel: 'pos');
        await cubit.previewBulk(
          operation: 'fixed_increase',
          amount: '1',
          roundingMode: 'no_rounding',
        );
        final review = cubit.state.review!;
        await cubit.apply(
          adjustmentId: review.id,
          fingerprint: review.fingerprint,
          acknowledgeOppositeDirection: false,
        );

        expect(await cubit.recover(), isFalse);
        expect(cubit.state.status, MenuPricingStatus.uncertain);
        expect(cubit.state.review!.id, review.id);
        expect(cubit.state.review!.fingerprint, review.fingerprint);
        expect(cubit.state.blocksContextChange, isTrue);
        expect(
          await cubit.load(menuId: 3, branchId: 2, channel: 'pos'),
          isFalse,
        );
        expect(
          cubit.state.contextKey,
          const MenuPricingContextKey(1, 2, 'pos'),
        );
        expect(await cubit.recover(), isFalse);
        expect(repository.recoveredId, review.id);
      },
    );

    test(
      'rejected preview cannot be applied again without a fresh preview',
      () async {
        final repository = _PricingRepository(
          applyError: const ApiException(
            message: 'stale',
            type: ApiErrorType.server,
            code: 'MENU_PRICING_PREVIEW_STALE',
          ),
        );
        final cubit = MenuPricingCubit(repository: repository);
        await cubit.load(menuId: 1, branchId: 2, channel: 'pos');
        await cubit.previewBulk(
          operation: 'fixed_increase',
          amount: '1',
          roundingMode: 'no_rounding',
        );
        final review = cubit.state.review!;

        expect(
          await cubit.apply(
            adjustmentId: review.id,
            fingerprint: review.fingerprint,
            acknowledgeOppositeDirection: false,
          ),
          isFalse,
        );
        expect(cubit.state.status, MenuPricingStatus.stale);
        expect(cubit.state.review!.fingerprint, review.fingerprint);
        expect(cubit.state.isReviewApplyCandidate, isFalse);
        expect(
          await cubit.apply(
            adjustmentId: review.id,
            fingerprint: review.fingerprint,
            acknowledgeOppositeDirection: false,
          ),
          isFalse,
        );
        expect(repository.applyCalls, 1);
      },
    );
  });
}

class _PricingRepository extends MenuCatalogRepository {
  _PricingRepository({
    this._preview,
    this._apply,
    this.applyError,
    this._recovery,
    this.recoveryError,
  });
  final Future<MenuPriceAdjustment>? _preview;
  final Future<MenuPriceAdjustment>? _apply;
  final ApiException? applyError;
  final ApiException? recoveryError;
  final MenuPriceAdjustment? _recovery;
  int applyCalls = 0;
  int? recoveredId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<MenuPricingOverview> getMenuPricingOverview({
    required int menuId,
    required int branchId,
    required String channel,
    String search = '',
    int? categoryId,
    int page = 1,
    int perPage = 25,
  }) async => _overview(menuId, branchId, channel, page);
  @override
  Future<MenuPriceAdjustment> previewMenuPriceAdjustment(
    int menuId,
    Map<String, dynamic> request,
  ) => _preview ?? Future<MenuPriceAdjustment>.value(_previewAdjustment());
  @override
  Future<MenuPriceAdjustment> applyMenuPriceAdjustment(
    int menuId,
    int adjustmentId,
    Map<String, dynamic> request,
  ) {
    applyCalls++;
    if (applyError != null) {
      return Future<MenuPriceAdjustment>.error(applyError!);
    }
    return _apply ??
        Future<MenuPriceAdjustment>.value(
          _previewAdjustment(status: 'applied'),
        );
  }

  @override
  Future<MenuPriceAdjustment> getMenuPriceAdjustment(
    int menuId,
    int adjustmentId,
  ) async {
    recoveredId = adjustmentId;
    if (recoveryError != null) {
      return Future<MenuPriceAdjustment>.error(recoveryError!);
    }
    return _recovery ?? _previewAdjustment();
  }
}

MenuPricingOverview _overview(
  int menuId,
  int branchId,
  String channel,
  int page,
) => MenuPricingOverview.fromJson(<String, dynamic>{
  'context': <String, dynamic>{
    'menuId': menuId,
    'branchId': branchId,
    'channel': channel,
    'currency': 'SYP',
  },
  'items': const <dynamic>[],
  'pagination': <String, dynamic>{'page': page, 'perPage': 25, 'total': 0},
  'scope': const <String, dynamic>{
    'adjustableVariantCount': 1,
    'excludedVariantCount': 0,
  },
});

MenuPriceAdjustment _preview({String status = 'previewed'}) =>
    _previewAdjustment(status: status);
MenuPriceAdjustment _previewAdjustment({String status = 'previewed'}) =>
    MenuPriceAdjustment.fromJson(<String, dynamic>{
      'id': 44,
      'status': status,
      'fingerprint': 'a' * 64,
      'context': const <String, dynamic>{
        'menuId': 1,
        'branchId': 2,
        'channel': 'pos',
      },
      'operation': 'manual_changes',
      'roundingMode': 'no_rounding',
      'roundingStep': null,
      'summary': const <String, dynamic>{'oppositeDirectionCount': 0},
      'items': <dynamic>[
        <String, dynamic>{
          'variantId': 10,
          'productName': 'Coffee',
          'variantName': 'Regular',
          'action': 'set',
          'originalEffectivePrice': '10.00',
          'originalSource': 'base',
          'rawCalculatedPrice': '12.00',
          'finalNewPrice': '12.00',
          'finalSource': 'menu',
          'difference': '2.00',
          'finalMovement': 'increase',
          'oppositeDirection': false,
          'configurationEffect': 'create_override',
          'hadMenuOverride': false,
        },
      ],
    });
