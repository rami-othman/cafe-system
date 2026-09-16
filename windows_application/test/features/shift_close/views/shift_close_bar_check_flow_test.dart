import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/shift_close/controllers/bar_check_cubit.dart';
import 'package:windows_application/features/shift_close/controllers/shift_close_cubit.dart';
import 'package:windows_application/features/shift_close/models/bar_check_line.dart';
import 'package:windows_application/features/shift_close/models/bar_check_session.dart';
import 'package:windows_application/features/shift_close/repositories/shift_close_repository.dart';
import 'package:windows_application/features/shift_close/views/bar_check_screen.dart';
import 'package:windows_application/features/shift_close/views/shift_close_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

/// Proves the section-8 UX contract end to end: POS -> Close Shift detects a
/// required bar check -> the dedicated Bar Check screen opens -> posting it
/// returns to Shift Close, which then finishes closing the shift
/// automatically — the cashier never has to enter the Inventory Center.
void main() {
  testWidgets(
    'shift close routes to the required bar check and finishes closing on return',
    (WidgetTester tester) async {
      final _FlowRepository repository = _FlowRepository();
      final PosCubit posCubit = PosCubit(repository: PosRepository());
      await posCubit.loadInitialData(); // non-backend PosRepository yields shiftId: 1
      addTearDown(posCubit.close);

      final GoRouter router = GoRouter(
        initialLocation: '/shift-close',
        routes: <RouteBase>[
          GoRoute(
            path: '/shift-close',
            builder: (context, state) => BlocProvider<ShiftCloseCubit>(
              create: (_) => ShiftCloseCubit(repository: repository),
              child: const ShiftCloseScreen(),
            ),
          ),
          GoRoute(
            path: BarCheckScreen.routePath,
            builder: (context, state) => BlocProvider<BarCheckCubit>(
              create: (_) => BarCheckCubit(repository: repository),
              child: BarCheckScreen(args: state.extra! as BarCheckScreenArgs),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        BlocProvider<PosCubit>.value(
          value: posCubit,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('shift-close-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byType(BarCheckScreen), findsOneWidget,
          reason: 'a required bar check must route to the dedicated screen');
      expect(repository.closeShiftCalls, 1);

      await tester.tap(find.byKey(const Key('bar-check-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byType(BarCheckScreen), findsNothing,
          reason: 'posting the bar check must return to Shift Close');
      expect(find.byType(ShiftCloseScreen), findsOneWidget);
      expect(
        repository.closeShiftCalls,
        2,
        reason: 'Shift Close must finish automatically once the bar check is posted',
      );
      expect(repository.transitionCalls, <String>['submit', 'approve', 'post']);
    },
  );
}

class _FlowRepository extends ShiftCloseRepository {
  _FlowRepository() : super(DioApiClient());

  int closeShiftCalls = 0;
  final List<String> transitionCalls = <String>[];

  static const BarCheckLine _line = BarCheckLine(
    itemId: 5,
    itemName: 'Vodka',
    unit: 'kilogram',
    isRequired: true,
    isCounted: true,
    expectedQuantity: '0.000',
    countedQuantity: '0.000',
    varianceStatus: 'within_tolerance',
  );

  @override
  Future<Map<String, dynamic>> closeShift({
    required int shiftId,
    required double closingCash,
    String? note,
  }) async {
    closeShiftCalls++;
    if (closeShiftCalls == 1) {
      throw const ApiException(
        message: 'Complete the required bar check before closing the shift.',
        statusCode: 422,
        type: ApiErrorType.validation,
      );
    }
    return <String, dynamic>{'status': 'closed'};
  }

  @override
  Future<int?> requiredTemplateWarehouseForBranch(int branchId) async => 7;

  @override
  Future<BarCheckSession> startBarCheck({
    required int shiftId,
    required int warehouseId,
  }) async =>
      const BarCheckSession(id: 11, status: 'in_progress', lines: <BarCheckLine>[_line]);

  @override
  Future<BarCheckSession> transition(int countId, String action) async {
    transitionCalls.add(action);
    return BarCheckSession(
      id: countId,
      status: switch (action) {
        'submit' => 'submitted',
        'approve' => 'approved',
        'post' => 'posted',
        _ => 'in_progress',
      },
      lines: const <BarCheckLine>[_line],
    );
  }
}
