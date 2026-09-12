import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_management_golden_fixtures.dart';
import 'customer_management_golden_harness.dart';
import 'package:windows_application/features/customer_management/widgets/customer_confirmation_dialog.dart';
import 'package:windows_application/features/customer_management/widgets/customer_group_components.dart';

void main() {
  testWidgets('customer dialogs own every locale/viewport row', (tester) async {
    await CustomerManagementGoldenHarness.loadFonts();
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final _GoldenRow row in _rows) {
      final CustomerManagementGoldenFixtures fixtures =
          CustomerManagementGoldenFixtures();
      tester.view.physicalSize = row.size;
      tester.view.devicePixelRatio = 1;
      final Widget dialog = await row.dialog(fixtures);
      await tester.pumpWidget(
        CustomerManagementGoldenHarness.wrap(
          dialog,
          size: row.size,
          locale: row.locale,
          direction: row.direction,
          groupsSelected: row.name.startsWith('add_members'),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('baselines/customer_dialogs/${row.name}.png'),
      );
    }
  });
}

typedef _GoldenDialog =
    Future<Widget> Function(CustomerManagementGoldenFixtures);

class _GoldenRow {
  const _GoldenRow({
    required this.name,
    required this.size,
    required this.locale,
    required this.direction,
    required this.dialog,
  });

  final String name;
  final Size size;
  final Locale locale;
  final TextDirection direction;
  final _GoldenDialog dialog;
}

final List<_GoldenRow> _rows = <_GoldenRow>[
  ..._rowsFor('en_ltr', const Locale('en'), TextDirection.ltr),
  ..._rowsFor('ar_rtl', const Locale('ar'), TextDirection.rtl),
];

List<_GoldenRow> _rowsFor(
  String suffix,
  Locale locale,
  TextDirection direction,
) {
  final Map<String, _GoldenDialog> dialogs = <String, _GoldenDialog>{
    'add_members': (fixtures) async {
      final cubit = await fixtures.membershipCubit();
      return CustomerGroupCandidateDialog(cubit: cubit, onDone: () {});
    },
    'lifecycle_confirmation': (fixtures) async => fixtures.confirmation(),
    'member_removal_confirmation': (fixtures) async => const Scaffold(
      body: CustomerConfirmationDialog(
        title: 'Remove Ada Lovelace from VIP Guests?',
        message: 'This member will be removed from the group.',
        confirmLabel: 'Remove member',
      ),
    ),
    'unsaved_change_confirmation': (fixtures) async => const Scaffold(
      body: AlertDialog(
        title: Text('Discard unsaved changes?'),
        content: Text('Your unsaved changes will be lost.'),
        actions: <Widget>[
          TextButton(onPressed: null, child: Text('Keep editing')),
          FilledButton(onPressed: null, child: Text('Leave')),
        ],
      ),
    ),
  };
  final Map<String, Size> sizes = <String, Size>{
    '1440x900': const Size(1440, 900),
    '1280x800': const Size(1280, 800),
    '500x800': const Size(500, 800),
  };
  final List<_GoldenRow> rows = <_GoldenRow>[];
  for (final MapEntry<String, _GoldenDialog> dialog in dialogs.entries) {
    for (final MapEntry<String, Size> size in sizes.entries) {
      rows.add(
        _GoldenRow(
          name: '${dialog.key}_${suffix}_${size.key}',
          size: size.value,
          locale: locale,
          direction: direction,
          dialog: dialog.value,
        ),
      );
    }
  }
  return rows;
}
