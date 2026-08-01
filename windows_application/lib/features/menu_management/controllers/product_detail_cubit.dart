import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/catalog_models.dart';
import '../repositories/menu_catalog_repository.dart';

class ProductDetailState extends Equatable {
  const ProductDetailState({
    this.isLoading = false,
    this.product,
    this.errorMessage,
  });
  final bool isLoading;
  final ProductDetail? product;
  final String? errorMessage;
  ProductDetailState copyWith({
    bool? isLoading,
    ProductDetail? product,
    String? errorMessage,
    bool clearError = false,
  }) => ProductDetailState(
    isLoading: isLoading ?? this.isLoading,
    product: product ?? this.product,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
  @override
  List<Object?> get props => <Object?>[isLoading, product, errorMessage];
}

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit({required this.repository})
    : super(const ProductDetailState());
  final MenuCatalogRepository repository;
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
}
