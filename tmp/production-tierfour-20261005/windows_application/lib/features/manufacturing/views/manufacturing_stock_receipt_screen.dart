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

/// Direct stock receipt: a manual "material came in" entry for Manufacturing
/// materials, posted through the existing Inventory `stock_in` movement
/// (`InventoryRepository.postMovement`) so it produces a real, WAC-updating
/// stock movement server-side. This is explicitly NOT a supplier invoice and
/// creates no AP entry - for that, Purchasing's goods-receipt flow is the
/// correct tool.
class ManufacturingStockReceiptScreen extends StatefulWidget {
  const ManufacturingStockReceiptScreen({super.key});

  @override
  State<ManufacturingStockReceiptScreen> createState() =>
      _ManufacturingStockReceiptScreenState();
}

class _ManufacturingStockReceiptScreenState
    extends State<ManufacturingStockReceiptScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _unitCost = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  int? _itemId;
  int? _warehouseId;
  String? _unit;
  String? _idempotencyKey;

  static const Set<String> _materialTypes = <String>{
    'raw_material',
    'semi_finished_good',
    'finished_good',
    'packaging',
  };

  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() => cubit.loadItems(status: 'active'));
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    _reference.dispose();
    _notes.dispose();
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
      builder: (BuildContext context, InventoryState state) {
        final List<InventoryItem> materials = state.items
            .where(
              (InventoryItem item) => _materialTypes.contains(item.itemType),
            )
            .toList(growable: false);
        final InventoryItem? selectedItem = materials
            .where((InventoryItem item) => item.id == _itemId)
            .cast<InventoryItem?>()
            .firstWhere((_) => true, orElse: () => null);
        _unit ??= selectedItem?.unit;

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ManagementPageHeader(
                title: 'استلام مخزون مباشر',
                subtitle:
                    'تسجيل دخول مادة إلى المخزون مباشرة (ليست فاتورة مورد).',
                actions: <Widget>[
                  AppButton(
                    label: 'إلغاء',
                    variant: AppButtonVariant.outlined,
                    onPressed: () =>
                        context.go(AppRoutes.manufacturingMaterials),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<int>(
                      initialValue: _itemId,
                      decoration: const InputDecoration(labelText: 'المادة'),
                      items: materials
                          .map(
                            (InventoryItem item) => DropdownMenuItem<int>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (int? value) => setState(() {
                        _itemId = value;
                        _unit = materials
                            .where((InventoryItem item) => item.id == value)
                            .cast<InventoryItem?>()
                            .firstWhere((_) => true, orElse: () => null)
                            ?.unit;
                      }),
                      validator: (int? value) =>
                          value == null ? 'اختر المادة' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    WarehouseDropdown(
                      value: _warehouseId,
                      warehouses: state.warehouses,
                      onChanged: (int? value) =>
                          setState(() => _warehouseId = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'الكمية',
                            ),
                            validator: (String? value) {
                              final double? qty = double.tryParse(
                                value?.trim() ?? '',
                              );
                              return qty == null || qty <= 0
                                  ? 'أدخل كمية صحيحة'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _unit == null
                                ? 'اختر المادة لتحديد الوحدة'
                                : 'الوحدة: ${InventoryUnit.labelFor(_unit!)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _unitCost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'تكلفة الوحدة (ل.س)',
                      ),
                      validator: (String? value) {
                        final double? cost = double.tryParse(
                          value?.trim() ?? '',
                        );
                        return cost == null || cost < 0
                            ? 'أدخل تكلفة صحيحة'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _reference,
                      decoration: const InputDecoration(
                        labelText: 'المرجع (اختياري)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: state.saving ? 'جارٍ الحفظ...' : 'تسجيل الاستلام',
                icon: Icons.check_circle_outline,
                onPressed: state.saving ? null : () => _submit(context),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_warehouseId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر المخزن.')));
      return;
    }
    final String key = _idempotencyKey ??=
        'mfg-stock-receipt-${DateTime.now().microsecondsSinceEpoch}';
    final String reference = <String>[
      _reference.text.trim(),
      _notes.text.trim(),
    ].where((String value) => value.isNotEmpty).join(' — ');
    final InventoryCubit cubit = context.read<InventoryCubit>();
    final bool saved = await cubit.postMovement(<String, dynamic>{
      'warehouseId': _warehouseId,
      'itemId': _itemId,
      'type': 'stock_in',
      'quantity': _quantity.text.trim(),
      if (_unit != null) 'unit': _unit,
      'unitCost': _unitCost.text.trim(),
      'idempotencyKey': key,
      if (reference.isNotEmpty) 'reason': reference,
    });
    if (!context.mounted) return;
    if (saved) {
      context.go(AppRoutes.manufacturingMaterials);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cubit.state.error ?? 'تعذر تسجيل الاستلام')),
      );
    }
  }
}
