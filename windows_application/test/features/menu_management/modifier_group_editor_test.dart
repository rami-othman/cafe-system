import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/theme/app_theme.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/models/product_catalog_filter.dart';
import 'package:windows_application/features/menu_management/modifiers/controllers/modifier_group_editor_cubit.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_editor_drafts.dart';
import 'package:windows_application/features/menu_management/modifiers/models/modifier_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/products/models/product_editor_draft.dart';
import 'package:windows_application/features/menu_management/modifiers/views/modifier_group_editor_screen.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  test('multi-select create payload serializes every initial option', () {
    final ModifierGroupDraft draft = const ModifierGroupDraft(
      name: ' Add-ons ',
      selectionType: 'multiple',
      maxSelections: '3',
      initialOptions: <ModifierOptionDraft>[
        ModifierOptionDraft(name: ' Extra Shot ', priceDelta: '0.50'),
        ModifierOptionDraft(name: ' Whipped Cream '),
        ModifierOptionDraft(name: ' Caramel Drizzle ', priceDelta: '0.60'),
      ],
    );
    final List<dynamic> options =
        draft.toCreateJson()['options'] as List<dynamic>;

    expect(options.map((option) => option['name']), <String>[
      'Extra Shot',
      'Whipped Cream',
      'Caramel Drizzle',
    ]);
    expect(options[0]['priceDelta'], '0.50');
    expect(options[2]['priceDelta'], '0.60');
  });

  testWidgets(
    'initial options can be added and removed without leaving create mode',
    (tester) async {
      final _EditorRepository repository = _EditorRepository();
      await tester.pumpWidget(
        _app(ModifierGroupEditorCubit(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Initial Options'), findsOneWidget);
      expect(find.byKey(const Key('initial-option-name-0')), findsOneWidget);
      final Finder addOption = find.byKey(
        const Key('add-initial-modifier-option'),
      );
      await tester.ensureVisible(addOption);
      await tester.tap(addOption);
      await tester.pump();
      expect(find.byKey(const Key('initial-option-name-1')), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Option').last);
      await tester.pump();
      expect(find.byKey(const Key('initial-option-name-1')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching required back to optional updates the rule summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(ModifierGroupEditorCubit(repository: _EditorRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Optional'), findsOneWidget);

    final Finder requiredOption = find.text('Required');
    await tester.ensureVisible(requiredOption);
    await tester.tap(requiredOption);
    await tester.pump();
    expect(
      find.textContaining('Customer must choose exactly 1'),
      findsOneWidget,
    );

    final Finder optionalOption = find.text('Optional');
    await tester.ensureVisible(optionalOption);
    await tester.tap(optionalOption);
    await tester.pump();
    expect(find.text('Optional'), findsOneWidget);
    expect(find.textContaining('Customer must choose exactly 1'), findsNothing);
  });

  test('initial options accept signed price adjustments', () async {
    final _EditorRepository repository = _EditorRepository();
    final ModifierGroupEditorCubit cubit = ModifierGroupEditorCubit(
      repository: repository,
    );
    cubit.initializeCreate();
    cubit.updateDraft(
      const ModifierGroupDraft(
        name: 'Milk choices',
        initialOptions: <ModifierOptionDraft>[
          ModifierOptionDraft(name: 'Discounted side', priceDelta: '-0.50'),
        ],
      ),
    );

    await cubit.submit();

    expect(repository.createCalls, 1);
    expect(cubit.state.fieldErrors, isEmpty);
  });

  testWidgets('multi-select count validation is localized in Arabic RTL', (
    tester,
  ) async {
    final ModifierGroupEditorCubit cubit = ModifierGroupEditorCubit(
      repository: _EditorRepository(),
    );
    await tester.pumpWidget(_app(cubit, locale: const Locale('ar')));
    await tester.pumpAndSettle();
    cubit.updateDraft(
      const ModifierGroupDraft(
        name: 'إضافات',
        selectionType: 'multiple',
        maxSelections: '3',
        initialOptions: <ModifierOptionDraft>[
          ModifierOptionDraft(name: 'جرعة إضافية'),
        ],
      ),
    );
    await cubit.submit();
    await tester.pump();

    expect(
      find.text('أضف 3 خيارات نشطة على الأقل أو خفّض الحد الأقصى للاختيارات.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'server validation preserves the draft and duplicate submits are ignored',
    () async {
      final _EditorRepository repository = _EditorRepository(
        failure: const ApiException(
          message: 'invalid group',
          validationErrors: <String, List<String>>{
            'modifierGroup': <String>['invalid selection rules'],
          },
        ),
      );
      final ModifierGroupEditorCubit cubit = ModifierGroupEditorCubit(
        repository: repository,
      );
      cubit.initializeCreate();
      const ModifierGroupDraft draft = ModifierGroupDraft(
        name: 'Add-ons',
        initialOptions: <ModifierOptionDraft>[
          ModifierOptionDraft(name: 'Extra Shot'),
        ],
      );
      cubit.updateDraft(draft);
      await Future.wait(<Future<void>>[cubit.submit(), cubit.submit()]);

      expect(repository.createCalls, 1);
      expect(cubit.state.draft, draft);
      expect(cubit.state.formErrorCode, 'groupSave');
    },
  );
}

Widget _app(
  ModifierGroupEditorCubit cubit, {
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: AppTheme.lightTheme,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: BlocProvider<ModifierGroupEditorCubit>.value(
      value: cubit,
      child: const ModifierGroupEditorScreen(),
    ),
  ),
);

class _EditorRepository extends MenuCatalogRepository {
  _EditorRepository({this.failure});

  final Object? failure;
  int createCalls = 0;

  @override
  Future<CatalogPage<ProductSummary>> listProducts({
    required ProductCatalogFilter filter,
    required int page,
    int perPage = 20,
  }) => throw UnimplementedError();

  @override
  Future<ProductDetail> getProduct(
    int productId, {
    bool includeArchived = false,
  }) => throw UnimplementedError();

  @override
  Future<ProductDetail> createProduct(ProductEditorDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ProductDetail> updateProductGeneral(
    int productId,
    ProductEditorDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<CatalogPage<CatalogCategory>> listCategories({int perPage = 100}) =>
      throw UnimplementedError();

  @override
  Future<CatalogPage<ReportingCategory>> listReportingCategories({
    int perPage = 100,
  }) => throw UnimplementedError();

  @override
  Future<CatalogPage<KitchenStation>> listKitchenStations({
    int perPage = 100,
  }) => throw UnimplementedError();

  @override
  Future<ModifierGroupRecord> createModifierGroup(
    ModifierGroupDraft draft,
  ) async {
    createCalls++;
    if (failure != null) throw failure!;
    return ModifierGroupRecord.fromJson(<String, dynamic>{
      'id': 1,
      'name': draft.name,
      'groupType': 'choice',
      'selectionType': draft.selectionType,
      'isRequired': draft.isRequired,
      'minSelections': int.parse(draft.minSelections),
      'maxSelections': int.parse(draft.maxSelections),
      'allowQuantity': draft.allowQuantity,
      'isActive': true,
      'sortOrder': 0,
      'optionCount': draft.createOptions.length,
      'options': draft.createOptions
          .asMap()
          .entries
          .map(
            (entry) => <String, dynamic>{
              'id': entry.key + 1,
              'name': entry.value.name,
              'priceDelta': entry.value.priceDelta,
              'isDefault': false,
              'isActive': true,
              'isAvailable': true,
              'sortOrder': entry.key,
            },
          )
          .toList(),
    });
  }
}
