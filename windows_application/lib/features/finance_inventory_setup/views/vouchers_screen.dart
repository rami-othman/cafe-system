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
import '../widgets/finance_design.dart';
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

/// Loading state for the branch's cash/bank source list, tracked separately
/// from `_cashOptions` so the UI can distinguish "still loading" from
/// "loaded and empty" — the empty case reads as a silent bug otherwise (the
/// reported client issue).
enum _SourceLoadState { idle, loading, loaded, failed }

class _VoucherDialogState extends State<_VoucherDialog> {
  int? _locationId;
  int? _branchId;
  CashSourceOptions? _cashOptions;
  _SourceLoadState _sourceState = _SourceLoadState.idle;
  late final TextEditingController _amount = TextEditingController();
  late final TextEditingController _description = TextEditingController();
  final List<_DistributionLine> _lines = <_DistributionLine>[];
  String? _error; bool _saving = false;
  // Defaults to today; the user can pick an earlier open-period date. The
  // posted journal entry uses this value, not the moment the dialog is saved.
  String _documentDate = DateTime.now().toIso8601String().substring(0, 10);

  bool get _isPayment => widget.type == 'payment';

  /// Accounts a cash/bank source (financial_locations.financial_account_id)
  /// backs are excluded from the distribution list: they already represent
  /// the source side of the journal, so offering them here would let a user
  /// put the same cash/bank account on both the debit and credit side of the
  /// same voucher by accident.
  late final Set<int> _cashBackedAccountIds = widget.locations.map((l) => l.financialAccountId).toSet();
  late final List<FinancialAccount> _distributionAccounts = widget.accounts.where((a) => !_cashBackedAccountIds.contains(a.id)).toList(growable: false);

  @override void initState() { super.initState(); _addLine(); }
  @override void dispose() { _amount.dispose(); _description.dispose(); for (final line in _lines) { line.dispose(); } super.dispose(); }

  // Item 1: a new voucher starts with no distribution account selected —
  // never `accounts.first`, and never a hardcoded 1010.
  void _addLine() => _lines.add(_DistributionLine());

  Future<void> _pickDocumentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_documentDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _documentDate = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _selectBranch(int? branchId) async {
    setState(() { _branchId = branchId; _locationId = null; _cashOptions = null; _sourceState = branchId == null ? _SourceLoadState.idle : _SourceLoadState.loading; });
    if (branchId == null) return;
    try {
      final options = await widget.repository.getCashSourceOptions(branchId);
      if (mounted && _branchId == branchId) setState(() { _cashOptions = options; _sourceState = _SourceLoadState.loaded; });
    } catch (error) {
      if (mounted && _branchId == branchId) setState(() { _error = 'تعذر تحميل الصناديق والحسابات البنكية لهذا الفرع: $error'; _sourceState = _SourceLoadState.failed; });
    }
  }

  /// Bank locations are not part of `CashSourceOptions` (that contract only
  /// covers `kind == 'cash'`), so the branch-scoped bank locations are read
  /// straight from the reference data already loaded for the screen.
  List<FinancialLocation> get _bankLocationsForBranch => widget.locations
      .where((x) => x.kind == 'bank' && (x.branchId == null || x.branchId == _branchId))
      .toList(growable: false);

  int _cents(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
    if (match == null) return 0;
    return int.parse(match.group(1)!) * 100 + int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

  int get _amountCents => _cents(_amount.text);
  int get _distributedCents => _lines.fold(0, (sum, line) => sum + _cents(line.amount.text));
  bool get _isBalanced => _amountCents > 0 && _amountCents == _distributedCents;

  String? _validationError() {
    if (_amount.text.trim().isEmpty || _cents(_amount.text) <= 0) return 'أدخل مبلغ السند.';
    if (_lines.isEmpty || _lines.any((line) => line.accountId == null)) return 'اختر ${_isPayment ? 'الحساب المدين' : 'الحساب الدائن'} لكل سطر توزيع.';
    if (_lines.any((line) => line.amount.text.trim().isEmpty || _cents(line.amount.text) <= 0)) return 'أدخل مبلغًا صحيحًا لكل سطر توزيع.';
    if (!_isBalanced) {
      final diff = (_amountCents - _distributedCents).abs();
      final diffText = '${diff ~/ 100}.${(diff % 100).toString().padLeft(2, '0')}';
      return 'مجموع سطور التوزيع لا يساوي مبلغ السند. الفرق: $diffText. يرجى تعديل المبالغ حتى تتطابق مع إجمالي السند.';
    }
    if (_cashOptions?.mode == 'shift' && _cashOptions?.resolved == null) return 'يجب فتح وردية بصندوق صالح قبل إنشاء السند.';
    if (_cashOptions?.mode != 'shift' && !cashSourceIsResolved(_cashOptions, _locationId)) return 'يرجى اختيار الصندوق أو الحساب البنكي.';
    return null;
  }

  Map<String, dynamic> _payload() => <String, dynamic>{
    'documentType': widget.type,
    'documentDate': _documentDate,
    'branchId': _branchId,
    if (_cashOptions?.mode != 'shift') 'financialLocationId': _locationId,
    'currencyCode': 'SYP', 'exchangeRate': '1',
    'amount': _amount.text.trim(),
    'description': _description.text.trim(),
    'idempotencyKey': _idempotencyKey,
    'lines': _lines.map((line) => <String, dynamic>{'accountId': line.accountId, 'amount': line.amount.text.trim(), 'description': line.description.text.trim()}).toList(),
  };

  // Stable per-dialog-instance key: a retry after a failed "Save and Post"
  // reuses the same key so the backend returns the already-created draft
  // instead of inserting a duplicate document (see FinanceDocumentService::byKey).
  late final String _idempotencyKey = 'voucher-${DateTime.now().microsecondsSinceEpoch}';
  int? _draftId;

  Future<void> _saveDraft() async {
    final validation = _validationError();
    if (validation != null) { setState(() => _error = validation); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final voucher = await widget.repository.createVoucher(_payload());
      _draftId = voucher.id;
      if (mounted) Navigator.pop(context, true);
    } catch (error) { if (mounted) setState(() { _error = '$error'; _saving = false; }); }
  }

  Future<void> _saveAndPost() async {
    final validation = _validationError();
    if (validation != null) { setState(() => _error = validation); return; }
    setState(() { _saving = true; _error = null; });
    try {
      // create-or-reuse (idempotency key) then post: at most one journal
      // entry is ever created even if this is a retry after a prior failure.
      final voucher = await widget.repository.createVoucher(_payload());
      _draftId = voucher.id;
      await widget.repository.postVoucher(voucher.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _draftId != null
              ? 'تم حفظ السند كمسودة رقم $_draftId لكن تعذر ترحيله: $error. يمكنك إعادة محاولة «حفظ وترحيل» دون تكرار السند.'
              : '$error';
          _saving = false;
        });
      }
    }
  }

  @override Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.type == 'receipt' ? 'سند قبض جديد' : 'سند دفع جديد'),
    content: SizedBox(width: 780, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      DropdownButtonFormField<int?>(initialValue: _branchId, decoration: const InputDecoration(labelText: 'الفرع'), items: <DropdownMenuItem<int?>>[const DropdownMenuItem(value: null, child: Text('بدون فرع')), ...widget.branches.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))], onChanged: _selectBranch),
      const SizedBox(height: AppSpacing.sm),
      InkWell(onTap: _pickDocumentDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'تاريخ السند'), child: Text(_documentDate))),
      const SizedBox(height: AppSpacing.sm),
      Text(_isPayment ? 'الصندوق أو الحساب البنكي المحدد هو الجانب الدائن (Cr) لهذا السند.' : 'الصندوق أو الحساب البنكي المحدد هو الجانب المدين (Dr) لهذا السند.', style: FinanceText.small),
      const SizedBox(height: 4),
      _buildSourceField(),
      const SizedBox(height: AppSpacing.md),
      TextField(controller: _amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.type == 'receipt' ? 'إجمالي المقبوض' : 'إجمالي المدفوع'), onChanged: (_) => setState(() {})),
      TextField(controller: _description, decoration: const InputDecoration(labelText: 'البيان')),
      const SizedBox(height: AppSpacing.md),
      Text(_isPayment ? 'الحساب المدين (Dr)' : 'الحساب الدائن (Cr)', style: FinanceText.label),
      const SizedBox(height: 4),
      ..._lines.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: <Widget>[
        Expanded(child: LayoutBuilder(builder: (context, constraints) => DropdownMenu<int>(
          initialSelection: entry.value.accountId,
          width: constraints.maxWidth,
          menuHeight: 5 * 48,
          hintText: 'اختر الحساب',
          dropdownMenuEntries: _distributionAccounts.map((a) => DropdownMenuEntry(value: a.id, label: '${a.code} — ${a.nameAr}')).toList(),
          onSelected: (x) => setState(() => entry.value.accountId = x),
        ))),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(width: 120, child: TextField(controller: entry.value.amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ'), onChanged: (_) => setState(() {}))),
        IconButton(onPressed: _lines.length == 1 ? null : () => setState(() { entry.value.dispose(); _lines.removeAt(entry.key); }), icon: const Icon(Icons.delete_outline)),
      ]))),
      TextButton.icon(onPressed: () => setState(_addLine), icon: const Icon(Icons.add), label: const Text('إضافة سطر')),
      const SizedBox(height: AppSpacing.md),
      _buildPreview(),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(_error!, style: const TextStyle(color: Colors.red))),
    ]))),
    actions: <Widget>[
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      AppButton(label: 'حفظ كمسودة', variant: AppButtonVariant.outlined, onPressed: _saving ? null : _saveDraft),
      AppButton(label: 'حفظ وترحيل', onPressed: _saving ? null : _saveAndPost),
    ],
  );

  Widget _buildSourceField() {
    if (_branchId == null) return const Text('اختر الفرع أولاً لعرض الصناديق والحسابات البنكية المتاحة.', style: FinanceText.small);
    if (_sourceState == _SourceLoadState.loading) {
      return const Row(children: <Widget>[SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('جارٍ تحميل الصناديق والحسابات البنكية...', style: FinanceText.small)]);
    }
    if (_sourceState == _SourceLoadState.failed) {
      return const Text('تعذر تحميل الصناديق والحسابات البنكية. راجع الرسالة أدناه.', style: TextStyle(color: FinanceColors.danger));
    }
    final options = _cashOptions;
    if (options == null) return const SizedBox.shrink();
    if (options.mode == 'shift') {
      if (options.resolved == null) {
        return const Text('لا توجد وردية مفتوحة بصندوق صالح لهذا المستخدم. افتح وردية قبل إنشاء السند.', style: TextStyle(color: FinanceColors.danger));
      }
      return Text('الصندوق: ${options.resolved!.name}', style: FinanceText.body);
    }
    final bankLocations = _bankLocationsForBranch;
    if (options.allowed.isEmpty && bankLocations.isEmpty) {
      return const Text('لا يوجد صندوق نقدي أو حساب بنكي مُهيأ أو مصرّح به لهذا الفرع. راجع إعدادات الصناديق أو صلاحياتك.', style: TextStyle(color: FinanceColors.danger));
    }
    final items = <DropdownMenuItem<int>>[
      ...options.allowed.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name, overflow: TextOverflow.ellipsis))),
      ...bankLocations.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name, overflow: TextOverflow.ellipsis))),
    ];
    return DropdownButtonFormField<int>(initialValue: _locationId, isExpanded: true, decoration: const InputDecoration(labelText: 'الصندوق / الحساب البنكي'), items: items, onChanged: (x) => setState(() => _locationId = x));
  }

  String _sourceLabel() {
    if (_cashOptions?.mode == 'shift') return _cashOptions?.resolved?.name ?? '—';
    final id = _locationId;
    if (id == null) return '—';
    final fromBank = _bankLocationsForBranch.where((l) => l.id == id).firstOrNull;
    if (fromBank != null) return fromBank.name;
    return _cashOptions?.allowed.where((l) => l.id == id).firstOrNull?.name ?? '—';
  }

  /// Item 4: the preview is built from exactly the same `_lines`/`_amount`/
  /// source selection that `_payload()` sends to the backend — no separate
  /// calculation that could drift from what is actually submitted.
  Widget _buildPreview() {
    String decimal(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
    final distributionRows = _lines.where((l) => l.accountId != null).map((l) {
      final account = _distributionAccounts.where((a) => a.id == l.accountId).firstOrNull;
      return (label: account == null ? '—' : '${account.code} — ${account.nameAr}', cents: _cents(l.amount.text));
    }).toList(growable: false);
    final sourceCents = _distributedCents;
    return Container(
      padding: const EdgeInsets.all(FinanceSpace.md),
      decoration: BoxDecoration(color: FinanceColors.workspace, border: Border.all(color: FinanceColors.border), borderRadius: BorderRadius.circular(FinanceRadius.control)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('معاينة القيد', style: FinanceText.label),
        const SizedBox(height: FinanceSpace.sm),
        if (_isPayment) ...<Widget>[
          ...distributionRows.map((row) => _previewRow(row.label, 'مدين', row.cents, FinanceColors.success)),
          _previewRow(_sourceLabel(), 'دائن', sourceCents, FinanceColors.warning),
        ] else ...<Widget>[
          _previewRow(_sourceLabel(), 'مدين', sourceCents, FinanceColors.success),
          ...distributionRows.map((row) => _previewRow(row.label, 'دائن', row.cents, FinanceColors.warning)),
        ],
        const Divider(height: FinanceSpace.lg),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
          Text('إجمالي المدين: ${decimal(_isPayment ? _distributedCents : sourceCents)}', style: FinanceText.small),
          Text('إجمالي الدائن: ${decimal(_isPayment ? sourceCents : _distributedCents)}', style: FinanceText.small),
          Text(_isBalanced ? 'متوازن' : 'غير متوازن', style: TextStyle(color: _isBalanced ? FinanceColors.success : FinanceColors.danger, fontFamily: FinanceText.fontFamily, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ]),
      ]),
    );
  }

  Widget _previewRow(String label, String side, int cents, Color sideColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: <Widget>[
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.12), border: Border.all(color: sideColor), borderRadius: BorderRadius.circular(FinanceRadius.pill)), child: Text(side, style: TextStyle(color: sideColor, fontFamily: FinanceText.fontFamily, fontWeight: FontWeight.w700, fontSize: 11))),
      const SizedBox(width: FinanceSpace.sm),
      Expanded(child: Text(label, style: FinanceText.body)),
      FinanceAmount(value: '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}'),
    ]),
  );
}
class _DistributionLine { _DistributionLine() : amount = TextEditingController(), description = TextEditingController(); int? accountId; final TextEditingController amount, description; void dispose() { amount.dispose(); description.dispose(); } }
