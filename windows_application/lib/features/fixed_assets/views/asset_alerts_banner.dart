import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../data/fa_api.dart';

/// تنبيهات سجل الأصول: كفالات تنتهي (أو انتهت حديثًا) وأصول يقترب انتهاء عمرها الإنتاجي.
/// يختفي تمامًا إذا لا توجد تنبيهات أو تعذّر التحميل (التنبيهات إضافة لا تعطّل السجل).
class AssetAlertsBanner extends StatefulWidget {
  const AssetAlertsBanner({super.key, this.days = 60});

  final int days;

  @override
  State<AssetAlertsBanner> createState() => _AssetAlertsBannerState();
}

class _AssetAlertsBannerState extends State<AssetAlertsBanner> {
  final FaApi _api = FaApi();
  Json? _data;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Json d = await _api.alerts(days: widget.days);
      if (mounted) setState(() => _data = d);
    } catch (_) {
      // alerts are optional; the register keeps working without them
    }
  }

  Widget _row(Json a, String note, {bool danger = false}) => InkWell(
    onTap: () => context.go('/finance/assets/${a['id']}'),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('${a['code']} — ${a['nameAr']} (${a['branchName']})', style: FinanceText.body)),
          Text(note, style: FinanceText.body.copyWith(color: danger ? FinanceColors.danger : FinanceColors.warning, fontWeight: FontWeight.w700)),
          const SizedBox(width: FinanceSpace.md),
          Text(str(a['date']), style: FinanceText.subtitle),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final Json? d = _data;
    if (d == null || intOf(d['count']) == 0) return const SizedBox.shrink();
    final List<Json> warranty = asJsonList(d['warranty']);
    final List<Json> life = asJsonList(d['endOfLife']);
    return Padding(
      padding: const EdgeInsets.only(bottom: FinanceSpace.md),
      child: Container(
        decoration: BoxDecoration(color: FinanceColors.warningBg, border: Border.all(color: FinanceColors.warningBorder), borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(FinanceSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.notifications_active_outlined, size: 18, color: FinanceColors.warning),
                  const SizedBox(width: FinanceSpace.sm),
                  Expanded(
                    child: Text(
                      'تنبيهات (${d['count']}): ${warranty.length} كفالة، ${life.length} أصل يقترب انتهاء عمره خلال ${d['days']} يومًا',
                      style: FinanceText.label,
                    ),
                  ),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                ],
              ),
            ),
            if (_open) ...<Widget>[
              const SizedBox(height: FinanceSpace.sm),
              if (warranty.isNotEmpty) const Text('الكفالات', style: FinanceText.subtitle),
              for (final Json a in warranty) _row(a, a['expired'] == true ? 'انتهت منذ ${(intOf(a['daysLeft']) ?? 0).abs()} يومًا' : 'تنتهي بعد ${a['daysLeft']} يومًا', danger: a['expired'] == true),
              if (life.isNotEmpty) ...<Widget>[
                const SizedBox(height: FinanceSpace.sm),
                const Text('انتهاء العمر الإنتاجي', style: FinanceText.subtitle),
              ],
              for (final Json a in life) _row(a, 'بعد ${a['daysLeft']} يومًا (القيمة الدفترية ${money(a['bookValue'])})'),
            ],
          ],
        ),
      ),
    );
  }
}
