import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/printer_config.dart';
import '../repositories/device_printer_settings_store.dart';
import '../services/printer_service.dart';

enum PrinterSetupStatus { loading, ready, testing, success, failure }

class PrinterSetupState extends Equatable {
  const PrinterSetupState({
    this.status = PrinterSetupStatus.loading,
    this.branchDefaults,
    this.deviceSettings = const DevicePrinterSettings(),
    this.failure,
  });

  final PrinterSetupStatus status;
  final PrinterConfig? branchDefaults;
  final DevicePrinterSettings deviceSettings;
  final PrinterPrintFailure? failure;

  bool get isTesting => status == PrinterSetupStatus.testing;
  PrinterConfig? effective(EffectivePrinterConfigResolver resolver) =>
      branchDefaults == null
      ? null
      : resolver.resolve(
          branchDefaults: branchDefaults!,
          deviceSettings: deviceSettings,
        );

  PrinterSetupState copyWith({
    PrinterSetupStatus? status,
    PrinterConfig? branchDefaults,
    DevicePrinterSettings? deviceSettings,
    PrinterPrintFailure? failure,
    bool clearFailure = false,
  }) => PrinterSetupState(
    status: status ?? this.status,
    branchDefaults: branchDefaults ?? this.branchDefaults,
    deviceSettings: deviceSettings ?? this.deviceSettings,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    branchDefaults,
    deviceSettings.useBranchDefaults,
    deviceSettings.localOverride,
    failure,
  ];
}

/// Keeps source selection and effective-configuration logic outside widgets.
/// The branch provider is read-only; only [DevicePrinterSettingsStore] receives
/// local override writes.
class PrinterSetupCubit extends Cubit<PrinterSetupState> {
  factory PrinterSetupCubit({
    required int tenantId,
    required Future<PrinterConfig> Function(int branchId)
    branchDefaultsProvider,
    required DevicePrinterSettingsStore settingsStore,
    required PrinterService printerService,
    EffectivePrinterConfigResolver resolver =
        const EffectivePrinterConfigResolver(),
  }) => PrinterSetupCubit._(
    tenantId,
    branchDefaultsProvider,
    settingsStore,
    printerService,
    resolver,
  );

  PrinterSetupCubit._(
    this._tenantId,
    this._branchDefaultsProvider,
    this._settingsStore,
    this._printerService,
    this._resolver,
  ) : super(const PrinterSetupState());

  final int _tenantId;
  final Future<PrinterConfig> Function(int branchId) _branchDefaultsProvider;
  final DevicePrinterSettingsStore _settingsStore;
  final PrinterService _printerService;
  final EffectivePrinterConfigResolver _resolver;
  int _loadGeneration = 0;

  Future<void> load(int branchId) async {
    final int request = ++_loadGeneration;
    emit(const PrinterSetupState());
    try {
      final PrinterConfig branchDefaults = await _branchDefaultsProvider(
        branchId,
      );
      final DevicePrinterSettings settings = await _settingsStore.read(
        tenantId: _tenantId,
      );
      if (isClosed || request != _loadGeneration) return;
      emit(
        PrinterSetupState(
          branchDefaults: branchDefaults,
          deviceSettings: settings,
          status: PrinterSetupStatus.ready,
        ),
      );
    } catch (_) {
      if (isClosed || request != _loadGeneration) return;
      emit(
        const PrinterSetupState(
          status: PrinterSetupStatus.failure,
          failure: PrinterPrintFailure.failed,
        ),
      );
    }
  }

  void setUseBranchDefaults(bool value) {
    if (state.isTesting) return;
    emit(
      state.copyWith(
        deviceSettings: state.deviceSettings.copyWith(useBranchDefaults: value),
        status: PrinterSetupStatus.ready,
        clearFailure: true,
      ),
    );
  }

  void updateLocalOverride(PrinterConfig config) {
    if (state.isTesting) return;
    emit(
      state.copyWith(
        deviceSettings: state.deviceSettings.copyWith(localOverride: config),
        status: PrinterSetupStatus.ready,
        clearFailure: true,
      ),
    );
  }

  Future<void> saveDeviceSettings() async {
    if (state.isTesting) return;
    await _settingsStore.write(
      tenantId: _tenantId,
      settings: state.deviceSettings,
    );
    emit(state.copyWith(status: PrinterSetupStatus.ready, clearFailure: true));
  }

  Future<void> testPrint() async {
    if (state.isTesting) return;
    final PrinterConfig? effective = state.effective(_resolver);
    if (effective == null || !effective.isValid) {
      emit(
        state.copyWith(
          status: PrinterSetupStatus.failure,
          failure: PrinterPrintFailure.invalidConfiguration,
        ),
      );
      return;
    }
    emit(
      state.copyWith(status: PrinterSetupStatus.testing, clearFailure: true),
    );
    final PrinterPrintResult result = await _printerService.printTest(
      effective,
    );
    emit(
      state.copyWith(
        status: result.isSuccess
            ? PrinterSetupStatus.success
            : PrinterSetupStatus.failure,
        failure: result.failure,
        clearFailure: result.isSuccess,
      ),
    );
  }
}
