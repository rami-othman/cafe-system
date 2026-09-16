import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/config/tax_config.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/discounts_cubit.dart';
import '../controllers/discounts_state.dart';
import '../models/discount_detail.dart';
import '../models/discount_form_references.dart';
import '../models/discount_list_item.dart';
import '../models/discount_upsert_request.dart';
import '../widgets/discount_bottom_action_bar.dart';
import '../widgets/discount_chip_selector.dart';
import '../widgets/discount_form_section_card.dart';
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

  bool _active = false;
  String _applicationMode = 'manual';
  String _scope = 'order';
  String _valueType = 'percentage';
  String _customerEligibilityMode = 'all';
  bool _appliesToAllBranches = true;
  bool _allPaymentMethods = true;
  final Set<int> _productIds = <int>{};
  final Set<int> _categoryIds = <int>{};
  final Set<int> _customerGroupIds = <int>{};
  final Set<int> _branchIds = <int>{};
  final Set<int> _paymentMethodIds = <int>{};
  final Set<String> _activeDays = <String>{};
  bool _isLoadingDetail = false;
  String? _detailError;
  String? _conditions;
  bool _showValidationErrors = false;

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
        _detailError = 'Unable to load this discount. Please try again.';
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
    setState(() {
      _active = detail.isActive;
      _applicationMode = detail.applicationMode == 'code' ? 'code' : 'manual';
      _scope = switch (detail.scope) {
        'product' => 'product',
        'category' => 'category',
        _ => 'order',
      };
      _valueType = detail.type == 'fixed' ? 'fixed' : 'percentage';
      _customerEligibilityMode =
          detail.customerEligibilityMode == 'selected_groups'
          ? 'selected_groups'
          : 'all';
      _appliesToAllBranches = detail.appliesToAllBranches;
      _allPaymentMethods = detail.paymentMethodIds.isEmpty;
      _replace(_productIds, detail.targetProductIds);
      _replace(_categoryIds, detail.targetCategoryIds);
      _replace(_customerGroupIds, detail.customerGroupIds);
      _replace(_branchIds, detail.branchIds);
      _replace(_paymentMethodIds, detail.paymentMethodIds);
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
            ...state.validationErrors.values.expand(
              (List<String> messages) => messages,
            ),
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

  Widget _basicCard(bool locked) => DiscountFormSectionCard(
    title: 'Basic Information',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('Active', style: AppTextStyles.bodySmall),
        const SizedBox(width: AppSpacing.sm),
        Switch(
          value: _active,
          onChanged: locked ? null : (value) => setState(() => _active = value),
        ),
      ],
    ),
    child: _AdaptiveFields(
      children: <_LabeledField>[
        _LabeledField(
          label: 'Discount Name',
          child: AppTextField(
            key: const Key('discount-name-field'),
            controller: _nameController,
            enabled: !locked,
          ),
        ),
        _LabeledField(
          label: 'Application Mode',
          child: _SelectField(
            key: const Key('discount-application-mode-field'),
            value: _applicationMode,
            options: const <_SelectOption>[
              _SelectOption('manual', 'Manual'),
              _SelectOption('code', 'Coupon / Code'),
            ],
            enabled: !locked,
            onChanged: (value) => setState(() {
              _applicationMode = value;
              if (value == 'manual') _codeController.clear();
            }),
          ),
        ),
        if (_applicationMode == 'code')
          _LabeledField(
            label: 'Code',
            child: AppTextField(
              key: const Key('discount-code-field'),
              controller: _codeController,
              enabled: !locked,
            ),
          ),
        _LabeledField(
          label: 'Description',
          span: 2,
          child: AppTextField(
            controller: _descriptionController,
            enabled: !locked,
            hintText: 'Internal description for discount policy...',
            maxLines: 3,
          ),
        ),
      ],
    ),
  );

  Widget _scopeCard(DiscountsState state, bool locked) =>
      DiscountFormSectionCard(
        title: 'Scope & Value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _AdaptiveFields(
              children: <_LabeledField>[
                _LabeledField(
                  label: 'Applies To',
                  child: _SelectField(
                    key: const Key('discount-scope-field'),
                    value: _scope,
                    options: const <_SelectOption>[
                      _SelectOption('order', 'Entire Order'),
                      _SelectOption('product', 'Selected Products'),
                      _SelectOption('category', 'Selected Categories'),
                    ],
                    enabled: !locked,
                    onChanged: (value) => setState(() {
                      _scope = value;
                      if (value != 'product') _productIds.clear();
                      if (value != 'category') _categoryIds.clear();
                    }),
                  ),
                ),
                _LabeledField(
                  label: 'Value Type',
                  child: _SelectField(
                    key: const Key('discount-value-type-field'),
                    value: _valueType,
                    options: const <_SelectOption>[
                      _SelectOption('percentage', 'Percentage'),
                      _SelectOption('fixed', 'Fixed Amount'),
                    ],
                    enabled: !locked,
                    onChanged: (value) => setState(() => _valueType = value),
                  ),
                ),
                _LabeledField(
                  label: 'Value',
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
                  label: 'Min Spend (optional)',
                  child: _moneyField(
                    _minSpendController,
                    locked,
                    const Key('discount-min-spend-field'),
                    _currency(state),
                  ),
                ),
                _LabeledField(
                  label: 'Max Discount (optional)',
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
                  ? 'Quick percentage values'
                  : 'Quick fixed values',
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
                label: 'Selected Products',
                items: state.formReferences.products,
                selectedIds: _productIds,
                loading: state.isLoadingFormReferences,
                enabled: !locked,
                onChanged: (ids) => setState(() => _replace(_productIds, ids)),
              ),
            if (_scope == 'category')
              _referenceSelector(
                key: const Key('discount-categories-selector'),
                label: 'Selected Categories',
                items: state.formReferences.categories,
                selectedIds: _categoryIds,
                loading: state.isLoadingFormReferences,
                enabled: !locked,
                onChanged: (ids) => setState(() => _replace(_categoryIds, ids)),
              ),
            if (state.formReferencesErrorMessage != null)
              _ReferencesRetry(
                onRetry: () =>
                    context.read<DiscountsCubit>().loadFormReferences(),
              ),
          ],
        ),
      );

  Widget _eligibilityCard(DiscountsState state, bool locked) =>
      DiscountFormSectionCard(
        title: 'Eligibility Conditions',
        child: _AdaptiveFields(
          children: <_LabeledField>[
            _LabeledField(
              label: 'Customer Eligibility',
              child: _SelectField(
                key: const Key('discount-customer-eligibility-field'),
                value: _customerEligibilityMode,
                options: const <_SelectOption>[
                  _SelectOption('all', 'All Customers'),
                  _SelectOption('selected_groups', 'Selected Customer Groups'),
                ],
                enabled: !locked,
                onChanged: (value) => setState(() {
                  _customerEligibilityMode = value;
                  if (value == 'all') _customerGroupIds.clear();
                }),
              ),
            ),
            _LabeledField(
              label: 'Payment Methods',
              child: _SelectField(
                key: const Key('discount-payment-mode-field'),
                value: _allPaymentMethods ? 'all' : 'selected',
                options: const <_SelectOption>[
                  _SelectOption('all', 'All Payment Methods'),
                  _SelectOption('selected', 'Selected Payment Methods'),
                ],
                enabled: !locked,
                onChanged: (value) => setState(() {
                  _allPaymentMethods = value == 'all';
                  if (_allPaymentMethods) _paymentMethodIds.clear();
                }),
              ),
            ),
            _LabeledField(
              label: 'Branches',
              child: _SelectField(
                key: const Key('discount-branch-mode-field'),
                value: _appliesToAllBranches ? 'all' : 'selected',
                options: const <_SelectOption>[
                  _SelectOption('all', 'All Branches'),
                  _SelectOption('selected', 'Selected Branches'),
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
                label: 'Customer Groups',
                child: _referenceSelector(
                  key: const Key('discount-customer-groups-selector'),
                  label: 'Select Customer Groups',
                  items: state.formReferences.customerGroups,
                  selectedIds: _customerGroupIds,
                  loading: state.isLoadingFormReferences,
                  enabled: !locked,
                  onChanged: (ids) =>
                      setState(() => _replace(_customerGroupIds, ids)),
                ),
              ),
            if (!_allPaymentMethods)
              _LabeledField(
                label: 'Selected Payment Methods',
                child: _referenceSelector(
                  key: const Key('discount-payment-methods-selector'),
                  label: 'Select Payment Methods',
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
                label: 'Selected Branches',
                child: _branchSelector(state, locked),
              ),
          ],
        ),
      );

  Widget _scheduleCard(bool locked) => DiscountFormSectionCard(
    title: 'Schedule',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _FieldLabel(label: 'Active Weekdays (optional)'),
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
        ),
        const SizedBox(height: AppSpacing.lg),
        _AdaptiveFields(
          children: <_LabeledField>[
            _LabeledField(
              label: 'Start Date',
              child: _dateField(
                _startDateController,
                locked,
                const Key('discount-start-date-field'),
              ),
            ),
            _LabeledField(
              label: 'End Date',
              child: _dateField(
                _endDateController,
                locked,
                const Key('discount-end-date-field'),
              ),
            ),
            _LabeledField(
              label: 'Start Time',
              child: _timeField(
                _startTimeController,
                locked,
                const Key('discount-start-time-field'),
              ),
            ),
            _LabeledField(
              label: 'End Time',
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
          'An end time earlier than the start time is an overnight window.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    ),
  );

  Widget _usageCard(bool locked) => DiscountFormSectionCard(
    title: 'Usage Limits',
    child: _AdaptiveFields(
      children: <_LabeledField>[
        _LabeledField(
          label: 'Global Usage Limit (optional)',
          child: _integerField(
            _usageLimitController,
            locked,
            const Key('discount-usage-limit-field'),
          ),
        ),
        _LabeledField(
          label: 'Per Customer Lifetime Limit (optional)',
          child: _integerField(
            _perCustomerLimitController,
            locked,
            const Key('discount-per-customer-limit-field'),
          ),
        ),
      ],
    ),
  );

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
    hintText: 'Unlimited',
    keyboardType: TextInputType.number,
  );

  Widget _referenceSelector({
    required Key key,
    required String label,
    required List<DiscountFormReference> items,
    required Set<int> selectedIds,
    required bool loading,
    required bool enabled,
    required ValueChanged<Set<int>> onChanged,
  }) => _ReferenceSelector(
    key: key,
    label: label,
    items: items,
    selectedIds: selectedIds,
    loading: loading,
    enabled: enabled,
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
      label: 'Select Branches',
      items: branches,
      selectedIds: _branchIds,
      loading: state.isLoadingBranches,
      enabled: !locked,
      onChanged: (ids) => setState(() => _replace(_branchIds, ids)),
    );
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
              ? '${_decimal(value)}% Percentage'
              : '${_currency(state)} ${_decimal(value)} Fixed Amount',
          isReady: isReady,
          scope: _scopeLabel(_scope),
          branches: _appliesToAllBranches
              ? 'All Branches'
              : '${_branchIds.length} selected',
          schedule: _activeDays.isEmpty
              ? 'Any day'
              : '${_activeDays.length} days selected',
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
      _productIds.clear();
      _categoryIds.clear();
      _customerGroupIds.clear();
      _branchIds.clear();
      _paymentMethodIds.clear();
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
      customerEligibilityMode: _customerEligibilityMode,
      customerGroupIds: _customerEligibilityMode == 'selected_groups'
          ? _customerGroupIds.toList(growable: false)
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
        activate ? 'Discount saved and activated.' : 'Discount saved.',
      );
      context.go(AppRoutes.discounts);
    } else {
      _showMessage(cubit.state.errorMessage ?? 'Unable to save discount.');
    }
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
    final List<_FormValidationIssue> issues = <_FormValidationIssue>[];
    if (_nameController.text.trim().isEmpty) {
      issues.add(
        const _FormValidationIssue('name', 'Discount name is required.'),
      );
    }
    final double? value = _decimalValue(_valueController.text);
    if (value == null || value <= 0) {
      issues.add(
        const _FormValidationIssue('value', 'Enter a value greater than zero.'),
      );
    }
    if (_isPercentage && value != null && value > 100) {
      issues.add(
        const _FormValidationIssue(
          'value',
          'A percentage discount cannot exceed 100.',
        ),
      );
    }
    if (_applicationMode == 'code' && _nullableText(_codeController) == null) {
      issues.add(
        const _FormValidationIssue(
          'code',
          'A code is required for coupon discounts.',
        ),
      );
    }
    if (_scope == 'product' && _productIds.isEmpty) {
      issues.add(
        const _FormValidationIssue('scope', 'Select one or more products.'),
      );
    }
    if (_scope == 'category' && _categoryIds.isEmpty) {
      issues.add(
        const _FormValidationIssue('scope', 'Select one or more categories.'),
      );
    }
    if (_customerEligibilityMode == 'selected_groups' &&
        _customerGroupIds.isEmpty) {
      issues.add(
        const _FormValidationIssue(
          'customerGroups',
          'Select one or more customer groups.',
        ),
      );
    }
    if (!_appliesToAllBranches && _branchIds.isEmpty) {
      issues.add(
        const _FormValidationIssue('branches', 'Select one or more branches.'),
      );
    }
    if ((_minSpendController.text.trim().isNotEmpty &&
            _decimalValue(_minSpendController.text) == null) ||
        (_maxDiscountController.text.trim().isNotEmpty &&
            _decimalValue(_maxDiscountController.text) == null)) {
      issues.add(
        const _FormValidationIssue('money', 'Enter valid monetary amounts.'),
      );
    }
    if ((_decimalValue(_minSpendController.text) ?? 0) < 0 ||
        (_decimalValue(_maxDiscountController.text) ?? 0) < 0) {
      issues.add(
        const _FormValidationIssue(
          'money',
          'Monetary amounts cannot be negative.',
        ),
      );
    }
    if (_positiveInt(_usageLimitController.text) == null &&
        _usageLimitController.text.trim().isNotEmpty) {
      issues.add(
        const _FormValidationIssue(
          'usageLimit',
          'Usage limits must be positive whole numbers.',
        ),
      );
    }
    if (_positiveInt(_perCustomerLimitController.text) == null &&
        _perCustomerLimitController.text.trim().isNotEmpty) {
      issues.add(
        const _FormValidationIssue(
          'usageLimit',
          'Usage limits must be positive whole numbers.',
        ),
      );
    }
    final DateTime? startDate = _dateValue(_startDateController.text);
    final DateTime? endDate = _dateValue(_endDateController.text);
    if ((_startDateController.text.trim().isNotEmpty && startDate == null) ||
        (_endDateController.text.trim().isNotEmpty && endDate == null)) {
      issues.add(
        const _FormValidationIssue('startDate', 'Dates must use YYYY-MM-DD.'),
      );
    }
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      issues.add(
        const _FormValidationIssue(
          'endDate',
          'End date cannot be earlier than start date.',
        ),
      );
    }
    final bool hasStartTime = _startTimeController.text.trim().isNotEmpty;
    final bool hasEndTime = _endTimeController.text.trim().isNotEmpty;
    if (hasStartTime != hasEndTime) {
      issues.add(
        const _FormValidationIssue(
          'startTime',
          'Start time and end time must be provided together.',
        ),
      );
      issues.add(
        const _FormValidationIssue(
          'endTime',
          'Start time and end time must be provided together.',
        ),
      );
    }
    if ((hasStartTime && !_validTime(_startTimeController.text)) ||
        (hasEndTime && !_validTime(_endTimeController.text))) {
      issues.add(
        const _FormValidationIssue('startTime', 'Times must use HH:mm.'),
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
  static String _scopeLabel(String scope) => switch (scope) {
    'product' => 'Selected Products',
    'category' => 'Selected Categories',
    _ => 'Entire Order',
  };
  static String _currency(DiscountsState state) {
    for (final branch in state.branches) {
      if (branch.isActive && branch.currency.trim().isNotEmpty) {
        return branch.currency;
      }
    }
    return 'Currency';
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
            label: 'Discounts',
            onTap: () => context.go(AppRoutes.discounts),
            key: const Key('breadcrumb-discounts'),
          ),
          AppBreadcrumbItem(
            label: isEdit ? 'Edit Discount' : 'Create Discount',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        isEdit ? 'Edit Discount Policy' : 'Create Discount Policy',
        style: AppTextStyles.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Configure policy scope, eligibility, and schedule.',
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
  });
  final String label;
  final List<DiscountFormReference> items;
  final Set<int> selectedIds;
  final bool loading;
  final bool enabled;
  final ValueChanged<Set<int>> onChanged;
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
                ),
              );
              if (next != null) onChanged(next);
            },
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          loading
              ? 'Loading...'
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
  });
  final String title;
  final List<DiscountFormReference> items;
  final Set<int> initialSelection;
  @override
  State<_ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<_ReferencePicker> {
  late final Set<int> _selection = Set<int>.of(widget.initialSelection);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: widget.items.isEmpty
          ? const Text('No active options are available.')
          : ListView(
              children: widget.items
                  .map(
                    (item) => CheckboxListTile(
                      value: _selection.contains(item.id),
                      title: Text(item.name),
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
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _selection),
        child: const Text('Done'),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => DiscountFormSectionCard(
    title: 'Unable to load discount',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
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
      child: const Text('Retry loading selection options'),
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
