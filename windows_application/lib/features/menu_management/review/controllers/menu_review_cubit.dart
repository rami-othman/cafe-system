import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../pos/models/branch.dart';
import '../../assignments/models/menu_assignment_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/review_models.dart';

enum ReviewLoadStatus { initial, loading, ready, failure }

enum ReviewRequestStatus { idle, loading, loaded, failure }

enum PublicationActionStatus {
  idle,
  publishing,
  success,
  noChanges,
  validationBlocked,
  failure,
}

class MenuReviewState extends Equatable {
  const MenuReviewState({
    this.contextStatus = ReviewLoadStatus.initial,
    this.validationStatus = ReviewRequestStatus.idle,
    this.previewStatus = ReviewRequestStatus.idle,
    this.currentVersionStatus = ReviewRequestStatus.idle,
    this.publicationStatus = PublicationActionStatus.idle,
    this.branches = const <Branch>[],
    this.selectedBranch,
    this.channel = 'pos',
    this.eligibleMenus = const <MenuAssignment>[],
    this.menuId,
    this.evaluationAt,
    this.language = 'default',
    this.includeHidden = false,
    this.includeUnavailable = true,
    this.validation,
    this.preview,
    this.currentVersion,
    this.lastPublication,
    this.contextError,
    this.validationError,
    this.previewError,
    this.currentVersionError,
    this.publicationError,
    this.severityFilter,
    this.entityTypeFilter,
    this.search = '',
  });

  final ReviewLoadStatus contextStatus;
  final ReviewRequestStatus validationStatus;
  final ReviewRequestStatus previewStatus;
  final ReviewRequestStatus currentVersionStatus;
  final PublicationActionStatus publicationStatus;
  final List<Branch> branches;
  final Branch? selectedBranch;
  final String channel;
  final List<MenuAssignment> eligibleMenus;
  final int? menuId;
  final DateTime? evaluationAt;
  final String language;
  final bool includeHidden;
  final bool includeUnavailable;
  final MenuValidationResult? validation;
  final ResolvedPreview? preview;
  final PublishedMenuVersion? currentVersion;
  final MenuPublicationResult? lastPublication;
  final String? contextError;
  final String? validationError;
  final String? previewError;
  final String? currentVersionError;
  final String? publicationError;
  final ValidationSeverity? severityFilter;
  final String? entityTypeFilter;
  final String search;

  bool get hasContext => selectedBranch != null;
  bool get isCollection => menuId == null;
  bool get isBusy => contextStatus == ReviewLoadStatus.loading;

  /// Publishing is always affected by the selected Branch and Channel.
  /// Preview controls must not discard an in-flight publication result.
  String? get publishingScopeKey =>
      selectedBranch == null ? null : '${selectedBranch!.id}|$channel';
  ReviewContext? get context => selectedBranch == null
      ? null
      : ReviewContext(
          branchId: selectedBranch!.id,
          channel: channel,
          menuId: menuId,
          evaluationAt: evaluationAt,
          language: language,
          includeHidden: includeHidden,
          includeUnavailable: includeUnavailable,
        );
  List<ValidationIssue> get filteredIssues => (validation?.issues ?? const [])
      .where(
        (issue) =>
            severityFilter == null || issue.severityValue == severityFilter,
      )
      .where(
        (issue) =>
            entityTypeFilter == null || issue.entityType == entityTypeFilter,
      )
      .where((issue) {
        final String needle = search.trim().toLowerCase();
        return needle.isEmpty ||
            issue.code.toLowerCase().contains(needle) ||
            issue.message.toLowerCase().contains(needle);
      })
      .toList(growable: false);

  MenuReviewState copyWith({
    ReviewLoadStatus? contextStatus,
    ReviewRequestStatus? validationStatus,
    ReviewRequestStatus? previewStatus,
    ReviewRequestStatus? currentVersionStatus,
    PublicationActionStatus? publicationStatus,
    List<Branch>? branches,
    Branch? selectedBranch,
    bool clearBranch = false,
    String? channel,
    List<MenuAssignment>? eligibleMenus,
    int? menuId,
    bool clearMenu = false,
    DateTime? evaluationAt,
    String? language,
    bool? includeHidden,
    bool? includeUnavailable,
    MenuValidationResult? validation,
    ResolvedPreview? preview,
    PublishedMenuVersion? currentVersion,
    MenuPublicationResult? lastPublication,
    String? contextError,
    String? validationError,
    String? previewError,
    String? currentVersionError,
    String? publicationError,
    ValidationSeverity? severityFilter,
    bool clearSeverity = false,
    String? entityTypeFilter,
    bool clearEntityType = false,
    String? search,
    bool clearContextError = false,
    bool clearValidation = false,
    bool clearPreview = false,
    bool clearValidationError = false,
    bool clearPreviewError = false,
    bool clearCurrentVersion = false,
    bool clearLastPublication = false,
    bool clearCurrentVersionError = false,
    bool clearPublicationError = false,
  }) => MenuReviewState(
    contextStatus: contextStatus ?? this.contextStatus,
    validationStatus: validationStatus ?? this.validationStatus,
    previewStatus: previewStatus ?? this.previewStatus,
    currentVersionStatus: currentVersionStatus ?? this.currentVersionStatus,
    publicationStatus: publicationStatus ?? this.publicationStatus,
    branches: branches ?? this.branches,
    selectedBranch: clearBranch ? null : selectedBranch ?? this.selectedBranch,
    channel: channel ?? this.channel,
    eligibleMenus: eligibleMenus ?? this.eligibleMenus,
    menuId: clearMenu ? null : menuId ?? this.menuId,
    evaluationAt: evaluationAt ?? this.evaluationAt,
    language: language ?? this.language,
    includeHidden: includeHidden ?? this.includeHidden,
    includeUnavailable: includeUnavailable ?? this.includeUnavailable,
    validation: clearValidation ? null : validation ?? this.validation,
    preview: clearPreview ? null : preview ?? this.preview,
    currentVersion: clearCurrentVersion
        ? null
        : currentVersion ?? this.currentVersion,
    lastPublication: clearLastPublication
        ? null
        : lastPublication ?? this.lastPublication,
    contextError: clearContextError ? null : contextError ?? this.contextError,
    validationError: clearValidationError
        ? null
        : validationError ?? this.validationError,
    previewError: clearPreviewError ? null : previewError ?? this.previewError,
    currentVersionError: clearCurrentVersionError
        ? null
        : currentVersionError ?? this.currentVersionError,
    publicationError: clearPublicationError
        ? null
        : publicationError ?? this.publicationError,
    severityFilter: clearSeverity
        ? null
        : severityFilter ?? this.severityFilter,
    entityTypeFilter: clearEntityType
        ? null
        : entityTypeFilter ?? this.entityTypeFilter,
    search: search ?? this.search,
  );

  @override
  List<Object?> get props => <Object?>[
    contextStatus,
    validationStatus,
    previewStatus,
    currentVersionStatus,
    publicationStatus,
    branches,
    selectedBranch,
    channel,
    eligibleMenus,
    menuId,
    evaluationAt,
    language,
    includeHidden,
    includeUnavailable,
    validation,
    preview,
    currentVersion,
    lastPublication,
    contextError,
    validationError,
    previewError,
    currentVersionError,
    publicationError,
    severityFilter,
    entityTypeFilter,
    search,
  ];
}

class MenuReviewCubit extends Cubit<MenuReviewState> {
  MenuReviewCubit({required this.repository}) : super(const MenuReviewState());
  final MenuCatalogRepository repository;
  int _contextTicket = 0;
  int _validationTicket = 0;
  int _previewTicket = 0;
  int _currentVersionTicket = 0;
  int _publicationTicket = 0;

  Future<void> load({
    int? branchId,
    String? channel,
    int? menuId,
    DateTime? evaluationAt,
  }) async {
    final int ticket = ++_contextTicket;
    // Context starts changing before asynchronous assignment loading completes;
    // invalidate publication data immediately so old scope responses cannot win.
    _invalidateResults();
    final String selectedChannel = _supportedChannel(channel) ?? state.channel;
    emit(
      state.copyWith(
        contextStatus: ReviewLoadStatus.loading,
        channel: selectedChannel,
        evaluationAt: evaluationAt,
        clearContextError: true,
      ),
    );
    try {
      final List<Branch> branches = state.branches.isEmpty
          ? (await repository.listAssignmentBranches())
                .where((branch) => branch.isActive)
                .toList(growable: false)
          : state.branches;
      if (isClosed || ticket != _contextTicket) return;
      final Branch? branch =
          branches
              .where(
                (item) => item.id == (branchId ?? state.selectedBranch?.id),
              )
              .firstOrNull ??
          (branches.isEmpty ? null : branches.first);
      if (branch == null) {
        _invalidateResults();
        emit(
          state.copyWith(
            contextStatus: ReviewLoadStatus.ready,
            branches: branches,
            clearBranch: true,
            clearMenu: true,
          ),
        );
        return;
      }
      _invalidateResults();
      emit(
        state.copyWith(
          contextStatus: ReviewLoadStatus.ready,
          branches: branches,
          selectedBranch: branch,
          channel: selectedChannel,
          // A menu ID can arrive through a legacy diagnostic deep link, but
          // the manager workflow always renders the automatic collection.
          menuId: menuId != null && menuId > 0 ? menuId : null,
          evaluationAt: evaluationAt,
          clearMenu: menuId == null || menuId <= 0,
          validationStatus: ReviewRequestStatus.idle,
          clearValidation: true,
          clearPreview: true,
          clearValidationError: true,
          clearPreviewError: true,
          currentVersionStatus: ReviewRequestStatus.idle,
          publicationStatus: PublicationActionStatus.idle,
          clearCurrentVersion: true,
          clearLastPublication: true,
          clearCurrentVersionError: true,
          clearPublicationError: true,
        ),
      );
      await Future.wait<void>(<Future<void>>[loadCurrentVersion(), validate()]);
    } catch (error) {
      if (isClosed || ticket != _contextTicket) return;
      emit(
        state.copyWith(
          contextStatus: ReviewLoadStatus.failure,
          contextError: _message(error),
        ),
      );
    }
  }

  Future<void> selectBranch(int value) =>
      load(branchId: value, channel: state.channel, menuId: state.menuId);
  Future<void> selectChannel(String value) => load(
    branchId: state.selectedBranch?.id,
    channel: value,
    menuId: state.menuId,
  );
  void selectScope(int? value) {
    if (value != null && value <= 0) {
      return;
    }
    if (state.menuId == value) return;
    _invalidateResults();
    emit(
      state.copyWith(
        menuId: value,
        clearMenu: value == null,
        validationStatus: ReviewRequestStatus.idle,
        previewStatus: ReviewRequestStatus.idle,
        currentVersionStatus: ReviewRequestStatus.idle,
        publicationStatus: PublicationActionStatus.idle,
        clearValidation: true,
        clearPreview: true,
        clearCurrentVersion: true,
        clearLastPublication: true,
        clearValidationError: true,
        clearPreviewError: true,
        clearCurrentVersionError: true,
        clearPublicationError: true,
      ),
    );
    unawaited(loadCurrentVersion());
    unawaited(validate());
  }

  void setLanguage(String value) => _setPreviewControl(language: value);
  void setIncludeHidden(bool value) => _setPreviewControl(includeHidden: value);
  void setIncludeUnavailable(bool value) =>
      _setPreviewControl(includeUnavailable: value);
  void setIssueFilters({
    ValidationSeverity? severity,
    bool clearSeverity = false,
    String? entityType,
    bool clearEntityType = false,
    String? search,
  }) => emit(
    state.copyWith(
      severityFilter: severity,
      clearSeverity: clearSeverity,
      entityTypeFilter: entityType,
      clearEntityType: clearEntityType,
      search: search,
    ),
  );

  Future<void> validate() async {
    final ReviewContext? context = state.context;
    if (context == null ||
        state.validationStatus == ReviewRequestStatus.loading) {
      return;
    }
    final int ticket = ++_validationTicket;
    emit(
      state.copyWith(
        validationStatus: ReviewRequestStatus.loading,
        clearValidationError: true,
      ),
    );
    try {
      final MenuValidationResult result = context.isCollection
          ? await repository.validateMenuCollection(context)
          : await repository.validateMenu(context.menuId!, context);
      if (isClosed || ticket != _validationTicket) {
        return;
      }
      emit(
        state.copyWith(
          validationStatus: ReviewRequestStatus.loaded,
          validation: result,
        ),
      );
    } catch (error) {
      if (isClosed || ticket != _validationTicket) {
        return;
      }
      emit(
        state.copyWith(
          validationStatus: ReviewRequestStatus.failure,
          validationError: _message(error),
        ),
      );
    }
  }

  Future<void> preview() async {
    final ReviewContext? context = state.context;
    if (context == null || state.previewStatus == ReviewRequestStatus.loading) {
      return;
    }
    final int ticket = ++_previewTicket;
    emit(
      state.copyWith(
        previewStatus: ReviewRequestStatus.loading,
        clearPreviewError: true,
      ),
    );
    try {
      final ResolvedPreview result = context.isCollection
          ? await repository.previewMenuCollection(context)
          : await repository.previewMenu(context.menuId!, context);
      if (isClosed || ticket != _previewTicket) return;
      emit(
        state.copyWith(
          previewStatus: ReviewRequestStatus.loaded,
          preview: result,
        ),
      );
    } catch (error) {
      if (isClosed || ticket != _previewTicket) return;
      emit(
        state.copyWith(
          previewStatus: ReviewRequestStatus.failure,
          previewError: _message(error),
        ),
      );
    }
  }

  Future<void> loadCurrentVersion() async {
    final ReviewContext? context = state.context;
    final String? scopeKey = state.publishingScopeKey;
    if (context == null ||
        state.currentVersionStatus == ReviewRequestStatus.loading) {
      return;
    }
    final int ticket = ++_currentVersionTicket;
    emit(
      state.copyWith(
        currentVersionStatus: ReviewRequestStatus.loading,
        clearCurrentVersionError: true,
      ),
    );
    try {
      final PublishedMenuVersion? version = await repository
          .getCurrentPublishedVersion(context);
      if (isClosed ||
          ticket != _currentVersionTicket ||
          scopeKey != state.publishingScopeKey) {
        return;
      }
      emit(
        state.copyWith(
          currentVersionStatus: ReviewRequestStatus.loaded,
          currentVersion: version,
          clearCurrentVersion: version == null,
        ),
      );
    } catch (error) {
      if (isClosed ||
          ticket != _currentVersionTicket ||
          scopeKey != state.publishingScopeKey) {
        return;
      }
      emit(
        state.copyWith(
          currentVersionStatus: ReviewRequestStatus.failure,
          currentVersionError: _message(error),
        ),
      );
    }
  }

  Future<void> publish() async {
    final ReviewContext? reviewContext = state.context;
    final String? scopeKey = state.publishingScopeKey;
    if (reviewContext == null ||
        state.publicationStatus == PublicationActionStatus.publishing ||
        state.validationStatus != ReviewRequestStatus.loaded ||
        state.validation?.canPublish != true) {
      return;
    }
    // The manager workflow always publishes the backend-selected active
    // assignment collection for this exact Branch + Channel.  It never
    // submits a local menu selection or preview-only controls.
    final ReviewContext publishContext = ReviewContext(
      branchId: reviewContext.branchId,
      channel: reviewContext.channel,
    );
    final int ticket = ++_publicationTicket;
    emit(
      state.copyWith(
        publicationStatus: PublicationActionStatus.publishing,
        clearPublicationError: true,
      ),
    );
    try {
      final MenuPublicationResult result = await repository.publishMenuScope(
        publishContext,
      );
      if (isClosed ||
          ticket != _publicationTicket ||
          scopeKey != state.publishingScopeKey) {
        return;
      }
      emit(
        state.copyWith(
          publicationStatus: result.noChanges
              ? PublicationActionStatus.noChanges
              : PublicationActionStatus.success,
          lastPublication: result,
          clearPublicationError: true,
        ),
      );
      await loadCurrentVersion();
    } catch (error) {
      if (isClosed ||
          ticket != _publicationTicket ||
          scopeKey != state.publishingScopeKey) {
        return;
      }
      final bool validationBlocked =
          error is ApiException &&
          error.statusCode == 422 &&
          (error.validationErrors?.containsKey('publish') ?? false);
      debugPrint('Menu publish request failed: $error');
      emit(
        state.copyWith(
          publicationStatus: validationBlocked
              ? PublicationActionStatus.validationBlocked
              : PublicationActionStatus.failure,
          publicationError: validationBlocked
              ? 'publish_validation_changed'
              : 'publish_failed',
        ),
      );
      if (validationBlocked) {
        // Revalidation is server-authoritative. Reload only readiness so the
        // issue browser cannot retain a stale ready state.
        await validate();
      }
    }
  }

  void _setPreviewControl({
    String? language,
    bool? includeHidden,
    bool? includeUnavailable,
  }) {
    _previewTicket++;
    emit(
      state.copyWith(
        language: language,
        includeHidden: includeHidden,
        includeUnavailable: includeUnavailable,
        previewStatus: ReviewRequestStatus.idle,
        clearPreview: true,
        clearPreviewError: true,
      ),
    );
  }

  void _invalidateResults() {
    _validationTicket++;
    _previewTicket++;
    _currentVersionTicket++;
    _publicationTicket++;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to load menu review data. Please try again.';

  String? _supportedChannel(String? value) =>
      const <String>[
        'pos',
        'waiter_app',
        'kiosk',
        'qr_ordering',
        'delivery',
        'online_ordering',
      ].contains(value)
      ? value
      : null;
}
