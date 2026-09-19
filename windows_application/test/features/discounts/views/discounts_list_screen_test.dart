import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/utils/currency_formatter.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
import 'package:windows_application/features/discounts/models/discount_detail.dart';
import 'package:windows_application/features/discounts/models/discount_form_references.dart';
import 'package:windows_application/features/discounts/models/discount_upsert_request.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/discounts/views/discounts_list_screen.dart';

void main() {
  testWidgets('loads backend-provided discounts and summary metrics', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);
    expect(find.text('Discounts & Coupons'), findsOneWidget);
    expect(find.text('Morning Rush 15%'), findsOneWidget);
    expect(find.text('Student Discount'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('292'), findsOneWidget);
    expect(find.text('520 SYP'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Automatic'), findsNothing);
  });

  testWidgets('filters loaded discounts by search and status', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);
    await tester.enterText(
      find.byKey(const Key('discounts-search-field')),
      'student',
    );
    await tester.pump();
    expect(find.text('Student Discount'), findsOneWidget);
    expect(find.text('Morning Rush 15%'), findsNothing);
  });

  testWidgets('search preserves raw name, coupon code, and conditions', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);
    for (final String query in <String>[
      'Morning Rush',
      'MRNG15',
      'Student ID',
    ]) {
      await tester.enterText(
        find.byKey(const Key('discounts-search-field')),
        query,
      );
      await tester.pump();
      expect(find.byType(DiscountsListScreen), findsOneWidget);
      expect(
        find.text('No discounts match your search or status filter.'),
        findsNothing,
      );
    }
  });

  testWidgets('English search matches localized visible labels', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, repository: _SearchRepository());

    for (final MapEntry<String, String> search in <String, String>{
      'Manual': 'Manual fixed',
      'Code': 'Code percentage',
      'Percentage': 'Code percentage',
      'Fixed Amount': 'Manual fixed',
      'Active': 'Manual fixed',
      'Inactive': 'Code percentage',
      'Scheduled': 'Scheduled offer',
      'Expired': 'Expired offer',
    }.entries) {
      await tester.enterText(
        find.byKey(const Key('discounts-search-field')),
        search.key,
      );
      await tester.pump();
      expect(find.text(search.value), findsOneWidget, reason: search.key);
    }
  });

  testWidgets('Arabic search matches localized visible labels', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: _SearchRepository(),
      locale: const Locale('ar'),
    );

    for (final MapEntry<String, String> search in <String, String>{
      'يدوي': 'Manual fixed',
      'الرمز': 'Code percentage',
      'نسبة مئوية': 'Code percentage',
      'مبلغ ثابت': 'Manual fixed',
      'نشط': 'Manual fixed',
      'غير نشط': 'Code percentage',
      'مجدول': 'Scheduled offer',
      'منتهي': 'Expired offer',
    }.entries) {
      await tester.enterText(
        find.byKey(const Key('discounts-search-field')),
        search.key,
      );
      await tester.pump();
      expect(find.text(search.value), findsOneWidget, reason: search.key);
    }
  });

  testWidgets('Arabic delete confirmation uses localized body', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, locale: const Locale('ar'));

    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.delete_outline).first,
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('حذف الخصم؟'), findsOneWidget);
    expect(find.text('لن يعود Morning Rush 15% متاحاً.'), findsOneWidget);
    expect(find.textContaining('will no longer'), findsNothing);
  });

  testWidgets('canonical period, currency, and counts follow the locale', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: _LocalizedFormattingRepository(),
      locale: const Locale('ar'),
    );

    expect(
      find.textContaining(DateFormat.yMMMd('ar').format(DateTime(2026, 1, 2))),
      findsOneWidget,
    );
    expect(
      find.text(NumberFormat.decimalPattern('ar').format(1234)),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.text(CurrencyFormatter.format(1234, locale: 'ar')),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('Legacy display period'), findsNothing);
  });

  testWidgets('shows the API error instead of mock fallback data', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, repository: _FailingRepository());
    expect(
      find.text('Unable to complete the discount request. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Backend is not reachable.'), findsNothing);
    expect(find.text('Morning Rush 15%'), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  DiscountsRepository? repository,
  Locale locale = const Locale('en'),
}) async {
  final DiscountsCubit cubit = DiscountsCubit(
    repository: repository ?? _Repository(),
  )..loadDiscounts();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<DiscountsCubit>.value(
          value: cubit,
          child: const DiscountsListScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SearchRepository extends _Repository {
  @override
  Future<List<DiscountListItem>> getDiscounts() async => <DiscountListItem>[
    _searchItem('1', 'Manual fixed', 'fixed', DiscountStatus.active),
    _searchItem(
      '2',
      'Code percentage',
      'percentage',
      DiscountStatus.inactive,
      code: 'SAVE20',
    ),
    _searchItem('3', 'Scheduled offer', 'fixed', DiscountStatus.scheduled),
    _searchItem('4', 'Expired offer', 'percentage', DiscountStatus.expired),
  ];
}

class _LocalizedFormattingRepository extends _Repository {
  @override
  Future<List<DiscountListItem>> getDiscounts() async => <DiscountListItem>[
    DiscountListItem(
      id: 'format',
      name: 'بيانات التنسيق',
      type: 'fixed',
      status: DiscountStatus.active,
      usageCount: 1234,
      estimatedSavedValue: 1234,
      value: 1234,
      startDate: DateTime(2026, 1, 2),
      endDate: DateTime(2026, 2, 3),
      displayPeriodPrimary: 'Legacy display period',
    ),
  ];
}

DiscountListItem _searchItem(
  String id,
  String name,
  String type,
  DiscountStatus status, {
  String? code,
}) => DiscountListItem(
  id: id,
  name: name,
  code: code,
  type: type,
  conditions: 'Condition text',
  status: status,
  usageCount: 0,
  estimatedSavedValue: 0,
);

class _Repository implements DiscountsRepository {
  @override
  Future<DiscountFormReferences> getFormReferences() async =>
      const DiscountFormReferences();

  @override
  Future<List<Branch>> getBranches() async => const <Branch>[];
  @override
  Future<List<DiscountListItem>> getDiscounts() async => <DiscountListItem>[
    _item('1', 'Morning Rush 15%', DiscountStatus.active, 128, '192 SYP'),
    _item('2', 'Student Discount', DiscountStatus.active, 164, '328 SYP'),
  ];
  @override
  Future<DiscountDetail> getDiscountDetail(String discountId) =>
      throw UnimplementedError();
  @override
  Future<String> generateCouponCode() => throw UnimplementedError();
  @override
  Future<DiscountListItem> createDiscount(DiscountUpsertRequest request) =>
      throw UnimplementedError();
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

class _FailingRepository extends _Repository {
  @override
  Future<List<DiscountListItem>> getDiscounts() =>
      Future<List<DiscountListItem>>.error(
        const ApiException(message: 'Backend is not reachable.'),
      );
}

DiscountListItem _item(
  String id,
  String name,
  DiscountStatus status,
  int usage,
  String saved,
) => DiscountListItem(
  id: id,
  name: name,
  code: name == 'Student Discount' ? null : 'MRNG15',
  type: name == 'Student Discount' ? 'fixed' : 'percentage',
  conditions: name == 'Student Discount'
      ? 'Requires Student ID tag'
      : 'Min. 10 SYP spent',
  status: status,
  usageCount: usage,
  estimatedSavedValue: double.parse(saved.split(' ').first),
);
