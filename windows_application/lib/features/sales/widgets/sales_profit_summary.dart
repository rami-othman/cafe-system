import 'package:flutter/material.dart';
import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../models/sales_profitability.dart';

class SalesProfitSummary extends StatelessWidget {
  const SalesProfitSummary({super.key, required this.profit});
  final SalesProfitability profit;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(FinanceSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('هامش البيع بعد المرتجعات', style: FinanceText.page),
          const SizedBox(height: FinanceSpace.md),
          Wrap(
            spacing: FinanceSpace.lg,
            runSpacing: FinanceSpace.md,
            children: [
              _value('الإيراد دون الضريبة', profit.netRevenue),
              _value('تكلفة البضاعة المباعة', profit.netCogs),
              _value('الهامش الإجمالي', profit.grossProfit),
              _value(
                'نسبة الهامش',
                profit.grossMarginPercent == null
                    ? '—'
                    : '${profit.grossMarginPercent}%',
              ),
            ],
          ),
          const SizedBox(height: FinanceSpace.md),
          Text(
            'الهامش محسوب من تكلفة المخزون المثبتة عند البيع. لا يشمل الأجور والكهرباء والمصاريف التشغيلية؛ ليس ربحاً صافياً.',
            style: FinanceText.small,
          ),
        ],
      ),
    ),
  );

  Widget _value(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: FinanceText.small),
      Text(value, style: FinanceText.body),
    ],
  );
}
