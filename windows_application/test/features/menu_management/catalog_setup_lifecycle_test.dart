import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/core/network/dio_api_client.dart';
import 'package:windows_application/features/menu_management/catalog_setup/controllers/catalog_setup_cubit.dart';
import 'package:windows_application/features/menu_management/catalog_setup/models/catalog_setup_models.dart';
import 'package:windows_application/features/menu_management/models/catalog_models.dart';
import 'package:windows_application/features/menu_management/repositories/menu_catalog_repository.dart';

void main() {
  for (final CatalogSetupKind kind in CatalogSetupKind.values) {
    test(
      '$kind completes list filters, pagination, refresh, and mutations',
      () async {
        final _LifecycleRepository repository = _LifecycleRepository();
        final CatalogSetupCubit cubit = CatalogSetupCubit(
          repository: repository,
        );
        addTearDown(cubit.close);

        await cubit.initialize(kind);
        expect(cubit.state.page!.items.first.productCount, 7);
        await cubit.setSearch('espresso');
        await cubit.setStatus(CatalogSetupStatus.archived);
        await cubit.setStatus(CatalogSetupStatus.all);
        await cubit.load(page: 2);
        await cubit.load();
        expect(repository.listCalls.last, (
          kind,
          CatalogSetupStatus.all,
          'espresso',
          2,
        ));

        await cubit.create(const CatalogSetupDraft(name: 'Created'));
        await cubit.update(1, const CatalogSetupDraft(name: 'Updated'));
        await cubit.archive(1);
        await cubit.restore(1);
        await cubit.move(1, 1);

        expect(repository.mutations, <String>[
          'create',
          'update',
          'archive',
          'restore',
          'reorder',
        ]);
        expect(repository.reorderedIds, <int>[2, 1]);
        // The server reload determines the rendered order; the client never
        // assumes its optimistic move is authoritative.
        expect(cubit.state.page!.items.map((item) => item.id), <int>[1, 2]);
      },
    );

    test('$kind preserves records after each 422 mutation failure', () async {
      final _LifecycleRepository repository = _LifecycleRepository();
      final CatalogSetupCubit cubit = CatalogSetupCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.initialize(kind);

      for (final String operation in <String>[
        'create',
        'update',
        'archive',
        'restore',
        'reorder',
      ]) {
        repository.failingOperation = operation;
        switch (operation) {
          case 'create':
            await cubit.create(const CatalogSetupDraft(name: 'Duplicate'));
            break;
          case 'update':
            await cubit.update(1, const CatalogSetupDraft(name: 'Duplicate'));
            break;
          case 'archive':
            await cubit.archive(1);
            break;
          case 'restore':
            await cubit.restore(1);
            break;
          case 'reorder':
            await cubit.move(1, 1);
            break;
        }
        expect(cubit.state.requestStatus, CatalogSetupRequestStatus.failure);
        expect(cubit.state.error, 'The submitted data was invalid.');
        expect(cubit.state.page!.items.first.name, 'Backend first');
        repository.failingOperation = null;
        await cubit.load();
        expect(cubit.state.requestStatus, CatalogSetupRequestStatus.loaded);
      }
    });
  }

  test(
    'Catalog Setup reports an initial load failure, retries, and supports empty pages',
    () async {
      final _LifecycleRepository repository = _LifecycleRepository()
        ..failLists = true;
      final CatalogSetupCubit cubit = CatalogSetupCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.initialize(CatalogSetupKind.categories);
      expect(cubit.state.requestStatus, CatalogSetupRequestStatus.failure);
      expect(cubit.state.page, isNull);
      repository.failLists = false;
      await cubit.load();
      expect(cubit.state.requestStatus, CatalogSetupRequestStatus.loaded);
      repository.emptyLists = true;
      await cubit.setSearch('no matches');
      expect(cubit.state.page!.items, isEmpty);
      expect(cubit.state.page!.meta.total, 0);
    },
  );
}

class _LifecycleRepository extends BackendMenuCatalogRepository {
  _LifecycleRepository()
    : super(DioApiClient(dio: Dio(BaseOptions(baseUrl: 'http://localhost/'))));

  final List<(CatalogSetupKind, CatalogSetupStatus, String, int)> listCalls =
      <(CatalogSetupKind, CatalogSetupStatus, String, int)>[];
  final List<String> mutations = <String>[];
  List<int> reorderedIds = <int>[];
  String? failingOperation;
  bool failLists = false;
  bool emptyLists = false;

  @override
  Future<CatalogSetupPage> listCatalogSetup({
    required CatalogSetupKind kind,
    required CatalogSetupStatus status,
    required String search,
    required int page,
    int perPage = 20,
  }) async {
    listCalls.add((kind, status, search, page));
    if (failLists) {
      throw const ApiException(
        message: 'The Catalog Setup request could not be completed.',
      );
    }
    return CatalogSetupPage(
      items: emptyLists
          ? const <CatalogSetupRecord>[]
          : <CatalogSetupRecord>[
              _record(id: 1, name: 'Backend first'),
              _record(id: 2, name: 'Backend second'),
            ],
      meta: CatalogPagination(
        currentPage: page,
        lastPage: emptyLists ? 1 : 2,
        perPage: perPage,
        total: emptyLists ? 0 : 22,
      ),
    );
  }

  @override
  Future<CatalogSetupRecord> createCatalogSetup(
    CatalogSetupKind kind,
    CatalogSetupDraft draft,
  ) => _mutation('create', _record(id: 3, name: draft.name));

  @override
  Future<CatalogSetupRecord> updateCatalogSetup(
    CatalogSetupKind kind,
    int id,
    CatalogSetupDraft draft,
  ) => _mutation('update', _record(id: id, name: draft.name));

  @override
  Future<CatalogSetupRecord> archiveCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) => _mutation(
    'archive',
    _record(id: id, name: 'Backend first', active: false),
  );

  @override
  Future<CatalogSetupRecord> restoreCatalogSetup(
    CatalogSetupKind kind,
    int id,
  ) => _mutation('restore', _record(id: id, name: 'Backend first'));

  @override
  Future<void> reorderCatalogSetup(
    CatalogSetupKind kind,
    List<CatalogSetupRecord> items,
  ) async {
    mutations.add('reorder');
    if (failingOperation == 'reorder') _fail();
    reorderedIds = items.map((item) => item.id).toList(growable: false);
  }

  Future<CatalogSetupRecord> _mutation(
    String operation,
    CatalogSetupRecord record,
  ) async {
    mutations.add(operation);
    if (failingOperation == operation) _fail();
    return record;
  }

  Never _fail() => throw const ApiException(
    message: 'The submitted data was invalid.',
    statusCode: 422,
  );
}

CatalogSetupRecord _record({
  required int id,
  required String name,
  bool active = true,
}) => CatalogSetupRecord(
  id: id,
  name: name,
  nameAr: '',
  nameEn: '',
  description: '',
  code: id == 1 ? 'BAR' : '',
  printerName: id == 1 ? 'bar-printer' : '',
  branchId: null,
  isActive: active,
  sortOrder: id - 1,
  productCount: 7,
);
