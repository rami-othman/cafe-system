import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_management_golden_fixtures.dart';
import 'customer_management_golden_harness.dart';

void main() {
  testWidgets('group screens own every ready locale/viewport row', (
    tester,
  ) async {
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
      await tester.pumpWidget(
        CustomerManagementGoldenHarness.wrap(
          row.screen(fixtures),
          size: row.size,
          locale: row.locale,
          direction: row.direction,
          groupsSelected: true,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('baselines/customer_group_screens/${row.name}.png'),
      );
    }
  });
}

typedef _GoldenScreen = Widget Function(CustomerManagementGoldenFixtures);

class _GoldenRow {
  const _GoldenRow({
    required this.name,
    required this.size,
    required this.locale,
    required this.direction,
    required this.screen,
  });

  final String name;
  final Size size;
  final Locale locale;
  final TextDirection direction;
  final _GoldenScreen screen;
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
  final Map<String, _GoldenScreen> screens = <String, _GoldenScreen>{
    'group_list': (fixtures) => fixtures.groupList(),
    'group_detail': (fixtures) => fixtures.groupDetail(),
    'group_create': (fixtures) => fixtures.groupCreate(),
    'group_edit': (fixtures) => fixtures.groupEdit(),
  };
  final Map<String, Size> sizes = <String, Size>{
    '1440x900': const Size(1440, 900),
    '1280x800': const Size(1280, 800),
    '500x800': const Size(500, 800),
  };
  final List<_GoldenRow> rows = <_GoldenRow>[];
  for (final MapEntry<String, _GoldenScreen> screen in screens.entries) {
    for (final MapEntry<String, Size> size in sizes.entries) {
      rows.add(
        _GoldenRow(
          name: '${screen.key}_${suffix}_${size.key}',
          size: size.value,
          locale: locale,
          direction: direction,
          screen: screen.value,
        ),
      );
    }
  }
  return rows;
}
