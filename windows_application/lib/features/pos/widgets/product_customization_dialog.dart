import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/backend_product_detail.dart';
import '../models/modifier_group.dart';
import '../models/modifier_option.dart';
import '../models/pos_product.dart';
import '../models/pos_menu_runtime_models.dart';
import '../models/product_customization.dart';
import '../models/product_modifier.dart';
import '../models/selected_modifier.dart';
import 'customization_option_tile.dart';
import 'customization_quantity_panel.dart';
import 'customization_section.dart';
import 'customization_segmented_selector.dart';

class ProductCustomizationDialog extends StatefulWidget {
  const ProductCustomizationDialog({
    super.key,
    required this.product,
    this.productDetail,
    this.onSubmit,
  });

  final PosProduct product;
  final BackendProductDetail? productDetail;
  final Future<bool> Function(ProductCustomization customization)? onSubmit;

  @override
  State<ProductCustomizationDialog> createState() =>
      _ProductCustomizationDialogState();
}

class _ProductCustomizationDialogState
    extends State<ProductCustomizationDialog> {
  static const List<ProductModifierOption>
  _sizeOptions = <ProductModifierOption>[
    ProductModifierOption(id: 'small', label: 'Small (8oz)', priceDelta: -0.50),
    ProductModifierOption(id: 'medium', label: 'Medium (12oz)'),
    ProductModifierOption(id: 'large', label: 'Large (16oz)', priceDelta: 0.75),
  ];
  static const List<ProductModifierOption> _milkOptions =
      <ProductModifierOption>[
        ProductModifierOption(
          id: 'whole',
          label: 'Whole Milk',
          helperLabel: 'Default',
        ),
        ProductModifierOption(id: 'oat', label: 'Oat Milk', priceDelta: 0.75),
        ProductModifierOption(
          id: 'almond',
          label: 'Almond Milk',
          priceDelta: 0.75,
        ),
      ];
  static const List<ProductModifierOption> _addOnOptions =
      <ProductModifierOption>[
        ProductModifierOption(
          id: 'extra-espresso',
          label: 'Extra Espresso Shot',
          priceDelta: 1,
        ),
        ProductModifierOption(
          id: 'caramel',
          label: 'Caramel Syrup',
          priceDelta: 0.50,
        ),
        ProductModifierOption(
          id: 'vanilla',
          label: 'Vanilla Syrup',
          priceDelta: 0.50,
        ),
        ProductModifierOption(
          id: 'whipped-cream',
          label: 'Whipped Cream',
          priceDelta: 0.50,
        ),
      ];
  static const List<String> _sweetnessOptions = <String>[
    '0%',
    '50%',
    '100%',
    '150%',
  ];

  late final TextEditingController _instructionsController;
  int _quantity = 1;
  String _temperature = 'Hot';
  ProductModifierOption _selectedSize = _sizeOptions[1];
  ProductModifierOption _selectedMilk = _milkOptions[0];
  final Set<ProductModifierOption> _selectedAddOns = <ProductModifierOption>{};
  String _sweetness = '100%';
  final Map<int, Set<int>> _backendSelections = <int, Set<int>>{};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _instructionsController = TextEditingController();
    _initializeBackendSelections();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  ProductCustomization get _customization {
    final List<SelectedModifier> selectedModifiers = _selectedModifiers();
    final List<String> backendModifierLabels = _selectedBackendLabels();
    final bool published = widget.product.isPublishedRuntime;
    final double publishedModifierTotal = _activeDetail == null
        ? 0
        : _activeDetail!.modifierGroups.fold<double>(
            0,
            (double total, ModifierGroup group) =>
                total +
                group.options
                    .where(
                      (ModifierOption option) =>
                          _backendSelections[group.id]?.contains(option.id) ??
                          false,
                    )
                    .fold<double>(
                      0,
                      (double sum, ModifierOption option) =>
                          sum + option.priceDelta,
                    ),
          );

    return ProductCustomization(
      product: widget.product,
      quantity: _quantity,
      temperature: _temperature,
      size: _selectedSize,
      milkBase: _selectedMilk,
      addOns: _selectedAddOns.toList(growable: false),
      sweetness: _sweetness,
      specialInstructions: _instructionsController.text,
      selectedModifiers: selectedModifiers,
      backendModifierLabels: backendModifierLabels,
      publishedVariantId: published ? widget.product.defaultVariantId : null,
      publishedModifierOptionIds: published
          ? selectedModifiers
                .map((SelectedModifier modifier) => modifier.optionId)
                .toList(growable: false)
          : const <int>[],
      publishedUnitPrice: published
          ? widget.product.price + publishedModifierTotal
          : null,
    );
  }

  BackendProductDetail? get _activeDetail =>
      widget.productDetail ?? _runtimeProductDetail;

  BackendProductDetail? get _runtimeProductDetail {
    if (!widget.product.isPublishedRuntime) return null;
    final String languageCode = PlatformDispatcher.instance.locale.languageCode;
    return BackendProductDetail.fromJson(<String, dynamic>{
      'id': widget.product.backendId,
      'name': widget.product.name,
      'basePrice': widget.product.price,
      'isAvailable': widget.product.isAvailable,
      'modifierGroups': widget.product.modifierGroups
          .map(
            (PosModifierGroup group) => <String, dynamic>{
              'id': group.id,
              'name': group.name.resolve(languageCode),
              'type': group.selectionType ?? 'single',
              'required': group.isRequired,
              'minSelections': group.minSelections ?? 0,
              'maxSelections': group.maxSelections ?? 1,
              'options': group.options
                  .map(
                    (PosModifierOption option) => <String, dynamic>{
                      'id': option.id,
                      'name': option.name.resolve(languageCode),
                      'priceDelta': option.priceDelta ?? 0,
                      'isDefault': option.isDefault,
                      'isAvailable': option.isAvailable,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    });
  }

  void _initializeBackendSelections() {
    final BackendProductDetail? detail = _activeDetail;
    if (detail == null) {
      return;
    }

    for (final ModifierGroup group in detail.modifierGroups) {
      final List<ModifierOption> available = group.options
          .where((ModifierOption option) => option.isAvailable)
          .toList(growable: false);
      if (available.isEmpty) {
        _backendSelections[group.id] = <int>{};
        continue;
      }

      final Iterable<ModifierOption> defaults = available.where(
        (ModifierOption option) => option.isDefault,
      );
      if (defaults.isNotEmpty) {
        _backendSelections[group.id] = defaults
            .take(group.maxSelections <= 0 ? 1 : group.maxSelections)
            .map((ModifierOption option) => option.id)
            .toSet();
      } else if (group.required || group.minSelections > 0) {
        _backendSelections[group.id] = <int>{available.first.id};
      } else {
        _backendSelections[group.id] = <int>{};
      }
    }
  }

  List<SelectedModifier> _selectedModifiers() {
    return _backendSelections.entries
        .expand(
          (MapEntry<int, Set<int>> entry) => entry.value.map(
            (int optionId) =>
                SelectedModifier(groupId: entry.key, optionId: optionId),
          ),
        )
        .toList(growable: false);
  }

  List<String> _selectedBackendLabels() {
    final BackendProductDetail? detail = _activeDetail;
    if (detail == null) {
      return const <String>[];
    }

    final List<String> labels = <String>[];
    for (final ModifierGroup group in detail.modifierGroups) {
      final Set<int> selected = _backendSelections[group.id] ?? <int>{};
      for (final ModifierOption option in group.options) {
        if (selected.contains(option.id)) {
          labels.add(option.name);
        }
      }
    }

    return labels;
  }

  void _toggleBackendOption(ModifierGroup group, ModifierOption option) {
    if (!option.isAvailable) {
      return;
    }

    setState(() {
      final Set<int> selected = _backendSelections[group.id] ?? <int>{};
      final bool multi = group.type == 'multiple' || group.maxSelections > 1;
      if (!multi) {
        _backendSelections[group.id] = <int>{option.id};
        return;
      }

      if (selected.contains(option.id)) {
        if (!group.required || selected.length > group.minSelections) {
          selected.remove(option.id);
        }
      } else if (group.maxSelections <= 0 ||
          selected.length < group.maxSelections) {
        selected.add(option.id);
      }
      _backendSelections[group.id] = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewport) {
        final double maxWidth = (viewport.maxWidth - AppSpacing.xxl).clamp(
          280,
          AppSizes.customizationDialogWidth,
        );
        final double maxHeight = (viewport.maxHeight - AppSpacing.xxl).clamp(
          360,
          AppSizes.customizationDialogMaxHeight,
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Material(
              color: AppColors.white,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.md),
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x26000000),
                      offset: Offset(0, 16),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    _DialogHeader(onClose: () => Navigator.of(context).pop()),
                    Expanded(child: _dialogBody(customization: _customization)),
                    _DialogFooter(
                      onCancel: () => Navigator.of(context).pop(),
                      isSubmitting: _isSubmitting,
                      onAdd: _submit,
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final ProductCustomization customization = _customization;
    if (widget.onSubmit == null) {
      Navigator.of(context).pop<ProductCustomization>(customization);
      return;
    }
    setState(() => _isSubmitting = true);
    final bool succeeded = await widget.onSubmit!(customization);
    if (!mounted) return;
    if (succeeded) {
      Navigator.of(context).pop<ProductCustomization>(customization);
      return;
    }
    setState(() => _isSubmitting = false);
  }

  Widget _dialogBody({required ProductCustomization customization}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stackColumns =
            constraints.maxWidth < AppSizes.customizationDialogStackBreakpoint;
        final Widget productColumn = _ProductInfoColumn(
          product: widget.product,
          quantity: _quantity,
          total: customization.totalPrice,
          onDecrease: () {
            if (_quantity > 1) {
              setState(() => _quantity -= 1);
            }
          },
          onIncrease: () => setState(() => _quantity += 1),
        );
        final Widget modifiers = _ModifiersColumn(
          temperature: _temperature,
          selectedSize: _selectedSize,
          selectedMilk: _selectedMilk,
          selectedAddOns: _selectedAddOns,
          sweetness: _sweetness,
          instructionsController: _instructionsController,
          onTemperatureSelected: (String value) {
            setState(() => _temperature = value);
          },
          onSizeSelected: (ProductModifierOption option) {
            setState(() => _selectedSize = option);
          },
          onMilkSelected: (ProductModifierOption option) {
            setState(() => _selectedMilk = option);
          },
          onAddOnToggled: (ProductModifierOption option) {
            setState(() {
              if (_selectedAddOns.contains(option)) {
                _selectedAddOns.remove(option);
              } else {
                _selectedAddOns.add(option);
              }
            });
          },
          onSweetnessSelected: (String value) {
            setState(() => _sweetness = value);
          },
        );
        final BackendProductDetail? detail = _activeDetail;
        final Widget activeModifiers = detail == null
            ? modifiers
            : _BackendModifiersColumn(
                detail: detail,
                selections: _backendSelections,
                instructionsController: _instructionsController,
                onOptionToggled: _toggleBackendOption,
              );

        if (stackColumns) {
          return SingleChildScrollView(
            child: Column(
              children: <Widget>[
                productColumn,
                const Divider(height: 1, color: AppColors.border),
                activeModifiers,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: AppSizes.customizationDialogLeftColumnWidth,
              child: productColumn,
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: activeModifiers),
          ],
        );
      },
    );
  }

  static List<ProductModifierOption> get sizeOptions => _sizeOptions;
  static List<ProductModifierOption> get milkOptions => _milkOptions;
  static List<ProductModifierOption> get addOnOptions => _addOnOptions;
  static List<String> get sweetnessOptions => _sweetnessOptions;
}

class _BackendModifiersColumn extends StatelessWidget {
  const _BackendModifiersColumn({
    required this.detail,
    required this.selections,
    required this.instructionsController,
    required this.onOptionToggled,
  });

  final BackendProductDetail detail;
  final Map<int, Set<int>> selections;
  final TextEditingController instructionsController;
  final void Function(ModifierGroup group, ModifierOption option)
  onOptionToggled;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SingleChildScrollView(
        padding: AppSpacing.allXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final ModifierGroup group
                in detail.modifierGroups) ...<Widget>[
              CustomizationSection(
                title: group.name,
                trailing: group.required ? const _RequiredLabel() : null,
                child: _SelectionCard(
                  children: <Widget>[
                    for (final ModifierOption option in group.options)
                      _BackendOptionRow(
                        option: option,
                        isSelected:
                            selections[group.id]?.contains(option.id) ?? false,
                        isMulti:
                            group.type == 'multiple' || group.maxSelections > 1,
                        onTap: () => onOptionToggled(group, option),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
            CustomizationSection(
              title: 'Special Instructions',
              child: _InstructionsField(controller: instructionsController),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackendOptionRow extends StatelessWidget {
  const _BackendOptionRow({
    required this.option,
    required this.isSelected,
    required this.isMulti,
    required this.onTap,
  });

  final ModifierOption option;
  final bool isSelected;
  final bool isMulti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: option.isAvailable ? onTap : null,
      child: Opacity(
        opacity: option.isAvailable ? 1 : 0.45,
        child: SizedBox(
          height: AppSizes.customizationRowHeight,
          child: Padding(
            padding: AppSpacing.horizontalLg,
            child: Row(
              children: <Widget>[
                Icon(
                  isMulti
                      ? isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank
                      : isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected ? AppColors.tertiary : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _formatPriceDelta(option.priceDelta),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.customizationDialogHeaderHeight,
      padding: AppSpacing.horizontalXl,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Customize Item',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: AppColors.primary,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _ProductInfoColumn extends StatelessWidget {
  const _ProductInfoColumn({
    required this.product,
    required this.quantity,
    required this.total,
    required this.onDecrease,
    required this.onIncrease,
  });

  final PosProduct product;
  final int quantity;
  final double total;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: SingleChildScrollView(
        padding: AppSpacing.allXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: AppRadius.control,
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child:
                    product.imageUrl == null || product.imageUrl!.trim().isEmpty
                    ? Icon(
                        product.icon ?? Icons.local_cafe_outlined,
                        color: AppColors.secondary,
                        size: 72,
                      )
                    : ClipRRect(
                        borderRadius: AppRadius.control,
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) => Icon(
                                product.icon ?? Icons.local_cafe_outlined,
                                color: AppColors.secondary,
                                size: 72,
                              ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              product.name,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              product.description?.trim().isNotEmpty == true
                  ? product.description!.trim()
                  : 'A classic Italian espresso-based beverage with steamed milk and a thick layer of micro-foam.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${product.size} base - ${CurrencyFormatter.format(product.price)}',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            CustomizationQuantityPanel(
              quantity: quantity,
              total: total,
              onDecrease: onDecrease,
              onIncrease: onIncrease,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModifiersColumn extends StatelessWidget {
  const _ModifiersColumn({
    required this.temperature,
    required this.selectedSize,
    required this.selectedMilk,
    required this.selectedAddOns,
    required this.sweetness,
    required this.instructionsController,
    required this.onTemperatureSelected,
    required this.onSizeSelected,
    required this.onMilkSelected,
    required this.onAddOnToggled,
    required this.onSweetnessSelected,
  });

  final String temperature;
  final ProductModifierOption selectedSize;
  final ProductModifierOption selectedMilk;
  final Set<ProductModifierOption> selectedAddOns;
  final String sweetness;
  final TextEditingController instructionsController;
  final ValueChanged<String> onTemperatureSelected;
  final ValueChanged<ProductModifierOption> onSizeSelected;
  final ValueChanged<ProductModifierOption> onMilkSelected;
  final ValueChanged<ProductModifierOption> onAddOnToggled;
  final ValueChanged<String> onSweetnessSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SingleChildScrollView(
        padding: AppSpacing.allXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CustomizationSection(
              title: 'Temperature',
              child: _ResponsiveOptionGrid(
                itemCount: 2,
                minTileWidth: 160,
                itemBuilder: (BuildContext context, int index) {
                  final String option = index == 0 ? 'Hot' : 'Iced';
                  return CustomizationOptionTile(
                    label: option,
                    icon: index == 0
                        ? Icons.local_fire_department_outlined
                        : Icons.ac_unit_outlined,
                    isSelected: option == temperature,
                    onTap: () => onTemperatureSelected(option),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            CustomizationSection(
              title: 'Size',
              trailing: const _RequiredLabel(),
              child: _SelectionCard(
                children: <Widget>[
                  for (final ProductModifierOption option
                      in _ProductCustomizationDialogState.sizeOptions)
                    _SingleSelectRow(
                      option: option,
                      isSelected: option == selectedSize,
                      onTap: () => onSizeSelected(option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            CustomizationSection(
              title: 'Milk Base',
              child: _ResponsiveOptionGrid(
                itemCount: _ProductCustomizationDialogState.milkOptions.length,
                minTileWidth: 120,
                itemBuilder: (BuildContext context, int index) {
                  final ProductModifierOption option =
                      _ProductCustomizationDialogState.milkOptions[index];
                  return CustomizationOptionTile(
                    label: option.label,
                    helperLabel:
                        option.helperLabel ??
                        _formatPriceDelta(option.priceDelta),
                    isSelected: option == selectedMilk,
                    onTap: () => onMilkSelected(option),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            CustomizationSection(
              title: 'Add-ons',
              child: _SelectionCard(
                children: <Widget>[
                  for (final ProductModifierOption option
                      in _ProductCustomizationDialogState.addOnOptions)
                    _MultiSelectRow(
                      option: option,
                      isSelected: selectedAddOns.contains(option),
                      onTap: () => onAddOnToggled(option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            CustomizationSection(
              title: 'Sweetness',
              child: CustomizationSegmentedSelector(
                options: _ProductCustomizationDialogState.sweetnessOptions,
                selectedOption: sweetness,
                onSelected: onSweetnessSelected,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            CustomizationSection(
              title: 'Special Instructions',
              child: _InstructionsField(controller: instructionsController),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveOptionGrid extends StatelessWidget {
  const _ResponsiveOptionGrid({
    required this.itemCount,
    required this.minTileWidth,
    required this.itemBuilder,
  });

  final int itemCount;
  final double minTileWidth;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = (constraints.maxWidth / minTileWidth).floor().clamp(
          1,
          itemCount,
        );

        return GridView.builder(
          itemCount: itemCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: AppSizes.customizationOptionHeight,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) const Divider(height: 1, color: AppColors.border),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _SingleSelectRow extends StatelessWidget {
  const _SingleSelectRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ProductModifierOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppSizes.customizationRowHeight,
        child: Padding(
          padding: AppSpacing.horizontalLg,
          child: Row(
            children: <Widget>[
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? AppColors.tertiary : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatPriceDelta(option.priceDelta),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiSelectRow extends StatelessWidget {
  const _MultiSelectRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ProductModifierOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppSizes.customizationRowHeight,
        child: Padding(
          padding: AppSpacing.horizontalLg,
          child: Row(
            children: <Widget>[
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: AppColors.tertiary,
                side: const BorderSide(color: AppColors.border),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatPriceDelta(option.priceDelta),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionsField extends StatelessWidget {
  const _InstructionsField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.customizationInstructionsHeight,
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.control,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        cursorColor: AppColors.primary,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isCollapsed: true,
          hintText: 'E.g., Extra hot, in a to-go cup...',
          hintStyle: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Required',
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.tertiary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.onCancel,
    required this.onAdd,
    required this.isSubmitting,
  });

  final VoidCallback onCancel;
  final VoidCallback onAdd;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel',
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          FilledButton.icon(
            onPressed: isSubmitting ? null : onAdd,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shopping_cart_outlined),
            label: Text(isSubmitting ? 'Adding...' : 'Add to Order'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppSizes.buttonHeight),
              backgroundColor: AppColors.tertiary,
              foregroundColor: AppColors.white,
              textStyle: AppTextStyles.buttonLarge,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.control,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPriceDelta(double amount) {
  if (amount == 0) {
    return CurrencyFormatter.format(0);
  }

  final String formatted = CurrencyFormatter.format(amount.abs());
  return amount > 0 ? '+$formatted' : '-$formatted';
}
