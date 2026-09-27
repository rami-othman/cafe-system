import 'package:flutter/material.dart';
import '../../../core/services/service_locator.dart';
import '../../../shared/widgets/management_ui.dart';
import '../repositories/inventory_repository.dart';

class ItemProductionBatches extends StatefulWidget {
  const ItemProductionBatches({super.key, required this.itemId});
  final int itemId;
  @override
  State<ItemProductionBatches> createState() => _ItemProductionBatchesState();
}

class _ItemProductionBatchesState extends State<ItemProductionBatches> {
  int _page = 1;
  late Future<Map<String, dynamic>> _result = _load();
  Future<Map<String, dynamic>> _load() => serviceLocator<InventoryRepository>().itemProductionBatches(widget.itemId, page: _page);
  void _changePage(int page) => setState(() { _page = page; _result = _load(); });
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.hasError) return ManagementMessage(message: 'تعذر تحميل دفعات الإنتاج.', error: true, onRetry: () => _changePage(_page));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = (snapshot.data!['data'] as List).cast<Map<String, dynamic>>();
      final lastPage = (snapshot.data!['meta'] as Map)['lastPage'] as int;
      if (rows.isEmpty) return const ManagementMessage(message: 'لا توجد دفعات إنتاج لهذه المادة.');
      return Column(children: [
        Expanded(child: SingleChildScrollView(child: DataTable(
          columns: const [DataColumn(label: Text('المرجع')), DataColumn(label: Text('التاريخ')), DataColumn(label: Text('الكمية المنتجة')), DataColumn(label: Text('المتبقي')), DataColumn(label: Text('تكلفة الوحدة')), DataColumn(label: Text('الصلاحية'))],
          rows: rows.map((row) => DataRow(cells: [for (final key in ['reference', 'production_date', 'produced_quantity', 'remaining_quantity', 'actual_unit_cost', 'expiry_date']) DataCell(Text('${row[key] ?? '—'}'))])).toList(),
        ))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: _page > 1 ? () => _changePage(_page - 1) : null, icon: const Icon(Icons.chevron_right)),
          Text('$_page / $lastPage'),
          IconButton(onPressed: _page < lastPage ? () => _changePage(_page + 1) : null, icon: const Icon(Icons.chevron_left)),
        ]),
      ]);
    },
  );
}
