import 'package:equatable/equatable.dart';
import '../../../pos/models/json_helpers.dart';
import 'menu_pricing_models.dart';

class MenuPriceAdjustmentItem extends Equatable {
  const MenuPriceAdjustmentItem({
    required this.variantId,
    required this.productName,
    required this.productNameAr,
    required this.productNameEn,
    required this.variantName,
    required this.variantNameAr,
    required this.variantNameEn,
    required this.action,
    required this.originalEffectivePrice,
    required this.originalSource,
    required this.rawCalculatedPrice,
    required this.finalNewPrice,
    required this.finalSource,
    required this.difference,
    required this.finalMovement,
    required this.oppositeDirection,
    required this.configurationEffect,
    required this.hadMenuOverride,
  });
  factory MenuPriceAdjustmentItem.fromJson(Map<String, dynamic> j) =>
      MenuPriceAdjustmentItem(
        variantId: readInt(j['variantId']) ?? 0,
        productName: j['productName'] as String? ?? '',
        productNameAr: j['productNameAr'] as String? ?? '',
        productNameEn: j['productNameEn'] as String? ?? '',
        variantName: j['variantName'] as String? ?? '',
        variantNameAr: j['variantNameAr'] as String? ?? '',
        variantNameEn: j['variantNameEn'] as String? ?? '',
        action: j['action'] as String? ?? '',
        originalEffectivePrice: ExactDecimal.fromJson(
          j['originalEffectivePrice'],
        ),
        originalSource: j['originalSource'] as String? ?? '',
        rawCalculatedPrice: j['rawCalculatedPrice'] == null
            ? null
            : ExactDecimal.fromJson(j['rawCalculatedPrice']),
        finalNewPrice: ExactDecimal.fromJson(j['finalNewPrice']),
        finalSource: j['finalSource'] as String? ?? '',
        difference: ExactDecimal.fromJson(j['difference']),
        finalMovement: j['finalMovement'] as String? ?? '',
        oppositeDirection: j['oppositeDirection'] == true,
        configurationEffect: j['configurationEffect'] as String? ?? '',
        hadMenuOverride: j['hadMenuOverride'] == true,
      );
  final int variantId;
  final String productName,
      productNameAr,
      productNameEn,
      variantName,
      variantNameAr,
      variantNameEn,
      action,
      originalSource,
      finalSource,
      finalMovement,
      configurationEffect;
  final ExactDecimal originalEffectivePrice, finalNewPrice, difference;
  final ExactDecimal? rawCalculatedPrice;
  final bool oppositeDirection;
  final bool hadMenuOverride;
  @override
  List<Object?> get props => <Object?>[
    variantId,
    productName,
    productNameAr,
    productNameEn,
    variantName,
    variantNameAr,
    variantNameEn,
    action,
    originalEffectivePrice,
    originalSource,
    rawCalculatedPrice,
    finalNewPrice,
    finalSource,
    difference,
    finalMovement,
    oppositeDirection,
    configurationEffect,
    hadMenuOverride,
  ];
}

class MenuPriceAdjustment extends Equatable {
  const MenuPriceAdjustment({
    required this.id,
    required this.status,
    required this.fingerprint,
    required this.context,
    required this.operation,
    required this.amount,
    required this.roundingMode,
    required this.roundingStep,
    required this.summary,
    required this.items,
  });
  factory MenuPriceAdjustment.fromJson(Map<String, dynamic> j) =>
      MenuPriceAdjustment(
        id: readInt(j['id']) ?? 0,
        status: j['status'] as String? ?? '',
        fingerprint: j['fingerprint'] as String? ?? '',
        context: _context(Map<String, dynamic>.from(j['context'] as Map)),
        operation: j['operation'] as String? ?? '',
        amount: j['amount'] as String?,
        roundingMode: j['roundingMode'] as String? ?? '',
        roundingStep: j['roundingStep'] as String?,
        summary: Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
        ),
        items: (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) => MenuPriceAdjustmentItem.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false),
      );
  static MenuPricingContext _context(Map<String, dynamic> j) =>
      MenuPricingContext(
        menuId: readInt(j['menuId']) ?? 0,
        branchId: readInt(j['branchId']) ?? 0,
        channel: j['channel'] as String? ?? '',
        currency: '',
      );
  final int id;
  final String status, fingerprint, operation, roundingMode;
  final MenuPricingContext context;
  final String? amount, roundingStep;
  final Map<String, dynamic> summary;
  final List<MenuPriceAdjustmentItem> items;
  int get oppositeDirectionCount =>
      readInt(summary['oppositeDirectionCount']) ?? 0;
  bool get isApplyCandidate => status == 'previewed';
  @override
  List<Object?> get props => <Object?>[
    id,
    status,
    fingerprint,
    context,
    operation,
    amount,
    roundingMode,
    roundingStep,
    summary,
    items,
  ];
}
