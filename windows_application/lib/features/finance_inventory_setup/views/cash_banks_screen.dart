import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/service_locator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../pos/models/branch.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_design.dart';
import '../widgets/finance_journal_drawer.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_shell.dart';
import '../widgets/finance_transaction_type.dart';

/// Canonical `/finance/cash-banks` screen. Laravel remains the sole source of
/// balances, incoming/outgoing activity, movement history, and transfer
/// posting; this widget only presents already-authorized data and basic
/// view-composition (e.g. summing per-account balances already returned by
/// the backend) — it never derives or recalculates accounting values.
class CashBanksScreen extends StatefulWidget {
  const CashBanksScreen({super.key});
  @override
  State<CashBanksScreen> createState() => _CashBanksScreenState();
}

class _CashBanksScreenState extends State<CashBanksScreen> {
  late final FinanceSetupRepository _repository;

  List<FinancialLocation>? _cash;
  List<FinancialLocation>? _bank;
  List<PaymentMethodSetting> _paymentMethods = const <PaymentMethodSetting>[];
  List<FinancialAccount> _ledgerAccounts = const <FinancialAccount>[];
  List<Branch> _branches = const <Branch>[];
  List<Map<String, dynamic>> _movements = const <Map<String, dynamic>>[];
  Object? _error;
  bool _loading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<FinanceSetupRepository>();
    _load();
  }

  List<FinancialLocation> get _allLocations => <FinancialLocation>[
    ...?_cash,
    ...?_bank,
  ];

  /// Transfers may only move money between active accounts — the backend
  /// rejects an inactive source or destination, so the picker never offers
  /// one in the first place.
  List<FinancialLocation> get _activeLocations =>
      _allLocations.where((FinancialLocation a) => a.isActive).toList();

  Future<void> _load() async {
    final int requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getFinancialLocations('cash'),
        _repository.getFinancialLocations('bank'),
        _repository.getPaymentMethods(),
        _repository.getAccounts(status: 'active', group: 'assets'),
        _repository.getBranches(),
        _repository.getFinancePage(
          'finance/transactions',
          queryParameters: <String, dynamic>{
            'has_cash_effect': 1,
            'status': 'posted',
            'perPage': 8,
          },
        ),
      ]);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _cash = results[0] as List<FinancialLocation>;
        _bank = results[1] as List<FinancialLocation>;
        _paymentMethods = results[2] as List<PaymentMethodSetting>;
        _ledgerAccounts = results[3] as List<FinancialAccount>;
        _branches = results[4] as List<Branch>;
        _movements = (results[5] as FinancePage<Map<String, dynamic>>).items;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      padding: EdgeInsets.zero,
      child: FinanceShell(
        currentSection: 'النقدية والبنوك',
        title: 'النقدية والبنوك',
        subtitle: 'إدارة الصناديق والحسابات البنكية ومتابعة الأرصدة والحركات',
        showContext: false,
        actions: <Widget>[
          OutlinedButton(
            onPressed: () => _openAccountForm(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              foregroundColor: FinanceColors.primary,
              side: const BorderSide(color: FinanceColors.border),
              backgroundColor: FinanceColors.card,
            ),
            child: const Text('حساب جديد'),
          ),
          const SizedBox(width: FinanceSpace.sm),
          ElevatedButton.icon(
            onPressed: _activeLocations.length < 2 ? null : () => _openTransfer(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              backgroundColor: FinanceColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: FinanceColors.disabled,
            ),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('تحويل بين الحسابات'),
          ),
        ],
        child: _buildBody(),
      ),
    ),
  );

  Widget _buildBody() {
    if (_cash == null && _error == null) {
      return const FinanceLoadingState(label: 'جارٍ تحميل النقدية والبنوك…');
    }
    if (_cash == null) {
      return FinanceErrorState(
        message: 'تعذّر تحميل النقدية والبنوك. لم يتم اعتبار الخطأ صفراً.',
        onRetry: _load,
      );
    }
    final List<FinancialLocation> cash = _cash!;
    final List<FinancialLocation> bank = _bank!;
    final List<PaymentMethodSetting> unlinked = _paymentMethods
        .where(
          (PaymentMethodSetting method) =>
              method.isActive && method.financialLocationId == null,
        )
        .toList(growable: false);

    return SingleChildScrollView(
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: IgnorePointer(
          ignoring: _loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (unlinked.isNotEmpty) ...<Widget>[
                FinanceAlertBanner(
                  message:
                      'طريقة دفع غير مربوطة بحساب مالي — ${unlinked.map((PaymentMethodSetting m) => m.name).join('، ')}',
                  tone: FinanceTone.warning,
                  action: TextButton(
                    onPressed: () => context.go('/finance/settings/payment-methods'),
                    child: const Text('إعدادات المالية'),
                  ),
                ),
                const SizedBox(height: FinanceSpace.lg),
              ],
              if (_error != null) ...<Widget>[
                FinanceAlertBanner(
                  message: 'تعذّر تحديث بعض البيانات. تُعرض آخر بيانات محمّلة.',
                  tone: FinanceTone.warning,
                  action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                ),
                const SizedBox(height: FinanceSpace.lg),
              ],
              _SummaryGrid(cash: cash, bank: bank),
              const SizedBox(height: FinanceSpace.lg),
              _AccountGroupCard(
                title: 'النقدية',
                accounts: cash,
                emptyMessage: 'لا توجد حسابات نقدية',
                subtitleFor: (FinancialLocation a) =>
                    '${a.type} · ${a.branchName ?? 'كل الفروع'}',
                onOpen: _openAccountDetail,
                onTransfer: _activeLocations.length < 2 ? null : _openTransfer,
                onEdit: _openAccountForm,
                onToggleStatus: _confirmToggleStatus,
              ),
              const SizedBox(height: FinanceSpace.lg),
              _AccountGroupCard(
                title: 'البنوك',
                accounts: bank,
                emptyMessage: 'لا توجد حسابات بنكية',
                subtitleFor: (FinancialLocation a) =>
                    '${a.bankName ?? 'بنك'} · ${a.maskedReference ?? '—'}',
                onOpen: _openAccountDetail,
                onTransfer: _activeLocations.length < 2 ? null : _openTransfer,
                onEdit: _openAccountForm,
                onToggleStatus: _confirmToggleStatus,
              ),
              const SizedBox(height: FinanceSpace.lg),
              _RecentMovements(rows: _movements, onOpen: _openJournalDrawer),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmToggleStatus(FinancialLocation item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(item.isActive ? 'تعطيل الحساب؟' : 'تفعيل الحساب؟'),
        content: const Text(
          'لن يتغيّر الرصيد؛ يؤثر هذا فقط على إتاحة الحساب للحركات الجديدة.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(item.isActive ? 'تعطيل' : 'تفعيل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.setFinancialLocationStatus(
        item.kind,
        item.id,
        !item.isActive,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _openAccountForm([FinancialLocation? current]) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _AccountFormDialog(
        current: current,
        ledgerAccounts: _ledgerAccounts,
        branches: _branches,
        onSubmit: (String kind, Map<String, dynamic> payload) => _repository
            .saveFinancialLocation(kind, payload, id: current?.id),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openTransfer([FinancialLocation? preselectedSource]) async {
    final bool? completed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => _TransferDialog(
        accounts: _activeLocations,
        preselectedSourceId: preselectedSource?.id,
        onSubmit: (Map<String, dynamic> payload) =>
            _repository.createCashTransfer(payload),
      ),
    );
    if (completed == true) await _load();
  }

  Future<void> _openAccountDetail(FinancialLocation item) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialog) => _AccountDetailDialog(
        item: item,
        loader: () =>
            _repository.getFinancialLocationTransactions(item.kind, item.id),
        onTransfer: () {
          Navigator.of(dialog).pop();
          _openTransfer(item);
        },
        onEdit: () {
          Navigator.of(dialog).pop();
          _openAccountForm(item);
        },
        onToggleStatus: () {
          Navigator.of(dialog).pop();
          _confirmToggleStatus(item);
        },
        onOpenJournal: _openJournalDrawer,
      ),
    );
  }

  void _openJournalDrawer(int journalEntryId) {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'إغلاق',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (BuildContext dialogContext, _, _) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FinanceJournalDrawer(
          child: FinanceJournalDrawerBody(
            loader: () =>
                _repository.getFinanceMap('finance/transactions/$journalEntryId'),
            onNavigate: (String path) {
              Navigator.of(dialogContext).pop();
              context.go(path);
            },
            onReverseTransfer: (int transferId) async {
              await _repository.reverseCashTransfer(transferId);
              await _load();
            },
          ),
        ),
      ),
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            _,
            Widget child,
          ) => SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
    ).then((_) => _load());
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cash, required this.bank});
  final List<FinancialLocation> cash;
  final List<FinancialLocation> bank;

  @override
  Widget build(BuildContext context) {
    final double cashTotal = cash.fold<double>(
      0,
      (double sum, FinancialLocation a) => sum + _amount(a.balance),
    );
    final double bankTotal = bank.fold<double>(
      0,
      (double sum, FinancialLocation a) => sum + _amount(a.balance),
    );
    final List<FinancialLocation> all = <FinancialLocation>[...cash, ...bank];
    final double inToday = all.fold<double>(
      0,
      (double sum, FinancialLocation a) => sum + _amount(a.todayIncoming),
    );
    final double outToday = all.fold<double>(
      0,
      (double sum, FinancialLocation a) => sum + _amount(a.todayOutgoing),
    );
    return FinanceKpiGrid(
      items: <FinanceKpiData>[
        FinanceKpiData(
          label: 'إجمالي النقدية',
          value: _money(cashTotal),
          icon: Icons.payments_outlined,
        ),
        FinanceKpiData(
          label: 'إجمالي البنوك',
          value: _money(bankTotal),
          icon: Icons.account_balance_outlined,
        ),
        FinanceKpiData(
          label: 'الداخل اليوم',
          value: _money(inToday),
          icon: Icons.south_west,
          tone: FinanceTone.success,
        ),
        FinanceKpiData(
          label: 'الخارج اليوم',
          value: _money(outToday),
          icon: Icons.north_east,
          tone: FinanceTone.warning,
        ),
      ],
    );
  }
}

class _AccountGroupCard extends StatelessWidget {
  const _AccountGroupCard({
    required this.title,
    required this.accounts,
    required this.emptyMessage,
    required this.subtitleFor,
    required this.onOpen,
    required this.onTransfer,
    required this.onEdit,
    required this.onToggleStatus,
  });
  final String title;
  final List<FinancialLocation> accounts;
  final String emptyMessage;
  final String Function(FinancialLocation) subtitleFor;
  final ValueChanged<FinancialLocation> onOpen;
  final ValueChanged<FinancialLocation>? onTransfer;
  final ValueChanged<FinancialLocation> onEdit;
  final ValueChanged<FinancialLocation> onToggleStatus;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: FinanceSpace.lg,
            vertical: FinanceSpace.md,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FinanceColors.tableHead)),
          ),
          child: Text(
            title,
            style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(FinanceSpace.xl),
            child: FinanceEmptyState(message: emptyMessage),
          )
        else
          ...accounts.map(
            (FinancialLocation account) => _AccountRow(
              account: account,
              subtitle: subtitleFor(account),
              onOpen: () => onOpen(account),
              onTransfer: account.isActive && onTransfer != null
                  ? () => onTransfer!(account)
                  : null,
              onEdit: () => onEdit(account),
              onToggleStatus: () => onToggleStatus(account),
            ),
          ),
      ],
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.subtitle,
    required this.onOpen,
    required this.onTransfer,
    required this.onEdit,
    required this.onToggleStatus,
  });
  final FinancialLocation account;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback? onTransfer;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: FinanceSpace.lg,
      vertical: FinanceSpace.md,
    ),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: FinanceColors.tableHead)),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          flex: 16,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    account.name,
                    style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${account.financialAccountCode} — ${account.financialAccountNameAr ?? ''}',
                    style: FinanceText.small,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 9,
          child: Text(
            subtitle,
            style: FinanceText.small,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 9,
          child: FinanceAmount(value: account.balance),
        ),
        Expanded(
          flex: 7,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '↓${account.todayIncoming}',
              style: FinanceText.small.copyWith(color: FinanceColors.success),
            ),
          ),
        ),
        Expanded(
          flex: 7,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '↑${account.todayOutgoing}',
              style: FinanceText.small.copyWith(color: FinanceColors.danger),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onToggleStatus,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _ActiveBadge(active: account.isActive),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 10,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            children: <Widget>[
              _RowAction(label: 'عرض الحركات', onTap: onOpen),
              _RowAction(
                label: 'تحويل',
                onTap: onTransfer,
                muted: onTransfer == null,
              ),
              _RowAction(label: 'تعديل', onTap: onEdit, muted: true),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RowAction extends StatelessWidget {
  const _RowAction({required this.label, required this.onTap, this.muted = false});
  final String label;
  final VoidCallback? onTap;
  final bool muted;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap == null
        ? SystemMouseCursors.forbidden
        : SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: FinanceText.small.copyWith(
          fontWeight: FontWeight.w700,
          color: onTap == null
              ? FinanceColors.disabled
              : muted
              ? FinanceColors.muted
              : FinanceColors.brown,
        ),
      ),
    ),
  );
}

/// Account active/inactive is not a workflow status — `FinanceStatusBadge`'s
/// `active` case maps to "مكتمل" (completed), which is the wrong label here.
/// This renders Claude's exact "نشط" / "غير مفعّل" pair instead.
class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: active ? FinanceColors.successBg : const Color(0xffF0EDED),
      borderRadius: BorderRadius.circular(FinanceRadius.pill),
    ),
    child: Text(
      active ? 'نشط' : 'غير مفعّل',
      style: FinanceText.small.copyWith(
        color: active ? FinanceColors.success : FinanceColors.muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _RecentMovements extends StatelessWidget {
  const _RecentMovements({required this.rows, required this.onOpen});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('أحدث حركات النقدية والبنوك', style: FinanceText.page),
        const SizedBox(height: FinanceSpace.md),
        if (rows.isEmpty)
          const FinanceEmptyState(
            message: 'لا توجد حركات نقدية أو بنكية للفترة المحددة',
          )
        else
          FinanceTable(
            headers: const <String>['التاريخ', 'النوع', 'المرجع', 'الوصف', 'المبلغ', 'الحالة'],
            minWidth: 980,
            onRowTap: (int index) => onOpen(_int(rows[index]['id'])),
            rows: rows.map((Map<String, dynamic> row) {
              final Map<String, dynamic> source = _map(row['source']);
              final Map<String, dynamic> journal = _map(row['journal']);
              final Map<String, dynamic> cashEffect = _map(row['cashEffect']);
              final String direction = '${cashEffect['direction'] ?? ''}';
              final String amount = '${cashEffect['amount'] ?? _map(row['displayAmount'])['amount'] ?? '0.00'}';
              final Color amountColor = direction == 'outflow'
                  ? FinanceColors.danger
                  : direction == 'inflow'
                  ? FinanceColors.success
                  : FinanceColors.ink;
              return <Widget>[
                Text('${row['transactionDate'] ?? '—'}', style: FinanceText.small),
                FinanceTransactionTypeBadge(
                  normalizedType: source['normalizedType'] as String?,
                ),
                FinanceReference(reference: '${row['reference'] ?? '—'}'),
                Text('${row['description'] ?? '—'}', style: FinanceText.body),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${direction == 'outflow' ? '-' : ''}$amount',
                    style: FinanceText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                ),
                FinanceStatusBadge(status: '${journal['status'] ?? 'draft'}'),
              ];
            }).toList(),
          ),
      ],
    ),
  );
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({
    required this.current,
    required this.ledgerAccounts,
    required this.branches,
    required this.onSubmit,
  });
  final FinancialLocation? current;
  final List<FinancialAccount> ledgerAccounts;
  final List<Branch> branches;
  final Future<void> Function(String kind, Map<String, dynamic> payload) onSubmit;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _bankName;
  late final TextEditingController _reference;
  late String _kind;
  late String _type;
  int? _accountId;
  int? _branchId;
  late bool _active;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final FinancialLocation? current = widget.current;
    _code = TextEditingController(text: current?.code);
    _name = TextEditingController(text: current?.name);
    _bankName = TextEditingController(text: current?.bankName);
    _reference = TextEditingController(text: current?.maskedReference);
    _kind = current?.kind ?? 'cash';
    _type = current?.type ?? 'cash_drawer';
    _accountId = current?.financialAccountId ??
        (widget.ledgerAccounts.isEmpty ? null : widget.ledgerAccounts.first.id);
    _branchId = current?.branchId;
    _active = current?.isActive ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _bankName.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        _accountId == null ||
        (_kind == 'bank' && _bankName.text.trim().isEmpty)) {
      setState(() => _error = 'أكمل الحقول المطلوبة.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_kind, <String, dynamic>{
        'code': _code.text.trim(),
        'name': _name.text.trim(),
        'type': _type,
        'branchId': _branchId,
        'financialAccountId': _accountId,
        'bankName': _kind == 'bank' ? _bankName.text.trim() : null,
        'maskedReference': _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        'isActive': _active,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.current != null;
    return FinanceDialogShell(
      title: isEdit ? 'تعديل الحساب' : 'حساب جديد',
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: FinanceColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('حفظ'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!isEdit)
              _FormDropdown<String>(
                label: 'نوع الحساب',
                value: _kind,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'cash', child: Text('نقدي')),
                  DropdownMenuItem<String>(value: 'bank', child: Text('بنكي')),
                ],
                onChanged: (String? v) => setState(() {
                  _kind = v!;
                  _type = _kind == 'cash' ? 'cash_drawer' : 'bank';
                }),
              ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'الرمز'),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: FinanceSpace.md),
            _FormDropdown<String>(
              label: 'التصنيف',
              value: _type,
              items: (_kind == 'cash'
                      ? const <String>['cash_drawer', 'main_safe', 'petty_cash']
                      : const <String>['bank'])
                  .map(
                    (String v) => DropdownMenuItem<String>(value: v, child: Text(v)),
                  )
                  .toList(),
              onChanged: (String? v) => setState(() => _type = v!),
            ),
            const SizedBox(height: FinanceSpace.md),
            _FormDropdown<int>(
              label: 'حساب الأستاذ',
              value: _accountId,
              items: widget.ledgerAccounts
                  .map(
                    (FinancialAccount a) => DropdownMenuItem<int>(
                      value: a.id,
                      child: Text('${a.code} — ${a.nameAr}'),
                    ),
                  )
                  .toList(),
              onChanged: (int? v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: FinanceSpace.md),
            _FormDropdown<int?>(
              label: 'الفرع',
              value: _branchId,
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(value: null, child: Text('عام')),
                ...widget.branches.map(
                  (Branch b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                ),
              ],
              onChanged: (int? v) => setState(() => _branchId = v),
            ),
            if (_kind == 'bank') ...<Widget>[
              const SizedBox(height: FinanceSpace.md),
              TextField(
                controller: _bankName,
                decoration: const InputDecoration(labelText: 'اسم البنك'),
              ),
            ],
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(labelText: 'مرجع/رقم مخفي (اختياري)'),
            ),
            const SizedBox(height: FinanceSpace.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              title: const Text('الحساب نشط'),
              onChanged: (bool v) => setState(() => _active = v),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: FinanceSpace.sm),
              Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormDropdown<T> extends StatelessWidget {
  const _FormDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: items,
    onChanged: onChanged,
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({
    required this.accounts,
    required this.preselectedSourceId,
    required this.onSubmit,
  });
  final List<FinancialLocation> accounts;
  final int? preselectedSourceId;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late int? _fromId;
  late int? _toId;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fromId = widget.preselectedSourceId ?? widget.accounts.first.id;
    _toId = widget.accounts
        .firstWhere(
          (FinancialLocation a) => a.id != _fromId,
          orElse: () => widget.accounts.first,
        )
        .id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  FinancialLocation? _find(int? id) => id == null
      ? null
      : widget.accounts.where((FinancialLocation a) => a.id == id).firstOrNull;

  bool _isPositiveMoney(String value) {
    final RegExpMatch? match = RegExp(
      r'^(\d+)(?:\.(\d{1,2}))?$',
    ).firstMatch(value.trim());
    if (match == null) return false;
    return int.parse(match.group(1)!) * 100 +
            int.parse((match.group(2) ?? '').padRight(2, '0')) >
        0;
  }

  Future<void> _submit() async {
    if (_fromId == null || _toId == null || _fromId == _toId) {
      setState(() => _error = 'اختر حسابي مصدر ووجهة مختلفين.');
      return;
    }
    if (!_isPositiveMoney(_amount.text)) {
      setState(() => _error = 'أدخل مبلغاً موجباً صحيحاً.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(<String, dynamic>{
        'fromFinancialLocationId': _fromId,
        'toFinancialLocationId': _toId,
        'amount': _amount.text.trim(),
        'transferDate': DateTime.now().toIso8601String().substring(0, 10),
        'description': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'idempotencyKey':
            'cash-transfer-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FinancialLocation? from = _find(_fromId);
    final FinancialLocation? to = _find(_toId);
    return FinanceDialogShell(
      title: 'تحويل بين الحسابات',
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: FinanceColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('ترحيل التحويل'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _FormDropdown<int?>(
              label: 'من حساب',
              value: _fromId,
              items: widget.accounts
                  .map(
                    (FinancialLocation a) =>
                        DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (int? v) => setState(() => _fromId = v),
            ),
            const SizedBox(height: FinanceSpace.md),
            _FormDropdown<int?>(
              label: 'إلى حساب',
              value: _toId,
              items: widget.accounts
                  .map(
                    (FinancialLocation a) =>
                        DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (int? v) => setState(() => _toId = v),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: FinanceSpace.md),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
            if (from != null && to != null && from.id != to.id) ...<Widget>[
              const SizedBox(height: FinanceSpace.lg),
              FinanceAccountImpactPreview(
                fromLabel: from.name,
                toLabel: to.name,
                amount: _isPositiveMoney(_amount.text) ? _amount.text.trim() : '0.00',
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: FinanceSpace.sm),
              Text(_error!, style: const TextStyle(color: FinanceColors.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountDetailDialog extends StatefulWidget {
  const _AccountDetailDialog({
    required this.item,
    required this.loader,
    required this.onTransfer,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onOpenJournal,
  });
  final FinancialLocation item;
  final Future<FinancialLocationTransactions> Function() loader;
  final VoidCallback onTransfer;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final ValueChanged<int> onOpenJournal;

  @override
  State<_AccountDetailDialog> createState() => _AccountDetailDialogState();
}

class _AccountDetailDialogState extends State<_AccountDetailDialog> {
  late Future<FinancialLocationTransactions> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _retry() => setState(() {
    _future = widget.loader();
  });

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
      child: Padding(
        padding: const EdgeInsets.all(FinanceSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${widget.item.code} — ${widget.item.name}',
                    style: FinanceText.page,
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: FinanceSpace.md),
            Flexible(
              child: SingleChildScrollView(
                child: FutureBuilder<FinancialLocationTransactions>(
                  future: _future,
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<FinancialLocationTransactions> snapshot,
                      ) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const SizedBox(
                            height: 220,
                            child: FinanceLoadingState(
                              label: 'جارٍ تحميل تفاصيل الحساب…',
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return FinanceErrorState(
                            message: 'تعذّر تحميل تفاصيل الحساب.',
                            onRetry: _retry,
                          );
                        }
                        final FinancialLocation detail =
                            snapshot.data!.location;
                        final List<Map<String, dynamic>> movements =
                            snapshot.data!.transactions;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            FinanceEntityHeader(
                              title: detail.name,
                              reference:
                                  '${detail.financialAccountCode} — ${detail.financialAccountNameAr ?? ''}',
                              actions: <Widget>[
                                _ActiveBadge(active: detail.isActive),
                                const SizedBox(width: FinanceSpace.sm),
                                OutlinedButton(
                                  onPressed: widget.onTransfer,
                                  child: const Text('تحويل'),
                                ),
                              ],
                            ),
                            const SizedBox(height: FinanceSpace.md),
                            FinanceKpiGrid(
                              items: <FinanceKpiData>[
                                FinanceKpiData(
                                  label: 'الرصيد الحالي',
                                  value: _money(detail.balance),
                                ),
                                FinanceKpiData(
                                  label: 'الداخل اليوم',
                                  value: _money(detail.todayIncoming),
                                  tone: FinanceTone.success,
                                ),
                                FinanceKpiData(
                                  label: 'الخارج اليوم',
                                  value: _money(detail.todayOutgoing),
                                  tone: FinanceTone.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: FinanceSpace.md),
                            Wrap(
                              spacing: FinanceSpace.sm,
                              children: <Widget>[
                                OutlinedButton(
                                  onPressed: widget.onEdit,
                                  child: const Text('تعديل'),
                                ),
                                OutlinedButton(
                                  onPressed: widget.onToggleStatus,
                                  child: Text(
                                    detail.isActive ? 'تعطيل' : 'تفعيل',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: FinanceSpace.lg),
                            const Text('الحركات', style: FinanceText.label),
                            const SizedBox(height: FinanceSpace.sm),
                            if (movements.isEmpty)
                              const FinanceEmptyState(
                                message:
                                    'لا توجد حركات لهذا الحساب خلال الفترة المحددة',
                              )
                            else
                              FinanceTable(
                                headers: const <String>[
                                  'التاريخ',
                                  'المرجع',
                                  'النوع',
                                  'الوصف',
                                  'المبلغ',
                                  'الرصيد',
                                ],
                                minWidth: 760,
                                onRowTap: (int index) => widget.onOpenJournal(
                                  _int(movements[index]['journalEntryId']),
                                ),
                                rows: movements.map((Map<String, dynamic> row) {
                                  final bool isDebit = _amount(row['debit']) > 0;
                                  final String amount = isDebit
                                      ? '${row['debit']}'
                                      : '-${row['credit']}';
                                  return <Widget>[
                                    Text(
                                      '${row['date'] ?? '—'}',
                                      style: FinanceText.small,
                                    ),
                                    FinanceReference(
                                      reference: '${row['entryNumber'] ?? '—'}',
                                    ),
                                    FinanceTransactionTypeBadge(
                                      normalizedType: row['sourceType'] as String?,
                                    ),
                                    Text(
                                      '${row['description'] ?? '—'}',
                                      style: FinanceText.body,
                                    ),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        amount,
                                        style: FinanceText.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDebit
                                              ? FinanceColors.success
                                              : FinanceColors.danger,
                                        ),
                                      ),
                                    ),
                                    FinanceAmount(
                                      value: '${row['runningBalance'] ?? '0.00'}',
                                    ),
                                  ];
                                }).toList(),
                              ),
                          ],
                        );
                      },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

double _amount(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
String _money(dynamic value) => CurrencyFormatter.format(_amount(value));
int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
