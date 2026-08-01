import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../models/catalog_models.dart';
import '../repositories/menu_catalog_repository.dart';

enum ProductLifecycleAction { archive, restore }

enum ProductLifecycleStatus { idle, submitting, success, failure }

class ProductLifecycleState extends Equatable {
  const ProductLifecycleState({
    this.status = ProductLifecycleStatus.idle,
    this.productId,
    this.action,
    this.product,
    this.errorMessage,
    this.successMessage,
  });

  final ProductLifecycleStatus status;
  final int? productId;
  final ProductLifecycleAction? action;
  final ProductDetail? product;
  final String? errorMessage;
  final String? successMessage;

  bool get isSubmitting => status == ProductLifecycleStatus.submitting;
  bool isSubmittingFor(int id) => isSubmitting && productId == id;

  ProductLifecycleState copyWith({
    ProductLifecycleStatus? status,
    int? productId,
    ProductLifecycleAction? action,
    ProductDetail? product,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) => ProductLifecycleState(
    status: status ?? this.status,
    productId: productId ?? this.productId,
    action: action ?? this.action,
    product: product ?? this.product,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    productId,
    action,
    product,
    errorMessage,
    successMessage,
  ];
}

class ProductLifecycleCubit extends Cubit<ProductLifecycleState> {
  ProductLifecycleCubit({required this.repository})
    : super(const ProductLifecycleState());

  final MenuCatalogRepository repository;

  Future<ProductMenuUsage?> menuUsage(int productId) async {
    try {
      return await repository.getProductMenuUsage(productId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> archive(int productId) =>
      _run(productId, ProductLifecycleAction.archive);

  Future<bool> restore(int productId) =>
      _run(productId, ProductLifecycleAction.restore);

  Future<bool> _run(int productId, ProductLifecycleAction action) async {
    if (state.isSubmitting) return false;
    emit(
      ProductLifecycleState(
        status: ProductLifecycleStatus.submitting,
        productId: productId,
        action: action,
      ),
    );
    try {
      final ProductDetail product = action == ProductLifecycleAction.archive
          ? await repository.archiveProduct(productId)
          : await repository.restoreProduct(productId);
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: ProductLifecycleStatus.success,
          product: product,
          successMessage: action == ProductLifecycleAction.archive
              ? 'Product archived successfully.'
              : 'Product restored successfully.',
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: ProductLifecycleStatus.failure,
          errorMessage: _message(error),
          clearSuccess: true,
        ),
      );
      return false;
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update this product. Please try again.';
}
