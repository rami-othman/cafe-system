import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu_management/modifiers/controllers/modifier_library_cubit.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_editor_drafts.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_models.dart';
import 'package:windows_application/features/menu_management/modifiers/views/modifier_library_screen.dart';
import 'package:windows_application/features/menu_management/modifiers/widgets/modifier_presentation.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  test('signed price adjustments validate, serialize, and parse correctly', () {
    for (final String value in <String>[
      '-5.00',
      '-0.50',
      '0',
      '0.00',
      '0.75',
      '2.50',
    ]) {
      expect(isValidModifierPriceAdjustment(value), isTrue, reason: value);
    }
    for (final String value in <String>['abc', '--', '1..5', '0.001']) {
      expect(isValidModifierPriceAdjustment(value), isFalse, reason: value);
    }

    const ModifierOptionDraft draft = ModifierOptionDraft(
      name: 'Discounted side',
      priceDelta: '-0.50',
    );
    expect(draft.toJson()['priceDelta'], '-0.50');
    expect(
      ModifierOptionRecord.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Discounted side',
        'priceDelta': '-0.50',
        'isDefault': false,
        'isActive': true,
        'isAvailable': true,
        'sortOrder': 0,
      }).priceDelta,
      -0.5,
    );
  });

  testWidgets('signed price adjustments display with their correct sign', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        Builder(
          builder: (context) => Column(
            children: <Widget>[
              Text(modifierPriceAdjustmentLabel(context, 0.75)),
              Text(modifierPriceAdjustmentLabel(context, 0)),
              Text(modifierPriceAdjustmentLabel(context, -0.50)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'+$0.75'), findsOneWidget);
    expect(find.text('No extra charge'), findsOneWidget);
    expect(find.text(r'-$0.50'), findsOneWidget);
    expect(find.text(r'+$-0.50'), findsNothing);
  });

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
      expect(find.byTooltip('Move Up'), findsNothing);
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
    expect(find.textContaining('same option'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rule summary uses domain values and singular/plural wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        Builder(
          builder: (context) => Column(
            children: <Widget>[
              Text(
                modifierRuleSummaryForFields(
                  context,
                  selectionType: 'single',
                  isRequired: true,
                  minSelections: 1,
                  maxSelections: 1,
                  allowQuantity: false,
                ),
              ),
              Text(
                modifierRuleSummaryForFields(
                  context,
                  selectionType: 'multiple',
                  isRequired: false,
                  minSelections: 0,
                  maxSelections: 1,
                  allowQuantity: false,
                ),
              ),
              Text(
                modifierRuleSummaryForFields(
                  context,
                  selectionType: 'multiple',
                  isRequired: false,
                  minSelections: 0,
                  maxSelections: 2,
                  allowQuantity: false,
                ),
              ),
              Text(
                modifierRuleSummaryForFields(
                  context,
                  selectionType: 'multiple',
                  isRequired: true,
                  minSelections: 1,
                  maxSelections: 3,
                  allowQuantity: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer must choose exactly 1 option.'), findsOneWidget);
    expect(
      find.text('Optional — customer may choose 1 option.'),
      findsOneWidget,
    );
    expect(
      find.text('Optional — customer may choose up to 2 options.'),
      findsOneWidget,
    );
    expect(
      find.text('Customer must choose at least 1 and up to 3 options.'),
      findsOneWidget,
    );
    expect(find.textContaining('option(s)'), findsNothing);
  });

  testWidgets('library/detail helper and assignment summary share the rule', (
    tester,
  ) async {
    final ModifierGroupRecord group =
        ModifierGroupRecord.fromJson(<String, dynamic>{
          'id': 8,
          'name': 'Add-ons',
          'selectionType': 'multiple',
          'isRequired': false,
          'minSelections': 0,
          'maxSelections': 5,
          'allowQuantity': true,
          'isActive': true,
          'sortOrder': 0,
          'optionCount': 3,
        });
    await tester.pumpWidget(
      _localized(
        Builder(
          builder: (context) {
            final String librarySummary = modifierRuleSummary(context, group);
            final String detailSummary = modifierRuleSummaryForFields(
              context,
              selectionType: group.selectionType,
              isRequired: group.isRequired,
              minSelections: group.minSelections,
              maxSelections: group.maxSelections,
              allowQuantity: group.allowQuantity,
            );
            return Column(
              children: <Widget>[Text(librarySummary), Text(detailSummary)],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Optional — customer may choose up to 5 options. '
        'The same option may be added more than once.',
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('rule summary pluralization renders in Arabic', (tester) async {
    await tester.pumpWidget(
      _localized(
        Builder(
          builder: (context) => Text(
            modifierRuleSummaryForFields(
              context,
              selectionType: 'multiple',
              isRequired: false,
              minSelections: 0,
              maxSelections: 2,
              allowQuantity: false,
            ),
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('خيارين'), findsOneWidget);
    expect(find.textContaining('option(s)'), findsNothing);
  });

  testWidgets('reorder refuses to start while search is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(ModifierLibraryCubit(repository: _ModifierRepository())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'milk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reorder'));
    await tester.pump();

    expect(find.text('Done'), findsNothing);
    expect(
      find.text('Clear search and filters before reordering Modifier Groups.'),
      findsOneWidget,
    );
  });

  test(
    'reorder submits a complete contiguous set after loading every page',
    () async {
      final _ModifierRepository repository = _ModifierRepository(
        groups: <ModifierGroupRecord>[
          _group(1, 'One', 0),
          _group(2, 'Two', 1),
          _group(3, 'Three', 2),
        ],
      );
      final ModifierLibraryCubit cubit = ModifierLibraryCubit(
        repository: repository,
      );
      await cubit.load();
      expect(await cubit.prepareReorder(), isTrue);
      await cubit.move(cubit.state.groups[0], 1);

      expect(repository.reorders.single.map((item) => item.id), <int>[2, 1, 3]);
      expect(repository.reorders.single.map((item) => item.sortOrder), <int>[
        0,
        1,
        2,
      ]);
    },
  );
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
  _ModifierRepository({List<ModifierGroupRecord>? groups})
    : groups =
          groups ??
          <ModifierGroupRecord>[
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

  final List<ModifierGroupRecord> groups;
  final List<List<ModifierReorderItem>> reorders =
      <List<ModifierReorderItem>>[];

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
    meta: CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: groups.length,
    ),
  );

  @override
  Future<void> reorderModifierGroups(List<ModifierReorderItem> items) async {
    reorders.add(items);
  }
}

ModifierGroupRecord _group(int id, String name, int sortOrder) =>
    ModifierGroupRecord.fromJson(<String, dynamic>{
      'id': id,
      'name': name,
      'groupType': 'choice',
      'selectionType': 'single',
      'isRequired': false,
      'minSelections': 0,
      'maxSelections': 1,
      'allowQuantity': false,
      'isActive': true,
      'sortOrder': sortOrder,
      'optionCount': 1,
      'options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': id * 10,
          'name': '$name option',
          'priceDelta': 0,
          'isDefault': false,
          'isActive': true,
          'sortOrder': 0,
        },
      ],
    });
