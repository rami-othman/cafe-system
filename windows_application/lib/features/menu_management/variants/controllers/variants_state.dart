import 'package:equatable/equatable.dart';

import '../../models/catalog_models.dart';

enum VariantFilter { active, archived, all }

enum VariantAction { create, update, setDefault, archive, restore, reorder }

enum VariantsStatus { initial, loading, loaded, refreshing, failure }

class VariantsState extends Equatable {
  const VariantsState({
    this.status = VariantsStatus.initial,
    this.product,
    this.activeVariants = const <ProductVariant>[],
    this.archivedVariants = const <ProductVariant>[],
    this.recipeConfigured = const <int, bool>{},
    this.filter = VariantFilter.active,
    this.action,
    this.fieldErrors = const <String, String>{},
    this.formError,
    this.successMessage,
  });
  final VariantsStatus status;
  final ProductDetail? product;
  final List<ProductVariant> activeVariants;
  final List<ProductVariant> archivedVariants;

  /// Resolved from the existing recipe endpoint. An absent entry means the
  /// endpoint was unavailable; the UI deliberately treats that as not
  /// configured rather than inventing a recipe state.
  final Map<int, bool> recipeConfigured;
  final VariantFilter filter;
  final VariantAction? action;
  final Map<String, String> fieldErrors;
  final String? formError;
  final String? successMessage;
  bool get isMutating => action != null;
  List<ProductVariant> get visibleVariants => switch (filter) {
    VariantFilter.active => activeVariants,
    VariantFilter.archived => archivedVariants,
    VariantFilter.all => <ProductVariant>[
      ...activeVariants,
      ...archivedVariants,
    ],
  };
  VariantsState copyWith({
    VariantsStatus? status,
    ProductDetail? product,
    List<ProductVariant>? activeVariants,
    List<ProductVariant>? archivedVariants,
    Map<int, bool>? recipeConfigured,
    VariantFilter? filter,
    VariantAction? action,
    Map<String, String>? fieldErrors,
    String? formError,
    String? successMessage,
    bool clearAction = false,
    bool clearErrors = false,
    bool clearSuccess = false,
  }) => VariantsState(
    status: status ?? this.status,
    product: product ?? this.product,
    activeVariants: activeVariants ?? this.activeVariants,
    archivedVariants: archivedVariants ?? this.archivedVariants,
    recipeConfigured: recipeConfigured ?? this.recipeConfigured,
    filter: filter ?? this.filter,
    action: clearAction ? null : action ?? this.action,
    fieldErrors: clearErrors
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    formError: clearErrors ? null : formError ?? this.formError,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    product,
    activeVariants,
    archivedVariants,
    recipeConfigured,
    filter,
    action,
    fieldErrors,
    formError,
    successMessage,
  ];
}
