import 'package:flutter/material.dart';

import '../../finance_inventory_setup/widgets/finance_components.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../fixed_assets/data/fa_api.dart';
import '../../fixed_assets/widgets/fa_widgets.dart';

/// بوابة المستثمر (قراءة فقط): حصصه بالفروع، أرصدته، توزيعاته وكشف حسابه — لا شيء غير ذلك.
class InvestorPortalScreen extends StatefulWidget {
  const InvestorPortalScreen({super.key});

  @override
  State<InvestorPortalScreen> createState() => _InvestorPortalScreenState();
}

class _InvestorPortalScreenState extends State<InvestorPortalScreen> {
  final FaApi _api = FaApi();
  late String _from = isoDate(DateTime(DateTime.now().year, 1, 1));
  String _to = isoDate(DateTime.now());
  List<Json>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final List<Json> d = await _api.portal(_from, _to);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  static String _accountLabel(String a) => switch (a) {
    'capital' => 'رأس المال',
    'drawings' => 'المسحوبات',
    _ => 'الجاري',
  };

  Widget _notLinked() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.account_balance_wallet_outlined, size: 48),
            const SizedBox(height: FinanceSpace.md),
            const Text('حسابك غير مرتبط بمستثمر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: FinanceSpace.sm),
            const Text(
              'ليظهر لك سجل حصصك وأرصدتك، اطلب من المدير ربط مستخدمك بحساب الشريك من «الشركاء والمستثمرون» ← تعديل الشريك ← المستخدم المرتبط.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FinanceSpace.md),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 18), label: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (_error!.contains('مرتبط بمستخدمك')) return _notLinked();
      return FinanceErrorState(message: _error!, onRetry: _load);
    }
    if (_data == null) return const FinanceLoadingState();
    return ListView(
      children: <Widget>[
        const FinancePageHeader(title: 'حسابي كمستثمر', subtitle: 'حصصك بالفروع وأرصدتك وتوزيعاتك وكشف حسابك — للاطلاع فقط.'),
        const SizedBox(height: FinanceSpace.md),
        Wrap(
          spacing: FinanceSpace.md,
          runSpacing: FinanceSpace.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FaDateField(label: 'من', value: _from, width: 160, onChanged: (String? v) => setState(() => _from = v ?? _from)),
            FaDateField(label: 'إلى', value: _to, width: 160, onChanged: (String? v) => setState(() => _to = v ?? _to)),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 18), label: const Text('تحديث')),
          ],
        ),
        for (final Json entry in _data!) ...<Widget>[
          const SizedBox(height: FinanceSpace.lg),
          _PartnerBlock(partner: asJson(entry['partner']), statement: asJson(entry['statement'])),
        ],
      ],
    );
  }
}

class _PartnerBlock extends StatelessWidget {
  const _PartnerBlock({required this.partner, required this.statement});

  final Json partner;
  final Json statement;

  @override
  Widget build(BuildContext context) {
    final Json closing = asJson(statement['closing']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FaSection(
          title: str(partner['name']),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: FinanceSpace.md,
                runSpacing: FinanceSpace.md,
                children: <Widget>[
                  FaStat(label: 'رأس المال', value: money(asJson(partner['capitalAccount'])['balance'])),
                  FaStat(label: 'الحساب الجاري', value: money(asJson(partner['currentAccount'])['balance'])),
                  FaStat(label: 'المسحوبات', value: money(asJson(partner['drawingsAccount'])['balance'])),
                  FaStat(label: 'صافي المركز', value: money(partner['netPosition']), color: FinanceColors.primary),
                ],
              ),
              const SizedBox(height: FinanceSpace.md),
              FaTable(
                minWidth: 500,
                columns: const <String>['الفرع', 'حصتك'],
                flex: const <int>[4, 1],
                emptyMessage: 'لا توجد حصص حالية.',
                rows: asJsonList(partner['branches'])
                    .map((Json b) => <Widget>[faCell(str(b['branchName']), bold: true), faCell('${b['sharePercent']}%', ltr: true)])
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'التوزيعات',
          child: FaTable(
            minWidth: 800,
            columns: const <String>['الرقم', 'الفرع', 'الفترة', 'النسبة', 'المبلغ'],
            flex: const <int>[2, 2, 3, 1, 2],
            emptyMessage: 'لا توجد توزيعات.',
            rows: asJsonList(statement['distributions'])
                .map((Json d) => <Widget>[
                      faCell(str(d['number']), ltr: true),
                      faCell(str(d['branchName'])),
                      faCell('${d['periodFrom']} → ${d['periodTo']}', ltr: true),
                      faCell('${d['sharePercent']}%', ltr: true),
                      faMoneyCell(d['amount'], bold: true),
                    ])
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: FinanceSpace.md),
        FaSection(
          title: 'كشف الحساب (الرصيد الختامي ${money(closing['total'])})',
          child: FaTable(
            minWidth: 900,
            columns: const <String>['التاريخ', 'الحساب', 'البيان', 'مدين', 'دائن', 'الرصيد'],
            flex: const <int>[2, 2, 4, 2, 2, 2],
            emptyMessage: 'لا توجد حركات بهذه الفترة.',
            rows: asJsonList(statement['lines'])
                .map((Json l) => <Widget>[
                      faCell(str(l['date']), ltr: true),
                      faCell(_InvestorPortalScreenState._accountLabel(str(l['account']))),
                      faCell(str(l['description'])),
                      faMoneyCell(l['debit']),
                      faMoneyCell(l['credit']),
                      faMoneyCell(l['balance'], bold: true),
                    ])
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
