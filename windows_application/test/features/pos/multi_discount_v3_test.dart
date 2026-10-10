import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/core/utils/currency_formatter.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_print_cubit.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/features/pos/widgets/discount_engine_widgets.dart';
import 'package:windows_application/features/pos/widgets/pos_cart_panel.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'discount_engine_fixture.dart';

/// Discount System V3 Phase 3: the POS keeps an ordered desired intent list and
/// always reviews the COMPLETE list with `action: "set"`. Money comes from the
/// backend only.
Map<String, dynamic> _line(
  int id,
  String name,
  String amount, {
  String source = 'configured_manual',
  int? sequence,
  bool capped = false,
}) => {
  'id': id,
  'discountId': id,
  'name': name,
  'source': source,
  'stage': 'order',
  'type': 'percentage',
  'value': '10.00',
  'amount': amount,
  'settingsVersion': 3,
  'sequence': ?sequence,
  'capped': capped,
  'allocations': [
    {'orderItemId': 10, 'amount': amount},
  ],
};

Map<String, dynamic> _intent(String source, int id) => {
  'source': source,
  'discountId': id,
};

class V3Fake extends EngineFake {
  V3Fake() {
    caps = const DiscountCapabilities(
      contractVersion: 2,
      supportsDiscountReview: true,
      supportsPaymentQuote: true,
      requiresPaymentQuote: true,
      supportsMultipleDiscounts: true,
      maximumRequestedDiscounts: 10,
    );
    saved = {
      ...savedJson(),
      'explicitIntent': null,
      'explicitIntents': <Map<String, dynamic>>[],
      'discounts': <Map<String, dynamic>>[],
    };
  }

  /// What the next preview returns: applied lines, excluded entries, totals.
  List<Map<String, dynamic>> reviewDiscounts = [];
  List<Map<String, dynamic>> reviewExcluded = [];
  Map<String, dynamic> reviewTotals = totalsJson();

  void savedWith(
    List<Map<String, dynamic>> intents,
    List<Map<String, dynamic>> discounts,
  ) => saved = {
    ...saved,
    'explicitIntent': intents.isEmpty ? null : intents.first,
    'explicitIntents': intents,
    'discounts': discounts,
  };

  @override
  Future<DiscountReview> previewDiscount(
    int id,
    DiscountReviewRequest request, {
    int? paymentMethodId,
  }) async {
    previews++;
    lastReview = request;
    if (previewError != null) throw previewError!;
    return DiscountReview.fromJson({
      ...resolutionJson(),
      'discounts': reviewDiscounts,
      'excluded': reviewExcluded,
      'totals': reviewTotals,
      'reviewId': 'review-$previews',
      'before': totalsJson(),
      'after': reviewTotals,
      'removals': saved['discounts'],
      'additions': reviewDiscounts,
    });
  }
}

void main() {
  late V3Fake r;
  late PosCubit c;
  setUp(() async {
    r = V3Fake();
    c = PosCubit(repository: r);
    await c.loadInitialData();
    await c.addCustomizedProductToCart(publishedItem());
  });
  tearDown(() async {
    if (!c.isClosed) await c.close();
    await serviceLocator.reset();
  });

  group('desired intent list (action = set)', () {
    test(
      'first discount sends a one-item set, never the legacy apply',
      () async {
        await c.previewDiscountAddition(
          const DesiredDiscountIntent.configured(5),
        );
        expect(r.lastReview!.body, {
          'action': 'set',
          'intents': [
            {'source': 'configured_manual', 'discountId': 5},
          ],
        });
      },
    );

    test(
      'adding keeps every saved intent in backend order and appends the new one',
      () async {
        r.savedWith(
          [_intent('configured_manual', 1), _intent('code', 3)],
          [_line(1, 'Latte 10%', '1.00', sequence: 1)],
        );
        await c.previewDiscountAddition(
          const DesiredDiscountIntent.coupon('WELCOME'),
        );
        expect(r.lastReview!.body['action'], 'set');
        // A saved coupon is kept by id: its text is never stored or returned.
        expect(r.lastReview!.body['intents'], [
          {'source': 'configured_manual', 'discountId': 1},
          {'source': 'code', 'discountId': 3},
          {'source': 'code', 'code': 'WELCOME'},
        ]);
        expect(r.lastReview!.body.containsKey('amount'), isFalse);
      },
    );

    test(
      'removing one sends the remaining list; removing the last clears',
      () async {
        r.savedWith(
          [_intent('configured_manual', 1), _intent('code', 3)],
          [
            _line(1, 'Latte 10%', '1.00', sequence: 1),
            _line(3, 'WELCOME', '0.90', source: 'code', sequence: 2),
          ],
        );
        await c.previewDiscountRemoval(1);
        expect(r.lastReview!.body, {
          'action': 'set',
          'intents': [
            {'source': 'code', 'discountId': 3},
          ],
        });
        r.savedWith(
          [_intent('code', 3)],
          [_line(3, 'WELCOME', '1.00', source: 'code', sequence: 1)],
        );
        await c.previewDiscountRemoval(3);
        expect(r.lastReview!.body, {'action': 'remove'});
      },
    );

    test(
      'an older backend uses apply for the first discount but never silently replaces an existing one',
      () async {
        r.caps = const DiscountCapabilities(
          contractVersion: 2,
          supportsDiscountReview: true,
          supportsPaymentQuote: true,
        );
        await c.previewDiscountAddition(
          const DesiredDiscountIntent.configured(2),
        );
        expect(r.lastReview!.body, {
          'action': 'apply',
          'intent': {'source': 'configured_manual', 'discountId': 2},
        });

        r.savedWith(
          [_intent('configured_manual', 1)],
          [_line(1, 'Latte', '1.00')],
        );
        final previews = r.previews;
        final added = await c.previewDiscountAddition(
          const DesiredDiscountIntent.configured(3),
        );
        expect(added, isFalse);
        expect(r.previews, previews, reason: 'no request may be sent');
        expect(c.state.discounts.errorCode, 'DISCOUNT_CLIENT_UPDATE_REQUIRED');
        expect(c.state.discounts.review, isNull);

        await c.previewDiscountRemoval(1);
        expect(r.lastReview!.body, {'action': 'remove'});
      },
    );

    test(
      'the review shows the authoritative applied and excluded result, including a displaced discount',
      () async {
        r.savedWith(
          [_intent('configured_manual', 1)],
          [_line(1, 'Discount A', '1.00', sequence: 1)],
        );
        // best_saving keeps B and excludes the previously applied A.
        r.reviewDiscounts = [_line(2, 'Discount B', '2.00', sequence: 1)];
        r.reviewExcluded = [
          {
            'position': 1,
            'discountId': 1,
            'name': 'Discount A',
            'source': 'configured_manual',
            'code': 'MULTIPLE_DISCOUNTS_DISABLED',
            'conflictsWith': [2],
          },
        ];
        await c.previewDiscountAddition(
          const DesiredDiscountIntent.configured(2),
        );
        final resolution = c.state.discounts.review!.resolution;
        expect(resolution.discounts.single.discountId, 2);
        expect(resolution.excluded.single.discountId, 1);
        expect(resolution.excluded.single.code, 'MULTIPLE_DISCOUNTS_DISABLED');
        expect(resolution.excluded.single.conflictsWith, [2]);
      },
    );

    test('saved state without V3 fields still parses (old orders)', () {
      final legacy = SavedDiscountState.fromJson({
        ...savedJson(intent: _intent('configured_manual', 1)),
      });
      expect(legacy.explicitIntents.single.discountId, 1);
      expect(legacy.discounts.first.sequence, isNull);
      expect(legacy.discounts.first.capped, isFalse);
      expect(DesiredDiscountIntent.fromSaved(legacy), const [
        DesiredDiscountIntent.configured(1),
      ]);
    });

    test('a removed promotion carries its name; older backends omit it', () {
      final withName = SavedDiscountState.fromJson(
        savedJson(
          suppressions: [
            {
              'discountId': 7,
              'name': 'Happy hour',
              'reason': 'Declined',
              'actorId': 1,
            },
          ],
        ),
      );
      expect(withName.suppressions.single.name, 'Happy hour');
      final older = SavedDiscountState.fromJson(
        savedJson(
          suppressions: [
            {'discountId': 7, 'reason': 'Declined', 'actorId': 1},
          ],
        ),
      );
      expect(older.suppressions.single.name, isNull);
    });
  });

  group('errors and payment', () {
    for (final code in [
      'DISCOUNT_DUPLICATE_INTENT',
      'DISCOUNT_CLIENT_UPDATE_REQUIRED',
      'MAXIMUM_DISCOUNT_COUNT_EXCEEDED',
    ]) {
      test('$code is kept as a stable code for a localized message', () async {
        r.previewError = ApiException(message: 'raw', code: code);
        await c.previewDiscountAddition(
          const DesiredDiscountIntent.configured(1),
        );
        expect(c.state.discounts.errorCode, code);
      });
    }

    test(
      'a stale discount review is never applied: the operation reports it',
      () async {
        await c.previewDiscountAddition(
          const DesiredDiscountIntent.configured(1),
        );
        r.operationError = const ApiException(
          message: 'stale',
          code: 'DISCOUNT_REVIEW_STALE',
          statusCode: 422,
        );
        expect(
          await c.confirmDiscountReview(c.state.discounts.review!.reviewId),
          isFalse,
        );
        expect(c.state.discounts.errorCode, 'DISCOUNT_REVIEW_STALE');
        expect(c.state.discounts.review, isNull);
      },
    );

    test(
      'a stale payment quote is refreshed and must be confirmed again',
      () async {
        expect(await c.obtainPaymentQuote(7), isTrue);
        final first = c.state.discounts.quote!.quoteId;
        r.payError = const ApiException(
          message: 'changed',
          code: 'ORDER_TOTAL_CHANGED',
          statusCode: 422,
        );
        await c.confirmQuotedPayment(first, '7.56');
        expect(c.state.discounts.errorCode, 'ORDER_TOTAL_CHANGED');
        expect(c.state.discounts.quote!.quoteId, isNot(first));
        expect(r.pays, 1);
      },
    );

    test(
      'an order reduced to zero by several discounts completes without a tender',
      () async {
        r.quotedTotal = '0.00';
        expect(await c.obtainPaymentQuote(null), isTrue);
        final quote = c.state.discounts.quote!;
        expect(quote.paymentMethodId, isNull);
        await c.confirmQuotedPayment(quote.quoteId, '0.00');
        expect(r.pays, 1);
        expect(r.paymentRequests.single.$3, isNull);
      },
    );
  });

  group('localized reason codes', () {
    for (final language in ['en', 'ar']) {
      testWidgets('$language maps every V3 code without exposing raw codes', (
        tester,
      ) async {
        late AppLocalizations l;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                l = AppLocalizations.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        const codes = [
          'MULTIPLE_DISCOUNTS_DISABLED',
          'SAME_ITEM_STACKING_DISABLED',
          'MULTIPLE_COUPONS_DISABLED',
          'COUPON_COMBINATION_NOT_ALLOWED',
          'ORDER_ITEM_COMBINATION_NOT_ALLOWED',
          'EXCLUSIVE_DISCOUNT_CONFLICT',
          'MAXIMUM_DISCOUNT_COUNT_EXCEEDED',
          'MAXIMUM_TOTAL_DISCOUNT_EXCEEDED',
          'DISCOUNT_CONFLICT',
          'DISCOUNT_ITEMS_NOT_ELIGIBLE',
        ];
        final messages = {
          for (final code in codes) localizedExclusionReason(l, code),
        };
        expect(messages.length, codes.length, reason: 'distinct messages');
        for (final message in messages) {
          expect(message, isNot(contains('_')));
          expect(message, isNot(l.d2Generic));
        }
        for (final code in [
          'DISCOUNT_DUPLICATE_INTENT',
          'DISCOUNT_CLIENT_UPDATE_REQUIRED',
          'DISCOUNT_REVIEW_STALE',
          'ORDER_TOTAL_CHANGED',
          ...codes,
        ]) {
          expect(localizedDiscountError(l, code), isNot(l.d2Generic));
        }
        expect(
          localizedDiscountError(l, 'DISCOUNT_DUPLICATE_INTENT'),
          l.d3Duplicate,
        );
        expect(
          localizedDiscountError(l, 'DISCOUNT_CLIENT_UPDATE_REQUIRED'),
          l.d2UpdateRequired,
        );
      });
    }
  });

  group('cart', () {
    for (final language in ['en', 'ar']) {
      testWidgets(
        '$language cart lists every applied discount, removes one by sending the rest, and keeps the review authoritative',
        (tester) async {
          tester.view.physicalSize = const Size(1100, 1400);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          setupServiceLocator(useBackend: false);
          r.savedWith(
            [
              _intent('configured_manual', 1),
              _intent('code', 3),
              _intent('configured_manual', 4),
            ],
            [
              _line(1, 'Latte 10%', '10.00', sequence: 1),
              _line(3, 'WELCOME', '18.00', source: 'code', sequence: 2),
            ],
          );
          r.saved = {
            ...r.saved,
            'totals': {
              'subtotal': '100.00',
              'discountTotal': '28.00',
              'taxTotal': '0.00',
              'total': '72.00',
            },
          };
          await c.refreshDiscountCapabilities();
          await c.refreshSavedDiscountState();
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: c),
                BlocProvider.value(value: serviceLocator<PosPrintCubit>()),
              ],
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: PosCartPanel()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(PosCartPanel)),
          );
          if (language == 'ar') {
            expect(
              Directionality.of(tester.element(find.byType(PosCartPanel))),
              TextDirection.rtl,
            );
          }
          // Authoritative lines in sequence (10 then 18, not 10% + 20%).
          expect(find.text('1. Latte 10%'), findsOneWidget);
          expect(find.text('2. WELCOME'), findsOneWidget);
          expect(find.text('-${CurrencyFormatter.format(10)}'), findsOneWidget);
          expect(find.text('-${CurrencyFormatter.format(18)}'), findsOneWidget);
          expect(find.text(l.d3TotalDiscounts), findsOneWidget);
          expect(find.text('-${CurrencyFormatter.format(28)}'), findsOneWidget);
          expect(find.text(l.d2SourceCode), findsOneWidget);
          // A selected intent the backend no longer applies stays visible.
          expect(find.byKey(const Key('discount-pending-4')), findsOneWidget);

          r.reviewDiscounts = [
            _line(3, 'WELCOME', '20.00', source: 'code', sequence: 1),
          ];
          r.reviewExcluded = [
            {
              'position': 2,
              'discountId': 4,
              'name': 'Cookie',
              'source': 'configured_manual',
              'code': 'SAME_ITEM_STACKING_DISABLED',
            },
          ];
          final remove = find.byKey(const Key('discount-remove-1'));
          await tester.ensureVisible(remove);
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(r.lastReview!.body, {
            'action': 'set',
            'intents': [
              {'source': 'code', 'discountId': 3},
              {'source': 'configured_manual', 'discountId': 4},
            ],
          });
          expect(find.text(l.d3Applied), findsWidgets);
          expect(find.text(l.d3NotApplied), findsOneWidget);
          expect(find.text(l.d3ReasonSameItem), findsOneWidget);
          expect(
            find.textContaining('SAME_ITEM_STACKING_DISABLED'),
            findsNothing,
          );
          await tester.tap(find.byKey(const Key('discount-review-confirm')));
          await tester.pumpAndSettle();
          expect(r.operations, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });
}
