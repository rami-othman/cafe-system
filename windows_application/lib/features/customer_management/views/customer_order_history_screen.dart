import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/customer_management_route_locations.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_order_history_cubit.dart';
import '../controllers/customer_order_history_state.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_bidi_value.dart';
import '../widgets/customer_detail_sections.dart';
import '../widgets/customer_lifecycle_actions.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_surface.dart';
import '../widgets/customer_management_visual_tokens.dart';

class CustomerOrderHistoryScreen extends StatefulWidget {
  const CustomerOrderHistoryScreen({
    super.key,
    required this.customerId,
    this.repository,
  });
  final int customerId;
  final CustomerManagementRepository? repository;
  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CustomerOrderHistoryCubit>().load(widget.customerId),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CustomerOrderHistoryCubit, CustomerOrderHistoryState>(
    builder: (context, state) {
      if (state.customer == null &&
          state.status != CustomerOrderHistoryStatus.failure) {
        return const CustomerManagementStatePanel(
          loadingGeometry: CustomerManagementLoadingGeometry.detail,
        );
      }
      if (state.customer == null) {
        return CustomerManagementStatePanel(
          failure: state.failure,
          onRetry: context.read<CustomerOrderHistoryCubit>().retry,
        );
      }
      final customer = state.customer!;
      return ListView(
        key: const Key('customer-orders-scroll'),
        padding: CustomerManagementVisualTokens.pagePadding,
        children: <Widget>[
          CustomerDetailHeader(
            customer: customer,
            selectedTab: CustomerDetailTab.orders,
            onOverviewPressed: () => context.go(
              CustomerManagementRouteLocations.customer(customer.id),
            ),
            onOrdersPressed: () {},
            actions: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (customer.allowedActions.contains('update'))
                  SizedBox(
                    height:
                        CustomerManagementVisualTokens.minimumInteractiveSize,
                    child: FilledButton.icon(
                      onPressed: () => context.go(
                        CustomerManagementRouteLocations.editCustomer(
                          customer.id,
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        AppLocalizations.of(context).customerManagementEdit,
                      ),
                    ),
                  ),
                if (widget.repository != null)
                  CustomerLifecycleActions(
                    repository: widget.repository!,
                    customer: customer,
                    compact: true,
                  ),
              ],
            ),
          ),
          Text(
            AppLocalizations.of(context).cmvpOrderHistory,
            style: CustomerManagementVisualTokens.pageTitle.copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          _Filters(query: state.query, branches: state.branches),
          const SizedBox(height: 16),
          if (state.status == CustomerOrderHistoryStatus.failure &&
              state.page == null)
            CustomerManagementStatePanel(
              failure: state.failure,
              onRetry: context.read<CustomerOrderHistoryCubit>().retry,
            )
          else
            Column(
              children: <Widget>[
                if (state.status == CustomerOrderHistoryStatus.failure)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 16),
                    child: CustomerManagementStatePanel(
                      failure: state.failure,
                      onRetry: context.read<CustomerOrderHistoryCubit>().retry,
                    ),
                  ),
                _OrdersCollection(
                  page: state.page,
                  loading: state.status == CustomerOrderHistoryStatus.loading,
                  onPage: (page) => context
                      .read<CustomerOrderHistoryCubit>()
                      .apply(state.query.copyWith(page: page)),
                ),
              ],
            ),
        ],
      );
    },
  );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.query, required this.branches});
  final CustomerOrderQuery query;
  final List<CustomerOrderBranch> branches;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerOrderHistoryCubit>();
    final l = AppLocalizations.of(context);
    return CustomerManagementSurface(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int?>(
                key: const Key('customer-order-branch-filter'),
                initialValue: query.branchId,
                isExpanded: true,
                decoration: _filterDecoration(),
                hint: Text(l.cmvpAllBranches),
                items: <DropdownMenuItem<int?>>[
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l.cmvpAllBranches),
                  ),
                  ...branches.map(
                    (CustomerOrderBranch branch) => DropdownMenuItem<int?>(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                  ),
                ],
                onChanged: (int? branchId) => cubit.apply(
                  query.copyWith(
                    branchId: branchId,
                    clearBranch: branchId == null,
                    page: 1,
                  ),
                ),
              ),
            ),
            _DateRangeFilter(query: query),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<CustomerOrderStatusFilter?>(
                key: const Key('customer-order-status-filter'),
                initialValue: query.status,
                hint: Text(l.commonAll),
                isExpanded: true,
                decoration: _filterDecoration(),
                items: <DropdownMenuItem<CustomerOrderStatusFilter?>>[
                  DropdownMenuItem<CustomerOrderStatusFilter?>(
                    value: null,
                    child: Text(l.commonAll),
                  ),
                  ...CustomerOrderStatusFilter.values.map(
                    (v) => DropdownMenuItem<CustomerOrderStatusFilter?>(
                      value: v,
                      child: Text(_orderStatusLabel(l, v.name)),
                    ),
                  ),
                ],
                onChanged: (v) => cubit.apply(
                  query.copyWith(status: v, clearStatus: v == null, page: 1),
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<CustomerPaymentStatusFilter?>(
                key: const Key('customer-order-payment-filter'),
                initialValue: query.paymentStatus,
                hint: Text(l.commonAll),
                isExpanded: true,
                decoration: _filterDecoration(),
                items: <DropdownMenuItem<CustomerPaymentStatusFilter?>>[
                  DropdownMenuItem<CustomerPaymentStatusFilter?>(
                    value: null,
                    child: Text(l.commonAll),
                  ),
                  ...CustomerPaymentStatusFilter.values.map(
                    (v) => DropdownMenuItem<CustomerPaymentStatusFilter?>(
                      value: v,
                      child: Text(_paymentStatusLabel(l, v.value)),
                    ),
                  ),
                ],
                onChanged: (v) => cubit.apply(
                  query.copyWith(
                    paymentStatus: v,
                    clearPaymentStatus: v == null,
                    page: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _filterDecoration() => InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 12, 10, 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: CustomerManagementVisualTokens.surfaceBorder,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: CustomerManagementVisualTokens.surfaceBorder,
  ),
);

class _DateRangeFilter extends StatelessWidget {
  const _DateRangeFilter({required this.query});
  final CustomerOrderQuery query;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return SizedBox(
      width: 180,
      child: OutlinedButton.icon(
        key: const Key('customer-order-date-filter'),
        onPressed: () async {
          final DateTimeRange? range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            initialDateRange: query.from == null || query.to == null
                ? null
                : DateTimeRange(start: query.from!, end: query.to!),
            builder: (BuildContext context, Widget? child) => Theme(
              data: Theme.of(context).copyWith(
                dialogTheme: const DialogThemeData(
                  constraints: BoxConstraints(maxWidth: 560, maxHeight: 660),
                  insetPadding: EdgeInsets.all(24),
                ),
              ),
              child: child!,
            ),
          );
          if (range == null || !context.mounted) return;
          context.read<CustomerOrderHistoryCubit>().apply(
            query.copyWith(from: range.start, to: range.end, page: 1),
          );
        },
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(
          query.from == null || query.to == null
              ? '${l.commonAll} ${l.cmvpOrderDateTime}'
              : '${DateFormat('dd/MM/yyyy', 'en_US').format(query.from!)} – ${DateFormat('dd/MM/yyyy', 'en_US').format(query.to!)}',
        ),
      ),
    );
  }
}

class _OrdersCollection extends StatelessWidget {
  const _OrdersCollection({
    this.page,
    required this.loading,
    required this.onPage,
  });
  final CustomerPage<CustomerOrder>? page;
  final bool loading;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (loading && page == null) {
      return const CustomerManagementStatePanel(
        loadingGeometry: CustomerManagementLoadingGeometry.collection,
      );
    }
    if (page == null || page!.items.isEmpty) {
      return CustomerManagementStatePanel(
        empty: true,
        emptyMessage: l.cmvpNoOrders,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => CustomerManagementSurface(
        body:
            CustomerManagementVisualTokens.usesCollectionCards(
              MediaQuery.sizeOf(context).width,
            )
            ? _Cards(orders: page!.items)
            : Material(
                color: Colors.transparent,
                child: _Table(orders: page!.items),
              ),
        footer: _OrdersFooter(meta: page!.meta, onPageChanged: onPage),
      ),
    );
  }
}

class _OrdersFooter extends StatelessWidget {
  const _OrdersFooter({required this.meta, required this.onPageChanged});

  final CustomerPageMeta meta;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final int start = meta.total == 0
        ? 0
        : ((meta.currentPage - 1) * meta.perPage) + 1;
    final int end = (start + meta.perPage - 1).clamp(0, meta.total).toInt();
    final bool rtl = Directionality.of(context).name == 'rtl';
    return Semantics(
      container: true,
      label: l.cmvpOrdersShowing(start, end, meta.total),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(l.cmvpOrdersShowing(start, end, meta.total))),
          IconButton(
            onPressed: meta.currentPage > 1
                ? () => onPageChanged(meta.currentPage - 1)
                : null,
            tooltip: l.customerManagementPreviousPage,
            icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
          ),
          IconButton(
            onPressed: meta.currentPage < meta.lastPage
                ? () => onPageChanged(meta.currentPage + 1)
                : null,
            tooltip: l.customerManagementNextPage,
            icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.orders});
  final List<CustomerOrder> orders;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        key: const Key('customer-orders-table-width'),
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: const WidgetStatePropertyAll(
            CustomerManagementVisualTokens.warmHeader,
          ),
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 52,
          horizontalMargin: 20,
          columnSpacing: 28,
          columns: <DataColumn>[
            DataColumn(
              label: Text(AppLocalizations.of(context).cmvpOrderNumber),
            ),
            DataColumn(label: Text(AppLocalizations.of(context).cmvpBranch)),
            DataColumn(
              label: Text(AppLocalizations.of(context).cmvpOrderDateTime),
            ),
            DataColumn(
              label: Text(AppLocalizations.of(context).cmvpOrderStatus),
            ),
            DataColumn(
              label: Text(AppLocalizations.of(context).cmvpPaymentStatus),
            ),
            DataColumn(
              numeric: true,
              label: Text(AppLocalizations.of(context).cmvpOrderTotal),
            ),
          ],
          rows: orders
              .map(
                (o) => DataRow(
                  cells: <DataCell>[
                    DataCell(
                      CustomerBidiValue(value: o.orderNumber, isolate: true),
                    ),
                    DataCell(Text(o.branchName)),
                    DataCell(
                      CustomerBidiValue(
                        value: _dateTime(o.createdAt),
                        isolate: true,
                      ),
                    ),
                    DataCell(_OrderBadge.order(status: o.status)),
                    DataCell(_OrderBadge.payment(status: o.paymentStatus)),
                    DataCell(
                      CustomerBidiValue(
                        value: _money(context, o),
                        isolate: true,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
}

class _Cards extends StatelessWidget {
  const _Cards({required this.orders});
  final List<CustomerOrder> orders;
  @override
  Widget build(BuildContext context) => Column(
    children: orders
        .map(
          (o) => Semantics(
            container: true,
            label:
                '${_orderStatusLabel(AppLocalizations.of(context), o.status)}, ${_paymentStatusLabel(AppLocalizations.of(context), o.paymentStatus)}',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _CardField(
                      label: AppLocalizations.of(context).cmvpOrderNumber,
                      value: CustomerBidiValue(
                        value: o.orderNumber,
                        isolate: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CardField(
                      label: AppLocalizations.of(context).cmvpBranch,
                      value: Text(o.branchName),
                    ),
                    const SizedBox(height: 8),
                    _CardField(
                      label: AppLocalizations.of(context).cmvpOrderDateTime,
                      value: CustomerBidiValue(
                        value: _dateTime(o.createdAt),
                        isolate: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        _OrderBadge.order(status: o.status),
                        _OrderBadge.payment(status: o.paymentStatus),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _CardField(
                      label: AppLocalizations.of(context).cmvpOrderTotal,
                      value: CustomerBidiValue(
                        value: _money(context, o),
                        isolate: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _CardField extends StatelessWidget {
  const _CardField({required this.label, required this.value});
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: CustomerManagementVisualTokens.tableHeading),
      const SizedBox(height: 2),
      value,
    ],
  );
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge._({required this.kind, required this.color});

  factory _OrderBadge.order({required String status}) =>
      _OrderBadge._(kind: _orderKind(status), color: _orderColor(status));

  factory _OrderBadge.payment({required String status}) =>
      _OrderBadge._(kind: _paymentKind(status), color: _paymentColor(status));

  final _OrderBadgeKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String text = kind.localized(AppLocalizations.of(context));
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

enum _OrderBadgeKind {
  completed,
  held,
  cancelled,
  draft,
  paid,
  unpaid,
  partial,
  refunded,
}

_OrderBadgeKind _orderKind(String status) => switch (status) {
  'paid' => _OrderBadgeKind.completed,
  'held' => _OrderBadgeKind.held,
  'cancelled' => _OrderBadgeKind.cancelled,
  _ => _OrderBadgeKind.draft,
};

_OrderBadgeKind _paymentKind(String status) => switch (status) {
  'paid' => _OrderBadgeKind.paid,
  'partially_refunded' => _OrderBadgeKind.partial,
  'refunded' => _OrderBadgeKind.refunded,
  _ => _OrderBadgeKind.unpaid,
};

Color _orderColor(String status) => switch (_orderKind(status)) {
  _OrderBadgeKind.completed => const Color(0xFF2E7D32),
  _OrderBadgeKind.held => const Color(0xFF9A6518),
  _OrderBadgeKind.cancelled => const Color(0xFFC62828),
  _ => const Color(0xFF6E625C),
};

Color _paymentColor(String status) => switch (_paymentKind(status)) {
  _OrderBadgeKind.paid => const Color(0xFF2E7D32),
  _OrderBadgeKind.partial => const Color(0xFF8B5A2B),
  _OrderBadgeKind.refunded => const Color(0xFF7B4FA3),
  _ => const Color(0xFF6E625C),
};

extension _OrderBadgeLocalization on _OrderBadgeKind {
  String localized(AppLocalizations l) => switch (this) {
    _OrderBadgeKind.completed => l.cmvpOrderStatusCompleted,
    _OrderBadgeKind.held => l.cmvpOrderStatusHeld,
    _OrderBadgeKind.cancelled => l.cmvpOrderStatusCancelled,
    _OrderBadgeKind.draft => l.cmvpOrderStatusDraft,
    _OrderBadgeKind.paid => l.cmvpPaymentStatusPaid,
    _OrderBadgeKind.unpaid => l.cmvpPaymentStatusUnpaid,
    _OrderBadgeKind.partial => l.cmvpPaymentStatusPartiallyRefunded,
    _OrderBadgeKind.refunded => l.cmvpPaymentStatusRefunded,
  };
}

String _orderStatusLabel(AppLocalizations l, String value) =>
    _orderKind(value).localized(l);

String _paymentStatusLabel(AppLocalizations l, String value) =>
    _paymentKind(value).localized(l);

/// Order timestamps remain numeric, fixed-order values so Arabic RTL layout
/// cannot visually reorder their date and time segments.
String _dateTime(DateTime value) =>
    DateFormat('dd/MM/yyyy HH:mm', 'en_US').format(value);

String _money(BuildContext context, CustomerOrder order) =>
    NumberFormat.currency(
      locale: Localizations.localeOf(context).toString(),
      name: order.currency,
      decimalDigits: 2,
    ).format(num.tryParse(order.totalAmount) ?? 0);
