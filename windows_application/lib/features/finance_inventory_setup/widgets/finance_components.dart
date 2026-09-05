import 'package:flutter/material.dart';

import 'finance_design.dart';

class FinancePageHeader extends StatelessWidget {
  const FinancePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: FinanceText.page),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: FinanceSpace.xs),
              Text(subtitle!, style: FinanceText.subtitle),
            ],
          ],
        ),
      ),
      if (actions.isNotEmpty) ...<Widget>[
        const SizedBox(width: FinanceSpace.md),
        ...actions,
      ],
    ],
  );
}

class FinanceKpiData {
  const FinanceKpiData({
    required this.label,
    required this.value,
    this.trend,
    this.tone = FinanceTone.neutral,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String? trend;
  final FinanceTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
}

class FinanceKpiGrid extends StatelessWidget {
  const FinanceKpiGrid({super.key, required this.items});

  final List<FinanceKpiData> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = constraints.maxWidth >= 1160
          ? 4
          : constraints.maxWidth >= 760
          ? 2
          : 1;
      final double width =
          (constraints.maxWidth - (columns - 1) * FinanceSpace.md) / columns;
      return Wrap(
        spacing: FinanceSpace.md,
        runSpacing: FinanceSpace.md,
        children: items
            .map(
              (FinanceKpiData item) => SizedBox(
                width: width,
                child: FinanceKpiCard(item: item),
              ),
            )
            .toList(growable: false),
      );
    },
  );
}

class FinanceKpiCard extends StatelessWidget {
  const FinanceKpiCard({super.key, required this.item});

  final FinanceKpiData item;

  @override
  Widget build(BuildContext context) {
    final tone = financeTone(item.tone);
    final Widget card = Container(
      padding: const EdgeInsets.all(FinanceSpace.lg),
      decoration: BoxDecoration(
        color: FinanceColors.card,
        border: Border.all(color: FinanceColors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(item.label, style: FinanceText.label)),
              if (item.icon != null)
                Icon(item.icon, size: 18, color: tone.foreground),
            ],
          ),
          const SizedBox(height: FinanceSpace.sm),
          Text(item.value, style: FinanceText.title),
          if (item.trend != null) ...<Widget>[
            const SizedBox(height: FinanceSpace.xs),
            Text(
              item.trend!,
              style: FinanceText.small.copyWith(color: tone.foreground),
            ),
          ],
        ],
      ),
    );
    if (item.onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(FinanceRadius.card),
      child: InkWell(
        onTap: item.onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(FinanceRadius.card),
        child: card,
      ),
    );
  }
}

class FinanceStatusBadge extends StatelessWidget {
  const FinanceStatusBadge({super.key, required this.status});

  final String status;

  static ({String label, FinanceTone tone}) resolve(String value) {
    switch (value.trim().toLowerCase()) {
      case 'approved':
        return (label: 'معتمد', tone: FinanceTone.success);
      case 'paid':
      case 'posted':
      case 'closed':
      case 'active':
      case 'matched':
        return (label: 'مكتمل', tone: FinanceTone.success);
      case 'pending_approval':
        return (label: 'بانتظار الموافقة', tone: FinanceTone.warning);
      case 'pending':
      case 'draft':
      case 'open':
      case 'unpaid':
      case 'in_progress':
        return (label: 'قيد المراجعة', tone: FinanceTone.warning);
      case 'rejected':
      case 'cancelled':
      case 'overdue':
      case 'failed':
      case 'void':
        return (label: 'مرفوض', tone: FinanceTone.danger);
      case 'reversed':
        return (label: 'معكوس', tone: FinanceTone.neutral);
      default:
        return (label: value, tone: FinanceTone.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolve(status);
    return FinanceStatusBadgeCustom(label: resolved.label, tone: resolved.tone);
  }
}

/// A status pill with an explicit label and tone, for values that are not a
/// backend lifecycle `status` string (e.g. a derived readiness label).
class FinanceStatusBadgeCustom extends StatelessWidget {
  const FinanceStatusBadgeCustom({super.key, required this.label, required this.tone});
  final String label;
  final FinanceTone tone;
  @override
  Widget build(BuildContext context) {
    final colors = financeTone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.pill),
      ),
      child: Text(
        label,
        style: FinanceText.small.copyWith(color: colors.foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class FinanceFilterBar extends StatelessWidget {
  const FinanceFilterBar({super.key, required this.children, this.onReset});

  final List<Widget> children;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.md),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Wrap(
      spacing: FinanceSpace.sm,
      runSpacing: FinanceSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ...children,
        if (onReset != null)
          TextButton(onPressed: onReset, child: const Text('إعادة تعيين')),
      ],
    ),
  );
}

class FinanceTable extends StatelessWidget {
  const FinanceTable({
    super.key,
    required this.headers,
    required this.rows,
    this.minWidth = 780,
    this.onRowTap,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final double minWidth;
  final void Function(int index)? onRowTap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SizedBox(
      width: minWidth,
      child: Container(
        decoration: BoxDecoration(
          color: FinanceColors.card,
          border: Border.all(color: FinanceColors.border),
          borderRadius: BorderRadius.circular(FinanceRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            _TableRow(
              cells: headers
                  .map(
                    (String h) => Text(
                      h,
                      style: FinanceText.label.copyWith(
                        color: FinanceColors.brown,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                  .toList(),
              color: FinanceColors.tableHead,
            ),
            ...List<Widget>.generate(
              rows.length,
              (int index) => InkWell(
                onTap: onRowTap == null ? null : () => onRowTap!(index),
                child: _TableRow(cells: rows[index]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.color});
  final List<Widget> cells;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    color: color,
    constraints: const BoxConstraints(minHeight: 48),
    child: Row(
      children: cells
          .map(
            (Widget cell) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FinanceSpace.md,
                  vertical: FinanceSpace.sm,
                ),
                child: cell,
              ),
            ),
          )
          .toList(),
    ),
  );
}

class FinanceEntityHeader extends StatelessWidget {
  const FinanceEntityHeader({
    super.key,
    required this.title,
    this.reference,
    this.status,
    this.actions = const <Widget>[],
  });
  final String title;
  final String? reference;
  final String? status;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: FinanceText.page),
              if (reference != null) ...<Widget>[
                const SizedBox(height: FinanceSpace.xs),
                FinanceReference(reference: reference!),
              ],
            ],
          ),
        ),
        if (status != null) FinanceStatusBadge(status: status!),
        if (actions.isNotEmpty) ...<Widget>[
          const SizedBox(width: FinanceSpace.md),
          ...actions,
        ],
      ],
    ),
  );
}

class FinanceInfoItem {
  const FinanceInfoItem(this.label, this.value);
  final String label;
  final String value;
}

class FinanceInfoGrid extends StatelessWidget {
  const FinanceInfoGrid({super.key, required this.items});
  final List<FinanceInfoItem> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Wrap(
      spacing: FinanceSpace.xl,
      runSpacing: FinanceSpace.lg,
      children: items.map((FinanceInfoItem item) {
        return SizedBox(
          width: 190,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(item.label, style: FinanceText.label),
              const SizedBox(height: 3),
              Text(item.value, style: FinanceText.body),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class FinanceAlertBanner extends StatelessWidget {
  const FinanceAlertBanner({
    super.key,
    required this.message,
    this.tone = FinanceTone.warning,
    this.action,
  });
  final String message;
  final FinanceTone tone;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final colors = financeTone(tone);
    return Container(
      padding: const EdgeInsets.all(FinanceSpace.md),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(FinanceRadius.control),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            tone == FinanceTone.danger
                ? Icons.error_outline
                : Icons.info_outline,
            color: colors.foreground,
          ),
          const SizedBox(width: FinanceSpace.sm),
          Expanded(
            child: Text(
              message,
              style: FinanceText.body.copyWith(color: colors.foreground),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class FinanceReadinessPanel extends StatelessWidget {
  const FinanceReadinessPanel({super.key, required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('الجاهزية التشغيلية', style: FinanceText.page),
        const SizedBox(height: FinanceSpace.sm),
        ...items.map(
          (String item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_outline,
                  size: 17,
                  color: FinanceColors.success,
                ),
                const SizedBox(width: FinanceSpace.sm),
                Text(item, style: FinanceText.body),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class FinanceOperationalBar extends StatelessWidget {
  const FinanceOperationalBar({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: FinanceSpace.lg,
      vertical: FinanceSpace.sm,
    ),
    color: FinanceColors.ink,
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            message,
            style: FinanceText.body.copyWith(color: Colors.white),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: const TextStyle(
              color: Color(0xffFEC29E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class FinanceDialogShell extends StatelessWidget {
  const FinanceDialogShell({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(FinanceSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: FinanceText.page),
            const SizedBox(height: FinanceSpace.lg),
            child,
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: FinanceSpace.lg),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ],
        ),
      ),
    ),
  );
}

class FinanceJournalDrawer extends StatelessWidget {
  const FinanceJournalDrawer({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Drawer(
    width: 460,
    backgroundColor: FinanceColors.workspace,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FinanceSpace.lg),
        child: child,
      ),
    ),
  );
}

class FinanceLoadingState extends StatelessWidget {
  const FinanceLoadingState({super.key, this.label = 'جارٍ تحميل البيانات…'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(color: FinanceColors.brown),
        const SizedBox(height: FinanceSpace.md),
        Text(label, style: FinanceText.subtitle),
      ],
    ),
  );
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState({
    super.key,
    this.message = 'لا توجد بيانات لعرضها',
    this.action,
  });
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.inbox_outlined, color: FinanceColors.muted, size: 36),
        const SizedBox(height: FinanceSpace.sm),
        Text(message, style: FinanceText.subtitle),
        if (action != null) ...<Widget>[
          const SizedBox(height: FinanceSpace.sm),
          action!,
        ],
      ],
    ),
  );
}

class FinanceErrorState extends StatelessWidget {
  const FinanceErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => FinanceAlertBanner(
    message: message,
    tone: FinanceTone.danger,
    action: onRetry == null
        ? null
        : TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
  );
}

class FinanceAmount extends StatelessWidget {
  const FinanceAmount({super.key, required this.value, this.currency = 'SYP', this.color});
  final String value;
  final String currency;
  final Color? color;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      '$value $currency',
      style: FinanceText.body.copyWith(
        color: color,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    ),
  );
}

class FinanceReference extends StatelessWidget {
  const FinanceReference({super.key, required this.reference});
  final String reference;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      reference,
      style: FinanceText.small.copyWith(color: FinanceColors.supporting),
    ),
  );
}

/// Presents the fixed, backend-defined cash-transfer posting rule (debit the
/// destination account, credit the source account) for the selected accounts.
/// Display-only: Laravel remains the sole poster of the journal entry, so
/// this preview must never be treated as authoritative posting logic.
class FinanceAccountImpactPreview extends StatelessWidget {
  const FinanceAccountImpactPreview({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.amount,
  });
  final String? fromLabel;
  final String? toLabel;
  final String amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FinanceSpace.md),
    decoration: BoxDecoration(
      color: FinanceColors.workspace,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.control),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('الأثر المحاسبي المتوقع', style: FinanceText.label),
        const SizedBox(height: FinanceSpace.sm),
        _ImpactRow(
          label: toLabel ?? '—',
          side: 'مدين',
          tone: FinanceTone.success,
          amount: amount,
        ),
        const SizedBox(height: 4),
        _ImpactRow(
          label: fromLabel ?? '—',
          side: 'دائن',
          tone: FinanceTone.warning,
          amount: amount,
        ),
      ],
    ),
  );
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.label,
    required this.side,
    required this.tone,
    required this.amount,
  });
  final String label;
  final String side;
  final FinanceTone tone;
  final String amount;
  @override
  Widget build(BuildContext context) {
    final colors = financeTone(tone);
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(FinanceRadius.pill),
          ),
          child: Text(
            side,
            style: FinanceText.small.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: FinanceSpace.sm),
        Expanded(child: Text(label, style: FinanceText.body)),
        FinanceAmount(value: amount),
      ],
    );
  }
}
