import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/shift/controllers/shift_overview_cubit.dart';
import 'package:windows_application/features/shift/repositories/shift_mock_repository.dart';
import 'package:windows_application/features/shift/repositories/shift_repository.dart';
import 'package:windows_application/features/shift/models/shift_models.dart';
import 'package:windows_application/features/shift/views/shift_overview_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

/// One light smoke test for the whole module: proves the overview screen
/// loads an open shift from the mock repository and renders its KPIs and
/// the "start closing" action. Deep per-scenario/per-step coverage is
/// intentionally left for a follow-up pass — this is a UI-approval build.
void main() {
  testWidgets('opening rejection is visible on the opening form', (
    WidgetTester tester,
  ) async {
    final cubit = ShiftOverviewCubit(repository: _RejectedOpeningRepository());
    await tester.pumpWidget(
      BlocProvider<PosCubit>(
        create: (_) => PosCubit(repository: PosRepository()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: Scaffold(
            body: BlocProvider<ShiftOverviewCubit>.value(
              value: cubit,
              child: const ShiftOverviewScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    cubit.updateOpeningFloat('0');
    expect(await cubit.openShift(), isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shift-opening-error')), findsOneWidget);
    expect(find.text(_RejectedOpeningRepository.message), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
  testWidgets(
    'shift overview loads an open shift and shows the closing action',
    (WidgetTester tester) async {
      final ShiftMockRepository repository = ShiftMockRepository(
        clock: () => DateTime(2026, 9, 15, 16, 7),
      );

      await tester.pumpWidget(
        BlocProvider<PosCubit>(
          create: (_) => PosCubit(repository: PosRepository()),
          child: MaterialApp(
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
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('إدارة الوردية'), findsOneWidget);
      expect(
        find.byKey(const Key('shift-overview-start-closing')),
        findsOneWidget,
      );
    },
  );
}

class _RejectedOpeningRepository extends ShiftRepository {
  static const message = 'وجهة تحويل النقدية عند الإغلاق غير محددة.';

  @override
  Future<ShiftSnapshot?> loadOpenShift() async => null;

  @override
  Future<ShiftHistoryEntry?> loadLastShift() async => null;

  @override
  Future<ShiftSnapshot> openShift({
    required double openingFloat,
    required String note,
    int? branchId,
  }) async => throw const ShiftDataException(message);
}
