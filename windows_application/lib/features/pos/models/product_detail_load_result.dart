import 'backend_product_detail.dart';

sealed class ProductDetailLoadResult {
  const ProductDetailLoadResult();
}

class ProductDetailLoaded extends ProductDetailLoadResult {
  const ProductDetailLoaded(this.detail);

  final BackendProductDetail detail;
}

class ProductDetailLoadFailed extends ProductDetailLoadResult {
  const ProductDetailLoadFailed(this.message);

  final String message;
}

class ProductDetailNotRequired extends ProductDetailLoadResult {
  const ProductDetailNotRequired();
}

class ProductDetailLoadStale extends ProductDetailLoadResult {
  const ProductDetailLoadStale();
}
