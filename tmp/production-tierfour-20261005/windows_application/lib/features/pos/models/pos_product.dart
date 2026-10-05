import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'pos_menu_runtime_models.dart';

class PosProduct extends Equatable {
  const PosProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.size,
    required this.price,
    required this.isAvailable,
    this.backendId,
    this.categoryId,
    this.icon,
    this.publishedMenuVersionId,
    this.placementId,
    this.defaultVariantId,
    this.variants = const <PosPublishedVariant>[],
    this.modifierGroups = const <PosModifierGroup>[],
    this.sellableVariantIds = const <int>[],
    this.unavailabilityReason,
    this.currencyCode,
    this.imageUrl,
    this.description,
  });

  final String id;
  final int? backendId;
  final int? categoryId;
  final String name;
  final String category;
  final String size;
  final double price;
  final bool isAvailable;
  final IconData? icon;

  /// Immutable published identities. They are intentionally separate from the
  /// legacy Catalog identifiers because the same product can be placed more
  /// than once in a published menu collection.
  final int? publishedMenuVersionId;
  final int? placementId;
  final int? defaultVariantId;
  final List<PosPublishedVariant> variants;
  final List<PosModifierGroup> modifierGroups;
  final List<int> sellableVariantIds;
  final String? unavailabilityReason;
  final String? currencyCode;
  final String? imageUrl;
  final String? description;

  bool get isPublishedRuntime =>
      publishedMenuVersionId != null &&
      placementId != null &&
      backendId != null;

  @override
  List<Object?> get props => <Object?>[
    id,
    backendId,
    categoryId,
    name,
    category,
    size,
    price,
    isAvailable,
    icon,
    publishedMenuVersionId,
    placementId,
    defaultVariantId,
    variants,
    modifierGroups,
    sellableVariantIds,
    unavailabilityReason,
    currencyCode,
    imageUrl,
    description,
  ];
}
