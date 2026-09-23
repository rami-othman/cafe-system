import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../printer/models/printer_config.dart';
import '../../printer/models/receipt_data.dart';
import '../../printer/repositories/device_printer_settings_store.dart';
import '../../printer/services/printer_service.dart';
import '../../printer/services/receipt_renderer.dart';
import 'pos_state.dart';
import '../repositories/pos_repository.dart';
import 'pos_print_state.dart';

class PosPrintBranchSettings {
  const PosPrintBranchSettings({
    required this.printerConfig,
    this.autoPrintAfterPayment = false,
  });

  final PrinterConfig printerConfig;
  final bool autoPrintAfterPayment;
}

typedef PosPrintBranchSettingsProvider =
    Future<PosPrintBranchSettings> Function(int branchId);

class _ResolvedPrintSettings {
  const _ResolvedPrintSettings({required this.branch, required this.effective});

  final PosPrintBranchSettings branch;
  final PrinterConfig effective;
}

class PosPrintCubit extends Cubit<PosPrintState> {
  PosPrintCubit({
    required PosRepository repository,
    required PosPrintBranchSettingsProvider branchSettingsProvider,
    required DevicePrinterSettingsStore deviceSettingsStore,
    required PrinterService printerService,
    required int tenantId,
    EffectivePrinterConfigResolver resolver =
        const EffectivePrinterConfigResolver(),
  }) : this._(
         posRepository: repository,
         settingsProvider: branchSettingsProvider,
         settingsStore: deviceSettingsStore,
         localPrinter: printerService,
         tenant: tenantId,
         configResolver: resolver,
       );

  PosPrintCubit._({
    required PosRepository posRepository,
    required PosPrintBranchSettingsProvider settingsProvider,
    required DevicePrinterSettingsStore settingsStore,
    required PrinterService localPrinter,
    required int tenant,
    required EffectivePrinterConfigResolver configResolver,
  }) : _repository = posRepository,
       _branchSettingsProvider = settingsProvider,
       _deviceSettingsStore = settingsStore,
       _printerService = localPrinter,
       _tenantId = tenant,
       _resolver = configResolver,
       super(const PosPrintState());

  final PosRepository _repository;
  final PosPrintBranchSettingsProvider _branchSettingsProvider;
  final DevicePrinterSettingsStore _deviceSettingsStore;
  final PrinterService _printerService;
  final int _tenantId;
  final EffectivePrinterConfigResolver _resolver;
  final Set<int> _autoPrintAttemptedOrderIds = <int>{};

  Future<PosPrintOutcome> printPreBill({
    required PosState orderState,
    required Locale locale,
  }) async {
    final orderId = orderState.currentOrderId;
    if (orderId == null || orderId <= 0) {
      return _failBeforeAttempt(PosPrintFailure.orderRequired);
    }
    if (!orderState.hasCartItems) {
      return _failBeforeAttempt(PosPrintFailure.itemsRequired);
    }
    final paymentStatus = orderState.currentOrderPaymentStatus?.toLowerCase();
    if (paymentStatus == 'paid' || paymentStatus == 'completed') {
      return _failBeforeAttempt(PosPrintFailure.preBillUnavailable);
    }
    return _print(
      orderId: orderId,
      branchId: orderState.branchId,
      locale: locale,
      documentType: PosPrintDocumentType.preBill,
    );
  }

  Future<PosPrintOutcome> printReceipt({
    required int? orderId,
    required int branchId,
    required Locale locale,
  }) {
    if (orderId == null || orderId <= 0) {
      return Future<PosPrintOutcome>.value(
        _failBeforeAttempt(PosPrintFailure.orderRequired),
      );
    }
    return _print(
      orderId: orderId,
      branchId: branchId,
      locale: locale,
      documentType: PosPrintDocumentType.receipt,
    );
  }

  Future<PosPrintOutcome> autoPrintReceipt({
    required int? orderId,
    required int branchId,
    required Locale locale,
  }) async {
    if (orderId == null || orderId <= 0) {
      return const PosPrintOutcome.skipped();
    }
    if (_autoPrintAttemptedOrderIds.contains(orderId)) {
      return const PosPrintOutcome.skipped();
    }
    if (state.isPrinting) {
      try {
        await stream
            .firstWhere((PosPrintState state) => !state.isPrinting)
            .timeout(const Duration(seconds: 45));
      } catch (_) {
        return const PosPrintOutcome.skipped();
      }
    }
    if (isClosed || !_autoPrintAttemptedOrderIds.add(orderId)) {
      return const PosPrintOutcome.skipped();
    }

    return _print(
      orderId: orderId,
      branchId: branchId,
      locale: locale,
      documentType: PosPrintDocumentType.receipt,
      checkAutoPrintSetting: true,
    );
  }

  Future<PosPrintOutcome> _print({
    required int orderId,
    required int branchId,
    required Locale locale,
    required PosPrintDocumentType documentType,
    bool checkAutoPrintSetting = false,
  }) async {
    if (state.isPrinting) return const PosPrintOutcome.skipped();
    emit(state.copyWith(isPrinting: true, clearFailure: true));

    int? printJobId;
    try {
      _ResolvedPrintSettings settings;
      try {
        settings = await _loadSettings(branchId);
      } catch (_) {
        printJobId = await _queueJob(
          orderId: orderId,
          documentType: documentType,
          deviceName: defaultTargetPlatform.name,
        );
        return _finishFailure(
          PosPrintFailure.configurationUnavailable,
          printJobId,
        );
      }

      if (checkAutoPrintSetting && !settings.branch.autoPrintAfterPayment) {
        return const PosPrintOutcome.skipped();
      }

      final PrinterConfig config = settings.effective;
      printJobId = await _queueJob(
        orderId: orderId,
        documentType: documentType,
        printerId: _printerIdentifier(config),
        deviceName: defaultTargetPlatform.name,
      );

      if (!config.enabled || config.ipAddress.trim().isEmpty) {
        return _finishFailure(PosPrintFailure.printerNotConfigured, printJobId);
      }
      if (!config.isValid) {
        return _finishFailure(PosPrintFailure.invalidConfiguration, printJobId);
      }

      final ReceiptData receipt;
      try {
        receipt = await _repository
            .getPrintableReceipt(orderId)
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        return _finishFailure(PosPrintFailure.receiptUnavailable, printJobId);
      }
      if ((receipt.orderId != null && receipt.orderId != orderId) ||
          receipt.items.isEmpty) {
        return _finishFailure(PosPrintFailure.itemsRequired, printJobId);
      }
      if (documentType == PosPrintDocumentType.preBill &&
          receipt.payment != null) {
        return _finishFailure(PosPrintFailure.preBillUnavailable, printJobId);
      }

      await _updateJob(printJobId, status: 'printing');
      final PrinterPrintResult result;
      try {
        result = await _printerService.printReceipt(
          config,
          receipt,
          locale,
          isPreBill: documentType == PosPrintDocumentType.preBill,
        );
      } on ReceiptRenderException {
        return _finishFailure(PosPrintFailure.renderingFailed, printJobId);
      } catch (_) {
        return _finishFailure(PosPrintFailure.printerFailed, printJobId);
      }

      if (!result.isSuccess) {
        return _finishFailure(_failureForPrinter(result.failure), printJobId);
      }
      await _updateJob(printJobId, status: 'completed');
      return const PosPrintOutcome.success();
    } finally {
      if (!isClosed) emit(state.copyWith(isPrinting: false));
    }
  }

  Future<_ResolvedPrintSettings> _loadSettings(int branchId) async {
    final PosPrintBranchSettings branch = await _branchSettingsProvider(
      branchId,
    ).timeout(const Duration(seconds: 10));
    final DevicePrinterSettings device = await _deviceSettingsStore.read(
      tenantId: _tenantId,
    );
    return _ResolvedPrintSettings(
      branch: branch,
      effective: _resolver.resolve(
        branchDefaults: branch.printerConfig,
        deviceSettings: device,
      ),
    );
  }

  Future<int?> _queueJob({
    required int orderId,
    required PosPrintDocumentType documentType,
    String? printerId,
    required String deviceName,
  }) async {
    try {
      return await _repository
          .createPrintJob(
            orderId: orderId,
            type: documentType.apiValue,
            printerId: printerId,
            deviceName: deviceName,
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateJob(
    int? printJobId, {
    required String status,
    PosPrintFailure? failure,
  }) async {
    if (printJobId == null) return;
    try {
      await _repository
          .updatePrintJob(
            printJobId: printJobId,
            status: status,
            failureCode: failure == null ? null : _failureCode(failure),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Audit updates cannot change the physical print result.
    }
  }

  Future<PosPrintOutcome> _finishFailure(
    PosPrintFailure failure,
    int? printJobId,
  ) async {
    await _updateJob(printJobId, status: 'failed', failure: failure);
    if (!isClosed) emit(state.copyWith(failure: failure));
    return PosPrintOutcome.failed(failure);
  }

  PosPrintOutcome _failBeforeAttempt(PosPrintFailure failure) {
    if (!isClosed) emit(state.copyWith(failure: failure));
    return PosPrintOutcome.failed(failure);
  }

  String? _printerIdentifier(PrinterConfig config) {
    if (config.name.trim().isNotEmpty) return config.name.trim();
    if (config.ipAddress.trim().isEmpty) return null;
    return '${config.ipAddress.trim()}:${config.port}';
  }

  PosPrintFailure _failureForPrinter(PrinterPrintFailure? failure) =>
      switch (failure) {
        PrinterPrintFailure.invalidConfiguration =>
          PosPrintFailure.invalidConfiguration,
        PrinterPrintFailure.unreachable => PosPrintFailure.printerUnreachable,
        PrinterPrintFailure.timeout => PosPrintFailure.printerTimeout,
        PrinterPrintFailure.unsupported => PosPrintFailure.printerUnsupported,
        PrinterPrintFailure.failed || null => PosPrintFailure.printerFailed,
      };

  String _failureCode(PosPrintFailure failure) => switch (failure) {
    PosPrintFailure.printerNotConfigured => 'printer_not_configured',
    PosPrintFailure.invalidConfiguration => 'invalid_configuration',
    PosPrintFailure.configurationUnavailable => 'configuration_unavailable',
    PosPrintFailure.receiptUnavailable => 'receipt_unavailable',
    PosPrintFailure.renderingFailed => 'rendering_failed',
    PosPrintFailure.printerUnreachable => 'printer_unreachable',
    PosPrintFailure.printerTimeout => 'printer_timeout',
    PosPrintFailure.printerUnsupported => 'printer_unsupported',
    PosPrintFailure.orderRequired ||
    PosPrintFailure.itemsRequired ||
    PosPrintFailure.preBillUnavailable => 'printer_failed',
    PosPrintFailure.printerFailed => 'printer_failed',
  };
}
