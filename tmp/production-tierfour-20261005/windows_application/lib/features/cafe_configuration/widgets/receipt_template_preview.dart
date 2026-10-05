import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../printer/models/printer_config.dart';
import '../../printer/models/receipt_data.dart';
import '../../printer/models/receipt_template.dart';
import '../../printer/services/receipt_renderer.dart';

/// Renders a fixed sample order through the exact same [ReceiptRenderer]
/// used for real printing, so what the manager sees here is what actually
/// prints. Updates live as [template] changes; no printer hardware involved.
class ReceiptTemplatePreview extends StatefulWidget {
  const ReceiptTemplatePreview({
    super.key,
    required this.template,
    required this.paperWidth,
  });

  final ReceiptTemplate template;
  final PrinterPaperWidth paperWidth;

  @override
  State<ReceiptTemplatePreview> createState() => _ReceiptTemplatePreviewState();
}

class _ReceiptTemplatePreviewState extends State<ReceiptTemplatePreview> {
  final _renderer = ReceiptRenderer();
  Locale _locale = const Locale('en');
  Future<ReceiptRaster>? _future;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(covariant ReceiptTemplatePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template != widget.template ||
        oldWidget.paperWidth != widget.paperWidth) {
      _render();
    }
  }

  void _render() {
    final receipt = _sampleReceipt(widget.template);
    setState(() {
      _future = _renderer.render(
        receipt,
        locale: _locale,
        paperWidth: widget.paperWidth,
      );
    });
  }

  void _setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    _render();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.cafeConfigurationReceiptPreviewTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SegmentedButton<Locale>(
                segments: const <ButtonSegment<Locale>>[
                  ButtonSegment<Locale>(value: Locale('en'), label: Text('EN')),
                  ButtonSegment<Locale>(value: Locale('ar'), label: Text('AR')),
                ],
                selected: <Locale>{_locale},
                onSelectionChanged: (selection) => _setLocale(selection.first),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: FutureBuilder<ReceiptRaster>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  );
                }
                final raster = snapshot.data;
                if (raster == null) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Icon(Icons.error_outline),
                  );
                }
                return SingleChildScrollView(
                  child: Image.memory(raster.png, gaplessPlayback: true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

ReceiptData _sampleReceipt(ReceiptTemplate template) => ReceiptData(
  orderId: 1,
  orderNumber: 'ORD-1042',
  date: DateTime.now().toIso8601String(),
  cafeName: 'Cafe System',
  branchName: 'Downtown',
  address: '12 Market Street',
  phone: '+963 11 123 4567',
  orderType: 'dine_in',
  cashierName: 'Sam',
  customerName: 'Alex',
  items: const <ReceiptItem>[
    ReceiptItem(
      name: 'Cappuccino',
      quantity: 2,
      unitPrice: 5,
      lineTotal: 10,
      modifiers: <String>['Extra shot', 'Oat milk'],
      note: 'Less sugar',
    ),
    ReceiptItem(name: 'Croissant', quantity: 1, unitPrice: 4, lineTotal: 4),
  ],
  subtotal: 14,
  discountTotal: 1,
  taxTotal: 0.65,
  total: 13.65,
  payment: const ReceiptPayment(method: 'cash', amount: 15, changeDue: 1.35),
  footerText: template.footer.text,
  template: template,
);
