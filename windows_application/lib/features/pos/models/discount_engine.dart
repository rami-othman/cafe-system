import 'package:equatable/equatable.dart';

Map<String, dynamic> engineMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> engineList(dynamic value) =>
    (value as List? ?? []).map(engineMap).toList(growable: false);

/// New monetary DTOs stay decimal strings, including at the display boundary.
String exactMoney(dynamic value) {
  if (value is! String || !RegExp(r'^\d+\.\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid monetary DTO');
  }
  return value;
}

class DiscountCapabilities extends Equatable {
  const DiscountCapabilities({
    this.contractVersion = 0,
    this.engineReady = false,
    this.automaticPolicyCreationAvailable = false,
    this.automaticEnabled = false,
    this.settingsVersion = 0,
    this.supportsDiscountReview = false,
    this.supportsPaymentQuote = false,
    this.requiresPaymentQuote = false,
    this.canSuppressAutomatic = false,
    this.supportsMultipleDiscounts = false,
    this.maximumRequestedDiscounts = 1,
    this.policy,
  });
  final int contractVersion, settingsVersion;

  /// Discount V3: the backend accepts a full ordered intent list (`set`).
  final bool supportsMultipleDiscounts;
  final int maximumRequestedDiscounts;
  final DiscountEffectivePolicy? policy;
  final bool engineReady, automaticPolicyCreationAvailable, automaticEnabled;
  final bool supportsDiscountReview,
      supportsPaymentQuote,
      requiresPaymentQuote,
      canSuppressAutomatic;
  factory DiscountCapabilities.fromJson(Map<String, dynamic> j) =>
      DiscountCapabilities(
        contractVersion: j['contractVersion'] as int,
        settingsVersion: j['settingsVersion'] as int,
        engineReady: j['engineReady'] == true,
        automaticPolicyCreationAvailable:
            j['automaticPolicyCreationAvailable'] == true,
        automaticEnabled: j['automaticEnabled'] == true,
        supportsDiscountReview: j['supportsDiscountReview'] == true,
        supportsPaymentQuote: j['supportsPaymentQuote'] == true,
        requiresPaymentQuote: j['requiresPaymentQuote'] == true,
        canSuppressAutomatic: j['canSuppressAutomatic'] == true,
        supportsMultipleDiscounts: j['supportsMultipleDiscounts'] == true,
        maximumRequestedDiscounts: j['maximumRequestedDiscounts'] is int
            ? j['maximumRequestedDiscounts'] as int
            : 1,
        policy: j['policy'] is Map
            ? DiscountEffectivePolicy.fromJson(engineMap(j['policy']))
            : null,
      );
  @override
  List<Object?> get props => [
    supportsMultipleDiscounts,
    maximumRequestedDiscounts,
    policy,
    contractVersion,
    settingsVersion,
    engineReady,
    automaticPolicyCreationAvailable,
    automaticEnabled,
    supportsDiscountReview,
    supportsPaymentQuote,
    requiresPaymentQuote,
    canSuppressAutomatic,
  ];
}

/// The Cafe Discount Policy as the engine applies it right now. UI hints only:
/// the backend decides which discounts survive.
class DiscountEffectivePolicy extends Equatable {
  const DiscountEffectivePolicy({
    this.allowMultipleDiscounts = false,
    this.effectiveMaximumDiscounts = 1,
    this.allowMultipleCoupons = false,
    this.allowCouponWithConfigured = false,
    this.conflictResolution = 'best_saving',
  });
  final bool allowMultipleDiscounts,
      allowMultipleCoupons,
      allowCouponWithConfigured;
  final int effectiveMaximumDiscounts;
  final String conflictResolution;
  factory DiscountEffectivePolicy.fromJson(Map<String, dynamic> j) =>
      DiscountEffectivePolicy(
        allowMultipleDiscounts: j['allowMultipleDiscounts'] == true,
        effectiveMaximumDiscounts: j['effectiveMaximumDiscounts'] is int
            ? j['effectiveMaximumDiscounts'] as int
            : 1,
        allowMultipleCoupons: j['allowMultipleCoupons'] == true,
        allowCouponWithConfigured: j['allowCouponWithConfigured'] == true,
        conflictResolution: j['conflictResolution'] == 'priority'
            ? 'priority'
            : 'best_saving',
      );
  @override
  List<Object?> get props => [
    allowMultipleDiscounts,
    effectiveMaximumDiscounts,
    allowMultipleCoupons,
    allowCouponWithConfigured,
    conflictResolution,
  ];
}

class DiscountAllocation extends Equatable {
  const DiscountAllocation({required this.orderItemId, required this.amount});
  final int orderItemId;
  final String amount;
  factory DiscountAllocation.fromJson(Map<String, dynamic> j) =>
      DiscountAllocation(
        orderItemId: j['orderItemId'] as int,
        amount: exactMoney(j['amount']),
      );
  @override
  List<Object?> get props => [orderItemId, amount];
}

class SavedDiscount extends Equatable {
  const SavedDiscount({
    this.id,
    this.discountId,
    required this.name,
    this.source,
    this.stage,
    required this.type,
    required this.value,
    required this.amount,
    this.settingsVersion,
    this.priority,
    this.applicationMode,
    this.fixedAmountBasis,
    this.scope,
    this.sequence,
    this.combinationBehavior,
    this.capped = false,
    this.allocations = const [],
  });
  final int? id, discountId, settingsVersion, priority;

  /// V3 authoritative application order (1-based). Absent on old orders.
  final int? sequence;
  final String? combinationBehavior;

  /// True when the shared maximum-total-discount limit reduced this discount.
  final bool capped;
  final String name, type, value, amount;
  final String? source, stage, applicationMode, fixedAmountBasis, scope;
  final List<DiscountAllocation> allocations;
  factory SavedDiscount.fromJson(Map<String, dynamic> j) => SavedDiscount(
    id: j['id'] as int?,
    discountId: j['discountId'] as int?,
    name: j['name'] as String,
    source: j['source'] as String?,
    stage: j['stage'] as String?,
    type: j['type'] as String,
    value: j['value'].toString(),
    amount: exactMoney(j['amount']),
    settingsVersion: j['settingsVersion'] as int?,
    priority: j['priority'] as int?,
    applicationMode: j['applicationMode'] as String?,
    fixedAmountBasis: j['fixedAmountBasis'] as String?,
    scope: j['scope'] as String?,
    sequence: j['sequence'] as int?,
    combinationBehavior: j['combinationBehavior'] as String?,
    capped: j['capped'] == true,
    allocations: List.unmodifiable(
      engineList(j['allocations']).map(DiscountAllocation.fromJson),
    ),
  );
  @override
  List<Object?> get props => [
    id,
    discountId,
    name,
    source,
    stage,
    type,
    value,
    amount,
    settingsVersion,
    priority,
    applicationMode,
    fixedAmountBasis,
    scope,
    sequence,
    combinationBehavior,
    capped,
    allocations,
  ];
}

class DiscountTotals extends Equatable {
  const DiscountTotals({
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.total,
  });
  final String subtotal, discountTotal, taxTotal, total;
  factory DiscountTotals.fromJson(Map<String, dynamic> j) => DiscountTotals(
    subtotal: exactMoney(j['subtotal']),
    discountTotal: exactMoney(j['discountTotal']),
    taxTotal: exactMoney(j['taxTotal']),
    total: exactMoney(j['total']),
  );
  @override
  List<Object?> get props => [subtotal, discountTotal, taxTotal, total];
}

class ExplicitDiscountIntent extends Equatable {
  const ExplicitDiscountIntent({
    required this.source,
    this.discountId,
    this.type,
    this.value,
    this.name,
  });
  final String source;
  final int? discountId;
  final String? type, value, name;
  factory ExplicitDiscountIntent.fromJson(Map<String, dynamic> j) =>
      ExplicitDiscountIntent(
        source: j['source'] as String,
        discountId: j['discountId'] as int?,
        type: j['type'] as String?,
        value: j['value'] as String?,
        name: j['name'] as String?,
      );
  @override
  List<Object?> get props => [source, discountId, type, value, name];
}

class DiscountSuppression extends Equatable {
  const DiscountSuppression({
    required this.discountId,
    required this.reason,
    required this.actorId,
    this.name,
  });
  final int discountId, actorId;
  final String reason;

  /// Promotion name; null from older backends.
  final String? name;
  factory DiscountSuppression.fromJson(Map<String, dynamic> j) =>
      DiscountSuppression(
        discountId: j['discountId'] as int,
        reason: j['reason'] as String,
        actorId: j['actorId'] as int,
        name: j['name'] as String?,
      );
  @override
  List<Object?> get props => [discountId, reason, actorId, name];
}

class SavedDiscountState extends Equatable {
  const SavedDiscountState({
    required this.orderId,
    required this.totals,
    this.explicitIntent,
    this.explicitIntents = const [],
    this.discounts = const [],
    this.suppressions = const [],
    this.requiresDiscountBreakdown = false,
    this.discountContractVersion = 2,
  });
  final int orderId, discountContractVersion;
  final bool requiresDiscountBreakdown;
  final DiscountTotals totals;
  final ExplicitDiscountIntent? explicitIntent;

  /// V3 ordered explicit intents. Older backends only send [explicitIntent].
  final List<ExplicitDiscountIntent> explicitIntents;
  final List<SavedDiscount> discounts;
  final List<DiscountSuppression> suppressions;
  factory SavedDiscountState.fromJson(Map<String, dynamic> j) {
    final single = j['explicitIntent'] == null
        ? null
        : ExplicitDiscountIntent.fromJson(engineMap(j['explicitIntent']));
    return SavedDiscountState(
      orderId: j['orderId'] as int,
      totals: DiscountTotals.fromJson(engineMap(j['totals'])),
      explicitIntent: single,
      explicitIntents: List.unmodifiable(
        j['explicitIntents'] is List
            ? engineList(
                j['explicitIntents'],
              ).map(ExplicitDiscountIntent.fromJson)
            : [?single],
      ),
      discounts: List.unmodifiable(
        engineList(j['discounts']).map(SavedDiscount.fromJson),
      ),
      suppressions: List.unmodifiable(
        engineList(j['suppressions']).map(DiscountSuppression.fromJson),
      ),
      requiresDiscountBreakdown: j['requiresDiscountBreakdown'] == true,
      discountContractVersion: j['discountContractVersion'] as int,
    );
  }
  @override
  List<Object?> get props => [
    orderId,
    totals,
    explicitIntent,
    explicitIntents,
    discounts,
    suppressions,
    requiresDiscountBreakdown,
    discountContractVersion,
  ];
}

/// A requested discount the backend did not apply, with a stable reason code.
class ExcludedDiscount extends Equatable {
  const ExcludedDiscount({
    required this.code,
    this.position,
    this.discountId,
    this.name,
    this.source,
    this.conflictsWith = const [],
  });
  final int? position, discountId;
  final String? name, source;
  final String code;
  final List<int> conflictsWith;
  factory ExcludedDiscount.fromJson(Map<String, dynamic> j) => ExcludedDiscount(
    code: j['code'] as String,
    position: j['position'] as int?,
    discountId: j['discountId'] as int?,
    name: j['name'] as String?,
    source: j['source'] as String?,
    conflictsWith: List.unmodifiable(
      (j['conflictsWith'] as List? ?? const []).whereType<int>(),
    ),
  );
  @override
  List<Object?> get props => [
    code,
    position,
    discountId,
    name,
    source,
    conflictsWith,
  ];
}

class DiscountResolution extends Equatable {
  const DiscountResolution({
    required this.totals,
    required this.fingerprint,
    required this.settingsVersion,
    this.discounts = const [],
    this.excluded = const [],
    this.provisional = false,
    this.reasons = const [],
  });
  final DiscountTotals totals;
  final String fingerprint;
  final int settingsVersion;
  final bool provisional;
  final List<SavedDiscount> discounts;

  /// V3: requested but not applied. Never hide these from the cashier.
  final List<ExcludedDiscount> excluded;
  final List<(int?, String)> reasons;
  factory DiscountResolution.fromJson(Map<String, dynamic> j) =>
      DiscountResolution(
        totals: DiscountTotals.fromJson(engineMap(j['totals'])),
        fingerprint: j['fingerprint'] as String,
        settingsVersion: j['settingsVersion'] as int,
        provisional: j['provisional'] == true,
        discounts: List.unmodifiable(
          engineList(j['discounts']).map(SavedDiscount.fromJson),
        ),
        excluded: List.unmodifiable(
          engineList(j['excluded']).map(ExcludedDiscount.fromJson),
        ),
        reasons: List.unmodifiable(
          engineList(
            j['reasons'],
          ).map((r) => (r['discountId'] as int?, r['code'] as String)),
        ),
      );
  @override
  List<Object?> get props => [
    totals,
    fingerprint,
    settingsVersion,
    provisional,
    discounts,
    excluded,
    reasons,
  ];
}

class DiscountReview extends Equatable {
  const DiscountReview({
    required this.reviewId,
    required this.resolution,
    required this.before,
    required this.after,
    required this.removals,
    required this.additions,
  });
  final String reviewId;
  final DiscountResolution resolution;
  final DiscountTotals before, after;
  final List<SavedDiscount> removals, additions;
  factory DiscountReview.fromJson(Map<String, dynamic> j) => DiscountReview(
    reviewId: j['reviewId'] as String,
    resolution: DiscountResolution.fromJson(j),
    before: DiscountTotals.fromJson(engineMap(j['before'])),
    after: DiscountTotals.fromJson(engineMap(j['after'])),
    removals: List.unmodifiable(
      engineList(j['removals']).map(SavedDiscount.fromJson),
    ),
    additions: List.unmodifiable(
      engineList(j['additions']).map(SavedDiscount.fromJson),
    ),
  );
  @override
  List<Object?> get props => [
    reviewId,
    resolution,
    before,
    after,
    removals,
    additions,
  ];
}

class DiscountOperationResult {
  const DiscountOperationResult({
    required this.operationId,
    required this.completed,
    this.result,
  });
  final String operationId;
  final bool completed;
  final SavedDiscountState? result;
  factory DiscountOperationResult.fromJson(Map<String, dynamic> j) =>
      DiscountOperationResult(
        operationId: j['operationId'] as String,
        completed: j['completed'] == true,
        result: j['result'] == null
            ? null
            : SavedDiscountState.fromJson(engineMap(j['result'])),
      );
}

class OperationalPaymentMethod extends Equatable {
  const OperationalPaymentMethod({
    required this.id,
    required this.name,
    required this.type,
  });
  final int id;
  final String name, type;
  factory OperationalPaymentMethod.fromJson(Map<String, dynamic> j) =>
      OperationalPaymentMethod(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as String,
      );
  @override
  List<Object?> get props => [id, name, type];
}

class PaymentQuote extends Equatable {
  const PaymentQuote({
    required this.quoteId,
    required this.resolution,
    required this.paymentMethodId,
    required this.method,
    required this.expiresAt,
  });
  final String quoteId;
  final DiscountResolution resolution;
  final int? paymentMethodId;
  final String? method;
  final DateTime expiresAt;
  factory PaymentQuote.fromJson(Map<String, dynamic> j) => PaymentQuote(
    quoteId: j['quoteId'] as String,
    resolution: DiscountResolution.fromJson(j),
    paymentMethodId: j['paymentMethodId'] as int?,
    method: j['method'] as String?,
    expiresAt: DateTime.now().add(
      Duration(seconds: j['expiresInSeconds'] as int),
    ),
  );
  @override
  List<Object?> get props => [
    quoteId,
    resolution,
    paymentMethodId,
    method,
    expiresAt,
  ];
}

/// One entry of the cashier's desired discount list. Never carries money.
///
/// A coupon typed in this session carries its [code]; a coupon already saved on
/// the order is kept by [discountId] (the backend never returns coupon text).
class DesiredDiscountIntent extends Equatable {
  const DesiredDiscountIntent._(this.source, this.discountId, this.code);
  const DesiredDiscountIntent.configured(int id)
    : this._('configured_manual', id, null);
  const DesiredDiscountIntent.coupon(String code) : this._('code', null, code);
  const DesiredDiscountIntent.savedCoupon(int id) : this._('code', id, null);
  final String source;
  final int? discountId;
  final String? code;

  bool get isCoupon => source == 'code';

  /// Saved V3 intents, in their authoritative order. Legacy ad-hoc intents
  /// cannot be part of a set and are dropped.
  static List<DesiredDiscountIntent> fromSaved(SavedDiscountState? saved) => [
    for (final intent in saved?.explicitIntents ?? const [])
      if (intent.discountId != null && intent.source == 'code')
        DesiredDiscountIntent.savedCoupon(intent.discountId!)
      else if (intent.discountId != null &&
          intent.source == 'configured_manual')
        DesiredDiscountIntent.configured(intent.discountId!),
  ];

  Map<String, dynamic> toJson() => {
    'source': source,
    if (code != null) 'code': code else 'discountId': discountId,
  };
  @override
  List<Object?> get props => [source, discountId, code];
  @override
  String toString() => 'DesiredDiscountIntent($source)';
}

/// Coupon input exists only in this transient source-specific request.
class DiscountReviewRequest {
  const DiscountReviewRequest._(this.body);
  final Map<String, dynamic> body;
  factory DiscountReviewRequest.manual(int id) => DiscountReviewRequest._({
    'action': 'apply',
    'intent': {'source': 'configured_manual', 'discountId': id},
  });
  factory DiscountReviewRequest.code(String code) => DiscountReviewRequest._({
    'action': 'apply',
    'intent': {'source': 'code', 'code': code},
  });

  /// V3: the complete desired list replaces every explicit intent.
  factory DiscountReviewRequest.set(List<DesiredDiscountIntent> intents) =>
      DiscountReviewRequest._({
        'action': 'set',
        'intents': [for (final intent in intents) intent.toJson()],
      });
  factory DiscountReviewRequest.remove() =>
      const DiscountReviewRequest._({'action': 'remove'});
  factory DiscountReviewRequest.suppress(int id, String reason) =>
      DiscountReviewRequest._({
        'action': 'suppress',
        'discountId': id,
        'reason': reason,
      });
  factory DiscountReviewRequest.undo(int id) =>
      DiscountReviewRequest._({'action': 'undo', 'discountId': id});
  Map<String, dynamic> toJson({int? paymentMethodId}) => {
    ...body,
    'paymentMethodId': paymentMethodId,
  };
  @override
  String toString() => 'DiscountReviewRequest(${body['action']})';
}
