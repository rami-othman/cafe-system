import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  test(
    'maps products to category names when product payload has categoryId',
    () async {
      final PosRepository repository = PosRepository(
        apiClient: _FakePosApiClient(),
      );

      final List<String> categories = await repository.getCategories(
        branchId: 1,
      );
      final products = await repository.getProducts(branchId: 1);

      expect(categories, contains('Coffee'));
      expect(products.single.name, 'Espresso');
      expect(products.single.category, 'Coffee');
    },
  );
}

class _FakePosApiClient extends DioApiClient {
  _FakePosApiClient() : super(dio: Dio());

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return switch (path) {
      'menu/categories' => <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Coffee'},
      ],
      'menu/products' => <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'categoryId': 1,
          'name': 'Espresso',
          'basePrice': 3.5,
          'isAvailable': true,
        },
      ],
      _ => throw StateError('Unexpected path $path'),
    };
  }
}
