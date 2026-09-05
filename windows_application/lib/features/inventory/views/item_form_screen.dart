import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/inventory_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../controllers/inventory_cubit.dart';
import '../controllers/inventory_state.dart';
import '../models/inventory_models.dart';
import 'widgets/inventory_item_widgets.dart';

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, this.itemId});
  final int? itemId;
  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _sku = TextEditingController();
  final TextEditingController _barcode = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _minimum = TextEditingController(text: '0.000');
  final TextEditingController _reorder = TextEditingController(text: '0.000');
  final TextEditingController _averageCost = TextEditingController(
    text: '0.0000',
  );
  final TextEditingController _lastPurchaseCost = TextEditingController(
    text: '0.0000',
  );
  final TextEditingController _supplier = TextEditingController();
  final TextEditingController _purchaseFactor = TextEditingController(
    text: '1',
  );
  final TextEditingController _consumptionFactor = TextEditingController(
    text: '1',
  );
  String _type = 'stock_item';
  String _baseUnit = 'piece';
  String _purchaseUnit = 'piece';
  String _consumptionUnit = 'piece';
  bool _active = true;
  bool _trackExpiry = false;
  bool _trackBatch = false;
  final Set<int> _warehouseIds = <int>{};
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final InventoryCubit cubit = context.read<InventoryCubit>();
    Future<void>.microtask(() {
      cubit.loadItems();
      if (widget.itemId != null) {
        cubit.loadItemDetails(widget.itemId!);
      }
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _category,
      _sku,
      _barcode,
      _description,
      _minimum,
      _reorder,
      _averageCost,
      _lastPurchaseCost,
      _supplier,
      _purchaseFactor,
      _consumptionFactor,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrate(InventoryItem item) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = item.name;
    _category.text = item.category;
    _sku.text = item.sku;
    _barcode.text = item.barcode;
    _description.text = item.notes;
    _minimum.text = item.minimumStock;
    _reorder.text = item.reorderLevel;
    _averageCost.text = item.cost;
    _lastPurchaseCost.text = item.lastPurchaseCost;
    _supplier.text = item.preferredSupplierName;
    _type = item.itemType;
    _baseUnit = item.unit;
    _purchaseUnit = item.purchaseUnit.isEmpty ? item.unit : item.purchaseUnit;
    _consumptionUnit = item.consumptionUnit.isEmpty
        ? item.unit
        : item.consumptionUnit;
    _active = item.active;
    _trackExpiry = item.trackExpiry;
    _trackBatch = item.trackBatch;
    _warehouseIds.addAll(item.warehouseIds);
  }

  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
    ),
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (BuildContext context, InventoryState state) {
        final InventoryItem? current = widget.itemId == null
            ? null
            : state.selectedItem?.id == widget.itemId
            ? state.selectedItem
            : null;
        if (widget.itemId != null && current == null && state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (current != null) {
          _hydrate(current);
        }
        final List<InventoryUnit> units = state.units.isEmpty
            ? InventoryUnit.fallback
            : state.units;
        return SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ManagementPageHeader(
                  title: current == null ? 'إضافة مادة مخزنية' : 'تعديل المادة',
                  subtitle:
                      'الكمية لا تُعدّل هنا؛ تتغير فقط عبر عمليات المخزون المعتمدة.',
                  actions: <Widget>[
                    AppButton(
                      label: 'إلغاء',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go(
                        widget.itemId == null
                            ? AppRoutes.inventoryItems
                            : AppRoutes.inventoryItemDetailPath(widget.itemId!),
                      ),
                    ),
                    AppButton(
                      label: 'حفظ المادة',
                      icon: Icons.save_outlined,
                      onPressed: state.saving ? null : () => _save(current),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _section(
                  title: 'المعلومات الأساسية',
                  child: Column(
                    children: <Widget>[
                      _field(_name, 'اسم المادة', required: true),
                      _row(<Widget>[
                        _field(_category, 'الفئة', required: true),
                        _select('النوع', _type, const <String, String>{
                          'stock_item': 'صنف مخزني',
                          'non_stock_item': 'صنف غير مخزني',
                          'service': 'خدمة',
                          'raw_material': 'مادة خام',
                          'packaging': 'تغليف',
                          'supply': 'مستلزمات',
                          'finished_good': 'منتج جاهز',
                          'other': 'أخرى',
                        }, (String value) => setState(() => _type = value)),
                      ]),
                      _row(<Widget>[
                        _field(_sku, 'SKU'),
                        _field(_barcode, 'الباركود'),
                      ]),
                      _field(_description, 'الوصف', lines: 3),
                    ],
                  ),
                ),
                _section(
                  title: 'الوحدات والتحويلات',
                  child: Column(
                    children: <Widget>[
                      _row(<Widget>[
                        _unitSelect(
                          'وحدة الشراء',
                          _purchaseUnit,
                          units,
                          (String value) =>
                              setState(() => _purchaseUnit = value),
                        ),
                        _unitSelect(
                          'وحدة التخزين الأساسية',
                          _baseUnit,
                          units,
                          (String value) => setState(() {
                            _baseUnit = value;
                            if (_purchaseUnit == 'piece') {
                              _purchaseUnit = value;
                            }
                            if (_consumptionUnit == 'piece') {
                              _consumptionUnit = value;
                            }
                          }),
                        ),
                        _unitSelect(
                          'وحدة الاستهلاك',
                          _consumptionUnit,
                          units,
                          (String value) =>
                              setState(() => _consumptionUnit = value),
                        ),
                      ]),
                      if (_purchaseUnit != _baseUnit)
                        _field(
                          _purchaseFactor,
                          '1 ${inventoryUnitLabel(_purchaseUnit)} = كم ${inventoryUnitLabel(_baseUnit)}؟',
                          number: true,
                          required: true,
                        ),
                      if (_consumptionUnit != _baseUnit)
                        _field(
                          _consumptionFactor,
                          '1 ${inventoryUnitLabel(_consumptionUnit)} = كم ${inventoryUnitLabel(_baseUnit)}؟',
                          number: true,
                          required: true,
                        ),
                    ],
                  ),
                ),
                _section(
                  title: 'قواعد المخزون',
                  child: Column(
                    children: <Widget>[
                      _row(<Widget>[
                        _field(_minimum, 'الحد الأدنى', number: true),
                        _field(_reorder, 'نقطة إعادة الطلب', number: true),
                      ]),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تتبع الصلاحية'),
                        value: _trackExpiry,
                        onChanged: (bool value) =>
                            setState(() => _trackExpiry = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تتبع الدفعات'),
                        value: _trackBatch,
                        onChanged: (bool value) =>
                            setState(() => _trackBatch = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('المادة نشطة'),
                        value: _active,
                        onChanged: (bool value) =>
                            setState(() => _active = value),
                      ),
                    ],
                  ),
                ),
                _section(
                  title: 'معلومات التكلفة',
                  child: Column(
                    children: <Widget>[
                      _row(<Widget>[
                        _field(_averageCost, 'متوسط التكلفة', number: true),
                        _field(
                          _lastPurchaseCost,
                          'آخر تكلفة شراء',
                          number: true,
                        ),
                      ]),
                      _field(_supplier, 'المورد المفضل'),
                    ],
                  ),
                ),
                _section(
                  title: 'إتاحة المخازن',
                  child: state.warehouses.isEmpty
                      ? const ManagementMessage(
                          message: 'لا توجد مخازن نشطة متاحة.',
                        )
                      : Wrap(
                          spacing: AppSpacing.lg,
                          runSpacing: AppSpacing.xs,
                          children: state.warehouses
                              .map(
                                (WarehouseLocation warehouse) => SizedBox(
                                  width: 260,
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(warehouse.displayName),
                                    value: _warehouseIds.contains(warehouse.id),
                                    onChanged: (bool? value) => setState(() {
                                      if (value ?? false) {
                                        _warehouseIds.add(warehouse.id);
                                      } else {
                                        _warehouseIds.remove(warehouse.id);
                                      }
                                    }),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _save(InventoryItem? current) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bool saved = await context
        .read<InventoryCubit>()
        .saveItem(<String, dynamic>{
          'nameAr': _name.text.trim(),
          'nameEn': _name.text.trim(),
          'category': _category.text.trim(),
          'sku': _sku.text.trim(),
          'barcode': _barcode.text.trim(),
          'notes': _description.text.trim(),
          'itemType': _type,
          'unit': _baseUnit,
          'purchaseUnit': _purchaseUnit,
          'purchaseConversionFactor': _purchaseFactor.text.trim(),
          'consumptionUnit': _consumptionUnit,
          'consumptionConversionFactor': _consumptionFactor.text.trim(),
          'minimumStock': _minimum.text.trim(),
          'reorderLevel': _reorder.text.trim(),
          'latestUnitCost': _averageCost.text.trim(),
          'lastPurchaseCost': _lastPurchaseCost.text.trim(),
          'preferredSupplierName': _supplier.text.trim(),
          'trackExpiry': _trackExpiry,
          'trackBatch': _trackBatch,
          'warehouseIds': _warehouseIds.toList(growable: false),
          'isActive': _active,
        }, id: current?.id);
    if (!mounted) {
      return;
    }
    if (saved) {
      context.go(
        current == null
            ? AppRoutes.inventoryItems
            : AppRoutes.inventoryItemDetailPath(current.id),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<InventoryCubit>().state.error ?? 'تعذر حفظ المادة',
          ),
        ),
      );
    }
  }

  Widget _section({required String title, required Widget child}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          constraints.maxWidth < 720
          ? Column(children: children)
          : Row(
              children: children
                  .map(
                    (Widget child) => Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.md,
                        ),
                        child: child,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (String? value) =>
                value == null || value.trim().isEmpty ? '$label مطلوب' : null
          : null,
    ),
  );
  Widget _select(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String> changed,
  ) {
    final Map<String, String> uniqueItems = <String, String>{
      for (final MapEntry<String, String> entry in items.entries)
        entry.key: entry.value,
    };
    final String? selectedValue = uniqueItems.containsKey(value) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>('$label:$selectedValue'),
        initialValue: selectedValue,
        decoration: InputDecoration(labelText: label),
        items: uniqueItems.entries
            .map(
              (MapEntry<String, String> entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(growable: false),
        onChanged: (String? next) {
          if (next != null) changed(next);
        },
      ),
    );
  }

  Widget _unitSelect(
    String label,
    String value,
    List<InventoryUnit> units,
    ValueChanged<String> changed,
  ) => _select(label, value, <String, String>{
    for (final InventoryUnit unit in units) unit.code: unit.label,
  }, changed);
}
