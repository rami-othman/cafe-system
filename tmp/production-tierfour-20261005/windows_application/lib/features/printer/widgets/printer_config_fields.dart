import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/printer_config.dart';

/// The printer name/host/port/paper-width form, shared by Cafe Settings →
/// Printing (branch defaults) and Settings → Printer Setup (this device), so
/// both screens edit the same fields with the same labels.
class PrinterConfigFields extends StatelessWidget {
  const PrinterConfigFields({
    super.key,
    required this.config,
    required this.enabled,
    required this.onChanged,
    required this.nameKey,
    required this.hostKey,
    required this.portKey,
    required this.paperWidthKey,
  });

  final PrinterConfig config;
  final bool enabled;
  final ValueChanged<PrinterConfig> onChanged;
  final Key nameKey;
  final Key hostKey;
  final Key portKey;
  final Key paperWidthKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget name = TextFormField(
      key: nameKey,
      enabled: enabled,
      initialValue: config.name,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPrinterName),
      onChanged: (String value) => onChanged(config.copyWith(name: value)),
    );
    final Widget host = TextFormField(
      key: hostKey,
      enabled: enabled,
      initialValue: config.ipAddress,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPrinterHost),
      onChanged: (String value) => onChanged(config.copyWith(ipAddress: value)),
    );
    final Widget port = TextFormField(
      key: portKey,
      enabled: enabled,
      initialValue: config.port.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPrinterPort),
      onChanged: (String value) =>
          onChanged(config.copyWith(port: int.tryParse(value) ?? 0)),
    );
    final Widget width = DropdownButtonFormField<PrinterPaperWidth>(
      key: paperWidthKey,
      initialValue: config.paperWidth,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPaperWidth),
      items: PrinterPaperWidth.values
          .map(
            (PrinterPaperWidth width) =>
                DropdownMenuItem(value: width, child: Text(width.apiValue)),
          )
          .toList(),
      onChanged: enabled
          ? (PrinterPaperWidth? value) {
              if (value != null) {
                onChanged(config.copyWith(paperWidth: value));
              }
            }
          : null,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: <Widget>[
              name,
              const SizedBox(height: AppSpacing.lg),
              host,
              const SizedBox(height: AppSpacing.lg),
              port,
              const SizedBox(height: AppSpacing.lg),
              width,
            ],
          );
        }
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: name),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: host),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(child: port),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: width),
              ],
            ),
          ],
        );
      },
    );
  }
}
