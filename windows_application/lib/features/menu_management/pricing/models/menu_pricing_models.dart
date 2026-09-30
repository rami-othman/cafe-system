import 'package:equatable/equatable.dart';

import '../../../pos/models/json_helpers.dart';

String _text(dynamic value) => value is String ? value : '';
String? _nullableText(dynamic value) =>
    _text(value).trim().isEmpty ? null : _text(value);
int _requiredInt(Map<String, dynamic> json, String key) =>
    readInt(json[key]) ??
    (throw FormatException('Pricing response is missing $key.'));

/// Decimal values from this API are deliberately retained as strings.  They
/// can be signed and raw calculations may have more than two decimal places.
class ExactDecimal extends Equatable {
  const ExactDecimal(this.value);
  factory ExactDecimal.fromJson(dynamic value) {
    final String text = _text(value).trim();
    if (!RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(text)) {
      throw const FormatException('Invalid pricing decimal.');
    }
    return ExactDecimal(text);
  }
  final String value;
  @override
  List<Object> get props => <Object>[value];
}

class MenuPricingContext extends Equatable {
  const MenuPricingContext({
    required this.menuId,
    required this.branchId,
    required this.channel,
    required this.currency,
  });
  factory MenuPricingContext.fromJson(Map<String, dynamic> json) =>
      MenuPricingContext(
        menuId: _requiredInt(json, 'menuId'),
        branchId: _requiredInt(json, 'branchId'),
        channel: _text(json['channel']),
        currency: _text(json['currency']),
      );
  final int menuId, branchId;
  final String channel, currency;
  @override
  List<Object> get props => <Object>[menuId, branchId, channel, currency];
}

class MenuPricingItem extends Equatable {
  const MenuPricingItem({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.productNameAr,
    required this.productNameEn,
    required this.variantName,
    required this.variantNameAr,
    required this.variantNameEn,
    required this.isDefault,
    required this.sku,
    required this.categoryId,
    required this.hasVisiblePlacement,
    required this.configuredEffectivePrice,
    required this.configuredSource,
    required this.inheritedPrice,
    required this.inheritedSource,
    required this.hasMenuOverride,
    required this.adjustable,
    required this.eligibilityReason,
    this.publishedPrice,
    this.publishedVersion,
  });
  factory MenuPricingItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> eligibility = Map<String, dynamic>.from(
      json['eligibility'] as Map? ?? const <String, dynamic>{},
    );
    final Map<String, dynamic>? published = json['published'] is Map
        ? Map<String, dynamic>.from(json['published'] as Map)
        : null;
    return MenuPricingItem(
      variantId: _requiredInt(json, 'variantId'),
      productId: _requiredInt(json, 'productId'),
      productName: _text(json['productName']),
      productNameAr: _text(json['productNameAr']),
      productNameEn: _text(json['productNameEn']),
      variantName: _text(json['variantName']),
      variantNameAr: _text(json['variantNameAr']),
      variantNameEn: _text(json['variantNameEn']),
      isDefault: json['isDefault'] == true,
      sku: _nullableText(json['sku']),
      categoryId: readInt(json['categoryId']),
      hasVisiblePlacement: json['hasVisiblePlacement'] == true,
      configuredEffectivePrice: ExactDecimal.fromJson(
        json['configuredEffectivePrice'],
      ),
      configuredSource: _text(json['configuredSource']),
      inheritedPrice: ExactDecimal.fromJson(json['inheritedPrice']),
      inheritedSource: _text(json['inheritedSource']),
      hasMenuOverride: json['hasMenuOverride'] == true,
      adjustable: eligibility['adjustable'] == true,
      eligibilityReason: _nullableText(eligibility['reason']),
      publishedPrice: published == null
          ? null
          : ExactDecimal.fromJson(published['price']),
      publishedVersion: published == null
          ? null
          : readInt(published['versionNumber']),
    );
  }
  final int variantId, productId;
  final String productName,
      productNameAr,
      productNameEn,
      variantName,
      variantNameAr,
      variantNameEn;
  final bool isDefault;
  final String? sku;
  final int? categoryId;
  final bool hasVisiblePlacement, hasMenuOverride, adjustable;
  final ExactDecimal configuredEffectivePrice, inheritedPrice;
  final String configuredSource, inheritedSource;
  final String? eligibilityReason;
  final ExactDecimal? publishedPrice;
  final int? publishedVersion;
  String localizedName(bool arabic) => arabic && productNameAr.isNotEmpty
      ? productNameAr
      : !arabic && productNameEn.isNotEmpty
      ? productNameEn
      : productName;
  String localizedVariant(bool arabic) => arabic && variantNameAr.isNotEmpty
      ? variantNameAr
      : !arabic && variantNameEn.isNotEmpty
      ? variantNameEn
      : variantName;
  @override
  List<Object?> get props => <Object?>[
    variantId,
    productId,
    productName,
    productNameAr,
    productNameEn,
    variantName,
    variantNameAr,
    variantNameEn,
    isDefault,
    sku,
    categoryId,
    hasVisiblePlacement,
    configuredEffectivePrice,
    configuredSource,
    inheritedPrice,
    inheritedSource,
    hasMenuOverride,
    adjustable,
    eligibilityReason,
    publishedPrice,
    publishedVersion,
  ];
}

class MenuPricingOverview extends Equatable {
  const MenuPricingOverview({
    required this.context,
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.adjustableVariantCount,
    required this.excludedVariantCount,
  });
  factory MenuPricingOverview.fromJson(Map<String, dynamic> json) {
    final p = Map<String, dynamic>.from(json['pagination'] as Map? ?? const {});
    final s = Map<String, dynamic>.from(json['scope'] as Map? ?? const {});
    return MenuPricingOverview(
      context: MenuPricingContext.fromJson(
        Map<String, dynamic>.from(json['context'] as Map),
      ),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MenuPricingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      page: readInt(p['page']) ?? 1,
      perPage: readInt(p['perPage']) ?? 25,
      total: readInt(p['total']) ?? 0,
      adjustableVariantCount: readInt(s['adjustableVariantCount']) ?? 0,
      excludedVariantCount: readInt(s['excludedVariantCount']) ?? 0,
    );
  }
  final MenuPricingContext context;
  final List<MenuPricingItem> items;
  final int page, perPage, total, adjustableVariantCount, excludedVariantCount;
  @override
  List<Object> get props => <Object>[
    context,
    items,
    page,
    perPage,
    total,
    adjustableVariantCount,
    excludedVariantCount,
  ];
}

enum ManualPriceAction { set, reset }

class ManualPriceDraft extends Equatable {
  const ManualPriceDraft.set(this.variantId, this.price)
    : action = ManualPriceAction.set;
  const ManualPriceDraft.reset(this.variantId)
    : action = ManualPriceAction.reset,
      price = null;
  final int variantId;
  final ManualPriceAction action;
  final String? price;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'variantId': variantId,
    'action': action.name,
    if (action == ManualPriceAction.set) 'price': price,
  };
  @override
  List<Object?> get props => <Object?>[variantId, action, price];
}
