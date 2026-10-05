import 'package:flutter/material.dart';

import 'finance_pagination.dart';
import 'finance_design.dart';

/// Consistent ten-row pagination for Finance data tables.
///
/// The screen still owns loading, filtering, and row actions; this widget only
/// selects the visible table rows and renders the shared page controls.
class FinancePaginatedTable extends StatefulWidget {
  const FinancePaginatedTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.minWidth,
    this.emptyMessage,
    this.rowCount,
    this.rowBuilder,
  });

  static const int rowsPerPage = 10;

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int? rowCount;
  final DataRow Function(int index)? rowBuilder;
  final double minWidth;
  final String? emptyMessage;

  @override
  State<FinancePaginatedTable> createState() => _FinancePaginatedTableState();
}

class _FinancePaginatedTableState extends State<FinancePaginatedTable> {
  int _page = 1;

  @override
  void didUpdateWidget(covariant FinancePaginatedTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rows, widget.rows) ||
        oldWidget.rowCount != widget.rowCount ||
        !identical(oldWidget.rowBuilder, widget.rowBuilder)) {
      _page = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.rowCount ?? widget.rows.length;
    final int lastPage = (total / FinancePaginatedTable.rowsPerPage)
        .ceil()
        .clamp(1, 1 << 31)
        .toInt();
    final int page = _page.clamp(1, lastPage).toInt();
    final int start = (page - 1) * FinancePaginatedTable.rowsPerPage;
    final int end = (start + FinancePaginatedTable.rowsPerPage)
        .clamp(0, total)
        .toInt();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: widget.minWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DataTable(
                headingRowColor: const WidgetStatePropertyAll<Color>(
                  FinanceColors.tableHead,
                ),
                dividerThickness: 0.7,
                headingTextStyle: FinanceText.label.copyWith(
                  color: FinanceColors.brown,
                ),
                columns: widget.columns,
                rows: widget.rowBuilder == null
                    ? widget.rows.sublist(start, end)
                    : List<DataRow>.generate(
                        end - start,
                        (index) => widget.rowBuilder!(start + index),
                      ),
              ),
              FinancePagination(
                meta: FinancePageMeta(
                  currentPage: page,
                  perPage: FinancePaginatedTable.rowsPerPage,
                  total: total,
                  lastPage: lastPage,
                ),
                onPageChanged: (int value) => setState(() => _page = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
