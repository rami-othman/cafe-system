import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'finance_design.dart';

/// The only Finance tab bar. It is installed by the application shell, so
/// Finance screens do not create competing local navigation.
class FinanceNavigationBar extends StatelessWidget {
  const FinanceNavigationBar({super.key, required this.selected});

  final String selected;

  static const List<_FinanceDestination> _destinations = <_FinanceDestination>[
    _FinanceDestination('overview', 'نظرة عامة', '/finance'),
    _FinanceDestination(
      'transactions',
      'الحركات المالية',
      '/finance?tab=transactions',
    ),
    _FinanceDestination('cashbanks', 'النقدية والبنوك', '/finance/cash-banks'),
    _FinanceDestination('expenses', 'المصروفات', '/finance/expenses'),
    _FinanceDestination(
      'suppliers',
      'الموردون والمستحقات',
      '/finance/suppliers',
    ),
    _FinanceDestination(
      'reconciliation',
      'التسويات',
      '/finance/reconciliation',
    ),
    _FinanceDestination(
      'journals',
      'القيود المحاسبية',
      '/finance/journal-entries',
    ),
    _FinanceDestination('closing', 'الإغلاق اليومي', '/finance/daily-closing'),
    _FinanceDestination('reports', 'التقارير المالية', '/finance/reports'),
    _FinanceDestination('accounts', 'الحسابات', '/finance/accounts'),
    _FinanceDestination(
      'periods',
      'الفترات المالية',
      '/finance/accounting-periods',
    ),
    _FinanceDestination('settings', 'الإعدادات', '/finance/settings'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    decoration: const BoxDecoration(
      color: FinanceColors.workspace,
      border: Border(bottom: BorderSide(color: FinanceColors.border)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: FinanceSpace.sm,
        vertical: 8,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: _destinations
            .map(
              (_FinanceDestination destination) => Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: FinanceSpace.sm,
                ),
                child: _FinanceNavigationItem(
                  destination: destination,
                  selected: destination.id == selected,
                ),
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
}

class _FinanceDestination {
  const _FinanceDestination(this.id, this.label, this.path);
  final String id;
  final String label;
  final String path;
}

class _FinanceNavigationItem extends StatelessWidget {
  const _FinanceNavigationItem({
    required this.destination,
    required this.selected,
  });
  final _FinanceDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? FinanceColors.primary : FinanceColors.card,
    borderRadius: BorderRadius.circular(FinanceRadius.control),
    child: InkWell(
      onTap: () => context.go(destination.path),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
      child: Container(
        key: ValueKey<String>('finance-tab-${destination.id}'),
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? FinanceColors.primary : FinanceColors.border,
          ),
          borderRadius: BorderRadius.circular(FinanceRadius.control),
        ),
        child: Text(
          destination.label,
          style: TextStyle(
            color: selected ? Colors.white : FinanceColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
