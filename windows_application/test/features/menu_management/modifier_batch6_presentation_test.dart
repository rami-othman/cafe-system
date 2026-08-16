import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu_management/modifiers/controllers/modifier_library_cubit.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_models.dart';
import 'package:windows_application/features/menu_management/modifiers/views/modifier_library_screen.dart';
import 'package:windows_application/features/menu_management/modifiers/widgets/modifier_presentation.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('modifier library presents compact rows and reorder mode', (
    tester,
  ) async {
    for (final double width in <double>[1280, 1440, 1920]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final _ModifierRepository repository = _ModifierRepository();
      await tester.pumpWidget(
        _app(
          ModifierLibraryCubit(repository: repository),
          screenKey: ValueKey<double>(width),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modifier Library'), findsOneWidget);
      expect(find.text('Milk Type'), findsOneWidget);
      expect(find.textContaining('4 options'), findsOneWidget);
      expect(find.text('Whole Milk'), findsOneWidget);
      expect(find.text('+ 1 more'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Reorder'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(find.byTooltip('Move Up'), findsWidgets);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('modifier copy and rule summary are localized in Arabic RTL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _app(
        ModifierLibraryCubit(repository: _ModifierRepository()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مكتبة المعدلات'), findsOneWidget);
    expect(find.text('نشط'), findsWidgets);
    expect(find.textContaining('يجب على العميل'), findsOneWidget);
    expect(find.textContaining('Customer must choose'), findsNothing);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('rule summary exposes quantity behavior and long copy safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        Builder(
          builder: (context) => SizedBox(
            width: 320,
            child: Text(
              modifierRuleSummaryForFields(
                context,
                selectionType: 'multiple',
                isRequired: false,
                minSelections: 0,
                maxSelections: 3,
                allowQuantity: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Optional'), findsOneWidget);
    expect(find.textContaining('same Option'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  ModifierLibraryCubit cubit, {
  Locale locale = const Locale('en'),
  Key? screenKey,
}) => _localized(
  BlocProvider<ModifierLibraryCubit>.value(
    value: cubit,
    child: ModifierLibraryScreen(key: screenKey),
  ),
  locale: locale,
);

Widget _localized(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );

class _ModifierRepository extends MenuCatalogRepository {
  final List<ModifierGroupRecord> groups = <ModifierGroupRecord>[
    ModifierGroupRecord.fromJson(<String, dynamic>{
      'id': 1,
      'name': 'Milk Type',
      'nameEn': 'Milk Type',
      'groupType': 'choice',
      'selectionType': 'single',
      'isRequired': true,
      'minSelections': 1,
      'maxSelections': 1,
      'allowQuantity': false,
      'isActive': true,
      'sortOrder': 0,
      'optionCount': 4,
      'activeOptionCount': 4,
      'options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 11,
          'name': 'Whole Milk',
          'priceDelta': 0,
          'isDefault': true,
          'isActive': true,
          'sortOrder': 0,
        },
        <String, dynamic>{
          'id': 12,
          'name': 'Oat Milk',
          'priceDelta': 0.5,
          'isDefault': false,
          'isActive': true,
          'sortOrder': 1,
        },
        <String, dynamic>{
          'id': 13,
          'name': 'Almond Milk',
          'priceDelta': 0.5,
          'isDefault': false,
          'isActive': true,
          'sortOrder': 2,
        },
      ],
    }),
  ];

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) async => throw UnimplementedError();

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) async => throw UnimplementedError();

  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) async => throw UnimplementedError();

  @override
  Future<CatalogPage<CatalogCategory>> listCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogPage<ModifierGroupRecord>> listModifierGroups({
    required ModifierGroupFilter filter,
    required int page,
    int perPage = 20,
  }) async => CatalogPage<ModifierGroupRecord>(
    items: groups,
    meta: const CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 1,
    ),
  );
}
