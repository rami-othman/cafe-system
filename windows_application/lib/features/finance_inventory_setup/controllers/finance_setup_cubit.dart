import 'package:flutter_bloc/flutter_bloc.dart';

import '../../pos/models/branch.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import 'finance_setup_state.dart';

class FinanceSetupCubit extends Cubit<FinanceSetupState> {
  FinanceSetupCubit({required this.repository})
    : super(const FinanceSetupState());

  final FinanceSetupRepository repository;

  Future<void> loadDashboard() => _load(() async {
    final SetupStatus status = await repository.getSetupStatus();
    emit(state.copyWith(status: status, clearError: true));
  });

  Future<void> loadWarehouses({String? search}) => _load(() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      repository.getWarehouses(search: search),
      repository.getBranches(),
    ]);
    emit(
      state.copyWith(
        warehouses: results[0] as List<WarehouseLocation>,
        branches: results[1] as List<Branch>,
        clearError: true,
      ),
    );
  });

  Future<void> loadAccounts({
    String? search,
    String? group,
    String? status,
    String? system,
  }) => _load(() async {
    final List<FinancialAccount> accounts = await repository.getAccounts(
      search: search,
      group: group,
      status: status,
      system: system,
    );
    emit(state.copyWith(accounts: accounts, clearError: true));
  });

  Future<void> loadEntries({
    String? search,
    String? status,
    String? sourceType,
    int? branchId,
    String? from,
    String? to,
  }) => _load(() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      repository.getJournalEntries(
        search: search,
        status: status,
        sourceType: sourceType,
        branchId: branchId,
        from: from,
        to: to,
      ),
      repository.getAccounts(),
      repository.getBranches(),
    ]);
    emit(
      state.copyWith(
        entries: results[0] as List<JournalEntry>,
        accounts: results[1] as List<FinancialAccount>,
        branches: results[2] as List<Branch>,
        clearError: true,
      ),
    );
  });

  Future<bool> saveWarehouse(Map<String, dynamic> payload, {int? id}) =>
      _save(() async {
        await repository.saveWarehouse(payload, id: id);
        await loadWarehouses();
      });
  Future<bool> setWarehouseStatus(int id, bool isActive) => _save(() async {
    await repository.setWarehouseStatus(id, isActive);
    await loadWarehouses();
  });
  Future<bool> saveAccount(Map<String, dynamic> payload, {int? id}) =>
      _save(() async {
        await repository.saveAccount(payload, id: id);
        await loadAccounts();
      });
  Future<bool> setAccountStatus(int id, bool isActive) => _save(() async {
    await repository.setAccountStatus(id, isActive);
    await loadAccounts();
  });
  Future<bool> createDraft(Map<String, dynamic> payload) => _save(() async {
    await repository.createDraft(payload);
    await loadEntries();
  });
  Future<bool> postEntry(int id) => _save(() async {
    await repository.postJournalEntry(id);
    await loadEntries();
  });
  Future<JournalEntry?> getEntry(int id) async {
    try {
      return await repository.getJournalEntry(id);
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
      return null;
    }
  }

  Future<bool> reverseEntry(int id) => _save(() async {
    await repository.reverseJournalEntry(id);
    await loadEntries();
  });

  Future<void> _load(Future<void> Function() action) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await action();
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<bool> _save(Future<void> Function() action) async {
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await action();
      return true;
    } catch (error) {
      emit(state.copyWith(errorMessage: error.toString()));
      return false;
    } finally {
      emit(state.copyWith(isSaving: false));
    }
  }
}
