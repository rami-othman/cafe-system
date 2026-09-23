import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../printer/models/printer_config.dart';
import '../models/cafe_configuration_models.dart';
import '../repositories/cafe_configuration_repository.dart';
import 'cafe_configuration_cubits.dart';

class PrintingState extends Equatable {
  const PrintingState({
    this.status = CafeConfigurationLoadStatus.loading,
    this.branches = const <CafeConfigurationBranch>[],
    this.selectedBranchId,
    this.branch,
    this.config = const PrinterConfig(),
    this.autoPrintAfterPayment = false,
    this.isDirty = false,
    this.error,
    this.formVersion = 0,
  });

  final CafeConfigurationLoadStatus status;
  final List<CafeConfigurationBranch> branches;
  final int? selectedBranchId;
  final CafeConfigurationBranch? branch;
  final PrinterConfig config;
  final bool autoPrintAfterPayment;
  final bool isDirty;
  final String? error;
  final int formVersion;

  @override
  List<Object?> get props => <Object?>[
    status,
    branches,
    selectedBranchId,
    branch,
    config,
    autoPrintAfterPayment,
    isDirty,
    error,
    formVersion,
  ];
}

class PrintingCubit extends Cubit<PrintingState> {
  PrintingCubit(this._repository) : super(const PrintingState());

  final CafeConfigurationRepository _repository;
  int _request = 0;

  Future<void> load({int? preferredBranchId}) async {
    final int request = ++_request;
    emit(const PrintingState());
    try {
      final branches = await _repository.getBranches();
      if (isClosed || request != _request) return;
      final int? id = branches.any((b) => b.id == preferredBranchId)
          ? preferredBranchId
          : (branches.isEmpty ? null : branches.first.id);
      emit(
        PrintingState(
          status: id == null
              ? CafeConfigurationLoadStatus.ready
              : CafeConfigurationLoadStatus.loading,
          branches: branches,
          selectedBranchId: id,
        ),
      );
      if (id != null) await _loadBranch(id, request);
    } catch (_) {
      if (!isClosed && request == _request) {
        emit(
          const PrintingState(
            status: CafeConfigurationLoadStatus.failure,
            error: 'load',
          ),
        );
      }
    }
  }

  Future<void> selectBranch(int id) async {
    if ((id == state.selectedBranchId && state.branch != null) ||
        !state.branches.any((branch) => branch.id == id) ||
        state.status == CafeConfigurationLoadStatus.submitting) {
      return;
    }
    final request = ++_request;
    emit(PrintingState(branches: state.branches, selectedBranchId: id));
    await _loadBranch(id, request);
  }

  Future<void> _loadBranch(int id, int request) async {
    try {
      final branch = await _repository.getBranch(id);
      if (isClosed || request != _request) return;
      emit(
        PrintingState(
          status: CafeConfigurationLoadStatus.ready,
          branches: state.branches,
          selectedBranchId: id,
          branch: branch,
          config: branch.printerConfig,
          autoPrintAfterPayment: branch.autoPrintAfterPayment,
        ),
      );
    } catch (_) {
      if (!isClosed && request == _request) {
        emit(
          PrintingState(
            status: CafeConfigurationLoadStatus.failure,
            branches: state.branches,
            selectedBranchId: id,
            error: 'load',
          ),
        );
      }
    }
  }

  void update({PrinterConfig? config, bool? autoPrintAfterPayment}) {
    final branch = state.branch;
    if (branch == null ||
        state.status == CafeConfigurationLoadStatus.submitting) {
      return;
    }
    final nextConfig = config ?? state.config;
    final nextAuto = autoPrintAfterPayment ?? state.autoPrintAfterPayment;
    emit(
      PrintingState(
        status: CafeConfigurationLoadStatus.ready,
        branches: state.branches,
        selectedBranchId: state.selectedBranchId,
        branch: branch,
        config: nextConfig,
        autoPrintAfterPayment: nextAuto,
        isDirty:
            nextConfig != branch.printerConfig ||
            nextAuto != branch.autoPrintAfterPayment,
        formVersion: state.formVersion,
      ),
    );
  }

  void reset() {
    final branch = state.branch;
    if (branch == null) return;
    emit(
      PrintingState(
        status: CafeConfigurationLoadStatus.ready,
        branches: state.branches,
        selectedBranchId: state.selectedBranchId,
        branch: branch,
        config: branch.printerConfig,
        autoPrintAfterPayment: branch.autoPrintAfterPayment,
        formVersion: state.formVersion + 1,
      ),
    );
  }

  Future<void> save() async {
    final branch = state.branch;
    if (branch == null ||
        !state.isDirty ||
        state.status == CafeConfigurationLoadStatus.submitting) {
      return;
    }
    if (state.config.enabled && !state.config.isValid) {
      emit(_withStatus(CafeConfigurationLoadStatus.failure, 'validation'));
      return;
    }
    final config = state.config;
    final autoPrint = state.autoPrintAfterPayment;
    emit(_withStatus(CafeConfigurationLoadStatus.submitting, null));
    try {
      final saved = await _repository.updateBranch(
        branch.id,
        BranchDraft.fromBranch(
          branch,
        ).copyWith(printerConfig: config, autoPrintAfterPayment: autoPrint),
      );
      if (isClosed) return;
      emit(
        PrintingState(
          status: CafeConfigurationLoadStatus.success,
          branches: state.branches,
          selectedBranchId: branch.id,
          branch: saved,
          config: saved.printerConfig,
          autoPrintAfterPayment: saved.autoPrintAfterPayment,
          formVersion: state.formVersion + 1,
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(_withStatus(CafeConfigurationLoadStatus.failure, 'save'));
      }
    }
  }

  PrintingState _withStatus(
    CafeConfigurationLoadStatus status,
    String? error,
  ) => PrintingState(
    status: status,
    branches: state.branches,
    selectedBranchId: state.selectedBranchId,
    branch: state.branch,
    config: state.config,
    autoPrintAfterPayment: state.autoPrintAfterPayment,
    isDirty: state.isDirty,
    error: error,
    formVersion: state.formVersion,
  );
}
