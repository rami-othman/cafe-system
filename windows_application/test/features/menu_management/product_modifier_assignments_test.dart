import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_models.dart';
import 'package:windows_application/features/menu_management/products/controllers/product_modifier_assignments_cubit.dart';
import 'package:windows_application/features/menu_management/products/models/product_modifier_assignment.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  final json = <String, dynamic>{
    'id': 7,
    'name': 'Milk',
    'nameAr': 'حليب',
    'nameEn': 'Milk',
    'groupType': 'choice',
    'selectionType': 'multiple',
    'isActive': true,
    'isRequired': false,
    'minSelections': 0,
    'maxSelections': 3,
    'allowQuantity': false,
    'sortOrder': 2,
    'activeOptionCount': 3,
    'isRequiredOverride': true,
    'minSelectionsOverride': 1,
    'maxSelectionsOverride': null,
    'allowQuantityOverride': true,
  };

  test(
    'assignment resolves library defaults and serializes only sync fields',
    () {
      final assignment = ProductModifierAssignment.fromJson(json);
      expect(assignment.effectiveIsRequired, isTrue);
      expect(assignment.effectiveMinSelections, 1);
      expect(assignment.effectiveMaxSelections, 3);
      expect(assignment.effectiveAllowQuantity, isTrue);
      expect(assignment.toSyncJson(), <String, dynamic>{
        'modifierGroupId': 7,
        'sortOrder': 2,
        'isRequiredOverride': true,
        'minSelectionsOverride': 1,
        'maxSelectionsOverride': null,
        'allowQuantityOverride': true,
      });
    },
  );

  test('clearing overrides inherits all library defaults', () {
    final assignment = ProductModifierAssignment.fromJson(json).copyWith(
      clearRequired: true,
      clearMinimum: true,
      clearMaximum: true,
      clearAllowQuantity: true,
    );
    expect(assignment.effectiveIsRequired, isFalse);
    expect(assignment.effectiveMinSelections, 0);
    expect(assignment.effectiveMaxSelections, 3);
    expect(assignment.effectiveAllowQuantity, isFalse);
  });

  test('manager rule summary hides persistence fields', () {
    final assignment = ProductModifierAssignment.fromJson(json);
    expect(
      assignment.managerRuleSummary,
      'Customer must choose at least 1 and up to 3 options.',
    );
  });

  test(
    'load does not emit after the Cubit is closed during navigation',
    () async {
      final _ClosedLoadRepository repository = _ClosedLoadRepository();
      final ProductModifierAssignmentsCubit cubit =
          ProductModifierAssignmentsCubit(repository: repository);
      final Future<void> load = cubit.load(11);

      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      repository.productCompleter.complete(_product());

      await load;
    },
  );
}

class _ClosedLoadRepository extends MenuCatalogRepository {
  final Completer<ProductDetail> productCompleter = Completer<ProductDetail>();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) => productCompleter.future;

  @override
  Future<List<ProductModifierAssignment>> getProductModifierAssignments(
    int productId,
  ) async => <ProductModifierAssignment>[];

  @override
  Future<CatalogPage<ModifierGroupRecord>> listModifierGroups({
    required ModifierGroupFilter filter,
    required int page,
    int perPage = 20,
  }) async => const CatalogPage<ModifierGroupRecord>(
    items: <ModifierGroupRecord>[],
    meta: CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 100,
      total: 0,
    ),
  );
}

ProductDetail _product() => ProductDetail.fromJson(<String, dynamic>{
  'id': 11,
  'name': 'Latte',
  'productType': 'standard',
  'isActive': true,
  'category': null,
  'reportingCategory': null,
  'kitchenStation': null,
  'defaultVariant': null,
  'variantCount': 0,
  'modifierGroupCount': 0,
  'descriptionAr': null,
  'descriptionEn': null,
  'isStockTracked': false,
  'sortOrder': 0,
  'variants': <Map<String, dynamic>>[],
  'modifierGroups': <Map<String, dynamic>>[],
});
