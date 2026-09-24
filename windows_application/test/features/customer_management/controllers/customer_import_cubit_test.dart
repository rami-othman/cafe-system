import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_import_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_import_state.dart';
import 'package:windows_application/features/customer_management/models/customer_import_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_import_repository.dart';

void main() {
  test('coalesces concurrent previews and emits a ready import', () async {
    final _FakeImportRepository repository = _FakeImportRepository();
    final CustomerImportCubit cubit = CustomerImportCubit(repository);
    addTearDown(cubit.close);

    final Future<void> first = cubit.preview(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      filename: 'customers.csv',
    );
    final Future<void> second = cubit.preview(
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
      filename: 'ignored.csv',
    );

    expect(repository.previewCalls, 1);
    repository.previewCompleter.complete(_status('preview_ready'));
    await Future.wait(<Future<void>>[first, second]);

    expect(cubit.state.status, CustomerImportCubitStatus.ready);
    expect(cubit.state.importStatus?.id, 7);
  });

  test(
    'coalesces concurrent commits and finishes without polling when terminal',
    () async {
      final _FakeImportRepository repository = _FakeImportRepository(
        commitResult: _status('completed'),
      );
      final CustomerImportCubit cubit = CustomerImportCubit(repository);
      addTearDown(cubit.close);

      final Future<void> preview = cubit.preview(
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'customers.csv',
      );
      repository.previewCompleter.complete(_status('preview_ready'));
      await preview;
      final Future<void> first = cubit.commit(createMissingGroups: true);
      final Future<void> second = cubit.commit(createMissingGroups: false);
      await Future.wait(<Future<void>>[first, second]);

      expect(repository.commitCalls, 1);
      expect(repository.lastCreateMissingGroups, isTrue);
      expect(cubit.state.status, CustomerImportCubitStatus.success);
      expect(cubit.state.importStatus?.status, 'completed');
    },
  );
}

CustomerImportStatus _status(String status) =>
    CustomerImportStatus.fromJson(<String, dynamic>{
      'id': 7,
      'filename': 'customers.csv',
      'fingerprint': List<String>.filled(64, 'a').join(),
      'encoding': 'utf-8',
      'delimiter': 'semicolon',
      'status': status,
      'createMissingGroups': null,
      'counts': <String, dynamic>{
        'total': 1,
        'ready': 1,
        'warnings': 0,
        'rejected': 0,
        'duplicateCandidates': 0,
        'processed': status == 'completed' ? 1 : 0,
        'createdCustomers': status == 'completed' ? 1 : 0,
        'skippedCustomers': 0,
        'failedRows': 0,
        'createdGroups': 0,
        'createdMemberships': 0,
      },
      'groups': <String, dynamic>{'matched': <String>[], 'missing': <String>[]},
      'issues': <dynamic>[],
      'errorReportAvailable': false,
      'failureCode': null,
    });

class _FakeImportRepository implements CustomerImportRepository {
  _FakeImportRepository({this.commitResult});

  final CustomerImportStatus? commitResult;
  final Completer<CustomerImportStatus> previewCompleter =
      Completer<CustomerImportStatus>();
  int previewCalls = 0;
  int commitCalls = 0;
  bool? lastCreateMissingGroups;

  @override
  Future<CustomerImportStatus> previewCustomerImport({
    required Uint8List bytes,
    required String filename,
  }) {
    previewCalls++;
    return previewCompleter.future;
  }

  @override
  Future<CustomerImportStatus> commitCustomerImport({
    required int importId,
    required bool createMissingGroups,
  }) async {
    commitCalls++;
    lastCreateMissingGroups = createMissingGroups;
    return commitResult ?? _status('queued');
  }

  @override
  Future<CustomerImportStatus> getCustomerImport(int importId) async =>
      _status('completed');

  @override
  Future<Uint8List> downloadCustomerImportErrors(int importId) async =>
      Uint8List.fromList(<int>[]);
}
