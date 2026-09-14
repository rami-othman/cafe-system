import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_list_cubit.dart';
import '../controllers/customer_list_state.dart';
import '../models/customer_models.dart';
import '../models/customer_queries.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_collection.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_state_panel.dart';
import '../widgets/customer_management_surface.dart';
import '../widgets/customer_management_visual_tokens.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key, this.lifecycleRepository});

  final CustomerManagementRepository? lifecycleRepository;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerListCubit>().load();
      context.read<CustomerListCubit>().loadGroupOptions();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<CustomerListCubit, CustomerListState>(
      builder: (BuildContext context, CustomerListState state) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CustomerManagementPageHeader(
              title: l10n.customerManagementCustomers,
              description: l10n.cmvpCustomersDescription,
              breadcrumbs: <String>[l10n.cmvpBreadcrumbCustomers],
              primaryAction: FilledButton.icon(
                key: const Key('customer-create'),
                onPressed: () =>
                    context.go(CustomerManagementRouteLocations.customerCreate),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.customerManagementCreateCustomer),
              ),
            ),
            const SizedBox(height: 20),
            CustomerManagementSurface(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Widget search = _searchField(context, l10n);
                    final Widget status = _StatusFilter(
                      selected: state.query.status ?? CustomerStatusFilter.all,
                      onChanged: (CustomerStatusFilter value) =>
                          context.read<CustomerListCubit>().setStatus(
                            value == CustomerStatusFilter.all ? null : value,
                          ),
                      hiddenDropdown: _hiddenStatusDropdown(
                        context,
                        state,
                        l10n,
                      ),
                    );
                    final Widget group = _groupFilter(context, state, l10n);
                    if (constraints.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          search,
                          const SizedBox(height: 10),
                          status,
                          const SizedBox(height: 10),
                          group,
                        ],
                      );
                    }
                    return Row(
                      textDirection: Directionality.of(context),
                      children: <Widget>[
                        Expanded(flex: 5, child: search),
                        const SizedBox(width: 12),
                        SizedBox(width: 252, child: status),
                        const SizedBox(width: 12),
                        SizedBox(width: 184, child: group),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.page != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.cmvpCustomersCount(state.page!.meta.total),
                  key: const Key('customer-management-result-count'),
                  style: CustomerManagementVisualTokens.tableCell.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (state.page != null) const SizedBox(height: 12),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context, AppLocalizations l10n) => TextField(
    controller: _search,
    decoration: InputDecoration(
      hintText: l10n.customerManagementSearch,
      prefixIcon: const Icon(Icons.search, size: 18),
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              tooltip: l10n.customerManagementClearFilters,
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                _search.clear();
                context.read<CustomerListCubit>().searchChanged('');
                setState(() {});
              },
            ),
      isDense: true,
      filled: true,
      fillColor: CustomerManagementVisualTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: CustomerManagementVisualTokens.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: CustomerManagementVisualTokens.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: CustomerManagementVisualTokens.focus,
        ),
      ),
    ),
    onChanged: (String value) {
      setState(() {});
      context.read<CustomerListCubit>().searchChanged(value);
    },
    onSubmitted: context.read<CustomerListCubit>().submitSearch,
  );

  Widget _hiddenStatusDropdown(
    BuildContext context,
    CustomerListState state,
    AppLocalizations l10n,
  ) => SizedBox(
    height: 42,
    child: IgnorePointer(
      child: Opacity(
        opacity: 0,
        child: DropdownButtonFormField<CustomerStatusFilter?>(
          initialValue: state.query.status,
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
          ),
          items: <DropdownMenuItem<CustomerStatusFilter?>>[
            DropdownMenuItem(
              value: null,
              child: Text(l10n.customerManagementAll),
            ),
            ...CustomerStatusFilter.values
                .where(
                  (CustomerStatusFilter value) =>
                      value != CustomerStatusFilter.all,
                )
                .map(
                  (CustomerStatusFilter value) => DropdownMenuItem(
                    value: value,
                    child: Text(_status(l10n, value)),
                  ),
                ),
          ],
          onChanged: (CustomerStatusFilter? value) =>
              context.read<CustomerListCubit>().setStatus(value),
        ),
      ),
    ),
  );

  Widget _groupFilter(
    BuildContext context,
    CustomerListState state,
    AppLocalizations l10n,
  ) => DropdownButtonFormField<int?>(
    initialValue: state.query.groupId,
    isExpanded: true,
    decoration: InputDecoration(
      hintText: l10n.customerManagementGroupsLabel,
      isDense: true,
      filled: true,
      fillColor: CustomerManagementVisualTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: CustomerManagementVisualTokens.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: CustomerManagementVisualTokens.border,
        ),
      ),
    ),
    items: <DropdownMenuItem<int?>>[
      DropdownMenuItem(value: null, child: Text(l10n.customerManagementAll)),
      ...state.groupOptions.map(
        (group) => DropdownMenuItem<int?>(
          value: group.id,
          child: Text(group.name, overflow: TextOverflow.ellipsis),
        ),
      ),
    ],
    onChanged: context.read<CustomerListCubit>().setGroup,
  );

  Widget _body(BuildContext context, CustomerListState state) {
    if (state.status == CustomerListStatus.initial ||
        (state.status == CustomerListStatus.loading && state.page == null)) {
      return const CustomerManagementStatePanel(
        loadingGeometry: CustomerManagementLoadingGeometry.collection,
        collectionSurface: true,
      );
    }
    if (state.status == CustomerListStatus.failure) {
      return CustomerManagementStatePanel(
        failure: state.failure,
        onRetry: context.read<CustomerListCubit>().refresh,
        collectionSurface: true,
      );
    }
    final List<Customer> items = state.page?.items ?? const <Customer>[];
    if (items.isEmpty) {
      return CustomerManagementStatePanel(
        empty: !state.hasCriteria,
        noResults: state.hasCriteria,
        onClear: state.hasCriteria
            ? () {
                _search.clear();
                context.read<CustomerListCubit>().clearFilters();
                setState(() {});
              }
            : null,
        onCreate: !state.hasCriteria
            ? () => context.go(CustomerManagementRouteLocations.customerCreate)
            : null,
        onCreateLabel: AppLocalizations.of(
          context,
        ).customerManagementCreateCustomer,
        collectionSurface: true,
      );
    }
    final Widget content = CustomerCollection(
      customers: items,
      onSelected: (customer) =>
          context.go(CustomerManagementRouteLocations.customer(customer.id)),
      onEdit: (customer) => context.go(
        CustomerManagementRouteLocations.editCustomer(customer.id),
      ),
      onOrders: (customer) => context.go(
        CustomerManagementRouteLocations.customerOrdersPath(customer.id),
      ),
      lifecycleRepository: widget.lifecycleRepository,
      onLifecycleRefresh: context.read<CustomerListCubit>().refresh,
      paginationMeta: state.page!.meta,
      onPageChanged: context.read<CustomerListCubit>().setPage,
    );
    return state.status == CustomerListStatus.loading
        ? Stack(
            children: <Widget>[
              content,
              Semantics(
                label: AppLocalizations.of(context).cmvpLoadingCustomers,
                liveRegion: true,
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  color: CustomerManagementVisualTokens.accent,
                  backgroundColor: CustomerManagementVisualTokens.skeleton,
                ),
              ),
            ],
          )
        : content;
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.selected,
    required this.onChanged,
    required this.hiddenDropdown,
  });

  final CustomerStatusFilter selected;
  final ValueChanged<CustomerStatusFilter> onChanged;
  final Widget hiddenDropdown;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextStyle? textStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontSize: 12, fontWeight: FontWeight.w700);
    final List<CustomerStatusFilter> values = <CustomerStatusFilter>[
      CustomerStatusFilter.all,
      CustomerStatusFilter.active,
      CustomerStatusFilter.inactive,
      CustomerStatusFilter.archived,
    ];
    return Stack(
      children: <Widget>[
        Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: CustomerManagementVisualTokens.surface,
            border: Border.fromBorderSide(
              CustomerManagementVisualTokens.surfaceBorder,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            textDirection: Directionality.of(context),
            children: <Widget>[
              for (final CustomerStatusFilter value in values)
                Expanded(
                  child: TextButton(
                    onPressed: () => onChanged(value),
                    style: TextButton.styleFrom(
                      foregroundColor: value == selected
                          ? Colors.white
                          : CustomerManagementVisualTokens.rowText,
                      backgroundColor: value == selected
                          ? CustomerManagementVisualTokens.accent
                          : Colors.transparent,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: textStyle,
                    ),
                    child: Text('${_status(l10n, value)}\u200B'),
                  ),
                ),
            ],
          ),
        ),
        hiddenDropdown,
      ],
    );
  }
}

String _status(AppLocalizations l10n, CustomerStatusFilter status) =>
    switch (status) {
      CustomerStatusFilter.active => l10n.customerManagementActive,
      CustomerStatusFilter.inactive => l10n.customerManagementInactive,
      CustomerStatusFilter.archived => l10n.customerManagementArchived,
      CustomerStatusFilter.all => l10n.customerManagementAll,
    };
