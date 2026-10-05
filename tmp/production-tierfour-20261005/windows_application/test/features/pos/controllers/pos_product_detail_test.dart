import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/backend_product_detail.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/product_detail_load_result.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  late _ProductDetailRepository repository;
  late PosCubit cubit;

  setUp(() {
    repository = _ProductDetailRepository();
    cubit = PosCubit(repository: repository);
  });

  tearDown(() => cubit.close());

  test('backend detail succeeds with modifier groups', () async {
    repository.detail = _detail(
      id: 1,
      groups: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'name': 'Milk',
          'type': 'single',
          'required': true,
          'minSelections': 1,
          'maxSelections': 1,
          'options': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 100,
              'name': 'Whole',
              'priceDelta': 0,
              'isDefault': true,
              'isAvailable': true,
            },
          ],
        },
      ],
    );

    final ProductDetailLoadResult result = await cubit.loadProductDetail(_a);

    expect(result, isA<ProductDetailLoaded>());
    expect((result as ProductDetailLoaded).detail.modifierGroups.single.id, 10);
    expect(cubit.state.productDetailError, isNull);
  });

  test('zero modifier groups is a successful backend result', () async {
    repository.detail = _detail(id: 1, groups: const <Map<String, dynamic>>[]);

    final ProductDetailLoadResult result = await cubit.loadProductDetail(_a);

    expect(result, isA<ProductDetailLoaded>());
    expect((result as ProductDetailLoaded).detail.modifierGroups, isEmpty);
    expect(cubit.state.productDetailError, isNull);
  });

  test(
    'backend detail failure is explicit and does not look like no modifiers',
    () async {
      repository.error = const ApiException(message: 'Backend offline');

      final ProductDetailLoadResult result = await cubit.loadProductDetail(_a);

      expect(result, isA<ProductDetailLoadFailed>());
      expect(
        cubit.state.productDetailError,
        'Could not load product options. Please try again.',
      );
    },
  );

  test(
    'stale detail response cannot replace the latest product request',
    () async {
      final Completer<BackendProductDetail> first =
          Completer<BackendProductDetail>();
      final Completer<BackendProductDetail> second =
          Completer<BackendProductDetail>();
      repository.responses = <Future<BackendProductDetail>>[
        first.future,
        second.future,
      ];

      final Future<ProductDetailLoadResult> firstResult = cubit
          .loadProductDetail(_a);
      final Future<ProductDetailLoadResult> secondResult = cubit
          .loadProductDetail(_b);
      second.complete(_detail(id: 2, groups: const <Map<String, dynamic>>[]));

      expect(await secondResult, isA<ProductDetailLoaded>());
      first.complete(_detail(id: 1, groups: const <Map<String, dynamic>>[]));
      expect(await firstResult, isA<ProductDetailLoadStale>());
    },
  );

  test(
    'repeated click for the same loading product sends one request',
    () async {
      final Completer<BackendProductDetail> pending =
          Completer<BackendProductDetail>();
      repository.responses = <Future<BackendProductDetail>>[pending.future];

      final Future<ProductDetailLoadResult> first = cubit.loadProductDetail(_a);
      final ProductDetailLoadResult repeat = await cubit.loadProductDetail(_a);

      expect(repeat, isA<ProductDetailLoadStale>());
      expect(repository.calls, 1);
      pending.complete(_detail(id: 1, groups: const <Map<String, dynamic>>[]));
      expect(await first, isA<ProductDetailLoaded>());
    },
  );

  test(
    'published runtime product never requests the legacy detail endpoint',
    () async {
      final ProductDetailLoadResult result = await cubit.loadProductDetail(
        const PosProduct(
          id: 'published-12-40',
          backendId: 1,
          name: 'Published Latte',
          category: '',
          size: 'Regular',
          price: 4.5,
          isAvailable: true,
          publishedMenuVersionId: 12,
          placementId: 40,
        ),
      );

      expect(result, isA<ProductDetailNotRequired>());
      expect(repository.calls, 0);
    },
  );
}

const PosProduct _a = PosProduct(
  id: '1',
  backendId: 1,
  name: 'Latte',
  category: 'COFFEE',
  size: '12 oz',
  price: 4,
  isAvailable: true,
);
const PosProduct _b = PosProduct(
  id: '2',
  backendId: 2,
  name: 'Mocha',
  category: 'COFFEE',
  size: '12 oz',
  price: 5,
  isAvailable: true,
);

BackendProductDetail _detail({
  required int id,
  required List<Map<String, dynamic>> groups,
}) => BackendProductDetail.fromJson(<String, dynamic>{
  'id': id,
  'name': 'Coffee',
  'basePrice': 4,
  'isAvailable': true,
  'modifierGroups': groups,
});

class _ProductDetailRepository extends PosRepository {
  _ProductDetailRepository() : super();

  int calls = 0;
  BackendProductDetail? detail;
  Object? error;
  List<Future<BackendProductDetail>> responses =
      <Future<BackendProductDetail>>[];

  @override
  bool get usesBackend => true;

  @override
  Future<BackendProductDetail> getProductDetail({
    required int productId,
    required int branchId,
  }) async {
    calls += 1;
    if (responses.isNotEmpty) return responses.removeAt(0);
    if (error != null) throw error!;
    return detail!;
  }
}
