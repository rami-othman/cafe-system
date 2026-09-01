import 'package:flutter/material.dart';

import 'finance_pagination.dart';

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
  });

  static const int rowsPerPage = 10;

  final List<DataColumn> columns;
  final List<DataRow> rows;
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
    if (!identical(oldWidget.rows, widget.rows)) {
      _page = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.rows.length;
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
      child: SizedBox(
        width: widget.minWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DataTable(
              columns: widget.columns,
              rows: widget.rows.sublist(start, end),
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
    );
  }
}
