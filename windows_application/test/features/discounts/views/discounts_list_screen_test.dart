import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/core/theme/app_colors.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
import 'package:windows_application/features/discounts/views/discounts_list_screen.dart';
import 'package:windows_application/features/discounts/widgets/discount_status_badge.dart';

void main() {
  testWidgets('renders the page heading and three summary cards', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Discounts & Coupons'), findsOneWidget);
    expect(
      find.text('Manage promotional offers and pricing rules'),
      findsOneWidget,
    );
    expect(find.text('ACTIVE DISCOUNTS'), findsOneWidget);
    expect(find.text('TOTAL USAGE (THIS MONTH)'), findsOneWidget);
    expect(find.text('ESTIMATED VALUE SAVED'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('486'), findsOneWidget);
    expect(find.text('\$1,240.50'), findsOneWidget);
  });

  testWidgets('renders the four Figma reference rows on the first page', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    for (final String name in <String>[
      'Morning Rush 15%',
      'Student Discount',
      'Holiday Special',
      'Summer Coolers',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Showing 1 to 4 of 24 entries'), findsOneWidget);
  });

  testWidgets('filters local discounts by search query', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('discounts-search-field')),
      'student id',
    );
    await tester.pump();

    expect(find.text('Student Discount'), findsOneWidget);
    expect(find.text('Morning Rush 15%'), findsNothing);
    expect(find.text('Showing 1 to 1 of 1 entries'), findsOneWidget);
  });

  testWidgets('filters local discounts by status', (WidgetTester tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(const Key('discount-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scheduled').last);
    await tester.pump();

    expect(find.text('Holiday Special'), findsOneWidget);
    expect(find.text('Morning Rush 15%'), findsNothing);
  });

  testWidgets('changes pages with local pagination state', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('2'));
    await tester.pump();

    expect(find.text('Weekday Lunch'), findsOneWidget);
    expect(find.text('Morning Rush 15%'), findsNothing);
    expect(find.text('Showing 5 to 8 of 24 entries'), findsOneWidget);
  });

  testWidgets('uses the light selected pagination treatment from Figma', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    final OutlinedButton pageOne = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('1'), matching: find.byType(OutlinedButton)),
    );

    expect(
      pageOne.style!.backgroundColor!.resolve(<WidgetState>{}),
      AppColors.background,
    );
    expect(
      pageOne.style!.foregroundColor!.resolve(<WidgetState>{}),
      AppColors.paginationActive,
    );
  });

  testWidgets('shows a polished empty state when there are no matches', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('discounts-search-field')),
      'not-a-real-discount',
    );
    await tester.pump();

    expect(
      find.text('No discounts match your search or status filter.'),
      findsOneWidget,
    );
  });

  testWidgets('renders active, scheduled, and expired status badges', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is DiscountStatusBadge &&
            widget.status == DiscountStatus.active,
      ),
      findsNWidgets(2),
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is DiscountStatusBadge &&
            widget.status == DiscountStatus.scheduled,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is DiscountStatusBadge &&
            widget.status == DiscountStatus.expired,
      ),
      findsOneWidget,
    );
  });

  testWidgets('is overflow-free at the 1280 by 800 desktop reference size', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 800));

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, [
  Size size = const Size(1280, 800),
]) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: BlocProvider<DiscountsCubit>(
          create: (_) => DiscountsCubit(),
          child: const DiscountsListScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}
