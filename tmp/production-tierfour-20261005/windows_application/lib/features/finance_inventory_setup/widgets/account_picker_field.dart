import 'package:flutter/material.dart';

import '../../../core/utils/arabic_search.dart';
import '../models/finance_setup_models.dart';
import 'finance_design.dart';

String accountGroupLabel(String? value) => switch (value) {
  'assets' => 'الأصول',
  'liabilities' => 'الالتزامات',
  'equity' => 'حقوق الملكية',
  'revenue' => 'الإيرادات',
  'cost_of_sales' => 'تكلفة المبيعات',
  _ => 'المصروفات',
};

/// One account picker for every Finance screen: instead of a dropdown that
/// lists the whole chart of accounts, the user taps the field, types a few
/// letters or digits (Arabic-tolerant, code or name, several words at once)
/// and picks from a ranked list. Recently used accounts come first when the
/// search box is empty; each row shows its code, name, group and parent.
class AccountPickerField extends StatelessWidget {
  const AccountPickerField({
    super.key,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.label = 'الحساب',
    this.hint = 'ابحث بالاسم أو الرقم',
    this.allowClear = false,
    this.where,
    this.width,
    this.dense = false,
  });

  final List<FinancialAccount> accounts;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;
  final String hint;
  final bool allowClear;

  /// Extra rule on which accounts may be chosen (e.g. only postable ones).
  final bool Function(FinancialAccount account)? where;
  final double? width;
  final bool dense;

  FinancialAccount? get _selected {
    for (final FinancialAccount a in accounts) {
      if (a.id == value) return a;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final _Pick? pick = await showDialog<_Pick>(
      context: context,
      builder: (BuildContext dialogContext) => _AccountPickerDialog(
        accounts: accounts
            .where((FinancialAccount a) => (a.isActive || a.id == value) && (where?.call(a) ?? true))
            .toList(growable: false),
        selectedId: value,
        title: label,
        allowClear: allowClear,
      ),
    );
    if (pick == null) return;
    if (pick.account != null) _AccountPickerDialog.remember(pick.account!.id);
    onChanged(pick.account?.id);
  }

  @override
  Widget build(BuildContext context) {
    final FinancialAccount? selected = _selected;
    final Widget field = InkWell(
      borderRadius: BorderRadius.circular(FinanceRadius.control),
      onTap: () => _open(context),
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: dense,
          suffixIcon: const Icon(Icons.search, size: 20),
        ),
        child: selected == null
            ? const SizedBox(height: 20)
            : Text(
                '${selected.code} — ${selected.nameAr}',
                overflow: TextOverflow.ellipsis,
                style: FinanceText.body,
              ),
      ),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }
}

class _Pick {
  const _Pick(this.account);
  final FinancialAccount? account;
}

class _AccountPickerDialog extends StatefulWidget {
  const _AccountPickerDialog({
    required this.accounts,
    required this.selectedId,
    required this.title,
    required this.allowClear,
  });

  final List<FinancialAccount> accounts;
  final int? selectedId;
  final String title;
  final bool allowClear;

  static final List<int> _recent = <int>[];
  static void remember(int id) {
    _recent
      ..remove(id)
      ..insert(0, id);
    if (_recent.length > 6) _recent.removeRange(6, _recent.length);
  }

  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  final TextEditingController _query = TextEditingController();
  late final List<FinancialAccount> _sorted = (List<FinancialAccount>.of(widget.accounts)
    ..sort((FinancialAccount a, FinancialAccount b) => a.code.compareTo(b.code)));
  late final ArabicSearchIndex<FinancialAccount> _index = ArabicSearchIndex<FinancialAccount>(
    _sorted,
    (FinancialAccount a) => <String>[
      a.code,
      a.nameAr,
      a.nameEn,
      a.parentNameAr ?? '',
      accountGroupLabel(a.accountGroup),
    ],
  );
  int _highlight = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<FinancialAccount> get _results {
    final String q = _query.text.trim();
    if (q.isNotEmpty) return _index.search(q).take(80).toList(growable: false);
    final List<FinancialAccount> recent = <FinancialAccount>[
      for (final int id in _AccountPickerDialog._recent)
        ..._sorted.where((FinancialAccount a) => a.id == id),
    ];
    final Set<int> recentIds = recent.map((FinancialAccount a) => a.id).toSet();
    return <FinancialAccount>[
      ...recent,
      ..._sorted.where((FinancialAccount a) => !recentIds.contains(a.id)).take(60),
    ];
  }

  void _choose(FinancialAccount? account) => Navigator.pop(context, _Pick(account));

  @override
  Widget build(BuildContext context) {
    final List<FinancialAccount> results = _results;
    final bool searching = _query.text.trim().isNotEmpty;
    final int recentCount = searching ? 0 : _AccountPickerDialog._recent.length;
    if (_highlight >= results.length) _highlight = results.isEmpty ? 0 : results.length - 1;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('اختيار: ${widget.title}', style: FinanceText.page),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        content: SizedBox(
          width: 560,
          height: 460,
          child: Column(
            children: <Widget>[
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'اكتب جزءاً من الاسم أو الرقم (مثال: صندوق، 1010، مبيعات)',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() => _highlight = 0),
                onSubmitted: (_) {
                  if (results.isNotEmpty) _choose(results[_highlight]);
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  searching
                      ? (results.isEmpty ? 'لا نتائج مطابقة' : '${results.length} نتيجة مرتّبة حسب الأقرب')
                      : (recentCount > 0 ? 'المستخدمة مؤخراً ثم باقي الحسابات بترتيب الرقم' : 'الحسابات بترتيب الرقم — اكتب للبحث'),
                  style: FinanceText.small,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final FinancialAccount a = results[index];
                    final bool isSelected = a.id == widget.selectedId;
                    final String parent = a.parentCode == null ? '' : ' · الأب: ${a.parentCode} ${a.parentNameAr ?? ''}';
                    return ListTile(
                      dense: true,
                      selected: isSelected || index == _highlight && searching,
                      leading: index < recentCount ? const Icon(Icons.history, size: 18) : null,
                      title: Text('${a.code} — ${a.nameAr}', overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${accountGroupLabel(a.accountGroup)}$parent',
                        overflow: TextOverflow.ellipsis,
                        style: FinanceText.small,
                      ),
                      trailing: isSelected ? const Icon(Icons.check, size: 18) : null,
                      onTap: () => _choose(a),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          if (widget.allowClear && widget.selectedId != null)
            TextButton(onPressed: () => _choose(null), child: const Text('إزالة الاختيار')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ],
      ),
    );
  }
}
