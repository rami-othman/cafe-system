import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/inventory/repositories/inventory_repository.dart';
import 'package:windows_application/features/manufacturing/controllers/manufacturing_recipe_cubit.dart';
import 'package:windows_application/features/manufacturing/repositories/manufacturing_repository.dart';
import 'package:windows_application/features/sales/models/sales_models.dart';
import 'package:windows_application/app/item_route_scope.dart';
import 'package:windows_application/app/app_router.dart';

void main() {
  test('ingredient search pages carry factory scope and retain selected candidates', () async {
    final dio = Dio(); final requests = <RequestOptions>[];
    final api = DioApiClient(dio: dio)..scopeBranchId = 5;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final page = options.queryParameters['page'] as int;
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'data': [{'id': page, 'sku': 'F-$page', 'nameAr': 'مادة $page', 'nameEn': 'Ingredient $page', 'itemType': 'raw_material', 'unit': 'kilogram', 'isActive': true, 'ownerBranchId': 5, 'totalQuantity': '12.000'}], 'meta': {'currentPage': page, 'lastPage': 2, 'total': 2}}));
    }));
    final cubit = ManufacturingRecipeCubit(repository: ManufacturingRepository(api), inventoryRepository: InventoryRepository(api));
    await cubit.loadIngredientCandidates(search: 'طحين');
    await cubit.loadIngredientCandidates(nextPage: true);
    expect(cubit.state.ingredientCandidates.map((i) => i.id), [1, 2]);
    expect(cubit.state.ingredientCandidates.first.quantity, '12.000');
    expect(cubit.state.ingredientCandidates.first.ownerBranchId, 5);
    expect(requests.every((r) => r.queryParameters['scopeBranchId'] == 5 && r.queryParameters['branchId'] == 5), isTrue);
    expect(requests.last.queryParameters['search'], 'طحين');
    await cubit.close();
  });
  test('ingredient failure is visible and retry recovers', () async {
    final dio = Dio(); bool fail = true;
    final api = DioApiClient(dio: dio)..scopeBranchId = 5;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (fail) { handler.reject(DioException(requestOptions: options, response: Response(requestOptions: options, statusCode: 500), type: DioExceptionType.badResponse)); return; }
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {'data': [], 'meta': {'lastPage': 1}}));
    }));
    final cubit = ManufacturingRecipeCubit(repository: ManufacturingRepository(api), inventoryRepository: InventoryRepository(api));
    await cubit.loadIngredientCandidates(); expect(cubit.state.error, isNotNull);
    fail = false; await cubit.loadIngredientCandidates(); expect(cubit.state.error, isNull);
    await cubit.close();
  });
  test('manufacturing material navigation remains in its route scope', () {
    expect(ItemRouteScope.manufacturing.listPath, AppRoutes.manufacturingMaterials);
    expect(ItemRouteScope.manufacturing.detailPath(12), contains('/manufacturing/'));
  });
  test('internal sales customer preserves counterpart and registered credit status', () {
    final customer = SalesCustomer.fromJson({'id': 4, 'name': 'Cafe', 'customerNumber': 'INT-F5-C1', 'isInternal': true, 'internalBranchId': 1, 'isWalkIn': false, 'isActive': true, 'defaultCreditTermsDays': 30});
    expect(customer.isInternal, isTrue); expect(customer.internalBranchId, 1); expect(customer.isWalkIn, isFalse); expect(customer.creditTermsDays, 30);
  });
}
