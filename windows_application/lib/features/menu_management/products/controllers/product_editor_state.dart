import 'package:equatable/equatable.dart';

import '../../models/catalog_models.dart';
import '../models/product_editor_draft.dart';

enum ProductEditorStatus {
  initial,
  loading,
  ready,
  submitting,
  success,
  failure,
}

class ProductEditorState extends Equatable {
  const ProductEditorState({
    this.status = ProductEditorStatus.initial,
    this.draft = const ProductEditorDraft(),
    this.productId,
    this.currentDefaultVariant,
    this.categories = const <CatalogCategory>[],
    this.reportingCategories = const <ReportingCategory>[],
    this.kitchenStations = const <KitchenStation>[],
    this.referenceErrors = const <String, String>{},
    this.fieldErrors = const <String, String>{},
    this.formError,
    this.isDirty = false,
    this.savedProduct,
  });
  final ProductEditorStatus status;
  final ProductEditorDraft draft;
  final int? productId;
  final ProductVariant? currentDefaultVariant;
  final List<CatalogCategory> categories;
  final List<ReportingCategory> reportingCategories;
  final List<KitchenStation> kitchenStations;
  final Map<String, String> referenceErrors;
  final Map<String, String> fieldErrors;
  final String? formError;
  final bool isDirty;
  final ProductDetail? savedProduct;
  bool get isCreate => productId == null;
  ProductEditorState copyWith({
    ProductEditorStatus? status,
    ProductEditorDraft? draft,
    int? productId,
    ProductVariant? currentDefaultVariant,
    List<CatalogCategory>? categories,
    List<ReportingCategory>? reportingCategories,
    List<KitchenStation>? kitchenStations,
    Map<String, String>? referenceErrors,
    Map<String, String>? fieldErrors,
    String? formError,
    bool? isDirty,
    ProductDetail? savedProduct,
    bool clearProductId = false,
    bool clearDefaultVariant = false,
    bool clearFieldErrors = false,
    bool clearFormError = false,
    bool clearSavedProduct = false,
  }) => ProductEditorState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    productId: clearProductId ? null : productId ?? this.productId,
    currentDefaultVariant: clearDefaultVariant
        ? null
        : currentDefaultVariant ?? this.currentDefaultVariant,
    categories: categories ?? this.categories,
    reportingCategories: reportingCategories ?? this.reportingCategories,
    kitchenStations: kitchenStations ?? this.kitchenStations,
    referenceErrors: referenceErrors ?? this.referenceErrors,
    fieldErrors: clearFieldErrors
        ? const <String, String>{}
        : fieldErrors ?? this.fieldErrors,
    formError: clearFormError ? null : formError ?? this.formError,
    isDirty: isDirty ?? this.isDirty,
    savedProduct: clearSavedProduct ? null : savedProduct ?? this.savedProduct,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    draft,
    productId,
    currentDefaultVariant,
    categories,
    reportingCategories,
    kitchenStations,
    referenceErrors,
    fieldErrors,
    formError,
    isDirty,
    savedProduct,
  ];
}
