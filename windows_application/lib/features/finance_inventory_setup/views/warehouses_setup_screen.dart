import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/localization/localization_extensions.dart';
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
    Future<void>.microtask(context.read<FinanceSetupCubit>().loadWarehouses);
  }

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    child: BlocBuilder<FinanceSetupCubit, FinanceSetupState>(
      builder: (BuildContext context, FinanceSetupState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: context.l10n.financeWarehouseTitle,
            subtitle: context.l10n.financeWarehouseSubtitle,
            actions: <Widget>[
              AppButton(
                label: context.l10n.financeWarehouseAdd,
                icon: Icons.add,
                onPressed: () => _form(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ManagementFilterBar(
            children: <Widget>[
              _WarehouseFilter(
                context.l10n.financeWarehouseAllBranches,
                Icons.account_tree_outlined,
              ),
              _WarehouseFilter(
                context.l10n.financeWarehouseAllStatuses,
                Icons.filter_alt_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: state.isLoading && state.warehouses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.warehouses.isEmpty
                ? ManagementMessage(message: context.l10n.financeWarehouseEmpty)
                : ManagementTableShell(
                    minWidth: 760,
                    child: FinancePaginatedTable(
                      minWidth: 760,
                      columns: <DataColumn>[
                        DataColumn(label: Text(context.l10n.financeWarehouseName)),
                        DataColumn(label: Text(context.l10n.financeWarehouseCode)),
                        DataColumn(label: Text(context.l10n.financeWarehouseType)),
                        DataColumn(label: Text(context.l10n.financeWarehouseBranch)),
                        DataColumn(
                          label: Text(context.l10n.financeSupplierStatusLabel),
                        ),
                        const DataColumn(label: Text('')),
                      ],
                      rows: state.warehouses
                          .map(
                            (WarehouseLocation warehouse) => DataRow(
                              cells: <DataCell>[
                                DataCell(Text(warehouse.displayName)),
                                DataCell(Text(warehouse.code)),
                                DataCell(
                                  Text(
                                    warehouse.type == 'central'
                                        ? context.l10n.financeWarehouseCentral
                                        : context.l10n.financeWarehouseBranchType,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    warehouse.branchName ??
                                        context.l10n.financeWarehouseUnassignedBranch,
                                  ),
                                ),
                                DataCell(
                                  ManagementBadge(
                                    label: warehouse.isActive
                                        ? context.l10n.financeStatusActive
                                        : context.l10n.financeStatusInactive,
                                    tone: warehouse.isActive
                                        ? ManagementTone.success
                                        : ManagementTone.neutral,
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: context.l10n.financeWarehouseEdit,
                                    onPressed: () => _form(context, warehouse),
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
  );

  Future<void> _form(
    BuildContext context, [
    WarehouseLocation? current,
  ]) async {
    final FinanceSetupCubit cubit = context.read<FinanceSetupCubit>();
    final TextEditingController name = TextEditingController(text: current?.name);
    final TextEditingController code = TextEditingController(text: current?.code);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(
          current == null
              ? context.l10n.financeWarehouseAdd
              : context.l10n.financeWarehouseEdit,
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: context.l10n.financeWarehouseName,
                ),
              ),
              TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: context.l10n.financeWarehouseCode,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.l10n.commonCancel),
          ),
          AppButton(
            label: context.l10n.commonSave,
            icon: Icons.save_outlined,
            onPressed: () async {
              if (name.text.trim().isEmpty || code.text.trim().isEmpty) return;
              final bool saved = await cubit.saveWarehouse(
                <String, dynamic>{
                  'name': name.text.trim(),
                  'code': code.text.trim(),
                  'type': current?.type ?? 'central',
                  'branchId': current?.branchId,
                  'notes': current?.notes,
                  'isActive': current?.isActive ?? true,
                },
                id: current?.id,
              );
              if (dialog.mounted && saved) Navigator.pop(dialog);
            },
          ),
        ],
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
