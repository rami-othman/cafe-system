import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../widgets/discount_bottom_action_bar.dart';
import '../widgets/discount_chip_selector.dart';
import '../widgets/discount_form_section_card.dart';
import '../widgets/discount_pos_preview_card.dart';
import '../widgets/discount_summary_panel.dart';
import '../widgets/discount_toggle_row.dart';

class CreateDiscountPolicyScreen extends StatefulWidget {
  const CreateDiscountPolicyScreen({super.key});

  @override
  State<CreateDiscountPolicyScreen> createState() =>
      _CreateDiscountPolicyScreenState();
}

class _CreateDiscountPolicyScreenState
    extends State<CreateDiscountPolicyScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: 'Morning Coffee Happy Hour',
  );
  final TextEditingController _codeController = TextEditingController(
    text: 'COFFEE20',
  );
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _minSpendController = TextEditingController();
  final TextEditingController _maxDiscountController = TextEditingController();
  final TextEditingController _minimumOrderController = TextEditingController();
  final TextEditingController _maximumApprovalController =
      TextEditingController(text: '50.00');

  bool _active = true;
  String _discountMode = 'Auto';
  String _appliesTo = 'Entire Order';
  String _valueType = 'Percentage';
  int _discountPercent = 10;
  String _customerGroup = 'All Customers';
  String _paymentMethod = 'Any Payment Method';
  String _branchCondition = 'All Branches & Channels';
  final Set<String> _selectedDays = <String>{'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  final Set<String> _approvalLevels = <String>{'Manager', 'Admin'};
  final Set<String> _ruleTargets = <String>{'Category', 'Day/Hour'};
  bool _requireManagerApproval = false;
  bool _managerPinRequired = true;
  bool _visibleToCashiers = true;
  bool _combineDiscounts = false;
  bool _combineCoupons = false;
  bool _combineLoyalty = false;
  bool _combineManualDiscounts = true;
  final Map<String, bool> _reportFlags = <String, bool>{
    'Track by cashier': true,
    'Track by branch': true,
    'Include in daily report': true,
    'Require approval note': false,
    'Track by reason': true,
    'Include in discount export': true,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _minSpendController.dispose();
    _maxDiscountController.dispose();
    _minimumOrderController.dispose();
    _maximumApprovalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    const _PageHeading(),
                    const SizedBox(height: AppSpacing.xl),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool useColumns =
                                constraints.maxWidth >=
                                AppSizes.createProductTwoColumnBreakpoint;
                            final Widget form = _buildForm();
                            final Widget sideRail = _buildSideRail();

                            if (!useColumns) {
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
          onDiscard: _discardChanges,
          onSaveDraft: () => _showMessage('Discount draft saved locally.'),
          onActivate: () =>
              _showMessage('Discount activation is a UI placeholder.'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: <Widget>[
        DiscountFormSectionCard(
          title: 'Basic Information',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Active', style: AppTextStyles.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              Switch(
                value: _active,
                onChanged: (bool value) => setState(() => _active = value),
              ),
            ],
          ),
          child: _AdaptiveFields(
            children: <_LabeledField>[
              _LabeledField(
                label: 'Discount Name',
                child: AppTextField(controller: _nameController),
              ),
              _LabeledField(
                label: 'Discount Code',
                child: AppTextField(controller: _codeController),
              ),
              _LabeledField(
                label: 'Discount Mode',
                child: _SelectField(
                  value: _discountMode,
                  options: const <String>['Auto', 'Manual', 'Code'],
                  onChanged: (String value) {
                    setState(() => _discountMode = value);
                  },
                ),
              ),
              _LabeledField(
                label: 'Description',
                span: 2,
                child: AppTextField(
                  controller: _descriptionController,
                  hintText: 'Internal description for discount policy...',
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
                      value: _appliesTo,
                      options: const <String>[
                        'Entire Order',
                        'Selected Items',
                        'Categories',
                      ],
                      onChanged: (String value) {
                        setState(() => _appliesTo = value);
                      },
                    ),
                  ),
                  _LabeledField(
                    label: 'Value Type',
                    child: _SelectField(
                      value: _valueType,
                      options: const <String>['Percentage', 'Fixed Amount'],
                      onChanged: (String value) {
                        setState(() => _valueType = value);
                      },
                    ),
                  ),
                  _LabeledField(
                    label: 'Value',
                    child: DiscountChipSelector(
                      options: const <String>['10%', '15%', '20%'],
                      selected: <String>{'$_discountPercent%'},
                      multiSelect: false,
                      onSelected: (String value) {
                        setState(() {
                          _discountPercent = int.parse(
                            value.replaceAll('%', ''),
                          );
                        });
                      },
                    ),
                  ),
                  _LabeledField(
                    label: 'Min Spend (optional)',
                    child: AppTextField(
                      controller: _minSpendController,
                      hintText: 'SAR 0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  _LabeledField(
                    label: 'Max Discount (optional)',
                    child: AppTextField(
                      controller: _maxDiscountController,
                      hintText: 'SAR 0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _InfoBox(
                icon: Icons.info_outline,
                message:
                    'The configured percentage applies before VAT and respects optional limits.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscountFormSectionCard(
          title: 'Eligibility Conditions',
          child: _AdaptiveFields(
            children: <_LabeledField>[
              _LabeledField(
                label: 'Customer Group / Type',
                child: _SelectField(
                  value: _customerGroup,
                  options: const <String>[
                    'All Customers',
                    'Regular',
                    'VIP',
                    'New Customers',
                  ],
                  onChanged: (String value) {
                    setState(() => _customerGroup = value);
                  },
                ),
              ),
              _LabeledField(
                label: 'Minimum Order Amount',
                child: AppTextField(
                  controller: _minimumOrderController,
                  hintText: 'SAR 0.00',
                ),
              ),
              _LabeledField(
                label: 'Payment Method',
                child: _SelectField(
                  value: _paymentMethod,
                  options: const <String>[
                    'Any Payment Method',
                    'Cash',
                    'Card',
                    'Wallet',
                  ],
                  onChanged: (String value) {
                    setState(() => _paymentMethod = value);
                  },
                ),
              ),
              _LabeledField(
                label: 'Branch / Channel',
                child: _SelectField(
                  value: _branchCondition,
                  options: const <String>[
                    'All Branches & Channels',
                    'Downtown POS',
                    'Mall POS',
                    'Airport POS',
                  ],
                  onChanged: (String value) {
                    setState(() => _branchCondition = value);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscountFormSectionCard(
          title: 'Schedule',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _FieldLabel(label: 'Active Days'),
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
                selected: _selectedDays,
                onSelected: (String value) {
                  setState(() {
                    _selectedDays.contains(value)
                        ? _selectedDays.remove(value)
                        : _selectedDays.add(value);
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const _AdaptiveFields(
                children: <_LabeledField>[
                  _LabeledField(
                    label: 'From',
                    child: _StaticInput(value: '06:00 AM'),
                  ),
                  _LabeledField(
                    label: 'To',
                    child: _StaticInput(value: '10:00 AM'),
                  ),
                  _LabeledField(
                    label: 'Start Date',
                    child: _StaticInput(value: 'Jul 06, 2026'),
                  ),
                  _LabeledField(
                    label: 'End Date',
                    child: _StaticInput(value: 'No end date'),
                  ),
                  _LabeledField(
                    label: 'Usage Limit',
                    child: _StaticInput(value: 'Unlimited'),
                  ),
                  _LabeledField(
                    label: 'Per Customer / Day',
                    child: _StaticInput(value: '1'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscountFormSectionCard(
          title: 'Approval & Permissions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _FieldLabel(label: 'Approval Levels'),
              const SizedBox(height: AppSpacing.sm),
              DiscountChipSelector(
                options: const <String>[
                  'Cashier',
                  'Supervisor',
                  'Manager',
                  'Admin',
                ],
                selected: _approvalLevels,
                onSelected: (String value) {
                  setState(() {
                    _approvalLevels.contains(value)
                        ? _approvalLevels.remove(value)
                        : _approvalLevels.add(value);
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DiscountToggleRow(
                title: 'Require manager approval',
                subtitle:
                    'A manager must approve this policy when it is applied.',
                value: _requireManagerApproval,
                onChanged: (bool value) {
                  setState(() => _requireManagerApproval = value);
                },
              ),
              _LabeledField(
                label: 'Maximum Discount Amount Without Approval',
                child: AppTextField(
                  controller: _maximumApprovalController,
                  prefixText: 'SAR  ',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              DiscountToggleRow(
                title: 'Manager PIN required',
                value: _managerPinRequired,
                onChanged: (bool value) {
                  setState(() => _managerPinRequired = value);
                },
              ),
              DiscountToggleRow(
                title: 'Visible to cashier role',
                value: _visibleToCashiers,
                onChanged: (bool value) {
                  setState(() => _visibleToCashiers = value);
                },
              ),
              const _InfoBox(
                icon: Icons.warning_amber,
                message:
                    'Final permission enforcement will be added with the discount engine.',
                warning: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscountFormSectionCard(
          title: 'Discount Rules',
          trailing: Switch(
            value: true,
            onChanged: (_) =>
                _showMessage('Rule activation is a UI placeholder.'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DiscountChipSelector(
                options: const <String>[
                  'Category',
                  'Product',
                  'Customer',
                  'Payment',
                  'Day/Hour',
                ],
                selected: _ruleTargets,
                onSelected: (String value) {
                  setState(() {
                    _ruleTargets.contains(value)
                        ? _ruleTargets.remove(value)
                        : _ruleTargets.add(value);
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Add Condition Rule',
                icon: Icons.add,
                variant: AppButtonVariant.outlined,
                onPressed: () =>
                    _showMessage('Rule builder will be added later.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscountFormSectionCard(
          title: 'Stacking Rules',
          child: Column(
            children: <Widget>[
              DiscountToggleRow(
                title: 'Combine with other discounts',
                value: _combineDiscounts,
                onChanged: (bool value) {
                  setState(() => _combineDiscounts = value);
                },
              ),
              DiscountToggleRow(
                title: 'Combine with coupons',
                value: _combineCoupons,
                onChanged: (bool value) {
                  setState(() => _combineCoupons = value);
                },
              ),
              DiscountToggleRow(
                title: 'Combine with loyalty rewards',
                value: _combineLoyalty,
                onChanged: (bool value) {
                  setState(() => _combineLoyalty = value);
                },
              ),
              DiscountToggleRow(
                title: 'Combine with manually applied discounts',
                value: _combineManualDiscounts,
                onChanged: (bool value) {
                  setState(() => _combineManualDiscounts = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              const _LabeledField(
                label: 'Stacking Priority',
                child: _StaticInput(value: '10 · Standard priority'),
              ),
              const SizedBox(height: AppSpacing.md),
              const _InfoBox(
                icon: Icons.warning_amber,
                message:
                    'Higher-priority policies are evaluated first when stacking is enabled.',
                warning: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DiscountFormSectionCard(
          title: 'Reports & Audit',
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double itemWidth =
                  constraints.maxWidth >=
                      AppSizes.createProductFieldRowBreakpoint
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: _reportFlags.entries.map((
                  MapEntry<String, bool> entry,
                ) {
                  return SizedBox(
                    width: itemWidth,
                    child: CheckboxListTile(
                      value: entry.value,
                      onChanged: (bool? value) {
                        setState(
                          () => _reportFlags[entry.key] = value ?? false,
                        );
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(entry.key, style: AppTextStyles.bodySmall),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSideRail() {
    final bool allowsStacking =
        _combineDiscounts ||
        _combineCoupons ||
        _combineLoyalty ||
        _combineManualDiscounts;
    return Column(
      children: <Widget>[
        DiscountPosPreviewCard(discountPercent: _discountPercent),
        const SizedBox(height: AppSpacing.lg),
        DiscountSummaryPanel(
          value: '$_discountPercent% $_valueType',
          active: _active,
          schedule: _selectedDays.length == 7
              ? 'Every day'
              : '${_selectedDays.length} days selected',
          requiresApproval: _requireManagerApproval,
          allowsStacking: allowsStacking,
          auditEnabled: _reportFlags.values.any((bool value) => value),
        ),
      ],
    );
  }

  void _discardChanges() {
    _nameController.text = 'Morning Coffee Happy Hour';
    _codeController.text = 'COFFEE20';
    _descriptionController.clear();
    _minSpendController.clear();
    _maxDiscountController.clear();
    _minimumOrderController.clear();
    _maximumApprovalController.text = '50.00';
    setState(() {
      _active = true;
      _discountMode = 'Auto';
      _appliesTo = 'Entire Order';
      _valueType = 'Percentage';
      _discountPercent = 10;
      _customerGroup = 'All Customers';
      _paymentMethod = 'Any Payment Method';
      _branchCondition = 'All Branches & Channels';
      _selectedDays
        ..clear()
        ..addAll(<String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
      _approvalLevels
        ..clear()
        ..addAll(<String>['Manager', 'Admin']);
      _ruleTargets
        ..clear()
        ..addAll(<String>['Category', 'Day/Hour']);
      _requireManagerApproval = false;
      _managerPinRequired = true;
      _visibleToCashiers = true;
      _combineDiscounts = false;
      _combineCoupons = false;
      _combineLoyalty = false;
      _combineManualDiscounts = true;
      _reportFlags
        ..clear()
        ..addAll(<String, bool>{
          'Track by cashier': true,
          'Track by branch': true,
          'Include in daily report': true,
          'Require approval note': false,
          'Track by reason': true,
          'Include in discount export': true,
        });
    });
    _showMessage('Changes discarded.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Discount Management',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Create Discount Policy', style: AppTextStyles.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Configure policy scope, eligibility, schedule, and approvals.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _AdaptiveFields extends StatelessWidget {
  const _AdaptiveFields({required this.children});

  final List<_LabeledField> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useColumns =
            constraints.maxWidth >= AppSizes.createProductFieldRowBreakpoint;
        final double columnWidth = useColumns
            ? (constraints.maxWidth - AppSpacing.lg) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: children.map((_LabeledField field) {
            return SizedBox(
              width: useColumns && field.span == 2
                  ? constraints.maxWidth
                  : columnWidth,
              child: field,
            );
          }).toList(),
        );
      },
    );
  }
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label: label),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: options
          .map(
            (String option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(),
      onChanged: (String? value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _StaticInput extends StatelessWidget {
  const _StaticInput({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.inputHeight,
      padding: AppSpacing.horizontalMd,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.control,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(value, style: AppTextStyles.bodySmall),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final Color background = warning
        ? AppColors.discountOrangeBadge
        : AppColors.discountBlueBadge;
    final Color foreground = warning
        ? AppColors.discountOrangeText
        : AppColors.discountBlueText;

    return Container(
      width: double.infinity,
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: foreground,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
