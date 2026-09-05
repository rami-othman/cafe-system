import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/management_ui.dart';
import '../../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../controllers/inventory_cubit.dart';
import '../../controllers/inventory_state.dart';
import '../../models/inventory_models.dart';
import '../widgets/transfer_status_chip.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key, this.transferId});
  final int? transferId;

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  String _search = '';
  String? _status;
  Timer? _searchDebounce;
  final Map<String, String> _idempotencyKeys = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<InventoryCubit>().loadTransfers(),
    );
  }

  @override
  void dispose() { _searchDebounce?.cancel(); super.dispose(); }

  void _load(BuildContext context, {int page = 1}) => context.read<InventoryCubit>().loadTransfers(search: _search, status: _status, page: page);

  String _key(String operation) => _idempotencyKeys.putIfAbsent(
    operation,
    () {
      final Random random = Random.secure();
      String segment(int length) => List<String>.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
      return '${segment(8)}-${segment(4)}-4${segment(3)}-a${segment(3)}-${segment(12)}';
    },
  );

  @override
  Widget build(BuildContext context) {
    return DesktopPageLayout(
      child: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (BuildContext context, InventoryState state) {
          if (widget.transferId == null) return _list(context, state);
          final WarehouseTransfer? selected = state.selectedTransfer;
          if (selected?.id != widget.transferId) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.read<InventoryCubit>().loadTransfer(widget.transferId!),
            );
            return const Center(child: CircularProgressIndicator());
          }
          return _detail(context, state, selected!);
        },
      ),
    );
  }

  Widget _list(BuildContext context, InventoryState state) {
    final List<WarehouseTransfer> rows = state.transfers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ManagementPageHeader(
          title: 'تحويلات المستودعات',
          subtitle: 'إنشاء ومتابعة التحويلات بين المستودعات.',
          actions: <Widget>[
            AppButton(
              label: 'إنشاء تحويل',
              icon: Icons.add,
              onPressed: state.warehouses.length < 2
                  ? null
                  : () => _create(context, state.warehouses),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _kpi('مسودات', state.transferMeta.kpis['draft'] ?? 0),
            _kpi('بانتظار الاعتماد', state.transferMeta.kpis['submitted'] ?? 0),
            _kpi('قيد النقل', state.transferMeta.kpis['inTransit'] ?? 0),
            _kpi('مستلمة', state.transferMeta.kpis['received'] ?? 0),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                onChanged: (String value) {
                  _search = value;
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 350), () => _load(context));
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث برقم التحويل أو المستودع',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            DropdownButton<String?>(
              value: _status,
              hint: const Text('الحالة'),
              items: const <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(value: null, child: Text('كل الحالات')),
                DropdownMenuItem<String?>(value: 'draft', child: Text('مسودة')),
                DropdownMenuItem<String?>(value: 'submitted', child: Text('مرسل')),
                DropdownMenuItem<String?>(value: 'approved', child: Text('معتمد')),
                DropdownMenuItem<String?>(value: 'dispatched', child: Text('مرسل للشحن')),
                DropdownMenuItem<String?>(value: 'partially_received', child: Text('استلام جزئي')),
                DropdownMenuItem<String?>(value: 'received', child: Text('مستلم')),
              ],
              onChanged: (String? value) { setState(() => _status = value); _load(context); },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(child: _listBody(context, state, rows)),
      ],
    );
  }

  Widget _listBody(BuildContext context, InventoryState state, List<WarehouseTransfer> rows) {
    if (state.loading && state.transfers.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.error != null && state.transfers.isEmpty) return ManagementMessage(message: state.error!, error: true, onRetry: () => context.read<InventoryCubit>().loadTransfers());
    if (rows.isEmpty) return const ManagementMessage(message: 'لا توجد تحويلات مطابقة.');
    return ManagementTableShell(
      child: DataTable(
        columns: const <DataColumn>[DataColumn(label: Text('الرقم')), DataColumn(label: Text('المصدر')), DataColumn(label: Text('الوجهة')), DataColumn(label: Text('الحالة')), DataColumn(label: Text(''))],
        rows: rows.map((WarehouseTransfer transfer) => DataRow(cells: <DataCell>[
          DataCell(Text(transfer.number)), DataCell(Text(transfer.sourceWarehouseName)), DataCell(Text(transfer.destinationWarehouseName)), DataCell(TransferStatusChip(status: transfer.status)), DataCell(TextButton(onPressed: () => context.go(AppRoutes.inventoryTransferPath(transfer.id)), child: const Text('فتح'))),
        ])).toList(),
      ),
    );
  }

  Widget _detail(BuildContext context, InventoryState state, WarehouseTransfer transfer) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      TextButton.icon(onPressed: () => context.go(AppRoutes.inventoryTransfers), icon: const Icon(Icons.arrow_back), label: const Text('العودة للتحويلات')),
      ManagementPageHeader(title: transfer.number, subtitle: '${transfer.sourceWarehouseName} ← ${transfer.destinationWarehouseName}', actions: <Widget>[TransferStatusChip(status: transfer.status)]),
      if (transfer.rejectionReason != null || transfer.discrepancyReason != null) AppCard(child: Text(transfer.rejectionReason ?? transfer.discrepancyReason!)),
      const SizedBox(height: AppSpacing.md),
      AppCard(child: Wrap(spacing: AppSpacing.md, children: transfer.auditTimeline.map((TransferTimelineEvent event) => Chip(label: Text('${event.status} · ${event.actor ?? '—'} · ${event.at}'))).toList())),
      const SizedBox(height: AppSpacing.md),
      Expanded(child: ManagementTableShell(child: DataTable(columns: const <DataColumn>[DataColumn(label: Text('الصنف')),DataColumn(label: Text('مطلوب')),DataColumn(label: Text('محجوز')),DataColumn(label: Text('مرسل')),DataColumn(label: Text('مستلم')),DataColumn(label: Text('قيد النقل')),DataColumn(label: Text('فرق'))], rows: transfer.lines.map((WarehouseTransferLine line) => DataRow(cells: <DataCell>[DataCell(Text(line.itemName)),DataCell(Text(line.requestedQuantity)),DataCell(Text(line.reservedQuantity)),DataCell(Text(line.dispatchedQuantity)),DataCell(Text(line.receivedQuantity)),DataCell(Text(line.inTransitQuantity)),DataCell(Text(line.discrepancyQuantity))])).toList()))),
      const SizedBox(height: AppSpacing.md),
      Wrap(spacing: AppSpacing.sm, children: <Widget>[
        if (transfer.canSubmit) AppButton(label: 'إرسال للاعتماد', onPressed: state.saving ? null : () => _action(context, transfer, 'submit')),
        if (transfer.canApprove) AppButton(label: 'اعتماد', onPressed: state.saving ? null : () => _action(context, transfer, 'approve')),
        if (transfer.canReject) AppButton(label: 'رفض', variant: AppButtonVariant.outlined, onPressed: state.saving ? null : () => _reason(context, transfer, 'reject', 'rejectionReason')),
        if (transfer.canDispatch) AppButton(label: 'إرسال الشحنة', onPressed: state.saving ? null : () => _action(context, transfer, 'dispatch')),
        if (transfer.canReceive) AppButton(label: 'استلام', onPressed: state.saving ? null : () => _receive(context, transfer)),
        if (transfer.canCloseShortage) AppButton(label: 'إغلاق الفرق', variant: AppButtonVariant.outlined, onPressed: state.saving ? null : () => _reason(context, transfer, 'close-shortage', 'discrepancyReason')),
        if (transfer.canCancel) AppButton(label: 'إلغاء', variant: AppButtonVariant.outlined, onPressed: state.saving ? null : () => _reason(context, transfer, 'cancel', 'cancellationReason')),
      ]),
    ]);
  }

  Widget _kpi(String label, int value) => AppCard(child: SizedBox(width: 145, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label), Text('$value', style: Theme.of(context).textTheme.headlineSmall)])));

  Future<void> _create(BuildContext context, List<WarehouseLocation> warehouses) async {
    final InventoryCubit cubit = context.read<InventoryCubit>();
    final _CreateDraft? draft = await showDialog<_CreateDraft>(context: context, builder: (_) => BlocProvider<InventoryCubit>.value(value: cubit, child: _CreateTransferDialog(warehouses)));
    if (draft == null || !context.mounted) return;
    final bool created = await cubit.createTransfer(<String, dynamic>{'sourceWarehouseId': draft.source, 'destinationWarehouseId': draft.destination, 'notes': draft.notes, 'lines': draft.lines, 'idempotencyKey': _key('create')});
    if (created && context.mounted) context.go(AppRoutes.inventoryTransferPath(cubit.state.selectedTransfer!.id));
  }

  Future<void> _action(BuildContext context, WarehouseTransfer transfer, String action) => context.read<InventoryCubit>().transferAction(transfer.id, action, <String, dynamic>{'idempotencyKey': _key('$action-${transfer.id}')});

  Future<void> _reason(BuildContext context, WarehouseTransfer transfer, String action, String field) async {
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(context: context, builder: (BuildContext dialog) => AlertDialog(title: Text(action == 'reject' ? 'سبب الرفض' : action == 'cancel' ? 'سبب الإلغاء' : 'سبب إغلاق العجز'), content: TextField(controller: controller, maxLines: 3), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(dialog, controller.text.trim().isNotEmpty), child: const Text('تأكيد'))]));
    if (confirmed == true && context.mounted) await context.read<InventoryCubit>().transferAction(transfer.id, action, <String, dynamic>{field: controller.text.trim(), 'idempotencyKey': _key('$action-${transfer.id}')});
    controller.dispose();
  }

  Future<void> _receive(BuildContext context, WarehouseTransfer transfer) async {
    final List<Map<String, dynamic>>? lines = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (_) => _ReceiveDialog(transfer));
    if (lines == null || !context.mounted) return;
    for (final line in lines) {
      final WarehouseTransferLine transferLine = transfer.lines.firstWhere((value) => value.itemId == line['itemId']);
      final double received = double.tryParse(line['receivedQuantity'] as String? ?? '') ?? 0;
      final double remaining = double.tryParse(transferLine.inTransitQuantity) ?? 0;
      if (received <= 0 || received > remaining || (received < remaining && (line['discrepancyReason'] as String? ?? '').trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من الكميات وأدخل سبباً عند الاستلام الجزئي.')));
        return;
      }
    }
    await context.read<InventoryCubit>().receiveTransfer(transfer.id, <String, dynamic>{'idempotencyKey': _key('receive-${transfer.id}'), 'lines': lines});
  }
}

class _Locations { const _Locations(this.source, this.destination); final int source; final int destination; }
class _CreateDraft { const _CreateDraft(this.source, this.destination, this.lines, this.notes); final int source; final int destination; final List<Map<String, dynamic>> lines; final String? notes; }
class _CreateTransferDialog extends StatefulWidget { const _CreateTransferDialog(this.warehouses); final List<WarehouseLocation> warehouses; @override State<_CreateTransferDialog> createState() => _CreateTransferDialogState(); }
class _CreateTransferDialogState extends State<_CreateTransferDialog> {
  int? _source; int? _destination; int? _itemId; final TextEditingController _quantity = TextEditingController(); final TextEditingController _notes = TextEditingController(); final List<Map<String, dynamic>> _lines = <Map<String, dynamic>>[];
  @override void dispose() { _quantity.dispose(); _notes.dispose(); super.dispose(); }
  InventoryItem? _item(List<InventoryItem> items, int? id) { for (final item in items) { if (item.id == id) return item; } return null; }
  void _add(List<InventoryItem> items) { final item = _item(items, _itemId); final quantity = double.tryParse(_quantity.text.trim()) ?? 0; if (item == null || quantity <= 0 || _lines.any((x) => x['itemId'] == item.id)) return; setState(() { _lines.add(<String, dynamic>{'itemId': item.id, 'requestedQuantity': quantity.toStringAsFixed(3), 'unit': item.unit}); _itemId = null; _quantity.clear(); }); }
  @override Widget build(BuildContext context) => BlocBuilder<InventoryCubit, InventoryState>(builder: (context, state) => AlertDialog(title: const Text('إنشاء تحويل'), content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[DropdownButtonFormField<int>(initialValue: _source, decoration: const InputDecoration(labelText: 'مستودع المصدر'), items: widget.warehouses.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: (value) { setState(() { _source = value; _destination = null; _lines.clear(); }); if (value != null) context.read<InventoryCubit>().loadTransferItems(value); }), const SizedBox(height: 12), DropdownButtonFormField<int>(initialValue: _destination, decoration: const InputDecoration(labelText: 'مستودع الوجهة'), items: widget.warehouses.where((x) => x.id != _source).map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: (value) => setState(() => _destination = value)), if (_source != null) ...<Widget>[const SizedBox(height: 12), Row(children: <Widget>[Expanded(child: DropdownButtonFormField<int>(initialValue: _itemId, decoration: const InputDecoration(labelText: 'الصنف المتاح في المصدر'), items: state.items.where((x) => !_lines.any((line) => line['itemId'] == x.id)).map((x) => DropdownMenuItem(value: x.id, child: Text('${x.name} (${x.availableQuantity} ${x.unit})'))).toList(), onChanged: (value) => setState(() => _itemId = value))), const SizedBox(width: 8), SizedBox(width: 120, child: TextField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية'))), IconButton(onPressed: () => _add(state.items), icon: const Icon(Icons.add_circle_outline))]), ..._lines.map((line) => ListTile(title: Text('${_item(state.items, line['itemId'] as int)?.name ?? line['itemId']} — ${line['requestedQuantity']}'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _lines.remove(line)))))], const SizedBox(height: 12), TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'))]))), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), TextButton(onPressed: _source == null || _destination == null || _lines.isEmpty ? null : () => Navigator.pop(context, _CreateDraft(_source!, _destination!, _lines, _notes.text.trim().isEmpty ? null : _notes.text.trim())), child: const Text('حفظ كمسودة'))]));
}
class _LocationDialog extends StatefulWidget { const _LocationDialog(this.warehouses); final List<WarehouseLocation> warehouses; @override State<_LocationDialog> createState() => _LocationDialogState(); }
class _LocationDialogState extends State<_LocationDialog> { int? _source; int? _destination; @override Widget build(BuildContext context) => AlertDialog(title: const Text('مستودعات التحويل'), content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[DropdownButtonFormField<int>(initialValue: _source, decoration: const InputDecoration(labelText: 'المصدر'), items: widget.warehouses.map((WarehouseLocation x) => DropdownMenuItem<int>(value: x.id, child: Text(x.name))).toList(), onChanged: (int? value) => setState(() => _source = value)), DropdownButtonFormField<int>(initialValue: _destination, decoration: const InputDecoration(labelText: 'الوجهة'), items: widget.warehouses.where((WarehouseLocation x) => x.id != _source).map((WarehouseLocation x) => DropdownMenuItem<int>(value: x.id, child: Text(x.name))).toList(), onChanged: (int? value) => setState(() => _destination = value))]), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), TextButton(onPressed: _source == null || _destination == null ? null : () => Navigator.pop(context, _Locations(_source!, _destination!)), child: const Text('إنشاء'))]); }
class _ReceiveDialog extends StatefulWidget { const _ReceiveDialog(this.transfer); final WarehouseTransfer transfer; @override State<_ReceiveDialog> createState() => _ReceiveDialogState(); }
class _ReceiveDialogState extends State<_ReceiveDialog> { late final Map<int, TextEditingController> _quantities; late final Map<int, TextEditingController> _reasons; List<WarehouseTransferLine> get _remaining => widget.transfer.lines.where((line) => (double.tryParse(line.inTransitQuantity) ?? 0) > 0).toList(); @override void initState() { super.initState(); _quantities = <int, TextEditingController>{for (final WarehouseTransferLine line in _remaining) line.itemId: TextEditingController(text: line.inTransitQuantity)}; _reasons = <int, TextEditingController>{for (final WarehouseTransferLine line in _remaining) line.itemId: TextEditingController()}; } @override void dispose() { for (final TextEditingController controller in <TextEditingController>[..._quantities.values, ..._reasons.values]) { controller.dispose(); } super.dispose(); } @override Widget build(BuildContext context) => AlertDialog(title: const Text('استلام التحويل'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _remaining.map((WarehouseTransferLine line) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('${line.itemName} — المتبقي ${line.inTransitQuantity} ${line.unit}'), TextField(controller: _quantities[line.itemId], decoration: const InputDecoration(labelText: 'المستلم الآن')), TextField(controller: _reasons[line.itemId], decoration: const InputDecoration(labelText: 'سبب الفرق عند الاستلام الجزئي')), const Divider()])).toList())), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(context, _remaining.map((WarehouseTransferLine line) => <String, dynamic>{'itemId': line.itemId, 'receivedQuantity': _quantities[line.itemId]!.text.trim(), 'unit': line.unit, if (_reasons[line.itemId]!.text.trim().isNotEmpty) 'discrepancyReason': _reasons[line.itemId]!.text.trim()}).toList()), child: const Text('تأكيد الاستلام'))]); }
