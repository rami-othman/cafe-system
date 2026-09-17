import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../controllers/shift_closing_cubit.dart';
import '../controllers/shift_closing_state.dart';
import '../models/shift_models.dart';
import '../widgets/shift_bar_count_row.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_state_views.dart';
import '../widgets/shift_strings.dart';
import 'shift_closing_screen.dart';

/// Step 3 — bar count. A metadata strip, a search/filter/sort toolbar, a
/// desktop table (or mobile/tablet cards) and a completion summary that
/// blocks nothing but clearly flags what is left uncounted.
class ShiftClosingStep3BarCount extends StatefulWidget {
  const ShiftClosingStep3BarCount({super.key});

  @override
  State<ShiftClosingStep3BarCount> createState() => _ShiftClosingStep3BarCountState();
}

class _ShiftClosingStep3BarCountState extends State<ShiftClosingStep3BarCount> {
  late final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftClosingCubit, ShiftClosingState>(
    builder: (BuildContext context, ShiftClosingState state) {
      final ShiftClosingCubit cubit = context.read<ShiftClosingCubit>();
      final BarCountTemplate template = state.barTemplate!;
      final List<BarCountLine> visible = state.visibleBarLines;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ShiftWizardStepHeader(title: ShiftStrings.barCount),
          _MetaStrip(template: template),
          const SizedBox(height: AppSpacing.lg),
          _Toolbar(
            searchController: _searchController,
            state: state,
            cubit: cubit,
            uncountedCount: template.uncountedItems,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (visible.isEmpty) {
                return const ShiftEmptyView(
                  title: ShiftStrings.historyEmpty,
                  icon: Icons.search_off,
                );
              }
              if (constraints.maxWidth >= ShiftLayout.desktopBreakpoint) {
                return _DesktopTable(lines: visible, cubit: cubit);
              }
              return Column(
                children: <Widget>[
                  for (final BarCountLine line in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: BarCountCard(
                        line: line,
                        onCountedChanged: (String v) =>
                            cubit.updateCountedQuantity(line.id, v),
                        onNoteChanged: (String v) => cubit.updateLineNote(line.id, v),
                        onFillTheoretical: () => cubit.fillWithTheoretical(line.id),
                        onClear: () => cubit.clearCount(line.id),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _CompletionSummary(template: template),
        ],
      );
    },
  );
}

class _MetaStrip extends StatelessWidget {
  const _MetaStrip({required this.template});

  final BarCountTemplate template;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ShiftFactTile(
            label: ShiftStrings.warehouse,
            value: template.warehouseName,
            numeric: false,
          ),
        ),
        Expanded(
          child: ShiftFactTile(
            label: ShiftStrings.itemsToCount,
            value: ShiftFormat.count(template.totalItems),
          ),
        ),
        Expanded(
          child: ShiftFactTile(
            label: ShiftStrings.itemsCounted,
            value: '${ShiftFormat.count(template.countedItems)}/${ShiftFormat.count(template.totalItems)}',
          ),
        ),
        Expanded(
          child: ShiftFactTile(
            label: ShiftStrings.currentDifferences,
            value: ShiftFormat.count(template.differenceItems),
            valueColor: template.differenceItems > 0
                ? ShiftColors.shortageInk
                : ShiftColors.ink,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(ShiftFormat.percent(template.progress), style: ShiftText.metricValueSmall),
              const SizedBox(height: 6),
              ShiftProgressBar(value: template.progress),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.state,
    required this.cubit,
    required this.uncountedCount,
  });

  final TextEditingController searchController;
  final ShiftClosingState state;
  final ShiftClosingCubit cubit;
  final int uncountedCount;

  static const List<(BarCountFilter, String)> _filters = <(BarCountFilter, String)>[
    (BarCountFilter.all, ShiftStrings.filterAll),
    (BarCountFilter.uncounted, ShiftStrings.filterUncounted),
    (BarCountFilter.matched, ShiftStrings.filterMatched),
    (BarCountFilter.shortage, ShiftStrings.filterShortage),
    (BarCountFilter.surplus, ShiftStrings.filterSurplus),
    (BarCountFilter.differences, ShiftStrings.filterDifferencesOnly),
  ];

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ShiftSearchField(
              controller: searchController,
              hintText: ShiftStrings.searchItem,
              width: 220,
              onChanged: cubit.updateBarSearch,
            ),
            ShiftDropdown<BarCountSort>(
              width: 190,
              value: state.barSort,
              hint: ShiftStrings.sortBy,
              items: const <ShiftDropdownItem<BarCountSort>>[
                ShiftDropdownItem(value: BarCountSort.name, label: ShiftStrings.sortByName),
                ShiftDropdownItem(
                  value: BarCountSort.category,
                  label: ShiftStrings.sortByCategory,
                ),
                ShiftDropdownItem(
                  value: BarCountSort.largestDifference,
                  label: ShiftStrings.sortByLargestDifference,
                ),
              ],
              onChanged: (BarCountSort? v) => cubit.setBarSort(v ?? BarCountSort.name),
            ),
            if (uncountedCount > 0)
              ShiftButton(
                buttonKey: const Key('shift-bar-accept-all'),
                label: ShiftStrings.acceptAllMatching,
                variant: ShiftButtonVariant.secondary,
                icon: Icons.done_all,
                onPressed: () => _confirmAcceptAll(context),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final (BarCountFilter filter, String label) in _filters)
              ShiftFilterChip(
                label: label,
                isSelected: state.barFilter == filter,
                onTap: () => cubit.setBarFilter(filter),
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _confirmAcceptAll(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ShiftStrings.acceptAllMatchingConfirmTitle,
                  style: ShiftText.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  ShiftStrings.acceptAllMatchingConfirmBody(uncountedCount),
                  style: ShiftText.body,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ShiftButton(
                        label: ShiftStrings.back,
                        variant: ShiftButtonVariant.secondary,
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ShiftButton(
                        buttonKey: const Key('shift-bar-accept-all-confirm'),
                        label: ShiftStrings.confirm,
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) cubit.acceptAllUncountedAsMatching();
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.lines, required this.cubit});

  final List<BarCountLine> lines;
  final ShiftClosingCubit cubit;

  static const List<ShiftTableCell> _headers = <ShiftTableCell>[
    ShiftTableCell(ShiftStrings.item, flex: 3.2),
    ShiftTableCell(ShiftStrings.unit, flex: 1.2),
    ShiftTableCell(ShiftStrings.theoreticalQty, flex: 1.8, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.actualQty, flex: 2, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.difference, flex: 1.6, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.differenceStatus, flex: 1.8, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) => ShiftTableFrame(
    minWidth: 1000,
    child: Column(
      children: <Widget>[
        ShiftTableHeader(cells: _headers),
        for (int i = 0; i < lines.length; i++) ...<Widget>[
          if (i > 0) const Divider(height: 1, color: ShiftColors.border),
          BarCountRow(
            line: lines[i],
            onCountedChanged: (String v) => cubit.updateCountedQuantity(lines[i].id, v),
            onNoteChanged: (String v) => cubit.updateLineNote(lines[i].id, v),
            onFillTheoretical: () => cubit.fillWithTheoretical(lines[i].id),
            onClear: () => cubit.clearCount(lines[i].id),
            onSubmitNext: () {
              final String? next = cubit.nextUncountedAfter(lines[i].id);
              if (next != null) {
                FocusScope.of(context).requestFocus(FocusNode());
              }
            },
          ),
        ],
      ],
    ),
  );
}

class _CompletionSummary extends StatelessWidget {
  const _CompletionSummary({required this.template});

  final BarCountTemplate template;

  @override
  Widget build(BuildContext context) => ShiftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          ShiftStrings.countedOf(template.countedItems, template.totalItems),
          style: ShiftText.cardTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            ShiftBadge(
              label: '${ShiftStrings.statusMatch}: ${ShiftFormat.count(template.matchedItems)}',
              tone: ShiftTone.success,
            ),
            ShiftBadge(
              label: '${ShiftStrings.statusShortage}: ${ShiftFormat.count(template.shortageItems)}',
              tone: ShiftTone.warning,
            ),
            ShiftBadge(
              label: '${ShiftStrings.statusSurplus}: ${ShiftFormat.count(template.surplusItems)}',
              tone: ShiftTone.surplus,
            ),
          ],
        ),
        if (!template.isComplete) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          ShiftNotice(
            tone: ShiftTone.warning,
            message: ShiftStrings.uncountedRemaining(template.uncountedItems),
          ),
        ],
      ],
    ),
  );
}
