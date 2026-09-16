import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/shift_close/controllers/shift_close_cubit.dart';
import 'package:windows_application/features/shift_close/controllers/shift_close_state.dart';
import 'package:windows_application/features/shift_close/repositories/shift_close_repository.dart';

void main() {
  test('closeShift succeeds and emits closed', () async {
    final cubit = ShiftCloseCubit(repository: _FakeRepository());

    final bool result = await cubit.closeShift(
      shiftId: 1,
      branchId: 1,
      closingCash: 100,
    );

    expect(result, isTrue);
    expect(cubit.state.status, ShiftCloseStatus.closed);
    await cubit.close();
  });

  test(
    'when the backend reports a required bar check, resolves the branch '
    'warehouse instead of failing',
    () async {
      final cubit = ShiftCloseCubit(
        repository: _FakeRepository(
          closeError: const ApiException(
            message: 'Complete the required bar check before closing the shift.',
            statusCode: 422,
            type: ApiErrorType.validation,
          ),
          requiredWarehouseId: 42,
        ),
      );

      final bool result = await cubit.closeShift(
        shiftId: 1,
        branchId: 9,
        closingCash: 100,
      );

      expect(result, isFalse);
      expect(cubit.state.status, ShiftCloseStatus.idle);
      expect(cubit.state.requiredBarCheckWarehouseId, 42);
      await cubit.close();
    },
  );

  test('an unrelated validation failure surfaces as a normal error', () async {
    final cubit = ShiftCloseCubit(
      repository: _FakeRepository(
        closeError: const ApiException(
          message: 'Closing cash is required.',
          statusCode: 422,
          type: ApiErrorType.validation,
        ),
      ),
    );

    final bool result = await cubit.closeShift(
      shiftId: 1,
      branchId: 9,
      closingCash: 100,
    );

    expect(result, isFalse);
    expect(cubit.state.status, ShiftCloseStatus.error);
    expect(cubit.state.requiredBarCheckWarehouseId, isNull);
    expect(cubit.state.errorMessage, 'Closing cash is required.');
    await cubit.close();
  });
}

class _FakeRepository extends ShiftCloseRepository {
  _FakeRepository({this.closeError, this.requiredWarehouseId})
    : super(DioApiClient());

  final ApiException? closeError;
  final int? requiredWarehouseId;

  @override
  Future<Map<String, dynamic>> closeShift({
    required int shiftId,
    required double closingCash,
    String? note,
  }) async {
    if (closeError != null) throw closeError!;
    return <String, dynamic>{'status': 'closed'};
  }

  @override
  Future<int?> requiredTemplateWarehouseForBranch(int branchId) async =>
      requiredWarehouseId;
}
