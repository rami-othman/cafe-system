import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/shared/widgets/settings_ui.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('number stepper clamps to its range and reports each step', (
    tester,
  ) async {
    final controller = TextEditingController(text: '2');
    final changes = <String>[];
    var value = 2;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SettingsNumberStepper(
            fieldKey: const Key('count'),
            controller: controller,
            label: 'Count',
            min: 1,
            max: 3,
            value: value,
            decreaseLabel: 'Decrease',
            increaseLabel: 'Increase',
            onChanged: (v) => setState(() {
              changes.add(v);
              value = int.parse(v);
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Increase'));
    await tester.pump();
    expect(controller.text, '3');
    // At the maximum the + button is disabled.
    await tester.tap(find.byTooltip('Increase'));
    await tester.pump();
    expect(changes, ['3']);
    await tester.tap(find.byTooltip('Decrease'));
    await tester.pump();
    await tester.tap(find.byTooltip('Decrease'));
    await tester.pump();
    expect(controller.text, '1');
    expect(changes, ['3', '2', '1']);
    // Typing still works.
    await tester.enterText(find.byKey(const Key('count')), '2');
    expect(changes.last, '2');
    controller.dispose();
  });

  testWidgets('an inactive stepper keeps its value and disables everything', (
    tester,
  ) async {
    final controller = TextEditingController(text: '3');
    await tester.pumpWidget(
      _host(
        SettingsNumberStepper(
          fieldKey: const Key('count'),
          controller: controller,
          label: 'Count',
          min: 1,
          max: 10,
          value: 3,
          decreaseLabel: 'Decrease',
          increaseLabel: 'Increase',
          onChanged: null,
        ),
      ),
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('count'))).enabled,
      false,
    );
    await tester.tap(find.byTooltip('Increase'), warnIfMissed: false);
    expect(controller.text, '3');
    controller.dispose();
  });

  for (final width in [400.0, 900.0]) {
    testWidgets('choice cards select one value at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      var value = 'a';
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => SettingsChoiceCards<String>(
              label: 'Mode',
              value: value,
              onChanged: (v) => setState(() => value = v),
              choices: const [
                SettingsChoice(key: Key('a'), value: 'a', title: 'A'),
                SettingsChoice(
                  key: Key('b'),
                  value: 'b',
                  title: 'B',
                  help: 'Second',
                ),
              ],
            ),
          ),
        ),
      );
      final a = tester.getTopLeft(find.byKey(const Key('a')));
      final b = tester.getTopLeft(find.byKey(const Key('b')));
      // Side by side when wide, stacked when narrow.
      expect(a.dy == b.dy, width > 520);
      await tester.tap(find.byKey(const Key('b')));
      await tester.pump();
      expect(value, 'b');
      expect(
        tester.getSemantics(find.byKey(const Key('b'))),
        isSemantics(
          isButton: true,
          isSelected: true,
          isEnabled: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: false,
          label: 'B\nSecond',
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('inactive choice cards ignore taps', (tester) async {
    await tester.pumpWidget(
      _host(
        const SettingsChoiceCards<String>(
          value: 'a',
          onChanged: null,
          choices: [
            SettingsChoice(key: Key('a'), value: 'a', title: 'A'),
            SettingsChoice(key: Key('b'), value: 'b', title: 'B'),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('b')), warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('section card shows its notice and separates rows; RTL safe', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SettingsSectionCard(
          icon: Icons.tune,
          title: 'عام',
          description: 'وصف',
          notice: const SettingsNotice(message: 'تنبيه'),
          children: [
            SettingsSwitchTile(
              tileKey: const Key('one'),
              title: 'الأول',
              value: true,
              onChanged: (_) {},
            ),
            const SettingsSwitchTile(
              tileKey: Key('two'),
              title: 'الثاني',
              value: false,
              onChanged: null,
            ),
          ],
        ),
        direction: TextDirection.rtl,
      ),
    );
    expect(find.text('تنبيه'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('two'))).onChanged,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
