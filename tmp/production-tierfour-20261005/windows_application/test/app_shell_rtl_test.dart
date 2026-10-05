import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_shell.dart';
import 'package:windows_application/core/constants/app_sizes.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/auth/controllers/auth_session_cubit.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    setupServiceLocator(useBackend: false);
  });

  testWidgets(
    'places the RTL Inventory sidebar on the physical right at 1440x900',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthSessionCubit>.value(
            value: serviceLocator<AuthSessionCubit>(),
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: AppShell(
                activeLabel: 'Inventory Management',
                topBar: SizedBox(height: 64),
                child: SizedBox.expand(child: Text('Inventory content')),
              ),
            ),
          ),
        ),
      );

      final Rect sidebar = tester.getRect(find.byType(AppSidebar));
      final Rect content = tester.getRect(find.text('Inventory content'));

      expect(sidebar.width, AppSizes.sidebarWidth);
      expect(sidebar.left, greaterThan(content.left));
      expect(content.right, lessThanOrEqualTo(sidebar.left));
      expect(sidebar.right, closeTo(1440, 0.1));
    },
  );
}
