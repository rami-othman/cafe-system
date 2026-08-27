import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/management_ui.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../controllers/inventory_cubit.dart';
import '../controllers/inventory_state.dart';
import '../models/inventory_models.dart';

class BarCheckTemplatesScreen extends StatefulWidget {
  const BarCheckTemplatesScreen({super.key});
  @override
  State<BarCheckTemplatesScreen> createState() =>
      _BarCheckTemplatesScreenState();
}

class _BarCheckTemplatesScreenState extends State<BarCheckTemplatesScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => context.read<InventoryCubit>().loadBarCheckTemplates(),
    );
  }

  @override
  Widget build(BuildContext context) => _InventoryWorkflowPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (_, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ManagementPageHeader(
            title: 'قوالب فحص البار',
            subtitle: 'إعداد عناصر فحص البار لكل فرع ومستودع.',
            actions: <Widget>[
              AppButton(
                label: 'قالب جديد',
                icon: Icons.add,
                onPressed: state.warehouses.isEmpty
                    ? null
                    : () => _create(context, state.warehouses),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: state.loading && state.barCheckTemplates.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null && state.barCheckTemplates.isEmpty
                ? ManagementMessage(
                    message: state.error!,
                    error: true,
                    onRetry: () =>
                        context.read<InventoryCubit>().loadBarCheckTemplates(),
                  )
                : state.barCheckTemplates.isEmpty
                ? const ManagementMessage(
                    message: 'لا توجد قوالب فحص بار بعد. أنشئ قالباً للبدء.',
                  )
                : ManagementTableShell(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.menuTableHeader,
                      ),
                      columns: const <DataColumn>[
                        DataColumn(label: Text('القالب')),
                        DataColumn(label: Text('الفرع')),
                        DataColumn(label: Text('مستودع البار')),
                        DataColumn(label: Text('الحالة')),
                        DataColumn(label: Text('إغلاق الشفت')),
                        DataColumn(label: Text('')),
                      ],
                      rows: state.barCheckTemplates
                          .map(
                            (BarCheckTemplate template) => DataRow(
                              cells: <DataCell>[
                                DataCell(Text(template.name)),
                                DataCell(Text(template.branchName ?? '—')),
                                DataCell(Text(template.warehouseName ?? '—')),
                                DataCell(
                                  ManagementBadge(
                                    label: template.active ? 'نشط' : 'غير نشط',
                                    tone: template.active
                                        ? ManagementTone.success
                                        : ManagementTone.neutral,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    template.requiredForShiftClose
                                        ? 'مطلوب'
                                        : 'غير مطلوب',
                                  ),
                                ),
                                DataCell(
                                  TextButton(
                                    onPressed: () => context.go(
                                      AppRoutes.barCheckTemplatePath(
                                        template.id,
                                      ),
                                    ),
                                    child: const Text('فتح'),
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
  Future<void> _create(
    BuildContext context,
    List<WarehouseLocation> warehouses,
  ) async {
    final _NewBarTemplate? result = await showDialog<_NewBarTemplate>(
      context: context,
      builder: (_) => _NewBarTemplateDialog(warehouses: warehouses),
    );
    if (result == null || !context.mounted) return;
    final cubit = context.read<InventoryCubit>();
    final bool saved = await cubit.createBarCheckTemplate(<String, dynamic>{
      'branchId': result.warehouse.branchId,
      'warehouseId': result.warehouse.id,
      if (result.name.isNotEmpty) 'name': result.name,
      'active': true,
      'lines': const <dynamic>[],
    });
    if (!context.mounted) return;
    if (saved && cubit.state.selectedBarCheckTemplate != null)
      context.go(
        AppRoutes.barCheckTemplatePath(
          cubit.state.selectedBarCheckTemplate!.id,
        ),
      );
    else
      _message(context, cubit.state.error ?? 'تعذر إنشاء القالب', error: true);
  }
}

class BarCheckTemplateEditorScreen extends StatefulWidget {
  const BarCheckTemplateEditorScreen({super.key, required this.templateId});
  final int templateId;
  @override
  State<BarCheckTemplateEditorScreen> createState() =>
      _BarCheckTemplateEditorScreenState();
}

class _BarCheckTemplateEditorScreenState
    extends State<BarCheckTemplateEditorScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _search = TextEditingController();
  List<_EditableBarLine> _lines = <_EditableBarLine>[];
  bool _active = true;
  bool _requiredOnClose = false;
  bool _loaded = false;
  int _branchId = 0;
  int _warehouseId = 0;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final c = context.read<InventoryCubit>();
      await c.loadBarCheckTemplate(widget.templateId);
      if (!mounted) return;
      await c.loadBarCheckTemplates();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    for (final _EditableBarLine l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _sync(BarCheckTemplate? template) {
    if (_loaded || template == null) return;
    _loaded = true;
    _name.text = template.name;
    _active = template.active;
    _requiredOnClose = template.requiredForShiftClose;
    _branchId = template.branchId;
    _warehouseId = template.warehouseId;
    _lines = template.lines.map(_EditableBarLine.fromLine).toList();
  }

  @override
  Widget build(BuildContext context) => _InventoryWorkflowPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (_, state) {
        _sync(state.selectedBarCheckTemplate);
        final template = state.selectedBarCheckTemplate;
        if (state.loading && template == null)
          return const Center(child: CircularProgressIndicator());
        if (template == null)
          return ManagementMessage(
            message: state.error ?? 'تعذر تحميل قالب الفحص.',
            error: true,
            onRetry: () => context.read<InventoryCubit>().loadBarCheckTemplate(
              widget.templateId,
            ),
          );
        final available = state.items
            .where(
              (item) =>
                  !_lines.any((line) => line.item.id == item.id) &&
                  (_search.text.isEmpty ||
                      item.name.toLowerCase().contains(
                        _search.text.toLowerCase(),
                      ) ||
                      item.sku.toLowerCase().contains(
                        _search.text.toLowerCase(),
                      )),
            )
            .toList();
        final branchWarehouses = state.warehouses
            .where((warehouse) => warehouse.branchId == _branchId)
            .toList();
        final branches = <int, String>{
          for (final warehouse in state.warehouses)
            if (warehouse.branchId != null)
              warehouse.branchId!: warehouse.branchName ?? warehouse.name,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'إدارة المخزون / فحص البار / ${template.name}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ManagementPageHeader(
              title: 'قالب فحص البار',
              subtitle:
                  '${template.branchName ?? ''} — ${template.warehouseName ?? ''}',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: <Widget>[
                  SizedBox(
                    width: 310,
                    child: TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'اسم القالب',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<int>(
                      value: branches.containsKey(_branchId) ? _branchId : null,
                      decoration: const InputDecoration(
                        labelText: 'الفرع',
                        border: OutlineInputBorder(),
                      ),
                      items: branches.entries
                          .map(
                            (entry) => DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (branchId) {
                        if (branchId == null) return;
                        final nextWarehouse = state.warehouses.firstWhere(
                          (warehouse) => warehouse.branchId == branchId,
                        );
                        setState(() {
                          _branchId = branchId;
                          _warehouseId = nextWarehouse.id;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<int>(
                      value:
                          branchWarehouses.any(
                            (warehouse) => warehouse.id == _warehouseId,
                          )
                          ? _warehouseId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'مستودع البار',
                        border: OutlineInputBorder(),
                      ),
                      items: branchWarehouses
                          .map(
                            (warehouse) => DropdownMenuItem<int>(
                              value: warehouse.id,
                              child: Text(warehouse.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (warehouseId) {
                        if (warehouseId != null)
                          setState(() => _warehouseId = warehouseId);
                      },
                    ),
                  ),
                  FilterChip(
                    label: const Text('نشط'),
                    selected: _active,
                    onSelected: (v) => setState(() => _active = v),
                  ),
                  FilterChip(
                    label: const Text('مطلوب عند إغلاق الشفت'),
                    selected: _requiredOnClose,
                    onSelected: (v) => setState(() => _requiredOnClose = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: AppSpacing.allMd,
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث عن عنصر مخزني لإضافته...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_search.text.isNotEmpty && available.isNotEmpty)
                    ...available
                        .take(6)
                        .map(
                          (item) => ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              item.sku,
                              textDirection: TextDirection.ltr,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() {
                                _lines.add(_EditableBarLine(item));
                                _search.clear();
                              }),
                            ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _lines.isEmpty
                  ? const ManagementMessage(
                      message: 'أضف عناصر مخزنية إلى القالب.',
                    )
                  : ManagementTableShell(
                      verticalScroll: true,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.menuTableHeader,
                        ),
                        columns: const <DataColumn>[
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('العنصر')),
                          DataColumn(label: Text('وحدة العد')),
                          DataColumn(label: Text('مطلوب')),
                          DataColumn(label: Text('نوع التفاوت')),
                          DataColumn(label: Text('التفاوت المسموح')),
                          DataColumn(label: Text('مراجعة عند التجاوز')),
                          DataColumn(label: Text('')),
                        ],
                        rows: _lines
                            .map(
                              (line) => DataRow(
                                cells: <DataCell>[
                                  DataCell(
                                    Text(
                                      line.item.sku,
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ),
                                  DataCell(Text(line.item.name)),
                                  DataCell(Text(line.item.unit)),
                                  DataCell(
                                    Checkbox(
                                      value: line.required,
                                      onChanged: (v) => setState(
                                        () => line.required = v ?? true,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    DropdownButton<String>(
                                      value: line.toleranceType,
                                      items: const <DropdownMenuItem<String>>[
                                        DropdownMenuItem(
                                          value: 'quantity',
                                          child: Text('كمية'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'percentage',
                                          child: Text('نسبة %'),
                                        ),
                                      ],
                                      onChanged: (v) => setState(
                                        () => line.toleranceType = v!,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: line.tolerance,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Checkbox(
                                      value: line.review,
                                      onChanged: (v) => setState(
                                        () => line.review = v ?? false,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => setState(() {
                                        line.dispose();
                                        _lines.remove(line);
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: AppSpacing.allMd,
              child: Row(
                children: <Widget>[
                  AppButton(
                    label: 'حفظ القالب',
                    onPressed: state.saving ? null : () => _save(context),
                  ),
                  const Spacer(),
                  Text(
                    'اختر فقط العناصر التي تحتاج إلى فحص تشغيلي.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  Future<void> _save(BuildContext context) async {
    for (final line in _lines) {
      final value = double.tryParse(line.tolerance.text);
      if (value == null ||
          value < 0 ||
          (line.toleranceType == 'percentage' && value > 100)) {
        _message(context, 'أدخل تفاوتاً صالحاً.', error: true);
        return;
      }
    }
    final saved = await context
        .read<InventoryCubit>()
        .updateBarCheckTemplate(widget.templateId, <String, dynamic>{
          'name': _name.text.trim(),
          'branchId': _branchId,
          'warehouseId': _warehouseId,
          'active': _active,
          'requiredForShiftClose': _requiredOnClose,
          'lines': _lines.map((l) => l.toJson()).toList(),
        });
    if (!context.mounted) return;
    _message(
      context,
      saved
          ? 'تم حفظ قالب الفحص.'
          : (context.read<InventoryCubit>().state.error ?? 'تعذر الحفظ'),
      error: !saved,
    );
  }
}

class InventoryTransfersWorkspaceScreen extends StatefulWidget {
  const InventoryTransfersWorkspaceScreen({super.key, this.transferId});
  final int? transferId;
  @override
  State<InventoryTransfersWorkspaceScreen> createState() =>
      _InventoryTransfersWorkspaceScreenState();
}

class _InventoryTransfersWorkspaceScreenState
    extends State<InventoryTransfersWorkspaceScreen> {
  WarehouseTransfer? _transfer;
  final TextEditingController _notes = TextEditingController();
  final Map<int, TextEditingController> _quantities =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _received =
      <int, TextEditingController>{};
  String _itemSearch = '';
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => context.read<InventoryCubit>().loadTransfers(),
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final c in <TextEditingController>[
      ..._quantities.values,
      ..._received.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync(WarehouseTransfer? value) {
    if (value == null || _transfer?.id == value.id) return;
    _transfer = value;
    _notes.text = value.notes ?? '';
    for (final line in value.lines) {
      _quantities.putIfAbsent(
        line.itemId,
        () => TextEditingController(text: line.requestedQuantity),
      );
      _received.putIfAbsent(
        line.itemId,
        () => TextEditingController(text: _remaining(line)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _InventoryWorkflowPage(
    child: BlocBuilder<InventoryCubit, InventoryState>(
      builder: (_, state) {
        if (widget.transferId == null && _transfer == null)
          return _list(context, state);
        if (widget.transferId != null &&
            state.selectedTransfer?.id != widget.transferId) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) =>
                context.read<InventoryCubit>().loadTransfer(widget.transferId!),
          );
          return const Center(child: CircularProgressIndicator());
        }
        _sync(state.selectedTransfer);
        final transfer = _transfer!;
        return _workspace(context, state, transfer);
      },
    ),
  );
  Widget _list(BuildContext context, InventoryState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      ManagementPageHeader(
        title: 'تحويلات المستودعات',
        subtitle: 'إنشاء ومتابعة التحويلات بين المستودعات التشغيلية.',
        actions: <Widget>[
          AppButton(
            label: 'إنشاء تحويل',
            icon: Icons.add,
            onPressed: state.warehouses.length < 2
                ? null
                : () => _newTransfer(context, state.warehouses),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Expanded(
        child: state.loading && state.transfers.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.transfers.isEmpty
            ? ManagementMessage(
                message: state.error!,
                error: true,
                onRetry: () => context.read<InventoryCubit>().loadTransfers(),
              )
            : state.transfers.isEmpty
            ? const ManagementMessage(
                message: 'لا توجد تحويلات مخزون ضمن النطاق المحدد.',
              )
            : ManagementTableShell(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.menuTableHeader,
                  ),
                  columns: const <DataColumn>[
                    DataColumn(label: Text('رقم التحويل')),
                    DataColumn(label: Text('المصدر')),
                    DataColumn(label: Text('الوجهة')),
                    DataColumn(label: Text('الحالة')),
                    DataColumn(label: Text('')),
                  ],
                  rows: state.transfers
                      .map(
                        (t) => DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Text(t.number, textDirection: TextDirection.ltr),
                            ),
                            DataCell(Text(t.sourceWarehouseName)),
                            DataCell(Text(t.destinationWarehouseName)),
                            DataCell(_status(t.status)),
                            DataCell(
                              TextButton(
                                onPressed: () => context.go(
                                  AppRoutes.inventoryTransferPath(t.id),
                                ),
                                child: const Text('فتح'),
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
  Widget _workspace(
    BuildContext context,
    InventoryState state,
    WarehouseTransfer t,
  ) {
    final editable = t.status == 'draft';
    final receiving =
        t.status == 'in_transit' || t.status == 'partially_received';
    final sent = t.lines.fold<double>(
      0,
      (v, l) => v + (double.tryParse(l.dispatchedQuantity) ?? 0),
    );
    final got = t.lines.fold<double>(
      0,
      (v, l) => v + (double.tryParse(l.receivedQuantity) ?? 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'إدارة المخزون / تحويلات المستودعات / ${t.number}',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        ManagementPageHeader(
          title: receiving ? 'استلام التحويل' : 'مساحة عمل التحويل',
          subtitle: '${t.sourceWarehouseName} ← ${t.destinationWarehouseName}',
          actions: <Widget>[
            if (['draft', 'pending_approval', 'approved'].contains(t.status))
              AppButton(
                label: 'إلغاء التحويل',
                variant: AppButtonVariant.outlined,
                onPressed: state.saving
                    ? null
                    : () => _action(context, 'cancel'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: AppSpacing.allMd,
          child: Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _meta('رقم التحويل', t.number),
              _meta('المستودع المصدر', t.sourceWarehouseName),
              _meta('المستودع الوجهة', t.destinationWarehouseName),
              _status(t.status),
              _meta('تاريخ الطلب', t.createdAt ?? '—'),
              if (t.approvedAt != null) _meta('تاريخ الاعتماد', t.approvedAt!),
              if (t.dispatchedAt != null)
                _meta('تاريخ الإرسال', t.dispatchedAt!),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (receiving)
          _transferSummary(
            sent,
            got,
            sent - got,
            t.lines.fold<double>(
              0,
              (v, l) => v + (double.tryParse(l.discrepancyQuantity) ?? 0),
            ),
          ),
        if (receiving) const SizedBox(height: AppSpacing.md),
        if (editable) _addItem(context, state, t),
        if (editable) const SizedBox(height: AppSpacing.md),
        Expanded(
          child: t.lines.isEmpty
              ? const ManagementMessage(
                  message: 'أضف عناصر إلى التحويل قبل إرساله.',
                )
              : ManagementTableShell(
                  verticalScroll: true,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.menuTableHeader,
                    ),
                    columns: <DataColumn>[
                      const DataColumn(label: Text('العنصر')),
                      const DataColumn(label: Text('SKU')),
                      const DataColumn(label: Text('الوحدة')),
                      const DataColumn(label: Text('المتاح بالمصدر')),
                      const DataColumn(label: Text('المطلوب')),
                      if (!editable)
                        const DataColumn(label: Text('تم الإرسال')),
                      if (!editable)
                        const DataColumn(label: Text('تم الاستلام')),
                      if (receiving)
                        const DataColumn(label: Text('استلام الآن')),
                      if (editable) const DataColumn(label: Text('')),
                    ],
                    rows: t.lines
                        .map(
                          (line) => DataRow(
                            cells: <DataCell>[
                              DataCell(Text(line.itemName)),
                              DataCell(
                                Text(
                                  line.sku,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              DataCell(Text(line.unit)),
                              DataCell(Text(line.availableQuantity)),
                              DataCell(
                                editable
                                    ? SizedBox(
                                        width: 110,
                                        child: TextField(
                                          controller: _quantities[line.itemId],
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      )
                                    : Text(line.requestedQuantity),
                              ),
                              if (!editable)
                                DataCell(Text(line.dispatchedQuantity)),
                              if (!editable)
                                DataCell(Text(line.receivedQuantity)),
                              if (receiving)
                                DataCell(
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _received[line.itemId],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                              if (editable)
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _removeLine(line.itemId),
                                  ),
                                ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: AppSpacing.allMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('ملاحظات'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notes,
                enabled: editable,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'ملاحظات اختيارية حول هذا التحويل',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  if (editable)
                    AppButton(
                      label: 'حفظ كمسودة',
                      variant: AppButtonVariant.outlined,
                      onPressed: state.saving
                          ? null
                          : () => _saveDraft(context),
                    ),
                  if (editable) const SizedBox(width: AppSpacing.md),
                  if (editable)
                    AppButton(
                      label: 'إرسال للاعتماد',
                      onPressed: state.saving ? null : () => _submit(context),
                    ),
                  if (t.status == 'pending_approval' || t.status == 'approved')
                    AppButton(
                      label: 'إرسال التحويل',
                      onPressed: state.saving
                          ? null
                          : () => _action(context, 'dispatch'),
                    ),
                  if (receiving)
                    AppButton(
                      label: 'استلام التحويل',
                      onPressed: state.saving ? null : () => _receive(context),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addItem(
    BuildContext context,
    InventoryState state,
    WarehouseTransfer t,
  ) {
    final choices = state.items
        .where(
          (i) =>
              i.warehouseIds.contains(t.sourceWarehouseId) &&
              !t.lines.any((l) => l.itemId == i.id) &&
              (_itemSearch.isEmpty ||
                  i.name.toLowerCase().contains(_itemSearch.toLowerCase()) ||
                  i.sku.toLowerCase().contains(_itemSearch.toLowerCase())),
        )
        .toList();
    return AppCard(
      padding: AppSpacing.allMd,
      child: Column(
        children: <Widget>[
          TextField(
            onChanged: (v) => setState(() => _itemSearch = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'إضافة عنصر إلى التحويل...',
              border: OutlineInputBorder(),
            ),
          ),
          if (_itemSearch.isNotEmpty)
            ...choices
                .take(5)
                .map(
                  (item) => ListTile(
                    title: Text(item.name),
                    subtitle: Text(item.sku, textDirection: TextDirection.ltr),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _addLine(item),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _newTransfer(
    BuildContext context,
    List<WarehouseLocation> warehouses,
  ) async {
    final selection = await showDialog<_TransferLocations>(
      context: context,
      builder: (_) => _TransferLocationsDialog(warehouses: warehouses),
    );
    if (selection == null || !context.mounted) return;
    final c = context.read<InventoryCubit>();
    final saved = await c.createTransfer(<String, dynamic>{
      'sourceWarehouseId': selection.source.id,
      'destinationWarehouseId': selection.destination.id,
    });
    if (!context.mounted) return;
    if (saved && c.state.selectedTransfer != null)
      context.go(AppRoutes.inventoryTransferPath(c.state.selectedTransfer!.id));
    else
      _message(context, c.state.error ?? 'تعذر إنشاء التحويل', error: true);
  }

  Future<void> _addLine(InventoryItem item) async {
    final t = _transfer!;
    final lines = <Map<String, dynamic>>[
      ...t.lines.map(
        (l) => <String, dynamic>{
          'itemId': l.itemId,
          'requestedQuantity':
              _quantities[l.itemId]?.text ?? l.requestedQuantity,
        },
      ),
      <String, dynamic>{'itemId': item.id, 'requestedQuantity': '1'},
    ];
    await _update(<String, dynamic>{'lines': lines});
  }

  Future<void> _removeLine(int itemId) async {
    final t = _transfer!;
    await _update(<String, dynamic>{
      'lines': t.lines
          .where((l) => l.itemId != itemId)
          .map(
            (l) => <String, dynamic>{
              'itemId': l.itemId,
              'requestedQuantity':
                  _quantities[l.itemId]?.text ?? l.requestedQuantity,
            },
          )
          .toList(),
    });
  }

  Future<void> _saveDraft(BuildContext context) => _update(<String, dynamic>{
    'notes': _notes.text.trim(),
    'lines': _transfer!.lines
        .map(
          (l) => <String, dynamic>{
            'itemId': l.itemId,
            'requestedQuantity':
                _quantities[l.itemId]?.text ?? l.requestedQuantity,
          },
        )
        .toList(),
  }, context: context);
  Future<void> _update(
    Map<String, dynamic> data, {
    BuildContext? context,
  }) async {
    final ok = await this.context.read<InventoryCubit>().updateTransfer(
      _transfer!.id,
      data,
    );
    if (!mounted) return;
    if (ok) {
      setState(
        () => _transfer = this.context
            .read<InventoryCubit>()
            .state
            .selectedTransfer,
      );
      if (context != null) _message(context, 'تم حفظ المسودة.');
    } else
      _message(
        this.context,
        this.context.read<InventoryCubit>().state.error ?? 'تعذر حفظ المسودة',
        error: true,
      );
  }

  Future<void> _submit(BuildContext context) async {
    await _saveDraft(context);
    if (!mounted) return;
    await _action(context, 'submit');
  }

  Future<void> _action(BuildContext context, String action) async {
    final ok = await context.read<InventoryCubit>().transferAction(
      _transfer!.id,
      action,
    );
    if (!mounted) return;
    if (ok)
      setState(
        () => _transfer = context.read<InventoryCubit>().state.selectedTransfer,
      );
    _message(
      context,
      ok
          ? 'تم تحديث حالة التحويل.'
          : (context.read<InventoryCubit>().state.error ??
                'تعذر تحديث التحويل'),
      error: !ok,
    );
  }

  Future<void> _receive(BuildContext context) async {
    final lines = _transfer!.lines
        .map(
          (l) => <String, dynamic>{
            'itemId': l.itemId,
            'receivedQuantity': _received[l.itemId]?.text ?? _remaining(l),
          },
        )
        .toList();
    final ok = await context
        .read<InventoryCubit>()
        .receiveTransfer(_transfer!.id, <String, dynamic>{
          'idempotencyKey': 'desktop-${DateTime.now().microsecondsSinceEpoch}',
          'lines': lines,
        });
    if (!mounted) return;
    if (ok)
      setState(
        () => _transfer = context.read<InventoryCubit>().state.selectedTransfer,
      );
    _message(
      context,
      ok
          ? 'تم استلام التحويل.'
          : (context.read<InventoryCubit>().state.error ??
                'تعذر استلام التحويل'),
      error: !ok,
    );
  }

  String _remaining(WarehouseTransferLine l) =>
      ((double.tryParse(l.dispatchedQuantity) ?? 0) -
              (double.tryParse(l.receivedQuantity) ?? 0))
          .toStringAsFixed(3);
}

class _NewBarTemplate {
  const _NewBarTemplate(this.warehouse, this.name);
  final WarehouseLocation warehouse;
  final String name;
}

class _NewBarTemplateDialog extends StatefulWidget {
  const _NewBarTemplateDialog({required this.warehouses});
  final List<WarehouseLocation> warehouses;
  @override
  State<_NewBarTemplateDialog> createState() => _NewBarTemplateDialogState();
}

class _NewBarTemplateDialogState extends State<_NewBarTemplateDialog> {
  late WarehouseLocation _warehouse = widget.warehouses.first;
  final TextEditingController _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('قالب جديد'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<WarehouseLocation>(
            value: _warehouse,
            isExpanded: true,
            items: widget.warehouses
                .map(
                  (w) => DropdownMenuItem(value: w, child: Text(w.displayName)),
                )
                .toList(),
            onChanged: (w) => setState(() => _warehouse = w!),
            decoration: const InputDecoration(
              labelText: 'مستودع البار',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'اسم القالب (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      AppButton(
        label: 'إنشاء القالب',
        onPressed: () => Navigator.pop(
          context,
          _NewBarTemplate(_warehouse, _name.text.trim()),
        ),
      ),
    ],
  );
}

class _TransferLocations {
  const _TransferLocations(this.source, this.destination);
  final WarehouseLocation source;
  final WarehouseLocation destination;
}

class _TransferLocationsDialog extends StatefulWidget {
  const _TransferLocationsDialog({required this.warehouses});
  final List<WarehouseLocation> warehouses;
  @override
  State<_TransferLocationsDialog> createState() =>
      _TransferLocationsDialogState();
}

class _TransferLocationsDialogState extends State<_TransferLocationsDialog> {
  late WarehouseLocation _source = widget.warehouses.first;
  late WarehouseLocation _destination = widget.warehouses.firstWhere(
    (w) => w.id != _source.id,
  );
  @override
  Widget build(BuildContext context) {
    Widget select(
      String label,
      WarehouseLocation value,
      ValueChanged<WarehouseLocation?> change,
    ) => DropdownButtonFormField<WarehouseLocation>(
      value: value,
      isExpanded: true,
      items: widget.warehouses
          .map((w) => DropdownMenuItem(value: w, child: Text(w.displayName)))
          .toList(),
      onChanged: change,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
    return AlertDialog(
      title: const Text('إنشاء تحويل'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            select(
              'المستودع المصدر',
              _source,
              (v) => setState(() => _source = v!),
            ),
            const SizedBox(height: AppSpacing.md),
            select(
              'المستودع الوجهة',
              _destination,
              (v) => setState(() => _destination = v!),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        AppButton(
          label: 'إنشاء',
          onPressed: _source.id == _destination.id
              ? null
              : () => Navigator.pop(
                  context,
                  _TransferLocations(_source, _destination),
                ),
        ),
      ],
    );
  }
}

class _EditableBarLine {
  _EditableBarLine(
    this.item, {
    this.required = true,
    this.toleranceType = 'quantity',
    String tolerance = '0',
    this.review = false,
  }) : tolerance = TextEditingController(text: tolerance);
  factory _EditableBarLine.fromLine(BarCheckTemplateLine l) => _EditableBarLine(
    InventoryItem(
      id: l.itemId,
      name: l.itemName,
      sku: l.sku,
      unit: l.countUnit,
      itemType: '',
      category: '',
      quantity: '0',
      availableQuantity: '0',
      cost: '0',
      reorderLevel: '0',
      minimumStock: '0',
      active: true,
    ),
    required: l.required,
    toleranceType: l.toleranceType,
    tolerance: l.tolerance,
    review: l.requiresReviewWhenExceeded,
  );
  final InventoryItem item;
  bool required;
  String toleranceType;
  final TextEditingController tolerance;
  bool review;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemId': item.id,
    'countUnit': item.unit,
    'required': required,
    'toleranceType': toleranceType,
    'tolerance': tolerance.text.trim(),
    'requiresReviewWhenExceeded': review,
  };
  void dispose() => tolerance.dispose();
}

class _InventoryWorkflowPage extends StatelessWidget {
  const _InventoryWorkflowPage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DesktopPageLayout(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
      AppSizes.inventoryContentHorizontalPadding,
      AppSizes.inventoryContentVerticalPadding,
    ),
    child: child,
  );
}

Widget _meta(String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    Text(label, style: AppTextStyles.labelSmall),
    const SizedBox(height: AppSpacing.xs),
    Text(value, style: AppTextStyles.labelLarge),
  ],
);
Widget _status(String status) {
  final Map<String, (String, ManagementTone)> labels =
      <String, (String, ManagementTone)>{
        'draft': ('مسودة', ManagementTone.neutral),
        'pending_approval': ('قيد الاعتماد', ManagementTone.warning),
        'approved': ('معتمد', ManagementTone.info),
        'in_transit': ('قيد النقل', ManagementTone.info),
        'partially_received': ('استلام جزئي', ManagementTone.warning),
        'received': ('تم الاستلام', ManagementTone.success),
        'cancelled': ('ملغى', ManagementTone.danger),
      };
  final v = labels[status] ?? (status, ManagementTone.neutral);
  return ManagementBadge(label: v.$1, tone: v.$2);
}

Widget _transferSummary(
  double sent,
  double received,
  double remaining,
  double discrepancy,
) => AppCard(
  padding: EdgeInsets.zero,
  child: Row(
    children: <Widget>[
      _summary('الكمية المرسلة', sent, AppColors.textPrimary),
      _summary('الكمية المستلمة', received, AppColors.info),
      _summary('المتبقي قيد النقل', remaining, AppColors.textPrimary),
      _summary('كميات بها مشكلة', discrepancy, AppColors.danger),
    ],
  ),
);
Widget _summary(String label, double value, Color color) => Expanded(
  child: Padding(
    padding: AppSpacing.allMd,
    child: Column(
      children: <Widget>[
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value.toStringAsFixed(3),
          style: AppTextStyles.titleMedium.copyWith(color: color),
        ),
      ],
    ),
  ),
);
void _message(BuildContext context, String message, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
