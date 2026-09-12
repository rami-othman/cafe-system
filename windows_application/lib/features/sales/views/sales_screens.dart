import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../finance_inventory_setup/controllers/finance_setup_cubit.dart';
import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../finance_inventory_setup/repositories/finance_setup_repository.dart';
import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../../pos/models/branch.dart';
import '../controllers/sales_cubit.dart';
import '../models/sales_models.dart';
import '../repositories/sales_repository.dart';

class SalesCenterScreen extends StatefulWidget { const SalesCenterScreen({super.key}); @override State<SalesCenterScreen> createState() => _SalesCenterScreenState(); }
class _SalesCenterScreenState extends State<SalesCenterScreen> {
  SalesInvoicePage? page; Object? error; bool loading = false; int currentPage = 1; String search = ''; String? status; final searchController = TextEditingController();
  SalesCubit get cubit => context.read<SalesCubit>();
  @override void initState() { super.initState(); load(); }
  @override void dispose() { searchController.dispose(); super.dispose(); }
  Future<void> load() async { setState(() => loading = true); try { final result = await cubit.repository.invoices(query: <String, dynamic>{'page': currentPage, 'perPage': 25, if (search.isNotEmpty) 'search': search, if (status != null) 'status': status}); if (mounted) setState(() { page = result; error = null; loading = false; }); } catch (e) { if (mounted) setState(() { error = e; loading = false; }); } }
  @override Widget build(BuildContext context) => FinanceShell(title: 'المبيعات', subtitle: 'فواتير المبيعات والذمم والتحصيلات.', actions: <Widget>[OutlinedButton.icon(onPressed: () => context.go(AppRoutes.financeCustomersReceivables), icon: const Icon(Icons.groups_2_outlined), label: const Text('العملاء والمستحقات')), const SizedBox(width: 8), ElevatedButton.icon(onPressed: () => context.go(AppRoutes.financeSalesNew), icon: const Icon(Icons.add), label: const Text('فاتورة مبيع'))], child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Row(children: <Widget>[Expanded(child: _kpi('عدد فواتير المبيعات', '${page?.draftCount ?? 0}')), const SizedBox(width: 12), Expanded(child: _kpi('إجمالي الفواتير المسودة', page?.draftTotal ?? '0.00'))]), const SizedBox(height: 18),
    Wrap(spacing: 8, runSpacing: 8, children: <Widget>[SizedBox(width: 280, child: TextField(controller: searchController, onSubmitted: (v) { search = v.trim(); currentPage = 1; load(); }, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'رقم الفاتورة، العميل أو المرجع'))), DropdownButton<String>(value: status, hint: const Text('الحالة: الكل'), items: const <DropdownMenuItem<String>>[DropdownMenuItem(value: null, child: Text('الحالة: الكل')), DropdownMenuItem(value: 'draft', child: Text('مسودة')), DropdownMenuItem(value: 'cancelled', child: Text('ملغاة'))], onChanged: (v) { setState(() { status = v; currentPage = 1; }); load(); }), OutlinedButton(onPressed: () { searchController.clear(); setState(() { search = ''; status = null; currentPage = 1; }); load(); }, child: const Text('إعادة تعيين'))]), const SizedBox(height: 16),
    Expanded(child: _body()),
  ]));
  Widget _kpi(String label, String value) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: FinanceColors.card, border: Border.all(color: FinanceColors.border), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(label, style: FinanceText.small), const SizedBox(height: 5), Text(value, style: FinanceText.title.copyWith(color: FinanceColors.primary))]));
  Widget _body() { if (page == null && loading) return const FinanceLoadingState(label: 'جارٍ تحميل فواتير المبيعات…'); if (page == null) return FinanceErrorState(message: 'تعذر تحميل فواتير المبيعات.', onRetry: load); if (page!.items.isEmpty) return const FinanceEmptyState(message: 'لا توجد فواتير مبيعات مطابقة.'); return Opacity(opacity: loading ? .55 : 1, child: Column(children: <Widget>[Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const <DataColumn>[DataColumn(label: Text('رقم الفاتورة')), DataColumn(label: Text('التاريخ')), DataColumn(label: Text('العميل')), DataColumn(label: Text('الفرع')), DataColumn(label: Text('الإجمالي')), DataColumn(label: Text('المدفوع')), DataColumn(label: Text('المتبقي')), DataColumn(label: Text('حالة الدفع')), DataColumn(label: Text('حالة المستند')), DataColumn(label: Text('الإجراءات'))], rows: page!.items.map((i) => DataRow(onSelectChanged: (_) => context.go('/finance/sales/${i.id}'), cells: <DataCell>[DataCell(Text(i.invoiceNumber)), DataCell(Text(i.invoiceDate)), DataCell(Text(i.customerName)), DataCell(Text(i.branchName)), DataCell(Text(i.total)), DataCell(Text(i.paidAmount ?? '—')), DataCell(Text(i.remainingAmount ?? '—')), DataCell(_paymentStatusChip(i.paymentStatus)), DataCell(_status(i.status)), DataCell(i.canRegisterPayment ? TextButton(onPressed: () => _registerPayment(context, i), child: const Text('تسجيل دفعة')) : const Text('—'))])).toList()))), Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[Text('إجمالي النتائج: ${page!.total}'), const SizedBox(width: 12), IconButton(onPressed: page!.currentPage > 1 ? () { currentPage--; load(); } : null, icon: const Icon(Icons.chevron_right)), Text('${page!.currentPage} / ${page!.lastPage}'), IconButton(onPressed: page!.currentPage < page!.lastPage ? () { currentPage++; load(); } : null, icon: const Icon(Icons.chevron_left))]) ])); }
  Widget _status(String s) => Chip(label: Text(s == 'draft' ? 'مسودة' : (s == 'posted' ? 'مُرحّلة' : 'ملغاة')));
  Future<void> _registerPayment(BuildContext context, SalesInvoice i) async { final ok = await CustomerPaymentDialog.show(context, salesRepository: cubit.repository, financeSetupRepository: context.read<FinanceSetupCubit>().repository, customerId: i.customerId, customerName: i.customerName, branchId: i.branchId, preselectedInvoiceId: i.id); if (ok == true) load(); }
}

/// Shared across the Sales list, invoice detail and customer receivables screens (§26).
Widget _paymentStatusChip(String? status) { final labels = <String, Color>{'unpaid': FinanceColors.border, 'partial': Colors.orange, 'paid': Colors.green, 'overdue': Colors.red}; final label = <String, String>{'unpaid': 'غير مدفوعة', 'partial': 'مدفوعة جزئياً', 'paid': 'مدفوعة', 'overdue': 'متأخرة', 'not_applicable': '—'}[status ?? 'not_applicable'] ?? '—'; final color = labels[status] ?? FinanceColors.border; return Chip(label: Text(label), backgroundColor: color.withValues(alpha: 0.12), labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600), side: BorderSide(color: color.withValues(alpha: 0.4))); }

class SalesInvoiceDetailScreen extends StatefulWidget { const SalesInvoiceDetailScreen({super.key, required this.id}); final int id; @override State<SalesInvoiceDetailScreen> createState() => _SalesInvoiceDetailScreenState(); }
class _SalesInvoiceDetailScreenState extends State<SalesInvoiceDetailScreen> { SalesInvoice? invoice; Object? error; SalesCubit get cubit => context.read<SalesCubit>(); @override void initState() { super.initState(); load(); } Future<void> load() async { try { final r = await cubit.repository.invoice(widget.id); if (mounted) setState(() { invoice = r; error = null; }); } catch (e) { if (mounted) setState(() => error = e); } }
 @override Widget build(BuildContext context) { if (invoice == null) return FinanceShell(title: 'تفاصيل فاتورة المبيع', child: error == null ? const FinanceLoadingState(label: 'جارٍ التحميل…') : FinanceErrorState(message: 'تعذر تحميل الفاتورة.', onRetry: load)); final i = invoice!; final bool posted = i.status == 'posted'; return FinanceShell(title: i.invoiceNumber, subtitle: posted ? 'الحالة المحاسبية: مُرحّل • لا يوجد أثر نقدي عند الترحيل.' : 'الحالة المحاسبية: غير مُرحّل • حالة المخزون: لم يتم تنفيذ الاستهلاك بعد', actions: <Widget>[if (i.canPost) ElevatedButton.icon(onPressed: () => _confirmPost(i), icon: const Icon(Icons.post_add), label: const Text('ترحيل الفاتورة')), if (i.canPost) OutlinedButton.icon(onPressed: () => _postAndCollect(i), icon: const Icon(Icons.payments_outlined), label: const Text('ترحيل وتسجيل دفعة')), if (i.canRegisterPayment) ElevatedButton.icon(onPressed: () async { final ok = await CustomerPaymentDialog.show(context, salesRepository: cubit.repository, financeSetupRepository: context.read<FinanceSetupCubit>().repository, customerId: i.customerId, customerName: i.customerName, branchId: i.branchId, preselectedInvoiceId: i.id); if (ok == true) load(); }, icon: const Icon(Icons.add_card), label: const Text('+ تسجيل دفعة')), if (i.canEdit) OutlinedButton.icon(onPressed: () => context.go('/finance/sales/${i.id}/edit'), icon: const Icon(Icons.edit), label: const Text('تعديل')), if (i.canCancel) TextButton(onPressed: () async { await cubit.repository.cancel(i.id); if (mounted) load(); }, child: const Text('إلغاء المسودة'))], child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Wrap(spacing: 28, runSpacing: 10, children: <Widget>[_field('العميل', i.customerName), _field('الفرع', i.branchName), _field('التاريخ', i.invoiceDate), _field('الاستحقاق', i.dueDate ?? '—'), _field('المرجع', i.reference ?? '—'), if (posted) _field('مرجع القيد', i.journalReference ?? '—')]),
   if (posted) ...<Widget>[const SizedBox(height: 20), Wrap(spacing: 28, runSpacing: 10, children: <Widget>[_field('إجمالي الفاتورة', i.total), _field('المدفوع', i.paidAmount ?? '0.00'), _field('المتبقي', i.remainingAmount ?? i.total), Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('حالة الدفع', style: FinanceText.small), const SizedBox(height: 4), _paymentStatusChip(i.paymentStatus)])])],
   const SizedBox(height: 24), DataTable(columns: const <DataColumn>[DataColumn(label: Text('المنتج')), DataColumn(label: Text('الكمية')), DataColumn(label: Text('سعر الوحدة')), DataColumn(label: Text('الضريبة')), DataColumn(label: Text('الإجمالي'))], rows: i.lines.map((l) => DataRow(cells: <DataCell>[DataCell(Text(l.productName)), DataCell(Text(l.quantity)), DataCell(Text(l.unitPrice)), DataCell(Text(l.taxTotal)), DataCell(Text(l.total))])).toList()), const SizedBox(height: 16), Align(alignment: AlignmentDirectional.centerEnd, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[_field('الإجمالي قبل الضريبة', i.subtotal), _field('الضريبة', i.taxTotal), _field('الإجمالي النهائي', i.total)])),
   if (posted) ...<Widget>[const SizedBox(height: 28), Text('سجل التحصيلات', style: FinanceText.title), const SizedBox(height: 8), i.collections.isEmpty ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('لا توجد تحصيلات على هذه الفاتورة بعد.')) : DataTable(columns: const <DataColumn>[DataColumn(label: Text('رقم السند')), DataColumn(label: Text('التاريخ')), DataColumn(label: Text('طريقة الدفع')), DataColumn(label: Text('المبلغ'))], rows: i.collections.map((c) => DataRow(onSelectChanged: (_) => _showReceipt(c.paymentId), cells: <DataCell>[DataCell(Text(c.paymentNumber)), DataCell(Text(c.paymentDate)), DataCell(Text(c.paymentMethodName)), DataCell(Text(c.amount))])).toList())]
 ]))); }
 Future<void> _confirmPost(SalesInvoice i) async { try { final p = await cubit.repository.postingPreview(i.id); if (!mounted) return; final bool? approved = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('تأكيد ترحيل الفاتورة'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text('العميل: ${i.customerName}\nالإجمالي: ${i.total}'), const SizedBox(height: 12), const Text('الأثر المحاسبي'), Text('الذمم المدينة: ${p.ar}\nالإيرادات: ${p.revenue}\nالضريبة: ${p.tax}'), const SizedBox(height: 12), const Text('تكلفة البضاعة'), Text('COGS: ${p.cogs}\nInventory Asset: ${p.inventoryAsset}'), const SizedBox(height: 12), const Text('تأثير المخزون'), if (p.materials.isEmpty) const Text('لا يوجد استهلاك مخزني.'), ...p.materials.map((m) => Text('${m.name}: ${m.quantity} ${m.unit} — ${m.warehouse}')), const SizedBox(height: 8), const Text('لن يتم إنشاء دفعة أو أثر نقدي.') ])), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ترحيل'))])); if (approved != true) return; await cubit.repository.post(i.id, 'sales-post-${i.id}-${DateTime.now().microsecondsSinceEpoch}'); if (mounted) { await load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل الفاتورة بنجاح.'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحصول على معاينة/ترحيل الفاتورة: $e'))); } }
 Future<void> _postAndCollect(SalesInvoice i) async { final financeSetupRepository = context.read<FinanceSetupCubit>().repository; final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => ImmediateCollectDialog(financeSetupRepository: financeSetupRepository, invoiceTotal: i.total)); if (result == null || !mounted) return; try { final now = DateTime.now().microsecondsSinceEpoch; await cubit.repository.postAndCollect(i.id, <String, dynamic>{'postIdempotencyKey': 'sales-post-$now', 'paymentDate': result['paymentDate'], 'amount': result['amount'], 'paymentMethodId': result['paymentMethodId'], 'financialLocationId': result['financialLocationId'], 'paymentIdempotencyKey': 'sales-pay-$now', 'allocations': <Map<String, dynamic>>[<String, dynamic>{'invoiceId': i.id, 'amount': result['amount']}]}); if (mounted) { await load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل الفاتورة وتسجيل الدفعة بنجاح.'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر ترحيل الفاتورة وتسجيل الدفعة: $e'))); } }
 Future<void> _showReceipt(int paymentId) async { final reversed = await ReceiptDialog.show(context, salesRepository: cubit.repository, paymentId: paymentId); if (reversed == true) load(); }
 Widget _field(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(l, style: FinanceText.small), Text(v, style: FinanceText.body)]); }

class SalesInvoiceFormScreen extends StatefulWidget { const SalesInvoiceFormScreen({super.key, this.id}); final int? id; @override State<SalesInvoiceFormScreen> createState() => _SalesInvoiceFormScreenState(); }
class _SalesInvoiceFormScreenState extends State<SalesInvoiceFormScreen> { final form = GlobalKey<FormState>(); final reference = TextEditingController(); final notes = TextEditingController(); DateTime date = DateTime.now(); int? customerId; int? branchId; List<SalesCustomer> customers = const []; List<SalesProduct> products = const []; List<Branch> branches = const []; final List<_EditLine> lines = <_EditLine>[]; bool saving = false; SalesCubit get cubit => context.read<SalesCubit>();
 @override void initState() { super.initState(); bootstrap(); } @override void dispose() { reference.dispose(); notes.dispose(); for (final l in lines) { l.dispose(); } super.dispose(); }
 Future<void> bootstrap() async { try { final values = await Future.wait<dynamic>(<Future<dynamic>>[cubit.repository.customers(), cubit.repository.products(), context.read<FinanceSetupCubit>().repository.getBranches()]); if (!mounted) return; setState(() { customers = values[0] as List<SalesCustomer>; products = values[1] as List<SalesProduct>; branches = values[2] as List<Branch>; if (widget.id == null && branches.isNotEmpty) branchId = branches.first.id; }); if (widget.id != null) { final i = await cubit.repository.invoice(widget.id!); if (!mounted) return; setState(() { customerId = i.customerId; branchId = i.branchId; reference.text = i.reference ?? ''; notes.text = i.notes ?? ''; date = DateTime.tryParse(i.invoiceDate) ?? date; lines.addAll(i.lines.map((l) => _EditLine(productId: l.productId, variantId: l.variantId, quantity: l.quantity))); }); } } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل بيانات النموذج.'))); } }
 Future<void> save() async { if (!(form.currentState?.validate() ?? false) || customerId == null || branchId == null || lines.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر العميل والفرع وأضف بنداً واحداً على الأقل.'))); return; } setState(() => saving = true); try { final due = date.add(Duration(days: customers.where((c) => c.id == customerId).firstOrNull?.creditTermsDays ?? 0)); final r = await cubit.repository.save(<String, dynamic>{'branchId': branchId, 'customerId': customerId, 'invoiceDate': _date(date), 'dueDate': _date(due), 'reference': reference.text.trim().isEmpty ? null : reference.text.trim(), 'notes': notes.text.trim().isEmpty ? null : notes.text.trim(), if (widget.id == null) 'idempotencyKey': 'sales-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}', 'lines': lines.map((l) => <String, dynamic>{'productId': l.productId, if (l.variantId != null) 'variantId': l.variantId, 'quantity': l.quantity.text}).toList()}); if (mounted) context.go('/finance/sales/${r.id}'); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الفاتورة: $e'))); } finally { if (mounted) setState(() => saving = false); } }
 @override Widget build(BuildContext context) => FinanceShell(title: widget.id == null ? 'فاتورة مبيع جديدة' : 'تعديل فاتورة مبيع', subtitle: 'تحسب الشاشة معاينة فقط؛ المبلغ والضريبة النهائيان يحددهما الخادم.', actions: <Widget>[ElevatedButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), label: Text(saving ? 'جارٍ الحفظ…' : 'حفظ كمسودة'))], child: Form(key: form, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Wrap(spacing: 16, runSpacing: 12, children: <Widget>[_selector<SalesCustomer>('العميل', customerId, customers, (c) => c.id, (c) => '${c.name} (${c.customerNumber})', (v) => setState(() => customerId = v)), TextButton.icon(onPressed: _newCustomer, icon: const Icon(Icons.person_add), label: const Text('عميل جديد')), _selector<Branch>('الفرع', branchId, branches, (b) => b.id, (b) => b.name, (v) => setState(() => branchId = v)), OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => date = d); }, icon: const Icon(Icons.calendar_today), label: Text(_date(date))) ]), const SizedBox(height: 14), TextFormField(controller: reference, decoration: const InputDecoration(labelText: 'المرجع')), TextFormField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')), const SizedBox(height: 22), Row(children: <Widget>[Text('بنود الفاتورة', style: FinanceText.title), const Spacer(), OutlinedButton.icon(onPressed: products.isEmpty ? null : () { final p = products.first; setState(() => lines.add(_EditLine(productId: p.id, variantId: p.variants.where((v) => v.isDefault).firstOrNull?.id))); }, icon: const Icon(Icons.add), label: const Text('إضافة بند'))]), const SizedBox(height: 8), ...lines.asMap().entries.map((e) => _lineEditor(e.key, e.value)), if (lines.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('أضف منتجات من الكتالوج الحالي.'))]))));
 Widget _selector<T>(String label, int? value, List<T> items, int Function(T) id, String Function(T) name, ValueChanged<int?> onChanged) => SizedBox(width: 260, child: DropdownButtonFormField<int>(value: value, decoration: InputDecoration(labelText: label), items: items.map((x) => DropdownMenuItem(value: id(x), child: Text(name(x), overflow: TextOverflow.ellipsis))).toList(), onChanged: onChanged, validator: (v) => v == null ? 'مطلوب' : null));
 Widget _lineEditor(int index, _EditLine line) { final product = products.where((p) => p.id == line.productId).firstOrNull; final variants = product?.variants ?? const <SalesVariant>[]; return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: <Widget>[Expanded(flex: 3, child: DropdownButtonFormField<int>(value: line.productId, decoration: const InputDecoration(labelText: 'المنتج'), items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} — ${p.salePrice}'))).toList(), onChanged: (v) => setState(() { line.productId = v ?? line.productId; final p = products.where((x) => x.id == line.productId).firstOrNull; line.variantId = p?.variants.where((x) => x.isDefault).firstOrNull?.id; }))), if (variants.isNotEmpty) ...<Widget>[const SizedBox(width: 10), SizedBox(width: 170, child: DropdownButtonFormField<int>(value: line.variantId, decoration: const InputDecoration(labelText: 'النوع'), items: variants.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))).toList(), onChanged: (v) => setState(() => line.variantId = v)))], const SizedBox(width: 10), SizedBox(width: 120, child: TextFormField(controller: line.quantity, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number, validator: (v) => double.tryParse(v ?? '') == null || double.parse(v!) <= 0 ? 'غير صالح' : null)), IconButton(onPressed: () => setState(() { line.dispose(); lines.removeAt(index); }), icon: const Icon(Icons.delete_outline))])); }
 Future<void> _newCustomer() async { final controller = TextEditingController(); final name = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('عميل جديد'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'الاسم')), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('إنشاء'))])); controller.dispose(); if (name == null || name.isEmpty) return; try { final c = await cubit.repository.createCustomer(<String, dynamic>{'name': name}); if (mounted) setState(() { customers = <SalesCustomer>[...customers, c]; customerId = c.id; }); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إنشاء العميل.'))); } }
 String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'; }
class _EditLine { _EditLine({required this.productId, this.variantId, String quantity = '1'}) : quantity = TextEditingController(text: quantity); int productId; int? variantId; final TextEditingController quantity; void dispose() => quantity.dispose(); }

/// §28/§29/§30 — "تسجيل دفعة من العميل": customer + method + amount, then
/// allocate across the customer's open (posted, remaining > 0) invoices.
/// Posting is blocked while any amount is left unallocated (Phase 3 has no
/// unapplied customer credit — see docs/sales §12).
class CustomerPaymentDialog extends StatefulWidget {
  const CustomerPaymentDialog({super.key, required this.salesRepository, required this.financeSetupRepository, required this.customerId, required this.customerName, required this.branchId, this.preselectedInvoiceId});
  final SalesRepository salesRepository; final FinanceSetupRepository financeSetupRepository; final int customerId; final String customerName; final int branchId; final int? preselectedInvoiceId;
  // showDialog pushes onto the root Navigator, so a dialog widget cannot
  // read a Provider scoped to the page route that opened it (see docs on
  // this pattern in the class-level comment of ReceiptDialog below) — both
  // repositories are therefore captured by the caller and passed in here,
  // never re-read via context.read() inside the dialog itself.
  static Future<bool?> show(BuildContext context, {required SalesRepository salesRepository, required FinanceSetupRepository financeSetupRepository, required int customerId, required String customerName, required int branchId, int? preselectedInvoiceId}) => showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => CustomerPaymentDialog(salesRepository: salesRepository, financeSetupRepository: financeSetupRepository, customerId: customerId, customerName: customerName, branchId: branchId, preselectedInvoiceId: preselectedInvoiceId));
  @override State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  final amount = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  List<PaymentMethodSetting> methods = const <PaymentMethodSetting>[];
  int? methodId;
  CustomerReceivablesSummary? summary;
  final Map<int, TextEditingController> allocation = <int, TextEditingController>{};
  bool loading = true; bool saving = false; Object? error;

  @override void initState() { super.initState(); amount.addListener(_refresh); bootstrap(); }
  @override void dispose() { amount.dispose(); reference.dispose(); notes.dispose(); for (final c in allocation.values) { c.dispose(); } super.dispose(); }
  void _refresh() { if (mounted) setState(() {}); }

  Future<void> bootstrap() async {
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[widget.financeSetupRepository.getPaymentMethods(), widget.salesRepository.customerReceivables(widget.customerId)]);
      if (!mounted) return;
      final ms = (results[0] as List<PaymentMethodSetting>).where((m) => m.financialLocationId != null && m.isActive).toList();
      final s = results[1] as CustomerReceivablesSummary;
      setState(() {
        methods = ms; methodId = ms.firstOrNull?.id; summary = s;
        for (final inv in s.openInvoices) { allocation[inv.id] = TextEditingController()..addListener(_refresh); }
        final preselected = widget.preselectedInvoiceId;
        if (preselected != null) {
          final inv = s.openInvoices.where((x) => x.id == preselected).firstOrNull;
          if (inv != null) { allocation[inv.id]!.text = inv.remaining; amount.text = inv.remaining; }
        }
        loading = false;
      });
    } catch (e) { if (mounted) setState(() { error = e; loading = false; }); }
  }

  double _num(String s) => double.tryParse(s.trim()) ?? 0;
  double get paymentAmount => _num(amount.text);
  double get totalAllocated => allocation.values.fold(0.0, (double sum, TextEditingController c) => sum + _num(c.text));
  double get unallocated => paymentAmount - totalAllocated;

  /// §10 — oldest due/open invoice first, using the server's own ordering.
  void autoAllocate() {
    if (summary == null || paymentAmount <= 0) return;
    double left = paymentAmount;
    setState(() {
      for (final c in allocation.values) { c.text = ''; }
      for (final inv in summary!.openInvoices) {
        if (left <= 0.001) break;
        final invRemaining = _num(inv.remaining);
        final take = left < invRemaining ? left : invRemaining;
        if (take > 0) { allocation[inv.id]!.text = take.toStringAsFixed(2); left -= take; }
      }
    });
  }

  Future<void> submit() async {
    if (summary == null) return;
    if (paymentAmount <= 0) { _snack('أدخل مبلغاً صحيحاً أكبر من صفر.'); return; }
    if (methodId == null) { _snack('اختر طريقة الدفع.'); return; }
    if (unallocated.abs() > 0.004) { _snack('يجب توزيع كامل مبلغ الدفعة على الفواتير قبل الترحيل.'); return; }
    final allocations = allocation.entries.where((e) => _num(e.value.text) > 0).map((e) => <String, dynamic>{'invoiceId': e.key, 'amount': e.value.text.trim()}).toList();
    if (allocations.isEmpty) { _snack('حدد فاتورة واحدة على الأقل لتوزيع الدفعة عليها.'); return; }
    final method = methods.firstWhere((m) => m.id == methodId);
    setState(() => saving = true);
    try {
      await widget.salesRepository.registerPayment(<String, dynamic>{
        'branchId': widget.branchId, 'customerId': widget.customerId, 'paymentDate': _date(date), 'amount': amount.text.trim(),
        'paymentMethodId': methodId, 'financialLocationId': method.financialLocationId,
        if (reference.text.trim().isNotEmpty) 'reference': reference.text.trim(), if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        'idempotencyKey': 'customer-pay-${DateTime.now().microsecondsSinceEpoch}', 'allocations': allocations,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) { _snack('تعذر تسجيل الدفعة: $e'); } finally { if (mounted) setState(() => saving = false); }
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override Widget build(BuildContext context) {
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    final invoices = summary?.openInvoices ?? const <OpenReceivableInvoice>[];
    return AlertDialog(
      title: Text('تسجيل دفعة من العميل — ${widget.customerName}'),
      content: SizedBox(width: 640, child: loading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
          : error != null
              ? Text('تعذر تحميل بيانات العميل: $error')
              : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Wrap(spacing: 16, runSpacing: 12, children: <Widget>[
                    OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => date = d); }, icon: const Icon(Icons.calendar_today), label: Text(_date(date))),
                    SizedBox(width: 220, child: DropdownButtonFormField<int>(initialValue: methodId, decoration: const InputDecoration(labelText: 'طريقة الدفع'), items: methods.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(), onChanged: (v) => setState(() => methodId = v))),
                    SizedBox(width: 160, child: TextField(key: const Key('customerPaymentAmountField'), controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ'))),
                  ]),
                  if (method != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('الحساب المستلم: ${method.financialLocationName ?? '—'}', style: FinanceText.small)),
                  const SizedBox(height: 10),
                  TextField(controller: reference, decoration: const InputDecoration(labelText: 'المرجع')),
                  TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
                  const SizedBox(height: 18),
                  Row(children: <Widget>[Text('الفواتير المستحقة', style: FinanceText.title), const Spacer(), TextButton.icon(key: const Key('autoAllocateButton'), onPressed: paymentAmount > 0 ? autoAllocate : null, icon: const Icon(Icons.auto_awesome), label: const Text('توزيع تلقائي'))]),
                  if (invoices.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('لا توجد فواتير مستحقة لهذا العميل.')),
                  ...invoices.map((inv) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: <Widget>[
                        Expanded(flex: 2, child: Text(inv.invoiceNumber)),
                        Expanded(child: Text(inv.dueDate ?? '—', style: FinanceText.small)),
                        Expanded(child: Text(inv.total)),
                        Expanded(child: Text(inv.remaining, style: TextStyle(color: inv.isOverdue ? Colors.red : null))),
                        SizedBox(width: 120, child: TextField(key: Key('allocationField-${inv.id}'), controller: allocation[inv.id], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المخصص', isDense: true))),
                      ]))),
                  const Divider(height: 24),
                  Wrap(spacing: 24, children: <Widget>[
                    Text('إجمالي الدفعة: ${amount.text.isEmpty ? '0.00' : amount.text}'),
                    Text('إجمالي الموزع: ${totalAllocated.toStringAsFixed(2)}'),
                    Text('المتبقي غير الموزع: ${unallocated.toStringAsFixed(2)}', style: TextStyle(color: unallocated.abs() > 0.004 ? Colors.red : Colors.green, fontWeight: FontWeight.w700)),
                  ]),
                ]))),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        ElevatedButton(key: const Key('customerPaymentSubmit'), onPressed: (loading || saving) ? null : submit, child: Text(saving ? 'جارٍ الحفظ…' : 'ترحيل الدفعة')),
      ],
    );
  }
}

/// §31 immediate-payment UX — collects only what "ترحيل وتسجيل دفعة" needs;
/// the two accounting events (invoice post, then settlement) remain separate
/// (see SalesInvoicePostAndCollectService on the backend).
class ImmediateCollectDialog extends StatefulWidget {
  const ImmediateCollectDialog({super.key, required this.financeSetupRepository, required this.invoiceTotal});
  final FinanceSetupRepository financeSetupRepository; final String invoiceTotal;
  @override State<ImmediateCollectDialog> createState() => _ImmediateCollectDialogState();
}

class _ImmediateCollectDialogState extends State<ImmediateCollectDialog> {
  late final TextEditingController amount = TextEditingController(text: widget.invoiceTotal);
  List<PaymentMethodSetting> methods = const <PaymentMethodSetting>[];
  int? methodId; bool loading = true; Object? error;
  @override void initState() { super.initState(); bootstrap(); }
  @override void dispose() { amount.dispose(); super.dispose(); }
  Future<void> bootstrap() async {
    try {
      final ms = (await widget.financeSetupRepository.getPaymentMethods()).where((m) => m.financialLocationId != null && m.isActive).toList();
      if (!mounted) return;
      setState(() { methods = ms; methodId = ms.firstOrNull?.id; loading = false; });
    } catch (e) { if (mounted) setState(() { error = e; loading = false; }); }
  }
  String _today() { final d = DateTime.now(); return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'; }
  @override Widget build(BuildContext context) {
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    return AlertDialog(
      title: const Text('ترحيل الفاتورة وتسجيل دفعة فورية'),
      content: SizedBox(width: 420, child: loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : error != null
              ? Text('تعذر تحميل طرق الدفع: $error')
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  const Text('عمليتان محاسبيتان منفصلتان في طلب واحد: ترحيل الفاتورة (ذمم مدينة + إيرادات + ضريبة)، ثم تحصيل دفعة تسوية (نقدية/بنك مقابل الذمم). لن تُسجَّل إيرادات مرتين.'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(initialValue: methodId, decoration: const InputDecoration(labelText: 'طريقة الدفع'), items: methods.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(), onChanged: (v) => setState(() => methodId = v)),
                  if (method != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('الحساب المستلم: ${method.financialLocationName ?? '—'}', style: FinanceText.small)),
                  const SizedBox(height: 10),
                  TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'المبلغ المحصّل الآن', helperText: 'إجمالي الفاتورة: ${widget.invoiceTotal}')),
                ])),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: (loading || methodId == null) ? null : () { final selected = methods.firstWhere((m) => m.id == methodId); Navigator.pop(context, <String, dynamic>{'paymentDate': _today(), 'amount': amount.text.trim(), 'paymentMethodId': methodId, 'financialLocationId': selected.financialLocationId}); }, child: const Text('ترحيل وتسجيل الدفعة')),
      ],
    );
  }
}

/// §32 — a CustomerPayment displayed/printed as سند قبض. This is a read
/// view over the one CustomerPayment settlement journal; it never creates a
/// second accounting document.
class ReceiptDialog {
  // Same rationale as CustomerPaymentDialog: showDialog escapes the calling
  // page's Provider scope, so the repository is captured by the caller.
  static Future<bool?> show(BuildContext context, {required SalesRepository salesRepository, required int paymentId}) => showDialog<bool>(context: context, builder: (_) => _ReceiptDialogContent(salesRepository: salesRepository, paymentId: paymentId));
}

class _ReceiptDialogContent extends StatefulWidget {
  const _ReceiptDialogContent({required this.salesRepository, required this.paymentId});
  final SalesRepository salesRepository; final int paymentId;
  @override State<_ReceiptDialogContent> createState() => _ReceiptDialogContentState();
}

class _ReceiptDialogContentState extends State<_ReceiptDialogContent> {
  CustomerPayment? payment; Object? error; bool reversing = false;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { final p = await widget.salesRepository.payment(widget.paymentId); if (mounted) setState(() { payment = p; error = null; }); } catch (e) { if (mounted) setState(() => error = e); } }
  @override Widget build(BuildContext context) {
    if (payment == null) return AlertDialog(content: error == null ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())) : Text('تعذر تحميل السند: $error'));
    final p = payment!;
    final reversed = p.status == 'reversed';
    return AlertDialog(
      title: const Text('سند قبض'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        _row('رقم السند', p.paymentNumber), _row('التاريخ', p.paymentDate), _row('استلمنا من', p.customerName), _row('المبلغ', p.amount), _row('طريقة الدفع', p.paymentMethodName), _row('الصندوق / البنك', p.financialLocationName), _row('البيان', p.reference ?? p.notes ?? '—'),
        const SizedBox(height: 10), Text('الفواتير المسددة', style: FinanceText.small),
        if (p.allocations.isEmpty) const Text('—') else ...p.allocations.map((a) => Text('${a.invoiceNumber}: ${a.amount}')),
        const Divider(height: 24), Text('القيد المحاسبي', style: FinanceText.small),
        Text('مدين ${p.financialLocationName}: ${p.amount}'), Text('دائن الذمم المدينة: ${p.amount}'),
        if (reversed) const Padding(padding: EdgeInsets.only(top: 10), child: Text('تم عكس هذه الدفعة.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
      ]))),
      actions: <Widget>[
        if (p.canReverse) TextButton(onPressed: reversing ? null : () => _reverse(), child: Text(reversing ? 'جارٍ العكس…' : 'عكس الدفعة')),
        TextButton(onPressed: () => Navigator.pop(context, reversed), child: const Text('إغلاق')),
      ],
    );
  }
  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: <Widget>[SizedBox(width: 140, child: Text(label, style: FinanceText.small)), Expanded(child: Text(value))]));
  Future<void> _reverse() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _ReversalReasonDialog());
    if (reason == null || !mounted) return;
    setState(() => reversing = true);
    try {
      await widget.salesRepository.reversePayment(widget.paymentId, reason: reason);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر عكس الدفعة: $e')));
    } finally {
      if (mounted) setState(() => reversing = false);
    }
  }
}

/// §35 — reversal requires a typed reason, shown to the operator up front
/// alongside the accounting impact before they confirm.
class _ReversalReasonDialog extends StatefulWidget { const _ReversalReasonDialog(); @override State<_ReversalReasonDialog> createState() => _ReversalReasonDialogState(); }
class _ReversalReasonDialogState extends State<_ReversalReasonDialog> {
  final controller = TextEditingController();
  String? errorText;
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('عكس الدفعة'),
    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      const Text('سيُنشأ قيد تسوية جديد: مدين الذمم المدينة، دائن الصندوق أو البنك. الدفعة الأصلية لن تُحذف، وستُعاد فتح الفاتورة (كلياً أو جزئياً) بحسب المبلغ المعكوس.'),
      const SizedBox(height: 12),
      TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: 'سبب العكس', errorText: errorText)),
    ])),
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
      ElevatedButton(onPressed: () { final reason = controller.text.trim(); if (reason.isEmpty) { setState(() => errorText = 'مطلوب'); return; } Navigator.pop(context, reason); }, child: const Text('تأكيد العكس')),
    ],
  );
}

/// §33 — minimal "العملاء والمستحقات" view: outstanding is always derived
/// from posted invoices minus allocations, never a stored balance.
class CustomerReceivablesScreen extends StatefulWidget { const CustomerReceivablesScreen({super.key}); @override State<CustomerReceivablesScreen> createState() => _CustomerReceivablesScreenState(); }
class _CustomerReceivablesScreenState extends State<CustomerReceivablesScreen> {
  List<CustomerReceivableOverviewRow>? rows; Object? error; List<Branch> branches = const <Branch>[];
  SalesCubit get cubit => context.read<SalesCubit>();
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[cubit.repository.receivablesOverview(), context.read<FinanceSetupCubit>().repository.getBranches()]);
      if (mounted) setState(() { rows = results[0] as List<CustomerReceivableOverviewRow>; branches = results[1] as List<Branch>; error = null; });
    } catch (e) { if (mounted) setState(() => error = e); }
  }
  @override Widget build(BuildContext context) => FinanceShell(title: 'العملاء والمستحقات', subtitle: 'رصيد الذمم المدينة مشتق من الفواتير المرحّلة والتحصيلات الفعلية فقط — لا يوجد رصيد مخزَّن مستقل.', child: _body());
  Widget _body() {
    if (rows == null) return error == null ? const FinanceLoadingState(label: 'جارٍ تحميل المستحقات…') : FinanceErrorState(message: 'تعذر تحميل بيانات المستحقات.', onRetry: load);
    if (rows!.isEmpty) return const FinanceEmptyState(message: 'لا توجد فواتير مرحّلة بعد.');
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const <DataColumn>[DataColumn(label: Text('العميل')), DataColumn(label: Text('عدد الفواتير')), DataColumn(label: Text('إجمالي الفوترة')), DataColumn(label: Text('إجمالي المحصّل')), DataColumn(label: Text('المستحق')), DataColumn(label: Text('الإجراءات'))], rows: rows!.map((r) {
      final outstanding = double.tryParse(r.outstanding) ?? 0;
      return DataRow(cells: <DataCell>[
        DataCell(Text('${r.customerName} (${r.customerNumber})')),
        DataCell(Text('${r.invoiceCount}')),
        DataCell(Text(r.totalInvoiced)),
        DataCell(Text(r.totalPaid)),
        DataCell(Text(r.outstanding, style: TextStyle(fontWeight: FontWeight.w700, color: outstanding > 0 ? Colors.red : null))),
        DataCell(outstanding > 0 ? TextButton(onPressed: () async { final ok = await CustomerPaymentDialog.show(context, salesRepository: cubit.repository, financeSetupRepository: context.read<FinanceSetupCubit>().repository, customerId: r.customerId, customerName: r.customerName, branchId: branches.firstOrNull?.id ?? 0); if (ok == true) load(); }, child: const Text('تسجيل دفعة')) : const Text('—')),
      ]);
    }).toList()));
  }
}
