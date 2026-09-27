import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';

class PurchaseRouteScope {
  const PurchaseRouteScope._(this.isManufacturing);
  static const finance = PurchaseRouteScope._(false);
  static const manufacturing = PurchaseRouteScope._(true);
  final bool isManufacturing;
  static PurchaseRouteScope of(BuildContext context) => GoRouterState.of(context).uri.path.startsWith('/manufacturing') ? manufacturing : finance;
  String get listPath => isManufacturing ? AppRoutes.manufacturingPurchases : AppRoutes.financePurchases;
  String get createPath => '$listPath/new';
  String detailPath(int id) => '$listPath/$id';
  String editPath(int id) => '$listPath/$id/edit';
  String receivePath(int id) => '$listPath/$id/receive';
  String get receiptsPath => isManufacturing ? AppRoutes.manufacturingPurchaseReceipts : AppRoutes.financePurchaseReceipts;
}
