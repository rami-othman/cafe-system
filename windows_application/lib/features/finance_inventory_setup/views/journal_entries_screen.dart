import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../controllers/finance_setup_state.dart';
import '../models/finance_setup_models.dart';

class JournalEntriesScreen extends StatefulWidget {
  const JournalEntriesScreen({super.key});
  @override
  State<JournalEntriesScreen> createState() => _JournalState();
}

class _JournalState extends State<JournalEntriesScreen> {
  @override
  void initState() {
    super.initState();
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    Future<void>.microtask(cubit.loadEntries);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      child: BlocBuilder<FinanceSetupCubit, FinanceSetupState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ManagementPageHeader(
              title: 'قيود اليومية',
              subtitle: 'مراجعة القيود والمسودات المالية وترحيلها بعد التحقق.',
              actions: <Widget>[
                AppButton(
                  label: 'إضافة مسودة',
                  icon: Icons.add,
                  onPressed: state.accounts.length < 2
                      ? null
                      : () => _draft(context, state),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const ManagementFilterBar(
              children: <Widget>[
                _JournalFilter('آخر 30 يوماً', Icons.date_range_outlined),
                _JournalFilter('كل الحالات', Icons.filter_alt_outlined),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: state.isLoading && state.entries.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.entries.isEmpty
                  ? const ManagementMessage(
                      message: 'لا توجد قيود يومية ضمن الفترة المحددة.',
                    )
                  : ManagementTableShell(
                      minWidth: 820,
                      child: DataTable(
                        columns: const <DataColumn>[
                          DataColumn(label: Text('رقم القيد')),
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('مدين')),
                          DataColumn(label: Text('دائن')),
                          DataColumn(label: Text('الحالة')),
                          DataColumn(label: Text('')),
                        ],
                        rows: state.entries
                            .map(
                              (entry) => DataRow(
                                cells: <DataCell>[
                                  DataCell(Text(entry.entryNumber)),
                                  DataCell(Text(entry.entryDate)),
                                  DataCell(Text('${entry.debitTotal} ر.س')),
                                  DataCell(Text('${entry.creditTotal} ر.س')),
                                  DataCell(
                                    ManagementBadge(
                                      label: entry.status == 'draft'
                                          ? 'مسودة'
                                          : 'مُرحّل',
                                      tone: entry.status == 'draft'
                                          ? ManagementTone.warning
                                          : ManagementTone.success,
                                    ),
                                  ),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      onSelected: (action) =>
                                          action == 'details'
                                          ? _details(context, entry)
                                          : _post(context, entry),
                                      itemBuilder: (_) =>
                                          <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                              value: 'details',
                                              child: Text('عرض التفاصيل'),
                                            ),
                                            if (entry.status == 'draft')
                                              const PopupMenuItem<String>(
                                                value: 'post',
                                                child: Text('ترحيل القيد'),
                                              ),
                                          ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> _post(BuildContext context, JournalEntry entry) async {
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ok = await cubit.postEntry(entry.id);
    if (mounted && !ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(cubit.state.errorMessage ?? 'تعذر ترحيل القيد.'),
        ),
      );
    }
  }

  void _details(BuildContext context, JournalEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialog) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تفاصيل القيد ${entry.entryNumber}'),
          content: SizedBox(
            width: 620,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('الحساب')),
                DataColumn(label: Text('مدين')),
                DataColumn(label: Text('دائن')),
              ],
              rows: entry.lines
                  .map(
                    (line) => DataRow(
                      cells: <DataCell>[
                        DataCell(
                          Text('${line.accountCode} ${line.accountNameAr}'),
                        ),
                        DataCell(Text(line.debit)),
                        DataCell(Text(line.credit)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _draft(BuildContext context, FinanceSetupState state) async {
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    final accounts = state.accounts.where((a) => a.isActive).toList();
    var debit = accounts.first.id;
    var credit = accounts[1].id;
    final amount = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialog) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, set) => AlertDialog(
            title: const Text('إضافة مسودة قيد'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    initialValue: debit,
                    decoration: const InputDecoration(
                      labelText: 'الحساب المدين',
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a.id,
                            child: Text('${a.code} - ${a.nameAr}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => debit = v ?? debit),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: credit,
                    decoration: const InputDecoration(
                      labelText: 'الحساب الدائن',
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a.id,
                            child: Text('${a.code} - ${a.nameAr}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => credit = v ?? credit),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'المبلغ'),
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
                label: 'حفظ المسودة',
                onPressed: () async {
                  final value = double.tryParse(amount.text);
                  if (value == null || value <= 0 || debit == credit) return;
                  final ok = await cubit.createDraft(<String, dynamic>{
                    'entryDate': DateTime.now().toIso8601String().substring(
                      0,
                      10,
                    ),
                    'sourceType': 'manual',
                    'lines': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'accountId': debit,
                        'debit': amount.text,
                        'credit': '0.00',
                      },
                      <String, dynamic>{
                        'accountId': credit,
                        'debit': '0.00',
                        'credit': amount.text,
                      },
                    ],
                  });
                  if (dialog.mounted && ok) {
                    Navigator.pop(dialog);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
    amount.dispose();
  }
}

class _JournalFilter extends StatelessWidget {
  const _JournalFilter(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () {},
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}
