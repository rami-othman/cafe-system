import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../controllers/finance_setup_state.dart';
import '../models/finance_setup_models.dart';

class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({super.key});
  @override
  State<FinancialAccountsScreen> createState() => _AccountsState();
}

class _AccountsState extends State<FinancialAccountsScreen> {
  String query = '';
  @override
  void initState() {
    super.initState();
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    Future<void>.microtask(cubit.loadAccounts);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DesktopPageLayout(
      child: BlocBuilder<FinanceSetupCubit, FinanceSetupState>(
        builder: (context, state) {
          final rows = state.accounts
              .where((a) => '${a.code} ${a.nameAr}'.contains(query))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ManagementPageHeader(
                title: 'دليل الحسابات',
                subtitle: 'إدارة الحسابات المالية الأساسية والهيكل المحاسبي.',
                actions: <Widget>[
                  AppButton(
                    label: 'إضافة حساب',
                    icon: Icons.add,
                    onPressed: () => _form(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ManagementFilterBar(
                children: <Widget>[
                  SizedBox(
                    width: 280,
                    child: TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'البحث بالاسم أو الرمز',
                      ),
                    ),
                  ),
                  const _AccountsFilter(
                    'كل مجموعات الحسابات',
                    Icons.account_tree_outlined,
                  ),
                  const _AccountsFilter(
                    'كل الحالات',
                    Icons.filter_alt_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: state.isLoading && state.accounts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : rows.isEmpty
                    ? const ManagementMessage(
                        message: 'لا توجد حسابات مطابقة للبحث.',
                      )
                    : ManagementTableShell(
                        minWidth: 830,
                        child: DataTable(
                          columns: const <DataColumn>[
                            DataColumn(label: Text('الرمز')),
                            DataColumn(label: Text('اسم الحساب')),
                            DataColumn(label: Text('المجموعة')),
                            DataColumn(label: Text('الرصيد الطبيعي')),
                            DataColumn(label: Text('الحالة')),
                            DataColumn(label: Text('')),
                          ],
                          rows: rows
                              .map(
                                (a) => DataRow(
                                  cells: <DataCell>[
                                    DataCell(Text(a.code)),
                                    DataCell(Text(a.nameAr)),
                                    DataCell(Text(a.accountGroup)),
                                    DataCell(
                                      Text(
                                        a.normalBalance == 'debit'
                                            ? 'مدين'
                                            : 'دائن',
                                      ),
                                    ),
                                    DataCell(
                                      ManagementBadge(
                                        label: a.isActive ? 'نشط' : 'غير نشط',
                                        tone: a.isActive
                                            ? ManagementTone.success
                                            : ManagementTone.neutral,
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'تعديل الحساب',
                                        onPressed: a.isSystemProtected
                                            ? null
                                            : () => _form(context, a),
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
          );
        },
      ),
    ),
  );
  Future<void> _form(BuildContext context, [FinancialAccount? current]) async {
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    final code = TextEditingController(text: current?.code);
    final name = TextEditingController(text: current?.nameAr);
    await showDialog<void>(
      context: context,
      builder: (dialog) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(current == null ? 'إضافة حساب' : 'تعديل حساب'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'رمز الحساب'),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحساب بالعربية',
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
              label: 'حفظ',
              icon: Icons.save_outlined,
              onPressed: () async {
                if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
                  return;
                }
                final ok = await cubit.saveAccount(<String, dynamic>{
                  'code': code.text.trim(),
                  'nameAr': name.text.trim(),
                  'nameEn': current?.nameEn ?? name.text.trim(),
                  'accountGroup': current?.accountGroup ?? 'expenses',
                  'normalBalance': current?.normalBalance ?? 'debit',
                  'parentAccountId': current?.parentAccountId,
                  'isActive': current?.isActive ?? true,
                }, id: current?.id);
                if (dialog.mounted && ok) {
                  Navigator.pop(dialog);
                }
              },
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
  }
}

class _AccountsFilter extends StatelessWidget {
  const _AccountsFilter(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () {},
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}
