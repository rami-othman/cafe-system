import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/menu_enums.dart';
import '../widgets/channel_visibility_tile.dart';
import '../widgets/menu_bottom_action_bar.dart';
import '../widgets/menu_form_section_card.dart';
import '../widgets/product_summary_panel.dart';
import '../widgets/product_type_selector.dart';

class CreateEditProductScreen extends StatefulWidget {
  const CreateEditProductScreen({super.key});

  @override
  State<CreateEditProductScreen> createState() =>
      _CreateEditProductScreenState();
}

class _CreateEditProductScreenState extends State<CreateEditProductScreen> {
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _arabicNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _skuController = TextEditingController(
    text: 'BEV-HOT-001',
  );
  final TextEditingController _basePriceController = TextEditingController(
    text: '0.00',
  );

  String? _category;
  ProductType _productType = ProductType.simple;
  bool _taxable = true;
  bool _dineInVisible = true;
  bool _takeawayVisible = true;
  bool _deliveryVisible = false;

  @override
  void dispose() {
    _productNameController.dispose();
    _arabicNameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _basePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSizes.createProductContentBottomPadding,
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
                      const SizedBox(height: AppSpacing.md),
                      LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final Widget form = _buildForm();
                              const Widget summary = ProductSummaryPanel();

                              if (constraints.maxWidth <
                                  AppSizes.createProductTwoColumnBreakpoint) {
                                return Column(
                                  children: <Widget>[
                                    form,
                                    const SizedBox(height: AppSpacing.lg),
                                    summary,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(child: form),
                                  const SizedBox(width: AppSpacing.lg),
                                  const SizedBox(
                                    width: AppSizes.createProductSummaryWidth,
                                    child: summary,
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
          MenuBottomActionBar(
            onDiscard: _discardChanges,
            onSaveDraft: () => _showPlaceholderMessage(
              'Draft saving will be connected in a future task.',
            ),
            onSaveAndContinue: () => _showPlaceholderMessage(
              'Save and continue will be connected in a future task.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: <Widget>[
        MenuFormSectionCard(
          title: 'Basic Details',
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool useRow =
                  constraints.maxWidth >=
                  AppSizes.createProductFieldRowBreakpoint;
              return Column(
                children: <Widget>[
                  _ResponsiveFieldPair(
                    useRow: useRow,
                    first: _LabeledField(
                      label: 'Product Name',
                      required: true,
                      child: AppTextField(
                        controller: _productNameController,
                        hintText: 'e.g. Caramel Macchiato',
                      ),
                    ),
                    second: _LabeledField(
                      label: 'Arabic Name',
                      child: AppTextField(
                        controller: _arabicNameController,
                        hintText: 'ميكاتو كراميل',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _LabeledField(
                    label: 'Description',
                    child: AppTextField(
                      controller: _descriptionController,
                      hintText:
                          'Brief description for POS and digital menus...',
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: useRow
                          ? (constraints.maxWidth - AppSpacing.lg) / 2
                          : double.infinity,
                      child: _LabeledField(
                        label: 'Product SKU',
                        required: true,
                        child: AppTextField(
                          controller: _skuController,
                          suffixIcon: Icons.refresh,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MenuFormSectionCard(
          title: 'Classification',
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return _ResponsiveFieldPair(
                useRow:
                    constraints.maxWidth >=
                    AppSizes.createProductFieldRowBreakpoint,
                first: _LabeledField(
                  label: 'Category',
                  required: true,
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    hint: const Text('Select Category'),
                    isExpanded: true,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'Hot Beverages',
                        child: Text('Hot Beverages'),
                      ),
                      DropdownMenuItem(
                        value: 'Cold Beverages',
                        child: Text('Cold Beverages'),
                      ),
                      DropdownMenuItem(value: 'Bakery', child: Text('Bakery')),
                    ],
                    onChanged: (String? value) {
                      setState(() => _category = value);
                    },
                  ),
                ),
                second: _LabeledField(
                  label: 'Product Type',
                  child: ProductTypeSelector(
                    value: _productType,
                    onChanged: (ProductType value) {
                      setState(() => _productType = value);
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MenuFormSectionCard(
          title: 'Pricing & Tax',
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return _ResponsiveFieldPair(
                useRow:
                    constraints.maxWidth >=
                    AppSizes.createProductFieldRowBreakpoint,
                first: _LabeledField(
                  label: 'Base Price',
                  required: true,
                  child: AppTextField(
                    controller: _basePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixText: 'SAR  ',
                    textAlign: TextAlign.right,
                  ),
                ),
                second: _TaxableToggle(
                  value: _taxable,
                  onChanged: (bool value) {
                    setState(() => _taxable = value);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MenuFormSectionCard(
          title: 'Channel Visibility',
          child: Column(
            children: <Widget>[
              ChannelVisibilityTile(
                icon: Icons.storefront_outlined,
                title: 'Dine-in / POS',
                helperText: 'Available for order at the counter',
                value: _dineInVisible,
                onChanged: (bool value) {
                  setState(() => _dineInVisible = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ChannelVisibilityTile(
                icon: Icons.shopping_bag_outlined,
                title: 'Takeaway App',
                helperText: 'Available for pickup orders',
                value: _takeawayVisible,
                onChanged: (bool value) {
                  setState(() => _takeawayVisible = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ChannelVisibilityTile(
                icon: Icons.delivery_dining_outlined,
                title: 'Delivery Partners',
                helperText: 'Available on aggregated delivery apps',
                value: _deliveryVisible,
                onChanged: (bool value) {
                  setState(() => _deliveryVisible = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _discardChanges() {
    _productNameController.clear();
    _arabicNameController.clear();
    _descriptionController.clear();
    _skuController.text = 'BEV-HOT-001';
    _basePriceController.text = '0.00';
    setState(() {
      _category = null;
      _productType = ProductType.simple;
      _taxable = true;
      _dineInVisible = true;
      _takeawayVisible = true;
      _deliveryVisible = false;
    });
    _showPlaceholderMessage('Changes discarded.');
  }

  void _showPlaceholderMessage(String message) {
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
        AppBreadcrumbs(
          items: <AppBreadcrumbItem>[
            AppBreadcrumbItem(
              key: const Key('breadcrumb-menu'),
              label: 'Menu',
              onTap: () => context.go(AppRoutes.menu),
            ),
            AppBreadcrumbItem(
              key: const Key('breadcrumb-products'),
              label: 'Products',
              onTap: () => context.go(AppRoutes.menuProducts),
            ),
            const AppBreadcrumbItem(label: 'Create New Product'),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('General Information', style: AppTextStyles.headlineMedium),
      ],
    );
  }
}

class _ResponsiveFieldPair extends StatelessWidget {
  const _ResponsiveFieldPair({
    required this.useRow,
    required this.first,
    required this.second,
  });

  final bool useRow;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (!useRow) {
      return Column(
        children: <Widget>[
          first,
          const SizedBox(height: AppSpacing.lg),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: first),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: second),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            text: label,
            children: required
                ? const <InlineSpan>[
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Color(0xFFC2410C)),
                    ),
                  ]
                : null,
          ),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _TaxableToggle extends StatelessWidget {
  const _TaxableToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Taxable Item', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Apply standard VAT (15%)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
