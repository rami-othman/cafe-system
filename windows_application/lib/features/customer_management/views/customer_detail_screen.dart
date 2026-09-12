import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/customer_detail_cubit.dart';
import '../controllers/customer_detail_state.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import '../widgets/customer_bidi_value.dart';
import '../widgets/customer_detail_sections.dart';
import '../widgets/customer_lifecycle_badge.dart';
import '../widgets/customer_lifecycle_actions.dart';
import '../widgets/customer_management_page_header.dart';
import '../widgets/customer_management_state_panel.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    this.lifecycleRepository,
  });
  final int customerId;
  final CustomerManagementRepository? lifecycleRepository;
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CustomerDetailCubit>().load(widget.customerId),
    );
  }

  @override
  void didUpdateWidget(covariant CustomerDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      context.read<CustomerDetailCubit>().load(widget.customerId);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CustomerDetailCubit, CustomerDetailState>(
        builder: (BuildContext context, CustomerDetailState state) {
          if ((state.status == CustomerDetailStatus.initial ||
                  state.status == CustomerDetailStatus.loading) &&
              state.customer == null) {
            return const CustomerManagementStatePanel(
              loadingGeometry: CustomerManagementLoadingGeometry.detail,
            );
          }
          if (state.status == CustomerDetailStatus.failure &&
              state.customer == null) {
            return CustomerManagementStatePanel(
              failure: state.failure,
              onRetry: context.read<CustomerDetailCubit>().refresh,
            );
          }
          final Customer? customer = state.customer;
          if (customer == null) {
            return CustomerManagementStatePanel(
              failure: state.failure,
              onRetry: context.read<CustomerDetailCubit>().refresh,
            );
          }
          final Widget profile = RefreshIndicator(
            onRefresh: context.read<CustomerDetailCubit>().refresh,
            child: _CustomerProfile(
              customer: customer,
              lifecycleRepository: widget.lifecycleRepository,
              onCustomerReplaced: context.read<CustomerDetailCubit>().replace,
            ),
          );
          return Stack(
            children: <Widget>[
              profile,
              if (state.status == CustomerDetailStatus.loading)
                Semantics(
                  label: AppLocalizations.of(context).cmvpLoadingRecord,
                  liveRegion: true,
                  child: const LinearProgressIndicator(),
                ),
            ],
          );
        },
      );
}

class _CustomerProfile extends StatelessWidget {
  const _CustomerProfile({
    required this.customer,
    this.lifecycleRepository,
    this.onCustomerReplaced,
  });
  final Customer customer;
  final CustomerManagementRepository? lifecycleRepository;
  final ValueChanged<Customer>? onCustomerReplaced;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        CustomerManagementPageHeader(
          title: customer.name,
          description: l10n.cmvpCustomerDetailDescription,
          breadcrumbs: <String>[
            l10n.cmvpBreadcrumbCustomers,
            l10n.cmvpBreadcrumbDetails,
            customer.name,
          ],
          identity: CustomerBidiValue(value: customer.customerNumber),
          status: CustomerLifecycleBadge(lifecycle: customer.lifecycle),
          actions: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (lifecycleRepository != null)
                CustomerLifecycleActions(
                  repository: lifecycleRepository!,
                  customer: customer,
                  onCustomerReplaced: onCustomerReplaced == null
                      ? null
                      : (Customer value) async => onCustomerReplaced!(value),
                ),
              if (customer.allowedActions.contains('update'))
                IconButton(
                  tooltip: l10n.customerManagementEdit,
                  onPressed: () => context.go(
                    CustomerManagementRouteLocations.editCustomer(customer.id),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
        ),
        const Divider(height: 32),
        CustomerDetailSections(customer: customer),
      ],
    );
  }
}
