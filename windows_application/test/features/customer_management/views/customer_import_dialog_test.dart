import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/models/customer_import_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_import_repository.dart';
import 'package:windows_application/features/customer_management/views/customer_import_dialog.dart';
import 'package:windows_application/l10n/app_localizations.dart';

void main() {
  testWidgets('opens with the localized CSV selection workflow', (
    tester,
  ) async {
    final _FakeImportRepository repository = _FakeImportRepository();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => showCustomerImportDialog(
                context,
                repository: repository,
                onCompleted: () async {},
              ),
              child: const Text('Open import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open import'));
    await tester.pumpAndSettle();

    expect(find.text('Import customers from CSV'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-import-select-file')),
      findsOneWidget,
    );
    expect(find.text('Start import'), findsNothing);
  });
}

class _FakeImportRepository implements CustomerImportRepository {
  @override
  Future<CustomerImportStatus> previewCustomerImport({
    required Uint8List bytes,
    required String filename,
  }) => throw UnimplementedError();

  @override
  Future<CustomerImportStatus> commitCustomerImport({
    required int importId,
    required bool createMissingGroups,
  }) => throw UnimplementedError();

  @override
  Future<CustomerImportStatus> getCustomerImport(int importId) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> downloadCustomerImportErrors(int importId) =>
      throw UnimplementedError();
}
