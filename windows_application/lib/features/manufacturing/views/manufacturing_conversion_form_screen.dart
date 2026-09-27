import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../inventory/controllers/inventory_cubit.dart';
import '../../inventory/controllers/inventory_state.dart';
import '../../inventory/models/inventory_models.dart';
import '../../inventory/widgets/warehouse_dropdown.dart';
import '../controllers/manufacturing_conversion_cubit.dart';
import '../controllers/manufacturing_conversion_state.dart';

/// Item/unit conversion: source item+quantity -> target item+quantity, one
/// warehouse. The resulting unit cost is entirely backend-calculated
/// (`ManufacturingConversionService`); this screen only submits the request
/// and renders whatever comes back.
class ManufacturingConversionFormScreen extends StatefulWidget {
  const ManufacturingConversionFormScreen({super.key});

  @override
  State<ManufacturingConversionFormScreen> createState() =>
      _ManufacturingConversionFormScreenState();
}

class _ManufacturingConversionFormScreenState
    extends State<ManufacturingConversionFormScreen> {
  final TextEditingController _sourceQty = TextEditingController();
  final TextEditingController _resultQty = TextEditingController();
  int? _warehouseId;
  int? _sourceItemId;
  int? _targetItemId;

  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() => cubit.loadItems(status: 'active'));
  }

  @override
  void dispose() {
    _sourceQty.dispose();
    _resultQty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xxl,
    ),
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState inventoryState) =>
          BlocBuilder<
            ManufacturingConversionCubit,
            ManufacturingConversionState
          >(
            builder:
                (
                  BuildContext context,
                  ManufacturingConversionState conversionState,
                ) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const ManagementPageHeader(
                      title: 'تحويل صنف',
                      subtitle: 'تحويل كمية من صنف إلى صنف آخر ضمن نفس المخزن.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (conversionState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ManagementMessage(
                          message: conversionState.error!,
                          error: true,
                        ),
                      ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          WarehouseDropdown(
                            value: _warehouseId,
                            warehouses: inventoryState.warehouses,
                            onChanged: (int? value) =>
                                setState(() => _warehouseId = value),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: <Widget>[
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _sourceItemId,
                                  decoration: const InputDecoration(
                                    labelText: 'الصنف المصدر',
                                  ),
                                  items: inventoryState.items
                                      .map(
                                        (InventoryItem item) =>
                                            DropdownMenuItem<int>(
                                              value: item.id,
                                              child: Text(item.name),
                                            ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (int? value) =>
                                      setState(() => _sourceItemId = value),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextFormField(
                                  controller: _sourceQty,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'الكمية المصدر',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: <Widget>[
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _targetItemId,
                                  decoration: const InputDecoration(
                                    labelText: 'الصنف الهدف',
                                  ),
                                  items: inventoryState.items
                                      .map(
                                        (InventoryItem item) =>
                                            DropdownMenuItem<int>(
                                              value: item.id,
                                              child: Text(item.name),
                                            ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (int? value) =>
                                      setState(() => _targetItemId = value),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextFormField(
                                  controller: _resultQty,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'الكمية الناتجة',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: conversionState.submitting
                          ? 'جارٍ التحويل...'
                          : 'تنفيذ التحويل',
                      icon: Icons.sync_alt_outlined,
                      onPressed: conversionState.submitting
                          ? null
                          : () => _submit(context),
                    ),
                  ],
                ),
          ),
    ),
  );

  Future<void> _submit(BuildContext context) async {
    if (_warehouseId == null ||
        _sourceItemId == null ||
        _targetItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل جميع الحقول المطلوبة.')),
      );
      return;
    }
    final ManufacturingConversionCubit cubit = context
        .read<ManufacturingConversionCubit>();
    final bool ok = await cubit.convert(
      warehouseId: _warehouseId!,
      sourceItemId: _sourceItemId!,
      sourceQty: _sourceQty.text.trim(),
      targetItemId: _targetItemId!,
      resultQty: _resultQty.text.trim(),
    );
    if (!context.mounted) return;
    if (ok && cubit.state.result != null) {
      context.go(
        AppRoutes.manufacturingConversionDetailPath(cubit.state.result!.id),
      );
    }
  }
}
