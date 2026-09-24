import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../printer/models/printer_config.dart';
import '../../printer/models/receipt_template.dart';
import '../models/cafe_configuration_models.dart';
import '../repositories/cafe_configuration_repository.dart';
import 'cafe_configuration_cubits.dart';

/// Independent status for one of the two printing-config save actions
/// (printer configuration vs. receipt design). Kept separate per action so
/// the UI never implies both saved when only one did — the two are saved
/// through separate backend resources with no shared transaction.
enum SectionSaveStatus { idle, submitting, success, failure }

class PrintingState extends Equatable {
  const PrintingState({
    this.status = CafeConfigurationLoadStatus.loading,
    this.branches = const <CafeConfigurationBranch>[],
    this.selectedBranchId,
    this.branch,
    this.config = const PrinterConfig(),
    this.autoPrintAfterPayment = false,
    this.template = const ReceiptTemplate.defaultTemplate(),
    this.savedTemplate = const ReceiptTemplate.defaultTemplate(),
    this.error,
    this.formVersion = 0,
    this.printerSaveStatus = SectionSaveStatus.idle,
    this.printerSaveError,
    this.templateSaveStatus = SectionSaveStatus.idle,
    this.templateSaveError,
  });

  final CafeConfigurationLoadStatus status;
  final List<CafeConfigurationBranch> branches;
  final int? selectedBranchId;
  final CafeConfigurationBranch? branch;
  final PrinterConfig config;
  final bool autoPrintAfterPayment;
  final ReceiptTemplate template;
  final ReceiptTemplate savedTemplate;

  /// Only ever 'load': failures saving each section have their own
  /// status/error below.
  final String? error;
  final int formVersion;
  final SectionSaveStatus printerSaveStatus;
  final String? printerSaveError;
  final SectionSaveStatus templateSaveStatus;
  final String? templateSaveError;

  bool get isPrinterConfigDirty =>
      branch != null &&
      (config != branch!.printerConfig ||
          autoPrintAfterPayment != branch!.autoPrintAfterPayment);

  bool get isTemplateDirty => template != savedTemplate;

  /// Whether either section has unsaved edits — used only to decide whether
  /// to warn before discarding on a branch switch, never to imply a single
  /// atomic save.
  bool get isDirty => isPrinterConfigDirty || isTemplateDirty;

  PrintingState copyWith({
    CafeConfigurationLoadStatus? status,
    List<CafeConfigurationBranch>? branches,
    int? selectedBranchId,
    CafeConfigurationBranch? branch,
    PrinterConfig? config,
    bool? autoPrintAfterPayment,
    ReceiptTemplate? template,
    ReceiptTemplate? savedTemplate,
    String? error,
    bool clearError = false,
    int? formVersion,
    SectionSaveStatus? printerSaveStatus,
    String? printerSaveError,
    bool clearPrinterSaveError = false,
    SectionSaveStatus? templateSaveStatus,
    String? templateSaveError,
    bool clearTemplateSaveError = false,
  }) => PrintingState(
    status: status ?? this.status,
    branches: branches ?? this.branches,
    selectedBranchId: selectedBranchId ?? this.selectedBranchId,
    branch: branch ?? this.branch,
    config: config ?? this.config,
    autoPrintAfterPayment: autoPrintAfterPayment ?? this.autoPrintAfterPayment,
    template: template ?? this.template,
    savedTemplate: savedTemplate ?? this.savedTemplate,
    error: clearError ? null : error ?? this.error,
    formVersion: formVersion ?? this.formVersion,
    printerSaveStatus: printerSaveStatus ?? this.printerSaveStatus,
    printerSaveError: clearPrinterSaveError
        ? null
        : printerSaveError ?? this.printerSaveError,
    templateSaveStatus: templateSaveStatus ?? this.templateSaveStatus,
    templateSaveError: clearTemplateSaveError
        ? null
        : templateSaveError ?? this.templateSaveError,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    branches,
    selectedBranchId,
    branch,
    config,
    autoPrintAfterPayment,
    template,
    savedTemplate,
    error,
    formVersion,
    printerSaveStatus,
    printerSaveError,
    templateSaveStatus,
    templateSaveError,
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
        state.printerSaveStatus == SectionSaveStatus.submitting ||
        state.templateSaveStatus == SectionSaveStatus.submitting) {
      return;
    }
    final request = ++_request;
    emit(PrintingState(branches: state.branches, selectedBranchId: id));
    await _loadBranch(id, request);
  }

  Future<void> _loadBranch(int id, int request) async {
    try {
      final results = await Future.wait(<Future<Object>>[
        _repository.getBranch(id),
        _repository.getReceiptTemplate(id),
      ]);
      if (isClosed || request != _request) return;
      final branch = results[0] as CafeConfigurationBranch;
      final template = results[1] as ReceiptTemplate;
      emit(
        PrintingState(
          status: CafeConfigurationLoadStatus.ready,
          branches: state.branches,
          selectedBranchId: id,
          branch: branch,
          config: branch.printerConfig,
          autoPrintAfterPayment: branch.autoPrintAfterPayment,
          template: template,
          savedTemplate: template,
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

  void update({
    PrinterConfig? config,
    bool? autoPrintAfterPayment,
    ReceiptTemplate? template,
  }) {
    if (state.branch == null ||
        state.printerSaveStatus == SectionSaveStatus.submitting ||
        state.templateSaveStatus == SectionSaveStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        status: CafeConfigurationLoadStatus.ready,
        config: config,
        autoPrintAfterPayment: autoPrintAfterPayment,
        template: template,
        // Editing a section again after a save result clears that section's
        // stale success/failure banner.
        printerSaveStatus: config != null || autoPrintAfterPayment != null
            ? SectionSaveStatus.idle
            : null,
        clearPrinterSaveError: config != null || autoPrintAfterPayment != null,
        templateSaveStatus: template != null ? SectionSaveStatus.idle : null,
        clearTemplateSaveError: template != null,
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
        template: state.savedTemplate,
        savedTemplate: state.savedTemplate,
        formVersion: state.formVersion + 1,
      ),
    );
  }

  Future<void> savePrinterConfig() async {
    final branch = state.branch;
    if (branch == null ||
        !state.isPrinterConfigDirty ||
        state.printerSaveStatus == SectionSaveStatus.submitting) {
      return;
    }
    if (state.config.enabled && !state.config.isValid) {
      emit(
        state.copyWith(
          printerSaveStatus: SectionSaveStatus.failure,
          printerSaveError: 'validation',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        printerSaveStatus: SectionSaveStatus.submitting,
        clearPrinterSaveError: true,
      ),
    );
    try {
      final saved = await _repository.updateBranch(
        branch.id,
        BranchDraft.fromBranch(branch).copyWith(
          printerConfig: state.config,
          autoPrintAfterPayment: state.autoPrintAfterPayment,
        ),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          branch: saved,
          config: saved.printerConfig,
          autoPrintAfterPayment: saved.autoPrintAfterPayment,
          printerSaveStatus: SectionSaveStatus.success,
          clearPrinterSaveError: true,
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            printerSaveStatus: SectionSaveStatus.failure,
            printerSaveError: 'save',
          ),
        );
      }
    }
  }

  Future<void> saveReceiptTemplate() async {
    final branch = state.branch;
    if (branch == null ||
        !state.isTemplateDirty ||
        state.templateSaveStatus == SectionSaveStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        templateSaveStatus: SectionSaveStatus.submitting,
        clearTemplateSaveError: true,
      ),
    );
    try {
      final savedTemplate = await _repository.updateReceiptTemplate(
        branch.id,
        state.template,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          template: savedTemplate,
          savedTemplate: savedTemplate,
          templateSaveStatus: SectionSaveStatus.success,
          clearTemplateSaveError: true,
        ),
      );
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            templateSaveStatus: SectionSaveStatus.failure,
            templateSaveError: 'save',
          ),
        );
      }
    }
  }
}
