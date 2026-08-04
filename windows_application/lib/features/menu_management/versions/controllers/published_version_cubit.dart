// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../../review/models/review_models.dart';
import '../models/published_version_models.dart';

enum VersionRequestStatus { idle, loading, loaded, failure }

enum RollbackStatus {
  idle,
  confirming,
  submitting,
  success,
  noChanges,
  failure,
}

class PublishedVersionState extends Equatable {
  const PublishedVersionState({
    this.branchId,
    this.channel,
    this.historyStatus = VersionRequestStatus.idle,
    this.detailStatus = VersionRequestStatus.idle,
    this.payloadStatus = VersionRequestStatus.idle,
    this.comparisonStatus = VersionRequestStatus.idle,
    this.rollbackStatus = RollbackStatus.idle,
    this.history,
    this.currentVersion,
    this.selectedVersion,
    this.detail,
    this.comparisonTarget,
    this.comparison,
    this.rollbackResult,
    this.historyError,
    this.detailError,
    this.payloadError,
    this.comparisonError,
    this.rollbackError,
  });
  final int? branchId;
  final String? channel;
  final VersionRequestStatus historyStatus;
  final VersionRequestStatus detailStatus;
  final VersionRequestStatus payloadStatus;
  final VersionRequestStatus comparisonStatus;
  final RollbackStatus rollbackStatus;
  final PublishedVersionPage? history;
  final PublishedMenuVersion? currentVersion;
  final PublishedVersion? selectedVersion;
  final PublishedVersionDetail? detail;
  final PublishedVersion? comparisonTarget;
  final VersionComparison? comparison;
  final RollbackResult? rollbackResult;
  final String? historyError;
  final String? detailError;
  final String? payloadError;
  final String? comparisonError;
  final String? rollbackError;
  bool get hasContext => branchId != null && channel != null;
  String? get scopeKey => hasContext ? '$branchId|$channel' : null;
  PublishedVersionState copyWith({
    int? branchId,
    String? channel,
    bool clearContext = false,
    VersionRequestStatus? historyStatus,
    VersionRequestStatus? detailStatus,
    VersionRequestStatus? payloadStatus,
    VersionRequestStatus? comparisonStatus,
    RollbackStatus? rollbackStatus,
    PublishedVersionPage? history,
    PublishedMenuVersion? currentVersion,
    PublishedVersion? selectedVersion,
    PublishedVersionDetail? detail,
    PublishedVersion? comparisonTarget,
    VersionComparison? comparison,
    RollbackResult? rollbackResult,
    String? historyError,
    String? detailError,
    String? payloadError,
    String? comparisonError,
    String? rollbackError,
    bool clearHistory = false,
    bool clearCurrent = false,
    bool clearSelected = false,
    bool clearDetail = false,
    bool clearComparisonTarget = false,
    bool clearComparison = false,
    bool clearRollbackResult = false,
    bool clearHistoryError = false,
    bool clearDetailError = false,
    bool clearPayloadError = false,
    bool clearComparisonError = false,
    bool clearRollbackError = false,
  }) => PublishedVersionState(
    branchId: clearContext ? null : branchId ?? this.branchId,
    channel: clearContext ? null : channel ?? this.channel,
    historyStatus: historyStatus ?? this.historyStatus,
    detailStatus: detailStatus ?? this.detailStatus,
    payloadStatus: payloadStatus ?? this.payloadStatus,
    comparisonStatus: comparisonStatus ?? this.comparisonStatus,
    rollbackStatus: rollbackStatus ?? this.rollbackStatus,
    history: clearHistory ? null : history ?? this.history,
    currentVersion: clearCurrent ? null : currentVersion ?? this.currentVersion,
    selectedVersion: clearSelected
        ? null
        : selectedVersion ?? this.selectedVersion,
    detail: clearDetail ? null : detail ?? this.detail,
    comparisonTarget: clearComparisonTarget
        ? null
        : comparisonTarget ?? this.comparisonTarget,
    comparison: clearComparison ? null : comparison ?? this.comparison,
    rollbackResult: clearRollbackResult
        ? null
        : rollbackResult ?? this.rollbackResult,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
    detailError: clearDetailError ? null : detailError ?? this.detailError,
    payloadError: clearPayloadError ? null : payloadError ?? this.payloadError,
    comparisonError: clearComparisonError
        ? null
        : comparisonError ?? this.comparisonError,
    rollbackError: clearRollbackError
        ? null
        : rollbackError ?? this.rollbackError,
  );
  @override
  List<Object?> get props => <Object?>[
    branchId,
    channel,
    historyStatus,
    detailStatus,
    payloadStatus,
    comparisonStatus,
    rollbackStatus,
    history,
    currentVersion,
    selectedVersion,
    detail,
    comparisonTarget,
    comparison,
    rollbackResult,
    historyError,
    detailError,
    payloadError,
    comparisonError,
    rollbackError,
  ];
}

class PublishedVersionCubit extends Cubit<PublishedVersionState> {
  PublishedVersionCubit({required this.repository})
    : super(const PublishedVersionState());
  final MenuCatalogRepository repository;
  int _historyTicket = 0;
  int _detailTicket = 0;
  int _comparisonTicket = 0;
  int _rollbackTicket = 0;

  Future<void> setContext(int? branchId, String? channel) async {
    if (branchId == null || branchId <= 0 || channel == null || channel.isEmpty)
      return;
    if (state.branchId == branchId && state.channel == channel) return;
    _invalidateRequests();
    emit(PublishedVersionState(branchId: branchId, channel: channel));
    await loadHistory();
  }

  Future<void> loadHistory({int? page}) async {
    if (!state.hasContext ||
        state.historyStatus == VersionRequestStatus.loading)
      return;
    final int request = ++_historyTicket;
    final String scope = state.scopeKey!;
    final int requestedPage = page ?? state.history?.page ?? 1;
    emit(
      state.copyWith(
        historyStatus: VersionRequestStatus.loading,
        clearHistoryError: true,
      ),
    );
    try {
      final result = await repository.listPublishedVersions(
        branchId: state.branchId!,
        channel: state.channel!,
        page: requestedPage,
      );
      final current = await repository.getCurrentPublishedVersion(
        ReviewContext(branchId: state.branchId!, channel: state.channel!),
      );
      if (isClosed || request != _historyTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          historyStatus: VersionRequestStatus.loaded,
          history: result,
          currentVersion: current,
          clearCurrent: current == null,
        ),
      );
    } catch (error) {
      if (isClosed || request != _historyTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          historyStatus: VersionRequestStatus.failure,
          historyError: _message(error),
        ),
      );
    }
  }

  Future<void> refresh() => loadHistory(page: state.history?.page ?? 1);
  Future<void> previousPage() => state.history?.hasPrevious == true
      ? loadHistory(page: state.history!.page - 1)
      : Future<void>.value();
  Future<void> nextPage() => state.history?.hasNext == true
      ? loadHistory(page: state.history!.page + 1)
      : Future<void>.value();

  Future<void> openDetail(PublishedVersion version) async {
    final int request = ++_detailTicket;
    final String? scope = state.scopeKey;
    emit(
      state.copyWith(
        selectedVersion: version,
        detailStatus: VersionRequestStatus.loading,
        payloadStatus: VersionRequestStatus.idle,
        clearDetail: true,
        clearDetailError: true,
        clearPayloadError: true,
      ),
    );
    try {
      final detail = await repository.getPublishedVersion(version.id);
      if (isClosed || request != _detailTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          detailStatus: VersionRequestStatus.loaded,
          detail: detail,
        ),
      );
    } catch (error) {
      if (isClosed || request != _detailTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          detailStatus: VersionRequestStatus.failure,
          detailError: _message(error),
        ),
      );
    }
  }

  Future<void> loadPayload() async {
    final PublishedVersion? selected = state.selectedVersion;
    if (selected == null || state.payloadStatus == VersionRequestStatus.loading)
      return;
    final int request = ++_detailTicket;
    final String? scope = state.scopeKey;
    emit(
      state.copyWith(
        payloadStatus: VersionRequestStatus.loading,
        clearPayloadError: true,
      ),
    );
    try {
      final detail = await repository.getPublishedVersion(
        selected.id,
        includePayload: true,
      );
      if (isClosed || request != _detailTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          detailStatus: VersionRequestStatus.loaded,
          payloadStatus: VersionRequestStatus.loaded,
          detail: detail,
        ),
      );
    } catch (error) {
      if (isClosed || request != _detailTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          payloadStatus: VersionRequestStatus.failure,
          payloadError: _message(error),
        ),
      );
    }
  }

  void selectComparisonTarget(PublishedVersion? version) => emit(
    state.copyWith(
      comparisonTarget: version,
      clearComparisonTarget: version == null,
      clearComparison: true,
      clearComparisonError: true,
    ),
  );

  Future<void> compare(PublishedVersion source) async {
    final PublishedVersion? target = state.comparisonTarget;
    if (target == null ||
        target.id == source.id ||
        state.comparisonStatus == VersionRequestStatus.loading)
      return;
    final int request = ++_comparisonTicket;
    final String? scope = state.scopeKey;
    emit(
      state.copyWith(
        comparisonStatus: VersionRequestStatus.loading,
        clearComparisonError: true,
      ),
    );
    try {
      final result = await repository.comparePublishedVersions(
        source.id,
        target.id,
      );
      if (isClosed || request != _comparisonTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          comparisonStatus: VersionRequestStatus.loaded,
          comparison: result,
        ),
      );
    } catch (error) {
      if (isClosed || request != _comparisonTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          comparisonStatus: VersionRequestStatus.failure,
          comparisonError: _message(error),
        ),
      );
    }
  }

  void beginRollback(PublishedVersion version) => emit(
    state.copyWith(
      selectedVersion: version,
      rollbackStatus: RollbackStatus.confirming,
      clearRollbackResult: true,
      clearRollbackError: true,
    ),
  );

  Future<void> rollback(String reason) async {
    final PublishedVersion? target = state.selectedVersion;
    if (target == null || state.rollbackStatus == RollbackStatus.submitting)
      return;
    final int request = ++_rollbackTicket;
    final String? scope = state.scopeKey;
    emit(
      state.copyWith(
        rollbackStatus: RollbackStatus.submitting,
        clearRollbackError: true,
      ),
    );
    try {
      final result = await repository.rollbackPublishedVersion(
        target.id,
        reason: reason,
      );
      if (isClosed || request != _rollbackTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          rollbackStatus: result.noChanges
              ? RollbackStatus.noChanges
              : RollbackStatus.success,
          rollbackResult: result,
          clearDetail: true,
          clearComparison: true,
          clearComparisonTarget: true,
        ),
      );
      await loadHistory();
    } catch (error) {
      if (isClosed || request != _rollbackTicket || scope != state.scopeKey)
        return;
      emit(
        state.copyWith(
          rollbackStatus: RollbackStatus.failure,
          rollbackError: _message(error),
        ),
      );
    }
  }

  void _invalidateRequests() {
    _historyTicket++;
    _detailTicket++;
    _comparisonTicket++;
    _rollbackTicket++;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'The Version request could not be completed.';
}
