import 'package:equatable/equatable.dart';

import '../../pos/models/branch.dart';
import '../models/finance_setup_models.dart';

class FinanceSetupState extends Equatable {
  const FinanceSetupState({
    this.status,
    this.warehouses = const <WarehouseLocation>[],
    this.accounts = const <FinancialAccount>[],
    this.entries = const <JournalEntry>[],
    this.branches = const <Branch>[],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });
  final SetupStatus? status;
  final List<WarehouseLocation> warehouses;
  final List<FinancialAccount> accounts;
  final List<JournalEntry> entries;
  final List<Branch> branches;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  FinanceSetupState copyWith({
    SetupStatus? status,
    List<WarehouseLocation>? warehouses,
    List<FinancialAccount>? accounts,
    List<JournalEntry>? entries,
    List<Branch>? branches,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) => FinanceSetupState(
    status: status ?? this.status,
    warehouses: warehouses ?? this.warehouses,
    accounts: accounts ?? this.accounts,
    entries: entries ?? this.entries,
    branches: branches ?? this.branches,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    warehouses,
    accounts,
    entries,
    branches,
    isLoading,
    isSaving,
    errorMessage,
  ];
}
