import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/customer.dart';
import 'customer_list_tile.dart';
import 'customer_search_field.dart';

class SelectCustomerDialog extends StatefulWidget {
  const SelectCustomerDialog({
    super.key,
    required this.customers,
    required this.selectedCustomer,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;

  @override
  State<SelectCustomerDialog> createState() => _SelectCustomerDialogState();
}

class _SelectCustomerDialogState extends State<SelectCustomerDialog> {
  late final TextEditingController _searchController;
  Customer? _temporaryCustomer;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _temporaryCustomer = widget.selectedCustomer;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> get _filteredCustomers {
    final String normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return widget.customers;
    }

    return widget.customers
        .where((Customer customer) {
          return customer.name.toLowerCase().contains(normalized) ||
              customer.phone.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewport) {
        final List<Customer> filteredCustomers = _filteredCustomers;
        final bool canSelectTemporaryCustomer =
            _temporaryCustomer != null &&
            filteredCustomers.any(
              (Customer customer) => customer.id == _temporaryCustomer!.id,
            );
        final double maxWidth = math.min(
          math.max(viewport.maxWidth - AppSpacing.xxl, 280),
          AppSizes.selectCustomerDialogWidth,
        );
        final double maxHeight = math.min(
          math.max(viewport.maxHeight - AppSpacing.xxl, 360),
          AppSizes.selectCustomerDialogMaxHeight,
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Material(
              color: AppColors.white,
              clipBehavior: Clip.antiAlias,
              borderRadius: AppRadius.dialog,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.dialog,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Color(0x26000000),
                      offset: Offset(0, 16),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _DialogHeader(),
                    Flexible(
                      child: Padding(
                        padding: AppSpacing.allLg,
                        child: Column(
                          children: <Widget>[
                            CustomerSearchField(
                              controller: _searchController,
                              onChanged: (String value) {
                                setState(() => _query = value);
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Expanded(
                              child: _CustomerList(
                                customers: filteredCustomers,
                                selectedCustomer: _temporaryCustomer,
                                onCustomerSelected: (Customer customer) {
                                  setState(() => _temporaryCustomer = customer);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _DialogFooter(
                      canSelect: canSelectTemporaryCustomer,
                      onCreateNew: _showCreateNewPlaceholder,
                      onCancel: () => Navigator.of(context).pop(),
                      onSelect: () => Navigator.of(
                        context,
                      ).pop<Customer>(_temporaryCustomer),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateNewPlaceholder() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Customer creation will be added later.')),
      );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.selectCustomerDialogHeaderHeight,
      padding: AppSpacing.horizontalXl,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Select Customer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textPrimary,
            tooltip: 'Close customer selector',
          ),
        ],
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({
    required this.customers,
    required this.selectedCustomer,
    required this.onCustomerSelected,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onCustomerSelected;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Center(
        child: Text(
          'No customers found',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: AppSpacing.sm);
      },
      itemBuilder: (BuildContext context, int index) {
        final Customer customer = customers[index];
        return CustomerListTile(
          customer: customer,
          isSelected: selectedCustomer?.id == customer.id,
          onTap: () => onCustomerSelected(customer),
        );
      },
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.canSelect,
    required this.onCreateNew,
    required this.onCancel,
    required this.onSelect,
  });

  final bool canSelect;
  final VoidCallback onCreateNew;
  final VoidCallback onCancel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final List<Widget> actions = <Widget>[
            _CreateNewButton(onPressed: onCreateNew),
            _CancelButton(onPressed: onCancel),
            _SelectButton(canSelect: canSelect, onPressed: onSelect),
          ];

          if (constraints.maxWidth < AppSizes.customerFooterStackBreakpoint) {
            return Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: actions,
            );
          }

          return Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: actions[0],
                ),
              ),
              actions[1],
              const SizedBox(width: AppSpacing.md),
              actions[2],
            ],
          );
        },
      ),
    );
  }
}

class _CreateNewButton extends StatelessWidget {
  const _CreateNewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        textStyle: AppTextStyles.buttonMedium,
      ),
      child: const Text('Create New'),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.customerFooterCancelButtonWidth,
      height: AppSizes.customerFooterButtonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.shellBackground,
          foregroundColor: AppColors.primary,
          padding: AppSpacing.horizontalMd,
          side: const BorderSide(color: AppColors.border),
          textStyle: AppTextStyles.buttonMedium,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
        child: const Text(
          'Cancel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({required this.canSelect, required this.onPressed});

  final bool canSelect;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.customerFooterSelectButtonWidth,
      height: AppSizes.customerFooterButtonHeight,
      child: FilledButton(
        key: const ValueKey<String>('confirm-customer-selection'),
        onPressed: canSelect ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.tertiary,
          disabledBackgroundColor: AppColors.paymentDisabledBackground,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.textMuted,
          padding: AppSpacing.horizontalMd,
          textStyle: AppTextStyles.buttonMedium,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
        child: const Text(
          'Select Customer',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}
