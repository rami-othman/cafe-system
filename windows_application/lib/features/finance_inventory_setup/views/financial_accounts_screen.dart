import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../controllers/finance_setup_state.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_paginated_table.dart';

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
  String? _system;
  final Set<int> _expanded = <int>{};
  late Future<FinancialAccount>? _detailFuture;

  @override
  void initState() {
    super.initState();
    if (widget.accountId == null) {
      Future<void>.microtask(_load);
    } else {
      final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
      _detailFuture = cubit.repository.getAccount(widget.accountId!);
      Future<void>.microtask(cubit.loadAccounts);
    }
  }

  Future<void> _load() => context.read<FinanceSetupCubit>().loadAccounts(
    search: _search,
    group: _group,
    status: _status,
    system: _system,
  );

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: widget.accountId == null
        ? BlocBuilder<FinanceSetupCubit, FinanceSetupState>(
            builder: (context, state) {
              final accounts = state.accounts;
              final active = accounts.where((a) => a.isActive).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ManagementPageHeader(
                    title: 'دليل الحسابات',
                    subtitle:
                        'إدارة الحسابات الأساسية والهيكل المحاسبي ضمن نطاق المنشأة.',
                    actions: <Widget>[
                      AppButton(
                        label: 'إضافة حساب',
                        icon: Icons.add,
                        onPressed: () => _form(accounts),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: <Widget>[
                      ManagementKpiCard(
                        label: 'إجمالي الحسابات',
                        value: '${accounts.length}',
                        icon: Icons.account_tree_outlined,
                      ),
                      ManagementKpiCard(
                        label: 'الحسابات النشطة',
                        value: '$active',
                        icon: Icons.check_circle_outline,
                      ),
                      ManagementKpiCard(
                        label: 'غير النشطة',
                        value: '${accounts.length - active}',
                        icon: Icons.pause_circle_outline,
                      ),
                      ManagementKpiCard(
                        label: 'حسابات النظام',
                        value:
                            '${accounts.where((a) => a.isSystemProtected).length}',
                        icon: Icons.lock_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ManagementFilterBar(
                    children: <Widget>[
                      SizedBox(
                        width: 250,
                        child: TextField(
                          onChanged: (value) {
                            _search = value;
                            _load();
                          },
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'البحث بالاسم أو الرمز',
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
                          _load();
                        },
                      ),
                      _filter(
                        _status,
                        'كل الحالات',
                        const <String?>[null, 'active', 'inactive'],
                        (value) => value == 'active' ? 'نشط' : 'غير نشط',
                        (value) {
                          setState(() => _status = value);
                          _load();
                        },
                      ),
                      _filter(
                        _system,
                        'كل الحسابات',
                        const <String?>[null, 'system', 'non-system'],
                        (value) =>
                            value == 'system' ? 'حسابات النظام' : 'غير نظامية',
                        (value) {
                          setState(() => _system = value);
                          _load();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(child: _content(state, accounts)),
                ],
              );
            },
          )
        : _accountDetail(),
  );

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
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ManagementPageHeader(
              title: '${account.code} — ${account.nameAr}',
              subtitle: 'تفاصيل الحساب من دليل الحسابات.',
              actions: <Widget>[
                AppButton(
                  label: 'عرض دفتر الأستاذ',
                  icon: Icons.menu_book_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.go(
                    '${AppRoutes.financeReportsCanonical}?type=general-ledger&accountId=${account.id}',
                  ),
                ),
                if (!account.isSystemProtected)
                  AppButton(
                    label: 'تعديل',
                    icon: Icons.edit_outlined,
                    onPressed: () => _form(
                      context.read<FinanceSetupCubit>().state.accounts,
                      account,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            ManagementTableShell(
              minWidth: 0,
              child: Padding(
                padding: AppSpacing.allLg,
                child: Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.lg,
                  children: <Widget>[
                    _detailValue('الرمز', account.code),
                    _detailValue('الاسم العربي', account.nameAr),
                    _detailValue('الاسم الإنجليزي', account.nameEn),
                    _detailValue('المجموعة', _groupLabel(account.accountGroup)),
                    _detailValue(
                      'الرصيد الطبيعي',
                      account.normalBalance == 'debit' ? 'مدين' : 'دائن',
                    ),
                    _detailValue(
                      'الحساب الأب',
                      account.parentCode == null
                          ? '—'
                          : '${account.parentCode} — ${account.parentNameAr ?? ''}',
                    ),
                    _detailValue(
                      'الحالة',
                      account.isActive ? 'نشط' : 'غير نشط',
                    ),
                    _detailValue(
                      'حساب نظام',
                      account.isSystemProtected ? 'محمي' : 'غير محمي',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
      );
    },
  );

  Widget _detailValue(String label, String value) => SizedBox(
    width: 230,
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
  });

  Widget _content(FinanceSetupState state, List<FinancialAccount> accounts) {
    if (state.isLoading && accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && accounts.isEmpty) {
      return ManagementMessage(
        message: state.errorMessage!,
        error: true,
        onRetry: _load,
      );
    }
    if (accounts.isEmpty) {
      return const ManagementMessage(
        message:
            'لا توجد حسابات مطابقة. أكمِل إعداد المالية أو غيّر عوامل التصفية.',
      );
    }
    final hierarchy = _hierarchy(accounts, _expanded);
    return ManagementTableShell(
      minWidth: 1100,
      child: FinancePaginatedTable(
        minWidth: 1100,
        columns: const <DataColumn>[
          DataColumn(label: Text('الرمز')),
          DataColumn(label: Text('اسم الحساب')),
          DataColumn(label: Text('المجموعة')),
          DataColumn(label: Text('الرصيد الطبيعي')),
          DataColumn(label: Text('الحساب الأب')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('محمي')),
          DataColumn(label: Text('')),
        ],
        rows: hierarchy
            .map(
              (item) => _row(
                item.account,
                depth: item.depth,
                hasChildren: item.hasChildren,
              ),
            )
            .toList(),
      ),
    );
  }

  DataRow _row(
    FinancialAccount a, {
    int depth = 0,
    bool hasChildren = false,
  }) => DataRow(
    cells: <DataCell>[
      DataCell(
        Text(a.code),
        onTap: () => context.go('/finance/accounts/${a.id}'),
      ),
      DataCell(
        Padding(
          padding: EdgeInsetsDirectional.only(start: depth * 20.0),
          child: Row(
            children: <Widget>[
              if (hasChildren)
                IconButton(
                  tooltip: _expanded.contains(a.id)
                      ? 'طي الحسابات الفرعية'
                      : 'توسيع الحسابات الفرعية',
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _expanded.contains(a.id)
                        ? Icons.expand_more
                        : Icons.chevron_left,
                    size: 20,
                  ),
                  onPressed: () => setState(() {
                    _expanded.contains(a.id)
                        ? _expanded.remove(a.id)
                        : _expanded.add(a.id);
                  }),
                )
              else
                Icon(
                  depth == 0
                      ? Icons.account_tree_outlined
                      : Icons.subdirectory_arrow_left,
                  size: 17,
                ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(a.nameAr, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        onTap: () => context.go('/finance/accounts/${a.id}'),
      ),
      DataCell(Text(_groupLabel(a.accountGroup))),
      DataCell(Text(a.normalBalance == 'debit' ? 'مدين' : 'دائن')),
      DataCell(
        Text(
          a.parentCode == null
              ? '—'
              : '${a.parentCode} ${a.parentNameAr ?? ''}',
        ),
      ),
      DataCell(
        ManagementBadge(
          label: a.isActive ? 'نشط' : 'غير نشط',
          tone: a.isActive ? ManagementTone.success : ManagementTone.neutral,
        ),
      ),
      DataCell(
        a.isSystemProtected
            ? const Icon(Icons.lock_outline, size: 18)
            : const SizedBox(),
      ),
      DataCell(
        PopupMenuButton<String>(
          onSelected: (action) {
            action == 'edit'
                ? _form(context.read<FinanceSetupCubit>().state.accounts, a)
                : _changeStatus(a);
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            if (!a.isSystemProtected)
              const PopupMenuItem(value: 'edit', child: Text('تعديل الحساب')),
            PopupMenuItem(
              value: 'status',
              enabled: !(a.isSystemProtected && a.isActive),
              child: Text(a.isActive ? 'تعطيل الحساب' : 'تفعيل الحساب'),
            ),
          ],
        ),
      ),
    ],
  );

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
    }
  }

  Future<void> _form(
    List<FinancialAccount> accounts, [
    FinancialAccount? current,
  ]) async {
    final cubit = context.read<FinanceSetupCubit>();
    final code = TextEditingController(text: current?.code);
    final nameAr = TextEditingController(text: current?.nameAr);
    final nameEn = TextEditingController(text: current?.nameEn);
    var group = current?.accountGroup ?? 'expenses';
    var normal = current?.normalBalance ?? 'debit';
    int? parentId = current?.parentAccountId;
    var active = current?.isActive ?? true;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: Text(current == null ? 'إضافة حساب' : 'تعديل حساب'),
            content: SizedBox(
              width: 470,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: code,
                      enabled: current?.isSystemProtected != true,
                      decoration: const InputDecoration(
                        labelText: 'رمز الحساب',
                      ),
                    ),
                    TextField(
                      controller: nameAr,
                      decoration: const InputDecoration(
                        labelText: 'الاسم العربي',
                      ),
                    ),
                    TextField(
                      controller: nameEn,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الإنجليزي',
                      ),
                    ),
                    DropdownButtonFormField<String>(
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
                          : (value) => setDialog(() => group = value!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: normal,
                      decoration: const InputDecoration(
                        labelText: 'الرصيد الطبيعي',
                      ),
                      items: const <String>['debit', 'credit']
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v == 'debit' ? 'مدين' : 'دائن'),
                            ),
                          )
                          .toList(),
                      onChanged: current?.isSystemProtected == true
                          ? null
                          : (value) => setDialog(() => normal = value!),
                    ),
                    DropdownButtonFormField<int?>(
                      initialValue: parentId,
                      decoration: const InputDecoration(
                        labelText: 'الحساب الأب (اختياري)',
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('بدون حساب أب'),
                        ),
                        ...accounts
                            .where((a) => a.isActive && a.id != current?.id)
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.code} - ${a.nameAr}'),
                              ),
                            ),
                      ],
                      onChanged: (value) => setDialog(() => parentId = value),
                    ),
                    SwitchListTile(
                      value: active,
                      onChanged: current?.isSystemProtected == true
                          ? null
                          : (value) => setDialog(() => active = value),
                      title: const Text('الحساب نشط'),
                    ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('إلغاء'),
              ),
              AppButton(
                label: 'حفظ',
                icon: Icons.save_outlined,
                onPressed: () async {
                  if (code.text.trim().isEmpty ||
                      nameAr.text.trim().isEmpty ||
                      nameEn.text.trim().isEmpty) {
                    setDialog(() => error = 'الرمز والاسمان مطلوبان.');
                    return;
                  }
                  final ok = await cubit.saveAccount(<String, dynamic>{
                    'code': code.text.trim(),
                    'nameAr': nameAr.text.trim(),
                    'nameEn': nameEn.text.trim(),
                    'accountGroup': group,
                    'normalBalance': normal,
                    'parentAccountId': parentId,
                    'isActive': active,
                  }, id: current?.id);
                  if (ok && dialog.mounted) {
                    Navigator.pop(dialog);
                    if (widget.accountId != null) _reloadDetail();
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
