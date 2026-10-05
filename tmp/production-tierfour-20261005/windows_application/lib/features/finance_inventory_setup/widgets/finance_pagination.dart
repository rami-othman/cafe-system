import 'package:flutter/material.dart';

import '../../../app/localization/localization_extensions.dart';
import 'finance_design.dart';

class FinancePageMeta {
  const FinancePageMeta({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  const FinancePageMeta.singlePage({this.total = 0})
    : currentPage = 1,
      perPage = 10,
      lastPage = 1;

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < lastPage;

  factory FinancePageMeta.fromJson(Map<String, dynamic>? json, {int total = 0}) {
    if (json == null) return FinancePageMeta.singlePage(total: total);
    final int current = (json['currentPage'] as num?)?.toInt() ?? 1;
    final int perPage = (json['perPage'] as num?)?.toInt() ?? 10;
    final int responseTotal = (json['total'] as num?)?.toInt() ?? total;
    final int last = (json['lastPage'] as num?)?.toInt() ?? 1;
    return FinancePageMeta(
      currentPage: current < 1 ? 1 : current,
      perPage: perPage < 1 ? 10 : perPage,
      total: responseTotal < 0 ? 0 : responseTotal,
      lastPage: last < 1 ? 1 : last,
    );
  }
}

class FinancePage<T> {
  const FinancePage({required this.items, required this.meta});

  final List<T> items;
  final FinancePageMeta meta;
}

class FinancePagination extends StatelessWidget {
  const FinancePagination({
    super.key,
    required this.meta,
    required this.onPageChanged,
  });

  final FinancePageMeta meta;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (meta.total <= meta.perPage && meta.currentPage == 1) {
      return const SizedBox.shrink();
    }
    final int start = meta.total == 0 ? 0 : (meta.currentPage - 1) * meta.perPage + 1;
    final int end = (meta.currentPage * meta.perPage).clamp(0, meta.total).toInt();
    return Padding(
      padding: const EdgeInsets.only(top: FinanceSpace.md),
      child: Wrap(
        spacing: FinanceSpace.sm,
        runSpacing: FinanceSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            context.l10n.financePaginationRange(start, end, meta.total),
            style: FinanceText.small,
          ),
          OutlinedButton.icon(
            onPressed: meta.hasPrevious
                ? () => onPageChanged(meta.currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            label: Text(context.l10n.financePaginationPrevious),
          ),
          Text(
            context.l10n.financePaginationPage(meta.currentPage, meta.lastPage),
            style: FinanceText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          OutlinedButton.icon(
            onPressed: meta.hasNext ? () => onPageChanged(meta.currentPage + 1) : null,
            icon: const Icon(Icons.chevron_right),
            label: Text(context.l10n.financePaginationNext),
          ),
        ],
      ),
    );
  }
}
