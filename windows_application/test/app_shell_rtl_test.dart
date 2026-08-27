import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_shell.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  testWidgets(
    'places the RTL Inventory sidebar on the physical right at 1440x900',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(
            activeLabel: 'Inventory Management',
            textDirection: TextDirection.rtl,
            sidebarWidth: 236,
            topBar: SizedBox(height: 64),
            child: SizedBox.expand(child: Text('Inventory content')),
          ),
        ),
      );

      final Rect sidebar = tester.getRect(find.byType(AppSidebar));
      final Rect content = tester.getRect(find.text('Inventory content'));

      expect(sidebar.width, 236);
      expect(sidebar.left, greaterThan(content.left));
      expect(content.right, lessThanOrEqualTo(sidebar.left));
      expect(sidebar.right, closeTo(1440, 0.1));
    },
  );
}
