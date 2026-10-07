import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/app/app_router.dart';
import 'package:windows_application/app/shell_page_refresh.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  void bump() => emit(state + 1);
}

void main() {
  for (final String path in <String>[
    AppRoutes.dashboard,
    AppRoutes.cashierInventory,
    AppRoutes.reports,
  ]) {
    testWidgets('top refresh on $path reaches a page-scoped cubit', (
      tester,
    ) async {
      // The "shell" sits above the page's provider, as the real top bar does.
      late BuildContext shellContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              shellContext = context;
              return BlocProvider<_CounterCubit>(
                create: (_) => _CounterCubit(),
                child: RegisterShellRefresh(
                  refresh: (BuildContext context) async =>
                      context.read<_CounterCubit>().bump(),
                  child: BlocBuilder<_CounterCubit, int>(
                    builder: (_, int count) => Text('count $count'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await refreshActionForMatchedLocation(path)!(shellContext);
      await tester.pump();

      expect(find.text('count 1'), findsOneWidget);
    });
  }

  testWidgets('a page cannot clear the handler of the page that replaced it', (
    tester,
  ) async {
    int firstRuns = 0;
    int secondRuns = 0;
    Widget page(Key key, VoidCallback onRun) => RegisterShellRefresh(
      key: key,
      refresh: (_) async => onRun(),
      child: const SizedBox(),
    );

    await tester.pumpWidget(
      MaterialApp(home: page(const ValueKey<int>(1), () => firstRuns++)),
    );
    // New page mounts first, then the old one disposes.
    await tester.pumpWidget(
      MaterialApp(home: page(const ValueKey<int>(2), () => secondRuns++)),
    );
    await ShellPageRefresh.run();

    expect(firstRuns, 0);
    expect(secondRuns, 1);
  });
}
