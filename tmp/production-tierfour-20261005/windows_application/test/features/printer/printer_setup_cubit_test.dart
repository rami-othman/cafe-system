import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/printer/controllers/printer_setup_cubit.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';
import 'package:windows_application/features/printer/models/receipt_data.dart';
import 'package:windows_application/features/printer/repositories/device_printer_settings_store.dart';
import 'package:windows_application/features/printer/services/printer_service.dart';
import 'package:windows_application/features/printer/services/receipt_renderer.dart';

const PrinterConfig _branch = PrinterConfig(
  ipAddress: '192.168.1.50',
  enabled: true,
);

void main() {
  test(
    'loads branch defaults and persists only the local device override',
    () async {
      final _MemoryStore store = _MemoryStore();
      final PrinterSetupCubit cubit = _cubit(store: store);
      await cubit.load(1);
      cubit.setUseBranchDefaults(false);
      cubit.updateLocalOverride(
        const PrinterConfig(ipAddress: '192.168.1.51', enabled: true),
      );
      await cubit.saveDeviceSettings();

      expect(store.saved!.localOverride.ipAddress, '192.168.1.51');
      expect(_branch.ipAddress, '192.168.1.50');
      expect(
        cubit.state
            .effective(const EffectivePrinterConfigResolver())!
            .ipAddress,
        '192.168.1.51',
      );
    },
  );

  test(
    'test print exposes loading then success and blocks duplicate clicks',
    () async {
      final Completer<PrinterPrintResult> gate =
          Completer<PrinterPrintResult>();
      final _FakePrinter service = _FakePrinter(() => gate.future);
      final PrinterSetupCubit cubit = _cubit(service: service);
      await cubit.load(1);

      final Future<void> first = cubit.testPrint(const Locale('en'));
      final Future<void> second = cubit.testPrint(const Locale('en'));
      expect(cubit.state.status, PrinterSetupStatus.testing);
      gate.complete(const PrinterPrintResult.success());
      await Future.wait(<Future<void>>[first, second]);

      expect(service.calls, 1);
      expect(cubit.state.status, PrinterSetupStatus.success);
    },
  );

  test(
    'invalid configuration and connection failure become safe UI states',
    () async {
      final PrinterSetupCubit invalid = PrinterSetupCubit(
        tenantId: 1,
        branchDefaultsProvider: (_) async => const PrinterConfig(enabled: true),
        settingsStore: _MemoryStore(),
        printerService: _FakePrinter(
          () async => const PrinterPrintResult.success(),
        ),
      );
      await invalid.load(1);
      await invalid.testPrint(const Locale('en'));
      expect(invalid.state.failure, PrinterPrintFailure.invalidConfiguration);

      final PrinterSetupCubit unreachable = _cubit(
        service: _FakePrinter(
          () async =>
              const PrinterPrintResult.failure(PrinterPrintFailure.unreachable),
        ),
      );
      await unreachable.load(1);
      await unreachable.testPrint(const Locale('en'));
      expect(unreachable.state.failure, PrinterPrintFailure.unreachable);
    },
  );

  test(
    'loads the requested branch and retries a failed config request',
    () async {
      final List<int> requests = <int>[];
      bool fail = false;
      final PrinterSetupCubit cubit = PrinterSetupCubit(
        tenantId: 1,
        branchDefaultsProvider: (int branchId) async {
          requests.add(branchId);
          if (fail) throw StateError('API unavailable');
          return PrinterConfig(name: 'Branch $branchId');
        },
        settingsStore: _MemoryStore(),
        printerService: _FakePrinter(
          () async => const PrinterPrintResult.success(),
        ),
      );

      await cubit.load(1);
      expect(cubit.state.branchDefaults!.name, 'Branch 1');
      fail = true;
      await cubit.load(2);
      expect(cubit.state.status, PrinterSetupStatus.failure);
      expect(cubit.state.branchDefaults, isNull);
      fail = false;
      await cubit.load(2);
      expect(cubit.state.branchDefaults!.name, 'Branch 2');
      expect(requests, <int>[1, 2, 2]);
      await cubit.close();
    },
  );
}

PrinterSetupCubit _cubit({
  DevicePrinterSettingsStore? store,
  PrinterService? service,
}) => PrinterSetupCubit(
  tenantId: 1,
  branchDefaultsProvider: (_) async => _branch,
  settingsStore: store ?? _MemoryStore(),
  printerService:
      service ?? _FakePrinter(() async => const PrinterPrintResult.success()),
);

class _MemoryStore implements DevicePrinterSettingsStore {
  DevicePrinterSettings? saved;
  @override
  Future<DevicePrinterSettings> read({required int tenantId}) async =>
      saved ?? const DevicePrinterSettings();
  @override
  Future<void> write({
    required int tenantId,
    required DevicePrinterSettings settings,
  }) async => saved = settings;
}

class _FakePrinter implements PrinterService {
  _FakePrinter(this.result);
  final Future<PrinterPrintResult> Function() result;
  int calls = 0;
  @override
  Future<PrinterPrintResult> printTestReceipt(
    PrinterConfig config,
    Locale locale,
  ) {
    calls++;
    return result();
  }

  @override
  Future<PrinterPrintResult> printRaster(
    PrinterConfig config,
    ReceiptRaster raster,
  ) => result();

  @override
  Future<PrinterPrintResult> printReceipt(
    PrinterConfig config,
    ReceiptData receipt,
    Locale locale, {
    bool isPreBill = false,
  }) => result();
}
