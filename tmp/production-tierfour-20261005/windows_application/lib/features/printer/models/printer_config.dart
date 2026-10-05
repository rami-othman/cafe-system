enum PrinterPaperWidth {
  mm58('58mm', 32),
  mm80('80mm', 48);

  const PrinterPaperWidth(this.apiValue, this.columns);

  final String apiValue;
  final int columns;

  static PrinterPaperWidth fromApiValue(Object? value) => values.firstWhere(
    (PrinterPaperWidth width) => width.apiValue == value,
    orElse: () => PrinterPaperWidth.mm80,
  );
}

/// The complete connection information needed by the local printer service.
/// It intentionally contains no branch or tenant identifier: that ownership
/// belongs to the configuration source, not the TCP client.
class PrinterConfig {
  const PrinterConfig({
    this.name = '',
    this.ipAddress = '',
    this.port = 9100,
    this.paperWidth = PrinterPaperWidth.mm80,
    this.enabled = false,
  });

  final String name;
  final String ipAddress;
  final int port;
  final PrinterPaperWidth paperWidth;
  final bool enabled;

  PrinterConfig copyWith({
    String? name,
    String? ipAddress,
    int? port,
    PrinterPaperWidth? paperWidth,
    bool? enabled,
  }) => PrinterConfig(
    name: name ?? this.name,
    ipAddress: ipAddress ?? this.ipAddress,
    port: port ?? this.port,
    paperWidth: paperWidth ?? this.paperWidth,
    enabled: enabled ?? this.enabled,
  );

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
    name: json['name'] as String? ?? '',
    ipAddress: json['ipAddress'] as String? ?? '',
    port: (json['port'] as num?)?.toInt() ?? 9100,
    paperWidth: PrinterPaperWidth.fromApiValue(json['paperWidth']),
    enabled: json['enabled'] == true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'ipAddress': ipAddress.trim(),
    'port': port,
    'paperWidth': paperWidth.apiValue,
    'enabled': enabled,
  };

  String? get validationError {
    if (!enabled) {
      return 'Printing is disabled for this configuration.';
    }
    if (!_isValidHost(ipAddress.trim())) {
      return 'Enter a valid printer IP address or host name.';
    }
    if (port < 1 || port > 65535) {
      return 'Port must be between 1 and 65535.';
    }
    return null;
  }

  bool get isValid => validationError == null;

  static bool _isValidHost(String value) {
    if (value.isEmpty || value.length > 253 || value.contains(RegExp(r'\s'))) {
      return false;
    }
    final RegExp ipv4 = RegExp(
      r'^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$',
    );
    if (ipv4.hasMatch(value) || value.contains(':')) {
      return true; // IPv6 is validated by Socket.connect.
    }
    return value
        .split('.')
        .every(
          (String label) =>
              label.isNotEmpty &&
              label.length <= 63 &&
              RegExp(
                r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$',
              ).hasMatch(label),
        );
  }

  @override
  bool operator ==(Object other) =>
      other is PrinterConfig &&
      other.name == name &&
      other.ipAddress == ipAddress &&
      other.port == port &&
      other.paperWidth == paperWidth &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(name, ipAddress, port, paperWidth, enabled);
}

class DevicePrinterSettings {
  const DevicePrinterSettings({
    this.useBranchDefaults = true,
    this.localOverride = const PrinterConfig(enabled: true),
  });

  final bool useBranchDefaults;
  final PrinterConfig localOverride;

  DevicePrinterSettings copyWith({
    bool? useBranchDefaults,
    PrinterConfig? localOverride,
  }) => DevicePrinterSettings(
    useBranchDefaults: useBranchDefaults ?? this.useBranchDefaults,
    localOverride: localOverride ?? this.localOverride,
  );

  factory DevicePrinterSettings.fromJson(Map<String, dynamic> json) =>
      DevicePrinterSettings(
        useBranchDefaults: json['useBranchDefaults'] != false,
        localOverride: json['localOverride'] is Map
            ? PrinterConfig.fromJson(
                (json['localOverride'] as Map).cast<String, dynamic>(),
              )
            : const PrinterConfig(enabled: true),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'useBranchDefaults': useBranchDefaults,
    'localOverride': localOverride.toJson(),
  };
}

class EffectivePrinterConfigResolver {
  const EffectivePrinterConfigResolver();

  PrinterConfig resolve({
    required PrinterConfig branchDefaults,
    required DevicePrinterSettings deviceSettings,
  }) => deviceSettings.useBranchDefaults
      ? branchDefaults
      : deviceSettings.localOverride;
}
