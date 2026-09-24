import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/printer/models/printer_config.dart';

void main() {
  group('PrinterConfig', () {
    test(
      'serializes 80mm configuration without changing connection fields',
      () {
        const PrinterConfig config = PrinterConfig(
          name: 'Front counter',
          ipAddress: '192.168.1.50',
          port: 9100,
          paperWidth: PrinterPaperWidth.mm80,
          enabled: true,
        );

        expect(PrinterConfig.fromJson(config.toJson()), config);
        expect(config.paperWidth.columns, 48);
      },
    );

    test('supports 58mm', () {
      const PrinterConfig config = PrinterConfig(
        ipAddress: 'printer.local',
        paperWidth: PrinterPaperWidth.mm58,
        enabled: true,
      );
      expect(config.isValid, isTrue);
      expect(config.paperWidth.columns, 32);
    });

    test('rejects invalid hosts and ports before a socket is opened', () {
      expect(
        const PrinterConfig(ipAddress: 'bad host', enabled: true).isValid,
        isFalse,
      );
      expect(
        const PrinterConfig(
          ipAddress: '192.168.1.50',
          port: 0,
          enabled: true,
        ).isValid,
        isFalse,
      );
      expect(
        const PrinterConfig(
          ipAddress: '192.168.1.50',
          port: 65536,
          enabled: true,
        ).isValid,
        isFalse,
      );
    });
  });

  test(
    'effective resolver uses a local override without mutating branch defaults',
    () {
      const PrinterConfig branch = PrinterConfig(
        ipAddress: '192.168.1.50',
        enabled: true,
      );
      const PrinterConfig local = PrinterConfig(
        ipAddress: '192.168.1.51',
        enabled: true,
        paperWidth: PrinterPaperWidth.mm58,
      );
      const DevicePrinterSettings settings = DevicePrinterSettings(
        useBranchDefaults: false,
        localOverride: local,
      );

      final PrinterConfig effective = const EffectivePrinterConfigResolver()
          .resolve(branchDefaults: branch, deviceSettings: settings);

      expect(effective, local);
      expect(branch.ipAddress, '192.168.1.50');
    },
  );
}
