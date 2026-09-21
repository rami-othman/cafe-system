import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/config/tax_config.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../menu_management/operational_availability/operational_availability_formatters.dart'
    show operationalSalesChannels;
import '../controllers/discounts_cubit.dart';
import '../controllers/discounts_state.dart';
import '../models/discount_detail.dart';
import '../models/discount_form_references.dart';
import '../models/discount_list_item.dart';
import '../models/discount_upsert_request.dart';
import '../widgets/discount_bottom_action_bar.dart';
import '../widgets/discount_chip_selector.dart';
import '../widgets/discount_form_section_card.dart';
import '../widgets/discount_localization.dart';
import '../widgets/discount_pos_preview_card.dart';
import '../widgets/discount_summary_panel.dart';

/// One V1 form for create and edit. An edit row carries only an ID; the
/// complete policy is always hydrated from the authoritative detail endpoint.
class CreateDiscountPolicyScreen extends StatefulWidget {
  const CreateDiscountPolicyScreen({super.key, this.initialDiscount});

  final DiscountListItem? initialDiscount;

  @override
  State<CreateDiscountPolicyScreen> createState() =>
      _CreateDiscountPolicyScreenState();
}

class _CreateDiscountPolicyScreenState
    extends State<CreateDiscountPolicyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _minSpendController = TextEditingController();
  final TextEditingController _maxDiscountController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _usageLimitController = TextEditingController();
  final TextEditingController _perCustomerLimitController =
      TextEditingController();
  final TextEditingController _perCustomerDailyLimitController =
      TextEditingController();

  bool _active = false;
  String _applicationMode = 'manual';
  String _scope = 'order';
  String _valueType = 'percentage';
  String _customerEligibilityMode = 'all';
  bool _appliesToAllBranches = true;
  bool _allPaymentMethods = true;
  bool _allChannels = true;
  final Set<int> _productIds = <int>{};
  final Set<int> _categoryIds = <int>{};
  final Set<int> _customerGroupIds = <int>{};
  final Set<int> _customerIds = <int>{};
  final Set<int> _branchIds = <int>{};
  final Set<int> _paymentMethodIds = <int>{};
  final Set<String> _channelKeys = <String>{};
  final List<_BundleRequirementDraft> _bundleRequirements =
      <_BundleRequirementDraft>[];
  final Set<String> _activeDays = <String>{};
  bool _isLoadingDetail = false;
  String? _detailError;
  String? _conditions;
  bool _showValidationErrors = false;
  bool _isGeneratingCode = false;
  String? _couponGenerationError;

  bool get _isEdit => widget.initialDiscount != null;
  bool get _isPercentage => _valueType == 'percentage';

  @override
  void initState() {
    super.initState();
    for (final TextEditingController controller in _formControllers) {
      controller.addListener(_onFormChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final DiscountsCubit cubit = context.read<DiscountsCubit>();
      cubit.loadBranches();
      cubit.loadFormReferences();
      if (_isEdit) _loadDetail();
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _formControllers) {
      controller.removeListener(_onFormChanged);
      controller.dispose();
    }
    _clearBundleRequirements();
    super.dispose();
  }

  List<TextEditingController> get _formControllers => <TextEditingController>[
    _nameController,
    _codeController,
    _descriptionController,
    _valueController,
    _minSpendController,
    _maxDiscountController,
    _startDateController,
    _endDateController,
    _startTimeController,
    _endTimeController,
    _usageLimitController,
    _perCustomerLimitController,
    _perCustomerDailyLimitController,
  ];

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _detailError = null;
    });
    try {
      final DiscountDetail detail = await context
          .read<DiscountsCubit>()
          .getDiscountDetail(widget.initialDiscount!.id);
      if (!mounted) return;
      _hydrate(detail);
      setState(() => _isLoadingDetail = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingDetail = false;
        _detailError = AppLocalizations.of(context).discountFormLoadTitle;
      });
    }
  }

  void _hydrate(DiscountDetail detail) {
    _nameController.text = detail.name;
    _codeController.text = detail.code ?? '';
    _descriptionController.text = detail.description ?? '';
    _conditions = detail.conditions;
    _valueController.text = _decimal(detail.value);
    _minSpendController.text = _nullableDecimal(detail.minimumOrderAmount);
    _maxDiscountController.text = _nullableDecimal(
      detail.maximumDiscountAmount,
    );
    _startDateController.text = detail.startDate ?? '';
    _endDateController.text = detail.endDate ?? '';
    _startTimeController.text = _displayTime(detail.startTime);
    _endTimeController.text = _displayTime(detail.endTime);
    _usageLimitController.text = detail.usageLimit?.toString() ?? '';
    _perCustomerLimitController.text =
        detail.usageLimitPerCustomer?.toString() ?? '';
    _perCustomerDailyLimitController.text =
        detail.perCustomerDailyUsageLimit?.toString() ?? '';
    setState(() {
      _active = detail.isActive;
      _applicationMode = detail.applicationMode == 'code' ? 'code' : 'manual';
      _scope = switch (detail.scope) {
        'product' => 'product',
        'category' => 'category',
        'bundle' => 'bundle',
        _ => 'order',
      };
      _valueType = detail.type == 'fixed' ? 'fixed' : 'percentage';
      _customerEligibilityMode = switch (detail.customerEligibilityMode) {
        'selected_groups' => 'selected_groups',
        'selected_customers' => 'selected_customers',
        _ => 'all',
      };
      _appliesToAllBranches = detail.appliesToAllBranches;
      _allPaymentMethods = detail.paymentMethodIds.isEmpty;
      _replace(_productIds, detail.targetProductIds);
      _replace(_categoryIds, detail.targetCategoryIds);
      _replace(_customerGroupIds, detail.customerGroupIds);
      _replace(_customerIds, detail.customerIds);
      _replace(_branchIds, detail.branchIds);
      _replace(_paymentMethodIds, detail.paymentMethodIds);
      _channelKeys
        ..clear()
        ..addAll(detail.channelKeys);
      _allChannels = detail.channelKeys.isEmpty;
      for (final _BundleRequirementDraft requirement in _bundleRequirements) {
        requirement.dispose();
      }
      _bundleRequirements
        ..clear()
        ..addAll(
          detail.bundleRequirements.map(
            (requirement) =>
                _BundleRequirementDraft.fromRequirement(requirement),
          ),
        );
      _activeDays
        ..clear()
        ..addAll(detail.activeDays);
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DiscountsCubit, DiscountsState>(
        builder: (BuildContext context, DiscountsState state) {
          final bool locked = _isLoadingDetail || state.isSaving;
          final bool isReady = _validationIssues().isEmpty;
          return Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSizes.menuContentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _PageHeading(isEdit: _isEdit),
                          const SizedBox(height: AppSpacing.xl),
                          if (_isLoadingDetail)
                            const Padding(
                              padding: EdgeInsets.all(AppSpacing.xxl),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_detailError != null)
                            _LoadError(
                              message: _detailError!,
                              onRetry: _loadDetail,
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final Widget form = _buildForm(state, locked);
                                final Widget sideRail = _buildSideRail(
                                  state,
                                  isReady,
                                );
                                if (constraints.maxWidth <
                                    AppSizes.createProductTwoColumnBreakpoint) {
                                  return Column(
                                    children: <Widget>[
                                      form,
                                      const SizedBox(height: AppSpacing.lg),
                                      sideRail,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(child: form),
                                    const SizedBox(width: AppSpacing.lg),
                                    SizedBox(
                                      width: AppSizes.createProductSummaryWidth,
                                      child: sideRail,
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              DiscountBottomActionBar(
                onDiscard: locked ? null : _discardChanges,
                onSaveDraft: locked ? null : () => _submit(false),
                onActivate: locked || !isReady ? null : () => _submit(true),
              ),
            ],
          );
        },
      );

  Widget _buildForm(DiscountsState state, bool locked) => Column(
    children: <Widget>[
      if (state.validationErrors.isNotEmpty ||
          _showValidationErrors) ...<Widget>[
        _ValidationBanner(
          messages: <String>[
            ..._localizedServerValidationErrors(state.validationErrors),
            if (_showValidationErrors)
              ..._validationIssues().map(
                (_FormValidationIssue issue) => issue.message,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      _basicCard(locked),
      const SizedBox(height: AppSpacing.lg),
      _scopeCard(state, locked),
      const SizedBox(height: AppSpacing.lg),
      _eligibilityCard(state, locked),
      const SizedBox(height: AppSpacing.lg),
      _scheduleCard(locked),
      const SizedBox(height: AppSpacing.lg),
      _usageCard(locked),
    ],
  );

  Widget _basicCard(bool locked) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DiscountFormSectionCard(
      title: l10n.discountFormBasic,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.commonActive, style: AppTextStyles.bodySmall),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: _active,
            onChanged: locked
                ? null
                : (value) => setState(() => _active = value),
          ),
        ],
      ),
      child: _AdaptiveFields(
        children: <_LabeledField>[
          _LabeledField(
            label: l10n.discountFormName,
            child: AppTextField(
              key: const Key('discount-name-field'),
              controller: _nameController,
              enabled: !locked,
            ),
          ),
          _LabeledField(
            label: l10n.discountFormApplicationMode,
            child: _SelectField(
              key: const Key('discount-application-mode-field'),
              value: _applicationMode,
              options: <_SelectOption>[
                _SelectOption('manual', l10n.discountManual),
                _SelectOption('code', l10n.discountFormCouponOrCode),
              ],
              enabled: !locked,
              onChanged: _changeApplicationMode,
            ),
          ),
          if (_applicationMode == 'code')
            _LabeledField(
              label: l10n.discountCode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppTextField(
                    key: const Key('discount-code-field'),
                    controller: _codeController,
                    enabled: !locked && !_isGeneratingCode,
                    readOnly: true,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      if (_isGeneratingCode)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton(
                          key: const Key('discount-regenerate-code'),
                          onPressed: locked ? null : _generateCouponCode,
                          child: Text(l10n.discountV2Regenerate),
                        ),
                      if (_couponGenerationError != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.discountV2CodeGenerationFailed,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: locked ? null : _generateCouponCode,
                          child: Text(l10n.discountV2Retry),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          _LabeledField(
            label: l10n.discountFormDescription,
            span: 2,
            child: AppTextField(
              controller: _descriptionController,
              enabled: !locked,
              hintText: l10n.discountFormDescriptionHint,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeCard(DiscountsState state, bool locked) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DiscountFormSectionCard(
      title: l10n.discountFormScopeValue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _AdaptiveFields(
            children: <_LabeledField>[
              _LabeledField(
                label: l10n.discountFormAppliesTo,
                child: _SelectField(
                  key: const Key('discount-scope-field'),
                  value: _scope,
                  options: <_SelectOption>[
                    _SelectOption('order', l10n.discountEntireOrder),
                    _SelectOption('product', l10n.discountSelectedProducts),
                    _SelectOption('category', l10n.discountSelectedCategories),
                    _SelectOption('bundle', l10n.discountV2PackageBundle),
                  ],
                  enabled: !locked,
                  onChanged: (value) => setState(() {
                    _scope = value;
                    if (value != 'product') _productIds.clear();
                    if (value != 'category') _categoryIds.clear();
                    if (value != 'bundle') _clearBundleRequirements();
                  }),
                ),
              ),
              _LabeledField(
                label: l10n.discountFormValueType,
                child: _SelectField(
                  key: const Key('discount-value-type-field'),
                  value: _valueType,
                  options: <_SelectOption>[
                    _SelectOption('percentage', l10n.discountPercentage),
                    _SelectOption('fixed', l10n.discountFixedAmount),
                  ],
                  enabled: !locked,
                  onChanged: (value) => setState(() => _valueType = value),
                ),
              ),
              _LabeledField(
                label: l10n.discountFormValue,
                child: AppTextField(
                  key: const Key('discount-value-field'),
                  controller: _valueController,
                  enabled: !locked,
                  prefixText: _isPercentage ? null : '${_currency(state)} ',
                  hintText: _isPercentage ? '0 %' : '0 ${_currency(state)}',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: _fieldError('value'),
                ),
              ),
              _LabeledField(
                label: l10n.discountFormMinSpendOptional,
                child: _moneyField(
                  _minSpendController,
                  locked,
                  const Key('discount-min-spend-field'),
                  _currency(state),
                ),
              ),
              _LabeledField(
                label: l10n.discountFormMaxDiscountOptional,
                child: _moneyField(
                  _maxDiscountController,
                  locked,
                  const Key('discount-max-discount-field'),
                  _currency(state),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _FieldLabel(
            label: _isPercentage
                ? l10n.discountFormQuickPercentages
                : l10n.discountFormQuickFixed,
          ),
          const SizedBox(height: AppSpacing.sm),
          DiscountChipSelector(
            options: _isPercentage
                ? const <String>['5%', '10%', '15%', '20%']
                : const <String>['5000', '12500', '25000'],
            selected: const <String>{},
            multiSelect: false,
            onSelected: locked
                ? (_) {}
                : (value) => setState(
                    () => _valueController.text = value.replaceAll('%', ''),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_scope == 'product')
            _referenceSelector(
              key: const Key('discount-products-selector'),
              label: l10n.discountSelectedProducts,
              items: state.formReferences.products,
              selectedIds: _productIds,
              loading: state.isLoadingFormReferences,
              enabled: !locked,
              onChanged: (ids) => setState(() => _replace(_productIds, ids)),
            ),
          if (_scope == 'category')
            _referenceSelector(
              key: const Key('discount-categories-selector'),
              label: l10n.discountSelectedCategories,
              items: state.formReferences.categories,
              selectedIds: _categoryIds,
              loading: state.isLoadingFormReferences,
              enabled: !locked,
              onChanged: (ids) => setState(() => _replace(_categoryIds, ids)),
            ),
          if (_scope == 'bundle') ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _bundleRequirementsBuilder(state, locked),
          ],
          if (state.formReferencesErrorMessage != null)
            _ReferencesRetry(
              onRetry: () =>
                  context.read<DiscountsCubit>().loadFormReferences(),
            ),
        ],
      ),
    );
  }

  Widget _eligibilityCard(DiscountsState state, bool locked) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DiscountFormSectionCard(
      title: l10n.discountFormEligibility,
      child: _AdaptiveFields(
        children: <_LabeledField>[
          _LabeledField(
            label: l10n.discountCustomerEligibility,
            child: _SelectField(
              key: const Key('discount-customer-eligibility-field'),
              value: _customerEligibilityMode,
              options: <_SelectOption>[
                _SelectOption('all', l10n.discountFormAllCustomers),
                _SelectOption(
                  'selected_groups',
                  l10n.discountFormSelectedCustomerGroups,
                ),
                _SelectOption(
                  'selected_customers',
                  l10n.discountV2SelectedCustomers,
                ),
              ],
              enabled: !locked,
              onChanged: (value) => setState(() {
                _customerEligibilityMode = value;
                if (value == 'all') {
                  _customerGroupIds.clear();
                  _customerIds.clear();
                } else if (value == 'selected_groups') {
                  _customerIds.clear();
                } else if (value == 'selected_customers') {
                  _customerGroupIds.clear();
                }
              }),
            ),
          ),
          _LabeledField(
            label: l10n.discountPaymentMethods,
            child: _SelectField(
              key: const Key('discount-payment-mode-field'),
              value: _allPaymentMethods ? 'all' : 'selected',
              options: <_SelectOption>[
                _SelectOption('all', l10n.discountFormAllPaymentMethods),
                _SelectOption(
                  'selected',
                  l10n.discountFormSelectedPaymentMethods,
                ),
              ],
              enabled: !locked,
              onChanged: (value) => setState(() {
                _allPaymentMethods = value == 'all';
                if (_allPaymentMethods) _paymentMethodIds.clear();
              }),
            ),
          ),
          _LabeledField(
            label: l10n.discountFormBranches,
            child: _SelectField(
              key: const Key('discount-branch-mode-field'),
              value: _appliesToAllBranches ? 'all' : 'selected',
              options: <_SelectOption>[
                _SelectOption('all', l10n.discountFormAllBranches),
                _SelectOption('selected', l10n.discountFormSelectedBranches),
              ],
              enabled: !locked,
              onChanged: (value) => setState(() {
                _appliesToAllBranches = value == 'all';
                if (_appliesToAllBranches) _branchIds.clear();
              }),
            ),
          ),
          if (_customerEligibilityMode == 'selected_groups')
            _LabeledField(
              label: l10n.discountFormCustomerGroups,
              child: _referenceSelector(
                key: const Key('discount-customer-groups-selector'),
                label: l10n.discountFormSelectCustomerGroups,
                items: state.formReferences.customerGroups,
                selectedIds: _customerGroupIds,
                loading: state.isLoadingFormReferences,
                enabled: !locked,
                onChanged: (ids) =>
                    setState(() => _replace(_customerGroupIds, ids)),
              ),
            ),
          if (_customerEligibilityMode == 'selected_customers')
            _LabeledField(
              label: l10n.discountV2SelectedCustomers,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _referenceSelector(
                    key: const Key('discount-customers-selector'),
                    label: l10n.discountV2SelectCustomers,
                    items: state.formReferences.customers,
                    selectedIds: _customerIds,
                    loading: state.isLoadingFormReferences,
                    enabled: !locked,
                    searchable: true,
                    onChanged: (ids) =>
                        setState(() => _replace(_customerIds, ids)),
                  ),
                  if (_customerIds.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _SelectedReferenceChips(
                      items: state.formReferences.customers,
                      selectedIds: _customerIds,
                      enabled: !locked,
                      onRemove: (id) => setState(() => _customerIds.remove(id)),
                    ),
                  ],
                ],
              ),
            ),
          if (!_allPaymentMethods)
            _LabeledField(
              label: l10n.discountFormSelectedPaymentMethods,
              child: _referenceSelector(
                key: const Key('discount-payment-methods-selector'),
                label: l10n.discountFormSelectPaymentMethods,
                items: state.formReferences.paymentMethods,
                selectedIds: _paymentMethodIds,
                loading: state.isLoadingFormReferences,
                enabled: !locked,
                onChanged: (ids) =>
                    setState(() => _replace(_paymentMethodIds, ids)),
              ),
            ),
          if (!_appliesToAllBranches)
            _LabeledField(
              label: l10n.discountFormSelectedBranches,
              child: _branchSelector(state, locked),
            ),
          _LabeledField(
            label: l10n.discountV2Channels,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SelectField(
                  key: const Key('discount-channel-mode-field'),
                  value: _allChannels ? 'all' : 'selected',
                  options: <_SelectOption>[
                    _SelectOption('all', l10n.discountV2AllChannels),
                    _SelectOption('selected', l10n.discountV2SelectedChannels),
                  ],
                  enabled: !locked,
                  onChanged: (value) => setState(() {
                    _allChannels = value == 'all';
                    if (_allChannels) _channelKeys.clear();
                  }),
                ),
                if (!_allChannels) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _channelSelector(locked),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.discountV2BranchChannelHelp,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(bool locked) => DiscountFormSectionCard(
    title: AppLocalizations.of(context).discountFormSchedule,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(
          label: AppLocalizations.of(context).discountFormActiveWeekdays,
        ),
        const SizedBox(height: AppSpacing.sm),
        DiscountChipSelector(
          options: const <String>[
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ],
          selected: _activeDays,
          onSelected: locked
              ? (_) {}
              : (value) => setState(
                  () => _activeDays.contains(value)
                      ? _activeDays.remove(value)
                      : _activeDays.add(value),
                ),
          optionLabel: _weekdayLabel,
        ),
        const SizedBox(height: AppSpacing.lg),
        _AdaptiveFields(
          children: <_LabeledField>[
            _LabeledField(
              label: AppLocalizations.of(context).discountFormStartDate,
              child: _dateField(
                _startDateController,
                locked,
                const Key('discount-start-date-field'),
              ),
            ),
            _LabeledField(
              label: AppLocalizations.of(context).discountFormEndDate,
              child: _dateField(
                _endDateController,
                locked,
                const Key('discount-end-date-field'),
              ),
            ),
            _LabeledField(
              label: AppLocalizations.of(context).discountFormStartTime,
              child: _timeField(
                _startTimeController,
                locked,
                const Key('discount-start-time-field'),
              ),
            ),
            _LabeledField(
              label: AppLocalizations.of(context).discountFormEndTime,
              child: _timeField(
                _endTimeController,
                locked,
                const Key('discount-end-time-field'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppLocalizations.of(context).discountFormOvernightHelp,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    ),
  );

  Widget _usageCard(bool locked) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DiscountFormSectionCard(
      title: l10n.discountFormUsageLimits,
      child: _AdaptiveFields(
        children: <_LabeledField>[
          _LabeledField(
            label: l10n.discountFormGlobalUsageOptional,
            child: _integerField(
              _usageLimitController,
              locked,
              const Key('discount-usage-limit-field'),
            ),
          ),
          _LabeledField(
            label: l10n.discountFormLifetimeUsageOptional,
            child: _integerField(
              _perCustomerLimitController,
              locked,
              const Key('discount-per-customer-limit-field'),
            ),
          ),
          _LabeledField(
            label: l10n.discountV2DailyLimit,
            child: _integerField(
              _perCustomerDailyLimitController,
              locked,
              const Key('discount-per-customer-daily-limit-field'),
            ),
          ),
          _LabeledField(
            label: l10n.discountV2DailyLimit,
            child: Text(
              l10n.discountV2DailyLimitDetails,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyField(
    TextEditingController controller,
    bool locked,
    Key key,
    String currency,
  ) => AppTextField(
    key: key,
    controller: controller,
    enabled: !locked,
    prefixText: '$currency ',
    hintText: '0 $currency',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  );
  Widget _dateField(TextEditingController controller, bool locked, Key key) =>
      AppTextField(
        key: key,
        controller: controller,
        enabled: !locked,
        readOnly: true,
        hintText: 'YYYY-MM-DD',
        suffixIcon: controller.text.isEmpty
            ? Icons.calendar_today_outlined
            : Icons.clear,
        onSuffixPressed: controller.text.isEmpty || locked
            ? null
            : () => controller.clear(),
        onTap: locked ? null : () => _pickDate(controller),
        errorText: _fieldError(
          identical(controller, _startDateController) ? 'startDate' : 'endDate',
        ),
      );
  Widget _timeField(TextEditingController controller, bool locked, Key key) =>
      AppTextField(
        key: key,
        controller: controller,
        enabled: !locked,
        readOnly: true,
        hintText: 'HH:mm',
        suffixIcon: controller.text.isEmpty
            ? Icons.access_time_outlined
            : Icons.clear,
        onSuffixPressed: controller.text.isEmpty || locked
            ? null
            : () => controller.clear(),
        onTap: locked ? null : () => _pickTime(controller),
        errorText: _fieldError(
          identical(controller, _startTimeController) ? 'startTime' : 'endTime',
        ),
      );
  Widget _integerField(
    TextEditingController controller,
    bool locked,
    Key key,
  ) => AppTextField(
    key: key,
    controller: controller,
    enabled: !locked,
    hintText: AppLocalizations.of(context).discountFormUnlimited,
    keyboardType: TextInputType.number,
  );

  Widget _referenceSelector({
    required Key key,
    required String label,
    required List<DiscountFormReference> items,
    required Set<int> selectedIds,
    required bool loading,
    required bool enabled,
    bool searchable = false,
    required ValueChanged<Set<int>> onChanged,
  }) => _ReferenceSelector(
    key: key,
    label: label,
    items: items,
    selectedIds: selectedIds,
    loading: loading,
    enabled: enabled,
    searchable: searchable,
    onChanged: onChanged,
  );

  Widget _branchSelector(DiscountsState state, bool locked) {
    final List<DiscountFormReference> branches = state.branches
        .where((branch) => branch.id > 0 && branch.isActive)
        .map(
          (branch) => DiscountFormReference(
            id: branch.id,
            name: branch.name,
            isActive: branch.isActive,
          ),
        )
        .toList(growable: false);
    return _referenceSelector(
      key: const Key('discount-branches-selector'),
      label: AppLocalizations.of(context).discountFormSelectBranches,
      items: branches,
      selectedIds: _branchIds,
      loading: state.isLoadingBranches,
      enabled: !locked,
      onChanged: (ids) => setState(() => _replace(_branchIds, ids)),
    );
  }

  Widget _channelSelector(bool locked) => DiscountChipSelector(
    key: const Key('discount-channels-selector'),
    options: operationalSalesChannels,
    selected: _channelKeys,
    onSelected: locked
        ? (_) {}
        : (String value) => setState(
            () => _channelKeys.contains(value)
                ? _channelKeys.remove(value)
                : _channelKeys.add(value),
          ),
    optionLabel: (String channel) =>
        discountChannelLabel(channel, AppLocalizations.of(context)),
  );

  Widget _bundleRequirementsBuilder(DiscountsState state, bool locked) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label: l10n.discountV2PackageRequirements),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.discountV2AllPackageItems,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        for (int index = 0; index < _bundleRequirements.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _AdaptiveFields(
              children: <_LabeledField>[
                _LabeledField(
                  label: l10n.discountFormProduct,
                  child: DropdownButtonFormField<int>(
                    key: Key('discount-bundle-product-$index'),
                    initialValue: _bundleRequirements[index].productId == 0
                        ? null
                        : _bundleRequirements[index].productId,
                    isExpanded: true,
                    items: state.formReferences.products
                        .where(
                          (DiscountFormReference product) =>
                              product.id ==
                                  _bundleRequirements[index].productId ||
                              !_bundleRequirements.any(
                                (_BundleRequirementDraft requirement) =>
                                    requirement != _bundleRequirements[index] &&
                                    requirement.productId == product.id,
                              ),
                        )
                        .map(
                          (DiscountFormReference product) =>
                              DropdownMenuItem<int>(
                                value: product.id,
                                child: Text(product.name),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: locked
                        ? null
                        : (int? value) => setState(
                            () => _bundleRequirements[index].productId =
                                value ?? 0,
                          ),
                  ),
                ),
                _LabeledField(
                  label: l10n.discountV2RequiredQuantity,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: AppTextField(
                          key: Key('discount-bundle-quantity-$index'),
                          controller: _bundleRequirements[index].controller,
                          enabled: !locked,
                          hintText: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('discount-remove-bundle-row-$index'),
                        onPressed: locked
                            ? null
                            : () => setState(() {
                                final _BundleRequirementDraft requirement =
                                    _bundleRequirements.removeAt(index);
                                requirement.dispose();
                              }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          key: const Key('discount-add-bundle-product'),
          onPressed: locked
              ? null
              : () => setState(
                  () => _bundleRequirements.add(_BundleRequirementDraft()),
                ),
          icon: const Icon(Icons.add),
          label: Text(l10n.discountV2AddProduct),
        ),
      ],
    );
  }

  void _changeApplicationMode(String value) {
    setState(() {
      _applicationMode = value;
      _couponGenerationError = null;
      if (value == 'manual') _codeController.clear();
    });
    if (value == 'code' && _nullableText(_codeController) == null) {
      unawaited(_generateCouponCode());
    }
  }

  Future<void> _generateCouponCode() async {
    if (_isGeneratingCode || _applicationMode != 'code') return;
    setState(() {
      _isGeneratingCode = true;
      _couponGenerationError = null;
    });
    try {
      final String code = await context
          .read<DiscountsCubit>()
          .generateCouponCode();
      if (!mounted || _applicationMode != 'code') return;
      _codeController.text = code;
      setState(() => _isGeneratingCode = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGeneratingCode = false;
        _couponGenerationError = 'generation_failed';
      });
    }
  }

  void _clearBundleRequirements() {
    for (final _BundleRequirementDraft requirement in _bundleRequirements) {
      requirement.dispose();
    }
    _bundleRequirements.clear();
  }

  String _customerSummary(DiscountsState state) {
    if (_customerEligibilityMode == 'all') {
      return AppLocalizations.of(context).discountFormAllCustomers;
    }
    final Set<int> ids = _customerEligibilityMode == 'selected_groups'
        ? _customerGroupIds
        : _customerIds;
    final List<DiscountFormReference> items =
        _customerEligibilityMode == 'selected_groups'
        ? state.formReferences.customerGroups
        : state.formReferences.customers;
    final List<String> names = items
        .where((DiscountFormReference item) => ids.contains(item.id))
        .map((DiscountFormReference item) => item.name)
        .toList(growable: false);
    return names.isEmpty
        ? AppLocalizations.of(
            context,
          ).discountFormSelectedCustomersPlural(ids.length)
        : names.join(', ');
  }

  String? _bundleSummary(DiscountsState state) {
    if (_scope != 'bundle' || _bundleRequirements.isEmpty) return null;
    final Map<int, String> names = <int, String>{
      for (final DiscountFormReference product in state.formReferences.products)
        product.id: product.name,
    };
    return _bundleRequirements
        .where((item) => item.productId > 0)
        .map(
          (item) =>
              '${names[item.productId] ?? AppLocalizations.of(context).discountFormProduct} ×${item.controller.text}',
        )
        .join(' + ');
  }

  String? _usageSummary() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? lifetime = _positiveInt(_perCustomerLimitController.text);
    final int? daily = _positiveInt(_perCustomerDailyLimitController.text);
    if (lifetime == null && daily == null) return null;
    if (lifetime == null) return l10n.discountFormPerDayPlural(daily!);
    if (daily == null) return l10n.discountFormLifetimePlural(lifetime);
    return l10n.discountFormUsageBoth(lifetime, daily);
  }

  Widget _buildSideRail(DiscountsState state, bool isReady) {
    final double value = _decimalValue(_valueController.text) ?? 0;
    final double taxRate =
        state.branches
            .where((branch) => branch.isActive)
            .map((branch) => branch.taxRate)
            .cast<double?>()
            .firstWhere(
              (rate) => rate != null,
              orElse: () => TaxConfig.defaultTaxRate,
            ) ??
        TaxConfig.defaultTaxRate;
    return Column(
      children: <Widget>[
        DiscountPosPreviewCard(
          discountValue: value,
          isPercentage: _isPercentage,
          taxRate: taxRate,
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscountSummaryPanel(
          value: _isPercentage
              ? AppLocalizations.of(context).discountPercentOff(_decimal(value))
              : AppLocalizations.of(context).discountAmountOff(
                  CurrencyFormatter.format(
                    value,
                    locale: AppLocalizations.of(context).localeName,
                    currencyCode: _currency(state),
                  ),
                ),
          isReady: isReady,
          scope: _scopeLabel(_scope),
          branches: _appliesToAllBranches
              ? AppLocalizations.of(context).discountFormAllBranches
              : AppLocalizations.of(
                  context,
                ).discountFormSelectedCountPlural(_branchIds.length),
          schedule: _activeDays.isEmpty
              ? AppLocalizations.of(context).discountFormAnyDay
              : AppLocalizations.of(
                  context,
                ).discountFormDaysSelectedPlural(_activeDays.length),
          customers: _customerSummary(state),
          package: _bundleSummary(state),
          channels: _allChannels
              ? AppLocalizations.of(context).discountV2AllChannels
              : _channelKeys
                    .map(
                      (String channel) => discountChannelLabel(
                        channel,
                        AppLocalizations.of(context),
                      ),
                    )
                    .join(', '),
          usage: _usageSummary(),
          coupon: _applicationMode == 'code'
              ? _nullableText(_codeController)
              : null,
        ),
      ],
    );
  }

  void _discardChanges() {
    if (_isEdit) {
      _loadDetail();
      return;
    }
    for (final TextEditingController controller in _formControllers) {
      controller.clear();
    }
    setState(() {
      _active = false;
      _applicationMode = 'manual';
      _scope = 'order';
      _valueType = 'percentage';
      _customerEligibilityMode = 'all';
      _appliesToAllBranches = true;
      _allPaymentMethods = true;
      _allChannels = true;
      _productIds.clear();
      _categoryIds.clear();
      _customerGroupIds.clear();
      _customerIds.clear();
      _branchIds.clear();
      _paymentMethodIds.clear();
      _channelKeys.clear();
      _clearBundleRequirements();
      _activeDays.clear();
    });
  }

  Future<void> _submit(bool activate) async {
    if (_isLoadingDetail || context.read<DiscountsCubit>().state.isSaving) {
      return;
    }
    final String? validation = _validate();
    if (validation != null) {
      setState(() => _showValidationErrors = true);
      _showMessage(validation);
      return;
    }
    final DiscountUpsertRequest request = DiscountUpsertRequest(
      name: _nameController.text.trim(),
      code: _applicationMode == 'code' ? _nullableText(_codeController) : null,
      description: _nullableText(_descriptionController),
      applicationMode: _applicationMode,
      type: _valueType,
      scope: _scope,
      value: _decimalValue(_valueController.text)!,
      conditions: _conditions,
      minimumOrderAmount: _decimalValue(_minSpendController.text),
      maximumDiscountAmount: _decimalValue(_maxDiscountController.text),
      startDate: _nullableText(_startDateController),
      endDate: _nullableText(_endDateController),
      activeDays: _activeDays.isEmpty
          ? null
          : _activeDays.toList(growable: false),
      startTime: _nullableText(_startTimeController),
      endTime: _nullableText(_endTimeController),
      usageLimit: _positiveInt(_usageLimitController.text),
      usageLimitPerCustomer: _positiveInt(_perCustomerLimitController.text),
      perCustomerDailyUsageLimit: _positiveInt(
        _perCustomerDailyLimitController.text,
      ),
      customerEligibilityMode: _customerEligibilityMode,
      customerGroupIds: _customerEligibilityMode == 'selected_groups'
          ? _customerGroupIds.toList(growable: false)
          : const <int>[],
      customerIds: _customerEligibilityMode == 'selected_customers'
          ? _customerIds.toList(growable: false)
          : const <int>[],
      paymentMethodIds: _allPaymentMethods
          ? const <int>[]
          : _paymentMethodIds.toList(growable: false),
      targetProductIds: _scope == 'product'
          ? _productIds.toList(growable: false)
          : const <int>[],
      targetCategoryIds: _scope == 'category'
          ? _categoryIds.toList(growable: false)
          : const <int>[],
      bundleRequirements: _scope == 'bundle'
          ? _bundleRequirements
                .map(
                  (_BundleRequirementDraft item) => DiscountBundleRequirement(
                    productId: item.productId,
                    quantity: _decimalValue(item.controller.text) ?? 0,
                  ),
                )
                .toList(growable: false)
          : const <DiscountBundleRequirement>[],
      channelKeys: _allChannels
          ? const <String>[]
          : _channelKeys.toList(growable: false),
      appliesToAllBranches: _appliesToAllBranches,
      branchIds: _appliesToAllBranches
          ? const <int>[]
          : _branchIds.toList(growable: false),
      isActive: activate ? true : _active,
    );
    final DiscountsCubit cubit = context.read<DiscountsCubit>();
    final bool saved = _isEdit
        ? await cubit.updateDiscount(widget.initialDiscount!.id, request)
        : await cubit.createDiscount(request);
    if (!mounted) {
      return;
    }
    if (saved) {
      _showMessage(
        activate
            ? AppLocalizations.of(context).discountFormSavedActivated
            : AppLocalizations.of(context).discountFormSaved,
      );
      context.go(AppRoutes.discounts);
    } else if (cubit.state.validationErrors.isEmpty) {
      _showMessage(AppLocalizations.of(context).discountRequestFailed);
    }
  }

  List<String> _localizedServerValidationErrors(
    Map<String, List<String>> validationErrors,
  ) {
    if (validationErrors.isEmpty) {
      return const <String>[];
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    final Set<String> messages = <String>{};
    for (final String field in validationErrors.keys) {
      final String? label = _discountValidationFieldLabel(field, l10n);
      if (label == null) {
        return <String>[l10n.discountRequestFailed];
      }
      messages.add(l10n.discountServerFieldInvalid(label));
    }
    return messages.toList(growable: false);
  }

  String? _discountValidationFieldLabel(String field, AppLocalizations l10n) {
    final String root = field.split('.').first;
    return switch (root) {
      'name' => l10n.discountFormName,
      'code' => l10n.discountCode,
      'description' => l10n.discountFormDescription,
      'applicationMode' => l10n.discountFormApplicationMode,
      'type' => l10n.discountFormValueType,
      'scope' || 'targets' => l10n.discountFormAppliesTo,
      'value' => l10n.discountFormValue,
      'minimumOrderAmount' => l10n.discountFormMinSpendOptional,
      'maximumDiscountAmount' => l10n.discountFormMaxDiscountOptional,
      'targetProductIds' => l10n.discountSelectedProducts,
      'targetCategoryIds' => l10n.discountSelectedCategories,
      'bundleRequirements' => l10n.discountV2PackageRequirements,
      'customerEligibilityMode' ||
      'customerEligibility' => l10n.discountCustomerEligibility,
      'customerGroupIds' => l10n.discountFormCustomerGroups,
      'customerIds' => l10n.discountV2SelectedCustomers,
      'paymentMethod' || 'paymentMethodIds' => l10n.discountPaymentMethods,
      'branchIds' || 'appliesToAllBranches' => l10n.discountFormBranches,
      'channelKeys' => l10n.discountV2Channels,
      'startDate' || 'startsAt' => l10n.discountFormStartDate,
      'endDate' || 'endsAt' => l10n.discountFormEndDate,
      'startTime' => l10n.discountFormStartTime,
      'endTime' => l10n.discountFormEndTime,
      'schedule' || 'activeDays' => l10n.discountFormSchedule,
      'usageLimit' || 'usageLimitPerCustomer' => l10n.discountFormUsageLimits,
      'perCustomerDailyUsageLimit' => l10n.discountV2DailyLimit,
      'isActive' => l10n.commonActive,
      _ => null,
    };
  }

  String? _validate() {
    final List<_FormValidationIssue> issues = _validationIssues();
    return issues.isEmpty ? null : issues.first.message;
  }

  String? _fieldError(String field) {
    final List<_FormValidationIssue> matching = _validationIssues()
        .where((_FormValidationIssue issue) => issue.field == field)
        .toList(growable: false);
    final _FormValidationIssue? issue = matching.isEmpty
        ? null
        : matching.first;
    if (issue == null) return null;
    if (field == 'value' && _valueController.text.trim().isEmpty) return null;
    return issue.message;
  }

  List<_FormValidationIssue> _validationIssues() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<_FormValidationIssue> issues = <_FormValidationIssue>[];
    if (_nameController.text.trim().isEmpty) {
      issues.add(_FormValidationIssue('name', l10n.discountValidationName));
    }
    final double? value = _decimalValue(_valueController.text);
    if (value == null || value < 0) {
      issues.add(
        _FormValidationIssue('value', l10n.discountValidationNonNegativeValue),
      );
    }
    if (_isPercentage && value != null && value > 100) {
      issues.add(
        _FormValidationIssue('value', l10n.discountValidationPercentage),
      );
    }
    if (_applicationMode == 'code' && _nullableText(_codeController) == null) {
      issues.add(_FormValidationIssue('code', l10n.discountValidationCode));
    }
    if (_scope == 'product' && _productIds.isEmpty) {
      issues.add(
        _FormValidationIssue('scope', l10n.discountValidationProducts),
      );
    }
    if (_scope == 'category' && _categoryIds.isEmpty) {
      issues.add(
        _FormValidationIssue('scope', l10n.discountValidationCategories),
      );
    }
    if (_scope == 'bundle') {
      if (_bundleRequirements.isEmpty) {
        issues.add(
          _FormValidationIssue(
            'bundleRequirements',
            l10n.discountValidationBundle,
          ),
        );
      }
      final Set<int> bundleProductIds = <int>{};
      for (final _BundleRequirementDraft requirement in _bundleRequirements) {
        if (requirement.productId <= 0) {
          issues.add(
            _FormValidationIssue(
              'bundleRequirements',
              l10n.discountValidationBundleProduct,
            ),
          );
        } else if (!bundleProductIds.add(requirement.productId)) {
          issues.add(
            _FormValidationIssue(
              'bundleRequirements',
              l10n.discountValidationBundleUnique,
            ),
          );
        }
        final double? quantity = _decimalValue(requirement.controller.text);
        if (quantity == null || quantity <= 0) {
          issues.add(
            _FormValidationIssue(
              'bundleRequirements',
              l10n.discountValidationBundleQuantity,
            ),
          );
        }
      }
    }
    if (_customerEligibilityMode == 'selected_groups' &&
        _customerGroupIds.isEmpty) {
      issues.add(
        _FormValidationIssue('customerGroups', l10n.discountValidationGroups),
      );
    }
    if (_customerEligibilityMode == 'selected_customers' &&
        _customerIds.isEmpty) {
      issues.add(
        _FormValidationIssue('customers', l10n.discountValidationCustomers),
      );
    }
    if (!_appliesToAllBranches && _branchIds.isEmpty) {
      issues.add(
        _FormValidationIssue('branches', l10n.discountValidationBranches),
      );
    }
    if ((_minSpendController.text.trim().isNotEmpty &&
            _decimalValue(_minSpendController.text) == null) ||
        (_maxDiscountController.text.trim().isNotEmpty &&
            _decimalValue(_maxDiscountController.text) == null)) {
      issues.add(_FormValidationIssue('money', l10n.discountValidationMoney));
    }
    if ((_decimalValue(_minSpendController.text) ?? 0) < 0 ||
        (_decimalValue(_maxDiscountController.text) ?? 0) < 0) {
      issues.add(
        _FormValidationIssue('money', l10n.discountValidationNegativeMoney),
      );
    }
    if (_positiveInt(_usageLimitController.text) == null &&
        _usageLimitController.text.trim().isNotEmpty) {
      issues.add(
        _FormValidationIssue('usageLimit', l10n.discountValidationUsage),
      );
    }
    if (_positiveInt(_perCustomerLimitController.text) == null &&
        _perCustomerLimitController.text.trim().isNotEmpty) {
      issues.add(
        _FormValidationIssue('usageLimit', l10n.discountValidationUsage),
      );
    }
    if (_positiveInt(_perCustomerDailyLimitController.text) == null &&
        _perCustomerDailyLimitController.text.trim().isNotEmpty) {
      issues.add(
        _FormValidationIssue(
          'dailyUsageLimit',
          l10n.discountValidationDailyUsage,
        ),
      );
    }
    final DateTime? startDate = _dateValue(_startDateController.text);
    final DateTime? endDate = _dateValue(_endDateController.text);
    if ((_startDateController.text.trim().isNotEmpty && startDate == null) ||
        (_endDateController.text.trim().isNotEmpty && endDate == null)) {
      issues.add(
        _FormValidationIssue('startDate', l10n.discountValidationDate),
      );
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      issues.add(
        _FormValidationIssue('endDate', l10n.discountValidationEndDate),
      );
    }
    final bool hasStartTime = _startTimeController.text.trim().isNotEmpty;
    final bool hasEndTime = _endTimeController.text.trim().isNotEmpty;
    if (hasStartTime != hasEndTime) {
      issues.add(
        _FormValidationIssue('startTime', l10n.discountValidationTimesTogether),
      );
      issues.add(
        _FormValidationIssue('endTime', l10n.discountValidationTimesTogether),
      );
    }
    if ((hasStartTime && !_validTime(_startTimeController.text)) ||
        (hasEndTime && !_validTime(_endTimeController.text))) {
      issues.add(
        _FormValidationIssue('startTime', l10n.discountValidationTime),
      );
    }
    return issues;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateValue(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      controller.text = _dateText(picked);
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _timeValue(controller.text) ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      controller.text = _timeText(picked);
    }
  }

  static void _replace(Set<int> target, Iterable<int> values) {
    target
      ..clear()
      ..addAll(values);
  }

  static double? _decimalValue(String value) => value.trim().isEmpty
      ? null
      : double.tryParse(value.trim().replaceAll(',', ''));
  static int? _positiveInt(String value) {
    final int? result = int.tryParse(value.trim());
    return result != null && result > 0 ? result : null;
  }

  static DateTime? _dateValue(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim())
      ? DateTime.tryParse(value.trim())
      : null;
  static String _dateText(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static TimeOfDay? _timeValue(String value) {
    if (!_validTime(value)) return null;
    final List<String> parts = value.trim().split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _timeText(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  static bool _validTime(String value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value.trim());
  static String? _nullableText(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();
  static String _decimal(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
  static String _nullableDecimal(double? value) =>
      value == null ? '' : _decimal(value);
  static String _displayTime(String? value) => value == null
      ? ''
      : value.length >= 5
      ? value.substring(0, 5)
      : value;
  String _weekdayLabel(String value) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return switch (value) {
      'Mon' => l10n.discountWeekdayMonday,
      'Tue' => l10n.discountWeekdayTuesday,
      'Wed' => l10n.discountWeekdayWednesday,
      'Thu' => l10n.discountWeekdayThursday,
      'Fri' => l10n.discountWeekdayFriday,
      'Sat' => l10n.discountWeekdaySaturday,
      'Sun' => l10n.discountWeekdaySunday,
      _ => value,
    };
  }

  String _scopeLabel(String scope) => switch (scope) {
    'product' => AppLocalizations.of(context).discountSelectedProducts,
    'category' => AppLocalizations.of(context).discountSelectedCategories,
    'bundle' => AppLocalizations.of(context).discountV2PackageBundle,
    _ => AppLocalizations.of(context).discountEntireOrder,
  };
  String _currency(DiscountsState state) {
    for (final branch in state.branches) {
      if (branch.isActive && branch.currency.trim().isNotEmpty) {
        return branch.currency;
      }
    }
    return AppLocalizations.of(context).discountCurrency;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FormValidationIssue {
  const _FormValidationIssue(this.field, this.message);

  final String field;
  final String message;
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.isEdit});
  final bool isEdit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AppBreadcrumbs(
        items: <AppBreadcrumbItem>[
          AppBreadcrumbItem(
            label: AppLocalizations.of(context).discountsTitle,
            onTap: () => context.go(AppRoutes.discounts),
            key: const Key('breadcrumb-discounts'),
          ),
          AppBreadcrumbItem(
            label: isEdit
                ? AppLocalizations.of(context).discountFormEdit
                : AppLocalizations.of(context).discountFormCreate,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        isEdit
            ? AppLocalizations.of(context).discountFormEditPolicy
            : AppLocalizations.of(context).discountFormCreatePolicy,
        style: AppTextStyles.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        AppLocalizations.of(context).discountFormHeadingSubtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      ),
    ],
  );
}

class _AdaptiveFields extends StatelessWidget {
  const _AdaptiveFields({required this.children});
  final List<_LabeledField> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bool columns =
          constraints.maxWidth >= AppSizes.createProductFieldRowBreakpoint;
      final double width = columns
          ? (constraints.maxWidth - AppSpacing.lg) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: children
            .map(
              (field) => SizedBox(
                width: columns && field.span == 2
                    ? constraints.maxWidth
                    : width,
                child: field,
              ),
            )
            .toList(),
      );
    },
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.span = 1,
  });
  final String label;
  final Widget child;
  final int span;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _FieldLabel(label: label),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppTextStyles.labelSmall.copyWith(
      color: AppColors.textSecondary,
      letterSpacing: 0.2,
    ),
  );
}

class _SelectOption {
  const _SelectOption(this.value, this.label);
  final String value;
  final String label;
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
  });
  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    items: options
        .map(
          (option) => DropdownMenuItem<String>(
            value: option.value,
            child: Text(option.label),
          ),
        )
        .toList(),
    onChanged: enabled
        ? (value) {
            if (value != null) onChanged(value);
          }
        : null,
  );
}

class _ReferenceSelector extends StatelessWidget {
  const _ReferenceSelector({
    super.key,
    required this.label,
    required this.items,
    required this.selectedIds,
    required this.loading,
    required this.enabled,
    required this.onChanged,
    this.searchable = false,
  });
  final String label;
  final List<DiscountFormReference> items;
  final Set<int> selectedIds;
  final bool loading;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;
  final bool searchable;
  @override
  Widget build(BuildContext context) {
    final List<String> names = items
        .where((item) => selectedIds.contains(item.id))
        .map((item) => item.name)
        .toList(growable: false);
    return OutlinedButton(
      onPressed: !enabled || loading
          ? null
          : () async {
              final Set<int>? next = await showDialog<Set<int>>(
                context: context,
                builder: (_) => _ReferencePicker(
                  title: label,
                  items: items,
                  initialSelection: selectedIds,
                  searchable: searchable,
                ),
              );
              if (next != null) onChanged(next);
            },
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          loading
              ? AppLocalizations.of(context).discountFormLoading
              : names.isEmpty
              ? label
              : names.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ReferencePicker extends StatefulWidget {
  const _ReferencePicker({
    required this.title,
    required this.items,
    required this.initialSelection,
    required this.searchable,
  });
  final String title;
  final List<DiscountFormReference> items;
  final Set<int> initialSelection;
  final bool searchable;
  @override
  State<_ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<_ReferencePicker> {
  late final Set<int> _selection = Set<int>.of(widget.initialSelection);
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: widget.items.isEmpty
            ? Text(l10n.discountFormNoOptions)
            : Column(
                children: <Widget>[
                  if (widget.searchable)
                    TextField(
                      key: const Key('discount-reference-search'),
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: l10n.discountV2Search,
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: widget.items
                          .where((DiscountFormReference item) {
                            final String query = _query.trim().toLowerCase();
                            return query.isEmpty ||
                                item.name.toLowerCase().contains(query) ||
                                (item.subtitle ?? '').toLowerCase().contains(
                                  query,
                                );
                          })
                          .map(
                            (item) => CheckboxListTile(
                              value: _selection.contains(item.id),
                              title: Text(item.name),
                              subtitle: item.subtitle == null
                                  ? null
                                  : Text(item.subtitle!),
                              onChanged: (value) => setState(
                                () => value == true
                                    ? _selection.add(item.id)
                                    : _selection.remove(item.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selection),
          child: Text(l10n.discountFormDone),
        ),
      ],
    );
  }
}

class _SelectedReferenceChips extends StatelessWidget {
  const _SelectedReferenceChips({
    required this.items,
    required this.selectedIds,
    required this.enabled,
    required this.onRemove,
  });

  final List<DiscountFormReference> items;
  final Set<int> selectedIds;
  final bool enabled;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: items
        .where((DiscountFormReference item) => selectedIds.contains(item.id))
        .map(
          (DiscountFormReference item) => InputChip(
            label: Text(
              item.subtitle == null
                  ? item.name
                  : '${item.name} · ${item.subtitle}',
            ),
            onDeleted: enabled ? () => onRemove(item.id) : null,
          ),
        )
        .toList(growable: false),
  );
}

class _BundleRequirementDraft {
  _BundleRequirementDraft({this.productId = 0, String quantity = ''})
    : controller = TextEditingController(text: quantity);

  factory _BundleRequirementDraft.fromRequirement(
    DiscountBundleRequirement requirement,
  ) => _BundleRequirementDraft(
    productId: requirement.productId,
    quantity: requirement.quantity == requirement.quantity.truncateToDouble()
        ? requirement.quantity.toInt().toString()
        : requirement.quantity.toString(),
  );

  int productId;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => DiscountFormSectionCard(
    title: AppLocalizations.of(context).discountFormLoadTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).discountV2Retry),
        ),
      ],
    ),
  );
}

class _ReferencesRetry extends StatelessWidget {
  const _ReferencesRetry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: TextButton(
      onPressed: onRetry,
      child: Text(AppLocalizations.of(context).discountFormRetryOptions),
    ),
  );
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final List<String> uniqueMessages = messages.toSet().toList(
      growable: false,
    );
    return Container(
      width: double.infinity,
      padding: AppSpacing.allMd,
      color: AppColors.discountOrangeBadge,
      child: Text(
        uniqueMessages.join('\n'),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
      ),
    );
  }
}
