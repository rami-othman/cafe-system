import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/catalog_models.dart';
import '../repositories/menu_catalog_repository.dart';

class ProductDetailState extends Equatable {
  const ProductDetailState({
    this.isLoading = false,
    this.isLoadingUsage = false,
    this.product,
    this.usage,
    this.errorMessage,
    this.usageError,
  });
  final bool isLoading;
  final bool isLoadingUsage;
  final ProductDetail? product;
  final ProductMenuUsage? usage;
  final String? errorMessage;
  final String? usageError;
  ProductDetailState copyWith({
    bool? isLoading,
    bool? isLoadingUsage,
    ProductDetail? product,
    ProductMenuUsage? usage,
    String? errorMessage,
    String? usageError,
    bool clearError = false,
    bool clearUsageError = false,
  }) => ProductDetailState(
    isLoading: isLoading ?? this.isLoading,
    isLoadingUsage: isLoadingUsage ?? this.isLoadingUsage,
    product: product ?? this.product,
    usage: usage ?? this.usage,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    usageError: clearUsageError ? null : usageError ?? this.usageError,
  );
  @override
  List<Object?> get props => <Object?>[
    isLoading,
    isLoadingUsage,
    product,
    usage,
    errorMessage,
    usageError,
  ];
}

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit({required this.repository})
    : super(const ProductDetailState());
  final MenuCatalogRepository repository;

  void replaceProduct(ProductDetail product) {
    if (isClosed || state.product?.id != product.id) return;
    emit(state.copyWith(product: product, clearError: true));
  }

  Future<void> load(int productId) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      emit(
        state.copyWith(
          isLoading: false,
          product: await repository.getProduct(
            productId,
            includeArchived: true,
          ),
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error is ApiException
              ? error.message
              : 'Unable to load this product. Please try again.',
        ),
      );
    }
  }

  Future<void> loadUsage(int productId) async {
    if (state.isLoadingUsage || state.usage?.productId == productId) return;
    emit(state.copyWith(isLoadingUsage: true, clearUsageError: true));
    try {
      emit(
        state.copyWith(
          isLoadingUsage: false,
          usage: await repository.getProductMenuUsage(productId),
          clearUsageError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoadingUsage: false,
          usageError: error is ApiException
              ? error.message
              : 'Unable to load product usage. Please try again.',
        ),
      );
    }
  }
}
