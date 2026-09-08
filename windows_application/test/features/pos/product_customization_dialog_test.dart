import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/pos/models/pos_menu_runtime_models.dart';
import 'package:windows_application/features/pos/models/pos_product.dart';
import 'package:windows_application/features/pos/models/product_customization.dart';
import 'package:windows_application/features/pos/widgets/product_customization_dialog.dart';

void main() {
  testWidgets(
    'submits the selected published variant and its effective price',
    (WidgetTester tester) async {
      ProductCustomization? submitted;
      await _pumpDialog(
        tester,
        onSubmit: (ProductCustomization customization) async {
          submitted = customization;
          return false;
        },
      );

      await tester.tap(find.byKey(const ValueKey<String>('published-variant-31')));
      await tester.pump();
      await tester.tap(find.text('Add to Order'));
      await tester.pump();

      expect(submitted, isNotNull);
      expect(submitted!.publishedVariantId, 31);
      expect(submitted!.publishedUnitPrice, 5.5);
    },
  );

  testWidgets(
    'shows only sellable published variants',
    (WidgetTester tester) async {
      await _pumpDialog(tester);

      expect(
        find.byKey(const ValueKey<String>('published-variant-30')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('published-variant-31')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('published-variant-32')),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  Future<bool> Function(ProductCustomization customization)? onSubmit,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductCustomizationDialog(
          product: _publishedProduct,
          onSubmit: onSubmit,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const PosProduct _publishedProduct = PosProduct(
  id: 'published-12-40',
  backendId: 25,
  name: 'Latte',
  category: 'Coffee',
  size: 'Regular',
  price: 4,
  isAvailable: true,
  publishedMenuVersionId: 12,
  placementId: 40,
  defaultVariantId: 30,
  variants: <PosPublishedVariant>[
    PosPublishedVariant(
      id: 30,
      name: PosLocalizedText(defaultValue: 'Regular'),
      sku: null,
      barcode: null,
      sortOrder: 0,
      isDefault: true,
      basePrice: 4,
      effectivePrice: 4,
    ),
    PosPublishedVariant(
      id: 31,
      name: PosLocalizedText(defaultValue: 'Large'),
      sku: null,
      barcode: null,
      sortOrder: 1,
      isDefault: false,
      basePrice: 5.5,
      effectivePrice: 5.5,
    ),
    PosPublishedVariant(
      id: 32,
      name: PosLocalizedText(defaultValue: 'Sold out'),
      sku: null,
      barcode: null,
      sortOrder: 2,
      isDefault: false,
      basePrice: 7,
      effectivePrice: 7,
    ),
  ],
  sellableVariantIds: <int>[30, 31],
  currencyCode: 'SYP',
);
