import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/inventory_text_styles.dart';
import '../../../../core/utils/backend_datetime.dart';
import '../../../../shared/widgets/management_ui.dart';
import '../../models/inventory_models.dart';

String inventoryItemTypeLabel(String type) => switch (type) {
  'stock_item' => 'صنف مخزني',
  'non_stock_item' => 'صنف غير مخزني',
  'service' => 'خدمة',
  'raw_material' => 'مادة خام',
  'packaging' => 'تغليف',
  'supply' => 'مستلزمات',
  'finished_good' => 'منتج جاهز',
  _ => 'أخرى',
};

String inventoryUnitLabel(String unit) => InventoryUnit.labelFor(unit);

String inventoryNumber(String value, {int digits = 2}) =>
    (double.tryParse(value) ?? 0).toStringAsFixed(digits);

String inventoryMoney(String value) => '\$${inventoryNumber(value)}';

class ItemStatusBadge extends StatelessWidget {
  const ItemStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => ManagementBadge(
    label: switch (status) {
      'inactive' => 'غير نشط',
      'low_stock' => 'مخزون منخفض',
      'out_of_stock' => 'نافد المخزون',
      'expired' => 'منتهي الصلاحية',
      _ => 'نشط',
    },
    tone: switch (status) {
      'inactive' => ManagementTone.neutral,
      'low_stock' => ManagementTone.warning,
      'out_of_stock' || 'expired' => ManagementTone.danger,
      _ => ManagementTone.success,
    },
  );
}

class ItemFilters extends StatelessWidget {
  const ItemFilters({
    super.key,
    required this.searchController,
    required this.category,
    required this.type,
    required this.stockStatus,
    required this.warehouseId,
    required this.categories,
    required this.warehouses,
    required this.onSearch,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onWarehouseChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String category;
  final String type;
  final String stockStatus;
  final int? warehouseId;
  final List<String> categories;
  final List<({int id, String name})> warehouses;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<int?> onWarehouseChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ManagementFilterBar(
    children: <Widget>[
      SizedBox(
        width: 260,
        child: TextField(
          controller: searchController,
          onSubmitted: onSearch,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_outlined),
            hintText: 'ابحث بالاسم أو SKU أو الباركود',
          ),
        ),
      ),
      _ItemDropdown(
        label: 'الفئة',
        value: category,
        options: <String, String>{
          for (final String entry in categories) entry: entry,
        },
        onChanged: onCategoryChanged,
      ),
      _ItemDropdown(
        label: 'النوع',
        value: type,
        options: const <String, String>{
          'stock_item': 'صنف مخزني',
          'non_stock_item': 'صنف غير مخزني',
          'service': 'خدمة',
          'raw_material': 'مادة خام',
          'packaging': 'تغليف',
          'supply': 'مستلزمات',
          'finished_good': 'منتج جاهز',
        },
        onChanged: onTypeChanged,
      ),
      _ItemDropdown(
        label: 'حالة المخزون',
        value: stockStatus,
        options: const <String, String>{
          'active': 'نشط',
          'low_stock': 'مخزون منخفض',
          'out_of_stock': 'نافد المخزون',
          'expired': 'منتهي الصلاحية',
          'inactive': 'غير نشط',
        },
        onChanged: onStatusChanged,
      ),
      SizedBox(
        width: 190,
        child: DropdownButtonFormField<int?>(
          initialValue: warehouseId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'المخزن'),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('كل المخازن'),
            ),
            ...warehouses.map(
              (({int id, String name}) warehouse) => DropdownMenuItem<int?>(
                value: warehouse.id,
                child: Text(warehouse.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onWarehouseChanged,
        ),
      ),
      TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('مسح المرشحات'),
      ),
    ],
  );
}

class ItemTable extends StatelessWidget {
  const ItemTable({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onEdit,
  });
  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onOpen;
  final ValueChanged<InventoryItem> onEdit;

  @override
  Widget build(BuildContext context) => ManagementTableShell(
    minWidth: 1170,
    verticalScroll: true,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll<Color>(
        AppColors.menuTableHeader,
      ),
      columns: const <DataColumn>[
        DataColumn(label: Text('المادة')),
        DataColumn(label: Text('الفئة')),
        DataColumn(label: Text('النوع')),
        DataColumn(label: Text('الوحدة الأساسية')),
        DataColumn(label: Text('متوسط التكلفة'), numeric: true),
        DataColumn(label: Text('الكمية الحالية'), numeric: true),
        DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('آخر تحديث')),
        DataColumn(label: Text('الإجراءات')),
      ],
      rows: items
          .map(
            (InventoryItem item) => DataRow(
              onSelectChanged: (_) => onOpen(item),
              cells: <DataCell>[
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.name, style: AppTextStyles.labelLarge),
                      Text(
                        item.sku.isEmpty ? item.barcode : item.sku,
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
                DataCell(Text(item.category.isEmpty ? '—' : item.category)),
                DataCell(Text(inventoryItemTypeLabel(item.itemType))),
                DataCell(Text(inventoryUnitLabel(item.unit))),
                DataCell(Text(inventoryMoney(item.cost))),
                DataCell(
                  Text(
                    '${inventoryNumber(item.availableQuantity, digits: 3)} ${inventoryUnitLabel(item.unit)}',
                  ),
                ),
                DataCell(ItemStatusBadge(status: item.stockStatus)),
                DataCell(Text(_date(item.lastUpdatedAt))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: 'عرض التفاصيل',
                        onPressed: () => onOpen(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'تعديل المادة',
                        onPressed: () => onEdit(item),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _ItemDropdown extends StatelessWidget {
  const _ItemDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final Map<String, String> uniqueOptions = <String, String>{
      for (final MapEntry<String, String> entry in options.entries)
        if (entry.key.isNotEmpty) entry.key: entry.value,
    };
    final String selectedValue = uniqueOptions.containsKey(value) ? value : '';

    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>('$label:$selectedValue'),
        initialValue: selectedValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(value: '', child: Text('الكل')),
          ...uniqueOptions.entries.map(
            (MapEntry<String, String> entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          ),
        ],
        onChanged: (String? next) => onChanged(next ?? ''),
      ),
    );
  }
}

String _date(String value) {
  final DateTime? date = parseBackendDateTime(value);
  return date == null
      ? '—'
      : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
