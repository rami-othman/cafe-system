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
import '../../finance_inventory_setup/widgets/finance_pagination.dart';
import '../../finance_inventory_setup/widgets/finance_shell.dart';
import '../../pos/models/branch.dart';
import '../../../shared/widgets/searchable_select_field.dart';
import '../controllers/sales_cubit.dart';
import '../models/sales_models.dart';
import '../models/sales_draft_preview.dart';
import '../repositories/sales_repository.dart';

class SalesCenterScreen extends StatefulWidget {
  const SalesCenterScreen({super.key});
  @override
  State<SalesCenterScreen> createState() => _SalesCenterScreenState();
}

class _SalesCenterScreenState extends State<SalesCenterScreen> {
  SalesInvoicePage? page;
  Object? error;
  bool loading = false;
  int currentPage = 1;
  String search = '';
  String? status;
  final searchController = TextEditingController();
  SalesCubit get cubit => context.read<SalesCubit>();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final result = await cubit.repository.invoices(
        query: <String, dynamic>{
          'page': currentPage,
          'perPage': 25,
          if (search.isNotEmpty) 'search': search,
          if (status != null) 'status': status,
        },
      );
      if (mounted)
        setState(() {
          page = result;
          error = null;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => FinanceShell(
    title: 'المبيعات',
    subtitle: 'فواتير المبيعات والذمم والتحصيلات.',
    actions: <Widget>[
      OutlinedButton.icon(
        onPressed: () => context.go(AppRoutes.financeCustomersReceivables),
        icon: const Icon(Icons.groups_2_outlined),
        label: const Text('العملاء والمستحقات'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: () => context.go(AppRoutes.financeSalesCreditNotes),
        icon: const Icon(Icons.assignment_return_outlined),
        label: const Text('الإشعارات الدائنة / المرتجعات'),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: () => context.go(AppRoutes.financeSalesNew),
        icon: const Icon(Icons.add),
        label: const Text('فاتورة مبيع'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (page?.financialSummary != null) ...<Widget>[
          Text(
            'هذا الشهر (${page!.financialSummary!.periodFrom} — ${page!.financialSummary!.periodTo})',
            style: FinanceText.small,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _kpi('صافي المبيعات', page!.financialSummary!.netSales),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpi(
                  'عدد الفواتير المُرحّلة',
                  '${page!.financialSummary!.postedInvoicesCount}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpi(
                  'الذمم المستحقة',
                  page!.financialSummary!.outstandingAr,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpi('المُحصّل', page!.financialSummary!.collectedTotal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpi(
                  'الإشعارات الدائنة',
                  page!.financialSummary!.creditNotesTotal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: _kpi('عدد فواتير المبيعات', '${page?.draftCount ?? 0}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpi(
                'إجمالي الفواتير المسودة',
                page?.draftTotal ?? '0.00',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SizedBox(
              width: 280,
              child: TextField(
                controller: searchController,
                onSubmitted: (v) {
                  search = v.trim();
                  currentPage = 1;
                  load();
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'رقم الفاتورة، العميل أو المرجع',
                ),
              ),
            ),
            DropdownButton<String>(
              value: status,
              hint: const Text('الحالة: الكل'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: null, child: Text('الحالة: الكل')),
                DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                DropdownMenuItem(value: 'cancelled', child: Text('ملغاة')),
              ],
              onChanged: (v) {
                setState(() {
                  status = v;
                  currentPage = 1;
                });
                load();
              },
            ),
            OutlinedButton(
              onPressed: () {
                searchController.clear();
                setState(() {
                  search = '';
                  status = null;
                  currentPage = 1;
                });
                load();
              },
              child: const Text('إعادة تعيين'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: _body()),
      ],
    ),
  );
  Widget _kpi(String label, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: FinanceText.small),
        const SizedBox(height: 5),
        Text(
          value,
          style: FinanceText.title.copyWith(color: FinanceColors.primary),
        ),
      ],
    ),
  );
  Widget _body() {
    if (page == null && loading)
      return const FinanceLoadingState(label: 'جارٍ تحميل فواتير المبيعات…');
    if (page == null)
      return FinanceErrorState(
        message: 'تعذر تحميل فواتير المبيعات.',
        onRetry: load,
      );
    if (page!.items.isEmpty)
      return const FinanceEmptyState(message: 'لا توجد فواتير مبيعات مطابقة.');
    return Opacity(
      opacity: loading ? .55 : 1,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FinanceTable(
              minWidth: 1180,
              onRowTap: (int index) =>
                  context.go('/finance/sales/${page!.items[index].id}'),
              headers: const <String>[
                'رقم الفاتورة',
                'التاريخ',
                'العميل',
                'الفرع',
                'الإجمالي',
                'المدفوع',
                'المتبقي',
                'حالة الدفع',
                'حالة المستند',
                'الإجراءات',
              ],
              rows: page!.items
                  .map(
                    (i) => <Widget>[
                      Text(
                        i.invoiceNumber,
                        style: FinanceText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(i.invoiceDate, style: FinanceText.small),
                      Text(i.customerName, style: FinanceText.body),
                      Text(i.branchName, style: FinanceText.small),
                      FinanceAmount(value: i.total),
                      i.paidAmount == null
                          ? Text('—', style: FinanceText.small)
                          : FinanceAmount(value: i.paidAmount!),
                      i.remainingAmount == null
                          ? Text('—', style: FinanceText.small)
                          : FinanceAmount(
                              value: i.remainingAmount!,
                              color: i.isOverdue ? FinanceColors.danger : null,
                            ),
                      _paymentStatusChip(i.paymentStatus),
                      _status(i.status),
                      i.canRegisterPayment
                          ? TextButton(
                              onPressed: () => _registerPayment(context, i),
                              child: const Text('تسجيل دفعة'),
                            )
                          : Text('—', style: FinanceText.small),
                    ],
                  )
                  .toList(growable: false),
            ),
            FinancePagination(
              meta: FinancePageMeta(
                currentPage: page!.currentPage,
                perPage: 25,
                total: page!.total,
                lastPage: page!.lastPage,
              ),
              onPageChanged: (int value) {
                currentPage = value;
                load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(String s) => FinanceStatusBadgeCustom(
    label: s == 'draft' ? 'مسودة' : (s == 'posted' ? 'مُرحّلة' : 'ملغاة'),
    tone: s == 'posted'
        ? FinanceTone.success
        : (s == 'cancelled' ? FinanceTone.danger : FinanceTone.warning),
  );
  Future<void> _registerPayment(BuildContext context, SalesInvoice i) async {
    final ok = await CustomerPaymentDialog.show(
      context,
      salesRepository: cubit.repository,
      financeSetupRepository: context.read<FinanceSetupCubit>().repository,
      customerId: i.customerId,
      customerName: i.customerName,
      branchId: i.branchId,
      preselectedInvoiceId: i.id,
    );
    if (ok == true) load();
  }
}

/// Shared across the Sales list, invoice detail and customer receivables screens (§26).
Widget _paymentStatusChip(String? status) {
  if (status == null || status == 'not_applicable')
    return Text('—', style: FinanceText.small);
  final tones = <String, FinanceTone>{
    'unpaid': FinanceTone.neutral,
    'partial': FinanceTone.warning,
    'paid': FinanceTone.success,
    'overdue': FinanceTone.danger,
  };
  final labels = <String, String>{
    'unpaid': 'غير مدفوعة',
    'partial': 'مدفوعة جزئياً',
    'paid': 'مدفوعة',
    'overdue': 'متأخرة',
  };
  return FinanceStatusBadgeCustom(
    label: labels[status] ?? status,
    tone: tones[status] ?? FinanceTone.neutral,
  );
}

class SalesInvoiceDetailScreen extends StatefulWidget {
  const SalesInvoiceDetailScreen({super.key, required this.id});
  final int id;
  @override
  State<SalesInvoiceDetailScreen> createState() =>
      _SalesInvoiceDetailScreenState();
}

class _SalesInvoiceDetailScreenState extends State<SalesInvoiceDetailScreen> {
  SalesInvoice? invoice;
  Object? error;
  SalesCubit get cubit => context.read<SalesCubit>();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await cubit.repository.invoice(widget.id);
      if (mounted)
        setState(() {
          invoice = r;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (invoice == null)
      return FinanceShell(
        title: 'تفاصيل فاتورة المبيع',
        child: error == null
            ? const FinanceLoadingState(label: 'جارٍ التحميل…')
            : FinanceErrorState(message: 'تعذر تحميل الفاتورة.', onRetry: load),
      );
    final i = invoice!;
    final bool posted = i.status == 'posted';
    return FinanceShell(
      title: i.invoiceNumber,
      subtitle: posted
          ? (i.isWalkIn
                ? 'الحالة المحاسبية: مُرحّل ومدفوع • تم تسجيل الدفع النقدي مع القيد.'
                : 'الحالة المحاسبية: مُرحّل • لا يوجد أثر نقدي عند الترحيل.')
          : 'الحالة المحاسبية: غير مُرحّل • حالة المخزون: لم يتم تنفيذ الاستهلاك بعد',
      actions: <Widget>[
        if (i.canPost && !i.isWalkIn)
          ElevatedButton.icon(
            onPressed: () => _confirmPost(i),
            icon: const Icon(Icons.post_add),
            label: const Text('ترحيل الفاتورة'),
          ),
        if (i.canPost)
          OutlinedButton.icon(
            onPressed: () => _postAndCollect(i),
            icon: const Icon(Icons.payments_outlined),
            label: Text(i.isWalkIn ? 'حفظ وترحيل نقدي' : 'ترحيل وتسجيل دفعة'),
          ),
        if (i.canRegisterPayment)
          ElevatedButton.icon(
            onPressed: () async {
              final ok = await CustomerPaymentDialog.show(
                context,
                salesRepository: cubit.repository,
                financeSetupRepository: context
                    .read<FinanceSetupCubit>()
                    .repository,
                customerId: i.customerId,
                customerName: i.customerName,
                branchId: i.branchId,
                preselectedInvoiceId: i.id,
              );
              if (ok == true) load();
            },
            icon: const Icon(Icons.add_card),
            label: const Text('+ تسجيل دفعة'),
          ),
        if (i.canCreateCreditNote)
          OutlinedButton.icon(
            onPressed: () => context.go(
              Uri(
                path: AppRoutes.financeSalesCreditNoteNew,
                queryParameters: <String, String>{
                  'invoiceId': '${i.id}',
                  'customerName': i.customerName,
                },
              ).toString(),
            ),
            icon: const Icon(Icons.assignment_return_outlined),
            label: const Text('+ إنشاء مرتجع / إشعار دائن'),
          ),
        if (i.canEdit)
          OutlinedButton.icon(
            onPressed: () => context.go('/finance/sales/${i.id}/edit'),
            icon: const Icon(Icons.edit),
            label: const Text('تعديل'),
          ),
        if (i.canCancel)
          TextButton(
            onPressed: () async {
              await cubit.repository.cancel(i.id);
              if (mounted) load();
            },
            child: const Text('إلغاء المسودة'),
          ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 28,
              runSpacing: 10,
              children: <Widget>[
                _field('العميل', i.customerName),
                _field('الفرع', i.branchName),
                _field('التاريخ', i.invoiceDate),
                _field('الاستحقاق', i.dueDate ?? '—'),
                _field('المرجع', i.reference ?? '—'),
                if (posted) _field('مرجع القيد', i.journalReference ?? '—'),
              ],
            ),
            if (posted) ...<Widget>[
              const SizedBox(height: 20),
              Wrap(
                spacing: 28,
                runSpacing: 10,
                children: <Widget>[
                  _field('إجمالي الفاتورة', i.total),
                  _field('المدفوع', i.paidAmount ?? '0.00'),
                  _field(
                    i.isWalkIn ? 'المسترد نقداً' : 'المُعاد/المُخصوم',
                    i.isWalkIn
                        ? (i.refundedAmount ?? '0.00')
                        : (i.creditedAmount ?? '0.00'),
                  ),
                  _field(
                    i.isWalkIn ? 'القابل للاسترداد' : 'المتبقي',
                    i.isWalkIn
                        ? (i.remainingRefundableAmount ?? '0.00')
                        : (i.remainingAmount ?? i.total),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('حالة الدفع', style: FinanceText.small),
                      const SizedBox(height: 4),
                      _paymentStatusChip(i.paymentStatus),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('حالة الإشعارات الدائنة', style: FinanceText.small),
                      const SizedBox(height: 4),
                      _creditStatusChip(i.creditStatus),
                    ],
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('المنتج')),
                  DataColumn(label: Text('النوع')),
                  DataColumn(label: Text('الكمية')),
                  DataColumn(label: Text('سعر الوحدة')),
                  DataColumn(label: Text('الخصم')),
                  DataColumn(label: Text('الإجمالي قبل الخصم')),
                  DataColumn(label: Text('الضريبة')),
                  DataColumn(label: Text('الإجمالي')),
                ],
                rows: i.lines
                    .map(
                      (l) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(l.productName)),
                          DataCell(Text(l.unitCode ?? l.variantName ?? '—')),
                          DataCell(Text(l.quantity)),
                          DataCell(Text(l.unitPrice)),
                          DataCell(Text(l.discountAmount ?? '0.00')),
                          DataCell(Text(l.lineSubtotal ?? '0.00')),
                          DataCell(Text(l.taxTotal)),
                          DataCell(Text(l.total)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _field('إجمالي البنود', i.grossSubtotal ?? i.subtotal),
                  _field('خصومات البنود', i.lineDiscountTotal ?? '0.00'),
                  _field('خصم الفاتورة', i.invoiceDiscountTotal ?? '0.00'),
                  _field('رسوم إضافية', i.additionalChargesTotal ?? '0.00'),
                  _field('الإجمالي قبل الضريبة', i.subtotal),
                  _field('الضريبة', i.taxTotal),
                  _field('الإجمالي النهائي', i.total),
                ],
              ),
            ),
            if (posted) ...<Widget>[
              const SizedBox(height: 28),
              Text('سجل التحصيلات', style: FinanceText.title),
              const SizedBox(height: 8),
              i.collections.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('لا توجد تحصيلات على هذه الفاتورة بعد.'),
                    )
                  : DataTable(
                      columns: const <DataColumn>[
                        DataColumn(label: Text('رقم السند')),
                        DataColumn(label: Text('التاريخ')),
                        DataColumn(label: Text('طريقة الدفع')),
                        DataColumn(label: Text('المبلغ')),
                      ],
                      rows: i.collections
                          .map(
                            (c) => DataRow(
                              onSelectChanged: (_) => _showReceipt(c.paymentId),
                              cells: <DataCell>[
                                DataCell(Text(c.paymentNumber)),
                                DataCell(Text(c.paymentDate)),
                                DataCell(Text(c.paymentMethodName)),
                                DataCell(Text(c.amount)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            ],
            if (posted) ...<Widget>[
              const SizedBox(height: 28),
              Text(
                'سجل الإشعارات الدائنة / المرتجعات',
                style: FinanceText.title,
              ),
              const SizedBox(height: 8),
              i.creditNotes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'لا توجد إشعارات دائنة على هذه الفاتورة بعد.',
                      ),
                    )
                  : DataTable(
                      columns: const <DataColumn>[
                        DataColumn(label: Text('رقم الإشعار')),
                        DataColumn(label: Text('التاريخ')),
                        DataColumn(label: Text('السبب')),
                        DataColumn(label: Text('الإجمالي')),
                        DataColumn(label: Text('خصم من الذمم')),
                        DataColumn(label: Text('رصيد للعميل')),
                      ],
                      rows: i.creditNotes
                          .map(
                            (c) => DataRow(
                              onSelectChanged: (_) => context.go(
                                '${AppRoutes.financeSalesCreditNotes}/${c.id}',
                              ),
                              cells: <DataCell>[
                                DataCell(Text(c.creditNoteNumber)),
                                DataCell(Text(c.creditDate)),
                                DataCell(Text(c.reason ?? '—')),
                                DataCell(Text(c.total)),
                                DataCell(Text(c.arReductionAmount)),
                                DataCell(Text(c.customerCreditAmount)),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _creditStatusChip(String? status) {
    final tones = <String, FinanceTone>{
      'not_credited': FinanceTone.neutral,
      'partially_credited': FinanceTone.warning,
      'fully_credited': FinanceTone.dark,
    };
    final labels = <String, String>{
      'not_credited': 'بدون إشعارات',
      'partially_credited': 'مخصومة جزئياً',
      'fully_credited': 'مخصومة بالكامل',
    };
    final key = status ?? 'not_credited';
    return FinanceStatusBadgeCustom(
      label: labels[key] ?? '—',
      tone: tones[key] ?? FinanceTone.neutral,
    );
  }

  Future<void> _confirmPost(SalesInvoice i) async {
    try {
      final p = await cubit.repository.postingPreview(i.id);
      if (!mounted) return;
      final bool? approved = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('تأكيد ترحيل الفاتورة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('العميل: ${i.customerName}\nالإجمالي: ${i.total}'),
                const SizedBox(height: 12),
                const Text('الأثر المحاسبي'),
                Text(
                  'الذمم المدينة: ${p.ar}\nالإيرادات: ${p.revenue}\nالضريبة: ${p.tax}',
                ),
                const SizedBox(height: 12),
                const Text('تكلفة البضاعة'),
                Text('COGS: ${p.cogs}\nInventory Asset: ${p.inventoryAsset}'),
                const SizedBox(height: 12),
                const Text('تأثير المخزون'),
                if (p.materials.isEmpty) const Text('لا يوجد استهلاك مخزني.'),
                ...p.materials.map(
                  (m) => Text(
                    '${m.name}: ${m.quantity} ${m.unit} — ${m.warehouse}',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('لن يتم إنشاء دفعة أو أثر نقدي.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ترحيل'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await cubit.repository.post(
        i.id,
        'sales-post-${i.id}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) {
        await load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم ترحيل الفاتورة بنجاح.')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحصول على معاينة/ترحيل الفاتورة: $e')),
        );
    }
  }

  Future<void> _postAndCollect(SalesInvoice i) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ImmediateCollectDialog(
        financeSetupRepository: context.read<FinanceSetupCubit>().repository,
        invoiceTotal: i.total,
        branchId: i.branchId,
        directSale: i.isWalkIn,
        invoiceDate: i.invoiceDate,
      ),
    );
    if (result == null || !mounted) return;
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      await cubit.repository.postAndCollect(i.id, <String, dynamic>{
        'postIdempotencyKey': i.isWalkIn
            ? 'sales-cash-post-${i.id}'
            : 'sales-post-$now',
        'paymentIdempotencyKey': i.isWalkIn
            ? 'sales-cash-pay-${i.id}'
            : 'sales-pay-$now',
        'paymentDate': result['paymentDate'],
        'amount': result['amount'],
        'paymentMethodId': result['paymentMethodId'],
        if (result['financialLocationId'] != null)
          'financialLocationId': result['financialLocationId'],
        if (!i.isWalkIn)
          'allocations': <Map<String, dynamic>>[
            <String, dynamic>{'invoiceId': i.id, 'amount': result['amount']},
          ],
      });
      if (mounted) {
        await load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم ترحيل الفاتورة وتسجيل الدفعة بنجاح.'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر ترحيل الفاتورة وتسجيل الدفعة: $e')),
        );
    }
  }

  Future<void> _showReceipt(int paymentId) async {
    final reversed = await ReceiptDialog.show(
      context,
      salesRepository: cubit.repository,
      paymentId: paymentId,
    );
    if (reversed == true) load();
  }

  Widget _field(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(l, style: FinanceText.small),
      Text(v, style: FinanceText.body),
    ],
  );
}

class SalesInvoiceFormScreen extends StatefulWidget {
  const SalesInvoiceFormScreen({super.key, this.id});
  final int? id;
  @override
  State<SalesInvoiceFormScreen> createState() => _SalesInvoiceFormScreenState();
}

class _SalesInvoiceFormScreenState extends State<SalesInvoiceFormScreen> {
  final form = GlobalKey<FormState>();
  final reference = TextEditingController();
  final notes = TextEditingController();
  final invoiceDiscount = TextEditingController();
  final manualAdjustment = TextEditingController();
  String? invoiceDiscountType;
  DateTime date = DateTime.now();
  DateTime? dueDate;
  int? customerId;
  int? branchId;
  List<SalesCustomer> customers = const [];
  List<SalesProduct> products = const [];
  List<SalesMaterial> materials = const [];
  double taxRate = 0;
  List<Branch> branches = const [];
  final List<_EditLine> lines = <_EditLine>[];
  final List<_EditCharge> charges = <_EditCharge>[];
  int? savedId;
  late final String createKey =
      'sales-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
  bool saving = false;
  String? catalogError;
  SalesCubit get cubit => context.read<SalesCubit>();
  @override
  void initState() {
    super.initState();
    bootstrap();
  }

  @override
  void dispose() {
    reference.dispose();
    notes.dispose();
    invoiceDiscount.dispose();
    manualAdjustment.dispose();
    for (final l in lines) {
      l.dispose();
    }
    for (final c in charges) {
      c.dispose();
    }
    super.dispose();
  }

  Future<T?> _loadOptional<T>(
    Future<T> request,
    String label,
    List<String> errors,
  ) async {
    try {
      return await request;
    } catch (error) {
      errors.add('$label: $error');
      return null;
    }
  }

  Future<void> bootstrap() async {
    final errors = <String>[];
    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      _loadOptional(cubit.repository.customers(), 'العملاء', errors),
      _loadOptional(cubit.repository.products(), 'المنتجات', errors),
      _loadOptional(
        context.read<FinanceSetupCubit>().repository.getBranches(),
        'الفروع',
        errors,
      ),
      _loadOptional(cubit.repository.materials(), 'المواد الخام', errors),
      _loadOptional(cubit.repository.salesTaxRate(), 'الضريبة', errors),
    ]);
    if (!mounted) return;
    setState(() {
      customers = values[0] as List<SalesCustomer>? ?? const [];
      products = values[1] as List<SalesProduct>? ?? const [];
      branches = values[2] as List<Branch>? ?? const [];
      materials = values[3] as List<SalesMaterial>? ?? const [];
      taxRate = values[4] as double? ?? 0;
      if (products.isEmpty && materials.isEmpty && errors.isEmpty) {
        errors.add('لا توجد منتجات أو مواد خام متاحة للفوترة.');
      }
      catalogError = errors.isEmpty ? null : errors.join('\n');
      if (widget.id == null && branchId == null && branches.isNotEmpty)
        branchId = branches.first.id;
    });
    if (widget.id == null) return;
    try {
      final i = await cubit.repository.invoice(widget.id!);
      if (!mounted) return;
      setState(() {
        customerId = i.customerId;
        branchId = i.branchId;
        reference.text = i.reference ?? '';
        notes.text = i.notes ?? '';
        date = DateTime.tryParse(i.invoiceDate) ?? date;
        dueDate = DateTime.tryParse(i.dueDate ?? '');
        invoiceDiscountType = i.invoiceDiscountType;
        invoiceDiscount.text = i.invoiceDiscountValue ?? '';
        lines.addAll(
          i.lines.map(
            (l) => _EditLine(
              productId: l.inventoryItemId == null ? l.productId : null,
              inventoryItemId: l.inventoryItemId,
              unitCode: l.unitCode,
              variantId: l.variantId,
              isMaterial: l.inventoryItemId != null,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
              defaultPrice: l.baseUnitPrice ?? l.unitPrice,
              discountType: l.discountType,
              discountValue: l.discountValue,
              materialOverridesTouched: l.materialOverrides.isNotEmpty,
              materialOverrides: l.materialOverrides
                  .map(
                    (o) => _MaterialOverrideRow(
                      materialId: o.inventoryItemId,
                      materialName: o.materialName,
                      quantity: o.quantity,
                      unitCode: o.unitCode,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        charges.addAll(
          i.charges.map((c) => _EditCharge(name: c.name, amount: c.amount)),
        );
      });
    } catch (error) {
      if (mounted) setState(() => catalogError = 'تعذر تحميل الفاتورة: $error');
    }
  }

  void _addLine() {
    if (products.isEmpty && materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد منتجات أو مواد خام متاحة للإضافة.'),
        ),
      );
      return;
    }
    setState(
      () => lines.add(_EditLine(unitPrice: '0.00', defaultPrice: '0.00')),
    );
  }

  Future<void> save({bool postAfterSave = false}) async {
    if (!(form.currentState?.validate() ?? false) ||
        customerId == null ||
        branchId == null ||
        lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر العميل والفرع وأضف بنداً واحداً على الأقل.'),
        ),
      );
      return;
    }
    if (lines.any((l) => l.productId == null && l.inventoryItemId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر منتجاً أو مادة لكل بند من بنود الفاتورة.'),
        ),
      );
      return;
    }
    if (lines.any(
      (l) =>
          l.materialOverridesTouched &&
          l.materialOverrides.any((o) => o.materialId == null),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اختر مادة لكل مكوّن في قائمة مكونات الوصفة، أو احذف السطر الفارغ.',
          ),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final due =
          dueDate ??
          date.add(
            Duration(
              days:
                  customers
                      .where((c) => c.id == customerId)
                      .firstOrNull
                      ?.creditTermsDays ??
                  0,
            ),
          );
      final r = await cubit.repository.save(<String, dynamic>{
        'branchId': branchId,
        'customerId': customerId,
        'invoiceDate': _date(date),
        'dueDate': _date(due),
        'reference': reference.text.trim().isEmpty
            ? null
            : reference.text.trim(),
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
        if (widget.id == null && savedId == null) 'idempotencyKey': createKey,
        'invoiceDiscountType': invoiceDiscountType,
        'invoiceDiscountValue': invoiceDiscountType == null
            ? null
            : (invoiceDiscount.text.trim().isEmpty
                  ? '0'
                  : invoiceDiscount.text.trim()),
        'charges': charges
            .map(
              (c) => <String, dynamic>{
                'name': c.name.text.trim(),
                'amount': c.amount.text.trim(),
                'taxable': true,
              },
            )
            .toList(),
        'lines': lines
            .map(
              (l) => <String, dynamic>{
                if (l.productId != null) 'productId': l.productId,
                if (l.inventoryItemId != null)
                  'inventoryItemId': l.inventoryItemId,
                if (l.inventoryItemId != null) 'unitCode': l.unitCode,
                if (l.variantId != null) 'variantId': l.variantId,
                'quantity': l.quantity.text.trim(),
                if (l.inventoryItemId != null ||
                    l.unitPrice.text.trim() != l.defaultPrice)
                  'unitPrice': l.unitPrice.text.trim(),
                'discountType': l.discountType,
                'discountValue': l.discountType == null
                    ? null
                    : (l.discountValue.text.trim().isEmpty
                          ? '0'
                          : l.discountValue.text.trim()),
                if (l.materialOverridesTouched)
                  'materialOverrides': l.materialOverrides
                      .map(
                        (o) => <String, dynamic>{
                          'inventoryItemId': o.materialId,
                          'quantity': o.quantity.text.trim(),
                          'unitCode': o.unitCode.text.trim(),
                        },
                      )
                      .toList(),
              },
            )
            .toList(),
      }, id: savedId ?? widget.id);
      savedId = r.id;
      if (postAfterSave) {
        if (r.isWalkIn) {
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => ImmediateCollectDialog(
              financeSetupRepository: context
                  .read<FinanceSetupCubit>()
                  .repository,
              invoiceTotal: r.total,
              branchId: r.branchId,
              directSale: true,
              invoiceDate: r.invoiceDate,
            ),
          );
          if (result == null) {
            if (mounted) context.go('/finance/sales/${r.id}');
            return;
          }
          await cubit.repository.postAndCollect(r.id, <String, dynamic>{
            'postIdempotencyKey': 'sales-cash-post-${r.id}',
            'paymentIdempotencyKey': 'sales-cash-pay-${r.id}',
            'paymentDate': result['paymentDate'],
            'amount': result['amount'],
            'paymentMethodId': result['paymentMethodId'],
            if (result['financialLocationId'] != null)
              'financialLocationId': result['financialLocationId'],
          });
        } else {
          await cubit.repository.post(
            r.id,
            'sales-post-${r.id}-${DateTime.now().microsecondsSinceEpoch}',
          );
        }
      }
      if (mounted) context.go('/finance/sales/${r.id}');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ أو ترحيل الفاتورة: $e')),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  double _number(String value) => double.tryParse(value.trim()) ?? 0;
  SalesDraftPreview get _preview => SalesDraftPreview(
    lines: lines
        .map(
          (line) => SalesDraftLineInput(
            quantity: _number(line.quantity.text),
            unitPrice: _number(line.unitPrice.text),
            discountType: line.discountType,
            discountValue: _number(line.discountValue.text),
          ),
        )
        .toList(growable: false),
    invoiceDiscountType: invoiceDiscountType,
    invoiceDiscountValue: _number(invoiceDiscount.text),
    charges: charges.fold(
      0,
      (sum, charge) => sum + _number(charge.amount.text),
    ),
    taxRate: taxRate,
  );
  double get _grossPreview => _preview.gross;
  double get _lineDiscountPreview => _preview.lineDiscount;
  double get _invoiceDiscountPreview => _preview.invoiceDiscount;
  double get _chargesPreview => _preview.charges;
  double get _taxPreview => _preview.tax;
  double get _totalPreview => _preview.total;
  @override
  Widget build(BuildContext context) => FinanceShell(
    title: widget.id == null ? 'فاتورة مبيع جديدة' : 'تعديل فاتورة مبيع',
    subtitle:
        'تحسب الشاشة معاينة فقط؛ المبلغ والضريبة النهائيان يحددهما الخادم.',
    actions: <Widget>[
      ElevatedButton.icon(
        onPressed: saving ? null : () => save(postAfterSave: true),
        style: ElevatedButton.styleFrom(
          backgroundColor: FinanceColors.success,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.check_circle_outline),
        label: Text(
          saving
              ? 'جارٍ الترحيل…'
              : (customers
                            .where((c) => c.id == customerId)
                            .firstOrNull
                            ?.isWalkIn ==
                        true
                    ? 'حفظ وترحيل نقدي'
                    : 'ترحيل فاتورة المبيعات'),
        ),
      ),
    ],
    child: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (catalogError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('تعذر تحميل بعض بيانات الفاتورة: $catalogError'),
                      TextButton(
                        onPressed: bootstrap,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('بيانات الفاتورة', style: FinanceText.title),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: <Widget>[
                        const SizedBox(
                          width: 190,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'رقم الفاتورة',
                            ),
                            child: Text('يُنشأ عند الحفظ'),
                          ),
                        ),
                        _selector<SalesCustomer>(
                          'العميل',
                          customerId,
                          customers,
                          (c) => c.id,
                          (c) => '${c.name} (${c.customerNumber})',
                          (v) => setState(() => customerId = v),
                        ),
                        TextButton.icon(
                          onPressed: _newCustomer,
                          icon: const Icon(Icons.person_add),
                          label: const Text('عميل جديد'),
                        ),
                        _selector<Branch>(
                          'الفرع',
                          branchId,
                          branches,
                          (b) => b.id,
                          (b) => b.name,
                          (v) => setState(() => branchId = v),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => date = d);
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text("تاريخ الفاتورة: ${_date(date)}"),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => dueDate = d);
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                            "الاستحقاق: ${dueDate == null ? 'تلقائي' : _date(dueDate!)}",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: reference,
                      decoration: const InputDecoration(labelText: 'المرجع'),
                    ),
                    TextFormField(
                      controller: notes,
                      decoration: const InputDecoration(
                        labelText: 'البيان / ملاحظات',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Text('بنود الفاتورة', style: FinanceText.title),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: (products.isEmpty && materials.isEmpty)
                      ? null
                      : _addLine,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة بند'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lines.asMap().entries.map((e) => _lineEditor(e.key, e.value)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: invoiceDiscountType,
                    decoration: const InputDecoration(
                      labelText: 'نوع خصم الفاتورة',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('نسبة %')),
                      DropdownMenuItem(value: 'fixed', child: Text('مبلغ')),
                    ],
                    onChanged: (v) => setState(() => invoiceDiscountType = v),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    controller: invoiceDiscount,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'خصم الفاتورة',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('رسوم إضافية', style: FinanceText.title),
            OutlinedButton.icon(
              onPressed: () => setState(() => charges.add(_EditCharge())),
              icon: const Icon(Icons.add),
              label: const Text('إضافة رسوم'),
            ),
            ...charges.asMap().entries.map(
              (e) => Wrap(
                spacing: 10,
                children: <Widget>[
                  SizedBox(
                    width: 200,
                    child: TextFormField(
                      controller: e.value.name,
                      decoration: const InputDecoration(labelText: 'البيان'),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: e.value.amount,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      e.value.dispose();
                      charges.removeAt(e.key);
                    }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ملخص الفاتورة', style: FinanceText.title),
                    const Divider(),
                    _summaryRow('إجمالي البنود', _grossPreview),
                    _summaryRow('خصومات البنود', -_lineDiscountPreview),
                    _summaryRow('خصم الفاتورة', -_invoiceDiscountPreview),
                    _summaryRow('الرسوم الإضافية', _chargesPreview),
                    _summaryRow('الضريبة', _taxPreview),
                    const Divider(),
                    _summaryRow('الإجمالي النهائي', _totalPreview),
                    const Text(
                      'المعاينة تقريبية؛ الخادم يحسب الإجمالي النهائي عند الترحيل.',
                      style: FinanceText.small,
                    ),
                  ],
                ),
              ),
            ),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('أضف منتجات من الكتالوج الحالي.'),
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: saving ? null : () => save(),
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ كمسودة'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _summaryRow(String title, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(title)),
        Text(value.toStringAsFixed(2)),
      ],
    ),
  );
  Widget _selector<T>(
    String label,
    int? value,
    List<T> items,
    int Function(T) id,
    String Function(T) name,
    ValueChanged<int?> onChanged,
  ) => SizedBox(
    width: 260,
    child: DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (x) => DropdownMenuItem(
              value: id(x),
              child: Text(name(x), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'مطلوب' : null,
    ),
  );
  List<_CatalogEntry> get _catalogEntries => <_CatalogEntry>[
    ...products.map(_CatalogEntry.product),
    ...materials.map(_CatalogEntry.material),
  ];

  /// Pre-fills a product line's editable recipe section with the variant's live default recipe, unless the user already customized it for this invoice.
  Future<void> _loadDefaultRecipe(_EditLine line, int variantId) async {
    try {
      final components = await cubit.repository.variantRecipe(variantId);
      if (!mounted || line.materialOverridesTouched) return;
      setState(() {
        for (final o in line.materialOverrides) {
          o.dispose();
        }
        line.materialOverrides = components
            .map(
              (c) => _MaterialOverrideRow(
                materialId: c.materialId,
                materialName: materials
                    .where((m) => m.id == c.materialId)
                    .firstOrNull
                    ?.name,
                quantity: c.quantity,
                unitCode: c.unitCode,
              ),
            )
            .toList();
      });
    } catch (_) {
      // Informational display only — save-time behaviour is unaffected since nothing was touched.
    }
  }

  Widget _lineEditor(int index, _EditLine line) {
    final product = products.where((p) => p.id == line.productId).firstOrNull;
    final variants = product?.variants ?? const <SalesVariant>[];
    final material = materials
        .where((m) => m.id == line.inventoryItemId)
        .firstOrNull;
    final _CatalogEntry? selectedEntry = line.isMaterial
        ? (material == null ? null : _CatalogEntry.material(material))
        : (product == null ? null : _CatalogEntry.product(product));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 260,
                  child: SearchableSelectField<_CatalogEntry>(
                    key: ValueKey(
                      'sales-item-$index-${line.isMaterial}-${line.isMaterial ? line.inventoryItemId : line.productId}',
                    ),
                    label: 'الصنف',
                    items: _catalogEntries,
                    selected: selectedEntry,
                    itemLabel: (e) => e.name,
                    itemSubtitle: (e) => e.subtitle,
                    onSelected: (entry) {
                      setState(() {
                        if (entry == null) {
                          line.productId = null;
                          line.inventoryItemId = null;
                          return;
                        }
                        if (entry.isMaterial) {
                          final m = entry.material!;
                          line.isMaterial = true;
                          line.inventoryItemId = m.id;
                          line.productId = null;
                          line.unitCode = m.baseUnit;
                          return;
                        }
                        final p = entry.product!;
                        line.isMaterial = false;
                        line.productId = p.id;
                        line.inventoryItemId = null;
                        final selected = p.variants
                            .where((x) => x.isDefault)
                            .firstOrNull;
                        line.variantId = selected?.id;
                        line.defaultPrice = selected?.salePrice ?? p.salePrice;
                        line.unitPrice.text = line.defaultPrice;
                      });
                      if (entry != null &&
                          !entry.isMaterial &&
                          line.variantId != null)
                        _loadDefaultRecipe(line, line.variantId!);
                    },
                  ),
                ),
                if (line.isMaterial)
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'sales-unit-$index-${line.inventoryItemId}-${line.unitCode}',
                      ),
                      initialValue: line.unitCode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الوحدة'),
                      items: (material?.units ?? const <String>[])
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => line.unitCode = v),
                    ),
                  )
                else if (variants.isNotEmpty)
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('sales-variant-$index-${line.variantId}'),
                      initialValue: line.variantId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'النوع'),
                      items: variants
                          .map(
                            (v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                v.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          line.variantId = v;
                          line.defaultPrice =
                              variants
                                  .where((x) => x.id == v)
                                  .firstOrNull
                                  ?.salePrice ??
                              product?.salePrice ??
                              '0.00';
                          line.unitPrice.text = line.defaultPrice;
                        });
                        if (v != null) _loadDefaultRecipe(line, v);
                      },
                    ),
                  ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    key: Key('sales-line-quantity-$index'),
                    controller: line.quantity,
                    decoration: const InputDecoration(labelText: 'الكمية'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                        ? 'غير صالح'
                        : null,
                  ),
                ),
                SizedBox(
                  width: 125,
                  child: TextFormField(
                    key: Key('sales-line-price-$index'),
                    controller: line.unitPrice,
                    decoration: const InputDecoration(labelText: 'سعر الوحدة'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? -1) <=
                            (line.inventoryItemId == null ? -0.001 : 0)
                        ? 'غير صالح'
                        : null,
                  ),
                ),
                SizedBox(
                  width: 125,
                  child: DropdownButtonFormField<String>(
                    initialValue: line.discountType,
                    decoration: const InputDecoration(labelText: 'نوع الخصم'),
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('نسبة %')),
                      DropdownMenuItem(value: 'fixed', child: Text('مبلغ')),
                    ],
                    onChanged: (v) => setState(() => line.discountType = v),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: line.discountValue,
                    decoration: const InputDecoration(labelText: 'الخصم'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'الضريبة'),
                    child: Text('${(taxRate * 100).toStringAsFixed(2)}%'),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'إجمالي البند',
                    ),
                    child: Text(
                      (_number(line.quantity.text) *
                              _number(line.unitPrice.text))
                          .toStringAsFixed(2),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    line.dispose();
                    lines.removeAt(index);
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (!line.isMaterial) _materialOverridesSection(line),
          ],
        ),
      ),
    );
  }

  /// The line's editable recipe section — collapsed by default; expanding shows what will be consumed from stock and lets the user correct it for this invoice only (see [_EditLine.materialOverridesTouched]).
  Widget _materialOverridesSection(_EditLine line) {
    final String countLabel = line.materialOverrides.isEmpty
        ? 'لا توجد مكونات'
        : 'مكونات الوصفة (${line.materialOverrides.length})';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextButton.icon(
            onPressed: () => setState(
              () => line.materialOverridesExpanded =
                  !line.materialOverridesExpanded,
            ),
            icon: Icon(
              line.materialOverridesExpanded
                  ? Icons.expand_less
                  : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              countLabel +
                  (line.materialOverridesTouched
                      ? ' — مُعدّلة لهذه الفاتورة'
                      : ''),
              style: FinanceText.small,
            ),
          ),
          if (line.materialOverridesExpanded) ...<Widget>[
            ...line.materialOverrides.asMap().entries.map(
              (e) => _materialOverrideRow(line, e.key, e.value),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                line.materialOverridesTouched = true;
                line.materialOverrides.add(
                  _MaterialOverrideRow(quantity: '0', unitCode: ''),
                );
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة مكوّن'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _materialOverrideRow(
    _EditLine line,
    int index,
    _MaterialOverrideRow row,
  ) {
    final SalesMaterial? selected = materials
        .where((m) => m.id == row.materialId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 220,
            child: SearchableSelectField<SalesMaterial>(
              key: ValueKey('override-material-$index-${row.materialId}'),
              label: 'المادة',
              items: materials,
              selected: selected,
              itemLabel: (m) => m.name,
              itemSubtitle: (m) => m.sku ?? '',
              onSelected: (m) => setState(() {
                line.materialOverridesTouched = true;
                row.materialId = m?.id;
                row.materialName = m?.name;
                if (m != null && row.unitCode.text.trim().isEmpty)
                  row.unitCode.text = m.baseUnit;
              }),
            ),
          ),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: row.quantity,
              decoration: const InputDecoration(labelText: 'الكمية'),
              keyboardType: TextInputType.number,
              onChanged: (_) => line.materialOverridesTouched = true,
            ),
          ),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: row.unitCode,
              decoration: const InputDecoration(labelText: 'الوحدة'),
              onChanged: (_) => line.materialOverridesTouched = true,
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              line.materialOverridesTouched = true;
              row.dispose();
              line.materialOverrides.removeAt(index);
            }),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _newCustomer() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('عميل جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final c = await cubit.repository.createCustomer(<String, dynamic>{
        'name': name,
      });
      if (mounted)
        setState(() {
          customers = <SalesCustomer>[...customers, c];
          customerId = c.id;
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إنشاء العميل.')));
    }
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _EditLine {
  _EditLine({
    this.productId,
    this.inventoryItemId,
    this.unitCode,
    this.variantId,
    this.isMaterial = false,
    String quantity = '1',
    required String unitPrice,
    required this.defaultPrice,
    this.discountType,
    String? discountValue,
    List<_MaterialOverrideRow>? materialOverrides,
    this.materialOverridesTouched = false,
  }) : quantity = TextEditingController(text: quantity),
       unitPrice = TextEditingController(text: unitPrice),
       discountValue = TextEditingController(text: discountValue ?? ''),
       materialOverrides = materialOverrides ?? <_MaterialOverrideRow>[];
  int? productId;
  int? inventoryItemId;
  String? unitCode;
  int? variantId;
  bool isMaterial;
  String defaultPrice;
  String? discountType;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController discountValue;
  List<_MaterialOverrideRow> materialOverrides;
  bool materialOverridesTouched;
  bool materialOverridesExpanded = false;
  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
    discountValue.dispose();
    for (final o in materialOverrides) {
      o.dispose();
    }
  }
}

/// One editable row of a line's recipe override — see [_EditLine.materialOverrides].
class _MaterialOverrideRow {
  _MaterialOverrideRow({
    this.materialId,
    this.materialName,
    required String quantity,
    required String unitCode,
  }) : quantity = TextEditingController(text: quantity),
       unitCode = TextEditingController(text: unitCode);
  int? materialId;
  String? materialName;
  final TextEditingController quantity;
  final TextEditingController unitCode;
  void dispose() {
    quantity.dispose();
    unitCode.dispose();
  }
}

class _EditCharge {
  _EditCharge({String? name, String? amount})
    : name = TextEditingController(text: name ?? ''),
      amount = TextEditingController(text: amount ?? '');
  final TextEditingController name;
  final TextEditingController amount;
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

/// Unifies products and raw materials into one searchable catalog for the
/// combined "إضافة بند" line picker, so the user searches both at once
/// instead of choosing product-vs-material before they can even search.
class _CatalogEntry {
  _CatalogEntry.product(this.product) : material = null;
  _CatalogEntry.material(this.material) : product = null;
  final SalesProduct? product;
  final SalesMaterial? material;
  bool get isMaterial => material != null;
  String get name => isMaterial ? material!.name : product!.name;
  String get subtitle {
    final String? sku = isMaterial ? material!.sku : product!.sku;
    final String kind = isMaterial ? 'مادة خام' : 'منتج';
    return sku == null || sku.isEmpty ? kind : '$kind · $sku';
  }
}

/// §28/§29/§30 — "تسجيل دفعة من العميل": customer + method + amount, then
/// allocate across the customer's open (posted, remaining > 0) invoices.
/// Posting is blocked while any amount is left unallocated (Phase 3 has no
/// unapplied customer credit — see docs/sales §12).
class CustomerPaymentDialog extends StatefulWidget {
  const CustomerPaymentDialog({
    super.key,
    required this.salesRepository,
    required this.financeSetupRepository,
    required this.customerId,
    required this.customerName,
    required this.branchId,
    this.preselectedInvoiceId,
  });
  final SalesRepository salesRepository;
  final FinanceSetupRepository financeSetupRepository;
  final int customerId;
  final String customerName;
  final int branchId;
  final int? preselectedInvoiceId;
  // showDialog pushes onto the root Navigator, so a dialog widget cannot
  // read a Provider scoped to the page route that opened it (see docs on
  // this pattern in the class-level comment of ReceiptDialog below) — both
  // repositories are therefore captured by the caller and passed in here,
  // never re-read via context.read() inside the dialog itself.
  static Future<bool?> show(
    BuildContext context, {
    required SalesRepository salesRepository,
    required FinanceSetupRepository financeSetupRepository,
    required int customerId,
    required String customerName,
    required int branchId,
    int? preselectedInvoiceId,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CustomerPaymentDialog(
      salesRepository: salesRepository,
      financeSetupRepository: financeSetupRepository,
      customerId: customerId,
      customerName: customerName,
      branchId: branchId,
      preselectedInvoiceId: preselectedInvoiceId,
    ),
  );
  @override
  State<CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<CustomerPaymentDialog> {
  final amount = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  List<PaymentMethodSetting> methods = const <PaymentMethodSetting>[];
  int? methodId;
  CashSourceOptions? cashOptions;
  int? cashLocationId;
  CustomerReceivablesSummary? summary;
  final Map<int, TextEditingController> allocation =
      <int, TextEditingController>{};
  bool loading = true;
  bool saving = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    amount.addListener(_refresh);
    bootstrap();
  }

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    notes.dispose();
    for (final c in allocation.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> bootstrap() async {
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.financeSetupRepository.getPaymentMethods(),
        widget.salesRepository.customerReceivables(widget.customerId),
        widget.financeSetupRepository.getCashSourceOptions(widget.branchId),
      ]);
      if (!mounted) return;
      final ms = (results[0] as List<PaymentMethodSetting>)
          .where(
            (m) =>
                m.isActive &&
                (m.type == 'cash' || m.financialLocationId != null),
          )
          .toList();
      final s = results[1] as CustomerReceivablesSummary;
      setState(() {
        methods = ms;
        methodId = ms.firstOrNull?.id;
        summary = s;
        cashOptions = results[2] as CashSourceOptions;
        for (final inv in s.openInvoices) {
          allocation[inv.id] = TextEditingController()..addListener(_refresh);
        }
        final preselected = widget.preselectedInvoiceId;
        if (preselected != null) {
          final inv = s.openInvoices
              .where((x) => x.id == preselected)
              .firstOrNull;
          if (inv != null) {
            allocation[inv.id]!.text = inv.remaining;
            amount.text = inv.remaining;
          }
        }
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  double _num(String s) => double.tryParse(s.trim()) ?? 0;
  double get paymentAmount => _num(amount.text);
  double get totalAllocated => allocation.values.fold(
    0.0,
    (double sum, TextEditingController c) => sum + _num(c.text),
  );
  double get unallocated => paymentAmount - totalAllocated;

  /// §10 — oldest due/open invoice first, using the server's own ordering.
  void autoAllocate() {
    if (summary == null || paymentAmount <= 0) return;
    double left = paymentAmount;
    setState(() {
      for (final c in allocation.values) {
        c.text = '';
      }
      for (final inv in summary!.openInvoices) {
        if (left <= 0.001) break;
        final invRemaining = _num(inv.remaining);
        final take = left < invRemaining ? left : invRemaining;
        if (take > 0) {
          allocation[inv.id]!.text = take.toStringAsFixed(2);
          left -= take;
        }
      }
    });
  }

  Future<void> submit() async {
    if (summary == null) return;
    if (paymentAmount <= 0) {
      _snack('أدخل مبلغاً صحيحاً أكبر من صفر.');
      return;
    }
    if (methodId == null) {
      _snack('اختر طريقة الدفع.');
      return;
    }
    if (unallocated.abs() > 0.004) {
      _snack('يجب توزيع كامل مبلغ الدفعة على الفواتير قبل الترحيل.');
      return;
    }
    final allocations = allocation.entries
        .where((e) => _num(e.value.text) > 0)
        .map(
          (e) => <String, dynamic>{
            'invoiceId': e.key,
            'amount': e.value.text.trim(),
          },
        )
        .toList();
    if (allocations.isEmpty) {
      _snack('حدد فاتورة واحدة على الأقل لتوزيع الدفعة عليها.');
      return;
    }
    final method = methods.firstWhere((m) => m.id == methodId);
    if (method.type == 'cash' &&
        cashOptions?.mode == 'selectable' &&
        cashLocationId == null) {
      _snack('اختر الصندوق.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.salesRepository.registerPayment(<String, dynamic>{
        'branchId': widget.branchId,
        'customerId': widget.customerId,
        'paymentDate': _date(date),
        'amount': amount.text.trim(),
        'paymentMethodId': methodId,
        if (method.type != 'cash' || cashOptions?.mode == 'selectable')
          'financialLocationId': method.type == 'cash'
              ? cashLocationId
              : method.financialLocationId,
        if (reference.text.trim().isNotEmpty)
          'reference': reference.text.trim(),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        'idempotencyKey':
            'customer-pay-${DateTime.now().microsecondsSinceEpoch}',
        'allocations': allocations,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('تعذر تسجيل الدفعة: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    final invoices = summary?.openInvoices ?? const <OpenReceivableInvoice>[];
    return AlertDialog(
      title: Text('تسجيل دفعة من العميل — ${widget.customerName}'),
      content: SizedBox(
        width: 640,
        child: loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : error != null
            ? Text('تعذر تحميل بيانات العميل: $error')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => date = d);
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_date(date)),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<int>(
                            initialValue: methodId,
                            decoration: const InputDecoration(
                              labelText: 'طريقة الدفع',
                            ),
                            items: methods
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(m.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => methodId = v),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            key: const Key('customerPaymentAmountField'),
                            controller: amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'المبلغ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (method?.type == 'cash' && cashOptions?.mode == 'shift')
                      Text(
                        'الصندوق: ${cashOptions?.resolved?.name ?? 'غير محدد'}',
                      ),
                    if (method?.type == 'cash' &&
                        cashOptions?.mode == 'selectable')
                      DropdownButtonFormField<int>(
                        initialValue: cashLocationId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'الصندوق'),
                        items: cashOptions!.allowed
                            .map(
                              (l) => DropdownMenuItem(
                                value: l.id,
                                child: Text(
                                  l.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => cashLocationId = v),
                      ),
                    if (method != null && method.type != 'cash')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'الحساب المستلم: ${method.financialLocationName ?? '—'}',
                          style: FinanceText.small,
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reference,
                      decoration: const InputDecoration(labelText: 'المرجع'),
                    ),
                    TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Text('الفواتير المستحقة', style: FinanceText.title),
                        const Spacer(),
                        TextButton.icon(
                          key: const Key('autoAllocateButton'),
                          onPressed: paymentAmount > 0 ? autoAllocate : null,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('توزيع تلقائي'),
                        ),
                      ],
                    ),
                    if (invoices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('لا توجد فواتير مستحقة لهذا العميل.'),
                      ),
                    ...invoices.map(
                      (inv) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            Expanded(flex: 2, child: Text(inv.invoiceNumber)),
                            Expanded(
                              child: Text(
                                inv.dueDate ?? '—',
                                style: FinanceText.small,
                              ),
                            ),
                            Expanded(child: Text(inv.total)),
                            Expanded(
                              child: Text(
                                inv.remaining,
                                style: TextStyle(
                                  color: inv.isOverdue ? Colors.red : null,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                key: Key('allocationField-${inv.id}'),
                                controller: allocation[inv.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'المخصص',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Wrap(
                      spacing: 24,
                      children: <Widget>[
                        Text(
                          'إجمالي الدفعة: ${amount.text.isEmpty ? '0.00' : amount.text}',
                        ),
                        Text(
                          'إجمالي الموزع: ${totalAllocated.toStringAsFixed(2)}',
                        ),
                        Text(
                          'المتبقي غير الموزع: ${unallocated.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: unallocated.abs() > 0.004
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          key: const Key('customerPaymentSubmit'),
          onPressed: (loading || saving) ? null : submit,
          child: Text(saving ? 'جارٍ الحفظ…' : 'ترحيل الدفعة'),
        ),
      ],
    );
  }
}

/// §31 immediate-payment UX — collects only what "ترحيل وتسجيل دفعة" needs;
/// the two accounting events (invoice post, then settlement) remain separate
/// (see SalesInvoicePostAndCollectService on the backend).
class ImmediateCollectDialog extends StatefulWidget {
  const ImmediateCollectDialog({
    super.key,
    required this.financeSetupRepository,
    required this.invoiceTotal,
    required this.branchId,
    this.directSale = false,
    this.invoiceDate,
  });
  final FinanceSetupRepository financeSetupRepository;
  final String invoiceTotal;
  final int branchId;
  final bool directSale;
  final String? invoiceDate;
  @override
  State<ImmediateCollectDialog> createState() => _ImmediateCollectDialogState();
}

class _ImmediateCollectDialogState extends State<ImmediateCollectDialog> {
  late final TextEditingController amount = TextEditingController(
    text: widget.invoiceTotal,
  );
  List<PaymentMethodSetting> methods = const <PaymentMethodSetting>[];
  CashSourceOptions? cashOptions;
  int? cashLocationId;
  int? methodId;
  bool loading = true;
  Object? error;
  DateTime paymentDate = DateTime.now();
  @override
  void initState() {
    super.initState();
    bootstrap();
  }

  Future<void> _pickPaymentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => paymentDate = picked);
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> bootstrap() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.financeSetupRepository.getPaymentMethods(),
        widget.financeSetupRepository.getCashSourceOptions(widget.branchId),
      ]);
      final ms = (results[0] as List<PaymentMethodSetting>)
          .where(
            (m) =>
                m.isActive &&
                (m.type == 'cash' || m.financialLocationId != null),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        methods = ms;
        methodId = ms.firstOrNull?.id;
        cashOptions = results[1] as CashSourceOptions;
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    return AlertDialog(
      title: const Text('ترحيل الفاتورة وتسجيل دفعة فورية'),
      content: SizedBox(
        width: 420,
        child: loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : error != null
            ? Text('تعذر تحميل طرق الدفع: $error')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.directSale
                        ? 'بيع نقدي كامل: قيد واحد للفاتورة والمدفوع، دون ذمم. تاريخ الدفع هو تاريخ الفاتورة.'
                        : 'عمليتان محاسبيتان منفصلتان في طلب واحد: ترحيل الفاتورة (ذمم مدينة + إيرادات + ضريبة)، ثم تحصيل دفعة تسوية (نقدية/بنك مقابل الذمم). لن تُسجَّل إيرادات مرتين.',
                  ),
                  const SizedBox(height: 14),
                  if (!widget.directSale)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: _pickPaymentDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الدفع',
                          ),
                          child: Text(_dateOnly(paymentDate)),
                        ),
                      ),
                    ),
                  DropdownButtonFormField<int>(
                    initialValue: methodId,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: methods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => methodId = v),
                  ),
                  if (method?.type == 'cash' && cashOptions?.mode == 'shift')
                    Text(
                      'الصندوق: ${cashOptions?.resolved?.name ?? 'غير محدد'}',
                    ),
                  if (method?.type == 'cash' &&
                      cashOptions?.mode == 'selectable')
                    DropdownButtonFormField<int>(
                      initialValue: cashLocationId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الصندوق'),
                      items: cashOptions!.allowed
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                l.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => cashLocationId = v),
                    ),
                  if (method != null && method.type != 'cash')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'الحساب المستلم: ${method.financialLocationName ?? '—'}',
                        style: FinanceText.small,
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    readOnly: widget.directSale,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المبلغ المحصّل الآن',
                      helperText: 'إجمالي الفاتورة: ${widget.invoiceTotal}',
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
        ElevatedButton(
          onPressed:
              (loading ||
                  methodId == null ||
                  (method?.type == 'cash' &&
                      cashOptions?.mode == 'selectable' &&
                      cashLocationId == null))
              ? null
              : () {
                  final selected = methods.firstWhere((m) => m.id == methodId);
                  Navigator.pop(context, <String, dynamic>{
                    'paymentDate': widget.directSale
                        ? widget.invoiceDate
                        : _dateOnly(paymentDate),
                    'amount': widget.directSale
                        ? widget.invoiceTotal
                        : amount.text.trim(),
                    'paymentMethodId': methodId,
                    'financialLocationId': selected.type == 'cash'
                        ? (cashOptions?.mode == 'selectable'
                              ? cashLocationId
                              : null)
                        : selected.financialLocationId,
                  });
                },
          child: const Text('ترحيل وتسجيل الدفعة'),
        ),
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
  static Future<bool?> show(
    BuildContext context, {
    required SalesRepository salesRepository,
    required int paymentId,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => _ReceiptDialogContent(
      salesRepository: salesRepository,
      paymentId: paymentId,
    ),
  );
}

class _ReceiptDialogContent extends StatefulWidget {
  const _ReceiptDialogContent({
    required this.salesRepository,
    required this.paymentId,
  });
  final SalesRepository salesRepository;
  final int paymentId;
  @override
  State<_ReceiptDialogContent> createState() => _ReceiptDialogContentState();
}

class _ReceiptDialogContentState extends State<_ReceiptDialogContent> {
  CustomerPayment? payment;
  Object? error;
  bool reversing = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await widget.salesRepository.payment(widget.paymentId);
      if (mounted)
        setState(() {
          payment = p;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (payment == null)
      return AlertDialog(
        content: error == null
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Text('تعذر تحميل السند: $error'),
      );
    final p = payment!;
    final reversed = p.status == 'reversed';
    return AlertDialog(
      title: const Text('سند قبض'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _row('رقم السند', p.paymentNumber),
              _row('التاريخ', p.paymentDate),
              _row('استلمنا من', p.customerName),
              _row('المبلغ', p.amount),
              _row('طريقة الدفع', p.paymentMethodName),
              _row('الصندوق / البنك', p.financialLocationName),
              _row('البيان', p.reference ?? p.notes ?? '—'),
              const SizedBox(height: 10),
              Text('الفواتير المسددة', style: FinanceText.small),
              if (p.allocations.isEmpty)
                const Text('—')
              else
                ...p.allocations.map(
                  (a) => Text('${a.invoiceNumber}: ${a.amount}'),
                ),
              const Divider(height: 24),
              Text('القيد المحاسبي', style: FinanceText.small),
              Text('مدين ${p.financialLocationName}: ${p.amount}'),
              Text('دائن الذمم المدينة: ${p.amount}'),
              if (reversed)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'تم عكس هذه الدفعة.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (p.canReverse)
          TextButton(
            onPressed: reversing ? null : () => _reverse(),
            child: Text(reversing ? 'جارٍ العكس…' : 'عكس الدفعة'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, reversed),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        SizedBox(width: 140, child: Text(label, style: FinanceText.small)),
        Expanded(child: Text(value)),
      ],
    ),
  );
  Future<void> _reverse() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReversalReasonDialog(),
    );
    if (reason == null || !mounted) return;
    setState(() => reversing = true);
    try {
      await widget.salesRepository.reversePayment(
        widget.paymentId,
        reason: reason,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر عكس الدفعة: $e')));
    } finally {
      if (mounted) setState(() => reversing = false);
    }
  }
}

/// §35 — reversal requires a typed reason, shown to the operator up front
/// alongside the accounting impact before they confirm.
class _ReversalReasonDialog extends StatefulWidget {
  const _ReversalReasonDialog();
  @override
  State<_ReversalReasonDialog> createState() => _ReversalReasonDialogState();
}

class _ReversalReasonDialogState extends State<_ReversalReasonDialog> {
  final controller = TextEditingController();
  String? errorText;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('عكس الدفعة'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'سيُنشأ قيد تسوية جديد: مدين الذمم المدينة، دائن الصندوق أو البنك. الدفعة الأصلية لن تُحذف، وستُعاد فتح الفاتورة (كلياً أو جزئياً) بحسب المبلغ المعكوس.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'سبب العكس',
              errorText: errorText,
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('تراجع'),
      ),
      ElevatedButton(
        onPressed: () {
          final reason = controller.text.trim();
          if (reason.isEmpty) {
            setState(() => errorText = 'مطلوب');
            return;
          }
          Navigator.pop(context, reason);
        },
        child: const Text('تأكيد العكس'),
      ),
    ],
  );
}

/// §33 — minimal "العملاء والمستحقات" view: outstanding is always derived
/// from posted invoices minus allocations, never a stored balance.
class CustomerReceivablesScreen extends StatefulWidget {
  const CustomerReceivablesScreen({super.key});
  @override
  State<CustomerReceivablesScreen> createState() =>
      _CustomerReceivablesScreenState();
}

class _CustomerReceivablesScreenState extends State<CustomerReceivablesScreen> {
  List<CustomerReceivableOverviewRow>? rows;
  Object? error;
  List<Branch> branches = const <Branch>[];
  CustomerArOverviewSummary summary = CustomerArOverviewSummary.empty;
  CustomerArAgingTotals aging = CustomerArAgingTotals.empty;
  SalesCubit get cubit => context.read<SalesCubit>();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        cubit.repository.receivablesOverview(),
        context.read<FinanceSetupCubit>().repository.getBranches(),
        cubit.repository.receivablesSummary(),
        cubit.repository.customerAging(),
      ]);
      if (mounted)
        setState(() {
          rows = results[0] as List<CustomerReceivableOverviewRow>;
          branches = results[1] as List<Branch>;
          summary = results[2] as CustomerArOverviewSummary;
          aging = results[3] as CustomerArAgingTotals;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => FinanceShell(
    title: 'العملاء والمستحقات',
    subtitle:
        'رصيد الذمم المدينة مشتق من الفواتير المرحّلة والتحصيلات الفعلية فقط — لا يوجد رصيد مخزَّن مستقل.',
    child: _body(),
  );
  Widget _body() {
    if (rows == null)
      return error == null
          ? const FinanceLoadingState(label: 'جارٍ تحميل المستحقات…')
          : FinanceErrorState(
              message: 'تعذر تحميل بيانات المستحقات.',
              onRetry: load,
            );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _agingStrip(),
        const SizedBox(height: 16),
        Expanded(
          child: rows!.isEmpty
              ? const FinanceEmptyState(message: 'لا توجد فواتير مرحّلة بعد.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const <DataColumn>[
                      DataColumn(label: Text('العميل')),
                      DataColumn(label: Text('عدد الفواتير')),
                      DataColumn(label: Text('إجمالي الفوترة')),
                      DataColumn(label: Text('إجمالي المحصّل')),
                      DataColumn(label: Text('المستحق')),
                      DataColumn(label: Text('الإجراءات')),
                    ],
                    rows: rows!.map((r) {
                      final outstanding = double.tryParse(r.outstanding) ?? 0;
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(
                            Text('${r.customerName} (${r.customerNumber})'),
                          ),
                          DataCell(Text('${r.invoiceCount}')),
                          DataCell(Text(r.totalInvoiced)),
                          DataCell(Text(r.totalPaid)),
                          DataCell(
                            Text(
                              r.outstanding,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: outstanding > 0 ? Colors.red : null,
                              ),
                            ),
                          ),
                          DataCell(
                            outstanding > 0
                                ? TextButton(
                                    onPressed: () async {
                                      final ok =
                                          await CustomerPaymentDialog.show(
                                            context,
                                            salesRepository: cubit.repository,
                                            financeSetupRepository: context
                                                .read<FinanceSetupCubit>()
                                                .repository,
                                            customerId: r.customerId,
                                            customerName: r.customerName,
                                            branchId:
                                                branches.firstOrNull?.id ?? 0,
                                          );
                                      if (ok == true) load();
                                    },
                                    child: const Text('تسجيل دفعة'),
                                  )
                                : const Text('—'),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _agingStrip() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: <Widget>[
      _agingTile('إجمالي الذمم المدينة', summary.totalOutstanding, Colors.red),
      _agingTile('متداولة', aging.current, null),
      _agingTile('1-30 يوم', aging.days1To30, null),
      _agingTile('31-60 يوم', aging.days31To60, Colors.orange),
      _agingTile('61-90 يوم', aging.days61To90, Colors.deepOrange),
      _agingTile('أكثر من 90 يوم', aging.days90Plus, Colors.red),
      _agingTile(
        'رصيد العملاء الدائن',
        summary.totalCustomerCredit,
        Colors.blueGrey,
      ),
    ],
  );
  Widget _agingTile(String label, String value, Color? color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: FinanceText.small),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}
