import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/controllers/finance_setup_cubit.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/repositories/finance_setup_repository.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../controllers/sales_cubit.dart';
import '../models/sales_models.dart';
import '../repositories/sales_repository.dart';

/// §32 — "الإشعارات الدائنة / المرتجعات" tab: every posted/draft Credit Note,
/// each linked to its original invoice (§1 — the original stays untouched).
class SalesCreditNotesScreen extends StatefulWidget { const SalesCreditNotesScreen({super.key}); @override State<SalesCreditNotesScreen> createState() => _SalesCreditNotesScreenState(); }
class _SalesCreditNotesScreenState extends State<SalesCreditNotesScreen> {
  List<SalesCreditNote>? notes; Object? error;
  SalesCubit get cubit => context.read<SalesCubit>();
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final result = await cubit.repository.creditNotes();
      if (mounted) setState(() { notes = result; error = null; });
    } catch (e) { if (mounted) setState(() => error = e); }
  }
  @override Widget build(BuildContext context) => FinanceShell(title: 'الإشعارات الدائنة / المرتجعات', subtitle: 'كل إشعار دائن مرتبط بفاتورة أصلية ثابتة؛ الفاتورة الأصلية لا تُعدَّل أبداً.', child: _body());
  Widget _body() {
    if (notes == null) return error == null ? const FinanceLoadingState(label: 'جارٍ تحميل الإشعارات الدائنة…') : FinanceErrorState(message: 'تعذر تحميل الإشعارات الدائنة.', onRetry: load);
    if (notes!.isEmpty) return const FinanceEmptyState(message: 'لا توجد إشعارات دائنة بعد. أنشئ مرتجعاً من تفاصيل فاتورة مرحّلة.');
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const <DataColumn>[DataColumn(label: Text('رقم الإشعار')), DataColumn(label: Text('الفاتورة الأصلية')), DataColumn(label: Text('العميل')), DataColumn(label: Text('التاريخ')), DataColumn(label: Text('الإجمالي')), DataColumn(label: Text('الحالة'))], rows: notes!.map((n) => DataRow(onSelectChanged: (_) => context.go('/finance/sales/credit-notes/${n.id}'), cells: <DataCell>[DataCell(Text(n.creditNoteNumber)), DataCell(Text(n.originalInvoiceNumber)), DataCell(Text(n.customerName)), DataCell(Text(n.creditDate)), DataCell(Text(n.total)), DataCell(_statusChip(n.status))])).toList()));
  }
  Widget _statusChip(String s) => Chip(label: Text(s == 'draft' ? 'مسودة' : (s == 'posted' ? 'مُرحّل' : 'ملغى')));
}

/// §33 — "+ إنشاء مرتجع / إشعار دائن": returnable quantities are server-
/// authoritative (§5); the user cannot exceed them here, and the same limit
/// is re-enforced, locked, at posting time regardless of what this screen shows.
class CreateCreditNoteScreen extends StatefulWidget {
  const CreateCreditNoteScreen({super.key, required this.invoiceId, required this.customerName});
  final int invoiceId; final String customerName;
  @override State<CreateCreditNoteScreen> createState() => _CreateCreditNoteScreenState();
}
class _CreateCreditNoteScreenState extends State<CreateCreditNoteScreen> {
  List<ReturnableInvoiceLine> lines = const <ReturnableInvoiceLine>[];
  final Map<int, TextEditingController> quantity = <int, TextEditingController>{};
  final Map<int, bool> restock = <int, bool>{};
  final reason = TextEditingController();
  bool loading = true; bool saving = false; Object? error;
  SalesCubit get cubit => context.read<SalesCubit>();
  @override void initState() { super.initState(); load(); }
  @override void dispose() { reason.dispose(); for (final c in quantity.values) { c.dispose(); } super.dispose(); }
  Future<void> load() async {
    try {
      final result = await cubit.repository.returnableLines(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        lines = result.where((l) => double.tryParse(l.returnable) != null && double.parse(l.returnable) > 0).toList();
        for (final l in lines) { quantity[l.originalSalesInvoiceLineId] = TextEditingController(); restock[l.originalSalesInvoiceLineId] = l.isStockTracked; }
        loading = false;
      });
    } catch (e) { if (mounted) setState(() { error = e; loading = false; }); }
  }
  Future<void> submit() async {
    final selected = lines.where((l) => (double.tryParse(quantity[l.originalSalesInvoiceLineId]!.text) ?? 0) > 0).toList();
    if (selected.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدد كمية لبند واحد على الأقل.'))); return; }
    setState(() => saving = true);
    try {
      final note = await cubit.repository.saveCreditNote(<String, dynamic>{
        'originalSalesInvoiceId': widget.invoiceId,
        if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim(),
        'idempotencyKey': 'cn-${DateTime.now().microsecondsSinceEpoch}',
        'lines': selected.map((l) => <String, dynamic>{'originalSalesInvoiceLineId': l.originalSalesInvoiceLineId, 'quantity': quantity[l.originalSalesInvoiceLineId]!.text.trim(), 'restock': restock[l.originalSalesInvoiceLineId] ?? false}).toList(),
      });
      if (mounted) context.go('/finance/sales/credit-notes/${note.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء الإشعار الدائن: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  @override Widget build(BuildContext context) => FinanceShell(
    title: 'إنشاء مرتجع / إشعار دائن', subtitle: 'العميل: ${widget.customerName} — الفاتورة الأصلية تبقى دون تعديل؛ هذا مستند منفصل مرتبط بها.',
    actions: <Widget>[ElevatedButton.icon(onPressed: (loading || saving) ? null : submit, icon: const Icon(Icons.save), label: Text(saving ? 'جارٍ الحفظ…' : 'إنشاء كمسودة'))],
    child: loading
        ? const FinanceLoadingState(label: 'جارٍ تحميل بنود الفاتورة…')
        : error != null
            ? FinanceErrorState(message: 'تعذر تحميل بنود الفاتورة.', onRetry: load)
            : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب (اختياري)')),
                const SizedBox(height: 18),
                if (lines.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('لا توجد كميات قابلة للإرجاع على هذه الفاتورة.')),
                ...lines.map((l) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: <Widget>[
                      Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(l.productName, style: FinanceText.body), Text('الكمية الأصلية: ${l.originalQuantity} — تم إرجاعها: ${l.alreadyReturned} — القابل للإرجاع: ${l.returnable}', style: FinanceText.small)])),
                      SizedBox(width: 120, child: TextField(controller: quantity[l.originalSalesInvoiceLineId], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية المرتجعة الآن', isDense: true))),
                      const SizedBox(width: 12),
                      if (l.isStockTracked) Column(children: <Widget>[const Text('إعادة للمخزون؟', style: FinanceText.small), Switch(value: restock[l.originalSalesInvoiceLineId] ?? false, onChanged: (v) => setState(() => restock[l.originalSalesInvoiceLineId] = v))])
                      else const Text('خدمة — بدون مخزون', style: FinanceText.small),
                    ])))),
              ])),
  );
}

/// §34 — Credit Note detail: financial reversal, COGS reversal, inventory
/// movements and refund status in one place, plus the posting preview/post
/// action mirroring the Sales Invoice detail screen's own flow.
class SalesCreditNoteDetailScreen extends StatefulWidget { const SalesCreditNoteDetailScreen({super.key, required this.id}); final int id; @override State<SalesCreditNoteDetailScreen> createState() => _SalesCreditNoteDetailScreenState(); }
class _SalesCreditNoteDetailScreenState extends State<SalesCreditNoteDetailScreen> {
  SalesCreditNote? note; Object? error;
  SalesCubit get cubit => context.read<SalesCubit>();
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { final r = await cubit.repository.creditNote(widget.id); if (mounted) setState(() { note = r; error = null; }); } catch (e) { if (mounted) setState(() => error = e); } }
  @override Widget build(BuildContext context) {
    if (note == null) return FinanceShell(title: 'تفاصيل الإشعار الدائن', child: error == null ? const FinanceLoadingState(label: 'جارٍ التحميل…') : FinanceErrorState(message: 'تعذر تحميل الإشعار.', onRetry: load));
    final n = note!;
    final refundable = n.status == 'posted' && (double.tryParse(n.customerCreditAmount ?? '0') ?? 0) > 0;
    return FinanceShell(
      title: n.creditNoteNumber,
      subtitle: 'الفاتورة الأصلية: ${n.originalInvoiceNumber} — العميل: ${n.customerName}',
      actions: <Widget>[
        if (n.canPost) ElevatedButton.icon(onPressed: _confirmPost, icon: const Icon(Icons.post_add), label: const Text('ترحيل الإشعار')),
        if (n.canCancel) TextButton(onPressed: () async { await cubit.repository.cancelCreditNote(n.id); if (mounted) load(); }, child: const Text('إلغاء المسودة')),
        if (refundable) ElevatedButton.icon(onPressed: () async { final ok = await CustomerRefundDialog.show(context, api: cubit.repository, financeSetupRepository: context.read<FinanceSetupCubit>().repository, customerId: n.customerId, customerName: n.customerName, branchId: n.branchId); if (ok == true) load(); }, icon: const Icon(Icons.payments_outlined), label: const Text('+ رد مبلغ للعميل')),
      ],
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Wrap(spacing: 28, runSpacing: 10, children: <Widget>[_field('التاريخ', n.creditDate), _field('السبب', n.reason ?? '—'), _field('الحالة', n.status == 'posted' ? 'مُرحّل' : (n.status == 'draft' ? 'مسودة' : 'ملغى'))]),
        if (n.status == 'posted') ...<Widget>[const SizedBox(height: 16), Wrap(spacing: 28, runSpacing: 10, children: <Widget>[_field('تخفيض الذمم المدينة', n.arReductionAmount ?? '0.00'), _field('رصيد ائتماني للعميل', n.customerCreditAmount ?? '0.00')])],
        const SizedBox(height: 24),
        DataTable(columns: const <DataColumn>[DataColumn(label: Text('المنتج')), DataColumn(label: Text('الكمية')), DataColumn(label: Text('سعر الوحدة')), DataColumn(label: Text('الضريبة')), DataColumn(label: Text('الإجمالي')), DataColumn(label: Text('إعادة للمخزون'))],
          rows: n.lines.map((l) => DataRow(cells: <DataCell>[DataCell(Text(l.productName)), DataCell(Text(l.quantity)), DataCell(Text(l.unitPrice)), DataCell(Text(l.taxTotal)), DataCell(Text(l.total)), DataCell(Icon(l.restock ? Icons.check_circle : Icons.remove_circle_outline, size: 18, color: l.restock ? Colors.green : null))])).toList()),
        const SizedBox(height: 16),
        Align(alignment: AlignmentDirectional.centerEnd, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[_field('الإجمالي قبل الضريبة', n.subtotal), _field('الضريبة', n.taxTotal), _field('الإجمالي النهائي', n.total)])),
      ])),
    );
  }
  Future<void> _confirmPost() async {
    final n = note!;
    try {
      final preview = await cubit.repository.creditNotePostingPreview(n.id);
      if (!mounted) return;
      final approved = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('تأكيد ترحيل الإشعار الدائن'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('الإجمالي المُعتمد: ${preview.total}'), const SizedBox(height: 10),
          const Text('الأثر المحاسبي'), Text('مرتجعات المبيعات (مدين): ${preview.subtotal}\nالضريبة (مدين): ${preview.tax}'),
          Text('تخفيض الذمم المدينة: ${preview.arReduction}'), if (double.tryParse(preview.customerCreditCreated) != null && double.parse(preview.customerCreditCreated) > 0) Text('رصيد ائتماني جديد للعميل: ${preview.customerCreditCreated}'),
          const SizedBox(height: 10), const Text('بنود المرتجع'),
          ...preview.lines.map((l) => Text('${l.productName}: ${l.quantity} — ${l.restock ? "إعادة للمخزون (تكلفة: ${l.cogsReversal})" : "بدون إعادة للمخزون"}')),
        ])),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ترحيل'))],
      ));
      if (approved != true) return;
      await cubit.repository.postCreditNote(n.id, 'cn-post-${n.id}-${DateTime.now().microsecondsSinceEpoch}');
      if (mounted) { await load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل الإشعار الدائن بنجاح.'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر معاينة/ترحيل الإشعار: $e')));
    }
  }
  Widget _field(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(l, style: FinanceText.small), Text(v, style: FinanceText.body)]);
}

/// §35 — "+ رد مبلغ للعميل": settles unapplied customer credit only. It
/// never creates Revenue/Tax/COGS/Inventory effects — those already
/// happened at Credit Note posting.
class CustomerRefundDialog extends StatefulWidget {
  const CustomerRefundDialog({super.key, required this.api, required this.financeSetupRepository, required this.customerId, required this.customerName, required this.branchId});
  final SalesRepository api; final FinanceSetupRepository financeSetupRepository; final int customerId; final String customerName; final int branchId;
  static Future<bool?> show(BuildContext context, {required SalesRepository api, required FinanceSetupRepository financeSetupRepository, required int customerId, required String customerName, required int branchId}) => showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => CustomerRefundDialog(api: api, financeSetupRepository: financeSetupRepository, customerId: customerId, customerName: customerName, branchId: branchId));
  @override State<CustomerRefundDialog> createState() => _CustomerRefundDialogState();
}
class _CustomerRefundDialogState extends State<CustomerRefundDialog> {
  final amount = TextEditingController();
  final reference = TextEditingController();
  DateTime date = DateTime.now();
  List<PaymentMethodSetting> methods = const <PaymentMethodSetting>[];
  int? methodId; String availableCredit = '0.00'; bool loading = true; bool saving = false; Object? error;
  @override void initState() { super.initState(); bootstrap(); }
  @override void dispose() { amount.dispose(); reference.dispose(); super.dispose(); }
  Future<void> bootstrap() async {
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[widget.financeSetupRepository.getPaymentMethods(), widget.api.customerCredit(widget.customerId)]);
      if (!mounted) return;
      final ms = (results[0] as List<PaymentMethodSetting>).where((m) => m.financialLocationId != null && m.isActive).toList();
      final credit = results[1] as CustomerCreditInfo;
      setState(() { methods = ms; methodId = ms.firstOrNull?.id; availableCredit = credit.availableCredit; amount.text = credit.availableCredit; loading = false; });
    } catch (e) { if (mounted) setState(() { error = e; loading = false; }); }
  }
  Future<void> submit() async {
    final amt = double.tryParse(amount.text.trim());
    if (amt == null || amt <= 0) { _snack('أدخل مبلغاً صحيحاً أكبر من صفر.'); return; }
    if (methodId == null) { _snack('اختر طريقة الدفع.'); return; }
    final method = methods.firstWhere((m) => m.id == methodId);
    setState(() => saving = true);
    try {
      await widget.api.registerRefund(<String, dynamic>{
        'branchId': widget.branchId, 'customerId': widget.customerId, 'refundDate': _date(date), 'amount': amount.text.trim(),
        'paymentMethodId': methodId, 'financialLocationId': method.financialLocationId,
        if (reference.text.trim().isNotEmpty) 'reference': reference.text.trim(),
        'idempotencyKey': 'refund-${DateTime.now().microsecondsSinceEpoch}',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('تعذر تسجيل رد المبلغ: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  @override Widget build(BuildContext context) {
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    return AlertDialog(
      title: Text('رد مبلغ للعميل — ${widget.customerName}'),
      content: SizedBox(width: 420, child: loading
          ? const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()))
          : error != null
              ? Text('تعذر تحميل بيانات الرصيد: $error')
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text('الرصيد الائتماني المتاح: $availableCredit', style: FinanceText.body),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => date = d); }, icon: const Icon(Icons.calendar_today), label: Text(_date(date))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(initialValue: methodId, decoration: const InputDecoration(labelText: 'طريقة الدفع'), items: methods.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(), onChanged: (v) => setState(() => methodId = v)),
                  if (method != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('الصندوق / البنك: ${method.financialLocationName ?? '—'}', style: FinanceText.small)),
                  const SizedBox(height: 10),
                  TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
                  TextField(controller: reference, decoration: const InputDecoration(labelText: 'المرجع (اختياري)')),
                ])),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        ElevatedButton(onPressed: (loading || saving) ? null : submit, child: Text(saving ? 'جارٍ الحفظ…' : 'تسجيل الرد')),
      ],
    );
  }
}
