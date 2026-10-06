import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/discounts/models/discount_detail.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import '../discount_engine_fixture.dart';

void main() {
  test(
    'all discounts and allocation decimal strings are preserved exactly',
    () {
      final j = savedJson();
      j['totals'] = totalsJson(total: '9007199254740993.99');
      final s = SavedDiscountState.fromJson(j);
      expect(s.totals.total, '9007199254740993.99');
      expect(s.discounts.map((d) => d.amount), ['1.00', '2.00']);
      expect(s.discounts.last.allocations.single.amount, '2.00');
      expect(s.explicitIntent, null);
    },
  );
  test('legacy paid rows keep null metadata and empty allocations', () {
    final d = SavedDiscount.fromJson(discountJson(1, '2.00', source: null));
    expect(d.source, null);
    expect(d.stage, null);
    expect(d.settingsVersion, null);
    expect(d.allocations, isEmpty);
  });
  for (final value in [1.01, '1.1', 'NaN', '-1.00', '1e2']) {
    test(
      'invalid new money $value is rejected instead of rounded',
      () => expect(() => exactMoney(value), throwsFormatException),
    );
  }
  test(
    'capabilities distinguish isolated creation and unavailable activation',
    () {
      final c = DiscountCapabilities.fromJson({
        'contractVersion': 2,
        'settingsVersion': 0,
        'engineReady': false,
        'automaticPolicyCreationAvailable': true,
        'automaticEnabled': true,
        'supportsDiscountReview': true,
        'supportsPaymentQuote': true,
        'requiresPaymentQuote': true,
        'canSuppressAutomatic': false,
      });
      expect(c.automaticPolicyCreationAvailable, true);
      expect(c.engineReady, false);
      expect(c.supportsDiscountReview, true);
    },
  );
  test(
    'Automatic detail retains priority, conditions, targets, and explicit null code',
    () {
      final d = DiscountDetail.fromJson({
        'id': 1,
        'name': 'Auto',
        'code': null,
        'applicationMode': 'automatic',
        'priority': 1000,
        'type': 'fixed',
        'scope': 'product',
        'value': 2,
        'conditions': 'Preserved',
        'targetProductIds': [4],
        'customerEligibilityMode': 'all',
        'branchIds': [1],
        'productVariantSelections': [
          {
            'productId': 4,
            'variantMode': 'selected',
            'variantIds': [30],
          },
        ],
        'isActive': true,
        'appliesToAllBranches': false,
      });
      final j = d.toUpsertRequest().toJson();
      expect(j['applicationMode'], 'automatic');
      expect(j['priority'], 1000);
      expect(j['code'], null);
      expect(j['conditions'], 'Preserved');
      expect(j['productVariantSelections'], [
        {
          'productId': 4,
          'variantMode': 'selected',
          'variantIds': [30],
        },
      ]);
    },
  );
  test(
    'omitted priority is omitted; intentional Code-to-Automatic clear is null',
    () {
      final j = const DiscountUpsertRequest(
        name: 'Auto',
        applicationMode: 'automatic',
        type: 'fixed',
        scope: 'order',
        value: 2,
        isActive: false,
        appliesToAllBranches: true,
      ).toJson();
      expect(j.containsKey('priority'), false);
      expect(j.containsKey('code'), true);
      expect(j['code'], null);
    },
  );
  test('source requests do not mix intents or log coupon text', () {
    expect(DiscountReviewRequest.manual(3).toJson()['intent'], {
      'source': 'configured_manual',
      'discountId': 3,
    });
    final code = DiscountReviewRequest.code('PRIVATE');
    expect(code.toString(), isNot(contains('PRIVATE')));
    expect(code.toJson()['intent'], {'source': 'code', 'code': 'PRIVATE'});
    expect(DiscountReviewRequest.remove().toJson(), {
      'action': 'remove',
      'paymentMethodId': null,
    });
    expect(
      DiscountReviewRequest.suppress(1, 'reason').toJson()['reason'],
      'reason',
    );
    expect(DiscountReviewRequest.undo(1).toJson()['action'], 'undo');
  });
  test(
    'new requests send header 2 on every order path; capabilities remain operational',
    () async {
      final dio = Dio();
      final captured = <RequestOptions>[];
      // Install after the production interceptor, with no network or auth bypass.
      final client = DioApiClient(dio: dio);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            captured.add(o);
            h.resolve(
              Response(requestOptions: o, statusCode: 200, data: {'data': {}}),
            );
          },
        ),
      );
      for (final path in [
        'orders',
        'orders/42/items',
        'orders/42/discounts/preview',
        'orders/42/discount-operations/id',
        'orders/42/payment-quote',
        'orders/42/pay',
      ]) {
        await client.post(path, data: {});
      }
      expect(
        captured.every((o) => o.headers['X-Discount-Contract'] == '2'),
        true,
      );
    },
  );
  test(
    'quoted tender and amount are transported without decimal conversion',
    () async {
      final dio = Dio(), captured = <Map<String, dynamic>>[];
      final api = DioApiClient(dio: dio);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            captured.add(Map<String, dynamic>.from(o.data as Map));
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'data': {
                    'method': 'cash',
                    'amount': 10,
                    'status': 'completed',
                  },
                },
              ),
            );
          },
        ),
      );
      final r = PosRepository(apiClient: api);
      final q = PaymentQuote.fromJson({
        ...resolutionJson(),
        'quoteId': 'quote',
        'paymentMethodId': 7,
        'method': 'cash',
        'expiresInSeconds': 300,
      });
      await r.payQuotedOrder(
        orderId: 42,
        quote: q,
        amount: '10.00',
        idempotencyKey: 'durable',
      );
      expect(captured.single, {
        'amount': '10.00',
        'idempotencyKey': 'durable',
        'quoteId': 'quote',
        'paymentMethodId': 7,
        'method': 'cash',
      });
      final zero = PaymentQuote.fromJson({
        ...resolutionJson(total: '0.00'),
        'quoteId': 'zero',
        'paymentMethodId': null,
        'method': null,
        'expiresInSeconds': 300,
      });
      await r.payQuotedOrder(
        orderId: 42,
        quote: zero,
        amount: '0.00',
        idempotencyKey: 'zero',
      );
      expect(captured.last.containsKey('method'), false);
      expect(captured.last.containsKey('paymentMethodId'), false);
    },
  );
}
