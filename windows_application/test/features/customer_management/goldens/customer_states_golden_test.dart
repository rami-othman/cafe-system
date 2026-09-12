import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:windows_application/features/customer_management/models/customer_failure.dart';
import 'package:windows_application/features/customer_management/widgets/customer_confirmation_dialog.dart';
import 'package:windows_application/features/customer_management/widgets/customer_management_state_panel.dart';
import 'customer_management_golden_fixtures.dart';
import 'customer_management_golden_harness.dart';

void main() {
  testWidgets('state matrix owns web-desktop and mutation state rows', (
    tester,
  ) async {
    await CustomerManagementGoldenHarness.loadFonts();
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final CustomerManagementGoldenFixtures fixtures =
        CustomerManagementGoldenFixtures();
    final Map<String, Widget> states = <String, Widget>{
      'customer_collection': fixtures.customerCollection(),
      'customer_group_collection': fixtures.groupCollection(),
      'loading': const CustomerManagementStatePanel(
        loadingGeometry: CustomerManagementLoadingGeometry.collection,
      ),
      'empty': CustomerManagementStatePanel(empty: true, onCreate: _noop),
      'no_results': CustomerManagementStatePanel(
        noResults: true,
        onClear: _noop,
      ),
      'forbidden': const CustomerManagementStatePanel(
        failure: CustomerFailure(kind: CustomerFailureKind.forbidden),
      ),
      'not_found': const CustomerManagementStatePanel(
        failure: CustomerFailure(kind: CustomerFailureKind.notFound),
      ),
      'validation': const CustomerManagementStatePanel(
        failure: CustomerFailure(kind: CustomerFailureKind.validation),
      ),
      'progress': const CustomerConfirmationDialog(
        title: 'Adding members',
        message: 'The selected members are being added.',
        confirmLabel: 'Add members',
        isPending: true,
      ),
    };

    for (final MapEntry<String, Widget> state in states.entries) {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        CustomerManagementGoldenHarness.wrap(
          Scaffold(body: state.value),
          size: const Size(1280, 800),
          locale: const Locale('en'),
          direction: TextDirection.ltr,
          groupsSelected: state.key == 'customer_group_collection',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('baselines/customer_states/${state.key}.png'),
      );
    }
  });
}

void _noop() {}
