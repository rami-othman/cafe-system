import 'package:equatable/equatable.dart';

/// The eight writable fields. Version and activation capability belong to the
/// saved resource, never to the editable replacement.
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
  });
  final bool automaticEnabled;
  final String selectionStrategy, combinationMode, orderDiscountBehavior;
  final String couponBehavior, manualBehavior, maximumTotalDiscountPercent;
  final bool allowAutomaticSuppression;

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
                n <= 100));
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
  ];
}

class SavedDiscountSettings extends Equatable {
  const SavedDiscountSettings({
    required this.draft,
    required this.version,
    required this.engineReady,
  });
  final DiscountSettingsDraft draft;
  final int version;
  final bool engineReady;
  factory SavedDiscountSettings.fromJson(Map<String, dynamic> j) =>
      SavedDiscountSettings(
        draft: DiscountSettingsDraft.fromJson(j),
        version: j['version'] as int,
        engineReady: j['engineReady'] == true,
      );
  @override
  List<Object?> get props => [draft, version, engineReady];
}
