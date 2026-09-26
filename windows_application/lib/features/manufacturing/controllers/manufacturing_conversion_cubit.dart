import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../repositories/manufacturing_repository.dart';
import 'manufacturing_conversion_state.dart';

/// Unit/item conversion screen-cluster. Every quantity, unit-cost, and the
/// conversion itself are backend-calculated; this Cubit only submits the
/// request and renders the response.
class ManufacturingConversionCubit extends Cubit<ManufacturingConversionState> {
  ManufacturingConversionCubit({
    required this.repository,
    String Function(String operation)? operationKeyGenerator,
  }) : _operationKeyGenerator = operationKeyGenerator ?? _defaultOperationKey,
       super(const ManufacturingConversionState());

  final ManufacturingRepository repository;
  final String Function(String operation) _operationKeyGenerator;

  String? _fingerprint;
  String? _key;

  Future<bool> convert({
    required int warehouseId,
    required int sourceItemId,
    required String sourceQty,
    required int targetItemId,
    required String resultQty,
  }) async {
    final String fingerprint =
        'w$warehouseId|s$sourceItemId|sq$sourceQty|t$targetItemId|rq$resultQty';
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _key = null;
    }
    final String idempotencyKey = _key ??= _operationKeyGenerator('conversion');

    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final result = await repository.createConversion(<String, dynamic>{
        'warehouseId': warehouseId,
        'sourceItemId': sourceItemId,
        'sourceQty': sourceQty,
        'targetItemId': targetItemId,
        'resultQty': resultQty,
        'idempotencyKey': idempotencyKey,
      });
      emit(state.copyWith(submitting: false, result: result, clearError: true));
      _fingerprint = null;
      _key = null;
      return true;
    } catch (error) {
      emit(state.copyWith(submitting: false, error: _messageFor(error)));
      return false;
    }
  }

  Future<void> loadConversion(String idOrReference) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final result = await repository.conversion(idOrReference);
      emit(state.copyWith(result: result, clearError: true));
    } catch (error) {
      emit(state.copyWith(error: _messageFor(error)));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  String _messageFor(Object error) {
    final ApiException? apiError = error is ApiException ? error : null;
    return apiError?.message ?? 'تعذر إتمام التحويل، حاول مرة أخرى.';
  }

  static String _defaultOperationKey(String operation) {
    final int random = Random.secure().nextInt(0x100000000);
    return '$operation-${DateTime.now().microsecondsSinceEpoch}-${random.toRadixString(16)}';
  }
}
