import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/app/localization/app_locale_cubit.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/repositories/auth_session_storage_contract.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/views/pos_screen.dart';
import 'package:windows_application/features/pos/widgets/discount_dialog.dart';
import 'package:windows_application/features/pos/widgets/payment_dialog.dart';
import 'package:windows_application/features/pos/widgets/pos_action_buttons.dart';
import 'package:windows_application/features/pos/widgets/pos_cart_panel.dart';
import 'package:windows_application/features/pos/widgets/product_customization_dialog.dart';
import 'package:windows_application/features/pos/widgets/receipt_preview_dialog.dart';

/// Authenticated Windows acceptance for Plan 1 Create/Edit variant targeting.
///
/// Runs the compiled Windows app against an ISOLATED, explicitly identified
/// testing backend (never operational data) and logs in through the real
/// login screen. Fixtures expected on that backend: products 10 (Acc Tea,
/// variants 10/11/12), 11 (Acc Cake), 12 (Acc Latte, 45 variants) plus 45
/// filler products. Required defines:
///   --dart-define=API_BASE_URL=http://localhost:18100/api/v1
///   --dart-define=ACCEPTANCE_COMPOSE=(compose file that owns accept-backend)
/// The test stops/starts only the `accept-backend` service of that compose
/// project to produce a genuine search failure.
final _captureKey = GlobalKey();
const _screenshots = String.fromEnvironment('ACCEPTANCE_SCREENSHOTS');

const String _compose = String.fromEnvironment('ACCEPTANCE_COMPOSE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'discount variant Create/Edit acceptance (EN then AR) on Windows',
    (WidgetTester tester) async {
      await binding.setSurfaceSize(null);
      WidgetController.hitTestWarningShouldBeFatal = true;
      expect(_compose, isNotEmpty, reason: 'ACCEPTANCE_COMPOSE must be set');
      await tester.runAsync(() async {
        final identity = await Process.run('docker', [
          'compose',
          '-f',
          _compose,
          'exec',
          '-T',
          'accept-backend',
          'php',
          'artisan',
          'tinker',
          '--execute',
          "dump(app()->environment(), config('database.connections.pgsql.host'), DB::selectOne('select current_database() as name')->name);",
        ]);
        expect(identity.exitCode, 0, reason: '${identity.stderr}');
        for (final expected in [
          '"testing"',
          '"accept-postgres"',
          '"cafe_discount_acceptance_testing"',
        ]) {
          expect('${identity.stdout}', contains(expected));
        }
      });
      addTearDown(
        () => Process.run('docker', [
          'compose',
          '-f',
          _compose,
          'start',
          'accept-backend',
        ]),
      );
      serviceLocator.registerLazySingleton<AuthSessionStorage>(
        MemoryAuthSessionStorage.new,
      );
      setupServiceLocator();
      await tester.pumpWidget(
        RepaintBoundary(key: _captureKey, child: const App()),
      );
      await _until(tester, find.byKey(const Key('auth-identifier-field')));
      await _tapKey(tester, 'auth-identifier-field');
      await tester.enterText(
        find.byKey(const Key('auth-identifier-field')),
        'owner@cafe618.local',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'owner-local-dev',
      );
      await tester.tap(find.byKey(const Key('auth-login-submit-button')));
      final loginEnd = DateTime.now().add(const Duration(seconds: 30));
      while (find
          .byKey(const Key('auth-identifier-field'))
          .evaluate()
          .isNotEmpty) {
        expect(
          DateTime.now().isBefore(loginEnd),
          isTrue,
          reason: 'login timed out',
        );
        await tester.pump(const Duration(milliseconds: 250));
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      for (final locale in ['en', 'ar']) {
        final context = tester.element(find.byType(Scaffold).first);
        final cubit = context.read<AppLocaleCubit>();
        await (locale == 'ar' ? cubit.selectArabic() : cubit.selectEnglish());
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await _scenario(tester, locale);
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  int timeout = 20,
}) async {
  final end = DateTime.now().add(Duration(seconds: timeout));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .toList();
  fail('Timed out waiting for $finder; visible texts: $texts');
}

/// Bring the actual hit target into the viewport and require a hit-testable
/// point. Never call a control callback to bypass a missed pointer event.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(
    target.hitTestable(),
    findsWidgets,
    reason: 'target is outside the pointer viewport: $target',
  );
  await tester.tap(target.hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(Key(key)));

Future<void> _check(WidgetTester tester, Finder row) => _tap(
  tester,
  find.descendant(of: row.first, matching: find.byType(Checkbox)),
);

Future<void> _activate(WidgetTester tester) => _tap(
  tester,
  find
      .ancestor(
        of: find.text(_l(tester).discountFormActivate),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      )
      .first,
);

Future<void> _pick(WidgetTester tester, String fieldKey, String value) async {
  final dropdown = find.descendant(
    of: find.byKey(Key(fieldKey)),
    matching: find.byType(DropdownButton<String>),
  );
  final option = tester
      .widget<DropdownButton<String>>(dropdown)
      .items!
      .singleWhere((item) => item.value == value);
  final label = (option.child as Text).data!;
  await _tap(tester, dropdown);
  await _tap(tester, find.text(label).last);
}

Finder _nav(WidgetTester tester, String tooltip) =>
    find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);

Future<void> _backend(WidgetTester tester, bool up) async {
  await tester.runAsync(() async {
    final result = await Process.run('docker', [
      'compose',
      '-f',
      _compose,
      up ? 'start' : 'stop',
      'accept-backend',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    if (!up) return;
    final client = HttpClient();
    for (var i = 0; i < 60; i++) {
      try {
        final request = await client.postUrl(
          Uri.parse('http://localhost:18100/api/v1/auth/login'),
        );
        request.headers.contentType = ContentType.json;
        request.write('{}');
        await (await request.close()).drain<void>();
        client.close();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    fail('backend did not come back');
  });
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _search(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('discount-reference-search'));
  await _tap(tester, field);
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 800));
  final editable = tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  expect(editable.controller.text, text);
}

/// Search fails with the backend stopped: both navigation buttons are
/// disabled and no stale `n / m` counter remains; retry repeats the query.
Future<void> _failRecoverNavigate(
  WidgetTester tester,
  String query,
  String afterRecoveryKey,
  String navigationQuery,
) async {
  final l = _l(tester);
  await _backend(tester, false);
  await _search(tester, query);
  await _until(tester, find.text(l.commonRetry));
  expect(find.text(l.discountReferenceFailed), findsOneWidget);
  expect(
    tester.widget<IconButton>(_nav(tester, l.discountReferenceNext)).onPressed,
    isNull,
    reason: 'next must be disabled after a failed new search',
  );
  expect(
    tester
        .widget<IconButton>(_nav(tester, l.discountReferencePrevious))
        .onPressed,
    isNull,
  );
  expect(find.textContaining(RegExp(r'^\d+ / \d+$')), findsNothing);
  await _backend(tester, true);
  await tester.tap(find.text(l.commonRetry));
  await _until(tester, find.byKey(Key(afterRecoveryKey)), timeout: 30);
  // Navigation works again after recovery and requests the recovered query.
  await _search(tester, navigationQuery);
  await _until(tester, find.textContaining(RegExp(r'^1 / [0-9]+$')));
  await tester.tap(_nav(tester, l.discountReferenceNext));
  await _until(tester, find.textContaining(RegExp(r'^2 / [0-9]+$')));
  await _search(tester, query);
  await _until(tester, find.byKey(Key(afterRecoveryKey)), timeout: 30);
}

Future<void> _scenario(WidgetTester tester, String locale) async {
  final api = serviceLocator<DioApiClient>();
  final repo = serviceLocator<DiscountsRepository>();
  final name =
      'WIN-$locale per_unit mixed ${DateTime.now().millisecondsSinceEpoch % 100000}';
  appRouter.go(AppRoutes.discounts);
  await _until(tester, find.text(_l(tester).discountsCreate), timeout: 30);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.tap(find.text(_l(tester).discountsCreate).first);
  await _until(tester, find.byKey(const Key('discount-name-field')));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  final l = _l(tester);
  expect(
    Directionality.of(
      tester.element(find.byKey(const Key('discount-name-field'))),
    ),
    locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
  );
  // The navigation rail sits on the leading side: content must start clear of
  // it (left in EN, right in AR).
  final nameField = find.byKey(const Key('discount-name-field'));
  final viewWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  expect(
    locale == 'ar'
        ? tester.getTopRight(nameField).dx < viewWidth - 200
        : tester.getTopLeft(nameField).dx > 200,
    isTrue,
    reason: 'form content must be mirrored for $locale',
  );
  expect(tester.takeException(), isNull);
  await _tapKey(tester, 'discount-name-field');
  await tester.enterText(find.byKey(const Key('discount-name-field')), name);
  await _pick(tester, 'discount-scope-field', 'product');
  await _pick(tester, 'discount-value-type-field', 'fixed');
  await _pick(tester, 'discount-fixed-amount-basis-field', 'per_unit');
  await _tapKey(tester, 'discount-value-field');
  await tester.enterText(find.byKey(const Key('discount-value-field')), '4');

  // Products: page 2 of the unfiltered list, then a failed new search.
  await _tapKey(tester, 'discount-products-selector');
  await _until(tester, find.byKey(const Key('discount-reference-search')));
  await _until(tester, _nav(tester, l.discountReferenceNext));
  await tester.tap(_nav(tester, l.discountReferenceNext));
  await _until(tester, find.textContaining(RegExp(r'^2 / [0-9]+$')));
  await _failRecoverNavigate(tester, 'Acc Tea', 'discount-reference-10', 'Acc');
  await _check(tester, find.byKey(const Key('discount-reference-10')));
  for (final q in const [('Acc Cake', 11), ('Acc Latte', 12)]) {
    await _search(tester, q.$1);
    await _until(tester, find.byKey(Key('discount-reference-${q.$2}')));
    await _check(tester, find.byKey(Key('discount-reference-${q.$2}')));
  }
  await tester.tap(find.text(l.discountFormDone).last);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  await _tapKey(tester, 'discount-variant-mode-11-selected');
  await _tapKey(tester, 'discount-variant-mode-11-all');

  // Tea: selected -> Small (10). Cake stays All. Latte: selected -> page 2.
  await _tapKey(tester, 'discount-variant-mode-10-selected');
  await _tapKey(tester, 'discount-variants-selector-10');
  await _until(tester, find.byKey(const Key('discount-reference-10')));
  await _check(tester, find.byKey(const Key('discount-reference-10')));
  await tester.tap(find.text(l.discountFormDone).last);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  await _tapKey(tester, 'discount-variant-mode-12-selected');
  await _tapKey(tester, 'discount-variants-selector-12');
  await _until(tester, _nav(tester, l.discountReferenceNext));
  await tester.tap(_nav(tester, l.discountReferenceNext));
  await _until(tester, find.textContaining(RegExp(r'^2 / [0-9]+$')));
  await _check(tester, find.byType(CheckboxListTile).last);
  await tester.pump(const Duration(milliseconds: 300));
  await _failRecoverNavigate(tester, 'Size 3', 'discount-reference-44', 'Size');
  await _check(tester, find.byKey(const Key('discount-reference-44')));
  await tester.tap(find.text(l.discountFormDone).last);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  await _capture(tester, 'windows_${locale}_create_targets');
  await Scrollable.ensureVisible(tester.element(nameField), alignment: 0.5);
  await _capture(tester, 'windows_${locale}_create');
  await _activate(tester);
  await _until(tester, find.text(l.discountsTitle), timeout: 30);
  expect(tester.takeException(), isNull);

  final saved = (await repo.getDiscounts()).firstWhere((d) => d.name == name);
  final detail = await repo.getDiscountDetail(saved.id);
  final selections = {
    for (final s in detail.effectiveProductSelections) s.productId: s,
  };
  expect(detail.type, 'fixed');
  expect(detail.fixedAmountBasis, 'per_unit');
  expect(selections[10]!.variantMode, 'selected');
  expect(selections[10]!.variantIds, [10]);
  expect(selections[11]!.variantMode, 'all');
  expect(selections[12]!.variantMode, 'selected');
  expect(selections[12]!.variantIds.length, 2);
  expect(selections[12]!.variantIds, contains(44));
  await _posAcceptance(tester, locale, name);
  final latteArchived = selections[12]!.variantIds.firstWhere((v) => v != 44);
  // ignore: avoid_print
  print(
    'ACCEPTANCE[$locale] saved ${saved.id}: ${jsonEncode(detail.toUpsertRequest().toJson()['productVariantSelections'])}',
  );

  // Add policy fields through the API so edit must preserve them.
  final body = detail.toUpsertRequest().toJson()
    ..['description'] = 'Windows acceptance $locale'
    ..['usageLimit'] = 50
    ..['activeDays'] = ['Mon', 'Tue', 'Wed']
    ..['startTime'] = '08:00'
    ..['endTime'] = '23:00'
    ..['minimumOrderAmount'] = '5.00'
    ..['maximumDiscountAmount'] = '100.00'
    ..['channelKeys'] = ['pos'];
  await api.put('discounts/${saved.id}', data: body);
  final before = await repo.getDiscountDetail(saved.id);
  final beforeJson = before.toUpsertRequest().toJson();
  await api.post('admin/catalog/product-variants/$latteArchived/archive');

  // Edit: unavailable saved variant stays visible and blocks saving.
  final item = (await repo.getDiscounts()).firstWhere((d) => d.id == saved.id);
  appRouter.go(AppRoutes.discountCreate, extra: item);
  await _until(tester, find.byKey(const Key('discount-name-field')));
  await _until(
    tester,
    find.byKey(const Key('discount-variants-selector-12')),
    timeout: 30,
  );
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text(l.discountUnavailableTarget), findsWidgets);
  await Scrollable.ensureVisible(
    tester.element(find.byKey(Key('discount-remove-variant-$latteArchived'))),
    alignment: 0.5,
  );
  await _capture(tester, 'windows_${locale}_edit_unavailable');
  ButtonStyleButton formButton(String label) =>
      tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .first,
      );
  expect(
    formButton(l.discountFormActivate).onPressed,
    isNull,
    reason: 'Activate must be disabled while an unavailable target remains',
  );
  final draft = formButton(l.discountFormSaveDraft).onPressed;
  if (draft != null) {
    await _tap(tester, find.text(l.discountFormSaveDraft));
    await tester.pump(const Duration(seconds: 2));
  }
  final blocked = await repo.getDiscountDetail(saved.id);
  expect(
    blocked.effectiveProductSelections
        .firstWhere((s) => s.productId == 12)
        .variantIds,
    contains(latteArchived),
    reason: 'saving must stay blocked until the unavailable target is fixed',
  );
  final chip = find.byKey(Key('discount-remove-variant-$latteArchived'));
  await Scrollable.ensureVisible(chip.evaluate().first, alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 300));
  final deleteIcon = find.descendant(of: chip, matching: find.byType(Icon));
  await _tap(tester, deleteIcon.last);
  await tester.pump(const Duration(milliseconds: 400));
  await _activate(tester);
  await _until(tester, find.text(l.discountsTitle), timeout: 30);

  final after = await repo.getDiscountDetail(saved.id);
  final afterJson = after.toUpsertRequest().toJson();
  for (final key in beforeJson.keys.where(
    (k) => k != 'productVariantSelections',
  )) {
    expect(afterJson[key], beforeJson[key], reason: 'lost on edit: $key');
  }
  final afterSelections = {
    for (final s in after.effectiveProductSelections) s.productId: s,
  };
  expect(afterSelections[12]!.variantIds, [44]);
  expect(afterSelections[10]!.variantIds, [10]);
  expect(afterSelections[11]!.variantMode, 'all');
  // ignore: avoid_print
  print('ACCEPTANCE[$locale] edit preserved all non-target fields.');
  // Let the list reload that follows a save finish before the next route or the
  // end of the test disposes its cubit.
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  expect(
    _screenshots,
    isNotEmpty,
    reason: 'ACCEPTANCE_SCREENSHOTS must be set',
  );
  await tester.pumpAndSettle();
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await tester.runAsync(() async {
    await Directory(_screenshots).create(recursive: true);
    await File(
      '$_screenshots/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

Future<void> _posAcceptance(
  WidgetTester tester,
  String locale,
  String policy,
) async {
  final api = serviceLocator<DioApiClient>();
  appRouter.go(AppRoutes.pos);
  await _until(tester, find.text('Acc Tea'), timeout: 30);
  final pos = tester.element(find.byType(PosScreen)).read<PosCubit>();
  final l = _l(tester);
  Future<void> add(String variant) async {
    await _tap(tester, find.text('Acc Tea').first);
    await _until(tester, find.byType(ProductCustomizationDialog));
    await _tap(tester, find.text(variant));
    await _tap(tester, find.text(l.posAddToOrder));
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (find.byType(ProductCustomizationDialog).evaluate().isNotEmpty ||
        pos.state.isSyncingOrder) {
      expect(
        DateTime.now().isBefore(end),
        isTrue,
        reason: 'cart mutation timed out',
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(pos.state.cartMutationError, isNull);
  }

  await add('Large');
  await tester.scrollUntilVisible(
    find.text(l.posAddDiscount),
    120,
    scrollable: find
        .descendant(
          of: find.byType(PosCartPanel),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _tap(tester, find.text(l.posAddDiscount));
  await _until(tester, find.byType(DiscountDialog));
  final siblingPolicy = tester
      .widget<DiscountDialog>(find.byType(DiscountDialog))
      .availableDiscounts
      .singleWhere((d) => d.title == policy);
  expect(
    siblingPolicy.isEligible,
    isFalse,
    reason: 'sibling variant must not qualify',
  );
  await _tap(tester, find.text(policy));
  final rejectionEnd = DateTime.now().add(const Duration(seconds: 30));
  while (pos.state.cartMutationError == null) {
    expect(
      DateTime.now().isBefore(rejectionEnd),
      isTrue,
      reason: 'ineligible apply must be rejected',
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(pos.state.discountTotal, 0);
  expect(pos.state.appliedDiscount, isNull);
  final rejectedOrder = await api.get('orders/${pos.state.currentOrderId}');
  expect(rejectedOrder['totals']['discountTotal'], 0);

  await add('Small');
  await add('Small');
  await tester.scrollUntilVisible(
    find.text(l.posAddDiscount),
    120,
    scrollable: find
        .descendant(
          of: find.byType(PosCartPanel),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await _tap(tester, find.text(l.posAddDiscount));
  await _until(tester, find.text(policy));
  await _tap(tester, find.text(policy));
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (pos.state.discountTotal != 8) {
    expect(
      DateTime.now().isBefore(end),
      isTrue,
      reason: 'discount application timed out',
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(pos.state.subtotal, 40);
  expect(pos.state.tax, 2.56);
  expect(pos.state.total, 34.56);
  final orderId = pos.state.currentOrderId!;
  final order = await api.get('orders/$orderId');
  void totals(dynamic data) {
    final amounts = data['totals'] ?? data;
    for (final expected in {
      'subtotal': 40,
      'discountTotal': 8,
      'taxTotal': 2.56,
      'total': 34.56,
    }.entries) {
      expect(
        double.parse('${amounts[expected.key]}'),
        expected.value,
        reason: expected.key,
      );
    }
  }

  totals(order);
  await _capture(tester, 'windows_${locale}_pos_totals');
  await _tap(
    tester,
    find.descendant(
      of: find.byType(PosActionButtons),
      matching: find.byType(FilledButton),
    ),
  );
  await _until(tester, find.byType(PaymentDialog));
  expect(
    tester.widget<PaymentDialog>(find.byType(PaymentDialog)).totalDue,
    34.56,
  );
  await _tap(tester, find.text(l.posConfirmPayment));
  await _until(tester, find.byType(ReceiptPreviewDialog), timeout: 30);
  final receipt = tester
      .widget<ReceiptPreviewDialog>(find.byType(ReceiptPreviewDialog))
      .receipt;
  expect(receipt.subtotal, 40);
  expect(receipt.discountTotal, 8);
  expect(receipt.tax, 2.56);
  expect(receipt.total, 34.56);
  expect(receipt.payment.totalDue, 34.56);
  totals(await api.get('orders/$orderId/receipt'));
  await _capture(tester, 'windows_${locale}_receipt');
  await _tap(tester, find.byTooltip(l.posCloseReceiptPreview));
  expect(tester.takeException(), isNull);
  // ignore: avoid_print
  print(
    'ACCEPTANCE[$locale] pointer POS order $orderId: 40 - 8 + 2.56 = 34.56; payment and receipt equal backend.',
  );
}
