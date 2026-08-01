// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../pos/models/branch.dart';
import '../../menus/models/menu_filter.dart';
import '../../menus/models/menu_models.dart';
import '../../repositories/menu_catalog_repository.dart';
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

class MenuAssignmentsState extends Equatable {
  const MenuAssignmentsState({
    this.status = MenuAssignmentsStatus.initial,
    this.branches = const <Branch>[],
    this.selectedBranch,
    this.selectedChannel = 'pos',
    this.assignments = const <MenuAssignment>[],
    this.availableMenus = const <MenuRecord>[],
    this.scheduleRules = const <int, List<MenuScheduleRule>>{},
    this.scheduleLoadFailures = const <int>{},
    this.errorMessage,
    this.fieldErrors = const <String, List<String>>{},
    this.currentActionKey,
    this.successMessage,
  });
  final MenuAssignmentsStatus status;
  final List<Branch> branches;
  final Branch? selectedBranch;
  final String selectedChannel;
  final List<MenuAssignment> assignments;
  final List<MenuRecord> availableMenus;
  final Map<int, List<MenuScheduleRule>> scheduleRules;
  final Set<int> scheduleLoadFailures;
  final String? errorMessage, currentActionKey, successMessage;
  final Map<String, List<String>> fieldErrors;
  bool get isBusy =>
      status == MenuAssignmentsStatus.loading ||
      status == MenuAssignmentsStatus.loadingContext ||
      status == MenuAssignmentsStatus.refreshing ||
      currentActionKey != null;
  bool get hasScope => selectedBranch != null;
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
    List<MenuAssignment>? assignments,
    List<MenuRecord>? availableMenus,
    Map<int, List<MenuScheduleRule>>? scheduleRules,
    Set<int>? scheduleLoadFailures,
    String? errorMessage,
    Map<String, List<String>>? fieldErrors,
    String? currentActionKey,
    String? successMessage,
    bool clearError = false,
    bool clearAction = false,
    bool clearSuccess = false,
  }) => MenuAssignmentsState(
    status: status ?? this.status,
    branches: branches ?? this.branches,
    selectedBranch: clearBranch ? null : selectedBranch ?? this.selectedBranch,
    selectedChannel: selectedChannel ?? this.selectedChannel,
    assignments: assignments ?? this.assignments,
    availableMenus: availableMenus ?? this.availableMenus,
    scheduleRules: scheduleRules ?? this.scheduleRules,
    scheduleLoadFailures: scheduleLoadFailures ?? this.scheduleLoadFailures,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    fieldErrors: clearError
        ? const <String, List<String>>{}
        : fieldErrors ?? this.fieldErrors,
    currentActionKey: clearAction
        ? null
        : currentActionKey ?? this.currentActionKey,
    successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    branches,
    selectedBranch,
    selectedChannel,
    assignments,
    availableMenus,
    scheduleRules,
    scheduleLoadFailures,
    errorMessage,
    fieldErrors,
    currentActionKey,
    successMessage,
  ];
}

class MenuAssignmentsCubit extends Cubit<MenuAssignmentsState> {
  MenuAssignmentsCubit({required this.repository})
    : super(const MenuAssignmentsState());
  final MenuCatalogRepository repository;
  int _generation = 0;

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
            : refresh
            ? MenuAssignmentsStatus.refreshing
            : MenuAssignmentsStatus.loading,
        assignments: const <MenuAssignment>[],
        availableMenus: const <MenuRecord>[],
        scheduleRules: const <int, List<MenuScheduleRule>>{},
        scheduleLoadFailures: const <int>{},
        selectedChannel: channel ?? state.selectedChannel,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final List<Branch> branches = state.branches.isEmpty
          ? (await repository.listAssignmentBranches())
                .where((b) => b.isActive)
                .toList(growable: false)
          : state.branches;
      if (ticket != _generation) return;
      final int? wantedBranch = branchId ?? state.selectedBranch?.id;
      final Branch? selected =
          branches.where((b) => b.id == wantedBranch).firstOrNull ??
          (branches.isEmpty ? null : branches.first);
      if (selected == null) {
        emit(
          state.copyWith(
            status: MenuAssignmentsStatus.loaded,
            branches: branches,
            clearBranch: true,
          ),
        );
        return;
      }
      final String selectedChannel = channel ?? state.selectedChannel;
      final results = await Future.wait<Object>(<Future<Object>>[
        repository.listMenuAssignments(
          branchId: selected.id,
          channel: selectedChannel,
        ),
        repository.listMenus(
          filter: const MenuFilter(status: 'active'),
          page: 1,
          perPage: 100,
        ),
      ]);
      if (ticket != _generation) return;
      final List<MenuAssignment> assignments =
          results[0] as List<MenuAssignment>;
      final List<MenuRecord> allMenus =
          (results[1] as dynamic).items as List<MenuRecord>;
      final Set<int> assignedIds = assignments.map((a) => a.menuId).toSet();
      emit(
        state.copyWith(
          status: MenuAssignmentsStatus.loaded,
          branches: branches,
          selectedBranch: selected,
          selectedChannel: selectedChannel,
          assignments: assignments,
          availableMenus: allMenus
              .where((m) => !m.isArchived && !assignedIds.contains(m.id))
              .toList(growable: false),
        ),
      );
      await _loadSchedules(ticket, assignments);
    } catch (error) {
      if (ticket != _generation) return;
      emit(
        state.copyWith(
          status: MenuAssignmentsStatus.failure,
          errorMessage: _message(error),
          fieldErrors: _errors(error),
        ),
      );
    }
  }

  Future<void> selectBranch(int id) => load(branchId: id);
  Future<void> selectChannel(String channel) => load(channel: channel);
  Future<void> refresh() => load(refresh: true);

  Future<void> assignMenu(MenuRecord menu) async {
    if (!state.hasScope ||
        menu.isArchived ||
        state.isBusy ||
        state.assignments.any((a) => a.menuId == menu.id))
      return;
    final List<MenuAssignmentDraft> next = _drafts(<MenuAssignment>[
      ...state.orderedAssignments,
      MenuAssignment(
        id: -menu.id,
        menuId: menu.id,
        branchId: state.selectedBranch!.id,
        channel: state.selectedChannel,
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
        .map((a) => a.menuId == menuId ? a.copyWith(isActive: isActive) : a)
        .toList(growable: false);
    await _syncAssignments(
      _drafts(next),
      'assignment-$menuId',
      isActive ? 'Assignment activated.' : 'Assignment deactivated.',
    );
  }

  Future<void> removeAssignment(int menuId) async => _syncAssignments(
    _drafts(
      state.orderedAssignments
          .where((a) => a.menuId != menuId)
          .toList(growable: false),
    ),
    'remove-$menuId',
    'Menu assignment removed.',
  );

  Future<void> moveAssignment(int menuId, int direction) async {
    if (state.isBusy) return;
    final List<MenuAssignment> old = state.orderedAssignments;
    final int index = old.indexWhere((a) => a.menuId == menuId);
    final int target = index + direction;
    if (index < 0 || target < 0 || target >= old.length) return;
    final List<MenuAssignment> moved = List<MenuAssignment>.of(old);
    final MenuAssignment item = moved.removeAt(index);
    moved.insert(target, item);
    emit(
      state.copyWith(
        assignments: _withPriorities(moved),
        currentActionKey: 'reorder-$menuId',
        clearError: true,
      ),
    );
    try {
      await repository.syncMenuAssignments(
        branchId: state.selectedBranch!.id,
        channel: state.selectedChannel,
        assignments: _drafts(moved),
      );
      await load(
        branchId: state.selectedBranch!.id,
        channel: state.selectedChannel,
        refresh: true,
      );
      emit(
        state.copyWith(
          clearAction: true,
          successMessage: 'Assignment order updated.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          assignments: old,
          currentActionKey: null,
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
        channel: state.selectedChannel,
        assignments: drafts,
      );
      await load(
        branchId: state.selectedBranch!.id,
        channel: state.selectedChannel,
        refresh: true,
      );
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
      final updated = await repository.syncMenuAvailabilityRules(menuId, rules);
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

  Future<void> _loadSchedules(
    int ticket,
    List<MenuAssignment> assignments,
  ) async {
    final Map<int, List<MenuScheduleRule>> rules =
        <int, List<MenuScheduleRule>>{};
    final Set<int> failures = <int>{};
    await Future.wait(
      assignments.map((assignment) async {
        try {
          rules[assignment.menuId] = await repository.listMenuAvailabilityRules(
            assignment.menuId,
          );
        } catch (_) {
          failures.add(assignment.menuId);
        }
      }),
    );
    if (ticket != _generation || isClosed) return;
    emit(state.copyWith(scheduleRules: rules, scheduleLoadFailures: failures));
  }

  List<MenuAssignmentDraft> _drafts(List<MenuAssignment> assignments) =>
      _withPriorities(assignments)
          .map(
            (a) => MenuAssignmentDraft(
              menuId: a.menuId,
              priority: a.priority,
              isActive: a.isActive,
            ),
          )
          .toList(growable: false);
  List<MenuAssignment> _withPriorities(List<MenuAssignment> values) => values
      .asMap()
      .entries
      .map((e) => e.value.copyWith(priority: e.key))
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

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Unable to update assignments and schedules.';
  Map<String, List<String>> _errors(Object error) => error is ApiException
      ? error.validationErrors ?? const <String, List<String>>{}
      : const <String, List<String>>{};
}
