import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu/views/create_edit_product_screen.dart';

void main() {
  testWidgets('renders the Create Product general information form', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: CreateEditProductScreen()),
      ),
    );

    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Create New Product'), findsOneWidget);
    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('Basic Details'), findsOneWidget);
    expect(find.text('Classification'), findsOneWidget);
    expect(find.text('Pricing & Tax'), findsOneWidget);
    expect(find.text('Channel Visibility'), findsOneWidget);
    expect(find.text('Product Summary'), findsOneWidget);
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('Save as Draft'), findsOneWidget);
    expect(find.text('Save & Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps product configuration state local and shows feedback', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: CreateEditProductScreen()),
      ),
    );

    final List<Switch> switches = tester
        .widgetList<Switch>(find.byType(Switch))
        .toList();
    expect(switches.map((Switch item) => item.value), <bool>[
      true,
      true,
      true,
      false,
    ]);
    expect(
      find.text('Simple product has no sizes or options.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Variant'));
    await tester.pump();
    expect(
      find.text('Variant options will be configured after saving.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save as Draft'));
    await tester.pump();
    expect(
      find.text('Draft saving will be connected in a future task.'),
      findsOneWidget,
    );
  });

  testWidgets('remains overflow-free at a compact desktop width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: CreateEditProductScreen()),
      ),
    );

    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('Save & Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
