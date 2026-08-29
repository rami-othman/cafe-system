import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/navigation/unsaved_navigation_guard.dart';
import 'package:windows_application/features/menu_management/widgets/menu_module_navigation.dart';
import 'package:windows_application/shared/widgets/app_sidebar.dart';

void main() {
  testWidgets('horizontal navigation keeps a dirty editor until Leave', (
    WidgetTester tester,
  ) async {
    final UnsavedNavigationController controller =
        UnsavedNavigationController();
    await tester.binding.setSurfaceSize(const Size(1920, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_GuardedRouter(controller: controller));

    await tester.tap(find.byKey(const Key('menu-module-menus')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Product editor'), findsOneWidget);

    controller.go(tester.element(find.text('Product editor')), '/reports');

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Product editor'), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-module-menus')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Menus destination'), findsOneWidget);

    controller.go(tester.element(find.text('Menus destination')), '/reports');
    await tester.pumpAndSettle();
    expect(find.text('Reports destination'), findsOneWidget);
  });

  testWidgets('global sidebar uses the same dirty-editor decision', (
    WidgetTester tester,
  ) async {
    final UnsavedNavigationController controller =
        UnsavedNavigationController();
    await tester.binding.setSurfaceSize(const Size(1920, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_GuardedRouter(controller: controller));

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Product editor'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Reports destination'), findsOneWidget);
  });

  testWidgets('clean editor navigation is immediate and does not prompt', (
    WidgetTester tester,
  ) async {
    final UnsavedNavigationController controller =
        UnsavedNavigationController();
    await tester.binding.setSurfaceSize(const Size(1920, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _GuardedRouter(controller: controller, initiallyDirty: false),
    );

    await tester.tap(find.byKey(const Key('menu-module-review')));
    await tester.pumpAndSettle();
    expect(find.text('Review destination'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsNothing);
  });
}

class _GuardedRouter extends StatelessWidget {
  const _GuardedRouter({required this.controller, this.initiallyDirty = true});

  final UnsavedNavigationController controller;
  final bool initiallyDirty;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/edit',
      routes: <RouteBase>[
        GoRoute(
          path: '/edit',
          builder: (_, _) => _Editor(initiallyDirty: initiallyDirty),
        ),
        GoRoute(
          path: '/menu-management/menus',
          builder: (_, _) => const Scaffold(body: Text('Menus destination')),
        ),
        GoRoute(
          path: '/menu-management/review',
          builder: (_, _) => const Scaffold(body: Text('Review destination')),
        ),
        GoRoute(
          path: '/reports',
          builder: (_, _) => const Scaffold(body: Text('Reports destination')),
        ),
      ],
    );
    return UnsavedNavigationScope(
      controller: controller,
      child: MaterialApp.router(routerConfig: router),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({required this.initiallyDirty});

  final bool initiallyDirty;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late bool _dirty = widget.initiallyDirty;
  late VoidCallback _unregister;
  bool _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registered) return;
    _registered = true;
    _unregister = UnsavedNavigationScope.of(context).register(
      UnsavedNavigationGuard(
        isDirty: () => _dirty,
        confirmLeave: () async {
          final bool? leave = await showDialog<bool>(
            context: context,
            builder: (BuildContext dialog) => AlertDialog(
              title: const Text('Unsaved changes'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Leave'),
                ),
              ],
            ),
          );
          return leave == true;
        },
      ),
    );
  }

  @override
  void dispose() {
    if (_registered) _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: <Widget>[
        const SizedBox(
          width: 260,
          child: AppSidebar(activeLabel: 'Menu Management'),
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              const MenuModuleNavigation(
                selected: MenuModuleDestination.products,
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Product editor'),
                      TextButton(
                        onPressed: () => setState(() => _dirty = !_dirty),
                        child: const Text('Toggle dirty'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
