import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/core/utils/backend_datetime.dart';
import 'package:windows_application/core/utils/currency_formatter.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/pos/models/available_discount.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/pos/widgets/discount_card.dart';
import 'package:windows_application/features/pos/widgets/discount_engine_widgets.dart';
import 'package:windows_application/features/printer/services/receipt_renderer.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

import '../../support/cashier_test_harness.dart';

/// Discount hardening, Flutter side: the Employee boundary (sidebar and deep
/// links), localized coupon errors, "Valid until", and discount money display.
void main() {
  group('Employee boundary', () {
    tearDown(() async {
      appRouter.go(AppRoutes.pos);
      await serviceLocator.reset();
    });

    for (final String role in <String>['employee', 'cashier']) {
      testWidgets('$role sidebar hides Discounts but keeps the POS', (
        WidgetTester tester,
      ) async {
        await setupCashierLocator(role: role);
        await _pumpSidebar(tester, role);

        expect(find.text('Discounts'), findsNothing);
        expect(find.text('POS'), findsOneWidget);
        expect(find.text('Orders'), findsOneWidget);
      });

      testWidgets('$role deep links into Discounts administration redirect', (
        WidgetTester tester,
      ) async {
        await setupCashierLocator(role: role);
        for (final String path in <String>[
          AppRoutes.discounts,
          AppRoutes.discountCreate,
          AppRoutes.discountSettings,
          AppRoutes.cafeConfigurationDiscountSettings,
        ]) {
          appRouter.go(path);
          await pumpApp(tester);
          expect(
            appRouter.state.uri.path,
            isNot(startsWith(AppRoutes.discounts)),
            reason: '$path must not open for $role',
          );
          expect(
            appRouter.state.uri.path,
            isNot(AppRoutes.cafeConfigurationDiscountSettings),
            reason: '$path must not open for $role',
          );
          expect(find.text('Discounts & Coupons'), findsNothing);
        }
      });
    }

    for (final String role in <String>['owner', 'manager']) {
      testWidgets('$role keeps the Discounts sidebar entry and route', (
        WidgetTester tester,
      ) async {
        await setupCashierLocator(role: role);
        await _pumpSidebar(tester, role);
        expect(find.text('Discounts'), findsOneWidget);

        appRouter.go(AppRoutes.discounts);
        await pumpApp(tester);
        expect(appRouter.state.uri.path, AppRoutes.discounts);
        expect(find.text('Discounts & Coupons'), findsOneWidget);
      });
    }
  });

  group('localized coupon errors', () {
    test('invalid/unavailable and throttled coupons read in English', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      expect(
        localizedDiscountError(en, 'DISCOUNT_NOT_FOUND'),
        en.d4CouponInvalid,
      );
      expect(
        localizedDiscountError(
          en,
          const ApiException(
            message: 'x',
            statusCode: 429,
            code: 'COUPON_ATTEMPTS_THROTTLED',
          ),
        ),
        en.d4CouponThrottled,
      );
      expect(en.d4CouponThrottled, contains('Wait'));
    });

    test('and in Arabic, never leaking the English text', () {
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      expect(
        localizedDiscountError(ar, 'DISCOUNT_NOT_FOUND'),
        ar.d4CouponInvalid,
      );
      expect(
        localizedDiscountError(ar, 'COUPON_ATTEMPTS_THROTTLED'),
        ar.d4CouponThrottled,
      );
      for (final String text in <String>[
        ar.d4CouponInvalid,
        ar.d4CouponThrottled,
        ar.discountsAccessDenied,
      ]) {
        expect(RegExp(r'[A-Za-z]').hasMatch(text), isFalse, reason: text);
      }
    });
  });

  group('Valid until', () {
    test(
      'the repository reads a branch-local end date as a calendar day',
      () async {
        final PosRepository repository = PosRepository(
          apiClient: _AvailableApi(<Map<String, Object?>>[
            <String, Object?>{
              'id': 1,
              'name': 'Day policy',
              'type': 'percentage',
              'value': 10,
              'badge': '10% OFF',
              'validUntil': '2026-10-20',
              'validUntilKind': 'date',
              'eligible': true,
            },
          ]),
        );

        final AvailableDiscount discount =
            (await repository.getAvailableDiscounts(5)).single;

        expect(discount.validUntilIsDate, isTrue);
        expect(discount.validUntil, DateTime(2026, 10, 20));
        expect(
          discount.subtitle,
          isEmpty,
          reason: 'no hard-coded English line',
        );
      },
    );

    test('a legacy instant is shown in the order branch timezone', () async {
      final PosRepository repository = PosRepository(
        apiClient: _AvailableApi(<Map<String, Object?>>[
          <String, Object?>{
            'id': 2,
            'name': 'Legacy',
            'type': 'fixed',
            'value': 5,
            'validUntil': '2026-10-20T22:30:00Z',
            'validUntilKind': 'instant',
            'validUntilTimezone': 'Asia/Damascus',
          },
          <String, Object?>{
            'id': 3,
            'name': 'Pacific',
            'type': 'fixed',
            'value': 5,
            'validUntil': '2026-10-20T22:30:00Z',
            'validUntilKind': 'instant',
            'validUntilTimezone': 'Pacific/Pago_Pago',
          },
          <String, Object?>{
            'id': 4,
            'name': 'Old server',
            'type': 'fixed',
            'value': 5,
            'validUntil': '2026-10-20 22:30:00',
          },
        ]),
      );

      final List<AvailableDiscount> discounts = await repository
          .getAvailableDiscounts(5);

      expect(discounts[0].validUntilIsDate, isFalse);
      // 22:30 UTC is 01:30 on the 21st in Damascus (UTC+3) ...
      expect(discounts[0].validUntil!.day, 21);
      expect(discounts[0].validUntil!.hour, 1);
      // ... and 11:30 on the 20th in Pago Pago (UTC-11).
      expect(discounts[1].validUntil!.day, 20);
      expect(discounts[1].validUntil!.hour, 11);
      // A pre-kind server sent the bare instant: still an instant, in the cafe zone.
      expect(discounts[2].validUntilIsDate, isFalse);
      expect(discounts[2].validUntil!.hour, 1);
    });

    test(
      'an unknown zone falls back to the cafe zone and dates stay dates',
      () {
        expect(
          parseBackendDateTimeIn('2026-10-20T22:30:00Z', 'Nowhere/Land')!.hour,
          1,
        );
        expect(parseBackendDateTimeIn('2026-10-20T22:30:00Z', null)!.hour, 1);
        expect(
          parseBackendDateTimeIn('2026-10-20', 'Pacific/Pago_Pago'),
          DateTime.parse('2026-10-20'),
        );
      },
    );

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the card shows a localized date in ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        late BuildContext captured;
        await tester.pumpWidget(
          _localized(
            locale,
            Builder(
              builder: (BuildContext context) {
                captured = context;
                return DiscountCard(
                  discount: AvailableDiscount(
                    id: '1',
                    title: 'Day policy',
                    subtitle: '',
                    badgeLabel: '10% OFF',
                    type: AvailableDiscountType.percentage,
                    value: 10,
                    validUntil: DateTime(2026, 10, 20),
                    validUntilIsDate: true,
                  ),
                  onApply: () {},
                );
              },
            ),
          ),
        );

        final String line = discountSubtitle(
          captured,
          AvailableDiscount(
            id: '1',
            title: 't',
            subtitle: '',
            badgeLabel: 'b',
            type: AvailableDiscountType.percentage,
            value: 10,
            validUntil: DateTime(2026, 10, 20),
            validUntilIsDate: true,
          ),
        );
        expect(find.text(line), findsOneWidget);
        expect(
          line,
          locale.languageCode == 'en'
              ? startsWith('Valid until ')
              : startsWith('صالح حتى '),
        );
        expect(line, isNot(contains('2026-10-20')), reason: 'no raw date');
        expect(line, isNot(contains('T00:00')));
      });
    }

    testWidgets(
      'an eligibility note outranks the date and an absent end hides the line',
      (WidgetTester tester) async {
        late BuildContext captured;
        await tester.pumpWidget(
          _localized(
            const Locale('en'),
            Builder(
              builder: (BuildContext context) {
                captured = context;
                return const SizedBox();
              },
            ),
          ),
        );
        AvailableDiscount make({String subtitle = '', DateTime? until}) =>
            AvailableDiscount(
              id: '1',
              title: 't',
              subtitle: subtitle,
              badgeLabel: 'b',
              type: AvailableDiscountType.fixedAmount,
              value: 5,
              validUntil: until,
              validUntilIsDate: true,
            );

        expect(
          discountSubtitle(
            captured,
            make(subtitle: 'Minimum not met', until: DateTime(2026, 10, 20)),
          ),
          'Minimum not met',
        );
        expect(discountSubtitle(captured, make()), isEmpty);
      },
    );
  });

  group('money formatting', () {
    test(
      'discountMoney follows the POS convention and keeps zero unsigned',
      () {
        expect(discountMoney('1234.50'), CurrencyFormatter.format(1234.5));
        expect(
          discountMoney('1234.50', negative: true),
          '-${CurrencyFormatter.format(1234.5)}',
        );
        expect(
          discountMoney('0.00', negative: true),
          CurrencyFormatter.format(0),
        );
        expect(discountMoney('oops', negative: true), 'oops');
        expect(discountMoney(null), isEmpty);
      },
    );

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'configured, coupon and automatic lines and the total share one format (${locale.languageCode})',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            _localized(
              locale,
              const DiscountBreakdown(
                discounts: <SavedDiscount>[
                  _Line('Configured', 'configured_manual', '1234.50', 1),
                  _Line('Coupon', 'code', '10.00', 2),
                  _Line('Promo', 'automatic', '0.25', 3),
                ],
                total: '1244.75',
              ),
            ),
          );

          expect(
            find.text('-${CurrencyFormatter.format(1234.5)}'),
            findsOneWidget,
          );
          expect(find.text('-${CurrencyFormatter.format(10)}'), findsOneWidget);
          expect(
            find.text('-${CurrencyFormatter.format(0.25)}'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<Text>(find.byKey(const Key('discount-lines-total')))
                .data,
            '-${CurrencyFormatter.format(1244.75)}',
          );
          expect(
            find.textContaining('1234.50'),
            findsNothing,
            reason: 'no raw backend string',
          );
          // Numbers keep a left-to-right run inside the RTL page.
          final Text amount = tester.widget<Text>(
            find.text('-${CurrencyFormatter.format(1234.5)}'),
          );
          expect(amount.textDirection, TextDirection.ltr);
        },
      );
    }

    testWidgets('exact totals use the same format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localized(
          const Locale('en'),
          const ExactDiscountTotals(
            totals: DiscountTotals(
              subtotal: '1500.00',
              discountTotal: '250.50',
              taxTotal: '0.00',
              total: '1249.50',
            ),
          ),
        ),
      );
      for (final double value in <double>[1500, 250.5, 0, 1249.5]) {
        expect(find.text(CurrencyFormatter.format(value)), findsOneWidget);
      }
    });

    test(
      'receipt discount lines use the receipt amount format on any paper width',
      () {
        String money(double v) => v.toStringAsFixed(2);

        expect(receiptDiscountAmount('1234.50', money), '-1234.50');
        expect(receiptDiscountAmount('0.00', money), '0.00');
        expect(receiptDiscountAmount('n/a', money), '-n/a');
      },
    );
  });
}

class _AvailableApi extends DioApiClient {
  _AvailableApi(this.rows) : super(dio: Dio());
  final List<Map<String, Object?>> rows;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool suppressAuthenticationFailure = false,
    bool debugMenuScheduleSave = false,
  }) async => rows;
}

class _Line extends SavedDiscount {
  const _Line(String name, String source, String amount, int sequence)
    : super(
        name: name,
        source: source,
        type: 'fixed',
        value: amount,
        amount: amount,
        sequence: sequence,
      );
}

Widget _localized(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _pumpSidebar(WidgetTester tester, String role) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthSessionCubit>.value(
        value: serviceLocator<AuthSessionCubit>(),
        child: Scaffold(
          body: AppSidebar(activeLabel: 'pos', actorRole: role),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
