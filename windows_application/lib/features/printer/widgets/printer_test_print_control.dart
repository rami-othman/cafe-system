import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../services/printer_service.dart';

class PrinterSuccessBanner extends StatelessWidget {
  const PrinterSuccessBanner({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Text(
      context.l10n.printerTestPrintSuccessful,
      style: const TextStyle(color: AppColors.success),
    ),
  );
}

class PrinterResultBanner extends StatelessWidget {
  const PrinterResultBanner({super.key, required this.failure});

  final PrinterPrintFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Text(switch (failure) {
        PrinterPrintFailure.invalidConfiguration =>
          l10n.posPrintInvalidConfiguration,
        PrinterPrintFailure.timeout => l10n.posPrintTimeout,
        PrinterPrintFailure.unreachable => l10n.posPrintUnreachable,
        PrinterPrintFailure.unsupported => l10n.posPrintUnsupported,
        PrinterPrintFailure.failed => l10n.posPrintFailed,
      }, style: const TextStyle(color: AppColors.danger)),
    );
  }
}

/// A self-contained "Test Print" button + result banner, shared by both
/// printer-configuration screens. [onTest] is expected to run the config
/// under test through the real receipt pipeline (see
/// `PrinterService.printTestReceipt`), not a hand-built diagnostic payload.
class PrinterTestPrintControl extends StatefulWidget {
  const PrinterTestPrintControl({
    super.key,
    required this.onTest,
    this.enabled = true,
  });

  final Future<PrinterPrintResult> Function() onTest;
  final bool enabled;

  @override
  State<PrinterTestPrintControl> createState() =>
      _PrinterTestPrintControlState();
}

class _PrinterTestPrintControlState extends State<PrinterTestPrintControl> {
  bool _isTesting = false;
  PrinterPrintFailure? _failure;
  bool _success = false;

  Future<void> _run() async {
    setState(() {
      _isTesting = true;
      _failure = null;
      _success = false;
    });
    final PrinterPrintResult result = await widget.onTest();
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _failure = result.failure;
      _success = result.isSuccess;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_failure != null) PrinterResultBanner(failure: _failure!),
        if (_success) const PrinterSuccessBanner(),
        AppButton(
          key: const Key('printer-test-print'),
          label: _isTesting
              ? l10n.printerTesting
              : _failure == null
              ? l10n.printerTestPrint
              : l10n.printerRetryTestPrint,
          icon: _isTesting ? null : Icons.print_outlined,
          variant: AppButtonVariant.outlined,
          onPressed: widget.enabled && !_isTesting ? _run : null,
        ),
      ],
    );
  }
}
