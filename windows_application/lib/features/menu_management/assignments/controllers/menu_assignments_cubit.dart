// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../pos/models/branch.dart';
import '../../menus/models/menu_filter.dart';
import '../../menus/models/menu_models.dart';
import '../../repositories/menu_catalog_repository.dart';
import '../../review/models/review_models.dart';
import '../models/menu_assignment_models.dart';

const List<String> salesChannels = <String>[
  'pos',
  'waiter_app',
  'kiosk',
  'qr_ordering',
  'delivery',
  'online_ordering',
];

enum MenuAssignmentsStatus {
  initial,
  loadingContext,
  loading,
  loaded,
  refreshing,
  failure,
}

enum AddMenusFailure { none, load, save, duplicate, archivedScope }

class MenuAssignmentsState extends Equatable {
  const MenuAssignmentsState({
    this.status = MenuAssignmentsStatus.initial,
    this.branches = const <Branch>[],
    this.selectedBranch,
    this.selectedChannel,
    this.assignments = const <MenuAssignment>[],
    this.availableMenus = const <MenuRecord>[],
    this.previewMenus = const <int, ResolvedMenu>{},
    this.previewUnavailable = false,
    this.scheduleRules = const <int, List<MenuScheduleRule>>{},
    this.isReordering = false,
    this.reorderDraft = const <MenuAssignment>[],
    this.errorMessage,
    this.fieldErrors = const <String, List<String>>{},
    this.currentActionKey,
    this.successMessage,
    this.addMenusFailure = AddMenusFailure.none,
  });

  final MenuAssignmentsStatus status;
  final List<Branch> branches;
  final Branch? selectedBranch;
  final String? selectedChannel;
  final List<MenuAssignment> assignments;
  final List<MenuRecord> availableMenus;
  final Map<int, ResolvedMenu> previewMenus;
  final bool previewUnavailable;
  final Map<int, List<MenuScheduleRule>> scheduleRules;
  final bool isReordering;
  final List<MenuAssignment> reorderDraft;
  final String? errorMessage, currentActionKey, successMessage;
  final AddMenusFailure addMenusFailure;
  final Map<String, List<String>> fieldErrors;

  bool get isBusy =>
      status == MenuAssignmentsStatus.loading ||
      status == MenuAssignmentsStatus.loadingContext ||
      status == MenuAssignmentsStatus.refreshing ||
      currentActionKey != null;
  bool get hasScope => selectedBranch != null && selectedChannel != null;
  bool get hasArchivedAssignment =>
      assignments.any((assignment) => assignment.menu?.isArchived == true);
  bool get canReorder =>
      hasScope && !isBusy && assignments.length > 1 && !hasArchivedAssignment;
  List<MenuAssignment> get orderedAssignments =>
      List<MenuAssignment>.of(assignments)..sort(
        (a, b) => a.priority != b.priority
            ? a.priority.compareTo(b.priority)
            : a.id.compareTo(b.id),
      );

  MenuAssignmentsState copyWith({
    MenuAssignmentsStatus? status,
    List<Branch>? branches,
    Branch? selectedBranch,
    bool clearBranch = false,
    String? selectedChannel,
    bool clearChannel = false,
    List<MenuAssignment>? assignments,
    List<MenuRecord>? availableMenus,
    Map<int, ResolvedMenu>? previewMenus,
    bool? previewUnavailable,
    Map<int, List<MenuScheduleRule>>? scheduleRules,
    bool? isReordering,
    List<MenuAssignment>? reorderDraft,
    String? errorMessage,
    Map<String, List<String>>? fieldErrors,
    String? currentActionKey,
    String? successMessage,
    AddMenusFailure? addMenusFailure,
    bool clearError = false,
    bool clearAction = false,
    bool clearSuccess = false,
  }) => MenuAssignmentsState(
    status: status ?? this.status,
    branches: branches ?? this.branches,
    selectedBranch: clearBranch ? null : selectedBranch ?? this.selectedBranch,
    selectedChannel: clearChannel
        ? null
        : selectedChannel ?? this.selectedChannel,
    assignments: assignments ?? this.assignments,
    availableMenus: availableMenus ?? this.availableMenus,
    previewMenus: previewMenus ?? this.previewMenus,
    previewUnavailable: previewUnavailable ?? this.previewUnavailable,
    scheduleRules: scheduleRules ?? this.scheduleRules,
    isReordering: isReordering ?? this.isReordering,
    reorderDraft: reorderDraft ?? this.reorderDraft,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    fieldErrors: clearError
        ? const <String, List<String>>{}
        : fieldErrors ?? this.fieldErrors,
    currentActionKey: clearAction
        ? null
        : currentActionKey ?? this.currentActionKey,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
    addMenusFailure: addMenusFailure ?? this.addMenusFailure,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    branches,
    selectedBranch,
    selectedChannel,
    assignments,
    availableMenus,
    previewMenus,
    previewUnavailable,
    scheduleRules,
    isReordering,
    reorderDraft,
    errorMessage,
    fieldErrors,
    currentActionKey,
    successMessage,
    addMenusFailure,
  ];
}

class MenuAssignmentsCubit extends Cubit<MenuAssignmentsState> {
  MenuAssignmentsCubit({required this.repository})
    : super(const MenuAssignmentsState());

  final MenuCatalogRepository repository;
  int _generation = 0;

  /// Loads references only until both required selectors form a context.
  Future<void> load({
    int? branchId,
    String? channel,
    bool refresh = false,
  }) async {
    final int ticket = ++_generation;
    emit(
      state.copyWith(
        status: state.branches.isEmpty
            ? MenuAssignmentsStatus.loadingContext
            : MenuAssignmentsStatus.initial,
        assignments: const <MenuAssignment>[],
        availableMenus: const <MenuRecord>[],
        previewMenus: const <int, ResolvedMenu>{},
        previewUnavailable: false,
        scheduleRules: const <int, List<MenuScheduleRule>>{},
        isReordering: false,
        reorderDraft: const <MenuAssignment>[],
        addMenusFailure: AddMenusFailure.none,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final List<Branch> branches = state.branches.isEmpty
          ? (await repository.listAssignmentBranches())
                .where((branch) => branch.isActive)
                .toList(growable: false)
          : state.branches;
      if (ticket != _generation || isClosed) return;
      final Branch? selected = branchId == null
          ? state.selectedBranch
          : branches.where((branch) => branch.id == branchId).firstOrNull;
      final String? selectedChannel =
          channel != null && salesChannels.contains(channel)
          ? channel
          : state.selectedChannel;
      emit(
        state.copyWith(
          status: MenuAssignmentsStatus.initial,
          branches: branches,
          selectedBranch: selected,
          clearBranch: selected == null,
          selectedChannel: selectedChannel,
          clearChannel: selectedChannel == null,
        ),
      );
      if (selected != null && selectedChannel != null) {
        await _loadScope(ticket, refresh: refresh);
      }
    } catch (error) {
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          status: MenuAssignmentsStatus.failure,
          errorMessage: _message(error),
          fieldErrors: _errors(error),
        ),
      );
    }
  }

  Future<void> selectBranch(int id) async {
    final Branch? branch = state.branches
        .where((item) => item.id == id)
        .firstOrNull;
    if (branch == null || branch.id == state.selectedBranch?.id) return;
    final int ticket = ++_generation;
    _clearForContextChange(selectedBranch: branch);
    if (state.selectedChannel != null) await _loadScope(ticket);
  }

  Future<void> selectChannel(String channel) async {
    if (!salesChannels.contains(channel) || channel == state.selectedChannel)
      return;
    final int ticket = ++_generation;
    _clearForContextChange(selectedChannel: channel);
    if (state.selectedBranch != null) await _loadScope(ticket);
  }

  Future<void> refresh() async {
    if (!state.hasScope) return;
    final int ticket = ++_generation;
    await _loadScope(ticket, refresh: true);
  }

  void _clearForContextChange({
    Branch? selectedBranch,
    String? selectedChannel,
  }) {
    emit(
      state.copyWith(
        status: MenuAssignmentsStatus.initial,
        selectedBranch: selectedBranch,
        selectedChannel: selectedChannel,
        assignments: const <MenuAssignment>[],
        availableMenus: const <MenuRecord>[],
        previewMenus: const <int, ResolvedMenu>{},
        previewUnavailable: false,
        scheduleRules: const <int, List<MenuScheduleRule>>{},
        isReordering: false,
        reorderDraft: const <MenuAssignment>[],
        addMenusFailure: AddMenusFailure.none,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  Future<void> _loadScope(int ticket, {bool refresh = false}) async {
    final Branch branch = state.selectedBranch!;
    final String channel = state.selectedChannel!;
    emit(
      state.copyWith(
        status: refresh
            ? MenuAssignmentsStatus.refreshing
            : MenuAssignmentsStatus.loading,
        assignments: const <MenuAssignment>[],
        availableMenus: const <MenuRecord>[],
        previewMenus: const <int, ResolvedMenu>{},
        previewUnavailable: false,
        scheduleRules: const <int, List<MenuScheduleRule>>{},
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final List<MenuAssignment> assignments = await repository
          .listMenuAssignments(branchId: branch.id, channel: channel);
      if (ticket != _generation || isClosed) return;

      final List<MenuAssignment> active = assignments
          .where((assignment) => assignment.isActive)
          .toList(growable: false);
      Map<int, ResolvedMenu> previewMenus = const <int, ResolvedMenu>{};
      bool previewUnavailable = false;
      if (active.isNotEmpty) {
        // Preview is supplemental decoration. A preview failure must never
        // hide the authoritative assignments that were loaded successfully.
        try {
          final ResolvedPreview preview = await repository
              .previewMenuCollection(
                ReviewContext(branchId: branch.id, channel: channel),
              );
          if (ticket != _generation || isClosed) return;
          previewMenus = <int, ResolvedMenu>{
            for (final ResolvedMenu menu in preview.menus) menu.id: menu,
          };
        } catch (_) {
          if (ticket != _generation || isClosed) return;
          previewUnavailable = true;
        }
      }
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          status: MenuAssignmentsStatus.loaded,
          assignments: assignments,
          previewMenus: previewMenus,
          previewUnavailable: previewUnavailable,
        ),
      );
    } catch (error) {
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          status: MenuAssignmentsStatus.failure,
          errorMessage: _message(error),
          fieldErrors: _errors(error),
        ),
      );
    }
  }

  /// Retries only the bounded collection preview after an assignment load
  /// succeeded. This intentionally never reloads per-menu schedule rules.
  Future<void> retryPreview() async {
    if (!state.hasScope || state.currentActionKey != null) return;
    final int ticket = _generation;
    final Branch branch = state.selectedBranch!;
    final String channel = state.selectedChannel!;
    emit(state.copyWith(currentActionKey: 'retry-preview', clearError: true));
    try {
      final ResolvedPreview preview = await repository.previewMenuCollection(
        ReviewContext(branchId: branch.id, channel: channel),
      );
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          previewMenus: <int, ResolvedMenu>{
            for (final ResolvedMenu menu in preview.menus) menu.id: menu,
          },
          previewUnavailable: false,
          clearAction: true,
        ),
      );
    } catch (_) {
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          previewMenus: const <int, ResolvedMenu>{},
          previewUnavailable: true,
          clearAction: true,
        ),
      );
    }
  }

  /// Deferred until the existing Add Menus workflow is opened.
  Future<void> loadAvailableMenus() async {
    if (!state.hasScope || state.isBusy || state.availableMenus.isNotEmpty)
      return;
    final int ticket = _generation;
    emit(
      state.copyWith(
        currentActionKey: 'available-menus',
        addMenusFailure: AddMenusFailure.none,
        clearError: true,
      ),
    );
    try {
      final page = await repository.listMenus(
        // The bounded Menu list is the picker source. `all` deliberately
        // includes Draft and Paused (assignable) plus archived diagnostics.
        filter: const MenuFilter(status: 'all', sort: 'name'),
        page: 1,
        perPage: 100,
      );
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          // Existing scope assignments remain in the result so the picker can
          // explain their exact-scope disabled state rather than hiding them.
          availableMenus: page.items,
          clearAction: true,
        ),
      );
    } catch (error) {
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: 'Could not load menus.',
          fieldErrors: _errors(error),
          addMenusFailure: AddMenusFailure.load,
        ),
      );
    }
  }

  /// Adds an intentionally local picker selection through one complete-scope
  /// sync. Existing assignments are ordered and carried forward verbatim;
  /// selected Menu IDs are appended in bounded list order by the caller.
  Future<bool> addMenus(Iterable<int> menuIds) async {
    if (!state.hasScope || state.isBusy) return false;
    if (state.hasArchivedAssignment) {
      emit(
        state.copyWith(
          addMenusFailure: AddMenusFailure.archivedScope,
          clearError: true,
        ),
      );
      return false;
    }
    final Set<int> assigned = state.assignments
        .map((assignment) => assignment.menuId)
        .toSet();
    final Map<int, MenuRecord> source = <int, MenuRecord>{
      for (final MenuRecord menu in state.availableMenus) menu.id: menu,
    };
    final Set<int> requested = <int>{};
    for (final int id in menuIds) {
      final MenuRecord? menu = source[id];
      if (menu == null || menu.isArchived || assigned.contains(id)) {
        continue;
      }
      requested.add(id);
    }
    // Append in the stable bounded list order, never click or search order.
    final List<MenuRecord> selected = state.availableMenus
        .where((menu) => requested.contains(menu.id))
        .toList(growable: false);
    if (selected.isEmpty) return false;

    final int ticket = _generation;
    final int branchId = state.selectedBranch!.id;
    final String channel = state.selectedChannel!;
    final List<MenuAssignment> next = <MenuAssignment>[
      ...state.orderedAssignments,
      for (final MenuRecord menu in selected)
        MenuAssignment(
          id: -menu.id,
          menuId: menu.id,
          branchId: branchId,
          channel: channel,
          priority: state.assignments.length + selected.indexOf(menu),
          // This is the server's established default; preserve it explicitly.
          isActive: true,
          createdAt: null,
          updatedAt: null,
          menu: menu,
        ),
    ];
    emit(
      state.copyWith(
        currentActionKey: 'add-menus',
        addMenusFailure: AddMenusFailure.none,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      await repository.syncMenuAssignments(
        branchId: branchId,
        channel: channel,
        assignments: _drafts(next),
      );
      if (ticket != _generation || isClosed) return false;
      // Re-read the authoritative scope and its existing bounded preview
      // strategy before allowing the sheet to close.
      final int reloadTicket = ++_generation;
      await _loadScope(reloadTicket, refresh: true);
      if (reloadTicket != _generation || isClosed) return false;
      if (state.status == MenuAssignmentsStatus.loaded) {
        emit(state.copyWith(clearAction: true));
        return true;
      }
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: 'Could not add menus.',
          addMenusFailure: AddMenusFailure.save,
        ),
      );
      return false;
    } catch (error) {
      if (ticket != _generation || isClosed) return false;
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: 'Could not add menus.',
          fieldErrors: _errors(error),
          addMenusFailure: error is ApiException && error.statusCode == 422
              ? AddMenusFailure.duplicate
              : AddMenusFailure.save,
        ),
      );
      return false;
    }
  }

  /// An on-demand detail request; never initial row-load work.
  Future<List<MenuScheduleRule>?> loadScheduleRules(int menuId) async {
    if (!state.hasScope) return null;
    final List<MenuScheduleRule>? cached = state.scheduleRules[menuId];
    if (cached != null) return cached;
    final int ticket = _generation;
    emit(
      state.copyWith(
        currentActionKey: 'load-schedule-$menuId',
        clearError: true,
      ),
    );
    try {
      final List<MenuScheduleRule> rules = await repository
          .listMenuAvailabilityRules(menuId);
      if (ticket != _generation || isClosed) return null;
      emit(
        state.copyWith(
          scheduleRules: <int, List<MenuScheduleRule>>{
            ...state.scheduleRules,
            menuId: rules,
          },
          clearAction: true,
        ),
      );
      return rules;
    } catch (error) {
      if (ticket != _generation || isClosed) return null;
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: _message(error),
          fieldErrors: _errors(error),
        ),
      );
      return null;
    }
  }

  /// Retries the one on-demand schedule request made by an open Menu Schedule
  /// sheet.  It deliberately does not affect any other assigned Menu.
  Future<List<MenuScheduleRule>?> retryScheduleRules(int menuId) {
    final Map<int, List<MenuScheduleRule>> rules =
        Map<int, List<MenuScheduleRule>>.of(state.scheduleRules)
          ..remove(menuId);
    emit(state.copyWith(scheduleRules: rules, clearError: true));
    return loadScheduleRules(menuId);
  }

  /// Syncs an already safety-preserved full Menu rule set.  The sheet owns its
  /// draft because this endpoint is complete replacement; this cubit only
  /// reconciles the authoritative result and the bounded collection preview.
  Future<bool> saveMenuSchedule(
    int menuId,
    List<Map<String, dynamic>> rules,
  ) async {
    if (!state.hasScope || state.currentActionKey != null) return false;
    final String? payloadError = _schedulePayloadError(rules);
    if (payloadError != null) {
      emit(
        state.copyWith(
          errorMessage: payloadError,
          fieldErrors: <String, List<String>>{
            'rules': <String>[payloadError],
          },
        ),
      );
      return false;
    }
    final int ticket = _generation;
    emit(
      state.copyWith(
        currentActionKey: 'save-menu-schedule-$menuId',
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      await repository.syncMenuAvailabilityRules(menuId, rules);
      if (ticket != _generation || isClosed) return false;

      // The sync endpoint is complete replacement. The explicit reload is the
      // persistence confirmation for the editor; a 200 response alone is not
      // allowed to clear the dirty draft.
      late final List<MenuScheduleRule> updated;
      try {
        updated = await repository.listMenuAvailabilityRules(menuId);
      } catch (_) {
        rethrow;
      }
      if (ticket != _generation || isClosed) return false;

      Map<int, ResolvedMenu> previewMenus = state.previewMenus;
      bool previewUnavailable = state.previewUnavailable;
      try {
        final ResolvedPreview preview = await repository.previewMenuCollection(
          ReviewContext(
            branchId: state.selectedBranch!.id,
            channel: state.selectedChannel!,
          ),
        );
        if (ticket != _generation || isClosed) return false;
        previewMenus = <int, ResolvedMenu>{
          for (final ResolvedMenu menu in preview.menus) menu.id: menu,
        };
        previewUnavailable = false;
      } catch (_) {
        rethrow;
      }
      if (ticket != _generation || isClosed) return false;
      emit(
        state.copyWith(
          scheduleRules: <int, List<MenuScheduleRule>>{
            ...state.scheduleRules,
            menuId: updated,
          },
          previewMenus: previewMenus,
          previewUnavailable: previewUnavailable,
          clearAction: true,
        ),
      );
      return true;
    } catch (error) {
      if (ticket != _generation || isClosed) return false;
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: 'Couldn\'t save Menu schedule. Try again.',
          fieldErrors: _errors(error),
        ),
      );
      return false;
    }
  }

  /// Checks one saved Menu schedule through the resolver.  The schedule sheet
  /// owns local edits, so this intentionally never evaluates a local draft.
  /// Keeping it independent from [currentActionKey] means a check failure
  /// cannot turn a successful schedule save into a failed editor state.
  Future<MenuScheduleCheck> checkMenuSchedule(int menuId, DateTime at) async {
    if (!state.hasScope) throw StateError('A branch and channel are required.');
    final context = ReviewContext(
      branchId: state.selectedBranch!.id,
      channel: state.selectedChannel!,
      evaluationAt: at,
    );
    return repository.previewMenuSchedule(menuId, context);
  }

  Future<void> assignMenu(MenuRecord menu) async {
    if (!state.hasScope ||
        menu.isArchived ||
        state.hasArchivedAssignment ||
        state.isBusy ||
        state.assignments.any((assignment) => assignment.menuId == menu.id))
      return;
    final List<MenuAssignmentDraft> next = _drafts(<MenuAssignment>[
      ...state.orderedAssignments,
      MenuAssignment(
        id: -menu.id,
        menuId: menu.id,
        branchId: state.selectedBranch!.id,
        channel: state.selectedChannel!,
        priority: state.assignments.length,
        isActive: true,
        createdAt: null,
        updatedAt: null,
        menu: menu,
      ),
    ]);
    await _syncAssignments(next, 'assign-${menu.id}', 'Menu assigned.');
  }

  Future<void> setAssignmentActive(int menuId, bool isActive) async {
    final List<MenuAssignment> next = state.orderedAssignments
        .map(
          (assignment) => assignment.menuId == menuId
              ? assignment.copyWith(isActive: isActive)
              : assignment,
        )
        .toList(growable: false);
    await _syncAssignments(
      _drafts(next),
      'assignment-$menuId',
      isActive ? 'Assignment activated.' : 'Assignment deactivated.',
    );
  }

  Future<void> removeAssignment(int menuId) => _syncAssignments(
    _drafts(
      state.orderedAssignments
          .where((assignment) => assignment.menuId != menuId)
          .toList(growable: false),
    ),
    'remove-$menuId',
    'Menu assignment removed.',
  );

  void startReordering() {
    if (!state.canReorder) return;
    emit(
      state.copyWith(
        isReordering: true,
        reorderDraft: state.orderedAssignments,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void moveReorderDraft(int menuId, int direction) {
    if (!state.isReordering || state.isBusy) return;
    final List<MenuAssignment> old = state.reorderDraft;
    final int index = old.indexWhere(
      (assignment) => assignment.menuId == menuId,
    );
    final int target = index + direction;
    if (index < 0 || target < 0 || target >= old.length) return;
    final List<MenuAssignment> moved = List<MenuAssignment>.of(old);
    final MenuAssignment item = moved.removeAt(index);
    moved.insert(target, item);
    emit(
      state.copyWith(reorderDraft: _withPriorities(moved), clearError: true),
    );
  }

  Future<void> doneReordering() async {
    if (!state.isReordering || state.isBusy || !state.hasScope) return;
    final int ticket = _generation;
    final int branchId = state.selectedBranch!.id;
    final String channel = state.selectedChannel!;
    final List<MenuAssignment> draft = state.reorderDraft;
    emit(state.copyWith(currentActionKey: 'save-reorder', clearError: true));
    try {
      await repository.syncMenuAssignments(
        branchId: branchId,
        channel: channel,
        assignments: _drafts(draft),
      );
      if (ticket != _generation || isClosed) return;
      // Reconcile with the exact authoritative scope. Reordering intentionally
      // does not fetch previews, schedules, or individual Menu details.
      final List<MenuAssignment> refreshed = await repository
          .listMenuAssignments(branchId: branchId, channel: channel);
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          status: MenuAssignmentsStatus.loaded,
          assignments: refreshed,
          isReordering: false,
          reorderDraft: const <MenuAssignment>[],
          clearAction: true,
        ),
      );
    } catch (error) {
      if (ticket != _generation || isClosed) return;
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: _message(error),
          fieldErrors: _errors(error),
        ),
      );
    }
  }

  Future<void> saveScheduleRule(
    int menuId,
    MenuScheduleRuleDraft draft, {
    int? replacingRuleId,
  }) async {
    if (!state.hasScope || state.isBusy || !_validSchedule(draft)) return;
    final List<MenuScheduleRule> existing =
        state.scheduleRules[menuId] ?? const <MenuScheduleRule>[];
    final List<Map<String, dynamic>> payload =
        existing
            .where((rule) => rule.id != replacingRuleId)
            .map((rule) => rule.toSyncJson())
            .toList(growable: true)
          ..add(
            draft.toJson(
              branchId: state.selectedBranch!.id,
              channel: state.selectedChannel,
            ),
          );
    await _syncSchedule(
      menuId,
      payload,
      'schedule-$menuId',
      replacingRuleId == null
          ? 'Schedule rule added.'
          : 'Schedule rule updated.',
    );
  }

  Future<void> removeScheduleRule(int menuId, int ruleId) async {
    final List<MenuScheduleRule> existing =
        state.scheduleRules[menuId] ?? const <MenuScheduleRule>[];
    await _syncSchedule(
      menuId,
      existing
          .where((rule) => rule.id != ruleId)
          .map((rule) => rule.toSyncJson())
          .toList(growable: false),
      'rule-$ruleId',
      'Schedule rule removed.',
    );
  }

  Future<void> _syncAssignments(
    List<MenuAssignmentDraft> drafts,
    String key,
    String success,
  ) async {
    if (!state.hasScope || state.isBusy) return;
    emit(
      state.copyWith(
        currentActionKey: key,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      await repository.syncMenuAssignments(
        branchId: state.selectedBranch!.id,
        channel: state.selectedChannel!,
        assignments: drafts,
      );
      final int ticket = ++_generation;
      await _loadScope(ticket, refresh: true);
      emit(state.copyWith(clearAction: true, successMessage: success));
    } catch (error) {
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: _message(error),
          fieldErrors: _errors(error),
        ),
      );
    }
  }

  Future<void> _syncSchedule(
    int menuId,
    List<Map<String, dynamic>> rules,
    String key,
    String success,
  ) async {
    emit(
      state.copyWith(
        currentActionKey: key,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final List<MenuScheduleRule> updated = await repository
          .syncMenuAvailabilityRules(menuId, rules);
      emit(
        state.copyWith(
          scheduleRules: <int, List<MenuScheduleRule>>{
            ...state.scheduleRules,
            menuId: updated,
          },
          clearAction: true,
          successMessage: success,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          clearAction: true,
          errorMessage: _message(error),
          fieldErrors: _errors(error),
        ),
      );
    }
  }

  List<MenuAssignmentDraft> _drafts(List<MenuAssignment> assignments) =>
      _withPriorities(assignments)
          .map(
            (assignment) => MenuAssignmentDraft(
              menuId: assignment.menuId,
              priority: assignment.priority,
              isActive: assignment.isActive,
            ),
          )
          .toList(growable: false);
  List<MenuAssignment> _withPriorities(List<MenuAssignment> values) => values
      .asMap()
      .entries
      .map((entry) => entry.value.copyWith(priority: entry.key))
      .toList(growable: false);

  bool _validSchedule(MenuScheduleRuleDraft draft) {
    final List<String> errors = <String>[];
    final RegExp time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if ((draft.startTime.isEmpty) != (draft.endTime.isEmpty))
      errors.add('Start and end time must be supplied together.');
    if (draft.startTime.isNotEmpty &&
        (!time.hasMatch(draft.startTime) || !time.hasMatch(draft.endTime)))
      errors.add('Times must use HH:mm.');
    if (draft.startTime.isNotEmpty && draft.startTime == draft.endTime)
      errors.add('Start and end times must differ.');
    if (draft.startDate.isNotEmpty &&
        draft.endDate.isNotEmpty &&
        draft.startDate.compareTo(draft.endDate) > 0)
      errors.add('End date must be after or equal to start date.');
    if (int.tryParse(draft.priority) == null)
      errors.add('Priority must be an integer.');
    if (errors.isEmpty) return true;
    emit(
      state.copyWith(
        errorMessage: errors.first,
        fieldErrors: <String, List<String>>{'rules': errors},
      ),
    );
    return false;
  }

  String? _schedulePayloadError(List<Map<String, dynamic>> rules) {
    final RegExp time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    final RegExp date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final Set<String> canonical = <String>{};
    for (final (index, rule) in rules.indexed) {
      final Object? branchId = rule['branchId'];
      if (branchId != null && branchId is! int) {
        return 'Rule ${index + 1}: branch must be an integer.';
      }
      final Object? channel = rule['channel'];
      if (channel != null && channel is! String) {
        return 'Rule ${index + 1}: channel is invalid.';
      }
      final Object? dayOfWeek = rule['dayOfWeek'];
      if (dayOfWeek != null &&
          (dayOfWeek is! int || dayOfWeek < 0 || dayOfWeek > 6)) {
        return 'Rule ${index + 1}: day of week must be between 0 and 6.';
      }
      final String? start = rule['startTime']?.toString();
      final String? end = rule['endTime']?.toString();
      if ((start == null) != (end == null)) {
        return 'Start and end time must be supplied together.';
      }
      if (start != null &&
          (!time.hasMatch(start) || !time.hasMatch(end!) || start == end)) {
        return 'Enter two different times in HH:mm format.';
      }
      final String? startDate = rule['startDate']?.toString();
      final String? endDate = rule['endDate']?.toString();
      if ((startDate != null && !date.hasMatch(startDate)) ||
          (endDate != null && !date.hasMatch(endDate))) {
        return 'Rule ${index + 1}: dates must use YYYY-MM-DD.';
      }
      if (startDate != null &&
          endDate != null &&
          startDate.compareTo(endDate) > 0) {
        return 'End date must be after or equal to start date.';
      }
      final Object? priority = rule['priority'];
      if (priority is! int) {
        return 'Rule ${index + 1}: priority must be an integer.';
      }
      if (rule['isActive'] is! bool) {
        return 'Rule ${index + 1}: active status must be true or false.';
      }
      // This is intentionally the same identity as the backend service. Do
      // not deduplicate windows: reject only a payload that the server would
      // reject as an identical canonical rule.
      final String key = <Object?>[
        branchId,
        channel,
        dayOfWeek,
        start,
        end,
        startDate,
        endDate,
        priority,
      ].map((value) => value ?? '').join('|');
      if (!canonical.add(key)) {
        return 'Rule ${index + 1} duplicates another schedule rule.';
      }
    }
    return null;
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update assignments and schedules.';
  Map<String, List<String>> _errors(Object error) => error is ApiException
      ? error.validationErrors ?? const <String, List<String>>{}
      : const <String, List<String>>{};
}
