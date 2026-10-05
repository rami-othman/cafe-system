import 'package:flutter/material.dart';

import '../../../core/network/dio_api_client.dart';
import '../../../core/services/service_locator.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';

/// سلة المحذوفات العامة: كل ما يُحذف في النظام يظهر هنا ويمكن استعادته. للمالك فقط.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashItem {
  const _TrashItem({
    required this.type,
    required this.typeLabel,
    required this.id,
    required this.title,
    required this.code,
    required this.deletedAt,
  });

  final String type;
  final String typeLabel;
  final int id;
  final String title;
  final String? code;
  final DateTime? deletedAt;

  factory _TrashItem.fromJson(Map<String, dynamic> json) => _TrashItem(
    type: '${json['type']}',
    typeLabel: '${json['typeLabel'] ?? json['type']}',
    id: (json['id'] as num).toInt(),
    title: '${json['title'] ?? ''}',
    code: json['code']?.toString(),
    deletedAt: DateTime.tryParse('${json['deletedAt'] ?? ''}')?.toLocal(),
  );
}

class _TrashType {
  const _TrashType(this.type, this.label, this.count);
  final String type;
  final String label;
  final int count;
}

const Map<String, IconData> _typeIcons = <String, IconData>{
  'vouchers': Icons.receipt_long_outlined,
  'expenses': Icons.payments_outlined,
  'purchase_invoices': Icons.shopping_cart_outlined,
  'customers': Icons.person_outline,
  'customer_groups': Icons.groups_outlined,
  'suppliers': Icons.local_shipping_outlined,
  'products': Icons.local_cafe_outlined,
  'product_variants': Icons.tune,
  'categories': Icons.category_outlined,
  'modifier_groups': Icons.add_circle_outline,
  'modifier_options': Icons.radio_button_checked,
  'menus': Icons.menu_book_outlined,
  'inventory_items': Icons.inventory_2_outlined,
  'warehouses': Icons.warehouse_outlined,
  'discounts': Icons.local_offer_outlined,
  'expense_categories': Icons.account_balance_wallet_outlined,
  'financial_accounts': Icons.account_tree_outlined,
};

class _TrashScreenState extends State<TrashScreen> {
  final DioApiClient _api = serviceLocator<DioApiClient>();
  final TextEditingController _search = TextEditingController();
  List<_TrashItem> _items = const <_TrashItem>[];
  List<_TrashType> _types = const <_TrashType>[];
  String? _type;
  bool _loading = true;
  String? _error;
  int? _restoring;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _total => _types.fold<int>(0, (int sum, _TrashType t) => sum + t.count);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic envelope = await _api.getEnvelope(
        'trash',
        queryParameters: <String, dynamic>{
          if (_type != null) 'type': _type,
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
          'perPage': 200,
        },
      );
      final Map<String, dynamic> body = Map<String, dynamic>.from(envelope as Map);
      if (!mounted) return;
      setState(() {
        _items = (body['data'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic v) => _TrashItem.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(growable: false);
        _types = (body['types'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic v) {
              final Map<String, dynamic> m = Map<String, dynamic>.from(v as Map);
              return _TrashType('${m['type']}', '${m['label']}', (m['count'] as num?)?.toInt() ?? 0);
            })
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _restore(_TrashItem item) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('استعادة العنصر؟'),
        content: Text('سيعود «${item.title}» (${item.typeLabel}) إلى مكانه.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _restoring = item.id);
    try {
      await _api.postEnvelope('trash/${item.type}/${item.id}/restore');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الاستعادة.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)}  ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(FinanceSpace.pageX, 28, FinanceSpace.pageX, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _header(),
          const SizedBox(height: FinanceSpace.lg),
          _toolbar(),
          const SizedBox(height: FinanceSpace.md),
          if (_types.any((_TrashType t) => t.count > 0)) ...<Widget>[
            _typeChips(),
            const SizedBox(height: FinanceSpace.lg),
          ],
          Expanded(child: _content()),
        ],
      ),
    ),
  );

  Widget _header() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: FinanceColors.tableHead,
          borderRadius: BorderRadius.circular(FinanceRadius.card),
        ),
        child: const Icon(Icons.delete_outline, color: FinanceColors.brown),
      ),
      const SizedBox(width: FinanceSpace.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('سلة المحذوفات', style: FinanceText.page),
            const SizedBox(height: FinanceSpace.xs),
            Text(
              'كل ما حُذف من النظام يبقى هنا ويمكن استعادته. السند المرحّل المحذوف يُلغى أثره بقيد عكسي، ويبقى القيد الأصلي في السجل.',
              style: FinanceText.subtitle,
            ),
          ],
        ),
      ),
      if (_total > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: FinanceColors.warningBg,
            border: Border.all(color: FinanceColors.warningBorder),
            borderRadius: BorderRadius.circular(FinanceRadius.pill),
          ),
          child: Text(
            '$_total عنصر',
            style: const TextStyle(
              fontFamily: FinanceText.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: FinanceColors.brown,
            ),
          ),
        ),
    ],
  );

  Widget _toolbar() => Row(
    children: <Widget>[
      Expanded(
        child: SizedBox(
          height: 44,
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            style: const TextStyle(fontFamily: FinanceText.fontFamily, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الرقم',
              hintStyle: const TextStyle(color: FinanceColors.muted, fontFamily: FinanceText.fontFamily),
              prefixIcon: const Icon(Icons.search, color: FinanceColors.muted),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                    ),
              filled: true,
              fillColor: FinanceColors.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FinanceRadius.control),
                borderSide: const BorderSide(color: FinanceColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FinanceRadius.control),
                borderSide: const BorderSide(color: FinanceColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FinanceRadius.control),
                borderSide: const BorderSide(color: FinanceColors.accent, width: 1.4),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: FinanceSpace.sm),
      SizedBox(
        height: 44,
        width: 44,
        child: OutlinedButton(
          onPressed: _load,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: FinanceColors.card,
            side: const BorderSide(color: FinanceColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FinanceRadius.control)),
          ),
          child: const Icon(Icons.refresh, color: FinanceColors.brown),
        ),
      ),
    ],
  );

  Widget _chip(String label, int? count, bool selected, VoidCallback onTap, {IconData? icon}) => InkWell(
    borderRadius: BorderRadius.circular(FinanceRadius.pill),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? FinanceColors.primary : FinanceColors.card,
        border: Border.all(color: selected ? FinanceColors.primary : FinanceColors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: selected ? Colors.white : FinanceColors.brown),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: FinanceText.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : FinanceColors.textSecondary,
            ),
          ),
          if (count != null) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white24 : FinanceColors.tableHead,
                borderRadius: BorderRadius.circular(FinanceRadius.pill),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : FinanceColors.brown,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _typeChips() => Wrap(
    spacing: FinanceSpace.sm,
    runSpacing: FinanceSpace.sm,
    children: <Widget>[
      _chip('الكل', _total, _type == null, () {
        setState(() => _type = null);
        _load();
      }),
      for (final _TrashType t in _types.where((_TrashType t) => t.count > 0))
        _chip(t.label, t.count, _type == t.type, () {
          setState(() => _type = t.type);
          _load();
        }, icon: _typeIcons[t.type]),
    ],
  );

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: FinanceColors.accent));
    }
    if (_error != null) {
      return _state(Icons.error_outline, 'تعذّر تحميل السلة', _error!, action: OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')));
    }
    if (_items.isEmpty) {
      return _state(
        Icons.delete_sweep_outlined,
        _search.text.isNotEmpty || _type != null ? 'لا توجد نتائج' : 'السلة فارغة',
        _search.text.isNotEmpty || _type != null
            ? 'جرّب تغيير البحث أو النوع.'
            : 'عند حذف أي عنصر في النظام سيظهر هنا ويمكنك استعادته.',
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: FinanceSpace.xl),
      decoration: BoxDecoration(
        color: FinanceColors.card,
        border: Border.all(color: FinanceColors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: FinanceColors.border),
        itemBuilder: (BuildContext context, int index) => _row(_items[index]),
      ),
    );
  }

  Widget _row(_TrashItem item) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: FinanceSpace.lg, vertical: 12),
    child: Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: FinanceColors.workspace,
            border: Border.all(color: FinanceColors.border),
            borderRadius: BorderRadius.circular(FinanceRadius.control),
          ),
          child: Icon(_typeIcons[item.type] ?? Icons.delete_outline, size: 20, color: FinanceColors.brown),
        ),
        const SizedBox(width: FinanceSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: FinanceText.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: FinanceColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: FinanceColors.tableHead,
                      borderRadius: BorderRadius.circular(FinanceRadius.pill),
                    ),
                    child: Text(
                      item.typeLabel,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: FinanceColors.brown),
                    ),
                  ),
                  if (item.code != null && item.code != item.title) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(item.code!, style: FinanceText.subtitle),
                  ],
                  const SizedBox(width: 8),
                  const Icon(Icons.schedule, size: 13, color: FinanceColors.muted),
                  const SizedBox(width: 4),
                  Text('حُذف ${_formatDate(item.deletedAt)}', style: FinanceText.subtitle),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: FinanceSpace.md),
        OutlinedButton.icon(
          onPressed: _restoring == null ? () => _restore(item) : null,
          icon: _restoring == item.id
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.restore, size: 18),
          label: const Text('استعادة'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FinanceColors.primary,
            side: const BorderSide(color: FinanceColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FinanceRadius.control)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    ),
  );

  Widget _state(IconData icon, String title, String message, {Widget? action}) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: FinanceColors.tableHead, shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: FinanceColors.brown),
        ),
        const SizedBox(height: FinanceSpace.md),
        Text(title, style: FinanceText.page),
        const SizedBox(height: FinanceSpace.xs),
        Text(message, style: FinanceText.subtitle, textAlign: TextAlign.center),
        if (action != null) ...<Widget>[const SizedBox(height: FinanceSpace.md), action],
      ],
    ),
  );
}
