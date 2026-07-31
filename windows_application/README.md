# Cafe System 618 Windows Application

The Flutter Windows desktop application supports POS, Orders, Discounts, Reports, and the read-only Menu Management Product Catalog. Menu Management uses the real Laravel Admin Catalog APIs; it contains no mock menu data.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Backend tax rates are supplied with each branch and stored on backend orders/receipts. The shared Flutter tax configuration is only a fallback for local/mock data or malformed responses.

Menu Management routes are `/menu-management` (redirects to `/menu-management/products`), `/menu-management/products`, `/menu-management/products/create`, `/menu-management/products/:productId`, `/menu-management/products/:productId/edit`, and `/menu-management/products/:productId/variants`. Product creation submits one required active Default Variant; general editing never resends or mutates variants. The Variants screen manages base pricing, default selection, archive/restore, and ordering. Branch/channel Price Overrides are deliberately a future UI; modifiers remain Phase 4B.3. POS continues to use the temporary Catalog API.
