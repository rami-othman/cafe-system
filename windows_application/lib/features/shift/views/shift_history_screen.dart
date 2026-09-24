import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shift_route_locations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/shift_history_cubit.dart';
import '../controllers/shift_history_state.dart';
import '../models/shift_models.dart';
import '../widgets/shift_design.dart';
import '../widgets/shift_format.dart';
import '../widgets/shift_primitives.dart';
import '../widgets/shift_state_views.dart';
import '../widgets/shift_strings.dart';

/// Searchable/filterable shift history with a summary KPI row, a dense
/// desktop table (scrolling horizontally under `minWidth`) and pagination.
class ShiftHistoryScreen extends StatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  State<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends State<ShiftHistoryScreen> {
  late final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ShiftHistoryCubit>().load(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ShiftHistoryCubit, ShiftHistoryState>(
    builder: (BuildContext context, ShiftHistoryState state) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(ShiftStrings.historyTitle, style: ShiftText.pageTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(ShiftStrings.historySubtitle, style: ShiftText.body),
          const SizedBox(height: AppSpacing.lg),
          _HistoryFilters(state: state, searchController: _searchController),
          const SizedBox(height: AppSpacing.lg),
          _buildBody(context, state),
        ],
      ),
    ),
  );

  Widget _buildBody(BuildContext context, ShiftHistoryState state) {
    final ShiftHistoryCubit cubit = context.read<ShiftHistoryCubit>();
    final DateTime now = cubit.now;

    switch (state.status) {
      case ShiftHistoryStatusView.loading:
        return const ShiftTableSkeleton(label: ShiftStrings.loadingHistory);
      case ShiftHistoryStatusView.error:
        return ShiftErrorView(
          title: ShiftStrings.errorLoadingHistory,
          detail: state.errorMessage,
          onRetry: cubit.load,
        );
      case ShiftHistoryStatusView.empty:
      case ShiftHistoryStatusView.ready:
        break;
    }

    final ShiftHistorySummary summary = state.summary(now);
    final List<ShiftHistoryEntry> pageEntries = state.pageEntries(now);
    final int totalMatches = state.filtered(now).length;
    final int pages = state.pageCount(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HistorySummaryRow(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        if (totalMatches == 0)
          ShiftEmptyView(
            title: ShiftStrings.historyEmpty,
            detail: ShiftStrings.historyEmptyHint,
            icon: Icons.search_off,
            action: ShiftButton(
              label: ShiftStrings.clearFilters,
              variant: ShiftButtonVariant.secondary,
              onPressed: cubit.clearFilters,
            ),
          )
        else ...<Widget>[
          _HistoryTable(entries: pageEntries),
          const SizedBox(height: AppSpacing.md),
          _Pagination(page: state.page.clamp(1, pages), pages: pages, onPage: cubit.goToPage),
        ],
      ],
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({required this.state, required this.searchController});

  final ShiftHistoryState state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final ShiftHistoryCubit cubit = context.read<ShiftHistoryCubit>();
    return ShiftCard(
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          ShiftSearchField(
            controller: searchController,
            hintText: ShiftStrings.searchHistoryHint,
            width: 240,
            onChanged: cubit.search,
          ),
          ShiftDropdown<ShiftHistoryPeriod>(
            width: 150,
            value: state.period,
            items: const <ShiftDropdownItem<ShiftHistoryPeriod>>[
              ShiftDropdownItem(value: ShiftHistoryPeriod.today, label: ShiftStrings.periodToday),
              ShiftDropdownItem(
                value: ShiftHistoryPeriod.yesterday,
                label: ShiftStrings.periodYesterday,
              ),
              ShiftDropdownItem(
                value: ShiftHistoryPeriod.thisWeek,
                label: ShiftStrings.periodThisWeek,
              ),
              ShiftDropdownItem(
                value: ShiftHistoryPeriod.thisMonth,
                label: ShiftStrings.periodThisMonth,
              ),
              ShiftDropdownItem(
                value: ShiftHistoryPeriod.custom,
                label: ShiftStrings.periodCustom,
              ),
            ],
            onChanged: (ShiftHistoryPeriod? v) {
              if (v == null) return;
              if (v == ShiftHistoryPeriod.custom) {
                _pickCustomRange(context, cubit);
              } else {
                cubit.setPeriod(v);
              }
            },
          ),
          ShiftDropdown<String>(
            width: 170,
            value: state.cashier,
            hint: ShiftStrings.allCashiers,
            items: <ShiftDropdownItem<String>>[
              const ShiftDropdownItem(value: null, label: ShiftStrings.allCashiers),
              for (final String c in state.cashierOptions)
                ShiftDropdownItem(value: c, label: c),
            ],
            onChanged: cubit.setCashier,
          ),
          ShiftDropdown<String>(
            width: 170,
            value: state.branch,
            hint: ShiftStrings.allBranches,
            items: <ShiftDropdownItem<String>>[
              const ShiftDropdownItem(value: null, label: ShiftStrings.allBranches),
              for (final String b in state.branchOptions)
                ShiftDropdownItem(value: b, label: b),
            ],
            onChanged: cubit.setBranch,
          ),
          ShiftDropdown<ShiftDifferenceFilter>(
            width: 170,
            value: state.differenceFilter,
            hint: ShiftStrings.differenceFilter,
            items: const <ShiftDropdownItem<ShiftDifferenceFilter>>[
              ShiftDropdownItem(
                value: ShiftDifferenceFilter.all,
                label: ShiftStrings.differenceAll,
              ),
              ShiftDropdownItem(
                value: ShiftDifferenceFilter.matched,
                label: ShiftStrings.differenceMatched,
              ),
              ShiftDropdownItem(
                value: ShiftDifferenceFilter.shortage,
                label: ShiftStrings.differenceShort,
              ),
              ShiftDropdownItem(
                value: ShiftDifferenceFilter.surplus,
                label: ShiftStrings.differenceOver,
              ),
            ],
            onChanged: (ShiftDifferenceFilter? v) =>
                cubit.setDifferenceFilter(v ?? ShiftDifferenceFilter.all),
          ),
          if (state.hasActiveFilters)
            ShiftButton(
              label: ShiftStrings.clearFilters,
              variant: ShiftButtonVariant.quiet,
              icon: Icons.filter_alt_off_outlined,
              onPressed: () {
                searchController.clear();
                cubit.clearFilters();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context, ShiftHistoryCubit cubit) async {
    final DateTime now = cubit.now;
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );
    if (range != null) cubit.setCustomRange(range.start, range.end);
  }
}

class _HistorySummaryRow extends StatelessWidget {
  const _HistorySummaryRow({required this.summary});

  final ShiftHistorySummary summary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = constraints.maxWidth >= ShiftLayout.desktopBreakpoint
          ? 4
          : constraints.maxWidth >= ShiftLayout.tabletBreakpoint
          ? 2
          : 1;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: columns == 1 ? 3 : 2,
        children: <Widget>[
          ShiftMetricCard(
            label: ShiftStrings.shiftsCount,
            value: ShiftFormat.count(summary.shiftCount),
            icon: Icons.schedule_outlined,
          ),
          ShiftMetricCard(
            label: ShiftStrings.totalNetSales,
            value: ShiftFormat.money(summary.totalNetSales),
            icon: Icons.savings_outlined,
            tone: ShiftTone.success,
          ),
          ShiftMetricCard(
            label: ShiftStrings.totalCashDifferences,
            value: ShiftFormat.signedMoney(summary.totalCashDifference),
            icon: Icons.balance_outlined,
            tone: summary.totalCashDifference.abs() <= 0.5
                ? ShiftTone.success
                : ShiftTone.warning,
          ),
          ShiftMetricCard(
            label: ShiftStrings.averageShiftDuration,
            value: ShiftFormat.shortDuration(summary.averageDuration),
            icon: Icons.timelapse_outlined,
          ),
        ],
      );
    },
  );
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.entries});

  final List<ShiftHistoryEntry> entries;

  static const List<ShiftTableCell> _headers = <ShiftTableCell>[
    ShiftTableCell(ShiftStrings.shiftNumber, flex: 1.2),
    ShiftTableCell(ShiftStrings.date, flex: 1),
    ShiftTableCell(ShiftStrings.cashier, flex: 1),
    ShiftTableCell(ShiftStrings.branch, flex: 1),
    ShiftTableCell(ShiftStrings.openedAt, flex: .8, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.closedAt, flex: .8, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.duration, flex: .8, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.orderCount, flex: .7, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.netSales, flex: 1, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.cashSales, flex: 1, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.cashDifference, flex: 1, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.barDifferences, flex: .8, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.status, flex: .9, alignment: Alignment.center),
    ShiftTableCell(ShiftStrings.details, flex: .8, alignment: AlignmentDirectional.centerEnd),
  ];

  @override
  Widget build(BuildContext context) => ShiftTableFrame(
    minWidth: 1500,
    child: Column(
      children: <Widget>[
        ShiftTableHeader(cells: _headers),
        for (final ShiftHistoryEntry entry in entries) _HistoryRow(entry: entry),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final ShiftHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    // Uncounted closes (automatic / legacy reconcile) have no cash difference.
    final (ShiftTone diffTone, String diffLabel) = switch (entry.closeMode) {
      ShiftCloseMode.automatic => (ShiftTone.neutral, ShiftStrings.closeTypeAutomatic),
      ShiftCloseMode.legacyReconcile => (ShiftTone.accent, ShiftStrings.closeTypeLegacyReconcile),
      ShiftCloseMode.unknown => (ShiftTone.neutral, ShiftStrings.closeTypeUnknown),
      ShiftCloseMode.manual => entry.isBalanced
          ? (ShiftTone.success, ShiftStrings.differenceMatched)
          : entry.isShortage
          ? (ShiftTone.warning, ShiftStrings.differenceShort)
          : (ShiftTone.surplus, ShiftStrings.differenceOver),
    };

    return InkWell(
      onTap: () => context.push(ShiftRouteLocations.report(entry.shiftNumber)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: ShiftColors.border)),
        ),
        child: Row(
          children: <Widget>[
            _cell(1.2, ShiftValue(entry.shiftNumber, style: ShiftText.bodyStrong)),
            _cell(1, Text(ShiftFormat.isoDate(entry.date), style: ShiftText.tableCell)),
            _cell(1, Text(entry.cashierName, style: ShiftText.tableCell)),
            _cell(1, Text(entry.branchName, style: ShiftText.tableCell)),
            _cell(
              .8,
              ShiftValue(
                ShiftFormat.time(entry.openedAt),
                align: TextAlign.center,
                style: ShiftText.tableCell,
              ),
              center: true,
            ),
            _cell(
              .8,
              ShiftValue(
                ShiftFormat.time(entry.closedAt),
                align: TextAlign.center,
                style: ShiftText.tableCell,
              ),
              center: true,
            ),
            _cell(
              .8,
              ShiftValue(
                ShiftFormat.shortDuration(entry.duration),
                align: TextAlign.center,
                style: ShiftText.tableCell,
              ),
              center: true,
            ),
            _cell(
              .7,
              ShiftValue(
                ShiftFormat.count(entry.orderCount),
                align: TextAlign.center,
                style: ShiftText.tableCell,
              ),
              center: true,
            ),
            _cell(
              1,
              ShiftValue(
                ShiftFormat.money(entry.netSales),
                align: TextAlign.center,
                style: ShiftText.bodyStrong,
              ),
              center: true,
            ),
            _cell(
              1,
              ShiftValue(
                ShiftFormat.money(entry.cashSales),
                align: TextAlign.center,
                style: ShiftText.tableCell,
              ),
              center: true,
            ),
            _cell(
              1,
              ShiftValue(
                entry.isCounted
                    ? ShiftFormat.signedMoney(entry.cashDifference)
                    : ShiftStrings.notApplicable,
                align: TextAlign.center,
                style: ShiftText.bodyStrong,
                color: diffTone.ink,
              ),
              center: true,
            ),
            _cell(
              .8,
              ShiftValue(
                ShiftFormat.count(entry.barDifferenceCount),
                align: TextAlign.center,
                style: ShiftText.tableCell,
                color: entry.barDifferenceCount > 0
                    ? ShiftColors.shortageInk
                    : ShiftColors.ink,
              ),
              center: true,
            ),
            _cell(.9, Center(child: ShiftBadge(label: diffLabel, tone: diffTone, dense: true))),
            _cell(
              .8,
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ShiftButton(
                  label: ShiftStrings.viewReport,
                  variant: ShiftButtonVariant.quiet,
                  onPressed: () =>
                      context.push(ShiftRouteLocations.report(entry.shiftNumber)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(double flex, Widget child, {bool center = false}) => Expanded(
    flex: (flex * 10).round(),
    child: center ? Center(child: child) : child,
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.page, required this.pages, required this.onPage});

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      IconButton(
        onPressed: page > 1 ? () => onPage(page - 1) : null,
        icon: const Icon(Icons.chevron_right),
        color: ShiftColors.inkSoft,
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: ShiftColors.surface,
          borderRadius: AppRadius.control,
          border: Border.all(color: ShiftColors.border),
        ),
        child: Text(ShiftStrings.pageOf(page, pages), style: ShiftText.bodyStrong),
      ),
      IconButton(
        onPressed: page < pages ? () => onPage(page + 1) : null,
        icon: const Icon(Icons.chevron_left),
        color: ShiftColors.inkSoft,
      ),
    ],
  );
}
