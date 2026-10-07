import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../finance_inventory_setup/widgets/finance_design.dart';
import '../../pos/models/branch.dart';
import '../data/fa_api.dart';

/// Small building blocks shared by the fixed-assets and partners screens.

void showFaMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? FinanceColors.danger : null,
    ),
  );
}

Future<bool> confirmFa(BuildContext context, String title, String message, {String confirm = 'تأكيد'}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(confirm)),
      ],
    ),
  );
  return ok == true;
}

/// White card with a title row — the section container used across the module.
class FaSection extends StatelessWidget {
  const FaSection({super.key, required this.title, required this.child, this.actions = const <Widget>[], this.padding});

  final String title;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(FinanceSpace.lg),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(title, style: FinanceText.page.copyWith(fontSize: 15))),
            ...actions,
          ],
        ),
        const SizedBox(height: FinanceSpace.md),
        child,
      ],
    ),
  );
}

/// Label / value pair laid out in a responsive wrap.
class FaFacts extends StatelessWidget {
  const FaFacts({super.key, required this.items, this.itemWidth = 210});

  final List<(String, String)> items;
  final double itemWidth;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: FinanceSpace.lg,
    runSpacing: FinanceSpace.md,
    children: items
        .map(
          ((String, String) item) => SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.$1, style: FinanceText.label),
                const SizedBox(height: 2),
                Text(item.$2.isEmpty ? '—' : item.$2, style: FinanceText.body.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        )
        .toList(growable: false),
  );
}

/// Simple read-only grid table with a header row; [flex] sets column widths.
class FaTable extends StatelessWidget {
  const FaTable({
    super.key,
    required this.columns,
    required this.rows,
    this.flex,
    this.onTap,
    this.minWidth = 900,
    this.footer,
    this.emptyMessage = 'لا توجد بيانات',
    this.rowColor,
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final void Function(int index)? onTap;
  final double minWidth;
  final List<Widget>? footer;
  final String emptyMessage;
  final Color? Function(int index)? rowColor;

  Widget _row(List<Widget> cells, {Color? color}) => Container(
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: FinanceSpace.md, vertical: 10),
    child: Row(
      children: List<Widget>.generate(
        cells.length,
        (int i) => Expanded(
          flex: flex != null && i < flex!.length ? flex![i] : 1,
          child: Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: cells[i]),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double width = constraints.maxWidth.isFinite && constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Container(
            decoration: BoxDecoration(
              color: FinanceColors.card,
              border: Border.all(color: FinanceColors.border),
              borderRadius: BorderRadius.circular(FinanceRadius.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _row(
                  columns
                      .map((String c) => Text(c, style: FinanceText.label.copyWith(color: FinanceColors.brown)))
                      .toList(growable: false),
                  color: FinanceColors.tableHead,
                ),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(FinanceSpace.xl),
                    child: Text(emptyMessage, style: FinanceText.subtitle),
                  ),
                ...List<Widget>.generate(
                  rows.length,
                  (int i) => InkWell(
                    onTap: onTap == null ? null : () => onTap!(i),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: FinanceColors.border))),
                      child: _row(rows[i], color: rowColor?.call(i)),
                    ),
                  ),
                ),
                if (footer != null)
                  DecoratedBox(
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: FinanceColors.border, width: 2))),
                    child: _row(footer!, color: FinanceColors.workspace),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget faCell(String text, {bool bold = false, Color? color, bool ltr = false}) {
  final Widget label = Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: FinanceText.body.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color),
  );
  return ltr ? Directionality(textDirection: TextDirection.ltr, child: Align(alignment: AlignmentDirectional.centerStart, child: label)) : label;
}

Widget faMoneyCell(dynamic value, {bool bold = false, Color? color}) {
  final double n = numOf(value);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.centerRight,
      child: Text(
        money(value),
        style: FinanceText.body.copyWith(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? (n < 0 ? FinanceColors.danger : null),
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

/// Date field that opens the date picker; value is an ISO yyyy-MM-dd string.
class FaDateField extends StatelessWidget {
  const FaDateField({super.key, required this.label, required this.value, required this.onChanged, this.width = 180, this.allowClear = false});

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final double width;
  final bool allowClear;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: InkWell(
      onTap: () async {
        final DateTime initial = parseDate(value) ?? DateTime.now();
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(isoDate(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: allowClear && value != null
              ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => onChanged(null))
              : const Icon(Icons.calendar_today_outlined, size: 16),
        ),
        child: Text(value ?? '—', style: FinanceText.body),
      ),
    ),
  );
}

/// Plain outlined text field with optional numeric keyboard.
class FaTextField extends StatelessWidget {
  const FaTextField({
    super.key,
    required this.label,
    required this.controller,
    this.width,
    this.numeric = false,
    this.integer = false,
    this.maxLines = 1,
    this.hint,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final double? width;
  final bool numeric;
  final bool integer;
  final int maxLines;
  final String? hint;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final Widget field = TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: numeric || integer ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: integer
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : numeric
          ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder()),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }
}

/// Branch selector with an optional "head office" (no branch) entry and an optional "all" entry.
class FaBranchDropdown extends StatelessWidget {
  const FaBranchDropdown({
    super.key,
    required this.branches,
    required this.value,
    required this.onChanged,
    this.label = 'الفرع',
    this.includeCompany = true,
    this.includeAll = false,
    this.width = 220,
  });

  final List<Branch> branches;

  /// null = all (when [includeAll]) or head office; 'company' = head office; else branch id as string.
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool includeCompany;
  final bool includeAll;
  final double width;

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String?>> items = <DropdownMenuItem<String?>>[
      if (includeAll) const DropdownMenuItem<String?>(value: null, child: Text('كل الفروع')),
      if (includeCompany) const DropdownMenuItem<String?>(value: kCompanyBranch, child: Text(kCompanyBranchLabel)),
      ...branches.map((Branch b) => DropdownMenuItem<String?>(value: '${b.id}', child: Text(b.name))),
    ];
    final bool known = items.any((DropdownMenuItem<String?> i) => i.value == value);
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        key: ValueKey<String?>('branch-$label-$value'),
        initialValue: known ? value : items.first.value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

/// Coloured status pill for asset statuses.
class FaStatusPill extends StatelessWidget {
  const FaStatusPill({super.key, required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ({Color foreground, Color background, Color border}) tone = financeTone(switch (status) {
      'active' || 'posted' => FinanceTone.success,
      'draft' => FinanceTone.warning,
      'disposed' || 'reversed' => FinanceTone.danger,
      _ => FinanceTone.neutral,
    });
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: tone.background,
          border: Border.all(color: tone.border),
          borderRadius: BorderRadius.circular(FinanceRadius.pill),
        ),
        child: Text(label, style: FinanceText.small.copyWith(color: tone.foreground, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Big number tile.
class FaStat extends StatelessWidget {
  const FaStat({super.key, required this.label, required this.value, this.color, this.width = 210});

  final String label;
  final String value;
  final Color? color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(FinanceSpace.md),
    decoration: BoxDecoration(
      color: FinanceColors.card,
      border: Border.all(color: FinanceColors.border),
      borderRadius: BorderRadius.circular(FinanceRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: FinanceText.label),
        const SizedBox(height: FinanceSpace.xs),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(value, style: FinanceText.title.copyWith(fontSize: 19, color: color)),
        ),
      ],
    ),
  );
}

/// Dialog frame with a scrollable body and bottom actions, wider than FinanceDialogShell.
class FaDialog extends StatelessWidget {
  const FaDialog({super.key, required this.title, required this.child, required this.actions, this.maxWidth = 760});

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: Padding(
        padding: const EdgeInsets.all(FinanceSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: FinanceText.page),
            const SizedBox(height: FinanceSpace.lg),
            Flexible(child: SingleChildScrollView(child: child)),
            const SizedBox(height: FinanceSpace.lg),
            Wrap(alignment: WrapAlignment.end, spacing: FinanceSpace.sm, children: actions),
          ],
        ),
      ),
    ),
  );
}

/// Inline error line for dialogs.
class FaErrorText extends StatelessWidget {
  const FaErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: FinanceSpace.sm),
          child: Text(message!, style: FinanceText.body.copyWith(color: FinanceColors.danger)),
        );
}

/// Button that shows a spinner while [busy].
class FaBusyButton extends StatelessWidget {
  const FaBusyButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : onPressed,
    icon: busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon ?? Icons.check_rounded, size: 18),
    label: Text(label),
  );
}
