import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../models/inventory_models.dart';
import '../repositories/inventory_repository.dart';

class OpeningInventoryDialog extends StatefulWidget {
  const OpeningInventoryDialog({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<OpeningInventoryDialog> createState() => _OpeningInventoryDialogState();
}

class _OpeningInventoryDialogState extends State<OpeningInventoryDialog> {
  List<Map<String, dynamic>> _periods = const [];
  List<WarehouseLocation> _warehouses = const [];
  List<InventoryItem> _items = const [];
  final List<_OpeningLine> _lines = <_OpeningLine>[_OpeningLine()];
  int? _periodId;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.openingPeriods(),
        widget.repository.warehouses(),
        widget.repository.items(activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _periods = results[0] as List<Map<String, dynamic>>;
        _warehouses = results[1] as List<WarehouseLocation>;
        _items = results[2] as List<InventoryItem>;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _loading = false; });
    }
  }

  @override
  void dispose() {
    for (final line in _lines) { line.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (_periodId == null || _lines.any((line) => line.warehouseId == null || line.itemId == null ||
        (double.tryParse(line.quantity.text) ?? 0) <= 0 || (double.tryParse(line.unitCost.text) ?? 0) <= 0)) {
      setState(() => _error = 'اختر السنة والمستودع والمادة، وأدخل كمية وتكلفة موجبتين لكل سطر.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.repository.postOpeningInventory(_periodId!, _lines.map((line) => <String, dynamic>{
        'warehouseId': line.warehouseId,
        'itemId': line.itemId,
        'quantity': line.quantity.text.trim(),
        'unitCost': line.unitCost.text.trim(),
      }).toList(growable: false));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('بضاعة أول المدة'),
    content: SizedBox(width: 850, height: 450, child: _loading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('تُسجّل الكميات في المخزون، وتُرحّل قيمتها إلى أصل المخزون وحقوق الملكية في اليوم الأول من السنة.'),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int>(
          initialValue: _periodId,
          decoration: const InputDecoration(labelText: 'السنة المحاسبية المفتوحة'),
          items: _periods.map((row) => DropdownMenuItem<int>(value: row['id'] as int,
            child: Text('${row['name']} — ${row['startDate']}'))).toList(),
          onChanged: (value) => setState(() => _periodId = value),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._lines.asMap().entries.map((entry) {
          final line = entry.value;
          final availableItems = _items.where((item) =>
            line.warehouseId == null || item.warehouseIds.contains(line.warehouseId)).toList();
          return Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Row(children: <Widget>[
            Expanded(child: DropdownButtonFormField<int>(
              initialValue: line.warehouseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المستودع'),
              items: _warehouses.map((warehouse) => DropdownMenuItem(value: warehouse.id,
                child: Text(warehouse.displayName, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() { line.warehouseId = value; line.itemId = null; }),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: DropdownButtonFormField<int>(
              key: ValueKey('${entry.key}-${line.warehouseId}'),
              initialValue: line.itemId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المادة'),
              items: availableItems.map((item) => DropdownMenuItem(value: item.id,
                child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() => line.itemId = value),
            )),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 95, child: TextField(controller: line.quantity,
              keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية'))),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 115, child: TextField(controller: line.unitCost,
              keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة الوحدة'))),
            IconButton(onPressed: _lines.length == 1 ? null : () => setState(() {
              _lines.removeAt(entry.key).dispose();
            }), icon: const Icon(Icons.remove_circle_outline)),
          ]));
        }),
        TextButton.icon(onPressed: () => setState(() => _lines.add(_OpeningLine())),
          icon: const Icon(Icons.add), label: const Text('إضافة مادة')),
        if (_periods.isEmpty) const Text('أنشئ سنة محاسبية مفتوحة أولًا.'),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      ]))),
    actions: <Widget>[
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')),
      FilledButton(onPressed: _loading || _saving || _periods.isEmpty ? null : _save,
        child: const Text('ترحيل بضاعة أول المدة')),
    ],
  );
}

class _OpeningLine {
  int? warehouseId;
  int? itemId;
  final quantity = TextEditingController();
  final unitCost = TextEditingController();

  void dispose() { quantity.dispose(); unitCost.dispose(); }
}
