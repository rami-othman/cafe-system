import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_models.dart';
import '../repositories/customer_management_repository.dart';
import 'customer_bidi_value.dart';
import 'customer_lifecycle_badge.dart';
import 'customer_lifecycle_actions.dart';
import 'customer_management_surface.dart';

class CustomerCollection extends StatelessWidget {
  const CustomerCollection({
    super.key,
    required this.customers,
    required this.onSelected,
    this.onEdit,
    this.lifecycleRepository,
    this.onLifecycleRefresh,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onSelected;
  final ValueChanged<Customer>? onEdit;
  final CustomerManagementRepository? lifecycleRepository;
  final Future<void> Function()? onLifecycleRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Widget content;
      if (constraints.maxWidth < 760) {
        content = ListView.separated(
          itemCount: customers.length,
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, int index) => _CustomerCard(
            customer: customers[index],
            onSelected: onSelected,
            onEdit: onEdit,
            lifecycleRepository: lifecycleRepository,
            onLifecycleRefresh: onLifecycleRefresh,
          ),
        );
      } else {
        content = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: <DataColumn>[
                DataColumn(
                  label: Text(
                    AppLocalizations.of(
                      context,
                    ).customerManagementCustomerNumber,
                  ),
                ),
                DataColumn(
                  label: Text(
                    AppLocalizations.of(context).customerManagementName,
                  ),
                ),
                DataColumn(
                  label: Text(
                    AppLocalizations.of(context).customerManagementPhone,
                  ),
                ),
                DataColumn(
                  label: Text(
                    AppLocalizations.of(context).customerManagementGroupsLabel,
                  ),
                ),
                DataColumn(
                  label: Text(
                    AppLocalizations.of(context).customerManagementStatus,
                  ),
                ),
                DataColumn(
                  label: Text(
                    AppLocalizations.of(context).customerManagementView,
                  ),
                ),
              ],
              rows: customers
                  .map(
                    (Customer customer) => DataRow(
                      onSelectChanged: (_) => onSelected(customer),
                      cells: <DataCell>[
                        DataCell(
                          CustomerBidiValue(value: customer.customerNumber),
                        ),
                        DataCell(
                          Text(customer.name, overflow: TextOverflow.ellipsis),
                        ),
                        DataCell(
                          CustomerBidiValue(
                            value: _primaryPhone(context, customer),
                          ),
                        ),
                        DataCell(
                          Text(
                            _groups(context, customer),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          CustomerLifecycleBadge(lifecycle: customer.lifecycle),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              if (customer.allowedActions.contains('update') &&
                                  onEdit != null)
                                IconButton(
                                  tooltip: AppLocalizations.of(
                                    context,
                                  ).customerManagementEdit,
                                  onPressed: () => onEdit!(customer),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              if (lifecycleRepository != null)
                                CustomerLifecycleActions(
                                  repository: lifecycleRepository!,
                                  customer: customer,
                                  showBadge: false,
                                  onCollectionsRefresh: onLifecycleRefresh,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      }
      return CustomerManagementSurface(
        expandBody: constraints.hasBoundedHeight,
        body: content,
      );
    },
  );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onSelected,
    this.onEdit,
    this.lifecycleRepository,
    this.onLifecycleRefresh,
  });
  final Customer customer;
  final ValueChanged<Customer> onSelected;
  final ValueChanged<Customer>? onEdit;
  final CustomerManagementRepository? lifecycleRepository;
  final Future<void> Function()? onLifecycleRefresh;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${customer.customerNumber} ${customer.name}',
    child: Card(
      child: ListTile(
        onTap: () => onSelected(customer),
        title: Text(customer.name, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CustomerBidiValue(value: customer.customerNumber),
            CustomerBidiValue(value: _primaryPhone(context, customer)),
            Text(
              _groups(context, customer),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: lifecycleRepository == null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CustomerLifecycleBadge(lifecycle: customer.lifecycle),
                  if (customer.allowedActions.contains('update') &&
                      onEdit != null)
                    IconButton(
                      tooltip: AppLocalizations.of(
                        context,
                      ).customerManagementEdit,
                      onPressed: () => onEdit!(customer),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              )
            : SizedBox(
                width: 230,
                child: CustomerLifecycleActions(
                  repository: lifecycleRepository!,
                  customer: customer,
                  onCollectionsRefresh: onLifecycleRefresh,
                ),
              ),
      ),
    ),
  );
}

String _primaryPhone(BuildContext context, Customer customer) {
  final Iterable<CustomerPhone> primary = customer.phones.where(
    (CustomerPhone phone) => phone.isPrimary,
  );
  return primary.isEmpty
      ? AppLocalizations.of(context).customerManagementNoPhone
      : primary.first.rawNumber;
}

String _groups(BuildContext context, Customer customer) =>
    customer.groups.isEmpty
    ? AppLocalizations.of(context).customerManagementNotAvailable
    : customer.groups
          .map((CustomerGroupSummary group) => group.name)
          .join(AppLocalizations.of(context).customerManagementValueSeparator);
