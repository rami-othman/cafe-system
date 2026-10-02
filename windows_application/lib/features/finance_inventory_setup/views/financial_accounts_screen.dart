import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_components.dart';
import '../widgets/finance_pagination.dart';
import '../widgets/finance_transaction_type.dart';

class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({super.key, this.accountId});
  final int? accountId;
  @override
  State<FinancialAccountsScreen> createState() => _AccountsState();
}

class _AccountsState extends State<FinancialAccountsScreen> {
  String _search = '';
  String? _group;
  String? _status;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expanded = <int>{};
  bool _initialTreeExpanded = false;
  late Future<FinancialAccount>? _detailFuture;
  late Future<List<FinancialAccount>>? _catalogFuture;
  Future<FinancePage<Map<String, dynamic>>>? _movementsFuture;
  List<FinancialAccount>? _indexedAccounts;
  ArabicSearchIndex<FinancialAccount>? _searchIndex;

  @override
  void initState() {
    super.initState();
    if (widget.accountId == null) {
      _catalogFuture = context
          .read<FinanceSetupCubit>()
          .repository
          .getAccountCatalog();
    } else {
      final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
      _detailFuture = cubit.repository.getAccount(widget.accountId!);
      _catalogFuture = cubit.repository.getAccountCatalog();
      _movementsFuture = cubit.repository.getAccountMovements(
        widget.accountId!,
      );
      Future<void>.microtask(cubit.loadAccounts);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() => setState(() {
    _catalogFuture = context
        .read<FinanceSetupCubit>()
        .repository
        .getAccountCatalog();
  });

  /// Smart search over code, Arabic/English name and the parent path (so
  /// «موردين ارت» works). Built once per loaded catalog, not per keystroke.
  ArabicSearchIndex<FinancialAccount> _searchIndexFor(
    List<FinancialAccount> all,
  ) {
    if (_searchIndex == null || !identical(_indexedAccounts, all)) {
      final byId = <int, FinancialAccount>{for (final a in all) a.id: a};
      _searchIndex = ArabicSearchIndex<FinancialAccount>(
        all,
        (a) => <String>[
          a.code,
          a.nameAr,
          a.nameEn,
          _accountPath(a, byId, includeSelf: false),
        ],
      );
      _indexedAccounts = all;
    }
    return _searchIndex!;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _group = null;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) => widget.accountId == null
      ? FutureBuilder<List<FinancialAccount>>(
          future: _catalogFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return ManagementMessage(
                  message: 'تعذر تحميل دليل الحسابات: ${snapshot.error}',
                  error: true,
                  onRetry: _load,
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            final allAccounts = snapshot.data!;
            if (!_initialTreeExpanded) {
              _expanded.addAll(
                allAccounts
                    .where((a) => a.parentAccountId == null)
                    .map((a) => a.id),
              );
              _initialTreeExpanded = true;
            }
            final accounts = _searchIndexFor(allAccounts).search(
              _search,
              where: (a) =>
                  (_group == null || a.accountGroup == _group) &&
                  (_status == null || a.isActive == (_status == 'active')),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FinancePageHeader(
                  title: 'دليل الحسابات',
                  subtitle: 'شجرة حسابات PHINIX · ${allAccounts.length} حسابًا',
                  actions: <Widget>[
                    AppButton(
                      label: 'ربط الحسابات',
                      icon: Icons.link,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go(AppRoutes.financeAccountMappings),
                    ),
                    AppButton(
                      label: 'إضافة حساب',
                      icon: Icons.add,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _form(allAccounts),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: constraints.maxWidth < 650
                            ? constraints.maxWidth
                            : 340,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _search = value),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.secondary,
                            ),
                            suffixIcon: _search.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'مسح البحث',
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _search = '');
                                    },
                                  ),
                            hintText: 'ابحث بالاسم أو الرمز',
                          ),
                        ),
                      ),
                      _filter(
                        _group,
                        'كل المجموعات',
                        const <String?>[
                          null,
                          'assets',
                          'liabilities',
                          'equity',
                          'revenue',
                          'cost_of_sales',
                          'expenses',
                        ],
                        _groupLabel,
                        (value) {
                          setState(() => _group = value);
                        },
                      ),
                      _filter(
                        _status,
                        'كل الحالات',
                        const <String?>[null, 'active', 'inactive'],
                        (value) => value == 'active' ? 'نشط' : 'غير نشط',
                        (value) {
                          setState(() => _status = value);
                        },
                      ),
                      if (_search.isNotEmpty ||
                          _group != null ||
                          _status != null)
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('مسح التصفية'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          if (_expanded.isEmpty) {
                            _expanded.addAll(
                              allAccounts
                                  .where((a) => a.parentAccountId == null)
                                  .map((a) => a.id),
                            );
                          } else {
                            _expanded.clear();
                          }
                        }),
                        icon: Icon(
                          _expanded.isEmpty
                              ? Icons.unfold_more
                              : Icons.unfold_less,
                          size: 18,
                        ),
                        label: Text(
                          _expanded.isEmpty ? 'توسيع الأقسام' : 'طيّ الكل',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(child: _content(accounts, allAccounts)),
              ],
            );
          },
        )
      : _accountDetail();

  Widget _accountDetail() => FutureBuilder<FinancialAccount>(
    future: _detailFuture,
    builder: (BuildContext context, AsyncSnapshot<FinancialAccount> snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return ManagementMessage(
          message: snapshot.error.toString(),
          error: true,
          onRetry: _reloadDetail,
        );
      }
      final account = snapshot.data!;
      return FutureBuilder<List<FinancialAccount>>(
        future: _catalogFuture,
        builder: (context, catalogSnapshot) => _detailLayout(
          account,
          catalogSnapshot.data ?? const <FinancialAccount>[],
        ),
      );
    },
  );

  Widget _detailLayout(
    FinancialAccount account,
    List<FinancialAccount> catalog,
  ) {
    final byId = {for (final a in catalog) a.id: a};
    final children = catalog
        .where((a) => a.parentAccountId == account.id)
        .toList();
    final path = _accountPath(account, byId);
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final left = Column(
            children: <Widget>[
              _balanceCard(account),
              const SizedBox(height: 16),
              _referenceCard(
                'بيانات الحساب',
                Wrap(
                  spacing: 24,
                  runSpacing: 18,
                  children: <Widget>[
                    _detailValue('رمز الحساب', account.code),
                    _detailValue('الاسم العربي', account.nameAr),
                    _detailValue('الاسم الإنجليزي', account.nameEn),
                    _detailValue('المجموعة', _groupLabel(account.accountGroup)),
                    _detailValue(
                      'طبيعة الرصيد',
                      account.normalBalance == 'debit' ? 'مدين' : 'دائن',
                    ),
                    _detailValue(
                      'الحساب الأب',
                      account.parentCode == null
                          ? '—'
                          : '${account.parentCode} — ${account.parentNameAr ?? ''}',
                    ),
                    _detailValue(
                      'نوع الحساب',
                      account.isContra ? 'حساب معاكس' : 'عادي',
                    ),
                    _detailValue(
                      'الحماية',
                      account.isSystemProtected ? 'حساب نظام محمي' : 'غير محمي',
                    ),
                  ],
                ),
              ),
            ],
          );
          final right = Column(
            children: <Widget>[
              _referenceCard(
                'موضعه في الشجرة',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      path.isEmpty ? account.nameAr : path,
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                    if (catalog.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'تعذر عرض مسار الشجرة حاليًا.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _referenceCard(
                'الحسابات الفرعية (${children.length})',
                children.isEmpty
                    ? const Text(
                        'لا توجد حسابات فرعية.',
                        style: TextStyle(color: AppColors.textMuted),
                      )
                    : Column(
                        children: children
                            .take(12)
                            .map(
                              (child) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.account_tree_outlined,
                                  size: 18,
                                  color: AppColors.secondary,
                                ),
                                title: Text(
                                  child.nameAr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(child.code),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () => context.go(
                                  AppRoutes.financeAccountDetailPath(child.id),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.financeAccountsCanonical),
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('دليل الحسابات'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _AccountPill(
                    account.code,
                    AppColors.contentBackground,
                    AppColors.secondary,
                  ),
                  Text(
                    account.nameAr,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _AccountPill(
                    account.isActive ? 'نشط' : 'غير نشط',
                    account.isActive
                        ? AppColors.customerVipBadge
                        : AppColors.discountExpiredBadge,
                    account.isActive
                        ? AppColors.customerVipText
                        : AppColors.textMuted,
                  ),
                ],
              ),
              if (account.nameEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    account.nameEn,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: <Widget>[
                  AppButton(
                    label: 'عرض دفتر الأستاذ',
                    icon: Icons.menu_book_outlined,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.go(
                      '${AppRoutes.financeReportsCanonical}?type=general-ledger&accountId=${account.id}',
                    ),
                  ),
                  AppButton(
                    label: 'إضافة حساب فرعي',
                    icon: Icons.add,
                    variant: AppButtonVariant.outlined,
                    onPressed: account.isActive
                        ? () => _form(catalog, null, account)
                        : null,
                  ),
                  if (!account.isSystemProtected)
                    AppButton(
                      label: 'تعديل الحساب',
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _form(catalog, account),
                    ),
                  if (!account.isSystemProtected || !account.isActive)
                    AppButton(
                      label: account.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                      icon: account.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => _changeStatus(account),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 6, child: left),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: right),
                  ],
                )
              else
                Column(
                  children: <Widget>[left, const SizedBox(height: 16), right],
                ),
              const SizedBox(height: 16),
              _accountMovements(),
            ],
          );
        },
      ),
    );
  }

  Widget
  _accountMovements() => FutureBuilder<FinancePage<Map<String, dynamic>>>(
    future: _movementsFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return _referenceCard(
          'الحركات المالية',
          const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return _referenceCard(
          'الحركات المالية',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'تعذر تحميل حركات الحساب.',
                style: TextStyle(color: AppColors.danger),
              ),
              TextButton.icon(
                onPressed: () => _showMovementPage(1),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        );
      }
      final page = snapshot.data!;
      if (page.items.isEmpty) {
        return _referenceCard(
          'الحركات المالية',
          const Text(
            'لا توجد قيود مرحّلة لهذا الحساب.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }
      String amount(dynamic value) => CurrencyFormatter.formatForContext(
        context,
        double.tryParse('$value') ?? 0,
      );
      return _referenceCard(
        'الحركات المالية (${page.meta.total})',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'جميع القيود المرحّلة على هذا الحساب، مرتبة من الأقدم إلى الأحدث.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF4E7D3),
                ),
                showCheckboxColumn: false,
                columns: const <DataColumn>[
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('القيد')),
                  DataColumn(label: Text('النوع')),
                  DataColumn(label: Text('الوصف')),
                  DataColumn(label: Text('مدين')),
                  DataColumn(label: Text('دائن')),
                  DataColumn(label: Text('الرصيد')),
                ],
                rows: page.items
                    .map(
                      (row) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text('${row['date'] ?? '—'}')),
                          DataCell(
                            TextButton(
                              onPressed: () => context.go(
                                AppRoutes.financeJournalEntryDetailPath(
                                  (row['journalEntryId'] as num).toInt(),
                                ),
                              ),
                              child: Text('${row['entryNumber'] ?? '—'}'),
                            ),
                          ),
                          DataCell(
                            FinanceTransactionTypeBadge(
                              normalizedType: row['sourceType']?.toString(),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Text(
                                '${row['description'] ?? '—'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(amount(row['debit']))),
                          DataCell(Text(amount(row['credit']))),
                          DataCell(Text(amount(row['runningBalance']))),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            FinancePagination(
              meta: page.meta,
              onPageChanged: _showMovementPage,
            ),
          ],
        ),
      );
    },
  );

  Widget _referenceCard(String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _balanceCard(FinancialAccount account) {
    final double balance = double.tryParse(account.balance) ?? 0;
    final bool isReversed =
        (account.normalBalance == 'debit' && balance < 0) ||
        (account.normalBalance == 'credit' && balance < 0);
    // A customer's own account doubles as their wallet: money they hold with us
    // is positive, so a debit balance (they owe us) is shown negative and red.
    final bool isCustomerAccount =
        account.normalBalance == 'debit' &&
        (account.parentCode == '121' || account.parentCode == '1200');
    final double shownBalance = isCustomerAccount ? -balance : balance;
    // Customer account: credit (they hold money with us) green, debit (they owe) red.
    final Color balanceColor = isCustomerAccount
        ? (shownBalance > 0
              ? Colors.green.shade700
              : shownBalance < 0
              ? Colors.red.shade700
              : Theme.of(context).colorScheme.primary)
        : isReversed
        ? Colors.red.shade700
        : Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'الرصيد الحالي',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _AccountPill(
                account.normalBalance == 'debit' ? 'رصيد مدين' : 'رصيد دائن',
                const Color(0xFFFFF8F1),
                AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                CurrencyFormatter.formatForContext(context, shownBalance),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: balanceColor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // The balance is signed against the account's normal side, so the
              // real side (debit = owed to us for a customer) is spelled out.
              Text(
                (account.normalBalance == 'debit') == (balance >= 0)
                    ? 'مدين'
                    : 'دائن',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: balanceColor,
                ),
              ),
            ],
          ),
          const Text(
            'من القيود المالية المسجلة',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const Divider(height: 24),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _detailValue(
                'إجمالي المدين',
                CurrencyFormatter.formatForContext(
                  context,
                  double.tryParse(account.totalDebit) ?? 0,
                ),
              ),
              _detailValue(
                'إجمالي الدائن',
                CurrencyFormatter.formatForContext(
                  context,
                  double.tryParse(account.totalCredit) ?? 0,
                ),
              ),
              _detailValue('آخر حركة', account.lastMovementDate ?? '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailValue(String label, String value) => SizedBox(
    width: 170,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(value),
      ],
    ),
  );

  void _reloadDetail() => setState(() {
    _detailFuture = context.read<FinanceSetupCubit>().repository.getAccount(
      widget.accountId!,
    );
    _movementsFuture = context
        .read<FinanceSetupCubit>()
        .repository
        .getAccountMovements(widget.accountId!);
  });

  void _showMovementPage(int page) => setState(() {
    _movementsFuture = context
        .read<FinanceSetupCubit>()
        .repository
        .getAccountMovements(widget.accountId!, page: page);
  });

  Widget _content(
    List<FinancialAccount> accounts,
    List<FinancialAccount> allAccounts,
  ) {
    final filtering =
        _search.trim().isNotEmpty || _group != null || _status != null;
    final hierarchy = filtering
        ? accounts.map((a) => _AccountTreeItem(a, 0, false)).toList()
        : _hierarchy(accounts, _expanded);
    final active = accounts.where((a) => a.isActive).length;
    final byId = {for (final a in allAccounts) a.id: a};
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) => Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: const Color(0xFFF4E7D3),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'الحساب',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (constraints.maxWidth > 850) ...const <Widget>[
                    SizedBox(
                      width: 150,
                      child: Text(
                        'المجموعة',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        'طبيعة الرصيد',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (constraints.maxWidth > 620)
                    const SizedBox(
                      width: 110,
                      child: Text(
                        'الحالة',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: accounts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFFF4E7D3),
                          child: Icon(
                            Icons.search_off_outlined,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد حسابات مطابقة',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'جرّب رمزًا أو اسمًا آخر، أو خفّف عوامل التصفية.',
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('مسح البحث والتصفية'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: hierarchy.length,
                    itemBuilder: (context, index) => _treeRow(
                      hierarchy[index],
                      allAccounts,
                      byId,
                      filtering,
                    ),
                  ),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.contentBackground,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  '${accounts.length} حساب · $active نشط',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  filtering ? 'نتائج البحث والتصفية' : 'شجرة الحسابات',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeRow(
    _AccountTreeItem item,
    List<FinancialAccount> allAccounts,
    Map<int, FinancialAccount> byId,
    bool filtering,
  ) {
    final a = item.account;
    final isRoot = item.depth == 0;
    final path = _accountPath(a, byId, includeSelf: false);
    return LayoutBuilder(
      builder: (context, constraints) => InkWell(
        // A parent row only expands/collapses (a near-miss on the arrow no longer
        // opens the card); the explicit open button below enters the account.
        onTap: item.hasChildren
            ? () => setState(() {
                _expanded.contains(a.id)
                    ? _expanded.remove(a.id)
                    : _expanded.add(a.id);
              })
            : () => context.go(AppRoutes.financeAccountDetailPath(a.id)),
        child: Container(
          decoration: BoxDecoration(
            color: isRoot && !filtering ? const Color(0xFFFCF9F8) : null,
            border: const Border(bottom: BorderSide(color: Color(0xFFEFEAE2))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              SizedBox(width: filtering ? 0 : item.depth * 24.0),
              SizedBox(
                width: 28,
                child: item.hasChildren
                    ? IconButton(
                        tooltip: _expanded.contains(a.id)
                            ? 'طي الحسابات الفرعية'
                            : 'توسيع الحسابات الفرعية',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: Icon(
                          _expanded.contains(a.id)
                              ? Icons.expand_more
                              : Icons.chevron_left,
                        ),
                        onPressed: () => setState(() {
                          _expanded.contains(a.id)
                              ? _expanded.remove(a.id)
                              : _expanded.add(a.id);
                        }),
                      )
                    : const Icon(
                        Icons.circle,
                        size: 5,
                        color: AppColors.dashedBorder,
                      ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 84,
                child: Text(
                  a.code,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            a.nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isRoot && !filtering
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (a.isSystemProtected)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(start: 6),
                            child: Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    if (filtering && path.isNotEmpty)
                      Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (constraints.maxWidth > 850) ...<Widget>[
                SizedBox(
                  width: 150,
                  child: Text(
                    _groupLabel(a.accountGroup),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Row(
                    children: <Widget>[
                      Text(
                        a.normalBalance == 'debit' ? 'مدين' : 'دائن',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (a.isContra)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(start: 5),
                          child: _AccountPill(
                            'معاكس',
                            Color(0xFFFFF8F1),
                            AppColors.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (constraints.maxWidth > 620)
                SizedBox(
                  width: 110,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _AccountPill(
                      a.isActive ? 'نشط' : 'غير نشط',
                      a.isActive
                          ? AppColors.customerVipBadge
                          : AppColors.discountExpiredBadge,
                      a.isActive
                          ? AppColors.customerVipText
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'فتح الحساب',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                  onPressed: () =>
                      context.go(AppRoutes.financeAccountDetailPath(a.id)),
                ),
              ),
              SizedBox(
                width: 48,
                child: PopupMenuButton<String>(
                  tooltip: 'خيارات الحساب',
                  onSelected: (action) {
                    if (action == 'detail') {
                      context.go(AppRoutes.financeAccountDetailPath(a.id));
                    } else if (action == 'ledger') {
                      context.go(
                        '${AppRoutes.financeReportsCanonical}?type=general-ledger&accountId=${a.id}',
                      );
                    } else if (action == 'child') {
                      _form(allAccounts, null, a);
                    } else if (action == 'edit') {
                      _form(allAccounts, a);
                    } else {
                      _changeStatus(a);
                    }
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                      value: 'detail',
                      child: Text('عرض التفاصيل'),
                    ),
                    const PopupMenuItem(
                      value: 'ledger',
                      child: Text('دفتر الأستاذ'),
                    ),
                    PopupMenuItem(
                      value: 'child',
                      enabled: a.isActive,
                      child: const Text('إضافة حساب فرعي'),
                    ),
                    if (!a.isSystemProtected)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('تعديل الحساب'),
                      ),
                    PopupMenuItem(
                      value: 'status',
                      enabled: !(a.isSystemProtected && a.isActive),
                      child: Text(a.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _accountPath(
    FinancialAccount account,
    Map<int, FinancialAccount> byId, {
    bool includeSelf = true,
  }) {
    final names = <String>[];
    final visited = <int>{};
    FinancialAccount? node = includeSelf
        ? account
        : byId[account.parentAccountId];
    while (node != null && visited.add(node.id)) {
      names.insert(0, node.nameAr);
      node = byId[node.parentAccountId];
    }
    return names.join(' ‹ ');
  }

  Widget _filter(
    String? value,
    String hint,
    List<String?> values,
    String Function(String?) label,
    ValueChanged<String?> onChanged,
  ) => SizedBox(
    width: 170,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      hint: Text(hint),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item == null ? hint : label(item)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
  String _groupLabel(String? value) => switch (value) {
    'assets' => 'الأصول',
    'liabilities' => 'الالتزامات',
    'equity' => 'حقوق الملكية',
    'revenue' => 'الإيرادات',
    'cost_of_sales' => 'تكلفة المبيعات',
    _ => 'المصروفات',
  };

  Future<void> _changeStatus(FinancialAccount account) async {
    if (account.isSystemProtected && account.isActive) return;
    if (account.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('تعطيل الحساب؟'),
          content: const Text(
            'لن يمكن استخدام الحساب المعطّل في القيود الجديدة.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'تعطيل',
              onPressed: () => Navigator.pop(dialog, true),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    final ok = await context.read<FinanceSetupCubit>().setAccountStatus(
      account.id,
      !account.isActive,
    );
    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<FinanceSetupCubit>().state.errorMessage ??
                'تعذر تحديث حالة الحساب.',
          ),
        ),
      );
    } else if (mounted && widget.accountId != null) {
      _reloadDetail();
    } else if (mounted) {
      _load();
    }
  }

  Future<int?> _selectParent(
    List<FinancialAccount> accounts,
    int? currentId,
    int? initialSelection,
  ) async {
    String query = '';
    int selected = initialSelection ?? -1;
    final byId = {for (final a in accounts) a.id: a};
    bool isOwnDescendant(FinancialAccount candidate) {
      if (currentId == null) return false;
      final seen = <int>{};
      FinancialAccount? node = candidate;
      while (node != null && seen.add(node.id)) {
        if (node.id == currentId) return true;
        node = byId[node.parentAccountId];
      }
      return false;
    }

    final pickerIndex = ArabicSearchIndex<FinancialAccount>(
      accounts,
      (a) => <String>[
        a.code,
        a.nameAr,
        a.nameEn,
        _accountPath(a, byId, includeSelf: false),
      ],
    );

    return showDialog<int>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setPicker) {
          final matches = pickerIndex
              .search(
                query,
                where: (a) => a.isActive && !isOwnDescendant(a),
              )
              .take(80)
              .toList(growable: false);
          final selectedAccount = byId[selected];
          return AlertDialog(
            title: const Text('اختيار الحساب الأب'),
            content: SizedBox(
              width: 680,
              height: 540,
              child: Column(
                children: <Widget>[
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setPicker(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث بالرمز أو الاسم',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    leading: const Icon(Icons.account_tree_outlined),
                    title: const Text('بدون حساب أب — حساب رئيسي'),
                    trailing: selected == -1
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.secondary,
                          )
                        : null,
                    onTap: () => setPicker(() => selected = -1),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final account = matches[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${account.code} — ${account.nameAr}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: selected == account.id,
                          selectedTileColor: const Color(0xFFFFF8F1),
                          leading: selected == account.id
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.secondary,
                                )
                              : const Icon(
                                  Icons.circle_outlined,
                                  color: AppColors.dashedBorder,
                                ),
                          subtitle: Text(
                            _accountPath(
                                  account,
                                  byId,
                                  includeSelf: false,
                                ).isEmpty
                                ? _groupLabel(account.accountGroup)
                                : _accountPath(
                                    account,
                                    byId,
                                    includeSelf: false,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => setPicker(() => selected = account.id),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        selectedAccount == null
                            ? 'سيُنشأ الحساب كحساب رئيسي'
                            : 'سيرث الحساب: ${_groupLabel(selectedAccount.accountGroup)} · ${selectedAccount.normalBalance == 'debit' ? 'مدين' : 'دائن'}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('إلغاء'),
              ),
              AppButton(
                label: 'اختيار هذا الحساب',
                onPressed: () => Navigator.pop(dialog, selected),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _form(
    List<FinancialAccount> accounts, [
    FinancialAccount? current,
    FinancialAccount? initialParent,
  ]) async {
    final cubit = context.read<FinanceSetupCubit>();
    List<FinancialAccount> accountOptions = accounts;
    if (accountOptions.isEmpty) {
      try {
        accountOptions = await cubit.repository.getAccountCatalog();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحميل الحسابات لاختيار الحساب الأب.'),
            ),
          );
        }
        return;
      }
    }
    accountOptions = accountOptions.toList(growable: true);
    if (current?.parentAccountId != null &&
        !accountOptions.any((a) => a.id == current!.parentAccountId)) {
      try {
        accountOptions.add(
          await cubit.repository.getAccount(current!.parentAccountId!),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل الحساب الأب.')),
          );
        }
        return;
      }
    }
    final code = TextEditingController(text: current?.code);
    final nameAr = TextEditingController(text: current?.nameAr);
    final nameEn = TextEditingController(text: current?.nameEn);
    var group =
        current?.accountGroup ?? initialParent?.accountGroup ?? 'expenses';
    var normal =
        current?.normalBalance ?? initialParent?.normalBalance ?? 'debit';
    var isContra = current?.isContra ?? false;
    var categoryOverride = current?.categoryOverride ?? false;
    int? parentId = current?.parentAccountId ?? initialParent?.id;
    var active = current?.isActive ?? true;
    String baseNormal(FinancialAccount parent) => categoryOverride
        ? (<String>['liabilities', 'equity', 'revenue'].contains(group)
              ? 'credit'
              : 'debit')
        : parent.normalBalance;
    String? error;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) {
          final parent = <FinancialAccount>[
            ...accountOptions,
            ?initialParent,
          ].where((account) => account.id == parentId).firstOrNull;
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(current == null ? 'إضافة حساب جديد' : 'تعديل الحساب'),
                const SizedBox(height: 3),
                const Text(
                  'بيانات الحساب وتصنيفه ضمن الشجرة المحاسبية',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(context).width > 1100
                  ? 980
                  : MediaQuery.sizeOf(context).width - 100,
              height: MediaQuery.sizeOf(context).height > 780
                  ? 620
                  : MediaQuery.sizeOf(context).height - 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 7,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'بيانات الحساب',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: code,
                            enabled: current?.isSystemProtected != true,
                            onChanged: (_) => setDialog(() {}),
                            decoration: InputDecoration(
                              labelText: current == null
                                  ? 'رمز الحساب (اختياري)'
                                  : 'رمز الحساب',
                              helperText: current == null
                                  ? 'اتركه فارغاً ليُولَّد تلقائياً — ويُستبدل تلقائياً إن كان مكرراً'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameAr,
                            onChanged: (_) => setDialog(() {}),
                            decoration: const InputDecoration(
                              labelText: 'الاسم العربي',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameEn,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الإنجليزي (اختياري)',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'التصنيف في الشجرة',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.contentBackground,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.account_tree_outlined,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Text(
                                        'الحساب الأب',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      Text(
                                        parent == null
                                            ? 'بدون حساب أب — حساب رئيسي'
                                            : '${parent.code} — ${parent.nameAr}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final selection = await _selectParent(
                                      accountOptions,
                                      current?.id,
                                      parentId,
                                    );
                                    if (selection == null || !dialog.mounted) {
                                      return;
                                    }
                                    setDialog(() {
                                      parentId = selection < 0
                                          ? null
                                          : selection;
                                      final selected = accountOptions
                                          .where((a) => a.id == parentId)
                                          .firstOrNull;
                                      if (selected != null) {
                                        group = selected.accountGroup;
                                        normal = selected.normalBalance;
                                      }
                                      isContra = false;
                                      categoryOverride = false;
                                    });
                                  },
                                  child: const Text('تغيير'),
                                ),
                              ],
                            ),
                          ),
                          if (parent != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Text(
                                'يرث الحساب الجديد المجموعة وطبيعة الرصيد من الأب تلقائيًا.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (parent != null && !categoryOverride)
                            _inheritedField('مجموعة الحساب', _groupLabel(group))
                          else
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'account-group-$group-$parentId-$categoryOverride',
                              ),
                              initialValue: group,
                              decoration: const InputDecoration(
                                labelText: 'مجموعة الحساب',
                              ),
                              items:
                                  const <String>[
                                        'assets',
                                        'liabilities',
                                        'equity',
                                        'revenue',
                                        'cost_of_sales',
                                        'expenses',
                                      ]
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(_groupStatic(v)),
                                        ),
                                      )
                                      .toList(),
                              onChanged: current?.isSystemProtected == true
                                  ? null
                                  : (value) => setDialog(() {
                                      group = value!;
                                      if (parent != null && categoryOverride) {
                                        normal = isContra
                                            ? (baseNormal(parent) == 'debit'
                                                  ? 'credit'
                                                  : 'debit')
                                            : baseNormal(parent);
                                      }
                                    }),
                            ),
                          const SizedBox(height: 12),
                          if (parent != null)
                            _inheritedField(
                              'طبيعة الرصيد',
                              normal == 'debit' ? 'مدين' : 'دائن',
                            )
                          else
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'normal-balance-$normal-$parentId-$isContra',
                              ),
                              initialValue: normal,
                              decoration: const InputDecoration(
                                labelText: 'الرصيد الطبيعي',
                              ),
                              items: const <String>['debit', 'credit']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v == 'debit' ? 'مدين' : 'دائن',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: current?.isSystemProtected == true
                                  ? null
                                  : (value) => setDialog(() => normal = value!),
                            ),
                          if (parent != null)
                            ExpansionTile(
                              title: const Text('خيارات محاسبية متقدمة'),
                              initiallyExpanded: isContra || categoryOverride,
                              children: <Widget>[
                                SwitchListTile(
                                  value: isContra,
                                  onChanged: current?.isSystemProtected == true
                                      ? null
                                      : (value) => setDialog(() {
                                          isContra = value;
                                          normal = value
                                              ? (baseNormal(parent) == 'debit'
                                                    ? 'credit'
                                                    : 'debit')
                                              : baseNormal(parent);
                                        }),
                                  title: const Text('حساب معاكس'),
                                  subtitle: const Text(
                                    'مثل مجمع الاهتلاك أو مردود المبيعات.',
                                  ),
                                ),
                                SwitchListTile(
                                  value: categoryOverride,
                                  onChanged: current?.isSystemProtected == true
                                      ? null
                                      : (value) => setDialog(() {
                                          categoryOverride = value;
                                          if (!value) {
                                            group = parent.accountGroup;
                                          }
                                          normal = isContra
                                              ? (baseNormal(parent) == 'debit'
                                                    ? 'credit'
                                                    : 'debit')
                                              : baseNormal(parent);
                                        }),
                                  title: const Text('استثناء تصنيف الأب'),
                                  subtitle: const Text(
                                    'فقط عند الحاجة لتصنيف مختلف عن الأب.',
                                  ),
                                ),
                              ],
                            ),
                          SwitchListTile(
                            value: active,
                            onChanged: current?.isSystemProtected == true
                                ? null
                                : (value) => setDialog(() => active = value),
                            title: const Text('الحساب نشط'),
                          ),
                          if (error != null)
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          if (MediaQuery.sizeOf(context).width <=
                              950) ...<Widget>[
                            const SizedBox(height: 16),
                            _accountPreview(
                              code.text.trim(),
                              nameAr.text.trim(),
                              parent,
                              group,
                              normal,
                              isContra,
                              active,
                              accountOptions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 950) ...<Widget>[
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 3,
                      child: _accountPreview(
                        code.text.trim(),
                        nameAr.text.trim(),
                        parent,
                        group,
                        normal,
                        isContra,
                        active,
                        accountOptions,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('إلغاء'),
              ),
              AppButton(
                label: current == null ? 'حفظ الحساب' : 'حفظ التعديل',
                icon: Icons.save_outlined,
                onPressed: () async {
                  if ((current != null && code.text.trim().isEmpty) ||
                      nameAr.text.trim().isEmpty) {
                    setDialog(() => error = 'الرمز والاسم العربي مطلوبان.');
                    return;
                  }
                  final ok = await cubit.saveAccount(<String, dynamic>{
                    'code': code.text.trim(),
                    'nameAr': nameAr.text.trim(),
                    'nameEn': nameEn.text.trim().isEmpty
                        ? nameAr.text.trim()
                        : nameEn.text.trim(),
                    'accountGroup': group,
                    'normalBalance': normal,
                    'isContra': isContra,
                    'categoryOverride': categoryOverride,
                    'parentAccountId': parentId,
                    'isActive': active,
                  }, id: current?.id);
                  if (ok && dialog.mounted) {
                    Navigator.pop(dialog);
                    if (widget.accountId != null) {
                      _reloadDetail();
                    } else {
                      _load();
                    }
                  } else if (dialog.mounted) {
                    setDialog(
                      () => error =
                          cubit.state.errorMessage ?? 'تعذر حفظ الحساب.',
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
    code.dispose();
    nameAr.dispose();
    nameEn.dispose();
  }

  Widget _accountPreview(
    String code,
    String name,
    FinancialAccount? parent,
    String group,
    String normal,
    bool isContra,
    bool active,
    List<FinancialAccount> accounts,
  ) {
    final byId = {for (final a in accounts) a.id: a};
    final parentPath = parent == null ? '' : _accountPath(parent, byId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.contentBackground,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'معاينة الحساب',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'الموضع في الشجرة',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 5),
          Text(
            parentPath.isEmpty ? 'حساب رئيسي' : parentPath,
            style: const TextStyle(color: AppColors.secondary),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.account_tree_outlined,
                  size: 20,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        code.isEmpty ? 'رمز الحساب' : code,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        name.isEmpty ? 'اسم الحساب' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _previewLine('المجموعة', _groupLabel(group)),
          _previewLine('طبيعة الرصيد', normal == 'debit' ? 'مدين' : 'دائن'),
          _previewLine('النوع', isContra ? 'حساب معاكس' : 'عادي'),
          _previewLine('الحالة', active ? 'نشط' : 'غير نشط'),
          const SizedBox(height: 12),
          const Text(
            'تُحدد الأرصدة من القيود المالية؛ لا يُدخل رصيد افتتاحي هنا.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _inheritedField(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFBF6EE),
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const _AccountPill('تلقائي', Color(0xFFF4E7D3), AppColors.secondary),
      ],
    ),
  );

  Widget _previewLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    ),
  );
}

class _AccountPill extends StatelessWidget {
  const _AccountPill(this.label, this.background, this.foreground);
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _AccountTreeItem {
  const _AccountTreeItem(this.account, this.depth, this.hasChildren);
  final FinancialAccount account;
  final int depth;
  final bool hasChildren;
}

List<_AccountTreeItem> _hierarchy(
  List<FinancialAccount> accounts,
  Set<int> expanded,
) {
  final Map<int?, List<FinancialAccount>> children =
      <int?, List<FinancialAccount>>{};
  final Set<int> accountIds = accounts
      .map((FinancialAccount account) => account.id)
      .toSet();
  for (final FinancialAccount account in accounts) {
    final int? parentId =
        account.parentAccountId != null &&
            accountIds.contains(account.parentAccountId)
        ? account.parentAccountId
        : null;
    children.putIfAbsent(parentId, () => <FinancialAccount>[]).add(account);
  }
  final List<_AccountTreeItem> output = <_AccountTreeItem>[];
  void visit(FinancialAccount account, int depth, Set<int> ancestry) {
    if (!ancestry.add(account.id)) return;
    final List<FinancialAccount> descendants =
        children[account.id] ?? const <FinancialAccount>[];
    output.add(_AccountTreeItem(account, depth, descendants.isNotEmpty));
    if (expanded.contains(account.id)) {
      for (final FinancialAccount child in descendants) {
        visit(child, depth + 1, Set<int>.from(ancestry));
      }
    }
  }

  for (final FinancialAccount root
      in children[null] ?? const <FinancialAccount>[]) {
    visit(root, 0, <int>{});
  }
  return output;
}

String _groupStatic(String group) => switch (group) {
  'assets' => 'الأصول',
  'liabilities' => 'الالتزامات',
  'equity' => 'حقوق الملكية',
  'revenue' => 'الإيرادات',
  'cost_of_sales' => 'تكلفة المبيعات',
  _ => 'المصروفات',
};
