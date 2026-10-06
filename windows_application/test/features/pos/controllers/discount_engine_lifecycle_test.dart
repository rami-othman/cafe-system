import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/backend_order.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import '../discount_engine_fixture.dart';

void main() {
  late EngineFake r;
  late PosCubit c;
  setUp(() async {
    r = EngineFake();
    c = PosCubit(repository: r);
    await c.loadInitialData();
  });
  tearDown(() async {
    if (!c.isClosed) await c.close();
  });
  test(
    'early published cart persists once and serial repeated taps retain pinned context',
    () async {
      r.createGate = Completer();
      final first = c.addCustomizedProductToCart(publishedItem());
      final second = c.addCustomizedProductToCart(publishedItem());
      await Future<void>.delayed(Duration.zero);
      expect(r.creates, 1);
      expect(c.state.isCartMutationInProgress, true);
      final request = r.createRequests.single;
      expect(request.publishedMenuVersionId, 12);
      expect(request.items.single.variantId, 30);
      expect(request.items.single.modifierOptionIds, [71]);
      expect(request.idempotencyKey, isNotEmpty);
      r.createGate!.complete(r.order());
      await Future.wait([first, second]);
      expect(r.creates, 1);
      expect(c.state.cartItems.single.quantity, 2);
      expect(c.state.discounts.saved!.discounts.length, 2);
    },
  );
  test(
    'lost create keeps cart and request; explicit recovery replays exact same identity',
    () async {
      r.createError = const ApiException(message: 'lost');
      expect(await c.addCustomizedProductToCart(publishedItem()), false);
      expect(c.state.cartItems, isNotEmpty);
      expect(c.state.discounts.createUncertain, true);
      await c.clearCart();
      expect(c.state.cartItems, isNotEmpty);
      expect(await c.addCustomizedProductToCart(publishedItem()), false);
      r.createError = null;
      await c.recoverCartCreation();
      expect(r.createRequests[0].toJson(), r.createRequests[1].toJson());
      expect(c.state.currentOrderId, 42);
      expect(c.state.discounts.createUncertain, false);
    },
  );
  test(
    'missing shift does not stage or duplicate a persistent cart item',
    () async {
      r.currentShift = null;
      await c.refreshShiftStatus();
      expect(await c.addCustomizedProductToCart(publishedItem()), false);
      expect(await c.addCustomizedProductToCart(publishedItem()), false);
      expect(c.state.cartItems, isEmpty);
      expect(c.state.currentOrderId, isNull);
      expect(c.state.discounts.createUncertain, false);
      expect(r.creates, 0);
      expect(c.state.cartMutationError, isNotNull);
    },
  );
  test(
    'compatible default keeps local cart until explicit authoritative review',
    () async {
      r.caps = const DiscountCapabilities(
        contractVersion: 2,
        supportsDiscountReview: true,
        supportsPaymentQuote: true,
      );
      await c.refreshDiscountCapabilities();
      await c.addCustomizedProductToCart(publishedItem());
      expect(r.creates, 0);
      expect(c.state.currentOrderId, null);
      expect(
        await c.previewDiscountChange(DiscountReviewRequest.manual(1)),
        true,
      );
      expect(r.creates, 1);
    },
  );
  test(
    'rapid quantity increments read latest confirmed quantity in serial queue',
    () async {
      await c.addCustomizedProductToCart(publishedItem());
      final id = c.state.cartItems.single.id;
      await Future.wait([c.increaseQuantity(id), c.increaseQuantity(id)]);
      expect(c.state.cartItems.single.quantity, 3);
    },
  );
  test('review is explicit and does not submit before confirmation', () async {
    await c.addCustomizedProductToCart(publishedItem());
    await c.previewDiscountChange(DiscountReviewRequest.manual(1));
    expect(r.operations, 0);
    final review = c.state.discounts.review!;
    expect(review.removals.length, 2);
    expect(review.additions.length, 2);
    await c.confirmDiscountReview(review.reviewId);
    expect(r.operations, 1);
    expect(r.operationRequests.single.$1, isNotEmpty);
  });
  test(
    'uncertain operation retains identity and never resubmits on an empty recovery',
    () async {
      await c.addCustomizedProductToCart(publishedItem());
      await c.previewDiscountChange(DiscountReviewRequest.code('SECRET'));
      r.operationError = const ApiException(message: 'lost');
      await c.confirmDiscountReview(c.state.discounts.review!.reviewId);
      expect(c.state.discounts.operationUncertain, true);
      final identity = c.state.discounts.operationId;
      expect(await c.recoverDiscountChange(), false);
      await c.confirmDiscountReview('old');
      expect(r.operations, 1);
      expect(c.state.discounts.operationId, identity);
      r.recovery = DiscountOperationResult(
        operationId: identity!,
        completed: true,
        result: SavedDiscountState.fromJson(r.saved),
      );
      expect(await c.recoverDiscountChange(), true);
      expect(c.state.discounts.operationUncertain, false);
    },
  );
  test('stale review clears confirmation; requires a new preview', () async {
    await c.addCustomizedProductToCart(publishedItem());
    await c.previewDiscountChange(DiscountReviewRequest.manual(1));
    final old = c.state.discounts.review!.reviewId;
    r.operationError = const ApiException(
      message: 'hidden',
      statusCode: 422,
      code: 'DISCOUNT_REVIEW_STALE',
    );
    await c.confirmDiscountReview(old);
    expect(c.state.discounts.review, null);
    await c.confirmDiscountReview(old);
    expect(r.operations, 1);
    expect(c.state.discounts.errorCode, 'DISCOUNT_REVIEW_STALE');
  });
  test(
    'explicit intent remains when applied rows disappear; never replaced locally',
    () async {
      await c.addCustomizedProductToCart(publishedItem());
      r.saved = savedJson(
        intent: {'source': 'configured_manual', 'discountId': 11},
      )..['discounts'] = [];
      await c.selectCustomer(null);
      await c.refreshSavedDiscountState();
      expect(c.state.discounts.saved!.explicitIntent!.discountId, 11);
      expect(c.state.discounts.saved!.discounts, isEmpty);
    },
  );
  test(
    'suppression survives cart updates; new cart clears suppression',
    () async {
      await c.addCustomizedProductToCart(publishedItem());
      r.saved = savedJson(
        suppressions: [
          {'discountId': 1, 'reason': 'Reviewed', 'actorId': 4},
        ],
      );
      await c.refreshSavedDiscountState();
      await c.increaseQuantity(c.state.cartItems.single.id);
      expect(c.state.discounts.saved!.suppressions.single.reason, 'Reviewed');
      await c.previewDiscountChange(DiscountReviewRequest.undo(1));
      expect(r.lastReview!.toJson()['action'], 'undo');
      await c.clearCart();
      expect(c.state.discounts.saved, null);
      expect(c.state.currentOrderId, null);
    },
  );
  test(
    'hold/resume refreshes authority and retained saved breakdown',
    () async {
      await c.addCustomizedProductToCart(publishedItem());
      await c.holdCurrentOrder();
      expect(r.status, 'held');
      await c.loadExistingOrder(42);
      expect(c.state.currentOrderStatus, 'draft');
      expect(c.state.discounts.totalsResolved, true);
    },
  );
  test('cart mutation invalidates quote and review', () async {
    await c.addCustomizedProductToCart(publishedItem());
    await c.obtainPaymentQuote(7);
    expect(c.state.discounts.quote!.paymentMethodId, 7);
    await c.increaseQuantity(c.state.cartItems.single.id);
    expect(c.state.discounts.quote, null);
  });
  test('tender change obtains a new quote with actual ID', () async {
    await c.addCustomizedProductToCart(publishedItem());
    await c.obtainPaymentQuote(7);
    final first = c.state.discounts.quote!.quoteId;
    await c.obtainPaymentQuote(9);
    expect(c.state.discounts.quote!.quoteId, isNot(first));
    expect(c.state.discounts.quote!.method, 'card');
    await c.confirmQuotedPayment(first, '10');
    expect(r.pays, 0);
  });
  for (final code in ['PAYMENT_QUOTE_REQUIRED', 'ORDER_TOTAL_CHANGED']) {
    test('$code refetches cheaper quote without retrying payment', () async {
      await c.addCustomizedProductToCart(publishedItem());
      await c.obtainPaymentQuote(7);
      final first = c.state.discounts.quote!.quoteId;
      r.payError = ApiException(
        message: 'private',
        statusCode: 422,
        code: code,
      );
      r.quotedTotal = '5.00';
      await c.confirmQuotedPayment(first, '10');
      expect(r.pays, 1);
      expect(c.state.discounts.quote!.resolution.totals.total, '5.00');
      expect(c.state.discounts.quote!.quoteId, isNot(first));
      expect(c.state.discounts.errorCode, code);
    });
  }
  test(
    'uncertain payment with empty read stays blocked; same identity read later confirms',
    () async {
      await c.addCustomizedProductToCart(publishedItem());
      await c.obtainPaymentQuote(7);
      r.payError = const ApiException(message: 'lost');
      expect(
        await c.confirmQuotedPayment(c.state.discounts.quote!.quoteId, '10'),
        PaymentCompletionStatus.uncertain,
      );
      final id = r.paymentRequests.single.$1;
      await c.checkUncertainPaymentStatus();
      expect(c.state.uncertainPaymentOrderId, 42);
      expect(r.pays, 1);
      r.paymentStatus = 'paid';
      r.status = 'paid';
      r.payments = [
        OrderPaymentIdentity(id: 1, status: 'completed', idempotencyKey: id),
      ];
      await c.checkUncertainPaymentStatus();
      expect(c.state.currentOrderId, null);
      expect(r.pays, 1);
      expect(c.state.pendingReceiptOrderId, 42);
    },
  );
  test('null tender zero quote preserves amount as received tender', () async {
    await c.addCustomizedProductToCart(publishedItem());
    r.quotedTotal = '0.00';
    await c.obtainPaymentQuote(null);
    await c.confirmQuotedPayment(c.state.discounts.quote!.quoteId, '0.00');
    expect(r.paymentRequests.single.$2, '0.00');
    expect(r.paymentRequests.single.$3, null);
  });
  test('unresolved authoritative state blocks payment', () async {
    await c.addCustomizedProductToCart(publishedItem());
    await c.obtainPaymentQuote(7);
    final quote = c.state.discounts.quote!.quoteId;
    r.savedError = StateError('offline');
    await c.refreshSavedDiscountState();
    await c.confirmQuotedPayment(quote, '10');
    expect(r.pays, 0);
  });
  test('late preview after disposal does not emit', () async {
    await c.addCustomizedProductToCart(publishedItem());
    r.previewGate = Completer();
    final future = c.previewDiscountChange(DiscountReviewRequest.manual(1));
    while (r.previews == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    await c.close();
    r.previewGate!.complete(
      DiscountReview.fromJson({
        ...resolutionJson(),
        'reviewId': 'r',
        'before': totalsJson(),
        'after': totalsJson(),
        'removals': [],
        'additions': [],
      }),
    );
    expect(await future, false);
  });
}
