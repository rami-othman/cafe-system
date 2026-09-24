import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/recipes/models/recipe_models.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';

void main() {
  test('variant recipe keeps only explicit override components editable', () {
    final recipe = VariantRecipe.fromJson(<String, dynamic>{
      'variantId': 7,
      'hasOverride': false,
      'source': 'product',
      'components': const <Object>[],
      'overrideComponents': const <Object>[],
      'effectiveComponents': <Map<String, dynamic>>[
        <String, dynamic>{
          'materialId': 4,
          'quantity': '1.250000',
          'unitCode': 'kg',
        },
      ],
    });
    expect(recipe.source, RecipeSource.product);
    expect(recipe.components, isEmpty);
    expect(recipe.overrideComponents, isEmpty);
    expect(recipe.effectiveComponents.single.quantity, '1.250000');
  });

  test('old variant recipe response remains editable compatibility data', () {
    final recipe = VariantRecipe.fromJson(<String, dynamic>{
      'variantId': 7,
      'components': <Map<String, dynamic>>[
        <String, dynamic>{
          'materialId': 4,
          'quantity': '0.125000',
          'unitCode': 'kg',
        },
      ],
    });
    expect(recipe.source, RecipeSource.none);
    expect(recipe.hasOverride, isTrue);
    expect(recipe.components.single.quantity, '0.125000');
  });

  test('product recipe parses decimal strings unchanged', () {
    final recipe = ProductRecipe.fromJson(<String, dynamic>{
      'productId': 2,
      'components': <Map<String, dynamic>>[
        <String, dynamic>{
          'materialId': 4,
          'quantity': '2.000001',
          'unitCode': 'g',
        },
      ],
    });
    expect(recipe.productId, 2);
    expect(recipe.components.single.quantity, '2.000001');
  });

  test(
    'catalog and review summaries retain legacy aliases and parse additions',
    () {
      final base = <String, dynamic>{
        'id': 7,
        'name': 'Regular',
        'nameAr': null,
        'nameEn': 'Regular',
        'sku': null,
        'barcode': null,
        'basePrice': '1.00',
        'costPrice': null,
        'isDefault': true,
        'isActive': true,
        'sortOrder': 0,
        'recipeConfigured': true,
        'recipeComponentCount': 2,
      };
      final old = ProductVariant.fromJson(base);
      final current = ProductVariant.fromJson(<String, dynamic>{
        ...base,
        'effectiveRecipeConfigured': true,
        'effectiveRecipeComponentCount': 2,
        'recipeSource': 'product',
        'hasRecipeOverride': false,
      });
      expect(old.recipeConfigured, isTrue);
      expect(old.effectiveRecipeConfigured, isNull);
      expect(current.recipeSource, 'product');
      expect(current.hasRecipeOverride, isFalse);

      final review = ResolvedVariant.fromJson(<String, dynamic>{
        ...base,
        'effectivePrice': '1.00',
        'isScheduledAvailable': true,
        'isOperationallyAvailable': true,
        'isSellable': true,
        'unavailabilityReasons': const <Object>[],
        'effectiveRecipeConfigured': true,
        'effectiveRecipeComponentCount': 2,
        'recipeSource': 'product',
        'hasRecipeOverride': false,
      });
      expect(review.recipeConfigured, isTrue);
      expect(review.recipeSource, 'product');
      expect(review.hasRecipeOverride, isFalse);
    },
  );
}
