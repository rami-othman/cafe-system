import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The single Finance navigation bar used by the workspace and Finance detail
/// routes.  It intentionally mirrors the approved RTL desktop order.
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
      '/finance/reconciliations',
    ),
    _FinanceDestination(
      'journals',
      'القيود المحاسبية',
      '/finance/journal-entries',
    ),
    _FinanceDestination('closing', 'الإغلاق اليومي', '/finance/daily-closings'),
    _FinanceDestination(
      'reports',
      'التقارير المالية',
      '/finance/reports/general-ledger',
    ),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: const BoxDecoration(
      color: Color(0xffFCFAF8),
      border: Border(bottom: BorderSide(color: Color(0xffE8DED4))),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        textDirection: TextDirection.rtl,
        children: _destinations
            .map(
              (_FinanceDestination destination) => Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
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
    color: selected ? const Color(0xff3D2518) : Colors.white,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: () => context.go(destination.path),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xff3D2518) : const Color(0xffE8DED4),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          destination.label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xff3D2518),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
