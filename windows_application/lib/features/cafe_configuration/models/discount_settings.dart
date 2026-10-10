import 'package:equatable/equatable.dart';

/// The editable settings. Version and activation capability belong to the
/// saved resource, never to the editable replacement.
///
/// The public screen edits only [policy] and [maximumTotalDiscountPercent].
/// The eight legacy engine fields are carried unchanged from the saved resource
/// so a save never resets them, but they are no longer shown.
class DiscountSettingsDraft extends Equatable {
  const DiscountSettingsDraft({
    this.automaticEnabled = false,
    this.selectionStrategy = 'highest_saving',
    this.combinationMode = 'single',
    this.orderDiscountBehavior = 'exclusive',
    this.couponBehavior = 'exclusive',
    this.manualBehavior = 'exclusive',
    this.maximumTotalDiscountPercent = '',
    this.allowAutomaticSuppression = true,
    this.policy = const DiscountCafePolicy(),
  });
  final bool automaticEnabled;
  final String selectionStrategy, combinationMode, orderDiscountBehavior;
  final String couponBehavior, manualBehavior, maximumTotalDiscountPercent;
  final bool allowAutomaticSuppression;
  final DiscountCafePolicy policy;

  factory DiscountSettingsDraft.fromJson(Map<String, dynamic> j) =>
      DiscountSettingsDraft(
        automaticEnabled: j['automaticEnabled'] == true,
        selectionStrategy: j['selectionStrategy'] as String,
        combinationMode: j['combinationMode'] as String,
        orderDiscountBehavior: j['orderDiscountBehavior'] as String,
        couponBehavior: j['couponBehavior'] as String,
        manualBehavior: j['manualBehavior'] as String,
        maximumTotalDiscountPercent:
            j['maximumTotalDiscountPercent']?.toString() ?? '',
        allowAutomaticSuppression: j['allowAutomaticSuppression'] == true,
        policy: DiscountCafePolicy.fromJson(j),
      );
  bool get isValid {
    final cap = maximumTotalDiscountPercent.trim();
    final n = num.tryParse(cap);
    return const [
          'highest_saving',
          'lowest_saving',
          'priority',
        ].contains(selectionStrategy) &&
        const ['single', 'disjoint_items'].contains(combinationMode) &&
        const ['exclusive', 'after_items'].contains(orderDiscountBehavior) &&
        (orderDiscountBehavior != 'after_items' ||
            combinationMode == 'disjoint_items') &&
        const [
          'exclusive',
          'follow_combination_rules',
        ].contains(couponBehavior) &&
        const [
          'exclusive',
          'follow_combination_rules',
        ].contains(manualBehavior) &&
        (cap.isEmpty ||
            (RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(cap) &&
                n != null &&
                n > 0 &&
                n <= 100)) &&
        policy.isValid;
  }

  Map<String, dynamic> toJson(int expectedVersion) => {
    'automaticEnabled': automaticEnabled,
    'selectionStrategy': selectionStrategy,
    'combinationMode': combinationMode,
    'orderDiscountBehavior': orderDiscountBehavior,
    'couponBehavior': couponBehavior,
    'manualBehavior': manualBehavior,
    'maximumTotalDiscountPercent': maximumTotalDiscountPercent.trim().isEmpty
        ? null
        : maximumTotalDiscountPercent.trim(),
    'allowAutomaticSuppression': allowAutomaticSuppression,
    // V3 Cafe Discount Policy. Dormant values (e.g. a maximum of 3 while
    // multiple discounts are off) are sent back unchanged, never normalized.
    ...policy.toJson(),
    'expectedVersion': expectedVersion,
  };
  DiscountSettingsDraft copyWith({
    bool? automaticEnabled,
    String? selectionStrategy,
    String? combinationMode,
    String? orderDiscountBehavior,
    String? couponBehavior,
    String? manualBehavior,
    String? maximumTotalDiscountPercent,
    bool? allowAutomaticSuppression,
    DiscountCafePolicy? policy,
  }) => DiscountSettingsDraft(
    automaticEnabled: automaticEnabled ?? this.automaticEnabled,
    selectionStrategy: selectionStrategy ?? this.selectionStrategy,
    combinationMode: combinationMode ?? this.combinationMode,
    orderDiscountBehavior: orderDiscountBehavior ?? this.orderDiscountBehavior,
    couponBehavior: couponBehavior ?? this.couponBehavior,
    manualBehavior: manualBehavior ?? this.manualBehavior,
    maximumTotalDiscountPercent:
        maximumTotalDiscountPercent ?? this.maximumTotalDiscountPercent,
    allowAutomaticSuppression:
        allowAutomaticSuppression ?? this.allowAutomaticSuppression,
    policy: policy ?? this.policy,
  );

  /// Public defaults for the visible policy; hidden legacy fields are kept.
  DiscountSettingsDraft withPublicDefaults() => copyWith(
    policy: const DiscountCafePolicy(),
    maximumTotalDiscountPercent: '',
    automaticEnabled: false,
    allowAutomaticSuppression: true,
  );
  @override
  List<Object?> get props => [
    automaticEnabled,
    selectionStrategy,
    combinationMode,
    orderDiscountBehavior,
    couponBehavior,
    manualBehavior,
    maximumTotalDiscountPercent,
    allowAutomaticSuppression,
    policy,
  ];
}

/// Discount V3 Cafe Discount Policy, as persisted and enforced by the backend.
///
/// The defaults are the single-discount behavior and also apply when an older
/// backend omits the fields. The total-percent limit is the draft's
/// maximumTotalDiscountPercent, shared with V3, not a second field.
class DiscountCafePolicy extends Equatable {
  const DiscountCafePolicy({
    this.allowMultipleDiscounts = false,
    this.stackingMode = 'different_items_only',
    this.allowMultipleCoupons = false,
    this.allowCouponWithConfigured = false,
    this.allowOrderAfterItemDiscounts = false,
    this.maximumDiscountsPerOrder = 1,
    this.conflictResolution = 'best_saving',
  });
  final bool allowMultipleDiscounts;

  /// `different_items_only` or `same_item_allowed`.
  final String stackingMode;
  final bool allowMultipleCoupons;
  final bool allowCouponWithConfigured;
  final bool allowOrderAfterItemDiscounts;
  final int maximumDiscountsPerOrder;

  /// `best_saving` or `priority`.
  final String conflictResolution;

  static const int maximumDiscountsLimit = 10;

  bool get isValid =>
      maximumDiscountsPerOrder >= 1 &&
      maximumDiscountsPerOrder <= maximumDiscountsLimit;

  /// Shown/enforced count: 1 while multiple discounts are off. The saved value
  /// itself is left untouched.
  int get effectiveMaximumDiscounts =>
      allowMultipleDiscounts ? maximumDiscountsPerOrder : 1;

  DiscountCafePolicy copyWith({
    bool? allowMultipleDiscounts,
    String? stackingMode,
    bool? allowMultipleCoupons,
    bool? allowCouponWithConfigured,
    bool? allowOrderAfterItemDiscounts,
    int? maximumDiscountsPerOrder,
    String? conflictResolution,
  }) => DiscountCafePolicy(
    allowMultipleDiscounts:
        allowMultipleDiscounts ?? this.allowMultipleDiscounts,
    stackingMode: stackingMode ?? this.stackingMode,
    allowMultipleCoupons: allowMultipleCoupons ?? this.allowMultipleCoupons,
    allowCouponWithConfigured:
        allowCouponWithConfigured ?? this.allowCouponWithConfigured,
    allowOrderAfterItemDiscounts:
        allowOrderAfterItemDiscounts ?? this.allowOrderAfterItemDiscounts,
    maximumDiscountsPerOrder:
        maximumDiscountsPerOrder ?? this.maximumDiscountsPerOrder,
    conflictResolution: conflictResolution ?? this.conflictResolution,
  );

  factory DiscountCafePolicy.fromJson(Map<String, dynamic> j) =>
      DiscountCafePolicy(
        allowMultipleDiscounts: j['allowMultipleDiscounts'] == true,
        stackingMode: j['stackingMode'] == 'same_item_allowed'
            ? 'same_item_allowed'
            : 'different_items_only',
        allowMultipleCoupons: j['allowMultipleCoupons'] == true,
        allowCouponWithConfigured: j['allowCouponWithConfigured'] == true,
        allowOrderAfterItemDiscounts: j['allowOrderAfterItemDiscounts'] == true,
        maximumDiscountsPerOrder: j['maximumDiscountsPerOrder'] is int
            ? j['maximumDiscountsPerOrder'] as int
            : 1,
        conflictResolution: j['conflictResolution'] == 'priority'
            ? 'priority'
            : 'best_saving',
      );

  Map<String, dynamic> toJson() => {
    'allowMultipleDiscounts': allowMultipleDiscounts,
    'stackingMode': stackingMode,
    'allowMultipleCoupons': allowMultipleCoupons,
    'allowCouponWithConfigured': allowCouponWithConfigured,
    'allowOrderAfterItemDiscounts': allowOrderAfterItemDiscounts,
    'maximumDiscountsPerOrder': maximumDiscountsPerOrder,
    'conflictResolution': conflictResolution,
  };

  @override
  List<Object?> get props => [
    allowMultipleDiscounts,
    stackingMode,
    allowMultipleCoupons,
    allowCouponWithConfigured,
    allowOrderAfterItemDiscounts,
    maximumDiscountsPerOrder,
    conflictResolution,
  ];
}

class SavedDiscountSettings extends Equatable {
  const SavedDiscountSettings({
    required this.draft,
    required this.version,
    required this.engineReady,
    this.policy = const DiscountCafePolicy(),
  });
  final DiscountSettingsDraft draft;
  final int version;
  final bool engineReady;
  final DiscountCafePolicy policy;
  factory SavedDiscountSettings.fromJson(Map<String, dynamic> j) =>
      SavedDiscountSettings(
        draft: DiscountSettingsDraft.fromJson(j),
        version: j['version'] as int,
        engineReady: j['engineReady'] == true,
        policy: DiscountCafePolicy.fromJson(j),
      );
  @override
  List<Object?> get props => [draft, version, engineReady, policy];
}
