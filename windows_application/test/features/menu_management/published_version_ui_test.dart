import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';
import 'package:windows_application/features/menu_management/versions/controllers/published_version_cubit.dart';
import 'package:windows_application/features/menu_management/versions/models/published_version_models.dart';
import 'package:windows_application/features/menu_management/versions/views/published_version_history_panel.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('Version History renders manager-facing rows in English', (
    tester,
  ) async {
    await _pump(tester, const Locale('en'));

    expect(find.text('Version History'), findsOneWidget);
    expect(find.text('Version 2'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Compare selected (0)'), findsOneWidget);
    expect(find.text('aabbccddeeff'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Version History renders in Arabic without a layout exception', (
    tester,
  ) async {
    await _pump(tester, const Locale('ar'));

    expect(find.byType(PublishedVersionHistoryPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<PublishedVersionCubit>(
        create: (_) => PublishedVersionCubit(repository: _UiRepository()),
        child: const Scaffold(
          body: SizedBox(
            height: 700,
            child: PublishedVersionHistoryPanel(
              branchId: 1,
              branchName: 'Downtown',
              channel: 'pos',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _UiRepository extends BackendMenuCatalogRepository {
  _UiRepository()
    : super(DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/'))));

  @override
  Future<PublishedVersionPage> listPublishedVersions({
    required int branchId,
    required String channel,
    required int page,
    int perPage = 20,
  }) async => PublishedVersionPage(
    items: const <PublishedVersion>[
      PublishedVersion(
        id: 2,
        versionNumber: 2,
        checksum: 'aabbccddeeff',
        status: 'current',
        publishedAt: '2026-08-02T10:00:00Z',
        isCurrent: true,
        publicationId: 4,
      ),
    ],
    page: 1,
    perPage: 20,
    total: 1,
  );
}
