# Cafe System 618 Windows Application

The Flutter Windows desktop application currently supports POS, Orders, Discounts, and Reports with Laravel backend integration for the POS catalog, orders, payments, refunds, and receipts.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Backend tax rates are supplied with each branch and stored on backend orders/receipts. The shared Flutter tax configuration is only a fallback for local/mock data or malformed responses. The old mock-based Menu Management prototype was intentionally removed; the future flow is documented in [../docs/MENU_MANAGEMENT_ARCHITECTURE.md](../docs/MENU_MANAGEMENT_ARCHITECTURE.md).
