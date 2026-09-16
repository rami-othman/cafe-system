import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/shift_close/controllers/bar_check_cubit.dart';
import 'package:windows_application/features/shift_close/controllers/bar_check_state.dart';
import 'package:windows_application/features/shift_close/models/bar_check_line.dart';
import 'package:windows_application/features/shift_close/models/bar_check_session.dart';
import 'package:windows_application/features/shift_close/repositories/shift_close_repository.dart';

void main() {
  const BarCheckLine line = BarCheckLine(
    itemId: 5,
    itemName: 'Vodka',
    unit: 'kilogram',
    isRequired: true,
    isCounted: true,
    expectedQuantity: '0.000',
    countedQuantity: '0.000',
    varianceStatus: 'within_tolerance',
  );

  test('start loads the count session from the repository', () async {
    final cubit = BarCheckCubit(
      repository: _FakeRepository(
        startResult: const BarCheckSession(
          id: 11,
          status: 'in_progress',
          lines: <BarCheckLine>[line],
        ),
      ),
    );

    await cubit.start(shiftId: 1, warehouseId: 3);

    expect(cubit.state.status, BarCheckStatus.ready);
    expect(cubit.state.session?.id, 11);
    expect(cubit.state.session?.lines, hasLength(1));
    await cubit.close();
  });

  test(
    'submitAndFinish carries a clean count straight through approve and post',
    () async {
      final _FakeRepository repository = _FakeRepository(
        startResult: const BarCheckSession(
          id: 11,
          status: 'in_progress',
          lines: <BarCheckLine>[line],
        ),
        transitionResults: <String, BarCheckSession>{
          'submit': const BarCheckSession(
            id: 11,
            status: 'submitted',
            lines: <BarCheckLine>[line],
          ),
          'approve': const BarCheckSession(
            id: 11,
            status: 'approved',
            lines: <BarCheckLine>[line],
          ),
          'post': const BarCheckSession(
            id: 11,
            status: 'posted',
            lines: <BarCheckLine>[line],
          ),
        },
      );
      final cubit = BarCheckCubit(repository: repository);
      await cubit.start(shiftId: 1, warehouseId: 3);

      final bool result = await cubit.submitAndFinish();

      expect(result, isTrue);
      expect(cubit.state.status, BarCheckStatus.posted);
      expect(repository.transitionCalls, <String>['submit', 'approve', 'post']);
      await cubit.close();
    },
  );

  test(
    'submitAndFinish stops and flags manager review instead of approving',
    () async {
      const BarCheckLine flaggedLine = BarCheckLine(
        itemId: 5,
        itemName: 'Vodka',
        unit: 'kilogram',
        isRequired: true,
        isCounted: true,
        expectedQuantity: '0.000',
        countedQuantity: '9.000',
        varianceStatus: 'needs_manager_review',
      );
      final _FakeRepository repository = _FakeRepository(
        startResult: const BarCheckSession(
          id: 11,
          status: 'in_progress',
          lines: <BarCheckLine>[flaggedLine],
        ),
        transitionResults: <String, BarCheckSession>{
          'submit': const BarCheckSession(
            id: 11,
            status: 'submitted',
            lines: <BarCheckLine>[flaggedLine],
          ),
        },
      );
      final cubit = BarCheckCubit(repository: repository);
      await cubit.start(shiftId: 1, warehouseId: 3);

      final bool result = await cubit.submitAndFinish();

      expect(result, isFalse);
      expect(cubit.state.blockedOnManagerReview, isTrue);
      expect(cubit.state.status, BarCheckStatus.ready);
      expect(repository.transitionCalls, <String>['submit']);
      await cubit.close();
    },
  );
}

class _FakeRepository extends ShiftCloseRepository {
  _FakeRepository({this.startResult, this.transitionResults = const {}})
    : super(DioApiClient());

  final BarCheckSession? startResult;
  final Map<String, BarCheckSession> transitionResults;
  final List<String> transitionCalls = <String>[];

  @override
  Future<BarCheckSession> startBarCheck({
    required int shiftId,
    required int warehouseId,
  }) async => startResult!;

  @override
  Future<BarCheckSession> transition(int countId, String action) async {
    transitionCalls.add(action);
    final BarCheckSession? result = transitionResults[action];
    if (result == null) {
      throw const ApiException(
        message: 'A required manager review is still pending.',
        statusCode: 422,
        type: ApiErrorType.validation,
      );
    }
    return result;
  }
}
