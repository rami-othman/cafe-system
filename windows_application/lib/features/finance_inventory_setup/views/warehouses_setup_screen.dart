import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/finance_setup_cubit.dart';
import '../controllers/finance_setup_state.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_paginated_table.dart';

class WarehousesSetupScreen extends StatefulWidget {
  const WarehousesSetupScreen({super.key});
  @override
  State<WarehousesSetupScreen> createState() => _WarehousesState();
}

class _WarehousesState extends State<WarehousesSetupScreen> {
  @override
  void initState() {
    super.initState();
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    Future<void>.microtask(cubit.loadWarehouses);
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
              title: 'تهيئة المخازن',
              subtitle: 'إدارة المستودعات التشغيلية وربطها بالفروع.',
              actions: <Widget>[
                AppButton(
                  label: 'إضافة مستودع',
                  icon: Icons.add,
                  onPressed: () => _form(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const ManagementFilterBar(
              children: <Widget>[
                _WarehouseFilter('كل الفروع', Icons.account_tree_outlined),
                _WarehouseFilter('كل الحالات', Icons.filter_alt_outlined),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: state.isLoading && state.warehouses.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.warehouses.isEmpty
                  ? const ManagementMessage(
                      message: 'لا توجد مستودعات مضافة حتى الآن.',
                    )
                  : ManagementTableShell(
                      minWidth: 760,
                      child: FinancePaginatedTable(
                        minWidth: 760,
                        columns: const <DataColumn>[
                          DataColumn(label: Text('المستودع')),
                          DataColumn(label: Text('الرمز')),
                          DataColumn(label: Text('النوع')),
                          DataColumn(label: Text('الفرع')),
                          DataColumn(label: Text('الحالة')),
                          DataColumn(label: Text('')),
                        ],
                        rows: state.warehouses
                            .map(
                              (w) => DataRow(
                                cells: <DataCell>[
                                  DataCell(Text(w.displayName)),
                                  DataCell(Text(w.code)),
                                  DataCell(
                                    Text(w.type == 'central' ? 'مركزي' : 'فرع'),
                                  ),
                                  DataCell(Text(w.branchName ?? '—')),
                                  DataCell(
                                    ManagementBadge(
                                      label: w.isActive ? 'نشط' : 'غير نشط',
                                      tone: w.isActive
                                          ? ManagementTone.success
                                          : ManagementTone.neutral,
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'تعديل المستودع',
                                      onPressed: () => _form(context, w),
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
  Future<void> _form(BuildContext context, [WarehouseLocation? current]) async {
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    final name = TextEditingController(text: current?.name);
    final code = TextEditingController(text: current?.code);
    await showDialog<void>(
      context: context,
      builder: (dialog) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(current == null ? 'إضافة مستودع' : 'تعديل مستودع'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المستودع'),
                ),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'رمز المستودع'),
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
                if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
                  return;
                }
                final ok = await cubit.saveWarehouse(<String, dynamic>{
                  'name': name.text.trim(),
                  'code': code.text.trim(),
                  'type': current?.type ?? 'central',
                  'branchId': current?.branchId,
                  'notes': current?.notes,
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
    name.dispose();
    code.dispose();
  }
}

class _WarehouseFilter extends StatelessWidget {
  const _WarehouseFilter(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
}
