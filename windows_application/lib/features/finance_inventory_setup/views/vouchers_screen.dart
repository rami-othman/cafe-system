import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../pos/models/branch.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../models/finance_voucher.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/cash_source_field.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_paginated_table.dart';

/// Receipt/payment documents intentionally use their own API. Journal entries
/// and cash transfers below stay linked to their established workflows.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key, this.initialType});

  /// The cashier shell reuses this screen for one document type at a time.
  final String? initialType;
  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  late final FinanceSetupRepository _repository = context.read<FinanceSetupCubit>().repository;
  List<FinanceVoucher> _items = const <FinanceVoucher>[];
  List<FinancialAccount> _accounts = const <FinancialAccount>[];
  List<FinancialLocation> _locations = const <FinancialLocation>[];
  List<Branch> _branches = const <Branch>[];
  String? _type;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getVouchers(filters: <String, dynamic>{if (_type != null) 'type': _type}),
        _repository.getCashierVoucherOptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<FinanceVoucher>;
        final options = results[1] as ({List<FinancialAccount> accounts, List<FinancialLocation> locations, List<Branch> branches});
        _accounts = options.accounts;
        _locations = options.locations;
        _branches = options.branches;
        _loading = false;
      });
    } catch (error) { if (mounted) setState(() { _error = '$error'; _loading = false; }); }
  }

  Future<void> _create(String type) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _VoucherDialog(type: type, repository: _repository, accounts: _accounts, locations: _locations, branches: _branches));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    FinancePageHeader(
      title: 'السندات والقيود',
      subtitle: 'سندات القبض والدفع مرتبطة بدفتر الأستاذ؛ القيود والتحويلات تستخدم مساراتها المحاسبية المعتمدة.',
      actions: <Widget>[
        if (widget.initialType == null || widget.initialType == 'receipt')
          AppButton(label: 'سند قبض', icon: Icons.add_circle_outline, onPressed: _locations.isEmpty ? null : () => _create('receipt')),
        if (widget.initialType == null || widget.initialType == 'payment')
          AppButton(label: 'سند دفع', icon: Icons.remove_circle_outline, variant: AppButtonVariant.outlined, onPressed: _locations.isEmpty ? null : () => _create('payment')),
        if (widget.initialType == null) ...<Widget>[
          OutlinedButton.icon(onPressed: () => context.go(AppRoutes.financeJournalEntriesCanonical), icon: const Icon(Icons.menu_book_outlined), label: const Text('قيد يومية')),
          OutlinedButton.icon(onPressed: () => context.go(AppRoutes.financeCashBanks), icon: const Icon(Icons.swap_horiz), label: const Text('تحويل نقدي')),
        ],
      ],
    ),
    const SizedBox(height: AppSpacing.lg),
    if (widget.initialType == null) Wrap(spacing: AppSpacing.md, children: <Widget>[
      ChoiceChip(label: const Text('الكل'), selected: _type == null, onSelected: (_) { setState(() => _type = null); _load(); }),
      ChoiceChip(label: const Text('سندات القبض'), selected: _type == 'receipt', onSelected: (_) { setState(() => _type = 'receipt'); _load(); }),
      ChoiceChip(label: const Text('سندات الدفع'), selected: _type == 'payment', onSelected: (_) { setState(() => _type = 'payment'); _load(); }),
    ]),
    if (widget.initialType == null) const SizedBox(height: AppSpacing.lg),
    Expanded(child: _content()),
  ]);

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ManagementMessage(message: _error!, error: true, onRetry: _load);
    if (_items.isEmpty) return const ManagementMessage(message: 'لا توجد سندات ضمن عوامل التصفية المحددة.');
    return ManagementTableShell(minWidth: 1040, child: FinancePaginatedTable(minWidth: 1040, columns: const <DataColumn>[
      DataColumn(label: Text('رقم السند')), DataColumn(label: Text('النوع')), DataColumn(label: Text('التاريخ')), DataColumn(label: Text('الفرع')), DataColumn(label: Text('الحساب النقدي')), DataColumn(label: Text('البيان')), DataColumn(label: Text('المبلغ')), DataColumn(label: Text('الحالة')), DataColumn(label: Text('')),
    ], rows: _items.map(_row).toList(growable: false)));
  }

  DataRow _row(FinanceVoucher item) => DataRow(cells: <DataCell>[
    DataCell(Text(item.documentNumber)), DataCell(Text(item.documentType == 'receipt' ? 'سند قبض' : 'سند دفع')), DataCell(Text(item.documentDate)), DataCell(Text(item.branchName ?? '—')), DataCell(Text(item.financialLocationName ?? '—')), DataCell(Text(item.description ?? '—')), DataCell(FinanceAmount(value: item.amount)), DataCell(ManagementBadge(label: item.status == 'draft' ? 'مسودة' : item.status == 'posted' ? 'مرحل' : 'معكوس', tone: item.status == 'draft' ? ManagementTone.warning : item.status == 'posted' ? ManagementTone.success : ManagementTone.danger)),
    DataCell(PopupMenuButton<String>(onSelected: (action) async { if (action == 'post') await _repository.postVoucher(item.id); if (action == 'reverse') await _repository.reverseVoucher(item.id, 'عكس بواسطة المستخدم'); if (mounted) _load(); }, itemBuilder: (_) => <PopupMenuEntry<String>>[if (item.allowedActions.contains('post')) const PopupMenuItem(value: 'post', child: Text('ترحيل')), if (item.allowedActions.contains('reverse')) const PopupMenuItem(value: 'reverse', child: Text('عكس'))])),
  ]);
}

class _VoucherDialog extends StatefulWidget {
  const _VoucherDialog({required this.type, required this.repository, required this.accounts, required this.locations, required this.branches});
  final String type; final FinanceSetupRepository repository; final List<FinancialAccount> accounts; final List<FinancialLocation> locations; final List<Branch> branches;
  @override State<_VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<_VoucherDialog> {
  int? _locationId;
  int? _branchId;
  CashSourceOptions? _cashOptions;
  late final TextEditingController _amount = TextEditingController();
  late final TextEditingController _description = TextEditingController();
  final List<_DistributionLine> _lines = <_DistributionLine>[];
  String? _error; bool _saving = false;
  @override void initState() { super.initState(); _addLine(); }
  @override void dispose() { _amount.dispose(); _description.dispose(); for (final line in _lines) { line.dispose(); } super.dispose(); }
  void _addLine() => _lines.add(_DistributionLine(widget.accounts.first.id));
  Future<void> _selectBranch(int? branchId) async {
    setState(() { _branchId = branchId; _locationId = null; _cashOptions = null; });
    if (branchId == null) return;
    try {
      final options = await widget.repository.getCashSourceOptions(branchId);
      if (mounted && _branchId == branchId) setState(() => _cashOptions = options);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }
  Future<void> _save() async {
    if (_amount.text.trim().isEmpty || _lines.any((line) => line.amount.text.trim().isEmpty)) { setState(() => _error = 'أدخل مبلغ السند ومبالغ التوزيع.'); return; }
    if (_cashOptions?.mode == 'shift' && _cashOptions?.resolved == null) { setState(() => _error = 'يجب فتح وردية بصندوق صالح.'); return; }
    if (_cashOptions?.mode != 'shift' && !cashSourceIsResolved(_cashOptions, _locationId)) { setState(() => _error = 'يرجى اختيار الصندوق.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.repository.createVoucher(<String, dynamic>{'documentType': widget.type, 'documentDate': DateTime.now().toIso8601String().substring(0, 10), 'branchId': _branchId, if (_cashOptions?.mode != 'shift') 'financialLocationId': _locationId, 'currencyCode': 'SYP', 'exchangeRate': '1', 'amount': _amount.text.trim(), 'description': _description.text.trim(), 'idempotencyKey': 'voucher-${DateTime.now().microsecondsSinceEpoch}', 'lines': _lines.map((line) => <String, dynamic>{'accountId': line.accountId, 'amount': line.amount.text.trim(), 'description': line.description.text.trim()}).toList()});
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _error = '$error'; _saving = false; }); }
  }
  @override Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.type == 'receipt' ? 'سند قبض جديد' : 'سند دفع جديد'),
    content: SizedBox(width: 760, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      DropdownButtonFormField<int?>(initialValue: _branchId, decoration: const InputDecoration(labelText: 'الفرع'), items: <DropdownMenuItem<int?>>[const DropdownMenuItem(value: null, child: Text('بدون فرع')), ...widget.branches.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))], onChanged: _selectBranch),
      if (_cashOptions?.mode == 'shift') Text('الصندوق: ${_cashOptions?.resolved?.name ?? 'غير محدد'}')
      else DropdownButtonFormField<int>(initialValue: _locationId, isExpanded: true, decoration: const InputDecoration(labelText: 'الصندوق / الحساب البنكي'), items: widget.locations.where((x) => _branchId == null || (x.kind == 'bank' && (x.branchId == null || x.branchId == _branchId)) || (_cashOptions?.allowed.any((allowed) => allowed.id == x.id) ?? false)).map((x) => DropdownMenuItem(value: x.id, child: Text(x.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (x) => setState(() => _locationId = x)),
      TextField(controller: _amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.type == 'receipt' ? 'إجمالي المقبوض' : 'إجمالي المدفوع')),
      TextField(controller: _description, decoration: const InputDecoration(labelText: 'البيان')),
      const SizedBox(height: AppSpacing.md), const Text('التوزيع المحاسبي'),
      ..._lines.asMap().entries.map((entry) => Row(children: <Widget>[Expanded(child: LayoutBuilder(builder: (context, constraints) => DropdownMenu<int>(initialSelection: entry.value.accountId, width: constraints.maxWidth, menuHeight: 5 * 48, dropdownMenuEntries: widget.accounts.map((a) => DropdownMenuEntry(value: a.id, label: '${a.code} — ${a.nameAr}')).toList(), onSelected: (x) { if (x != null) setState(() => entry.value.accountId = x); }))), const SizedBox(width: AppSpacing.sm), SizedBox(width: 120, child: TextField(controller: entry.value.amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ'))), IconButton(onPressed: _lines.length == 1 ? null : () => setState(() { entry.value.dispose(); _lines.removeAt(entry.key); }), icon: const Icon(Icons.delete_outline))])),
      TextButton.icon(onPressed: () => setState(_addLine), icon: const Icon(Icons.add), label: const Text('إضافة سطر')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
    ]))),
    actions: <Widget>[TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')), AppButton(label: 'حفظ كمسودة', onPressed: _saving ? null : _save)],
  );
}
class _DistributionLine { _DistributionLine(this.accountId) : amount = TextEditingController(), description = TextEditingController(); int accountId; final TextEditingController amount, description; void dispose() { amount.dispose(); description.dispose(); } }
