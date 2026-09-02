import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/controllers/pos_cubit.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/shift.dart';
import 'package:windows_application/features/pos/repositories/pos_repository.dart';

void main() {
  late _BranchRepository repository;
  late PosCubit cubit;

  setUp(() async {
    repository = _BranchRepository();
    cubit = PosCubit(repository: repository);
    await cubit.loadInitialData();
  });

  tearDown(() => cubit.close());

  test(
    'empty-cart switch replaces the authoritative POS branch context',
    () async {
      expect(cubit.state.branchId, 1);
      expect(cubit.state.products.single.name, 'Downtown Latte');

      final bool switched = await cubit.selectBranch(2);

      expect(switched, isTrue);
      expect(cubit.state.branchId, 2);
      expect(cubit.state.taxRate, 0.2);
      expect(cubit.state.shiftId, isNull);
      expect(cubit.state.products.single.name, 'Mall Latte');
      expect(repository.loadedBranchIds, <int>[1, 2]);
    },
  );

  test(
    'active cart blocks branch switching without changing the branch',
    () async {
      cubit.addProductToCart(cubit.state.products.single);

      final bool switched = await cubit.selectBranch(2);

      expect(switched, isFalse);
      expect(cubit.state.branchId, 1);
      expect(cubit.state.products.single.name, 'Downtown Latte');
      expect(cubit.state.cartItems, hasLength(1));
      expect(repository.loadedBranchIds, <int>[1]);
    },
  );
}

class _BranchRepository extends PosRepository {
  _BranchRepository() : super();

  final List<int> loadedBranchIds = <int>[];

  @override
  Future<List<Branch>> getBranches() async => const <Branch>[
    Branch(
      id: 1,
      name: 'Downtown',
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
      taxRate: 0.1,
    ),
    Branch(
      id: 2,
      name: 'Mall',
      currency: 'USD',
      timezone: 'Asia/Beirut',
      isActive: true,
      taxRate: 0.2,
    ),
  ];

  @override
  Future<Shift?> getCurrentShift({required int branchId}) async {
    loadedBranchIds.add(branchId);
    if (branchId == 2) return null;
    return Shift(
      id: branchId * 10,
      branchId: branchId,
      userId: 1,
      status: 'open',
    );
  }

  @override
  Future<List<String>> getCategories({required int branchId}) async =>
      const <String>['COFFEE'];

  @override
  Future<List<PosProduct>> getProducts({
    required int branchId,
    int? categoryId,
    String availability = 'all',
  }) async => <PosProduct>[
    PosProduct(
      id: 'latte-$branchId',
      name: branchId == 1 ? 'Downtown Latte' : 'Mall Latte',
      category: 'COFFEE',
      size: 'Regular',
      price: 4,
      isAvailable: true,
    ),
  ];

  @override
  Future<Map<String, dynamic>> getPosState({required int branchId}) async =>
      const <String, dynamic>{};
}
