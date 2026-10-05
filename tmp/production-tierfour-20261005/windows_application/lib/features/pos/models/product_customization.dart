import 'package:equatable/equatable.dart';

import 'pos_product.dart';
import 'cart_configuration.dart';
import 'product_modifier.dart';
import 'selected_modifier.dart';

class ProductCustomization extends Equatable {
  const ProductCustomization({
    required this.product,
    required this.quantity,
    required this.temperature,
    required this.size,
    required this.milkBase,
    required this.addOns,
    required this.sweetness,
    required this.specialInstructions,
    this.selectedModifiers = const <SelectedModifier>[],
    this.backendModifierLabels = const <String>[],
    this.publishedVariantId,
    this.publishedModifierOptionIds = const <int>[],
    this.publishedUnitPrice,
  });

  final PosProduct product;
  final int quantity;
  final String temperature;
  final ProductModifierOption size;
  final ProductModifierOption milkBase;
  final List<ProductModifierOption> addOns;
  final String sweetness;
  final String specialInstructions;
  final List<SelectedModifier> selectedModifiers;
  final List<String> backendModifierLabels;
  final int? publishedVariantId;
  final List<int> publishedModifierOptionIds;
  final double? publishedUnitPrice;

  bool get isPublishedRuntime =>
      product.isPublishedRuntime && publishedVariantId != null;

  double get unitPrice {
    if (publishedUnitPrice != null) return publishedUnitPrice!;
    final double addOnsTotal = addOns.fold<double>(
      0,
      (double total, ProductModifierOption option) => total + option.priceDelta,
    );
    final double price =
        product.price + size.priceDelta + milkBase.priceDelta + addOnsTotal;

    return price < 0 ? 0 : price;
  }

  double get totalPrice => unitPrice * quantity;

  List<String> get modifierLabels {
    if (backendModifierLabels.isNotEmpty) {
      return <String>[
        ...backendModifierLabels,
        if (specialInstructions.trim().isNotEmpty) specialInstructions.trim(),
      ];
    }

    return <String>[
      temperature,
      size.label,
      milkBase.label,
      ...addOns.map((ProductModifierOption option) => option.label),
      sweetness,
      if (specialInstructions.trim().isNotEmpty) specialInstructions.trim(),
    ];
  }

  String get configurationKey {
    if (isPublishedRuntime) {
      final List<int> options = List<int>.of(publishedModifierOptionIds)
        ..sort();
      return <Object?>[
        product.publishedMenuVersionId,
        product.placementId,
        product.backendId,
        publishedVariantId,
        options.join('+'),
        specialInstructions.trim(),
      ].join('|');
    }
    final String? backendKey = backendConfigurationKey;
    if (backendKey != null) {
      return backendKey;
    }

    final List<String> addOnIds =
        addOns
            .map((ProductModifierOption option) => option.id)
            .toList(growable: false)
          ..sort();

    return <String>[
      product.id,
      temperature,
      size.id,
      milkBase.id,
      addOnIds.join('+'),
      sweetness,
      specialInstructions.trim(),
    ].join('|');
  }

  String? get backendConfigurationKey {
    final int? productId = product.backendId;
    if (productId == null ||
        !CartConfiguration.hasCompleteModifierIdentity(selectedModifiers)) {
      return null;
    }
    return CartConfiguration.build(
      productId: productId,
      modifiers: selectedModifiers,
      specialInstructions: specialInstructions,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    product,
    quantity,
    temperature,
    size,
    milkBase,
    addOns,
    sweetness,
    specialInstructions,
    selectedModifiers,
    backendModifierLabels,
    publishedVariantId,
    publishedModifierOptionIds,
    publishedUnitPrice,
  ];
}
