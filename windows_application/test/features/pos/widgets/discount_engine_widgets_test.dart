import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/features/pos/widgets/discount_engine_widgets.dart';
import 'package:windows_application/features/pos/widgets/quoted_payment_dialog.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import '../discount_engine_fixture.dart';

void main() {
  for (final language in ['en', 'ar']) {
    for (final width in [380.0, 900.0]) {
      testWidgets(
        '$language quote uses real tender tap and text entry at width $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final r = EngineFake();
          final cubit = PosCubit(repository: r);
          await cubit.loadInitialData();
          await cubit.addCustomizedProductToCart(publishedItem());
          await tester.pumpWidget(
            BlocProvider.value(
              value: cubit,
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: QuotedPaymentDialog()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Both authoritative lines, numbered in backend application order.
          expect(find.text('1. Saved 1'), findsOneWidget);
          expect(find.text('2. Saved 2'), findsOneWidget);
          expect(
            find.text(language == 'en' ? 'Automatic promotion' : 'عرض تلقائي'),
            findsNWidgets(2),
          );
          expect(find.text('-2.00'), findsOneWidget);
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Till cash').last);
          await tester.pumpAndSettle();
          expect(cubit.state.discounts.quote!.paymentMethodId, 7);
          await tester.enterText(
            find.byKey(const Key('quoted-amount')),
            '10.00',
          );
          await tester.pump();
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('quoted-payment-confirm')),
                )
                .onPressed,
            isNotNull,
          );
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
          await cubit.close();
        },
      );
    }
    testWidgets('$language errors never expose unknown server content', (
      tester,
    ) async {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              l = AppLocalizations.of(c);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        localizedDiscountError(l, 'coupon SECRET stacktrace'),
        l.d2Generic,
      );
      expect(
        localizedDiscountError(l, 'ORDER_TOTAL_CHANGED'),
        l.d2QuoteChanged,
      );
      expect(
        localizedDiscountError(l, 'DISCOUNT_SUPPRESSION_FORBIDDEN'),
        l.d2Forbidden,
      );
      expect(
        localizedDiscountError(l, 'DISCOUNT_ITEMS_NOT_ELIGIBLE'),
        l.d2Eligibility,
      );
    });
    testWidgets('$language lost operation closes only after GET confirmation', (
      tester,
    ) async {
      final r = EngineFake();
      final cubit = PosCubit(repository: r);
      await cubit.loadInitialData();
      await cubit.addCustomizedProductToCart(publishedItem());
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDiscountReview(
                    context,
                    cubit,
                    DiscountReviewRequest.manual(1),
                  ),
                  child: const Text('Open review'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(r.operations, 0);
      r.operationError = const ApiException(message: 'lost response');
      r.recovery = DiscountOperationResult(
        operationId: 'recovery',
        completed: true,
        result: SavedDiscountState.fromJson(r.saved),
      );
      await tester.tap(find.byKey(const Key('discount-review-confirm')));
      await tester.pumpAndSettle();
      expect(r.operations, 1);
      expect(cubit.state.discounts.operationUncertain, false);
      expect(find.text('Open review'), findsOneWidget);
      expect(find.byKey(const Key('discount-review-confirm')), findsNothing);
      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(Scaffold))).d2Review,
        ),
        findsNothing,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    });
  }
}
