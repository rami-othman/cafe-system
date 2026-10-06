import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/discounts/controllers/discounts_cubit.dart';

void main() {
  test(
    'product AND variant references retain meta and send search/page beyond 100',
    () async {
      final api = _Client();
      final repo = DiscountsApiRepository(api);
      final products = await repo.getProducts(page: 6, search: ' coffee ');
      expect(products.currentPage, 6);
      expect(products.lastPage, 6);
      expect(products.total, 101);
      expect(api.calls.last.$1, 'discounts/references/products');
      expect(api.calls.last.$2, {'page': 6, 'perPage': 20, 'search': 'coffee'});
      final variants = await repo.getVariants(11, page: 6, search: ' large ');
      expect(variants.items.single.id, 101);
      expect(variants.currentPage, 6);
      expect(api.calls.last.$1, 'discounts/references/products/11/variants');
      expect(api.calls.last.$2, {'page': 6, 'perPage': 20, 'search': 'large'});
      await repo.getProducts(search: '   ');
      expect(api.calls.last.$2.containsKey('search'), isFalse);
      await repo.getVariants(11, search: '');
      expect(api.calls.last.$2.containsKey('search'), isFalse);
    },
  );
  test(
    'forbidden category is scoped; groups/payments and product controller remain functional',
    () async {
      final api = _Client();
      api.forbidCategories = true;
      final repo = DiscountsApiRepository(api);
      final cubit = DiscountsCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.loadFormReferences();
      expect(cubit.state.formReferences.failures, {'categories': 'forbidden'});
      expect(cubit.state.formReferences.customerGroups.single.id, 101);
      expect(cubit.state.formReferences.paymentMethods.single.id, 101);
      final targets = cubit.createTargetsController();
      addTearDown(targets.close);
      await targets.load();
      expect(targets.state.pages[0]!.page.items.single.id, 101);
      expect(targets.state.pages[0]!.error, isNull);
      api.forbidCategories = false;
      await cubit.loadFormReferences();
      expect(cubit.state.formReferences.failures, isEmpty);
      expect(cubit.state.formReferencesErrorMessage, isNull);
    },
  );
  test(
    'unavailable reference failure uses safe scoped state without clearing fields',
    () async {
      final api = _Client();
      api.failCustomers = true;
      final cubit = DiscountsCubit(repository: DiscountsApiRepository(api));
      addTearDown(cubit.close);
      await cubit.loadFormReferences();
      expect(cubit.state.formReferences.failures, {'customers': 'failed'});
      expect(cubit.state.formReferences.categories, isNotEmpty);
      expect(
        cubit.state.formReferencesErrorMessage,
        DiscountsCubit.requestFailed,
      );
    },
  );
}

class _Client extends DioApiClient {
  final calls = <(String, Map<String, dynamic>)>[];
  bool forbidCategories = false, failCustomers = false;
  @override
  Future<dynamic> getEnvelope(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add((path, queryParameters ?? {}));
    return {
      'data': [
        {'id': 101, 'name': 'Coffee', 'isActive': true, 'archivedAt': null},
      ],
      'meta': {
        'currentPage': queryParameters?['page'] ?? 1,
        'lastPage': 6,
        'total': 101,
        'perPage': 20,
      },
    };
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool suppressAuthenticationFailure = false,
  }) async {
    if (forbidCategories && path.endsWith('categories')) {
      throw const ApiException(message: 'SECRET', statusCode: 403);
    }
    if (failCustomers && path == 'customers') throw StateError('SECRET');
    return [
      {'id': 101, 'name': 'Available', 'isActive': true},
    ];
  }
}
