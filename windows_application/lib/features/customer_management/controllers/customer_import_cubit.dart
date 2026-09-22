import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/customer_failure.dart';
import '../models/customer_import_models.dart';
import '../repositories/customer_import_repository.dart';
import 'customer_import_state.dart';

class CustomerImportCubit extends Cubit<CustomerImportState> {
  CustomerImportCubit(this._repository) : super(const CustomerImportState());

  final CustomerImportRepository _repository;
  Future<void>? _request;
  Timer? _pollTimer;
  int _generation = 0;

  Future<void> preview({required Uint8List bytes, required String filename}) {
    if (_request != null) return _request!;
    final Future<void> request = _preview(bytes: bytes, filename: filename);
    _request = request;
    return request.whenComplete(() {
      if (identical(_request, request)) _request = null;
    });
  }

  Future<void> _preview({
    required Uint8List bytes,
    required String filename,
  }) async {
    final int generation = ++_generation;
    emit(
      state.copyWith(
        status: CustomerImportCubitStatus.previewing,
        clearFailure: true,
      ),
    );
    try {
      final CustomerImportStatus result = await _repository
          .previewCustomerImport(bytes: bytes, filename: filename);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerImportCubitStatus.ready,
          importStatus: result,
          clearFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerImportCubitStatus.failure,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  Future<void> commit({required bool createMissingGroups}) {
    if (_request != null ||
        state.importStatus == null ||
        state.importStatus!.isTerminal) {
      return _request ?? Future<void>.value();
    }
    final Future<void> request = _commit(
      createMissingGroups: createMissingGroups,
    );
    _request = request;
    return request.whenComplete(() {
      if (identical(_request, request)) _request = null;
    });
  }

  Future<void> _commit({required bool createMissingGroups}) async {
    final int generation = ++_generation;
    emit(
      state.copyWith(
        status: CustomerImportCubitStatus.committing,
        clearFailure: true,
      ),
    );
    try {
      final CustomerImportStatus result = await _repository
          .commitCustomerImport(
            importId: state.importStatus!.id,
            createMissingGroups: createMissingGroups,
          );
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: result.isTerminal
              ? CustomerImportCubitStatus.success
              : CustomerImportCubitStatus.polling,
          importStatus: result,
          clearFailure: true,
        ),
      );
      if (!result.isTerminal) _schedulePoll(generation);
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerImportCubitStatus.failure,
          failure: CustomerFailure.fromError(error),
        ),
      );
    }
  }

  void _schedulePoll(int generation) {
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 1), () async {
      if (isClosed || generation != _generation || state.importStatus == null) {
        return;
      }
      try {
        final CustomerImportStatus result = await _repository.getCustomerImport(
          state.importStatus!.id,
        );
        if (isClosed || generation != _generation) return;
        emit(
          state.copyWith(
            status: result.isTerminal
                ? CustomerImportCubitStatus.success
                : CustomerImportCubitStatus.polling,
            importStatus: result,
            clearFailure: true,
          ),
        );
        if (!result.isTerminal) _schedulePoll(generation);
      } catch (error) {
        if (isClosed || generation != _generation) return;
        emit(
          state.copyWith(
            status: CustomerImportCubitStatus.failure,
            failure: CustomerFailure.fromError(error),
          ),
        );
      }
    });
  }

  Future<Uint8List?> downloadErrors() async {
    final int? id = state.importStatus?.id;
    if (id == null) return null;
    try {
      return await _repository.downloadCustomerImportErrors(id);
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CustomerImportCubitStatus.failure,
            failure: CustomerFailure.fromError(error),
          ),
        );
      }
      return null;
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _pollTimer?.cancel();
    _request = null;
    return super.close();
  }
}
