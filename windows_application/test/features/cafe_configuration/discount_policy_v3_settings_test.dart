import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/cafe_configuration/controllers/discount_settings_cubit.dart';
import 'package:windows_application/features/cafe_configuration/models/discount_settings.dart';
import 'package:windows_application/features/cafe_configuration/views/discount_settings_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'discount_settings_test.dart' show SettingsFake;

/// Discount V3 Phase 3: the Cafe Discount Policy screen.
const DiscountSettingsDraft _legacyHidden = DiscountSettingsDraft(
  selectionStrategy: 'priority',
  combinationMode: 'disjoint_items',
  orderDiscountBehavior: 'after_items',
  couponBehavior: 'follow_combination_rules',
  manualBehavior: 'follow_combination_rules',
  allowAutomaticSuppression: false,
  policy: DiscountCafePolicy(
    allowMultipleDiscounts: true,
    maximumDiscountsPerOrder: 3,
  ),
);

SettingsFake _fake([DiscountSettingsDraft draft = _legacyHidden]) =>
    SettingsFake()
      ..current = SavedDiscountSettings(
        draft: draft,
        version: 5,
        engineReady: false,
      );

void main() {
  group('policy draft', () {
    test(
      'turning multiple discounts off keeps the dormant maximum and every hidden legacy field',
      () async {
        final r = _fake();
        final c = DiscountSettingsCubit(r);
        await c.load();
        expect(c.state.draft.policy.maximumDiscountsPerOrder, 3);
        c.update(
          c.state.draft.copyWith(
            policy: c.state.draft.policy.copyWith(
              allowMultipleDiscounts: false,
            ),
          ),
        );
        expect(c.state.draft.policy.effectiveMaximumDiscounts, 1);
        await c.save();
        final body = r.writes.single;
        expect(body['allowMultipleDiscounts'], false);
        expect(body['maximumDiscountsPerOrder'], 3);
        expect(body['expectedVersion'], 5);
        // Legacy engine fields are not shown but are never reset by a save.
        expect(body['selectionStrategy'], 'priority');
        expect(body['combinationMode'], 'disjoint_items');
        expect(body['orderDiscountBehavior'], 'after_items');
        expect(body['couponBehavior'], 'follow_combination_rules');
        expect(body['allowAutomaticSuppression'], false);
        expect(body['automaticEnabled'], false);
        await c.close();
      },
    );

    for (final count in [0, 11]) {
      test('maximum discounts $count is invalid and cannot be saved', () async {
        final c = DiscountSettingsCubit(_fake());
        await c.load();
        c.update(
          c.state.draft.copyWith(
            policy: c.state.draft.policy.copyWith(
              maximumDiscountsPerOrder: count,
            ),
          ),
        );
        expect(c.state.draft.isValid, false);
        expect(c.state.canSave, false);
        await c.close();
      });
    }

    test(
      'reset restores public defaults but keeps the hidden legacy fields',
      () async {
        final c = DiscountSettingsCubit(_fake());
        await c.load();
        c.resetDraft();
        expect(c.state.draft.policy, const DiscountCafePolicy());
        expect(c.state.draft.maximumTotalDiscountPercent, '');
        expect(c.state.draft.combinationMode, 'disjoint_items');
        expect(c.state.draft.selectionStrategy, 'priority');
        expect(c.state.dirty, true);
        await c.close();
      },
    );
  });

  for (final language in ['en', 'ar']) {
    for (final width in [700.0, 1200.0]) {
      testWidgets(
        '$language Cafe Discount Policy screen at $width edits every V3 control in business language',
        (tester) async {
          await serviceLocator.reset();
          setupServiceLocator(useBackend: false);
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final r = _fake(
            _legacyHidden.copyWith(
              policy: const DiscountCafePolicy(maximumDiscountsPerOrder: 3),
            ),
          );
          final c = DiscountSettingsCubit(r);
          await c.load();
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: c),
                BlocProvider.value(value: serviceLocator<AuthSessionCubit>()),
              ],
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: DiscountSettingsScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(DiscountSettingsScreen)),
          );
          if (language == 'ar') {
            expect(
              Directionality.of(
                tester.element(find.byType(DiscountSettingsScreen)),
              ),
              TextDirection.rtl,
            );
          }
          expect(find.text(l.ds3Title), findsOneWidget);
          // No engine jargon and no Automatic Promotions controls.
          for (final hidden in [
            l.dsAutomatic,
            l.dsLowest,
            l.dsDisjoint,
            l.dsCouponBehavior,
            l.dsManualBehavior,
            l.dsAllowSuppression,
          ]) {
            expect(find.text(hidden), findsNothing);
          }
          for (final raw in [
            'disjoint_items',
            'lowest_saving',
            'same_item_allowed',
          ]) {
            expect(find.textContaining(raw), findsNothing);
          }
          // Multiple discounts off: combining controls are shown but inactive,
          // and the dormant maximum keeps its saved value.
          SwitchListTile tile(String key) =>
              tester.widget<SwitchListTile>(find.byKey(Key(key)));
          expect(tile('ds-multiple-coupons').onChanged, isNull);
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('ds-max-discounts')))
                .enabled,
            false,
          );
          expect(find.text('3'), findsOneWidget);
          expect(find.text(l.ds3OneDiscount), findsOneWidget);
          // The disabled group explains how to enable it.
          expect(find.text(l.ds4CombiningOffHint), findsOneWidget);
          expect(find.text(l.ds4StatusSaved), findsOneWidget);
          // Wide: the live summary sits beside the settings; narrow: after.
          final summaryTop = tester
              .getTopLeft(find.byKey(const Key('ds-summary')))
              .dy;
          final switchTop = tester
              .getTopLeft(find.byKey(const Key('ds-allow-multiple')))
              .dy;
          expect(summaryTop < switchTop, width >= 1100);

          Future<void> tap(String key) async {
            final finder = find.byKey(Key(key));
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          await tap('ds-allow-multiple');
          expect(tile('ds-multiple-coupons').onChanged, isNotNull);
          expect(find.text(l.ds4CombiningOffHint), findsNothing);
          expect(find.text(l.ds4StatusUnsaved), findsNWidgets(2));
          // The stepper changes the count by one within 1..10.
          final increase = find.byTooltip(l.ds4Increase);
          await tester.ensureVisible(increase);
          await tester.pumpAndSettle();
          await tester.tap(increase);
          await tester.pumpAndSettle();
          expect(c.state.draft.policy.maximumDiscountsPerOrder, 4);
          await tap('ds-stacking-same_item_allowed');
          await tap('ds-multiple-coupons');
          await tap('ds-coupon-configured');
          await tap('ds-order-after-items');
          final max = find.byKey(const Key('ds-max-discounts'));
          await tester.ensureVisible(max);
          await tester.enterText(max, '4');
          await tester.pump();
          final cap = find.byKey(const Key('ds-cap'));
          await tester.ensureVisible(cap);
          await tester.enterText(cap, '20');
          await tester.pump();
          await tap('ds-conflict-priority');
          await tap('ds-save');
          final body = r.writes.single;
          expect(body['allowMultipleDiscounts'], true);
          expect(body['stackingMode'], 'same_item_allowed');
          expect(body['allowMultipleCoupons'], true);
          expect(body['allowCouponWithConfigured'], true);
          expect(body['allowOrderAfterItemDiscounts'], true);
          expect(body['maximumDiscountsPerOrder'], 4);
          expect(body['maximumTotalDiscountPercent'], '20');
          expect(body['conflictResolution'], 'priority');
          expect(body['combinationMode'], 'disjoint_items');
          expect(c.state.saved!.version, 6);
          expect(c.state.dirty, false);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await c.close();
          await serviceLocator.reset();
        },
      );
    }
  }
}
