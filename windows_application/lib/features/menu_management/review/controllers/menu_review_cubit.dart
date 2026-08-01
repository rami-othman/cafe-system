import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../pos/models/branch.dart';
import '../../assignments/controllers/menu_assignments_cubit.dart'
    show salesChannels;
import '../../assignments/models/menu_assignment_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../models/review_models.dart';

enum ReviewLoadStatus { initial, loading, ready, failure }

enum ReviewRequestStatus { idle, loading, loaded, failure }

class MenuReviewState extends Equatable {
  const MenuReviewState({
    this.contextStatus = ReviewLoadStatus.initial,
    this.validationStatus = ReviewRequestStatus.idle,
    this.previewStatus = ReviewRequestStatus.idle,
    this.branches = const <Branch>[],
    this.selectedBranch,
    this.channel = 'pos',
    this.eligibleMenus = const <MenuAssignment>[],
    this.menuId,
    this.language = 'default',
    this.includeHidden = false,
    this.includeUnavailable = true,
    this.validation,
    this.preview,
    this.contextError,
    this.validationError,
    this.previewError,
    this.severityFilter,
    this.entityTypeFilter,
    this.search = '',
  });

  final ReviewLoadStatus contextStatus;
  final ReviewRequestStatus validationStatus;
  final ReviewRequestStatus previewStatus;
  final List<Branch> branches;
  final Branch? selectedBranch;
  final String channel;
  final List<MenuAssignment> eligibleMenus;
  final int? menuId;
  final String language;
  final bool includeHidden;
  final bool includeUnavailable;
  final MenuValidationResult? validation;
  final ResolvedPreview? preview;
  final String? contextError;
  final String? validationError;
  final String? previewError;
  final ValidationSeverity? severityFilter;
  final String? entityTypeFilter;
  final String search;

  bool get hasContext => selectedBranch != null;
  bool get isCollection => menuId == null;
  bool get isBusy => contextStatus == ReviewLoadStatus.loading;
  ReviewContext? get context => selectedBranch == null
      ? null
      : ReviewContext(
          branchId: selectedBranch!.id,
          channel: channel,
          menuId: menuId,
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
    List<Branch>? branches,
    Branch? selectedBranch,
    bool clearBranch = false,
    String? channel,
    List<MenuAssignment>? eligibleMenus,
    int? menuId,
    bool clearMenu = false,
    String? language,
    bool? includeHidden,
    bool? includeUnavailable,
    MenuValidationResult? validation,
    ResolvedPreview? preview,
    String? contextError,
    String? validationError,
    String? previewError,
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
  }) => MenuReviewState(
    contextStatus: contextStatus ?? this.contextStatus,
    validationStatus: validationStatus ?? this.validationStatus,
    previewStatus: previewStatus ?? this.previewStatus,
    branches: branches ?? this.branches,
    selectedBranch: clearBranch ? null : selectedBranch ?? this.selectedBranch,
    channel: channel ?? this.channel,
    eligibleMenus: eligibleMenus ?? this.eligibleMenus,
    menuId: clearMenu ? null : menuId ?? this.menuId,
    language: language ?? this.language,
    includeHidden: includeHidden ?? this.includeHidden,
    includeUnavailable: includeUnavailable ?? this.includeUnavailable,
    validation: clearValidation ? null : validation ?? this.validation,
    preview: clearPreview ? null : preview ?? this.preview,
    contextError: clearContextError ? null : contextError ?? this.contextError,
    validationError: clearValidationError
        ? null
        : validationError ?? this.validationError,
    previewError: clearPreviewError ? null : previewError ?? this.previewError,
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
    branches,
    selectedBranch,
    channel,
    eligibleMenus,
    menuId,
    language,
    includeHidden,
    includeUnavailable,
    validation,
    preview,
    contextError,
    validationError,
    previewError,
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

  Future<void> load({int? branchId, String? channel, int? menuId}) async {
    final int ticket = ++_contextTicket;
    final String selectedChannel = salesChannels.contains(channel)
        ? channel!
        : state.channel;
    emit(
      state.copyWith(
        contextStatus: ReviewLoadStatus.loading,
        channel: selectedChannel,
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
            eligibleMenus: const [],
            clearMenu: true,
          ),
        );
        return;
      }
      final List<MenuAssignment> assignments = await repository
          .listMenuAssignments(branchId: branch.id, channel: selectedChannel);
      if (isClosed || ticket != _contextTicket) return;
      final List<MenuAssignment> eligible =
          assignments
              .where(
                (item) =>
                    item.isActive &&
                    item.menu != null &&
                    !item.menu!.isArchived,
              )
              .toList(growable: false)
            ..sort((a, b) => a.priority.compareTo(b.priority));
      final int? selectedMenu = eligible.any((item) => item.menuId == menuId)
          ? menuId
          : null;
      _invalidateResults();
      emit(
        state.copyWith(
          contextStatus: ReviewLoadStatus.ready,
          branches: branches,
          selectedBranch: branch,
          channel: selectedChannel,
          eligibleMenus: eligible,
          menuId: selectedMenu,
          clearMenu: selectedMenu == null,
          clearValidation: true,
          clearPreview: true,
          clearValidationError: true,
          clearPreviewError: true,
        ),
      );
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
    if (state.menuId == value) return;
    _invalidateResults();
    emit(
      state.copyWith(
        menuId: value,
        clearMenu: value == null,
        validationStatus: ReviewRequestStatus.idle,
        previewStatus: ReviewRequestStatus.idle,
        clearValidation: true,
        clearPreview: true,
        clearValidationError: true,
        clearPreviewError: true,
      ),
    );
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
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to load menu review data. Please try again.';
}
