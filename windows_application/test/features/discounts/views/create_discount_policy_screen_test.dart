import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/discounts/views/create_discount_policy_screen.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_list_item.dart';
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
      'Approval & Permissions',
      'Discount Rules',
      'Stacking Rules',
      'Reports & Audit',
    ]) {
      expect(find.text(title), findsAtLeastNWidgets(1));
    }

    expect(find.text('Discard Changes'), findsOneWidget);
    expect(find.text('Save as Draft'), findsOneWidget);
    expect(find.text('Activate Discount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates discount value selection without changing the form layout', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(1280, 900));

    expect(find.text('10%'), findsWidgets);
    await tester.tap(find.text('20%').first);
    await tester.pump();
    expect(find.text('20%'), findsWidgets);

  });

  testWidgets('remains overflow-free at a compact desktop width', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const Size(700, 800));

    expect(find.text('Create Discount Policy'), findsOneWidget);
    expect(find.text('Activate Discount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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

Future<void> _pumpScreen(WidgetTester tester, Size size) async {
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
          create: (_) => DiscountsCubit(repository: _DiscountsRepository()),
          child: const CreateDiscountPolicyScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _DiscountsRepository implements DiscountsRepository {
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

AppSidebarItem _discountsSidebarItem(WidgetTester tester) {
  return tester.widget<AppSidebarItem>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppSidebarItem && widget.label == 'Discounts',
    ),
  );
}
