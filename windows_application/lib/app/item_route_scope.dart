import 'app_router.dart';

class ItemRouteScope {
  const ItemRouteScope._(this.isManufacturing);
  static const inventory = ItemRouteScope._(false);
  static const manufacturing = ItemRouteScope._(true);
  final bool isManufacturing;
  String get listPath => isManufacturing ? AppRoutes.manufacturingMaterials : AppRoutes.inventoryItems;
  String get createPath => isManufacturing ? AppRoutes.manufacturingMaterialCreate : AppRoutes.inventoryItemCreate;
  String detailPath(int id) => isManufacturing ? AppRoutes.manufacturingMaterialDetailPath(id) : AppRoutes.inventoryItemDetailPath(id);
  String editPath(int id) => isManufacturing ? AppRoutes.manufacturingMaterialEditPath(id) : AppRoutes.inventoryItemEditPath(id);
}
