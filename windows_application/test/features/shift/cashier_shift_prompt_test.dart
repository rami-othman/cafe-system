import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/controllers/pos_state.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';
import 'package:windows_application/features/shift/models/shift_scenario.dart';
import 'package:windows_application/features/shift/repositories/shift_mock_repository.dart';
import 'package:windows_application/features/shift/widgets/cashier_shift_prompt.dart';
import 'package:windows_application/l10n/app_localizations.dart';

const _branch = Branch(
  id: 7,
  name: 'فرع الاختبار',
  currency: 'SYP',
  timezone: 'Asia/Damascus',
  isActive: true,
);
const _state = PosState(branches: [_branch], branchId: 7);

class _PromptPosCubit extends PosCubit {
  _PromptPosCubit(PosState initial) : super(repository: PosRepository()) {
    emit(initial);
  }
  void update(PosState value) => emit(value);
  int? shiftAfterRefresh;
  @override
  Future<void> refreshShiftStatus() async {
    if (shiftAfterRefresh != null) {
      emit(state.copyWith(shiftId: shiftAfterRefresh));
    }
  }
}

Widget _app(
  _PromptPosCubit pos,
  ShiftMockRepository repository, {
  bool cashier = true,
}) => BlocProvider<PosCubit>.value(
  value: pos,
  child: MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CashierShiftPrompt(
        isCashier: cashier,
        cashierName: 'كاشير الاختبار',
        repository: repository,
        child: const Text('محتوى التطبيق'),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'cashier sees opening after loading; X permits browsing and manual reopening',
    (tester) async {
      final pos = _PromptPosCubit(_state.copyWith(isLoading: true));
      final repository = ShiftMockRepository()
        ..selectScenario(ShiftScenario.noOpenShift);
      await tester.pumpWidget(_app(pos, repository));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cashier-shift-opening-dialog')),
        findsNothing,
      );
      pos.update(_state);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cashier-shift-opening-dialog')),
        findsOneWidget,
      );
      expect(find.text('فرع الاختبار'), findsOneWidget);
      expect(find.text('كاشير الاختبار'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cashier-shift-dismiss')));
      await tester.pumpAndSettle();
      expect(find.text('محتوى التطبيق'), findsOneWidget);
      expect(find.byKey(const Key('cashier-open-shift')), findsOneWidget);
      pos.update(_state.copyWith(searchQuery: 'تحديث'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cashier-shift-opening-dialog')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('cashier-open-shift')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cashier-shift-opening-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('cashier-shift-dismiss')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await pos.close();
    },
  );

  testWidgets('owner and cashier with an existing shift are not prompted', (
    tester,
  ) async {
    final pos = _PromptPosCubit(_state);
    final repository = ShiftMockRepository();
    await tester.pumpWidget(_app(pos, repository, cashier: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cashier-shift-opening-dialog')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    pos.update(_state.copyWith(shiftId: 12));
    await tester.pumpWidget(_app(pos, repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cashier-shift-opening-dialog')), findsNothing);
    expect(find.byKey(const Key('cashier-open-shift')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await pos.close();
  });

  testWidgets('a new float needs an amount; the old float is replaced only on request', (
    tester,
  ) async {
    final pos = _PromptPosCubit(_state);
    final repository = ShiftMockRepository()
      ..selectScenario(ShiftScenario.noOpenShift);
    await tester.pumpWidget(_app(pos, repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shift-opening-float-field')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('shift-new-float-checkbox')));
    await tester.tap(find.byKey(const Key('shift-new-float-checkbox')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shift-opening-float-field')), findsOneWidget);

    // Asking for a new float without an amount is refused before anything is sent.
    await tester.ensureVisible(find.byKey(const Key('shift-open-submit-button')));
    await tester.tap(find.byKey(const Key('shift-open-submit-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shift-confirm-open-button')), findsNothing);

    await tester.enterText(find.byKey(const Key('shift-opening-float-field')), '300');
    await tester.tap(find.byKey(const Key('shift-open-submit-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shift-confirm-open-button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await pos.close();
  });

  testWidgets('successful opening closes the popup after confirmation', (
    tester,
  ) async {
    final pos = _PromptPosCubit(_state);
    final repository = ShiftMockRepository()
      ..selectScenario(ShiftScenario.noOpenShift);
    await tester.pumpWidget(_app(pos, repository));
    await tester.pumpAndSettle();
    // No amount to type: the previous shift's float is carried over by the server.
    expect(find.byKey(const Key('shift-opening-float-field')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('shift-open-submit-button')),
    );
    await tester.tap(find.byKey(const Key('shift-open-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('فرع الاختبار'), findsWidgets);
    pos.shiftAfterRefresh = 12;
    await tester.tap(find.byKey(const Key('shift-confirm-open-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cashier-shift-opening-dialog')), findsNothing);
    expect(repository.scenario, ShiftScenario.balanced);
    expect(find.byKey(const Key('cashier-open-shift')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await pos.close();
  });
}
