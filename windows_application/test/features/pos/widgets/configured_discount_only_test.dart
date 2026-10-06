import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_print_cubit.dart';
import 'package:windows_application/features/pos/models/applied_discount.dart';
import 'package:windows_application/features/pos/models/available_discount.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/features/pos/widgets/discount_dialog.dart';
import 'package:windows_application/features/pos/widgets/pos_cart_panel.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import '../discount_engine_fixture.dart';

void main() {
  tearDown(() async => serviceLocator.reset());
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language POS offers saved policies and codes without free entry',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        setupServiceLocator(useBackend: false);
        final printCubit = serviceLocator<PosPrintCubit>();
        final repository = _ConfiguredRepository();
        final cubit = PosCubit(repository: repository);
        await cubit.loadInitialData();
        await cubit.addCustomizedProductToCart(publishedItem());
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: printCubit),
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
        expect(find.widgetWithText(TextButton, l.d2SourceAdHoc), findsNothing);
        expect(find.text(l.d2OptionalReason), findsNothing);
        await tester.ensureVisible(find.text(l.posAddDiscount));
        await tester.tap(find.text(l.posAddDiscount));
        await tester.pumpAndSettle();
        expect(find.byType(DiscountDialog), findsOneWidget);
        expect(find.text('Saved policy'), findsOneWidget);
        expect(find.text(l.posCouponCode), findsOneWidget);
        expect(find.text(l.discountFormValue), findsNothing);
        await tester.tap(find.text('Saved policy'));
        await tester.pumpAndSettle();
        expect(repository.lastReview!.toJson()['intent'], {
          'source': 'configured_manual',
          'discountId': 1,
        });
        expect(repository.operations, 0);
        expect(
          find.byKey(const Key('discount-review-confirm')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await cubit.close();
        await printCubit.close();
      },
    );
  }

  test(
    'backend cart rejects an arbitrary discount value before assigning it',
    () async {
      final repository = EngineFake()..caps = const DiscountCapabilities();
      final cubit = PosCubit(repository: repository);
      await cubit.loadInitialData();
      await cubit.addCustomizedProductToCart(publishedItem());
      await cubit.applyDiscount(
        const AppliedDiscount(
          id: 'free',
          title: 'Free',
          type: AppliedDiscountType.fixedAmount,
          value: 2.5,
        ),
      );
      expect(cubit.state.appliedDiscount, isNull);
      expect(cubit.state.discounts.errorCode, 'DISCOUNT_AD_HOC_DISABLED');
      expect(repository.lastReview, isNull);
      expect(repository.operations, 0);
      await cubit.close();
    },
  );
}

class _ConfiguredRepository extends EngineFake {
  @override
  Future<List<AvailableDiscount>> getAvailableDiscounts(int orderId) async =>
      const [
        AvailableDiscount(
          id: 'saved-1',
          backendId: 1,
          title: 'Saved policy',
          subtitle: 'Configured',
          badgeLabel: '10%',
          type: AvailableDiscountType.percentage,
          value: 10,
        ),
      ];
}
