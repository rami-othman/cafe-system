import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../inventory/controllers/inventory_cubit.dart';
import '../../inventory/controllers/inventory_state.dart';
import '../../inventory/widgets/warehouse_dropdown.dart';
import '../controllers/manufacturing_reports_cubit.dart';
import '../controllers/manufacturing_reports_state.dart';
import '../models/manufacturing_report_models.dart';

/// `GET /manufacturing/reports`. Filters are limited to what the controller
/// actually accepts (`warehouseId`, `type`, `dateFrom`, `dateTo`) - no date
/// presets or extra dimensions the backend would silently ignore.
class ManufacturingReportsScreen extends StatefulWidget {
  const ManufacturingReportsScreen({super.key});

  @override
  State<ManufacturingReportsScreen> createState() =>
      _ManufacturingReportsScreenState();
}

class _ManufacturingReportsScreenState
    extends State<ManufacturingReportsScreen> {
  int? _warehouseId;
  String _type = '';

  @override
  void initState() {
    super.initState();
    final ManufacturingReportsCubit cubit = context
        .read<ManufacturingReportsCubit>();
    final InventoryCubit inventoryCubit = context.read<InventoryCubit>();
    Future<void>.microtask(() {
      cubit.loadReports();
      inventoryCubit.loadItems();
    });
  }

  void _load() {
    context.read<ManufacturingReportsCubit>().loadReports(
      warehouseId: _warehouseId,
      type: _type.isEmpty ? null : _type,
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
    ),
    child: BlocBuilder<ManufacturingReportsCubit, ManufacturingReportsState>(
      builder: (BuildContext context, ManufacturingReportsState state) =>
          BlocBuilder<InventoryCubit, InventoryState>(
            builder: (BuildContext context, InventoryState inventoryState) =>
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ManagementPageHeader(
                      title: 'التقارير',
                      subtitle:
                          'تحليل الإنتاج والتكلفة والهدر خلال الفترة المحددة.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ManagementFilterBar(
                      children: <Widget>[
                        DropdownButton<String>(
                          value: _type,
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text('كل الأنواع'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'finished_good',
                              child: Text('منتج جاهز'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'semi_finished_good',
                              child: Text('نصف مصنع'),
                            ),
                          ],
                          onChanged: (String? value) {
                            setState(() => _type = value ?? '');
                            _load();
                          },
                        ),
                        WarehouseDropdown(
                          value: _warehouseId,
                          warehouses: inventoryState.warehouses,
                          onChanged: (int? value) {
                            setState(() => _warehouseId = value);
                            _load();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (state.loading && state.data == null)
                      const Padding(
                        padding: AppSpacing.allXxl,
                        child: AppLoading(),
                      )
                    else if (state.error != null && state.data == null)
                      ManagementMessage(
                        message: state.error!,
                        error: true,
                        onRetry: _load,
                      )
                    else if (state.data == null || !state.data!.hasData)
                      const ManagementMessage(
                        message: 'لا توجد بيانات ضمن الفترة المحددة.',
                      )
                    else
                      _ReportsBody(data: state.data!),
                  ],
                ),
          ),
    ),
  );
}

class _ReportsBody extends StatelessWidget {
  const _ReportsBody({required this.data});
  final ManufacturingReportsData data;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          ManagementKpiCard(
            label: 'إجمالي الكمية',
            value: data.kpis.totalQty.toStringAsFixed(2),
            icon: Icons.factory_outlined,
          ),
          ManagementKpiCard(
            label: 'إجمالي التكلفة',
            value: data.kpis.totalCost.toStringAsFixed(2),
            icon: Icons.payments_outlined,
          ),
          ManagementKpiCard(
            label: 'متوسط تكلفة الوحدة',
            value: data.kpis.avgUnitCost.toStringAsFixed(4),
            icon: Icons.calculate_outlined,
          ),
          ManagementKpiCard(
            label: 'متوسط الكفاءة',
            value: '${data.kpis.avgEfficiency.toStringAsFixed(1)}%',
            icon: Icons.trending_up_outlined,
          ),
          ManagementKpiCard(
            label: 'أحداث الهدر',
            value: '${data.kpis.totalWasteEvents}',
            icon: Icons.delete_outline,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      if (data.byProduct.isNotEmpty)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'التكلفة حسب المنتج',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...data.byProduct.map(
                (ManufacturingReportProductCost item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.product),
                  subtitle: Text('${item.qty.toStringAsFixed(2)} وحدة'),
                  trailing: Text(item.cost.toStringAsFixed(2)),
                ),
              ),
            ],
          ),
        ),
      if (data.byWarehouse.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('الكمية حسب المخزن', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ...data.byWarehouse.map(
                (ManufacturingReportWarehouseQty item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.warehouse),
                  trailing: Text(item.qty.toStringAsFixed(2)),
                ),
              ),
            ],
          ),
        ),
      ],
      if (data.materialConsumption.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('استهلاك المواد', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ManagementTableShell(
                minWidth: 500,
                verticalScroll: data.materialConsumption.length > 20,
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll<Color>(
                    AppColors.menuTableHeader,
                  ),
                  columns: const <DataColumn>[
                    DataColumn(label: Text('المادة')),
                    DataColumn(label: Text('الكمية')),
                  ],
                  rows: data.materialConsumption
                      .map(
                        (
                          ManufacturingReportMaterialConsumption item,
                        ) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(item.name)),
                            DataCell(
                              Text(
                                '${item.qty.toStringAsFixed(2)} ${item.unit}',
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ],
      if (data.waste.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('الهدر', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ...data.waste.map(
                (ManufacturingReportWasteEntry item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.product),
                  subtitle: Text(item.reason ?? ''),
                  trailing: Text('${item.qty} ${item.unit}'),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
