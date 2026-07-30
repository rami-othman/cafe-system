import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
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
    expect(find.text('\$520.00'), findsOneWidget);
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

  testWidgets('shows the API error instead of mock fallback data', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, repository: _FailingRepository());
    expect(find.text('Backend is not reachable.'), findsOneWidget);
    expect(find.text('Morning Rush 15%'), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  DiscountsRepository? repository,
}) async {
  final DiscountsCubit cubit = DiscountsCubit(
    repository: repository ?? _Repository(),
  )..loadDiscounts();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
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

class _Repository implements DiscountsRepository {
  @override
  Future<List<Branch>> getBranches() async => const <Branch>[];
  @override
  Future<List<DiscountListItem>> getDiscounts() async => <DiscountListItem>[
    _item('1', 'Morning Rush 15%', DiscountStatus.active, 128, '\$192.00'),
    _item('2', 'Student Discount', DiscountStatus.active, 164, '\$328.00'),
  ];
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
  secondaryLabel: name == 'Student Discount' ? 'Automatic' : 'Code: MRNG15',
  type: name == 'Student Discount' ? 'Fixed Amount' : 'Percentage',
  displayValue: name == 'Student Discount' ? '\$2.00 off' : '15% off',
  conditions: name == 'Student Discount'
      ? 'Requires Student ID tag'
      : 'Min. \$10 spent',
  validPeriodPrimary: 'Always Valid',
  status: status,
  usageCount: usage,
  estimatedSavedValue: saved,
);
