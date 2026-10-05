import 'pos_menu_runtime_models.dart';
import 'pos_product.dart';

/// Presentation-only projection of the v1 runtime contract. It deliberately
/// preserves every backend list order and never reads Catalog data.
class PosPublishedMenuPresenter {
  const PosPublishedMenuPresenter(this.runtime, {required this.languageCode});

  final PosPublishedRuntimeMenu runtime;
  final String languageCode;

  List<PosStaticMenu> get menus => runtime.menu.menus
      .where((PosStaticMenu menu) => _menuIsAvailable(menu.id))
      .toList(growable: false);

  List<PosProduct> productsForMenu(PosStaticMenu menu) => _deduplicate(
    menu.sections.expand(
      (PosStaticSection section) => productsForSection(section),
    ),
  );

  List<PosProduct> productsForSection(PosStaticSection section) => section
      .products
      .where((PosProductPlacement placement) => placement.isVisible)
      .map(_productForPlacement)
      .toList(growable: false);

  PosProduct _productForPlacement(PosProductPlacement placement) {
    final PosRuntimePlacementState? placementState = runtime
        .runtimeForPlacement(placement.placementId);
    final List<PosPublishedVariant> sellableVariants = placement.variants
        .where(
          (PosPublishedVariant variant) =>
              runtime
                  .runtimeForVariant(
                    placementId: placement.placementId,
                    variantId: variant.id,
                  )
                  ?.isSellable ??
              true,
        )
        .toList(growable: false);
    final PosPublishedVariant? displayVariant = _displayVariant(
      placement,
      sellableVariants,
    );
    final bool placementSellable = placementState?.isSellable ?? true;
    final bool isAvailable =
        placementSellable &&
        sellableVariants.isNotEmpty &&
        displayVariant != null;
    final String? reason =
        placementState?.reason ??
        (displayVariant == null
            ? 'not_sellable'
            : runtime
                  .runtimeForVariant(
                    placementId: placement.placementId,
                    variantId: displayVariant.id,
                  )
                  ?.reason);
    return PosProduct(
      id: 'published-${runtime.version.id}-${placement.placementId}',
      backendId: placement.productId,
      name: placement.name.resolve(languageCode),
      category: '',
      size: displayVariant?.name.resolve(languageCode) ?? '',
      price: displayVariant?.effectivePrice ?? 0,
      isAvailable: isAvailable,
      publishedMenuVersionId: runtime.version.id,
      placementId: placement.placementId,
      defaultVariantId: displayVariant?.id,
      variants: placement.variants,
      modifierGroups: placement.modifierGroups,
      sellableVariantIds: sellableVariants
          .map((PosPublishedVariant variant) => variant.id)
          .toList(growable: false),
      unavailabilityReason: reason,
      currencyCode: runtime.context.currency,
      imageUrl: placement.imageUrl,
      description: placement.description.resolve(languageCode),
    );
  }

  PosPublishedVariant? _displayVariant(
    PosProductPlacement placement,
    List<PosPublishedVariant> sellableVariants,
  ) {
    final Iterable<PosPublishedVariant> valid = sellableVariants.where(
      (PosPublishedVariant variant) => variant.effectivePrice != null,
    );
    for (final PosPublishedVariant variant in valid) {
      if (variant.isDefault) return variant;
    }
    return valid.isEmpty ? null : valid.first;
  }

  bool _menuIsAvailable(int menuId) {
    for (final PosRuntimeMenuState state
        in runtime.runtime?.menus ?? const <PosRuntimeMenuState>[]) {
      if (state.menuId == menuId) return state.isScheduledAvailable;
    }
    return true;
  }

  List<PosProduct> _deduplicate(Iterable<PosProduct> products) {
    final Set<int> seenPlacements = <int>{};
    return products
        .where((PosProduct product) => seenPlacements.add(product.placementId!))
        .toList(growable: false);
  }
}
