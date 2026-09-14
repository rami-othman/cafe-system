import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_state_panel.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('loading uses inert geometry and loading semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const CustomerManagementStatePanel(
          loadingGeometry: CustomerManagementLoadingGeometry.collection,
        ),
      ),
    );

    expect(
      find.byKey(const Key('customer-management-loading-skeleton')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Customer Management content is loading'),
      findsOneWidget,
    );
    expect(find.textContaining('C-'), findsNothing);
    expect(find.textContaining('Ada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail and form loading geometry stays bounded', (tester) async {
    for (final CustomerManagementLoadingGeometry geometry
        in <CustomerManagementLoadingGeometry>[
          CustomerManagementLoadingGeometry.detail,
          CustomerManagementLoadingGeometry.form,
        ]) {
      await tester.pumpWidget(
        SizedBox(
          width: 500,
          height: 800,
          child: _host(CustomerManagementStatePanel(loadingGeometry: geometry)),
        ),
      );
      expect(
        find.byKey(const Key('customer-management-loading-skeleton')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('loading skeleton stays overflow-free across required widths', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final Size size in <Size>[
      const Size(1440, 900),
      const Size(1280, 800),
      const Size(500, 800),
      const Size(760, 600),
      const Size(759, 600),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _host(
          const CustomerManagementStatePanel(
            loadingGeometry: CustomerManagementLoadingGeometry.collection,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'size=$size');
    }
  });
}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
