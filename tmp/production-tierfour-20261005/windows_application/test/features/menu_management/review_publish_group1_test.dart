import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:windows_application/app/localization/app_locale_cubit.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/assignments/models/menu_assignment_models.dart';
import 'package:windows_application/features/menu_management/review/controllers/menu_review_cubit.dart';
import 'package:windows_application/features/menu_management/review/models/review_models.dart';
import 'package:windows_application/features/menu_management/review/views/menu_review_screen.dart';
import 'package:windows_application/features/pos/models/branch.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  test(
    'initial readiness requests only context, current version, and validation',
    () async {
      final repository = _ReviewRepository();
      final cubit = MenuReviewCubit(repository: repository);

      await cubit.load();

      expect(repository.branchCalls, 1);
      expect(repository.assignmentCalls, 0);
      expect(repository.currentVersionCalls, 1);
      expect(repository.validationCalls, 1);
      expect(cubit.state.validationStatus, ReviewRequestStatus.loaded);
    },
  );

  test(
    'a stale readiness result cannot overwrite a newly selected context',
    () async {
      final repository = _ReviewRepository();
      final Completer<MenuValidationResult> first =
          Completer<MenuValidationResult>();
      repository.validationLoader = (context) => context.branchId == 1
          ? first.future
          : Future<MenuValidationResult>.value(_validation());
      final cubit = MenuReviewCubit(repository: repository);

      final Future<void> firstLoad = cubit.load(branchId: 1);
      await Future<void>.delayed(Duration.zero);
      final Future<void> secondLoad = cubit.selectBranch(2);
      first.complete(_validation(errors: 3, warnings: 5));
      await Future.wait<void>(<Future<void>>[firstLoad, secondLoad]);

      expect(cubit.state.selectedBranch?.id, 2);
      expect(cubit.state.validation?.errorCount, 0);
    },
  );

  testWidgets(
    'renders selling context, workflow tabs, current version, and blocked readiness',
    (tester) async {
      final repository = _ReviewRepository()
        ..result = _validation(errors: 3, warnings: 5);
      await _pump(tester, repository);

      expect(find.text('Review & Publish'), findsAtLeastNWidgets(1));
      expect(find.text('Selling Context'), findsOneWidget);
      expect(find.text('Branch'), findsOneWidget);
      expect(find.text('Sales Channel'), findsOneWidget);
      expect(find.text('Asia/Damascus'), findsOneWidget);
      for (final String tab in <String>[
        'Readiness',
        'Preview',
        'Publish',
        'Versions',
      ]) {
        expect(find.text(tab), findsAtLeastNWidgets(1));
      }
      expect(find.text('Currently Published'), findsOneWidget);
      expect(find.text('Version 12'), findsOneWidget);
      expect(find.text('Needs Attention'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows warning-only, clean, no-version, no-menu, and local readiness error states',
    (tester) async {
      final cases = <_WidgetCase>[
        _WidgetCase(
          repository: _ReviewRepository(),
          expected: 'No issues found for Downtown · POS.',
        ),
        _WidgetCase(
          repository: _ReviewRepository()..result = _validation(warnings: 4),
          expected: '4 warnings to review.',
        ),
        _WidgetCase(
          repository: _ReviewRepository()..current = null,
          expected: 'Not published yet',
        ),
        _WidgetCase(
          repository: _ReviewRepository()..result = _noAssignedMenu(),
          expected: 'No Menus assigned',
        ),
        _WidgetCase(
          repository: _ReviewRepository()
            ..validationLoader = (_) =>
                Future<MenuValidationResult>.error(StateError('offline')),
          expected: 'Could not load readiness results.',
        ),
      ];
      for (final item in cases) {
        await _pump(tester, item.repository);
        expect(find.text(item.expected), findsOneWidget);
      }
    },
  );

  testWidgets(
    'current Version failure stays local and Retry makes one new Version request',
    (tester) async {
      final repository = _ReviewRepository();
      var attempts = 0;
      repository.currentVersionLoader = (_) {
        attempts++;
        return attempts == 1
            ? Future<PublishedMenuVersion?>.error(StateError('offline'))
            : Future<PublishedMenuVersion?>.value(_version());
      };

      await _pump(tester, repository);

      expect(
        find.text('Could not load the current published version.'),
        findsOneWidget,
      );
      expect(repository.currentVersionCalls, 1);
      expect(repository.validationCalls, 1);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(repository.currentVersionCalls, 2);
      expect(repository.validationCalls, 1);
      expect(find.text('Version 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Arabic Review workspace keeps its RTL direction and fits 1280', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(tester, _ReviewRepository(), locale: AppLocaleCubit.arabic);

    expect(
      Directionality.of(tester.element(find.byType(MenuReviewScreen))),
      TextDirection.rtl,
    );
    expect(find.text('سياق البيع'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Readiness workspace fits the supported desktop widths', (
    tester,
  ) async {
    for (final double width in <double>[1280, 1440, 1920]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await _pump(tester, _ReviewRepository());
      expect(tester.takeException(), isNull, reason: '$width px');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'no assigned Menu action opens Assignments with its exact context',
    (tester) async {
      final repository = _ReviewRepository()..result = _noAssignedMenu();
      final router = GoRouter(
        initialLocation: '/review',
        routes: <RouteBase>[
          GoRoute(
            path: '/review',
            builder: (_, _) => BlocProvider<MenuReviewCubit>(
              create: (_) => MenuReviewCubit(repository: repository),
              child: const Scaffold(body: MenuReviewScreen()),
            ),
          ),
          GoRoute(
            path: '/menu-management/assignments',
            builder: (_, state) => Text(
              'Assignments ${state.uri.queryParameters['branchId']} ${state.uri.queryParameters['channel']}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          supportedLocales: AppLocaleCubit.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final action = find.widgetWithText(ElevatedButton, 'Go to Assignments');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Assignments 1 pos'), findsOneWidget);
    },
  );

  testWidgets(
    'Publish blocks errors and allows warnings through confirmation',
    (tester) async {
      final blocked = _ReviewRepository()
        ..result = _validation(errors: 3, warnings: 5);
      await _pump(tester, blocked);
      await tester.tap(find.text('Publish').last);
      await tester.pumpAndSettle();

      expect(find.text('Cannot publish yet'), findsOneWidget);
      expect(find.text('Review Errors'), findsOneWidget);
      expect(blocked.publicationCalls, 0);

      final warnings = _ReviewRepository()..result = _validation(warnings: 4);
      await _pump(tester, warnings);
      await tester.tap(find.text('Publish').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Publish Menu Version'));
      await tester.tap(find.text('Publish Menu Version'));
      await tester.pumpAndSettle();

      expect(find.text('Publish Downtown · POS?'), findsAtLeastNWidgets(1));
      expect(
        find.text('4 warnings remain. You can still publish this version.'),
        findsAtLeastNWidgets(1),
      );
      expect(warnings.publicationCalls, 0);
    },
  );

  testWidgets(
    'Publish success makes one mutation and refreshes Current Version',
    (tester) async {
      final repository = _ReviewRepository();
      await _pump(tester, repository);
      await tester.tap(find.text('Publish').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Publish Menu Version'));
      await tester.tap(find.text('Publish Menu Version'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish Menu Version').last);
      await tester.pumpAndSettle();

      expect(repository.publicationCalls, 1);
      expect(repository.currentVersionCalls, 2);
      expect(find.text('Published successfully'), findsOneWidget);
      expect(find.text('Version 13'), findsOneWidget);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _ReviewRepository repository, {
  Locale? locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<_ReviewRepository>(repository),
      locale: locale,
      supportedLocales: AppLocaleCubit.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: BlocProvider<MenuReviewCubit>(
        create: (_) => MenuReviewCubit(repository: repository),
        child: const Scaffold(body: MenuReviewScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

class _WidgetCase {
  const _WidgetCase({required this.repository, required this.expected});

  final _ReviewRepository repository;
  final String expected;
}

class _ReviewRepository extends BackendMenuCatalogRepository {
  _ReviewRepository()
    : super(
        DioApiClient(
          dio: Dio(BaseOptions(baseUrl: 'http://localhost/api/v1/')),
        ),
      );

  int branchCalls = 0;
  int assignmentCalls = 0;
  int currentVersionCalls = 0;
  int validationCalls = 0;
  int publicationCalls = 0;
  MenuValidationResult result = _validation();
  PublishedMenuVersion? current = _version();
  Future<MenuValidationResult> Function(ReviewContext context)?
  validationLoader;
  Future<PublishedMenuVersion?> Function(ReviewContext context)?
  currentVersionLoader;
  Future<MenuPublicationResult> Function(ReviewContext context)?
  publicationLoader;

  @override
  Future<List<Branch>> listAssignmentBranches() async {
    branchCalls++;
    return const <Branch>[
      Branch(
        id: 1,
        name: 'Downtown',
        currency: 'SYP',
        timezone: 'Asia/Damascus',
        isActive: true,
      ),
      Branch(
        id: 2,
        name: 'Uptown',
        currency: 'SYP',
        timezone: 'Asia/Damascus',
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<MenuAssignment>> listMenuAssignments({
    required int branchId,
    required String channel,
  }) async {
    assignmentCalls++;
    return const <MenuAssignment>[];
  }

  @override
  Future<MenuValidationResult> validateMenuCollection(ReviewContext context) {
    validationCalls++;
    return validationLoader?.call(context) ??
        Future<MenuValidationResult>.value(result);
  }

  @override
  Future<MenuValidationResult> validateMenu(int id, ReviewContext context) =>
      validateMenuCollection(context);

  @override
  Future<MenuPublicationResult> publishMenuScope(ReviewContext context) async {
    publicationCalls++;
    return publicationLoader?.call(context) ?? _publication();
  }

  @override
  Future<PublishedMenuVersion?> getCurrentPublishedVersion(
    ReviewContext context,
  ) async {
    currentVersionCalls++;
    return currentVersionLoader?.call(context) ?? current;
  }
}

MenuValidationResult _validation({int errors = 0, int warnings = 0}) =>
    MenuValidationResult.fromJson(<String, dynamic>{
      'isValid': errors == 0,
      'errorCount': errors,
      'warningCount': warnings,
      'informationCount': 0,
      'errors': List<Map<String, dynamic>>.generate(
        errors,
        (_) => _issue('ERROR'),
      ),
      'warnings': List<Map<String, dynamic>>.generate(
        warnings,
        (_) => _issue('WARNING'),
      ),
      'information': const <Object>[],
    });

MenuValidationResult _noAssignedMenu() =>
    MenuValidationResult.fromJson(<String, dynamic>{
      'isValid': false,
      'errorCount': 1,
      'warningCount': 0,
      'informationCount': 0,
      'errors': <Map<String, dynamic>>[_issue('NO_ASSIGNED_MENU')],
      'warnings': const <Object>[],
      'information': const <Object>[],
    });

Map<String, dynamic> _issue(String code) => <String, dynamic>{
  'severity': code == 'WARNING' ? 'warning' : 'error',
  'code': code,
  'message': 'Message',
  'entityType': 'scope',
  'menuId': 0,
};

PublishedMenuVersion _version() =>
    PublishedMenuVersion.fromJson(<String, dynamic>{
      'id': 1,
      'versionNumber': 12,
      'checksum': 'not-displayed',
      'status': 'current',
      'branchId': 1,
      'channel': 'pos',
      'publishedAt': '2026-08-26T18:30:00+03:00',
      'publicationId': 2,
    });

MenuPublicationResult _publication() =>
    MenuPublicationResult.fromJson(<String, dynamic>{
      'published': true,
      'noChanges': false,
      'publicationId': 3,
      'version': <String, dynamic>{
        'id': 2,
        'versionNumber': 13,
        'checksum': 'not-displayed',
        'status': 'current',
        'branchId': 1,
        'channel': 'pos',
        'publishedAt': '2026-08-26T18:45:00+03:00',
        'publicationId': 3,
      },
      'validation': <String, dynamic>{
        'isValid': true,
        'errorCount': 0,
        'warningCount': 0,
        'informationCount': 0,
        'errors': const <Object>[],
        'warnings': const <Object>[],
        'information': const <Object>[],
      },
    });
