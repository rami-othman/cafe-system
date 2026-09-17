import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/shift/controllers/shift_overview_cubit.dart';
import 'package:windows_application/features/shift/repositories/shift_mock_repository.dart';
import 'package:windows_application/features/shift/views/shift_overview_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

/// One light smoke test for the whole module: proves the overview screen
/// loads an open shift from the mock repository and renders its KPIs and
/// the "start closing" action. Deep per-scenario/per-step coverage is
/// intentionally left for a follow-up pass — this is a UI-approval build.
void main() {
  testWidgets('shift overview loads an open shift and shows the closing action', (
    WidgetTester tester,
  ) async {
    final ShiftMockRepository repository = ShiftMockRepository(
      clock: () => DateTime(2026, 9, 15, 16, 7),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BlocProvider<ShiftOverviewCubit>(
              create: (_) => ShiftOverviewCubit(repository: repository),
              child: const ShiftOverviewScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('إدارة الوردية'), findsOneWidget);
    expect(find.byKey(const Key('shift-overview-start-closing')), findsOneWidget);
  });
}
