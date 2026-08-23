// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/catalog_setup_models.dart';

enum CatalogSetupRequestStatus { idle, loading, loaded, failure, mutating }

class CatalogSetupState extends Equatable {
  const CatalogSetupState({
    this.kind = CatalogSetupKind.categories,
    this.status = CatalogSetupStatus.all,
    this.search = '',
    this.requestStatus = CatalogSetupRequestStatus.idle,
    this.page,
    this.error,
    this.fieldErrors = const <String, List<String>>{},
    this.message,
  });
  final CatalogSetupKind kind;
  final CatalogSetupStatus status;
  final String search;
  final CatalogSetupRequestStatus requestStatus;
  final CatalogSetupPage? page;
  final String? error;
  final Map<String, List<String>> fieldErrors;
  final String? message;
  bool get isBusy =>
      requestStatus == CatalogSetupRequestStatus.loading ||
      requestStatus == CatalogSetupRequestStatus.mutating;
  CatalogSetupState copyWith({
    CatalogSetupKind? kind,
    CatalogSetupStatus? status,
    String? search,
    CatalogSetupRequestStatus? requestStatus,
    CatalogSetupPage? page,
    String? error,
    Map<String, List<String>>? fieldErrors,
    String? message,
    bool clearPage = false,
    bool clearError = false,
    bool clearFieldErrors = false,
    bool clearMessage = false,
  }) => CatalogSetupState(
    kind: kind ?? this.kind,
    status: status ?? this.status,
    search: search ?? this.search,
    requestStatus: requestStatus ?? this.requestStatus,
    page: clearPage ? null : page ?? this.page,
    error: clearError ? null : error ?? this.error,
    fieldErrors: clearFieldErrors
        ? const <String, List<String>>{}
        : fieldErrors ?? this.fieldErrors,
    message: clearMessage ? null : message ?? this.message,
  );
  @override
  List<Object?> get props => <Object?>[
    kind,
    status,
    search,
    requestStatus,
    page,
    error,
    fieldErrors,
    message,
  ];
}

class CatalogSetupCubit extends Cubit<CatalogSetupState> {
  CatalogSetupCubit({required this.repository})
    : super(const CatalogSetupState());
  final MenuCatalogRepository repository;
  int _ticket = 0;
  String? _loadingKey;
  final Map<CatalogSetupKind, CatalogSetupState> _tabStates =
      <CatalogSetupKind, CatalogSetupState>{};

  void _emit(CatalogSetupState next) {
    emit(next);
    _tabStates[next.kind] = next;
  }

  Future<void> initialize(CatalogSetupKind kind) async {
    if (state.kind != kind) {
      _emit(_tabStates[kind] ?? CatalogSetupState(kind: kind));
    }
    await load();
  }

  Future<void> selectKind(CatalogSetupKind kind) async {
    if (state.kind == kind) return;
    _ticket++;
    _emit(_tabStates[kind] ?? CatalogSetupState(kind: kind));
    await load();
  }

  Future<void> setStatus(CatalogSetupStatus status) async {
    if (state.status == status) return;
    _ticket++;
    _emit(state.copyWith(status: status));
    await load(page: 1);
  }

  Future<void> setSearch(String search) async {
    if (state.search == search) return;
    _ticket++;
    _emit(state.copyWith(search: search));
    await load(page: 1);
  }

  Future<void> load({int? page}) async {
    final CatalogSetupKind kind = state.kind;
    final CatalogSetupStatus status = state.status;
    final String search = state.search;
    final int requestedPage = page ?? state.page?.meta.currentPage ?? 1;
    final String loadingKey =
        '${kind.name}:${status.name}:$search:$requestedPage';
    if (_loadingKey == loadingKey) return;
    _loadingKey = loadingKey;
    final int request = ++_ticket;
    _emit(
      state.copyWith(
        requestStatus: CatalogSetupRequestStatus.loading,
        clearError: true,
        clearFieldErrors: true,
        clearMessage: true,
      ),
    );
    try {
      final CatalogSetupPage result = await repository.listCatalogSetup(
        kind: kind,
        status: status,
        search: search,
        page: requestedPage,
        perPage: catalogSetupPageSize,
      );
      if (isClosed || request != _ticket || kind != state.kind) return;
      _emit(
        state.copyWith(
          requestStatus: CatalogSetupRequestStatus.loaded,
          page: result,
        ),
      );
    } catch (error) {
      if (isClosed || request != _ticket || kind != state.kind) return;
      _emit(
        state.copyWith(
          requestStatus: CatalogSetupRequestStatus.failure,
          error: _message(error),
          fieldErrors: _fieldErrors(error),
        ),
      );
    } finally {
      if (_loadingKey == loadingKey) _loadingKey = null;
    }
  }

  Future<void> create(CatalogSetupDraft draft) {
    final CatalogSetupKind kind = state.kind;
    return _mutate(
      kind,
      () => repository.createCatalogSetup(kind, draft),
      'Created successfully.',
    );
  }

  Future<void> update(int id, CatalogSetupDraft draft) {
    final CatalogSetupKind kind = state.kind;
    return _mutate(
      kind,
      () => repository.updateCatalogSetup(kind, id, draft),
      'Saved successfully.',
    );
  }

  Future<void> archive(int id) {
    final CatalogSetupKind kind = state.kind;
    return _mutate(
      kind,
      () => repository.archiveCatalogSetup(kind, id),
      'Archived successfully.',
    );
  }

  Future<void> restore(int id) {
    final CatalogSetupKind kind = state.kind;
    return _mutate(
      kind,
      () => repository.restoreCatalogSetup(kind, id),
      'Restored successfully.',
    );
  }

  Future<void> move(int id, int delta) async {
    final List<CatalogSetupRecord> records = List<CatalogSetupRecord>.from(
      state.page?.items ?? const <CatalogSetupRecord>[],
    );
    final int index = records.indexWhere((item) => item.id == id);
    final int target = index + delta;
    if (state.isBusy || index < 0 || target < 0 || target >= records.length)
      return;
    final CatalogSetupKind kind = state.kind;
    records.insert(target, records.removeAt(index));
    await _mutate(
      kind,
      () => repository.reorderCatalogSetup(kind, records),
      'Order saved.',
    );
  }

  Future<void> _mutate(
    CatalogSetupKind kind,
    Future<Object?> Function() action,
    String message,
  ) async {
    if (state.isBusy) return;
    final int mutation = ++_ticket;
    _loadingKey = null;
    _emit(
      state.copyWith(
        requestStatus: CatalogSetupRequestStatus.mutating,
        clearError: true,
        clearFieldErrors: true,
        clearMessage: true,
      ),
    );
    try {
      await action();
      if (isClosed || mutation != _ticket || kind != state.kind) return;
      _emit(
        state.copyWith(
          requestStatus: CatalogSetupRequestStatus.loaded,
          message: message,
        ),
      );
      await load(page: state.page?.meta.currentPage ?? 1);
    } catch (error) {
      if (isClosed || mutation != _ticket || kind != state.kind) return;
      _emit(
        state.copyWith(
          requestStatus: CatalogSetupRequestStatus.failure,
          error: _message(error),
          fieldErrors: _fieldErrors(error),
        ),
      );
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'The Catalog Setup request could not be completed.';

  Map<String, List<String>> _fieldErrors(Object error) => error is ApiException
      ? error.validationErrors ?? const <String, List<String>>{}
      : const <String, List<String>>{};
}
