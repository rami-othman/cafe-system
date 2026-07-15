import '../models/menu_activity.dart';
import '../models/menu_category.dart';
import '../models/menu_kpis.dart';
import '../models/menu_product.dart';
import '../models/modifier_group.dart';
import '../models/product_variant.dart';

abstract interface class MenuRepository {
  Future<List<MenuCategory>> getCategories();
  Future<List<MenuProduct>> getProducts();
  Future<List<ProductVariant>> getProductVariants();
  Future<List<ModifierGroup>> getModifierGroups();
  Future<List<MenuActivity>> getRecentActivities();
  Future<MenuKpis> getMenuKpis();
}
