import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/search_debouncer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../customer_management/widgets/customer_create_dialog.dart';
import '../controllers/pos_customer_quick_create_cubit.dart';
import '../models/customer.dart';
import '../models/pos_customer_create_result.dart';
import '../models/pos_quick_create_customer_request.dart';
import '../repositories/pos_repository.dart';
import 'customer_list_tile.dart';
import 'customer_search_field.dart';
import 'pos_customer_quick_create_dialog.dart';

class SelectCustomerDialog extends StatefulWidget {
  const SelectCustomerDialog({
    super.key,
    required this.customers,
    required this.selectedCustomer,
    this.onSubmit,
    this.onSearch,
    this.quickCreateRepository,
    this.onQuickCreate,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;
  final Future<bool> Function(Customer customer)? onSubmit;
  final Future<List<Customer>> Function(String query)? onSearch;
  final PosRepository? quickCreateRepository;
  final Future<PosCustomerCreateResult> Function(
    PosQuickCreateCustomerRequest request,
  )?
  onQuickCreate;

  @override
  State<SelectCustomerDialog> createState() => _SelectCustomerDialogState();
}

enum _SearchFailure { forbidden, retryable }

class _SelectCustomerDialogState extends State<SelectCustomerDialog> {
  late final TextEditingController _searchController;
  final SearchDebouncer _debouncer = SearchDebouncer();
  final LatestRequestGuard _requestGuard = LatestRequestGuard();
  Customer? _temporaryCustomer;
  String _query = '';
  List<Customer> _results = const <Customer>[];
  bool _isSearching = false;
  bool _isSubmitting = false;
  _SearchFailure? _searchFailure;
  bool _selectionFailure = false;

  bool get _canCreate =>
      widget.quickCreateRepository != null && widget.onQuickCreate != null;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _temporaryCustomer = widget.selectedCustomer;
    _results = widget.customers;
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _requestGuard.next();
    setState(() {
      _query = value;
      _searchFailure = null;
      _selectionFailure = false;
      if (value.trim().isEmpty) {
        _results = widget.customers;
        _isSearching = false;
      }
    });
    if (widget.onSearch != null && value.trim().isNotEmpty) {
      _debouncer.run(() => _runSearch(value));
    }
  }

  Future<void> _runSearch(String value) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || widget.onSearch == null) return;
    final int token = _requestGuard.next();
    if (mounted) setState(() => _isSearching = true);
    try {
      final List<Customer> results = await widget.onSearch!(trimmed);
      if (!mounted || !_requestGuard.isCurrent(token)) return;
      setState(() {
        _results = results;
        _isSearching = false;
        _searchFailure = null;
      });
    } catch (error) {
      if (!mounted || !_requestGuard.isCurrent(token)) return;
      setState(() {
        _isSearching = false;
        _searchFailure = _searchFailureFor(error);
      });
    }
  }

  _SearchFailure _searchFailureFor(Object error) {
    if (error is ApiException &&
        (error.type == ApiErrorType.forbidden || error.statusCode == 403)) {
      return _SearchFailure.forbidden;
    }
    return _SearchFailure.retryable;
  }

  List<Customer> get _filteredCustomers {
    if (widget.onSearch != null) return _results;
    final String normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return widget.customers;
    return widget.customers
        .where(
          (Customer customer) =>
              customer.name.toLowerCase().contains(normalized) ||
              customer.phone.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewport) {
        final List<Customer> customers = _filteredCustomers;
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
                    _DialogHeader(),
                    Flexible(
                      child: Padding(
                        padding: AppSpacing.allLg,
                        child: Column(
                          children: <Widget>[
                            CustomerSearchField(
                              controller: _searchController,
                              onChanged: _onQueryChanged,
                            ),
                            if (_searchFailure != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              _SearchError(
                                failure: _searchFailure!,
                                onRetry: () => _runSearch(_query),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            Expanded(
                              child: _isSearching && customers.isEmpty
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _CustomerList(
                                      customers: customers,
                                      selectedCustomer: _temporaryCustomer,
                                      hasQuery: _query.trim().isNotEmpty,
                                      onCustomerSelected: (Customer customer) {
                                        setState(() {
                                          _temporaryCustomer = customer;
                                          _selectionFailure = false;
                                        });
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectionFailure)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.posCustomerAttachmentFailed,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    _DialogFooter(
                      canSelect:
                          _temporaryCustomer != null &&
                          customers.any(
                            (Customer item) =>
                                _sameCustomer(item, _temporaryCustomer),
                          ) &&
                          !_isSubmitting,
                      showCreate: _canCreate,
                      onCreateNew: _showCreateNew,
                      onCancel: _isSubmitting
                          ? () {}
                          : () => Navigator.of(context).pop(),
                      onSelect: _submit,
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

  Future<void> _showCreateNew() async {
    final PosRepository? repository = widget.quickCreateRepository;
    final Future<PosCustomerCreateResult> Function(
      PosQuickCreateCustomerRequest request,
    )?
    onCreate = widget.onQuickCreate;
    if (repository == null || onCreate == null) return;
    final PosCustomerCreateResult? result =
        await showDialog<PosCustomerCreateResult>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) => BlocProvider(
            create: (_) => PosCustomerQuickCreateCubit(
              repository: repository,
              onCreate: onCreate,
            ),
            child: const CustomerCreateDialog(
              mode: CustomerCreateMode.posQuickCreate,
              maxWidth: 480,
              maxHeight: 560,
              fitContent: true,
              child: PosCustomerQuickCreateDialog(compact: true),
            ),
          ),
        );
    if (!mounted || result == null) return;
    _upsertResult(result.customer);
    setState(() {
      _temporaryCustomer = result.customer;
      _selectionFailure = result.attachmentFailed;
    });
    if (!result.attachmentFailed) await _submit();
  }

  void _upsertResult(Customer customer) {
    final int index = _results.indexWhere(
      (Customer item) => _sameCustomer(item, customer),
    );
    final List<Customer> results = List<Customer>.from(_results);
    if (index >= 0) {
      results[index] = customer;
    } else {
      results.insert(0, customer);
    }
    _results = results;
  }

  Future<void> _submit() async {
    final Customer? customer = _temporaryCustomer;
    if (_isSubmitting || customer == null) return;
    if (widget.onSubmit == null) {
      Navigator.of(context).pop<Customer>(customer);
      return;
    }
    setState(() => _isSubmitting = true);
    bool succeeded = false;
    try {
      succeeded = await widget.onSubmit!(customer);
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _selectionFailure = !succeeded;
    });
    if (succeeded) Navigator.of(context).pop<Customer>(customer);
  }
}

class _DialogHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
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
              l10n.posSelectCustomer,
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
            tooltip: l10n.posCloseCustomerSelector,
          ),
        ],
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.failure, required this.onRetry});

  final _SearchFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final bool forbidden = failure == _SearchFailure.forbidden;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            forbidden
                ? l10n.posCustomerSearchForbidden
                : l10n.posCustomerSearchFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (!forbidden)
          TextButton(
            onPressed: onRetry,
            child: Text(l10n.customerManagementRetry),
          ),
      ],
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({
    required this.customers,
    required this.selectedCustomer,
    required this.hasQuery,
    required this.onCustomerSelected,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;
  final bool hasQuery;
  final ValueChanged<Customer> onCustomerSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    if (customers.isEmpty) {
      return Center(
        child: Text(
          hasQuery ? l10n.posNoCustomerMatches : l10n.posNoCustomers,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        final Customer customer = customers[index];
        return CustomerListTile(
          customer: customer,
          isSelected: _sameCustomer(selectedCustomer, customer),
          onTap: () => onCustomerSelected(customer),
        );
      },
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.canSelect,
    required this.showCreate,
    required this.onCreateNew,
    required this.onCancel,
    required this.onSelect,
  });

  final bool canSelect;
  final bool showCreate;
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
            if (showCreate) _CreateNewButton(onPressed: onCreateNew),
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
          final int trailingStart = showCreate ? 1 : 0;
          return Row(
            children: <Widget>[
              if (showCreate)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: actions.first,
                  ),
                )
              else
                const Spacer(),
              actions[trailingStart],
              const SizedBox(width: AppSpacing.md),
              actions[trailingStart + 1],
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
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: AppColors.secondary,
      textStyle: AppTextStyles.buttonMedium,
    ),
    child: Text(
      (Localizations.of<AppLocalizations>(context, AppLocalizations) ??
              AppLocalizationsEn())
          .posCreateNewCustomer,
    ),
  );
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
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
      child: Text(
        (Localizations.of<AppLocalizations>(context, AppLocalizations) ??
                AppLocalizationsEn())
            .customerManagementCancel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    ),
  );
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({required this.canSelect, required this.onPressed});

  final bool canSelect;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
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
      child: Text(
        (Localizations.of<AppLocalizations>(context, AppLocalizations) ??
                AppLocalizationsEn())
            .posSelectCustomer,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    ),
  );
}

bool _sameCustomer(Customer? first, Customer? second) {
  if (first == null || second == null) return first == second;
  if (first.backendId != null && second.backendId != null) {
    return first.backendId == second.backendId;
  }
  return first.id == second.id;
}
