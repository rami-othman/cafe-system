import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../data/fa_api.dart';
import '../widgets/fa_widgets.dart';
import 'asset_dialogs.dart';
import 'asset_maintenance_section.dart';
import 'asset_split_widgets.dart';

/// بطاقة أصل: كل ما يخص الأصل في صفحة واحدة — البيانات، الحسابات، الأرقام
/// الدفترية، سجل الحركات (مع عكس آخر حركة)، وجدول الاهتلاك المتوقع.
class AssetCardScreen extends StatefulWidget {
  const AssetCardScreen({super.key, required this.assetId});

  final int assetId;

  @override
  State<AssetCardScreen> createState() => _AssetCardScreenState();
}

class _AssetCardScreenState extends State<AssetCardScreen> {
  final FaApi _api = FaApi();
  Json? _asset;
  FaRefs? _refs;
  List<Json>? _schedule;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.asset(widget.assetId),
        if (_refs == null) FaRefs.load(_api),
      ]);
      if (!mounted) return;
      setState(() {
        _asset = r[0] as Json;
        if (r.length > 1) _refs = r[1] as FaRefs;
        _schedule = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _run(Future<Json?> Function() action, String done) async {
    final Json? result = await action();
    if (result == null || !mounted) return;
    setState(() => _asset = result);
    showFaMessage(context, done);
  }

  Future<void> _simple(Future<dynamic> Function() action, String done) async {
    setState(() => _working = true);
    try {
      final dynamic result = await action();
      if (!mounted) return;
      if (result is Map) setState(() => _asset = asJson(result));
      showFaMessage(context, done);
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _activate() async {
    final bool fromInvoice = _asset!['supplierInvoiceId'] != null;
    final bool opening = _asset!['isOpening'] == true;
    final String cost = str(_asset!['acquisitionCost'], '0');
    final FaRefs refs = _refs!;
    final GlobalKey<PaymentsEditorState> payKey = GlobalKey<PaymentsEditorState>();
    bool generate = !fromInvoice && !opening;
    String? error;
    List<Json>? payments;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => StatefulBuilder(
        builder: (BuildContext d, StateSetter set) => AlertDialog(
          title: const Text('تفعيل الأصل'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fromInvoice
                      ? 'الكلفة مرحّلة مسبقًا بفاتورة المورد؛ لن يُنشأ قيد جديد.'
                      : opening
                      ? 'رصيد افتتاحي: لن يُنشأ قيد (الرصيد موجود في الدفتر).'
                      : 'يُنشأ سند إدخال: مدين حساب الأصل / دائن حساب (أو حسابات) الدفع.',
                ),
                if (!fromInvoice && !opening)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: generate,
                    onChanged: (bool? v) => set(() => generate = v ?? false),
                    title: const Text('توليد سند إدخال'),
                  ),
                if (!fromInvoice && !opening && generate) ...<Widget>[
                  const SizedBox(height: FinanceSpace.sm),
                  PaymentsEditor(
                    key: payKey,
                    label: 'حساب الإدخال (الصندوق / المورد / الشريك)',
                    accounts: refs.accounts,
                    initialAccountId: intOf(asJson(_asset!['fundingAccount'])['id']),
                    total: () => numOf(cost),
                  ),
                ],
                if (error != null) FaErrorText(error),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (!fromInvoice && !opening && generate) {
                  final String? problem = payKey.currentState?.validate(cost);
                  if (problem != null) {
                    set(() => error = problem);
                    return;
                  }
                  payments = payKey.currentState?.payments(cost);
                }
                Navigator.pop(d, true);
              },
              child: const Text('تفعيل'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _simple(() => _api.activate(widget.assetId, generateEntry: generate, payments: generate ? payments : null), 'تم تفعيل الأصل.');
    }
  }

  Future<void> _delete() async {
    if (!await confirmFa(context, 'حذف الأصل', 'تُحذف المسودة نهائيًا من السجل. متابعة؟', confirm: 'حذف')) return;
    try {
      await _api.deleteAsset(widget.assetId);
      if (mounted) context.go('/finance/assets');
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  Future<void> _reverse(Json tx) async {
    final bool ok = await confirmFa(
      context,
      'عكس الحركة',
      'سيُعكس قيد «${tx['typeLabel']}» بتاريخ ${tx['date']} وتُلغى الحركة من سجل الأصل. متابعة؟',
      confirm: 'عكس',
    );
    if (ok) await _simple(() => _api.reverseTransaction(widget.assetId, intOf(tx['id'])!), 'تم عكس الحركة.');
  }

  /// Description + payment legs when paid from several accounts + the expense account of a P&L expense.
  String _txNote(Json t) {
    final List<String> parts = <String>[
      str(t['description'] ?? (t['periodFrom'] != null ? '${t['periodFrom']} → ${t['periodTo']}' : '')),
      if (numOf(t['expenseAmount']) > 0) 'مصروف ${money(t['expenseAmount'])} على ${str(t['expenseAccountName'], 'حساب المصروف')}',
      if (asJsonList(t['payments']).length > 1) 'الدفع: ${asJsonList(t['payments']).map((Json p) => '${p['accountName']} ${money(p['amount'])}').join(' + ')}',
    ].where((String x) => x.trim().isNotEmpty).toList(growable: false);
    return parts.join(' — ');
  }

  Future<void> _loadSchedule() async {
    try {
      final List<Json> rows = await _api.schedule(widget.assetId);
      if (mounted) setState(() => _schedule = rows);
    } catch (e) {
      if (mounted) showFaMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const FinanceLoadingState();
    if (_error != null) return FinanceErrorState(message: _error!, onRetry: _load);
    final Json a = _asset!;
    final FaRefs refs = _refs!;
    final String status = str(a['status']);
    final bool operable = status == 'active' || status == 'fully_depreciated';
    final Json acc = asJson(a['accounts']);
    String accLabel(String key) {
      final Json x = asJson(acc[key]);
      return x.isEmpty ? '—' : '${x['code']} - ${x['name']}';
    }

    final List<Json> txs = asJsonList(a['transactions']);
    final List<Json> components = asJsonList(a['components']);
    final int? lastTx = intOf(a['lastTransactionId']);
    final Json year = asJson(a['yearSummary']);
    final Json prev = asJson(year['previous']);
    final Json cur = asJson(year['current']);

    return ListView(
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(onPressed: () => context.go('/finance/assets'), icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'سجل الأصول'),
            const SizedBox(width: FinanceSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(child: Text('بطاقة أصل — ${a['nameAr']}', style: FinanceText.page)),
                      const SizedBox(width: FinanceSpace.sm),
                      FaStatusPill(status: status, label: str(a['statusLabel'])),
                    ],
                  ),
                  Text('الرمز ${a['code']} · ${a['categoryName'] ?? 'بلا صنف'} · ${a['branchName']}${a['locationName'] != null ? ' / ${a['locationName']}' : ''}', style: FinanceText.subtitle),
                ],
              ),
            ),
            if (_working) const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            Wrap(
              spacing: FinanceSpace.sm,
              children: <Widget>[
                if (status != 'disposed')
                  OutlinedButton.icon(
                    onPressed: () => _run(() => AssetFormDialog.show(context, refs, asset: a), 'تم الحفظ.'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تعديل'),
                  ),
                if (status == 'draft') ...<Widget>[
                  FilledButton.icon(onPressed: _activate, icon: const Icon(Icons.play_arrow_rounded, size: 18), label: const Text('تفعيل')),
                  TextButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('حذف')),
                ],
                if (operable) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _run(() => AssetOperationDialog.show(context, refs, a, AssetOperation.addition), 'تم ترحيل الإضافة.'),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('إضافة إلى الأصل'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _run(() => AssetOperationDialog.show(context, refs, a, AssetOperation.maintenance), 'تم ترحيل الصيانة.'),
                    icon: const Icon(Icons.build_circle_outlined, size: 18),
                    label: const Text('صيانة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _run(() => AssetOperationDialog.show(context, refs, a, AssetOperation.expense), 'تم ترحيل المصروف.'),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('مصروف'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _run(() => AssetOperationDialog.show(context, refs, a, AssetOperation.transfer), 'تم نقل الأصل.'),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('نقل'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _run(() => AssetOperationDialog.show(context, refs, a, AssetOperation.disposal), 'تم ترحيل الاستبعاد.'),
                    icon: const Icon(Icons.sell_outlined, size: 18),
                    label: const Text('بيع / استبعاد'),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: FinanceSpace.lg),
        Wrap(
          spacing: FinanceSpace.md,
          runSpacing: FinanceSpace.md,
          children: <Widget>[
            FaStat(label: 'قيمة إدخال الأصل', value: money(a['acquisitionCost'])),
            FaStat(label: 'الكلفة الحالية (مع الإضافات)', value: money(a['cost'])),
            FaStat(label: 'مجمع الاهتلاك', value: money(a['accumulated']), color: FinanceColors.brown),
            FaStat(label: 'القيمة الحالية', value: money(a['bookValue']), color: FinanceColors.success),
            FaStat(label: 'قيمة الخردة', value: money(a['salvageValue'])),
            if (a['nextMonthDepreciation'] != null) FaStat(label: 'اهتلاك متوقع حتى نهاية الشهر', value: money(a['nextMonthDepreciation'])),
          ],
        ),
        const SizedBox(height: FinanceSpace.lg),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool wide = c.maxWidth > 1100;
            final Widget general = FaSection(
              title: 'عام',
              child: FaFacts(items: <(String, String)>[
                ('الاسم اللاتيني', str(a['nameEn'])),
                ('الباركود', str(a['barcode'])),
                ('الرقم التسلسلي', str(a['serialNumber'])),
                ('الشركة المصنّعة', str(a['manufacturer'])),
                ('المورد', str(a['supplierName'])),
                ('حساب الإدخال', asJson(a['fundingAccount']).isEmpty ? '' : '${asJson(a['fundingAccount'])['code']} - ${asJson(a['fundingAccount'])['name']}'),
                ('تاريخ الشراء', str(a['acquisitionDate'])),
                ('نهاية الكفالة', str(a['warrantyEndDate'])),
                ('ملاحظات', str(a['notes'])),
              ]),
            );
            final Widget depreciation = FaSection(
              title: 'بيانات الاهتلاك',
              child: FaFacts(items: <(String, String)>[
                ('الطريقة', switch (a['method']) { 'none' => 'بدون اهتلاك', 'declining_balance' => 'القسط المتناقص المضاعف (يومي)', _ => 'القسط الثابت (يومي)' }),
                ('العمر الإنتاجي', '${a['usefulLifeMonths']} شهر${intOf(a['lifeChangeMonths'])! > 0 ? ' + ${a['lifeChangeMonths']} (إضافات)' : ''}'),
                ('بدء الاهتلاك', str(a['depreciationStartDate'])),
                ('مهتلك حتى', str(a['depreciatedUntil'], 'لم يُهتلك بعد')),
                if (a['isOpening'] == true) ('مجمع افتتاحي', money(a['openingAccumulated'])),
              ]),
            );
            final Widget accounts = FaSection(
              title: 'الحسابات',
              child: FaFacts(itemWidth: 320, items: <(String, String)>[
                ('حساب الأصل', accLabel('asset')),
                ('مجمع الاهتلاك', accLabel('accumulated')),
                ('مصروف الاهتلاك', accLabel('expense')),
                ('أرباح رأسمالية', accLabel('gain')),
                ('خسائر رأسمالية', accLabel('loss')),
              ]),
            );
            if (!wide) {
              return Column(children: <Widget>[general, const SizedBox(height: FinanceSpace.md), depreciation, const SizedBox(height: FinanceSpace.md), accounts]);
            }
            return Column(
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 3, child: general),
                    const SizedBox(width: FinanceSpace.md),
                    Expanded(flex: 2, child: depreciation),
                  ],
                ),
                const SizedBox(height: FinanceSpace.md),
                accounts,
              ],
            );
          },
        ),
        if (components.isNotEmpty) ...<Widget>[
          const SizedBox(height: FinanceSpace.md),
          FaSection(
            title: 'بنود الأصل',
            child: FaTable(
              minWidth: 700,
              columns: const <String>['البند', 'الكلفة عند الإدخال', 'الكلفة الحالية', 'مصروفات على البند'],
              flex: const <int>[4, 2, 2, 2],
              rows: <List<Widget>>[
                ...components.map((Json c) => <Widget>[faCell(str(c['name']), bold: true), faMoneyCell(c['baseCost']), faMoneyCell(c['cost']), faMoneyCell(c['expenses'])]),
                <Widget>[
                  faCell('المجموع', bold: true),
                  faMoneyCell(components.fold<double>(0, (double s, Json c) => s + numOf(c['baseCost']))),
                  faMoneyCell(components.fold<double>(0, (double s, Json c) => s + numOf(c['cost'])), bold: true),
                  faMoneyCell(components.fold<double>(0, (double s, Json c) => s + numOf(c['expenses']))),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'ملخص السنوات',
          child: FaTable(
            minWidth: 600,
            columns: const <String>['', 'الإضافات والصيانة', 'مصروفات على الأصل', 'الاستبعادات', 'الاهتلاكات'],
            flex: const <int>[2, 2, 2, 2, 2],
            rows: <List<Widget>>[
              <Widget>[faCell('مجمع سابق', bold: true), faMoneyCell(prev['additions']), faMoneyCell(prev['expenses']), faMoneyCell(prev['disposals']), faMoneyCell(prev['depreciation'])],
              <Widget>[faCell('السنة الحالية', bold: true), faMoneyCell(cur['additions']), faMoneyCell(cur['expenses']), faMoneyCell(cur['disposals']), faMoneyCell(cur['depreciation'])],
            ],
          ),
        ),
        if (status != 'draft') ...<Widget>[
          const SizedBox(height: FinanceSpace.md),
          AssetMaintenanceSection(assetId: widget.assetId),
        ],
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'سجل الأصل',
          child: FaTable(
            minWidth: 1150,
            columns: const <String>['التاريخ', 'العملية', 'الفرع', 'الكلفة', 'الاهتلاك', 'ربح/خسارة', 'القيمة بعدها', 'القيد', 'البيان', ''],
            flex: const <int>[2, 2, 2, 2, 2, 2, 2, 2, 4, 2],
            rowColor: (int i) => txs[i]['voided'] == true ? FinanceColors.dangerBg : null,
            rows: txs.map((Json t) {
              final bool voided = t['voided'] == true;
              final bool canReverse = !voided && intOf(t['id']) == lastTx && t['type'] != 'depreciation';
              return <Widget>[
                faCell(str(t['date']), ltr: true),
                faCell('${t['typeLabel']}${voided ? ' (معكوسة)' : ''}', bold: true, color: voided ? FinanceColors.danger : null),
                faCell(t['type'] == 'transfer' ? '${t['branchName']} ← ${t['toBranchName']}' : str(t['branchName'])),
                faMoneyCell(t['costAmount']),
                faMoneyCell(t['depreciationAmount']),
                t['gainLoss'] == null ? faCell('') : faMoneyCell(t['gainLoss']),
                faMoneyCell(t['bookValueAfter'], bold: true),
                faCell(str(t['journalNumber'] ?? t['runNumber']), ltr: true),
                faCell(_txNote(t)),
                canReverse
                    ? TextButton(onPressed: _working ? null : () => _reverse(t), child: const Text('عكس'))
                    : const SizedBox.shrink(),
              ];
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'جدول الاهتلاك المتوقع',
          actions: <Widget>[
            if (_schedule == null && (status == 'active' || status == 'draft'))
              TextButton.icon(onPressed: _loadSchedule, icon: const Icon(Icons.table_chart_outlined, size: 18), label: const Text('عرض')),
          ],
          child: _schedule == null
              ? const Text('الأقساط الشهرية المتوقعة حتى نهاية العمر الإنتاجي.', style: FinanceText.subtitle)
              : FaTable(
                  minWidth: 600,
                  columns: const <String>['نهاية الشهر', 'القسط', 'المجمع', 'القيمة الدفترية'],
                  emptyMessage: 'لا يوجد اهتلاك متبقٍ.',
                  rows: _schedule!
                      .map((Json r) => <Widget>[faCell(str(r['periodEnd']), ltr: true), faMoneyCell(r['amount']), faMoneyCell(r['accumulated']), faMoneyCell(r['bookValue'])])
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: FinanceSpace.xl),
      ],
    );
  }
}
