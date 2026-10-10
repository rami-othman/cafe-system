import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/discounts/views/create_discount_policy_screen.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
import 'package:windows_application/features/discounts/models/discount_product_selection.dart';
import 'package:windows_application/features/discounts/models/discount_detail.dart';
import 'package:windows_application/features/discounts/models/discount_dashboard_metrics.dart';
import 'package:windows_application/features/discounts/models/discount_form_references.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/discount_engine.dart';
import 'package:windows_application/shared/widgets/app_sidebar_item.dart';

void main() {
  for (final cafeOn in [false, true]) {
    testWidgets(
      'Automatic explains itself and warns while the cafe has promotions off (on=$cafeOn)',
      (tester) async {
        await _pumpScreen(
          tester,
          const Size(1280, 1200),
          capabilities: DiscountCapabilities(
            contractVersion: 2,
            engineReady: true,
            automaticPolicyCreationAvailable: true,
            automaticEnabled: cafeOn,
          ),
        );
        await tester.pumpAndSettle();
        final mode = find.byKey(const Key('discount-application-mode-field'));
        await tester.ensureVisible(mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Automatic').last);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('discount-automatic-notice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('discount-automatic-off')),
          cafeOn ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'isolated Automatic conversion preserves full detail and clears Code explicitly',
    (tester) async {
      final r = _DiscountsRepository(detail: _detail);
      await _pumpScreen(
        tester,
        const Size(1280, 1200),
        repository: r,
        initialDiscount: _editRow,
        capabilities: const DiscountCapabilities(
          contractVersion: 2,
          engineReady: false,
          automaticPolicyCreationAvailable: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('discount-application-mode-field')),
      );
      await tester.tap(
        find.byKey(const Key('discount-application-mode-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatic').last);
      await tester.pumpAndSettle();
      final priority = find.descendant(
        of: find.byKey(const Key('discount-priority-field')),
        matching: find.byType(TextField),
      );
      await tester.enterText(priority, '7');
      await tester.pump();
      await tester.tap(find.text('Save as Draft'));
      await tester.pumpAndSettle();
      final expected = _detail.toUpsertRequest().toJson()
        ..['applicationMode'] = 'automatic'
        ..['code'] = null
        ..['priority'] = 7;
      expect(r.lastUpdateRequest!.toJson(), expected);
      expect(tester.takeException(), null);
    },
  );
  testWidgets(
    'public Automatic is unavailable and priority must be an integer in range',
    (tester) async {
      final r = _DiscountsRepository();
      await _pumpScreen(tester, const Size(1280, 1200), repository: r);
      await tester.pumpAndSettle();
      final mode = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('discount-application-mode-field')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(mode.items!.map((i) => i.value), isNot(contains('automatic')));
      _fillRequiredFields(tester, name: 'Priority rule', value: '10');
      final field = find.descendant(
        of: find.byKey(const Key('discount-priority-field')),
        matching: find.byType(TextField),
      );
      for (final value in ['11', '-1', '2.5']) {
        await tester.enterText(field, value);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save as Draft'));
        await tester.tap(find.text('Save as Draft'));
        await tester.pumpAndSettle();
        expect(r.createCalls, 0);
      }
      await tester.enterText(field, '10');
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save as Draft'));
      await tester.tap(find.text('Save as Draft'));
      await tester.pumpAndSettle();
      expect(r.lastCreateRequest!.priority, 10);
      expect(r.createCalls, 1);
    },
  );
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() {
    appRouter.go(AppRoutes.pos);
  });

  testWidgets(
    'variant edit hydrates full detail and submits preserved fields',
    (tester) async {
      final detail = DiscountDetail.fromJson({
        'id': 81,
        'name': 'Variant policy',
        'applicationMode': 'code',
        'code': 'KEEP',
        'description': 'Keep description',
        'conditions': 'Keep conditions',
        'type': 'fixed',
        'scope': 'product',
        'value': 0,
        'fixedAmountBasis': 'per_unit',
        'isActive': true,
        'appliesToAllBranches': false,
        'branchIds': [41],
        'targetProductIds': [11],
        'customerEligibilityMode': 'selected_groups',
        'customerGroupIds': [41],
        'paymentMethodIds': [61],
        'channelKeys': ['pos'],
        'usageLimit': 10,
        'usageLimitPerCustomer': 2,
        'perCustomerDailyUsageLimit': 1,
        'startsAt': '2026-10-01T00:00:00Z',
        'endsAt': null,
        'startDate': '2026-10-01',
        'endDate': '2026-10-31',
        'startTime': '22:00:00',
        'endTime': '02:00:00',
        'activeDays': ['Mon'],
        'minimumOrderAmount': 0,
        'maximumDiscountAmount': null,
        'productVariantSelections': [
          {
            'productId': 11,
            'variantMode': 'selected',
            'variantIds': [101],
            'product': {
              'id': 11,
              'name': 'Saved coffee',
              'isActive': true,
              'archivedAt': null,
            },
            'variants': [
              {
                'id': 101,
                'name': 'Saved large',
                'isActive': true,
                'archivedAt': null,
              },
            ],
          },
        ],
      });
      final repository = _DiscountsRepository(detail: detail);
      await _pumpScreen(
        tester,
        const Size(1280, 900),
        repository: repository,
        initialDiscount: _editRow,
      );
      expect(repository.detailRequests, 1);
      expect(find.text('Saved coffee'), findsOneWidget);
      expect(find.text('Saved large'), findsOneWidget);
      await tester.tap(find.text('Save as Draft'));
      await tester.pumpAndSettle();
      final json = repository.lastUpdateRequest!.toJson();
      final expected = detail.toUpsertRequest().toJson();
      expect(json, expected);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('/discounts/create opens and keeps Discounts active', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.discountCreate);
    await _pumpApp(tester);

    expect(find.text('Create Discount Policy'), findsOneWidget);
    expect(find.text('POS Preview'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(_discountsSidebarItem(tester).isActive, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discounts breadcrumb returns to the discounts list', (
    WidgetTester tester,
  ) async {
    appRouter.go(AppRoutes.discountCreate);
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('breadcrumb-discounts')));
    await tester.pumpAndSettle();

    expect(find.text('Discounts & Coupons'), findsOneWidget);
    expect(_discountsSidebarItem(tester).isActive, isTrue);
  });

  testWidgets('renders all policy sections and bottom actions', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));

    for (final String title in <String>[
      'Basic Information',
      'Scope & Value',
      'Eligibility Conditions',
      'Schedule',
      'Usage Limits',
    ]) {
      expect(find.text(title), findsAtLeastNWidgets(1));
    }

    for (final String unsupported in <String>[
      'Approval & Permissions',
      'Discount Rules',
      'Stacking Rules',
      'Reports & Audit',
      'BOGO',
      'Manager PIN required',
    ]) {
      expect(find.text(unsupported), findsNothing);
    }

    expect(find.text('Discard Changes'), findsOneWidget);
    expect(find.text('Save as Draft'), findsOneWidget);
    expect(find.text('Activate Discount'), findsOneWidget);
    final mode = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('discount-application-mode-field')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(mode.items!.map((item) => item.value), isNot(contains('automatic')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick value chips fill the editable custom-value input', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));

    expect(find.byKey(const Key('discount-value-field')), findsOneWidget);
    await tester.ensureVisible(find.text('20%').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('20%').first);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('discount-value-field')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '20',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('discount-value-field')),
        matching: find.byType(TextField),
      ),
      '12.5',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('discount-value-field')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '12.5',
    );
  });

  testWidgets('remains overflow-free at a compact desktop width', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(700, 800));

    expect(find.text('Create Discount Policy'), findsOneWidget);
    expect(find.text('Activate Discount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic Create/Edit is RTL and overflow-free when constrained', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      const Size(700, 800),
      locale: const Locale('ar'),
      repository: _DiscountsRepository(detail: _detail),
      initialDiscount: _editRow,
    );
    await tester.pumpAndSettle();

    expect(find.text('تعديل سياسة خصم'), findsOneWidget);
    expect(
      Directionality.of(
        tester.element(find.byType(CreateDiscountPolicyScreen)),
      ),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic channel labels are localized without English leakage', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      const Size(1280, 900),
      locale: const Locale('ar'),
    );
    await _scrollToField(
      tester,
      find.byKey(const Key('discount-channel-mode-field')),
    );
    await _selectDropdown(
      tester,
      const Key('discount-channel-mode-field'),
      'قنوات محددة',
    );

    for (final String label in <String>[
      'نقطة البيع',
      'تطبيق النادل',
      'الكشك',
      'الطلب عبر رمز QR',
      'التوصيل',
      'الطلب عبر الإنترنت',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final String leaked in <String>[
      'Waiter App',
      'Kiosk',
      'QR Ordering',
      'Delivery',
      'Online Ordering',
      'Basic Information',
      'Save as Draft',
      'Activate Discount',
    ]) {
      expect(find.text(leaked), findsNothing, reason: leaked);
    }
  });

  testWidgets('English operational UI contains no Arabic leakage', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));

    for (final String leaked in <String>[
      'المعلومات الأساسية',
      'حفظ كمسودة',
      'تنشيط الخصم',
      'تطبيق النادل',
      'التوصيل',
    ]) {
      expect(find.text(leaked), findsNothing, reason: leaked);
    }
  });

  testWidgets('percentage 0 is valid and can activate', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));
    _fillRequiredFields(tester, name: 'Zero percentage', value: '0');
    await tester.pump();

    expect(_activateButton(tester).onPressed, isNotNull);
    expect(find.text('Enter a value of zero or greater.'), findsNothing);
  });

  testWidgets('fixed 0 is valid and submitted as zero', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      stallCreates: true,
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    await _selectValueType(tester, 'Fixed Amount');
    _fillRequiredFields(tester, name: 'Zero fixed', value: '0');
    await tester.pump();

    expect(_activateButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Save as Draft'));
    await tester.pump();
    expect(repository.lastCreateRequest!.value, 0);
  });

  testWidgets('fixed product discount offers per-unit basis in English', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      stallCreates: true,
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    await _selectDropdown(
      tester,
      const Key('discount-scope-field'),
      'Selected Products',
    );
    await _selectValueType(tester, 'Fixed Amount');
    final Finder basis = find.byKey(
      const Key('discount-fixed-amount-basis-field'),
    );
    expect(basis, findsOneWidget);
    await _scrollToField(tester, basis);
    await _selectDropdown(
      tester,
      const Key('discount-fixed-amount-basis-field'),
      'For each eligible unit',
    );
    _fillRequiredFields(tester, name: 'Coffee per unit', value: '5');
    final Finder products = find.byKey(const Key('discount-products-selector'));
    await _scrollToField(tester, products);
    await tester.tap(products);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cappuccino').last);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as Draft'));
    await tester.pump();

    expect(repository.lastCreateRequest!.fixedAmountBasis, 'per_unit');
    expect(repository.lastCreateRequest!.targetProductIds, <int>[11]);
  });

  testWidgets('fixed product discount shows the Arabic basis choices', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      const Size(1280, 900),
      locale: const Locale('ar'),
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CreateDiscountPolicyScreen)),
    );
    await _selectDropdown(
      tester,
      const Key('discount-scope-field'),
      l10n.discountSelectedProducts,
    );
    await _selectValueType(tester, l10n.discountFixedAmount);
    expect(find.text(l10n.discountFixedAmountBasis), findsOneWidget);
    expect(find.text(l10n.discountFixedOncePerOrder), findsOneWidget);
  });

  testWidgets('negative value remains invalid with the localized message', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));
    _fillRequiredFields(tester, name: 'Negative value', value: '-1');
    await tester.pump();

    expect(_activateButton(tester).onPressed, isNull);
    expect(find.text('Enter a value of zero or greater.'), findsOneWidget);
  });

  testWidgets('Arabic negative value uses the localized validation message', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      const Size(1280, 900),
      locale: const Locale('ar'),
    );
    _fillRequiredFields(tester, name: 'Negative value', value: '-1');
    await tester.pump();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CreateDiscountPolicyScreen)),
    );
    expect(find.text(l10n.discountValidationNonNegativeValue), findsOneWidget);
  });

  testWidgets('percentage values above 100 remain invalid', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));
    _fillRequiredFields(tester, name: 'Over percentage', value: '101');
    await tester.pump();

    expect(_activateButton(tester).onPressed, isNull);
    expect(
      find.text('A percentage discount cannot exceed 100.'),
      findsOneWidget,
    );
  });

  testWidgets('valid custom percentage and fixed amount become ready', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));
    _fillRequiredFields(tester, name: 'Afternoon', value: '12.5');
    await tester.pump();
    expect(_activateButton(tester).onPressed, isNotNull);
    expect(
      find.text('Policy is ready for review before activation.'),
      findsOneWidget,
    );

    await _selectValueType(tester, 'Fixed Amount');
    _setField(tester, const Key('discount-value-field'), '5000');
    await tester.pump();
    expect(_activateButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'untouched and explicitly cleared optional money serialize null',
    (WidgetTester tester) async {
      final _DiscountsRepository repository = _DiscountsRepository(
        stallCreates: true,
      );
      await _pumpScreen(tester, const Size(1280, 900), repository: repository);
      _fillRequiredFields(tester, name: 'No money bounds', value: '10');
      await tester.pump();

      await tester.tap(find.text('Save as Draft'));
      await tester.pump();
      expect(repository.lastCreateRequest!.minimumOrderAmount, isNull);
      expect(repository.lastCreateRequest!.maximumDiscountAmount, isNull);
    },
  );

  testWidgets('explicitly cleared optional money values serialize null', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      stallCreates: true,
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    // A visible 0 SYP hint is never stateful; clearing an entered value returns
    // the canonical nullable request value.
    _fillRequiredFields(tester, name: 'Cleared bound', value: '10');
    _setField(tester, const Key('discount-min-spend-field'), '5000');
    _setField(tester, const Key('discount-min-spend-field'), '');
    _setField(tester, const Key('discount-max-discount-field'), '5000');
    _setField(tester, const Key('discount-max-discount-field'), '');
    await tester.pump();

    await tester.tap(find.text('Save as Draft'));
    await tester.pump();
    expect(repository.lastCreateRequest!.minimumOrderAmount, isNull);
    expect(repository.lastCreateRequest!.maximumDiscountAmount, isNull);
  });

  testWidgets(
    'date fields use pickers, serialize, clear, and reject bad ranges',
    (WidgetTester tester) async {
      final _DiscountsRepository repository = _DiscountsRepository(
        stallCreates: true,
      );
      await _pumpScreen(tester, const Size(1280, 900), repository: repository);
      _fillRequiredFields(tester, name: 'Date bounded', value: '10');
      await tester.pump();

      await _scrollToField(
        tester,
        find.byKey(const Key('discount-start-date-field')),
      );
      await tester.tap(find.byKey(const Key('discount-start-date-field')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        _fieldText(tester, const Key('discount-start-date-field')),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );

      await _scrollToField(
        tester,
        find.byKey(const Key('discount-end-date-field')),
      );
      await tester.tap(find.byKey(const Key('discount-end-date-field')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      _setField(tester, const Key('discount-start-date-field'), '2026-10-02');
      _setField(tester, const Key('discount-end-date-field'), '2026-10-01');
      await tester.pump();
      expect(
        find.text('End date cannot be earlier than start date.'),
        findsOneWidget,
      );

      await _scrollToField(
        tester,
        find.byKey(const Key('discount-start-date-field')),
      );
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const Key('discount-start-date-field')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('discount-start-date-field')),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pump();
      expect(
        _fieldText(tester, const Key('discount-start-date-field')),
        isEmpty,
      );
      _setField(tester, const Key('discount-start-date-field'), '2026-10-01');
      await tester.pump();

      await tester.tap(find.text('Save as Draft'));
      await tester.pump();
      expect(repository.lastCreateRequest!.startDate, '2026-10-01');
      expect(repository.lastCreateRequest!.endDate, '2026-10-01');
    },
  );

  testWidgets(
    'time fields use pickers, serialize canonical values, and allow overnight',
    (WidgetTester tester) async {
      final _DiscountsRepository repository = _DiscountsRepository(
        stallCreates: true,
      );
      await _pumpScreen(tester, const Size(1280, 900), repository: repository);
      _fillRequiredFields(tester, name: 'Night', value: '10');
      await tester.pump();

      await _scrollToField(
        tester,
        find.byKey(const Key('discount-start-time-field')),
      );
      await tester.tap(find.byKey(const Key('discount-start-time-field')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _scrollToField(
        tester,
        find.byKey(const Key('discount-end-time-field')),
      );
      await tester.tap(find.byKey(const Key('discount-end-time-field')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      _setField(tester, const Key('discount-start-time-field'), '22:00');
      _setField(tester, const Key('discount-end-time-field'), '02:00');
      await tester.tap(find.text('Save as Draft'));
      await tester.pump();
      expect(repository.lastCreateRequest!.startTime, '22:00');
      expect(repository.lastCreateRequest!.endTime, '02:00');
    },
  );

  testWidgets('only one time is invalid and both can clear to null', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      stallCreates: true,
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    _fillRequiredFields(tester, name: 'Hours', value: '10');
    _setField(tester, const Key('discount-start-time-field'), '09:00');
    await tester.pump();
    expect(
      find.text('Start time and end time must be provided together.'),
      findsNWidgets(2),
    );

    _setField(tester, const Key('discount-end-time-field'), '17:00');
    await tester.pump();
    expect(
      find.text('Start time and end time must be provided together.'),
      findsNothing,
    );
    expect(_activateButton(tester).onPressed, isNotNull);
    await _scrollToField(
      tester,
      find.byKey(const Key('discount-start-time-field')),
    );
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(const Key('discount-start-time-field')),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('discount-start-time-field')),
        matching: find.byType(IconButton),
      ),
    );
    await _scrollToField(
      tester,
      find.byKey(const Key('discount-end-time-field')),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('discount-end-time-field')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump();
    expect(_fieldText(tester, const Key('discount-start-time-field')), isEmpty);
    expect(_fieldText(tester, const Key('discount-end-time-field')), isEmpty);
    _setField(tester, const Key('discount-end-time-field'), '17:00');
    await tester.pump();
    expect(
      find.text('Start time and end time must be provided together.'),
      findsNWidgets(2),
    );
    _setField(tester, const Key('discount-end-time-field'), '');
    await tester.pump();

    await tester.tap(find.text('Save as Draft'));
    await tester.pump();
    expect(repository.lastCreateRequest!.startTime, isNull);
    expect(repository.lastCreateRequest!.endTime, isNull);
  });

  testWidgets('edit loads the full V1 detail instead of the list row', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository();
    await _pumpScreen(
      tester,
      const Size(1280, 900),
      repository: repository,
      initialDiscount: _editRow,
    );

    expect(repository.detailRequests, 1);
    expect(find.text('Edit Discount Policy'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('discount-value-field')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '12.5',
    );
    expect(
      find.byKey(const Key('discount-categories-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discount-customer-groups-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discount-payment-methods-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('discount-branches-selector')), findsOneWidget);
    expect(
      _fieldText(tester, const Key('discount-start-date-field')),
      '2026-10-01',
    );
    expect(
      _fieldText(tester, const Key('discount-end-date-field')),
      '2026-10-31',
    );
    expect(_fieldText(tester, const Key('discount-start-time-field')), '22:00');
    expect(_fieldText(tester, const Key('discount-end-time-field')), '02:00');
    expect(_fieldText(tester, const Key('discount-code-field')), 'DETAIL12');
    expect(repository.generateCouponCalls, 0);
  });

  testWidgets('code mode requests backend-generated code and regenerates it', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository();
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);

    await _selectDropdown(
      tester,
      const Key('discount-application-mode-field'),
      'Coupon / Code',
    );
    await tester.pumpAndSettle();

    expect(repository.generateCouponCalls, 1);
    expect(_fieldText(tester, const Key('discount-code-field')), 'CPN-0001');
    expect(
      _textField(tester, const Key('discount-code-field')).readOnly,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('discount-regenerate-code')));
    await tester.pumpAndSettle();
    expect(repository.generateCouponCalls, 2);
    expect(_fieldText(tester, const Key('discount-code-field')), 'CPN-0002');
  });

  testWidgets('V2 bundle and customer selections serialize canonical IDs', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      stallCreates: true,
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    _fillRequiredFields(tester, name: 'Customer package', value: '20');

    await _scrollToField(
      tester,
      find.byKey(const Key('discount-customer-eligibility-field')),
    );
    await _selectDropdown(
      tester,
      const Key('discount-customer-eligibility-field'),
      'Selected Customers',
    );
    await tester.tap(find.byKey(const Key('discount-customers-selector')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('discount-reference-search')),
      'Amina',
    );
    await tester.pump();
    await tester.tap(find.text('Amina Hassan'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await _scrollToField(tester, find.byKey(const Key('discount-scope-field')));
    await _selectDropdown(
      tester,
      const Key('discount-scope-field'),
      'Package / Bundle',
    );
    await tester.tap(find.byKey(const Key('discount-add-bundle-product')));
    await tester.pump();
    await _selectDropdown(
      tester,
      const Key('discount-bundle-product-0'),
      'Cappuccino',
    );
    _setField(tester, const Key('discount-bundle-quantity-0'), '1');

    await _scrollToField(
      tester,
      find.byKey(const Key('discount-channel-mode-field')),
    );
    await _selectDropdown(
      tester,
      const Key('discount-channel-mode-field'),
      'Selected Channels',
    );
    await tester.pump();
    await tester.tap(find.text('POS'));
    await tester.tap(find.text('Delivery'));
    await tester.pump();

    await _scrollToField(
      tester,
      find.byKey(const Key('discount-per-customer-daily-limit-field')),
    );
    _setField(
      tester,
      const Key('discount-per-customer-daily-limit-field'),
      '1',
    );
    await tester.tap(find.text('Save as Draft'));
    await tester.pump();

    final DiscountUpsertRequest request = repository.lastCreateRequest!;
    expect(request.customerIds, <int>[71]);
    expect(request.customerGroupIds, isEmpty);
    expect(request.scope, 'bundle');
    expect(request.bundleRequirements.single.productId, 11);
    expect(request.bundleRequirements.single.quantity, 1);
    expect(request.channelKeys, <String>['pos', 'delivery']);
    expect(request.perCustomerDailyUsageLimit, 1);
  });

  testWidgets('coupon generation failure exposes retry', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      couponFailuresRemaining: 1,
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);

    await _selectDropdown(
      tester,
      const Key('discount-application-mode-field'),
      'Coupon / Code',
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to generate a code.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.generateCouponCalls, 2);
    expect(_fieldText(tester, const Key('discount-code-field')), 'CPN-0002');
  });

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language product and variant errors use safe localized labels',
      (tester) async {
        final repository = _DiscountsRepository(
          createFailure: const ApiException(
            message: 'SECRET',
            statusCode: 422,
            validationErrors: {
              'productVariantSelections.0.variantIds': ['SECRET'],
              'targetProductIds': ['SECRET'],
            },
          ),
        );
        await _pumpScreen(
          tester,
          const Size(1280, 900),
          repository: repository,
          locale: Locale(language),
        );
        await _submitValidDraft(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CreateDiscountPolicyScreen)),
        );
        expect(
          find.textContaining(
            l10n.discountServerFieldInvalid(l10n.discountSelectedVariants),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            l10n.discountServerFieldInvalid(l10n.discountSelectedProducts),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('SECRET'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'saving disables both submit actions and prevents a second request',
    (tester) async {
      final repository = _DiscountsRepository(stallCreates: true);
      await _pumpScreen(tester, const Size(1280, 900), repository: repository);
      await tester.enterText(
        find.byKey(const Key('discount-name-field')),
        'Policy',
      );
      await tester.enterText(
        find.byKey(const Key('discount-value-field')),
        '10',
      );
      await tester.tap(find.text('Save as Draft'));
      await tester.pump();
      expect(repository.createCalls, 1);
      final saveButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Save as Draft'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(saveButton.onPressed, isNull);
      expect(repository.createCalls, 1);
    },
  );

  testWidgets('known backend field validation is safely localized in English', (
    WidgetTester tester,
  ) async {
    const String rawBackendText = 'RAW_BACKEND_NAME_FAILURE';
    final _DiscountsRepository repository = _DiscountsRepository(
      createFailure: const ApiException(
        message: rawBackendText,
        type: ApiErrorType.validation,
        validationErrors: <String, List<String>>{
          'name': <String>[rawBackendText],
        },
      ),
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    await _submitValidDraft(tester);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CreateDiscountPolicyScreen)),
    );
    expect(
      find.textContaining(
        l10n.discountServerFieldInvalid(l10n.discountFormName),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.discountRequestFailed), findsNothing);
    expect(find.text(rawBackendText), findsNothing);
  });

  testWidgets('known backend field validation is safely localized in Arabic', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      createFailure: const ApiException(
        message: 'RAW_ARABIC_BACKEND_FAILURE',
        type: ApiErrorType.validation,
        validationErrors: <String, List<String>>{
          'value': <String>['RAW_ARABIC_BACKEND_FAILURE'],
        },
      ),
    );
    await _pumpScreen(
      tester,
      const Size(1280, 900),
      repository: repository,
      locale: const Locale('ar'),
    );
    await _submitValidDraft(tester);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CreateDiscountPolicyScreen)),
    );
    expect(
      find.textContaining(
        l10n.discountServerFieldInvalid(l10n.discountFormValue),
      ),
      findsOneWidget,
    );
    expect(find.text('RAW_ARABIC_BACKEND_FAILURE'), findsNothing);
  });

  testWidgets('multiple known backend field errors remain visible', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      createFailure: const ApiException(
        message: 'invalid',
        type: ApiErrorType.validation,
        validationErrors: <String, List<String>>{
          'name': <String>['unsafe name text'],
          'value': <String>['unsafe value text'],
        },
      ),
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    await _submitValidDraft(tester);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CreateDiscountPolicyScreen)),
    );
    expect(
      find.textContaining(
        l10n.discountServerFieldInvalid(l10n.discountFormName),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l10n.discountServerFieldInvalid(l10n.discountFormValue),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'unknown backend validation uses generic fallback without leaks',
    (WidgetTester tester) async {
      const String rawBackendText = 'TOP_SECRET_SERVER_VALIDATION';
      final _DiscountsRepository repository = _DiscountsRepository(
        createFailure: const ApiException(
          message: rawBackendText,
          type: ApiErrorType.validation,
          validationErrors: <String, List<String>>{
            'unrecognizedServerField': <String>[rawBackendText],
          },
        ),
      );
      await _pumpScreen(tester, const Size(1280, 900), repository: repository);
      await _submitValidDraft(tester);

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(CreateDiscountPolicyScreen)),
      );
      expect(find.text(l10n.discountRequestFailed), findsOneWidget);
      expect(find.text(rawBackendText), findsNothing);
    },
  );

  testWidgets('non-validation exception uses localized generic fallback', (
    WidgetTester tester,
  ) async {
    const String exceptionText = 'INTERNAL_EXCEPTION_DETAILS';
    final _DiscountsRepository repository = _DiscountsRepository(
      createFailure: StateError(exceptionText),
    );
    await _pumpScreen(tester, const Size(1280, 900), repository: repository);
    await _submitValidDraft(tester);

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(CreateDiscountPolicyScreen)),
    );
    expect(find.text(l10n.discountRequestFailed), findsOneWidget);
    expect(find.text(exceptionText), findsNothing);
  });

  testWidgets('edit hydrates V2 detail without generating a new code', (
    WidgetTester tester,
  ) async {
    final _DiscountsRepository repository = _DiscountsRepository(
      detail: _v2Detail,
    );
    await _pumpScreen(
      tester,
      const Size(1280, 900),
      repository: repository,
      initialDiscount: _editRow,
    );

    expect(_fieldText(tester, const Key('discount-code-field')), 'CPN-V2-0001');
    expect(
      _fieldText(tester, const Key('discount-per-customer-daily-limit-field')),
      '1',
    );
    expect(repository.generateCouponCalls, 0);
    await _scrollToField(
      tester,
      find.byKey(const Key('discount-bundle-product-0')),
    );
    expect(
      find.byKey(const Key('discount-customers-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('discount-channels-selector')), findsOneWidget);
    expect(_fieldText(tester, const Key('discount-bundle-quantity-0')), '1');
  });

  testWidgets(
    'edit restores the package variant scope, keeps it on save and resets it when the product changes',
    (WidgetTester tester) async {
      final _DiscountsRepository repository = _DiscountsRepository(
        detail: _variantPackageDetail,
      );
      await _pumpScreen(
        tester,
        const Size(1280, 900),
        repository: repository,
        initialDiscount: _editRow,
      );
      await _scrollToField(
        tester,
        find.byKey(const Key('discount-bundle-product-0')),
      );
      // Phase 3: the saved selection is restored as removable variant chips.
      final Finder variants = find.byKey(
        const Key('discount-bundle-variants-0'),
      );
      expect(
        find.descendant(of: variants, matching: find.text('Large')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: variants, matching: find.text('Iced')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('discount-bundle-variant-mode-0-selected')),
            )
            .selected,
        isTrue,
      );

      await tester.tap(find.text('Save as Draft'));
      await tester.pumpAndSettle();
      final Map<String, dynamic> saved = repository.lastUpdateRequest!.toJson();
      expect(saved['combinationBehavior'], 'exclusive');
      expect(saved['bundleRequirements'], <Map<String, dynamic>>[
        <String, dynamic>{
          'productId': 11,
          'quantity': 1.0,
          'variantMode': 'selected',
          'variantIds': <int>[101, 102],
        },
      ]);

      await _scrollToField(
        tester,
        find.byKey(const Key('discount-bundle-product-0')),
      );
      await _selectDropdown(
        tester,
        const Key('discount-bundle-product-0'),
        'Espresso',
      );
      expect(find.byKey(const Key('discount-bundle-variants-0')), findsNothing);
      // Let the first save's confirmation toast leave the button uncovered.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as Draft'));
      await tester.pumpAndSettle();
      expect(
        repository.lastUpdateRequest!.toJson()['bundleRequirements'],
        <Map<String, dynamic>>[
          <String, dynamic>{
            'productId': 12,
            'quantity': 1.0,
            'variantMode': 'all',
            'variantIds': <int>[],
          },
        ],
      );
      expect(tester.takeException(), isNull);
    },
  );

  _phase3CreateEditTests();
}

void _phase3CreateEditTests() {
  testWidgets(
    'Phase 3: combination behavior is chosen in business language and priority explains its role',
    (WidgetTester tester) async {
      final _DiscountsRepository repository = _DiscountsRepository(
        stallCreates: true,
      );
      await _pumpScreen(tester, const Size(1280, 900), repository: repository);
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(CreateDiscountPolicyScreen)),
      );
      expect(find.text(l10n.dp3PriorityHelp), findsOneWidget);
      expect(find.text(l10n.dp3FollowPolicyHelp), findsOneWidget);
      expect(find.text('follow_cafe_policy'), findsNothing);
      const Key field = Key('discount-combination-field-follow_cafe_policy');
      await _scrollToField(tester, find.byKey(field));
      await _selectDropdown(tester, field, l10n.dp3Exclusive);
      expect(find.text(l10n.dp3ExclusiveHelp), findsOneWidget);
      _fillRequiredFields(tester, name: 'Exclusive coupon', value: '10');
      await tester.pump();
      await tester.tap(find.text('Save as Draft'));
      await tester.pump();
      expect(
        repository.lastCreateRequest!.toJson()['combinationBehavior'],
        'exclusive',
      );
    },
  );

  testWidgets(
    'Phase 3: package selected variants need one variant and the paged picker writes the choice',
    (WidgetTester tester) async {
      final _VariantRepository repository = _VariantRepository();
      await _pumpScreen(
        tester,
        const Size(1280, 900),
        repository: repository,
        initialDiscount: _editRow,
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(CreateDiscountPolicyScreen)),
      );
      await _scrollToField(
        tester,
        find.byKey(const Key('discount-bundle-variants-0')),
      );
      // Removing every saved variant leaves "selected" empty: never submitted.
      for (final int id in <int>[101, 102]) {
        final Finder chip = find.byKey(Key('discount-bundle-variant-0-$id'));
        await tester.tap(
          find.descendant(of: chip, matching: find.byType(Icon)).last,
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Save as Draft'));
      await tester.pumpAndSettle();
      expect(repository.lastUpdateRequest, isNull);
      expect(find.text(l10n.dp3BundleVariantsRequired), findsWidgets);

      // The picker searches the product's own variants page by page.
      final Finder picker = find.byKey(
        const Key('discount-bundle-variants-picker-0'),
      );
      await _scrollToField(tester, picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(repository.variantRequests, contains(11));
      await tester.tap(find.byKey(const Key('discount-reference-103')));
      await tester.pump();
      await tester.tap(find.text(l10n.discountFormDone));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('discount-bundle-variants-0')),
          matching: find.text('Regular'),
        ),
        findsOneWidget,
      );
      // Let the validation toast from the blocked save leave the button.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as Draft'));
      await tester.pumpAndSettle();
      expect(
        repository.lastUpdateRequest!.toJson()['bundleRequirements'],
        <Map<String, dynamic>>[
          <String, dynamic>{
            'productId': 11,
            'quantity': 1.0,
            'variantMode': 'selected',
            'variantIds': <int>[103],
          },
        ],
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _VariantRepository extends _DiscountsRepository {
  _VariantRepository() : super(detail: _variantPackageDetail);
  final List<int> variantRequests = <int>[];
  @override
  Future<DiscountReferencePage> getVariants(
    int productId, {
    String search = '',
    int page = 1,
  }) async {
    variantRequests.add(productId);
    return const DiscountReferencePage(
      items: <DiscountFormReference>[
        DiscountFormReference(id: 101, name: 'Large', isActive: true),
        DiscountFormReference(id: 102, name: 'Iced', isActive: true),
        DiscountFormReference(id: 103, name: 'Regular', isActive: true),
      ],
    );
  }
}

FilledButton _activateButton(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Activate Discount'),
        matching: find.byType(FilledButton),
      ),
    );

String _fieldText(WidgetTester tester, Key key) =>
    _textField(tester, key).controller!.text;

void _setField(WidgetTester tester, Key key, String value) {
  _textField(tester, key).controller!.text = value;
}

TextField _textField(WidgetTester tester, Key key) => tester.widget<TextField>(
  find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
);

void _fillRequiredFields(
  WidgetTester tester, {
  required String name,
  required String value,
}) {
  _setField(tester, const Key('discount-name-field'), name);
  _setField(tester, const Key('discount-value-field'), value);
}

Future<void> _selectValueType(WidgetTester tester, String label) async {
  await _selectDropdown(tester, const Key('discount-value-type-field'), label);
}

Future<void> _selectDropdown(WidgetTester tester, Key key, String label) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _scrollToField(WidgetTester tester, Finder field) => tester
    .scrollUntilVisible(field, 300, scrollable: find.byType(Scrollable).first);

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Size size, {
  _DiscountsRepository? repository,
  DiscountListItem? initialDiscount,
  Locale locale = const Locale('en'),
  DiscountCapabilities capabilities = const DiscountCapabilities(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<DiscountsCubit>(
          create: (_) => DiscountsCubit(
            repository: repository ?? _DiscountsRepository(),
            capabilityLoader: () async => capabilities,
          ),
          child: CreateDiscountPolicyScreen(initialDiscount: initialDiscount),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _submitValidDraft(WidgetTester tester) async {
  _fillRequiredFields(tester, name: 'Backend validation', value: '10');
  await tester.pump();
  final AppLocalizations l10n = AppLocalizations.of(
    tester.element(find.byType(CreateDiscountPolicyScreen)),
  );
  await tester.tap(find.text(l10n.discountFormSaveDraft));
  await tester.pump();
}

class _DiscountsRepository extends DiscountsRepository {
  _DiscountsRepository({
    this.stallCreates = false,
    this.couponFailuresRemaining = 0,
    this.detail,
    this.createFailure,
  });

  int detailRequests = 0;
  int createCalls = 0;
  final bool stallCreates;
  DiscountUpsertRequest? lastCreateRequest;
  DiscountUpsertRequest? lastUpdateRequest;
  int generateCouponCalls = 0;
  int couponFailuresRemaining;
  final DiscountDetail? detail;
  final Object? createFailure;
  @override
  Future<DiscountFormReferences> getFormReferences() async =>
      const DiscountFormReferences(
        products: <DiscountFormReference>[
          DiscountFormReference(id: 11, name: 'Cappuccino', isActive: true),
          DiscountFormReference(id: 12, name: 'Espresso', isActive: true),
        ],
        categories: <DiscountFormReference>[
          DiscountFormReference(id: 31, name: 'Coffee', isActive: true),
        ],
        customerGroups: <DiscountFormReference>[
          DiscountFormReference(id: 41, name: 'Members', isActive: true),
        ],
        customers: <DiscountFormReference>[
          DiscountFormReference(
            id: 71,
            name: 'Amina Hassan',
            subtitle: '0933000000',
            isActive: true,
          ),
          DiscountFormReference(
            id: 72,
            name: 'Basil Nasser',
            subtitle: '0933111111',
            isActive: true,
          ),
        ],
        paymentMethods: <DiscountFormReference>[
          DiscountFormReference(id: 61, name: 'Cash drawer', isActive: true),
        ],
      );

  @override
  Future<List<Branch>> getBranches() async => const <Branch>[
    Branch(
      id: 41,
      name: 'Downtown',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];

  @override
  Future<List<DiscountListItem>> getDiscounts() async =>
      const <DiscountListItem>[];

  @override
  Future<DiscountDashboardMetrics> getDashboardMetrics() async =>
      const DiscountDashboardMetrics(actualSavedValueThisMonth: 0);

  @override
  Future<DiscountDetail> getDiscountDetail(String discountId) async {
    detailRequests++;
    return detail ?? _detail;
  }

  @override
  Future<String> generateCouponCode() async {
    generateCouponCalls++;
    if (couponFailuresRemaining > 0) {
      couponFailuresRemaining--;
      throw StateError('unavailable');
    }
    return 'CPN-000$generateCouponCalls';
  }

  @override
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request) async {
    createCalls++;
    lastCreateRequest = request;
    if (stallCreates) return Completer<DiscountListItem>().future;
    if (createFailure != null) throw createFailure!;
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDiscount(String discountId) => throw UnimplementedError();

  @override
  Future<DiscountListItem> setStatus(String discountId, bool isActive) =>
      throw UnimplementedError();

  @override
  Future<DiscountListItem> updateDiscount(
    String discountId,
    DiscountUpsertRequest request,
  ) async {
    lastUpdateRequest = request;
    throw UnimplementedError();
  }
}

const DiscountListItem _editRow = DiscountListItem(
  id: '81',
  name: 'List row name must not hydrate edit',
  code: 'OLD',
  type: 'percentage',
  conditions: 'List row only',
  status: DiscountStatus.active,
  usageCount: 0,
  estimatedSavedValue: 0,
  isActive: true,
);

const DiscountDetail _detail = DiscountDetail(
  id: 81,
  name: 'Complete policy detail',
  applicationMode: 'code',
  type: 'percentage',
  scope: 'category',
  value: 12.5,
  isActive: true,
  appliesToAllBranches: false,
  customerEligibilityMode: 'selected_groups',
  targetProductIds: <int>[],
  targetCategoryIds: <int>[31],
  customerGroupIds: <int>[41],
  branchIds: <int>[41],
  paymentMethodIds: <int>[61],
  code: 'DETAIL12',
  description: 'From detail',
  startDate: '2026-10-01',
  endDate: '2026-10-31',
  activeDays: <String>['Mon', 'Fri'],
  startTime: '22:00:00',
  endTime: '02:00:00',
  minimumOrderAmount: 1000,
  maximumDiscountAmount: 5000,
  usageLimit: 10,
  usageLimitPerCustomer: 2,
);

const DiscountDetail _v2Detail = DiscountDetail(
  id: 82,
  name: 'V2 package',
  code: 'CPN-V2-0001',
  applicationMode: 'code',
  type: 'percentage',
  scope: 'bundle',
  value: 20,
  isActive: true,
  appliesToAllBranches: true,
  customerEligibilityMode: 'selected_customers',
  targetProductIds: <int>[],
  targetCategoryIds: <int>[],
  customerGroupIds: <int>[],
  customerIds: <int>[71],
  branchIds: <int>[],
  paymentMethodIds: <int>[],
  perCustomerDailyUsageLimit: 1,
  channelKeys: <String>['pos', 'delivery'],
  bundleRequirements: <DiscountBundleRequirement>[
    DiscountBundleRequirement(productId: 11, quantity: 1),
  ],
);

const DiscountDetail _variantPackageDetail = DiscountDetail(
  id: 83,
  name: 'Variant package',
  code: 'K7M4P',
  applicationMode: 'code',
  type: 'percentage',
  scope: 'bundle',
  value: 20,
  isActive: true,
  appliesToAllBranches: true,
  customerEligibilityMode: 'all',
  targetProductIds: <int>[],
  targetCategoryIds: <int>[],
  customerGroupIds: <int>[],
  branchIds: <int>[],
  paymentMethodIds: <int>[],
  combinationBehavior: 'exclusive',
  bundleRequirements: <DiscountBundleRequirement>[
    DiscountBundleRequirement(
      productId: 11,
      quantity: 1,
      variantMode: 'selected',
      variantIds: <int>[101, 102],
      variants: <DiscountFormReference>[
        DiscountFormReference(id: 101, name: 'Large', isActive: true),
        DiscountFormReference(id: 102, name: 'Iced', isActive: true),
      ],
    ),
  ],
);

AppSidebarItem _discountsSidebarItem(WidgetTester tester) {
  return tester.widget<AppSidebarItem>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppSidebarItem && widget.label == 'Discounts',
    ),
  );
}
