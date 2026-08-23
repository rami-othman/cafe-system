import 'package:flutter_bloc/flutter_bloc.dart';

import '../../pos/models/branch.dart';
import '../models/finance_setup_models.dart';
import '../repositories/finance_setup_repository.dart';
import 'finance_setup_state.dart';

class FinanceSetupCubit extends Cubit<FinanceSetupState> {
  FinanceSetupCubit({required FinanceSetupRepository repository})
    : _repository = repository,
      super(const FinanceSetupState());

  final FinanceSetupRepository _repository;

  Future<void> loadDashboard() => _load(() async {
    final SetupStatus status = await _repository.getSetupStatus();
    emit(state.copyWith(status: status, clearError: true));
  });

  Future<void> loadWarehouses({String? search}) => _load(() async {
    final Future<List<WarehouseLocation>> warehousesFuture = _repository
        .getWarehouses(search: search);
    final Future<List<Branch>> branchesFuture = _repository.getBranches();
    final List<WarehouseLocation> warehouses = await warehousesFuture;
    final List<Branch> branches = await branchesFuture;
    emit(
      state.copyWith(
        warehouses: warehouses,
        branches: branches,
        clearError: true,
      ),
    );
  });

  Future<void> loadAccounts({String? search}) => _load(() async {
    final List<FinancialAccount> accounts = await _repository.getAccounts(
      search: search,
    );
    emit(state.copyWith(accounts: accounts, clearError: true));
  });

  Future<void> loadEntries() => _load(() async {
    final Future<List<JournalEntry>> entriesFuture = _repository
        .getJournalEntries();
    final Future<List<FinancialAccount>> accountsFuture = _repository
        .getAccounts();
    final List<JournalEntry> entries = await entriesFuture;
    final List<FinancialAccount> accounts = await accountsFuture;
    emit(
      state.copyWith(entries: entries, accounts: accounts, clearError: true),
    );
  });

  Future<bool> saveWarehouse(Map<String, dynamic> payload, {int? id}) =>
      _save(() async {
        await _repository.saveWarehouse(payload, id: id);
        await loadWarehouses();
      });
  Future<bool> setWarehouseStatus(int id, bool isActive) => _save(() async {
    await _repository.setWarehouseStatus(id, isActive);
    await loadWarehouses();
  });
  Future<bool> saveAccount(Map<String, dynamic> payload, {int? id}) =>
      _save(() async {
        await _repository.saveAccount(payload, id: id);
        await loadAccounts();
      });
  Future<bool> setAccountStatus(int id, bool isActive) => _save(() async {
    await _repository.setAccountStatus(id, isActive);
    await loadAccounts();
  });
  Future<bool> createDraft(Map<String, dynamic> payload) => _save(() async {
    await _repository.createDraft(payload);
    await loadEntries();
  });
  Future<bool> postEntry(int id) => _save(() async {
    await _repository.postJournalEntry(id);
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
