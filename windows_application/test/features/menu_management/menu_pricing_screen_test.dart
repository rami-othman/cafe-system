import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_filter.dart';
import 'package:windows_application/features/menu_management/menus/models/menu_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/pricing/controllers/menu_pricing_cubit.dart';
import 'package:windows_application/features/menu_management/pricing/models/menu_price_adjustment_models.dart';
import 'package:windows_application/features/menu_management/pricing/models/menu_pricing_models.dart';
import 'package:windows_application/features/menu_management/pricing/views/menu_pricing_screen.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  for (final scenario in <_LocaleScenario>[
    const _LocaleScenario(
      Locale('en'),
      'A very long English menu label that must remain contained in the pricing context selector',
      'A very long English branch label that must remain contained in the pricing context selector',
      'Open reviewed results',
      'Review price adjustment',
    ),
    const _LocaleScenario(
      Locale('ar'),
      'قائمة عربية طويلة جداً يجب أن تبقى ضمن محدد سياق تسعير القائمة دون تجاوز المساحة المتاحة',
      'فرع عربي طويل جداً يجب أن يبقى ضمن محدد سياق تسعير القائمة دون تجاوز المساحة المتاحة',
      'فتح النتائج المُراجعة',
      'مراجعة تعديل السعر',
    ),
  ]) {
    testWidgets(
      '${scenario.locale.languageCode} context bar and review dialog contain long labels',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _ScreenRepository(
          menuName: scenario.menuName,
          branchName: scenario.branchName,
        );
        final cubit = MenuPricingCubit(repository: repository);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          MaterialApp(
            locale: scenario.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: MenuPricingScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(scenario.menuName), findsOneWidget);
        await tester.tap(
          find
              .byWidgetPredicate(
                (widget) => widget is DropdownButtonFormField<int>,
              )
              .first,
        );
        await tester.pumpAndSettle();
        _expectNoLayoutException(tester);
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();

        expect(
          await cubit.previewBulk(
            operation: 'fixed_increase',
            amount: '1',
            roundingMode: 'no_rounding',
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(scenario.openReview));
        await tester.tap(find.text(scenario.openReview));
        await tester.pumpAndSettle();

        expect(find.text(scenario.reviewTitle), findsOneWidget);
        if (scenario.locale.languageCode == 'en') {
          final rawCalculation = find.text('Raw calculation');
          await tester.dragUntilVisible(
            rawCalculation,
            find.byType(ListView).last,
            const Offset(0, -240),
          );
          expect(rawCalculation, findsOneWidget);
          final configurationEffect = find.text('Configuration effect');
          await tester.dragUntilVisible(
            configurationEffect,
            find.byType(ListView).last,
            const Offset(0, -240),
          );
          expect(configurationEffect, findsOneWidget);
          final reviewedResults = find.text('I have reviewed these results.');
          await tester.dragUntilVisible(
            reviewedResults,
            find.byType(ListView).last,
            const Offset(0, -240),
          );
          expect(reviewedResults, findsOneWidget);
        }
        _expectNoLayoutException(tester);
      },
    );
  }

  testWidgets('bulk adjustment dialog remains usable on a narrow desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = MenuPricingCubit(
      repository: _ScreenRepository(menuName: 'Menu', branchName: 'Downtown'),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: MenuPricingScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final adjustAll = find.text('Adjust All Prices');
    await tester.ensureVisible(adjustAll);
    await tester.tap(adjustAll);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    _expectNoLayoutException(tester);
  });
}

void _expectNoLayoutException(WidgetTester tester) {
  final exceptions = <Object>[];
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    exceptions.add(exception!);
  }
  expect(exceptions, isEmpty, reason: 'Flutter reported a layout exception.');
}

class _LocaleScenario {
  const _LocaleScenario(
    this.locale,
    this.menuName,
    this.branchName,
    this.openReview,
    this.reviewTitle,
  );
  final Locale locale;
  final String menuName, branchName, openReview, reviewTitle;
}

class _ScreenRepository extends MenuCatalogRepository {
  _ScreenRepository({required this.menuName, required this.branchName});
  final String menuName, branchName;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<CatalogPage<MenuRecord>> listMenus({
    required MenuFilter filter,
    required int page,
    int perPage = 20,
  }) async => CatalogPage<MenuRecord>(
    items: <MenuRecord>[
      MenuRecord.fromJson(<String, dynamic>{
        'id': 1,
        'name': menuName,
        'nameAr': menuName,
        'nameEn': menuName,
        'status': 'active',
      }),
    ],
    meta: const CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 100,
      total: 1,
    ),
  );

  @override
  Future<List<Branch>> listAssignmentBranches() async => <Branch>[
    Branch(
      id: 2,
      name: branchName,
      currency: 'SYP',
      timezone: 'Asia/Damascus',
      isActive: true,
    ),
  ];

  @override
  Future<CatalogPage<CatalogCategory>> listCategories({
    int perPage = 100,
  }) async => const CatalogPage<CatalogCategory>(
    items: <CatalogCategory>[],
    meta: CatalogPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 100,
      total: 0,
    ),
  );

  @override
  Future<MenuPricingOverview> getMenuPricingOverview({
    required int menuId,
    required int branchId,
    required String channel,
    String search = '',
    int? categoryId,
    int page = 1,
    int perPage = 25,
  }) async => MenuPricingOverview.fromJson(<String, dynamic>{
    'context': <String, dynamic>{
      'menuId': menuId,
      'branchId': branchId,
      'channel': channel,
      'currency': 'SYP',
    },
    'items': const <dynamic>[],
    'pagination': <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'total': 0,
    },
    'scope': const <String, dynamic>{
      'adjustableVariantCount': 1,
      'excludedVariantCount': 0,
    },
  });

  @override
  Future<MenuPriceAdjustment> previewMenuPriceAdjustment(
    int menuId,
    Map<String, dynamic> request,
  ) async => MenuPriceAdjustment.fromJson(<String, dynamic>{
    'id': 44,
    'status': 'previewed',
    'fingerprint': 'a' * 64,
    'context': <String, dynamic>{
      'menuId': menuId,
      'branchId': request['branchId'],
      'channel': request['channel'],
    },
    'operation': 'manual_changes',
    'roundingMode': 'no_rounding',
    'summary': const <String, dynamic>{'oppositeDirectionCount': 0},
    'items': <dynamic>[
      <String, dynamic>{
        'variantId': 10,
        'productName':
            'A long product name that remains completely readable in the review dialog',
        'productNameAr':
            'اسم منتج عربي طويل يبقى مقروءاً بالكامل داخل نافذة مراجعة التسعير',
        'productNameEn':
            'A long product name that remains completely readable in the review dialog',
        'variantName': 'Regular',
        'variantNameAr': 'الحجم العادي',
        'variantNameEn': 'Regular',
        'action': 'set',
        'originalEffectivePrice': '10.00',
        'originalSource': 'base',
        'rawCalculatedPrice': '12.00',
        'finalNewPrice': '12.00',
        'finalSource': 'menu',
        'difference': '2.00',
        'finalMovement': 'increase',
        'oppositeDirection': false,
        'configurationEffect': 'create_override',
        'hadMenuOverride': false,
      },
    ],
  });
}
