import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../controllers/finance_setup_state.dart';
import '../widgets/finance_paginated_table.dart';
import '../models/finance_setup_models.dart';

class JournalEntriesScreen extends StatefulWidget {
  const JournalEntriesScreen({super.key, this.initialEntryId});
  final int? initialEntryId;
  @override
  State<JournalEntriesScreen> createState() => _JournalState();
}

class _JournalState extends State<JournalEntriesScreen> {
  String _search = '';
  String? _status;
  String? _source;
  int? _branch;
  String? _from;
  String? _to;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await _load();
      if (mounted && widget.initialEntryId != null) {
        final JournalEntry? entry = await context
            .read<FinanceSetupCubit>()
            .getEntry(widget.initialEntryId!);
        if (mounted && entry != null) await _details(entry);
      }
    });
  }

  Future<void> _load() => context.read<FinanceSetupCubit>().loadEntries(
    search: _search,
    status: _status,
    sourceType: _source,
    branchId: _branch,
    from: _from,
    to: _to,
  );

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: BlocBuilder<FinanceSetupCubit, FinanceSetupState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'القيود المحاسبية',
            subtitle:
                'القيود المُرحّلة لا تُعدّل؛ تصحيحها يكون بعكسها مع الاحتفاظ بالسجل.',
            actions: <Widget>[
              AppButton(
                label: 'إضافة مسودة',
                icon: Icons.add,
                onPressed: state.accounts.where((a) => a.isActive).length < 2
                    ? null
                    : () => _draft(state),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ManagementFilterBar(
            children: <Widget>[
              SizedBox(
                width: 190,
                child: TextField(
                  onChanged: (v) {
                    _search = v;
                    _load();
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'رقم القيد أو الوصف',
                  ),
                ),
              ),
              _filter(
                _status,
                'كل الحالات',
                const <String?>[null, 'draft', 'posted'],
                (v) => v == 'draft' ? 'مسودة' : 'مُرحّل',
                (v) {
                  setState(() => _status = v);
                  _load();
                },
              ),
              _filter(
                _source,
                'كل المصادر',
                const <String?>[null, 'manual', 'journal_reversal'],
                (v) => v == 'manual' ? 'يدوي' : 'عكس قيد',
                (v) {
                  setState(() => _source = v);
                  _load();
                },
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<int?>(
                  initialValue: _branch,
                  hint: const Text('كل الفروع'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem(
                      value: null,
                      child: Text('كل الفروع'),
                    ),
                    ...state.branches.map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _branch = v);
                    _load();
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  onChanged: (v) {
                    _from = v;
                    _load();
                  },
                  decoration: const InputDecoration(hintText: 'من YYYY-MM-DD'),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  onChanged: (v) {
                    _to = v;
                    _load();
                  },
                  decoration: const InputDecoration(hintText: 'إلى YYYY-MM-DD'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _content(state)),
        ],
      ),
    ),
  );

  Widget _content(FinanceSetupState state) {
    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.entries.isEmpty) {
      return ManagementMessage(
        message: state.errorMessage!,
        error: true,
        onRetry: _load,
      );
    }
    if (state.entries.isEmpty) {
      return const ManagementMessage(
        message: 'لا توجد قيود يومية ضمن عوامل التصفية المحددة.',
      );
    }
    return ManagementTableShell(
      minWidth: 1180,
      child: FinancePaginatedTable(
        minWidth: 1180,
        columns: const <DataColumn>[
          DataColumn(label: Text('رقم القيد')),
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('الوصف')),
          DataColumn(label: Text('المصدر')),
          DataColumn(label: Text('الفرع')),
          DataColumn(label: Text('مدين')),
          DataColumn(label: Text('دائن')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('العكس')),
          DataColumn(label: Text('')),
        ],
        rows: state.entries.map(_row).toList(),
      ),
    );
  }

  DataRow _row(JournalEntry entry) => DataRow(
    cells: <DataCell>[
      DataCell(Text(entry.entryNumber)),
      DataCell(Text(entry.entryDate)),
      DataCell(Text(entry.description ?? '—')),
      DataCell(Text(entry.sourceType)),
      DataCell(Text(entry.branchName ?? '—')),
      DataCell(Text(entry.debitTotal)),
      DataCell(Text(entry.creditTotal)),
      DataCell(
        ManagementBadge(
          label: entry.status == 'draft' ? 'مسودة' : 'مُرحّل',
          tone: entry.status == 'draft'
              ? ManagementTone.warning
              : ManagementTone.success,
        ),
      ),
      DataCell(
        Text(
          entry.reversalOfId != null
              ? 'عكس قيد سابق'
              : entry.isReversed
              ? 'تم عكسه'
              : '—',
        ),
      ),
      DataCell(
        PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'details') _details(entry);
            if (action == 'post') _post(entry);
            if (action == 'reverse') _reverse(entry);
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem(value: 'details', child: Text('عرض التفاصيل')),
            if (entry.status == 'draft')
              const PopupMenuItem(value: 'post', child: Text('ترحيل القيد')),
            if (entry.status == 'posted' &&
                !entry.isReversed &&
                entry.reversalOfId == null)
              const PopupMenuItem(value: 'reverse', child: Text('عكس القيد')),
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
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 150,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      hint: Text(hint),
      items: values
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(v == null ? hint : label(v)),
            ),
          )
          .toList(),
      onChanged: changed,
    ),
  );

  Future<void> _post(JournalEntry entry) async {
    final ok = await context.read<FinanceSetupCubit>().postEntry(entry.id);
    if (mounted && !ok) _error();
  }

  Future<void> _reverse(JournalEntry entry) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('عكس القيد؟'),
        content: Text(
          'لن يُحذف ${entry.entryNumber}. سيُنشأ قيد عكس مستقل ويحافظ على السجل المالي.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'عكس القيد',
            onPressed: () => Navigator.pop(d, true),
          ),
        ],
      ),
    );
    if (approved != true) return;
    if (!mounted) return;
    final ok = await context.read<FinanceSetupCubit>().reverseEntry(entry.id);
    if (mounted && !ok) _error();
  }

  void _error() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.read<FinanceSetupCubit>().state.errorMessage ??
            'تعذر تنفيذ العملية.',
      ),
    ),
  );

  Future<void> _details(JournalEntry summary) async {
    final future = context.read<FinanceSetupCubit>().getEntry(summary.id);
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('تفاصيل القيد ${summary.entryNumber}'),
        content: SizedBox(
          width: 760,
          child: FutureBuilder<JournalEntry?>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entry = snapshot.data;
              if (entry == null) return const Text('تعذر تحميل تفاصيل القيد.');
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'التاريخ: ${entry.entryDate}   الحالة: ${entry.status}',
                    ),
                    Text('الوصف: ${entry.description ?? '—'}'),
                    Text(
                      'المصدر: ${entry.sourceType} / ${entry.sourceId ?? '—'} / ${entry.sourceEvent ?? '—'}',
                    ),
                    Text('الفرع: ${entry.branchName ?? '—'}'),
                    Text(
                      entry.reversalOfId != null
                          ? 'عكس للقيد: ${entry.reversalOfId}'
                          : entry.isReversed
                          ? 'القيد الأصلي تم عكسه'
                          : 'لم يُعكس',
                    ),
                    Text(
                      'أنشأه: ${entry.createdBy ?? '—'}   رحّله: ${entry.postedBy ?? '—'}',
                    ),
                    Text(
                      'الإنشاء: ${entry.createdAt ?? '—'}   التحديث: ${entry.updatedAt ?? '—'}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FinancePaginatedTable(
                      minWidth: 720,
                      columns: const <DataColumn>[
                        DataColumn(label: Text('الحساب')),
                        DataColumn(label: Text('الوصف')),
                        DataColumn(label: Text('مدين')),
                        DataColumn(label: Text('دائن')),
                      ],
                      rows: entry.lines
                          .map(
                            (line) => DataRow(
                              cells: <DataCell>[
                                DataCell(
                                  Text(
                                    '${line.accountCode} ${line.accountNameAr}',
                                  ),
                                ),
                                DataCell(Text(line.description ?? '—')),
                                DataCell(Text(line.debit)),
                                DataCell(Text(line.credit)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                    const Divider(),
                    Text(
                      'إجمالي مدين: ${entry.debitTotal}    إجمالي دائن: ${entry.creditTotal}',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _draft(FinanceSetupState state) async {
    final accounts = state.accounts.where((a) => a.isActive).toList();
    final description = TextEditingController();
    final date = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final lines = <_DraftLine>[
      _DraftLine(accounts.first.id),
      _DraftLine(accounts[1].id),
    ];
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: const Text('إضافة مسودة قيد'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: date,
                      decoration: const InputDecoration(
                        labelText: 'التاريخ (YYYY-MM-DD)',
                      ),
                    ),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    ...lines.asMap().entries.map((entry) {
                      final i = entry.key;
                      final line = entry.value;
                      return Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: line.accountId,
                              items: accounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text('${a.code} - ${a.nameAr}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setDialog(() => line.accountId = value!),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: line.debit,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'مدين',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: line.credit,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'دائن',
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: lines.length > 2
                                ? () => setDialog(() {
                                    final removed = lines.removeAt(i);
                                    removed.dispose();
                                  })
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setDialog(
                        () => lines.add(_DraftLine(accounts.first.id)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة سطر'),
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
                label: 'حفظ مسودة',
                onPressed: () async {
                  final payload = _validatedPayload(
                    date.text,
                    description.text,
                    lines,
                  );
                  if (payload == null) {
                    setDialog(
                      () => error =
                          'أدخل تاريخاً صحيحاً، وسطرين على الأقل؛ كل سطر مدين أو دائن فقط وبمبلغ موجب، والإجماليان متساويان.',
                    );
                    return;
                  }
                  final ok = await context
                      .read<FinanceSetupCubit>()
                      .createDraft(payload);
                  if (ok && dialog.mounted) {
                    Navigator.pop(dialog);
                  } else if (dialog.mounted) {
                    setDialog(
                      () => error =
                          context
                              .read<FinanceSetupCubit>()
                              .state
                              .errorMessage ??
                          'تعذر حفظ المسودة.',
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
    description.dispose();
    date.dispose();
    for (final line in lines) {
      line.dispose();
    }
  }

  Map<String, dynamic>? _validatedPayload(
    String date,
    String description,
    List<_DraftLine> lines,
  ) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) || lines.length < 2) {
      return null;
    }
    var debit = 0;
    var credit = 0;
    final json = <Map<String, dynamic>>[];
    for (final line in lines) {
      final d = _cents(line.debit.text);
      final c = _cents(line.credit.text);
      if ((d > 0) == (c > 0)) return null;
      debit += d;
      credit += c;
      json.add(<String, dynamic>{
        'accountId': line.accountId,
        'debit': _decimal(d),
        'credit': _decimal(c),
      });
    }
    if (debit == 0 || debit != credit) return null;
    return <String, dynamic>{
      'entryDate': date,
      'description': description.trim().isEmpty ? null : description.trim(),
      'sourceType': 'manual',
      'lines': json,
    };
  }

  int _cents(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
    if (match == null) return 0;
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

  String _decimal(int cents) =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

class _DraftLine {
  _DraftLine(this.accountId);
  int accountId;
  final debit = TextEditingController();
  final credit = TextEditingController();
  void dispose() {
    debit.dispose();
    credit.dispose();
  }
}
