import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/features/cafe_configuration/controllers/discount_settings_cubit.dart';
import 'package:windows_application/features/cafe_configuration/controllers/discount_permissions_cubit.dart';
import 'package:windows_application/features/cafe_configuration/models/discount_settings.dart';
import 'package:windows_application/features/cafe_configuration/repositories/discount_settings_repository.dart';
import 'package:windows_application/features/cafe_configuration/views/discount_settings_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

class SettingsFake implements DiscountSettingsRepository {
  SavedDiscountSettings current = const SavedDiscountSettings(
    draft: DiscountSettingsDraft(),
    version: 0,
    engineReady: false,
  );
  Object? readError, saveError;
  Completer<SavedDiscountSettings>? pendingRead, pendingSave;
  final writes = <Map<String, dynamic>>[];
  Set<String> grants = {
    'discounts.view',
    'discounts.manage',
    'discounts.apply_manual',
    'discounts.apply_configured',
  };
  @override
  Future<SavedDiscountSettings> read() async {
    if (readError != null) throw readError!;
    return pendingRead?.future ?? current;
  }

  @override
  Future<SavedDiscountSettings> save(
    DiscountSettingsDraft draft,
    int version,
  ) async {
    writes.add(draft.toJson(version));
    if (saveError != null) throw saveError!;
    if (pendingSave != null) return pendingSave!.future;
    return current = SavedDiscountSettings(
      draft: draft,
      version: version + 1,
      engineReady: false,
    );
  }

  @override
  Future<Set<String>> managerPermissions() async => grants;
  @override
  Future<Set<String>> replaceManagerPermissions(
    Set<String> permissions,
  ) async => grants = {...permissions};
}

void main() {
  test(
    'defaults and replacement contain the eight legacy fields, the V3 policy and expectedVersion',
    () {
      final j = const DiscountSettingsDraft().toJson(0);
      expect(j.keys.toSet(), {
        'automaticEnabled',
        'selectionStrategy',
        'combinationMode',
        'orderDiscountBehavior',
        'couponBehavior',
        'manualBehavior',
        'maximumTotalDiscountPercent',
        'allowAutomaticSuppression',
        'allowMultipleDiscounts',
        'stackingMode',
        'allowMultipleCoupons',
        'allowCouponWithConfigured',
        'allowOrderAfterItemDiscounts',
        'maximumDiscountsPerOrder',
        'conflictResolution',
        'expectedVersion',
      });
      expect(j['automaticEnabled'], false);
      expect(j['maximumTotalDiscountPercent'], null);
      expect(j['allowAutomaticSuppression'], true);
    },
  );
  for (final value in [
    '0',
    '-1',
    '100.0001',
    '0.00001',
    'NaN',
    'Infinity',
    'bad',
  ]) {
    test(
      'invalid cap $value is blocked',
      () => expect(
        DiscountSettingsDraft(maximumTotalDiscountPercent: value).isValid,
        false,
      ),
    );
  }
  for (final value in ['', '0.0001', '15.1234', '100']) {
    test(
      'valid cap $value is accepted',
      () => expect(
        DiscountSettingsDraft(maximumTotalDiscountPercent: value).isValid,
        true,
      ),
    );
  }
  test('after_items requires disjoint_items', () {
    expect(
      const DiscountSettingsDraft(orderDiscountBehavior: 'after_items').isValid,
      false,
    );
    expect(
      const DiscountSettingsDraft(
        orderDiscountBehavior: 'after_items',
        combinationMode: 'disjoint_items',
      ).isValid,
      true,
    );
  });
  test('reset edits draft only and explicit save advances version', () async {
    final r = SettingsFake();
    final cubit = DiscountSettingsCubit(r);
    await cubit.load();
    cubit.update(
      cubit.state.draft.copyWith(
        policy: const DiscountCafePolicy(allowMultipleDiscounts: true),
      ),
    );
    await cubit.save();
    expect(r.writes.length, 1);
    expect(cubit.state.saved!.version, 1);
    cubit.resetDraft();
    expect(cubit.state.dirty, true);
    expect(r.writes.length, 1);
    await cubit.save();
    expect(r.writes.last['expectedVersion'], 1);
    expect(cubit.state.dirty, false);
    await cubit.close();
  });
  test(
    'conflict preserves draft and requires explicit review before resubmission',
    () async {
      final r = SettingsFake();
      final cubit = DiscountSettingsCubit(r);
      await cubit.load();
      final draft = cubit.state.draft.copyWith(
        maximumTotalDiscountPercent: '7',
      );
      cubit.update(draft);
      r.current = const SavedDiscountSettings(
        draft: DiscountSettingsDraft(selectionStrategy: 'priority'),
        version: 8,
        engineReady: false,
      );
      r.saveError = const ApiException(
        message: 'secret raw text',
        statusCode: 409,
        code: 'DISCOUNT_SETTINGS_VERSION_CONFLICT',
      );
      await cubit.save();
      expect(cubit.state.draft, draft);
      expect(cubit.state.saved!.version, 8);
      await cubit.save();
      expect(r.writes.length, 1);
      cubit.acknowledgeConflict();
      r.saveError = null;
      await cubit.save();
      expect(r.writes.last['expectedVersion'], 8);
      await cubit.close();
    },
  );
  test(
    'duplicate save is blocked and late completion after revocation ignored',
    () async {
      final r = SettingsFake();
      final cubit = DiscountSettingsCubit(r);
      await cubit.load();
      cubit.update(cubit.state.draft.copyWith(selectionStrategy: 'priority'));
      r.pendingSave = Completer();
      final first = cubit.save();
      await cubit.save();
      expect(r.writes.length, 1);
      cubit.revoke();
      r.pendingSave!.complete(r.current);
      await first;
      expect(cubit.state.status, DiscountSettingsStatus.forbidden);
      expect(cubit.state.saved, null);
      await cubit.close();
    },
  );
  test('forbidden fails closed; unknown load failure is retryable', () async {
    final r = SettingsFake()
      ..readError = const ApiException(message: 'private', statusCode: 403);
    final c = DiscountSettingsCubit(r);
    await c.load();
    expect(c.state.status, DiscountSettingsStatus.forbidden);
    r.readError = StateError('private stack');
    await c.load();
    expect(c.state.errorCode, 'load');
    r.readError = null;
    await c.load();
    expect(c.state.saved!.version, 0);
    await c.close();
  });
  test('load completion after close is ignored', () async {
    final r = SettingsFake()..pendingRead = Completer();
    final c = DiscountSettingsCubit(r);
    final load = c.load();
    await c.close();
    r.pendingRead!.complete(r.current);
    await load;
  });
  test(
    'engineReady false blocks activation independently of creation capability',
    () async {
      final r = SettingsFake();
      final cubit = DiscountSettingsCubit(r);
      await cubit.load();
      cubit.update(cubit.state.draft.copyWith(automaticEnabled: true));
      expect(cubit.state.canSave, false);
      await cubit.save();
      expect(r.writes, isEmpty);
      await cubit.close();
    },
  );
  test(
    'permission replacement retains four existing grants while settings and suppression are independent',
    () async {
      final r = SettingsFake();
      final cubit = DiscountPermissionsCubit(r);
      await cubit.load();
      cubit.toggle('discounts.settings.manage', true);
      await cubit.save();
      expect(r.grants.length, 5);
      expect(r.grants.contains('discounts.automatic.suppress'), false);
      cubit.toggle('discounts.automatic.suppress', true);
      cubit.toggle('discounts.settings.manage', false);
      await cubit.save();
      expect(r.grants.contains('discounts.manage'), true);
      expect(r.grants.contains('discounts.settings.manage'), false);
      await cubit.close();
    },
  );
  for (final language in ['en', 'ar']) {
    for (final width in [390.0, 1000.0]) {
      testWidgets(
        '$language settings pointer draft/reset/save at width $width',
        (tester) async {
          await serviceLocator.reset();
          setupServiceLocator(useBackend: false);
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final r = SettingsFake(), c = DiscountSettingsCubit(r);
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
          final cap = find.byKey(const Key('ds-cap'));
          await tester.ensureVisible(cap);
          await tester.enterText(cap, '12.5');
          await tester.pump();
          final save = find.byKey(const Key('ds-save'));
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(r.writes.single['maximumTotalDiscountPercent'], '12.5');
          await tester.tap(find.byKey(const Key('ds-reset')));
          await tester.pumpAndSettle();
          expect(c.state.draft.maximumTotalDiscountPercent, '');
          expect(r.writes.length, 1);
          expect(tester.takeException(), null);
          await tester.pumpWidget(const SizedBox());
          await c.close();
          await serviceLocator.reset();
        },
      );
    }
  }
}
