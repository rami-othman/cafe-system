import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/l10n/app_localizations.dart';

enum MenuDesktopViewport {
  desktop1280(1280),
  desktop1440(1440),
  desktop1920(1920);

  const MenuDesktopViewport(this.width);
  final double width;
}

Future<void> pumpMenuManagementHarness(
  WidgetTester tester, {
  required Widget child,
  MenuDesktopViewport viewport = MenuDesktopViewport.desktop1440,
  Locale locale = const Locale('en'),
  double height = 900,
}) async {
  tester.view.physicalSize = Size(viewport.width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

void expectNoMenuLayoutOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void expectMenuTextDirection(
  WidgetTester tester,
  Finder finder,
  TextDirection direction,
) {
  final BuildContext context = tester.element(finder);
  expect(Directionality.of(context), direction);
}
