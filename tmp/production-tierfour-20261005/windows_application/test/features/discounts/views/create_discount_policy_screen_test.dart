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
import 'package:windows_application/features/discounts/models/discount_detail.dart';
import 'package:windows_application/features/discounts/models/discount_form_references.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/shared/widgets/app_sidebar_item.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  tearDown(() {
    appRouter.go(AppRoutes.pos);
  });

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
      'Automatic',
      'BOGO',
      'Manager PIN required',
    ]) {
      expect(find.text(unsupported), findsNothing);
    }

    expect(find.text('Discard Changes'), findsOneWidget);
    expect(find.text('Save as Draft'), findsOneWidget);
    expect(find.text('Activate Discount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick value chips fill the editable custom-value input', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));

    expect(find.byKey(const Key('discount-value-field')), findsOneWidget);
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
    await _pumpScreen(
      tester,
      const Size(1280, 900),
      repository: repository,
    );
    await _selectValueType(tester, 'Fixed Amount');
    _fillRequiredFields(tester, name: 'Zero fixed', value: '0');
    await tester.pump();

    expect(_activateButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Save as Draft'));
    await tester.pump();
    expect(repository.lastCreateRequest!.value, 0);
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
          create: (_) =>
              DiscountsCubit(repository: repository ?? _DiscountsRepository()),
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

class _DiscountsRepository implements DiscountsRepository {
  _DiscountsRepository({
    this.stallCreates = false,
    this.couponFailuresRemaining = 0,
    this.detail,
    this.createFailure,
  });

  int detailRequests = 0;
  final bool stallCreates;
  DiscountUpsertRequest? lastCreateRequest;
  int generateCouponCalls = 0;
  int couponFailuresRemaining;
  final DiscountDetail? detail;
  final Object? createFailure;
  @override
  Future<DiscountFormReferences> getFormReferences() async =>
      const DiscountFormReferences(
        products: <DiscountFormReference>[
          DiscountFormReference(id: 11, name: 'Cappuccino', isActive: true),
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
  ) => throw UnimplementedError();
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

AppSidebarItem _discountsSidebarItem(WidgetTester tester) {
  return tester.widget<AppSidebarItem>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppSidebarItem && widget.label == 'Discounts',
    ),
  );
}
