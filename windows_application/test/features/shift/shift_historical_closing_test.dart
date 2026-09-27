import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/shift/controllers/shift_closing_cubit.dart';
import 'package:windows_application/features/shift/controllers/shift_closing_state.dart';
import 'package:windows_application/features/shift/models/shift_close_preview.dart';
import 'package:windows_application/features/shift/models/shift_models.dart';
import 'package:windows_application/features/shift/repositories/shift_mock_repository.dart';
import 'package:windows_application/features/shift/repositories/shift_repository.dart';

void main() {
  test(
    'changing date resets counts and rejects a superseded preview',
    () async {
      final repository = _PreviewRepository();
      final cubit = ShiftClosingCubit(repository: repository);
      await cubit.load();
      cubit.updateActualCash('100');
      final yesterday = cubit.selectClosingDate(DateTime(2026, 9, 26));
      expect(cubit.state.isPreviewLoading, isTrue);
      expect(cubit.state.cashActualInput, isEmpty);
      expect(cubit.goNext(), isFalse);
      final older = cubit.selectClosingDate(DateTime(2026, 9, 25));
      repository.pending[25]!.complete(repository.preview(25));
      await older;
      repository.pending[26]!.complete(repository.preview(26));
      await yesterday;
      expect(cubit.state.closingDate, DateTime(2026, 9, 25));
      expect(cubit.state.preview!.version, 'preview-25');
      expect(
        cubit.goNext(),
        isFalse,
        reason: 'historical counts require explicit provenance',
      );
      await cubit.close();
    },
  );

  test(
    'current cash and stock counts reconcile to the historical period',
    () async {
      final repository = _PreviewRepository();
      final cubit = ShiftClosingCubit(repository: repository);
      await cubit.load();
      final loading = cubit.selectClosingDate(DateTime(2026, 9, 26));
      repository.pending[26]!.complete(repository.preview(26));
      await loading;
      cubit.selectCashCountBasis(ShiftCountBasis.current);
      cubit.selectBarCountBasis(ShiftCountBasis.current);
      expect(cubit.goNext(), isTrue);
      cubit.updateActualCash('580');
      expect(cubit.state.cashCount!.actual, 500);
      expect(cubit.state.cashCount!.isBalanced, isTrue);
      expect(cubit.state.barLines.single.theoretical, 5);
      cubit.updateCountedQuantity('1', '5');
      expect(cubit.state.barLines.single.status, BarCountStatus.match);
      expect(cubit.goNext(), isTrue);
      expect(cubit.goNext(), isTrue);
      cubit.setAcknowledged(true);
      final result = await cubit.closeShift();
      expect(result, isNotNull);
      expect(repository.draft!.countedCashInput, 580);
      expect(repository.draft!.cash.actual, 500);
      expect(repository.draft!.cashCountBasis, 'current');
      expect(repository.draft!.barCountBasis, 'current');
      expect(repository.draft!.snapshot.barCount.lines.single.counted, 5);
      expect(repository.draft!.previewVersion, 'preview-26');
      await cubit.close();
    },
  );

  test(
    'a failed preview cannot reuse the previous period and failed close preserves inputs',
    () async {
      final repository = _PreviewRepository();
      final cubit = ShiftClosingCubit(repository: repository);
      await cubit.load();
      final loading = cubit.selectClosingDate(DateTime(2026, 9, 26));
      repository.pending[26]!.completeError(
        const ShiftDataException('تعذر تحميل الفترة'),
      );
      await loading;
      expect(cubit.state.periodReady, isFalse);
      expect(cubit.goNext(), isFalse);
      final retry = cubit.selectClosingDate(DateTime(2026, 9, 26));
      repository.pending[26]!.complete(repository.preview(26));
      await retry;
      cubit.selectCashCountBasis(ShiftCountBasis.periodRecorded);
      cubit.selectBarCountBasis(ShiftCountBasis.periodRecorded);
      cubit.goNext();
      cubit.updateActualCash('500');
      cubit.goNext();
      cubit.updateCountedQuantity('1', '8');
      cubit.goNext();
      cubit.setAcknowledged(true);
      repository.rejectClose = true;
      expect(await cubit.closeShift(), isNull);
      expect(cubit.state.status, ShiftClosingStatus.ready);
      expect(cubit.state.cashActualInput, '500');
      expect(cubit.state.barLines.single.counted, 8);
      expect(cubit.state.errorMessage, 'تغيرت المعاينة');
      expect(cubit.state.periodReady, isFalse);
      await cubit.close();
    },
  );
}

class _PreviewRepository extends ShiftMockRepository {
  _PreviewRepository() : super(clock: () => DateTime(2026, 9, 27, 10));

  final Map<int, Completer<ShiftClosePreview>> pending =
      <int, Completer<ShiftClosePreview>>{};
  late ShiftSnapshot initial;
  ShiftClosingResult? draft;
  bool rejectClose = false;

  @override
  Future<ShiftClosePreview> loadClosePreview(
    int shiftId, {
    DateTime? date,
  }) async {
    if (date == null) {
      initial = ShiftMockData.freshSnapshot(
        now: DateTime(2026, 9, 25, 8),
        openingFloat: 500,
      );
      return preview(27);
    }
    final completer = Completer<ShiftClosePreview>();
    pending[date.day] = completer;
    return completer.future;
  }

  ShiftClosePreview preview(int day) {
    final snapshot = initial.copyWith(
      barCount: const BarCountTemplate(
        warehouseName: 'Bar',
        lines: <BarCountLine>[
          BarCountLine(
            id: '1',
            name: 'Beans',
            sku: 'B',
            category: '',
            unit: 'piece',
            decimals: 0,
            theoretical: 8,
            unitCost: 0,
            laterNetQuantity: -3,
          ),
        ],
      ),
    );
    return ShiftClosePreview(
      snapshot: snapshot,
      date: DateTime(2026, 9, day),
      timezone: 'Asia/Damascus',
      openingDate: DateTime(2026, 9, 25),
      today: DateTime(2026, 9, 27),
      endExclusive: DateTime.utc(2026, 9, day, 21),
      historical: day < 27,
      version: 'preview-$day',
      currentLedgerCash: 580,
      laterNetCash: 80,
      transferAmount: 400,
      continuationCashAfterTransfer: 180,
      willContinue: true,
      laterRecordCount: 2,
      issues: const <String>[],
    );
  }

  @override
  Future<ShiftClosingResult> closeShift(ShiftClosingResult value) async {
    draft = value;
    if (rejectClose) throw const ShiftDataException('تغيرت المعاينة');
    return value;
  }
}
