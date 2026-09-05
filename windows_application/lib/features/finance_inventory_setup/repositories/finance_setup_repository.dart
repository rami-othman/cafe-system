import '../../../core/network/dio_api_client.dart';
import '../../pos/models/branch.dart';
import '../../pos/models/json_helpers.dart';
import '../models/finance_report_models.dart';
import '../models/finance_setup_models.dart';
import '../widgets/finance_pagination.dart';

class FinanceSetupRepository {
  const FinanceSetupRepository(this._api);
  final DioApiClient _api;

  /// Finance operational endpoints intentionally stay untyped here until each
  /// response has a dedicated screen model.  The backend remains the only
  /// financial calculation source; the workspace only presents these payloads.
  Future<Map<String, dynamic>> getFinanceMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => Map<String, dynamic>.from(
    await _api.get(path, queryParameters: queryParameters) as Map,
  );

  Future<List<Map<String, dynamic>>> getFinanceList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async =>
      readMapList(await _api.get(path, queryParameters: queryParameters));

  /// Reads a paginated Finance response without dropping the server metadata.
  /// Finance tables always use the backend's page boundary; no rows are
  /// sliced or counted in Flutter.
  Future<FinancePage<Map<String, dynamic>>> getFinancePage(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final Map<String, dynamic> response = Map<String, dynamic>.from(
      await _api.getRaw(path, queryParameters: queryParameters) as Map,
    );
    final List<Map<String, dynamic>> rows = readMapList(response['data']);
    final Map<String, dynamic>? meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : null;
    return FinancePage<Map<String, dynamic>>(
      items: rows,
      meta: FinancePageMeta.fromJson(meta, total: rows.length),
    );
  }

  Future<SetupStatus> getSetupStatus() async => SetupStatus.fromJson(
    Map<String, dynamic>.from(await _api.get('finance/setup-status') as Map),
  );
  Future<List<Branch>> getBranches() async => readMapList(
    await _api.get('branches'),
  ).map(Branch.fromJson).toList(growable: false);
  Future<List<WarehouseLocation>> getWarehouses({String? search}) async =>
      readMapList(
            await _api.get(
              'warehouses',
              queryParameters: _query(<String, dynamic>{
                'search': search,
                'perPage': 100,
                'status': 'active',
              }),
            ),
          )
          .map(WarehouseLocation.fromJson)
          .where((WarehouseLocation warehouse) => !warehouse.isLegacy)
          .toList(growable: false);
  Future<List<FinancialAccount>> getAccounts({
    String? search,
    String? group,
    String? status,
    String? system,
  }) async => readMapList(
    await _api.get(
      'finance/accounts',
      queryParameters: _query(<String, dynamic>{
        'search': search,
        'group': group,
        'status': status,
        'system': system,
        'perPage': 200,
      }),
    ),
  ).map(FinancialAccount.fromJson).toList(growable: false);
  Future<FinancialAccount> getAccount(int id) async =>
      FinancialAccount.fromJson(
        Map<String, dynamic>.from(
          await _api.get('finance/accounts/$id') as Map,
        ),
      );
  Future<List<JournalEntry>> getJournalEntries({
    String? search,
    String? status,
    String? sourceType,
    int? branchId,
    String? from,
    String? to,
  }) async => readMapList(
    await _api.get(
      'finance/journal-entries',
      queryParameters: _query(<String, dynamic>{
        'perPage': 100,
        'search': search,
        'status': status,
        'sourceType': sourceType,
        'branchId': branchId,
        'from': from,
        'to': to,
      }),
    ),
  ).map(JournalEntry.fromJson).toList(growable: false);
  Future<WarehouseLocation> saveWarehouse(
    Map<String, dynamic> payload, {
    int? id,
  }) async => WarehouseLocation.fromJson(
    Map<String, dynamic>.from(
      id == null
          ? await _api.post('warehouses', data: payload)
          : await _api.patch('warehouses/$id', data: payload) as Map,
    ),
  );
  Future<WarehouseLocation> setWarehouseStatus(int id, bool isActive) async =>
      WarehouseLocation.fromJson(
        Map<String, dynamic>.from(
          await _api.patch(
                'warehouses/$id/status',
                data: <String, dynamic>{'isActive': isActive},
              )
              as Map,
        ),
      );
  Future<FinancialAccount> saveAccount(
    Map<String, dynamic> payload, {
    int? id,
  }) async => FinancialAccount.fromJson(
    Map<String, dynamic>.from(
      id == null
          ? await _api.post('finance/accounts', data: payload)
          : await _api.patch('finance/accounts/$id', data: payload) as Map,
    ),
  );
  Future<FinancialAccount> setAccountStatus(int id, bool isActive) async =>
      FinancialAccount.fromJson(
        Map<String, dynamic>.from(
          await _api.patch(
                'finance/accounts/$id/status',
                data: <String, dynamic>{'isActive': isActive},
              )
              as Map,
        ),
      );
  Future<JournalEntry> createDraft(Map<String, dynamic> payload) async =>
      JournalEntry.fromJson(
        Map<String, dynamic>.from(
          await _api.post('finance/journal-entries', data: payload) as Map,
        ),
      );
  Future<JournalEntry> getJournalEntry(int id) async => JournalEntry.fromJson(
    Map<String, dynamic>.from(
      await _api.get('finance/journal-entries/$id') as Map,
    ),
  );
  Future<JournalEntry> postJournalEntry(int id) async => JournalEntry.fromJson(
    Map<String, dynamic>.from(
      await _api.post('finance/journal-entries/$id/post') as Map,
    ),
  );
  Future<JournalEntry> reverseJournalEntry(int id) async =>
      JournalEntry.fromJson(
        Map<String, dynamic>.from(
          await _api.post('finance/journal-entries/$id/reverse') as Map,
        ),
      );
  Future<List<FinancialLocation>> getFinancialLocations(String kind) async =>
      readMapList(
        await _api.get(
          'finance/${kind == 'cash' ? 'cash-accounts' : 'bank-accounts'}',
        ),
      ).map(FinancialLocation.fromJson).toList(growable: false);
  Future<void> createCashTransfer(Map<String, dynamic> payload) =>
      _api.post('finance/cash-transfers', data: payload);
  Future<Map<String, dynamic>> saveFinancialLocation(
    String kind,
    Map<String, dynamic> payload, {
    int? id,
  }) => getFinanceMapFrom(
    id == null
        ? _api.post(
            'finance/${kind == 'cash' ? 'cash-accounts' : 'bank-accounts'}',
            data: payload,
          )
        : _api.patch(
            'finance/${kind == 'cash' ? 'cash-accounts' : 'bank-accounts'}/$id',
            data: payload,
          ),
  );
  Future<FinancialLocation> getFinancialLocation(String kind, int id) async =>
      FinancialLocation.fromJson(
        await getFinanceMap(
          'finance/${kind == 'cash' ? 'cash-accounts' : 'bank-accounts'}/$id',
        ),
      );
  Future<FinancialLocationTransactions> getFinancialLocationTransactions(
    String kind,
    int id, {
    Map<String, dynamic>? queryParameters,
  }) async => FinancialLocationTransactions.fromJson(
    await getFinanceMap(
      'finance/${kind == 'cash' ? 'cash-accounts' : 'bank-accounts'}/$id/transactions',
      queryParameters: queryParameters,
    ),
  );
  Future<void> setFinancialLocationStatus(
    String kind,
    int id,
    bool isActive,
  ) => _api.patch(
    'finance/${kind == 'cash' ? 'cash-accounts' : 'bank-accounts'}/$id/status',
    data: <String, dynamic>{'isActive': isActive},
  );
  Future<void> reverseCashTransfer(int id) =>
      _api.post('finance/cash-transfers/$id/reverse');

  Future<FinancePage<ReconciliationSession>> getReconciliations({
    Map<String, dynamic>? filters,
  }) async {
    final FinancePage<Map<String, dynamic>> page = await getFinancePage(
      'finance/reconciliations',
      queryParameters: filters,
    );
    return FinancePage<ReconciliationSession>(
      items: page.items
          .map(ReconciliationSession.fromJson)
          .toList(growable: false),
      meta: page.meta,
    );
  }

  Future<ReconciliationSession> createReconciliation(
    Map<String, dynamic> payload,
  ) async => ReconciliationSession.fromJson(
    Map<String, dynamic>.from(
      await _api.post('finance/reconciliations', data: payload) as Map,
    ),
  );
  Future<ReconciliationSession> getReconciliation(int id) async =>
      ReconciliationSession.fromJson(
        await getFinanceMap('finance/reconciliations/$id'),
      );
  Future<List<ReconciliationSystemTransaction>> getReconciliationTransactions(
    int id,
  ) async => (await getFinanceList(
    'finance/reconciliations/$id/system-transactions',
  )).map(ReconciliationSystemTransaction.fromJson).toList(growable: false);
  Future<List<ReconciliationSuggestion>> getReconciliationSuggestions(
    int id,
  ) async => (await getFinanceList(
    'finance/reconciliations/$id/suggestions',
  )).map(ReconciliationSuggestion.fromJson).toList(growable: false);
  Future<void> updateReconciliation(int id, Map<String, dynamic> payload) =>
      _api.patch('finance/reconciliations/$id', data: payload);
  Future<void> addReconciliationStatementLine(
    int id,
    Map<String, dynamic> payload,
  ) => _api.post('finance/reconciliations/$id/statement-lines', data: payload);
  Future<void> updateReconciliationStatementLine(
    int reconciliationId,
    int lineId,
    Map<String, dynamic> payload,
  ) => _api.patch(
    'finance/reconciliations/$reconciliationId/statement-lines/$lineId',
    data: payload,
  );
  Future<void> deleteReconciliationStatementLine(
    int reconciliationId,
    int lineId,
  ) => _api.delete(
    'finance/reconciliations/$reconciliationId/statement-lines/$lineId',
  );
  Future<void> matchReconciliation(int id, Map<String, dynamic> payload) =>
      _api.post('finance/reconciliations/$id/matches', data: payload);
  Future<void> unmatchReconciliation(int reconciliationId, int matchId) =>
      _api.delete('finance/reconciliations/$reconciliationId/matches/$matchId');
  Future<void> completeReconciliation(int id) =>
      _api.post('finance/reconciliations/$id/complete');

  Future<FinancePage<DailyClosingListItem>> getDailyClosings({
    Map<String, dynamic>? filters,
  }) async {
    final FinancePage<Map<String, dynamic>> page = await getFinancePage(
      'finance/daily-closings',
      queryParameters: filters,
    );
    return FinancePage<DailyClosingListItem>(
      items: page.items
          .map(DailyClosingListItem.fromJson)
          .toList(growable: false),
      meta: page.meta,
    );
  }

  Future<DailyClosingDetail> getDailyClosingPreview({
    required int branchId,
    required String date,
  }) async => DailyClosingDetail.fromJson(
    await getFinanceMap(
      'finance/daily-closing',
      queryParameters: <String, dynamic>{'branchId': branchId, 'date': date},
    ),
  );
  Future<DailyClosingDetail> getDailyClosing(int id) async =>
      DailyClosingDetail.fromJson(
        await getFinanceMap('finance/daily-closings/$id'),
      );
  Future<DailyClosingDetail> updateDailyClosing(
    int id,
    Map<String, dynamic> payload,
  ) async => DailyClosingDetail.fromJson(
    await getFinanceMapFrom(
      _api.patch('finance/daily-closings/$id', data: payload),
    ),
  );
  Future<DailyClosingDetail> closeDailyClosing(
    int id,
    Map<String, dynamic> payload,
  ) async => DailyClosingDetail.fromJson(
    await getFinanceMapFrom(
      _api.post('finance/daily-closings/$id/close', data: payload),
    ),
  );

  Future<Map<String, dynamic>> getAccountingPeriod(int id) =>
      getFinanceMap('finance/accounting-periods/$id');
  Future<void> closeAccountingPeriod(int id) =>
      _api.post('finance/accounting-periods/$id/close');
  Future<void> lockAccountingPeriod(int id) =>
      _api.post('finance/accounting-periods/$id/lock');
  Future<List<PaymentMethodSetting>> getPaymentMethods() async => readMapList(
    await _api.get('finance/payment-methods'),
  ).map(PaymentMethodSetting.fromJson).toList(growable: false);
  Future<void> savePaymentMethod(Map<String, dynamic> payload, {int? id}) =>
      id == null
      ? _api.post('finance/payment-methods', data: payload)
      : _api.patch('finance/payment-methods/$id', data: payload);
  Future<void> setPaymentMethodStatus(int id, bool isActive) => _api.patch(
    'finance/payment-methods/$id/status',
    data: <String, dynamic>{'isActive': isActive},
  );
  Future<List<ExpenseCategory>> getExpenseCategories() async => readMapList(
    await _api.get('finance/expense-categories'),
  ).map(ExpenseCategory.fromJson).toList(growable: false);
  Future<void> saveExpenseCategory(Map<String, dynamic> payload, {int? id}) =>
      id == null
      ? _api.post('finance/expense-categories', data: payload)
      : _api.patch('finance/expense-categories/$id', data: payload);
  Future<void> setExpenseCategoryStatus(int id, bool isActive) => _api.patch(
    'finance/expense-categories/$id/status',
    data: <String, dynamic>{'isActive': isActive},
  );
  Future<List<ExpenseRecord>> getExpenses({
    Map<String, dynamic>? filters,
  }) async => readMapList(
    await _api.get('finance/expenses', queryParameters: filters),
  ).map(ExpenseRecord.fromJson).toList(growable: false);
  Future<ExpenseRecord> getExpense(int id) async => ExpenseRecord.fromJson(
    Map<String, dynamic>.from(await _api.get('finance/expenses/$id') as Map),
  );
  Future<void> saveExpense(Map<String, dynamic> payload, {int? id}) =>
      id == null
      ? _api.post('finance/expenses', data: payload)
      : _api.patch('finance/expenses/$id', data: payload);
  Future<void> expenseAction(
    int id,
    String action, [
    Map<String, dynamic>? payload,
  ]) => _api.post('finance/expenses/$id/$action', data: payload);
  Future<void> payExpense(int id, Map<String, dynamic> payload) =>
      _api.post('finance/expenses/$id/pay', data: payload);

  Future<List<Supplier>> getSuppliers({Map<String, dynamic>? filters}) async =>
      readMapList(
        await _api.get('finance/suppliers', queryParameters: filters),
      ).map(Supplier.fromJson).toList(growable: false);
  Future<Supplier> getSupplier(int id) async => Supplier.fromJson(
    Map<String, dynamic>.from(await _api.get('finance/suppliers/$id') as Map),
  );
  Future<void> saveSupplier(Map<String, dynamic> payload, {int? id}) =>
      id == null
      ? _api.post('finance/suppliers', data: payload)
      : _api.patch('finance/suppliers/$id', data: payload);
  Future<void> setSupplierStatus(int id, bool isActive) => _api.patch(
    'finance/suppliers/$id/status',
    data: <String, dynamic>{'isActive': isActive},
  );
  Future<List<SupplierStatementLine>> getSupplierStatement(int id) async =>
      readMapList(
        (await _api.get('finance/suppliers/$id/statement') as Map)['lines'],
      ).map(SupplierStatementLine.fromJson).toList(growable: false);

  Future<List<SupplierInvoice>> getSupplierInvoices({
    Map<String, dynamic>? filters,
  }) async => readMapList(
    await _api.get('finance/supplier-invoices', queryParameters: filters),
  ).map(SupplierInvoice.fromJson).toList(growable: false);
  Future<SupplierInvoice> getSupplierInvoice(int id) async =>
      SupplierInvoice.fromJson(
        Map<String, dynamic>.from(
          await _api.get('finance/supplier-invoices/$id') as Map,
        ),
      );
  Future<void> saveSupplierInvoice(Map<String, dynamic> payload, {int? id}) =>
      id == null
      ? _api.post('finance/supplier-invoices', data: payload)
      : _api.patch('finance/supplier-invoices/$id', data: payload);
  Future<void> postSupplierInvoice(int id, String idempotencyKey) => _api.post(
    'finance/supplier-invoices/$id/post',
    data: <String, dynamic>{'idempotencyKey': idempotencyKey},
  );
  Future<void> reverseSupplierInvoice(int id) =>
      _api.post('finance/supplier-invoices/$id/reverse');

  Future<List<SupplierPayment>> getSupplierPayments({
    Map<String, dynamic>? filters,
  }) async => readMapList(
    await _api.get('finance/supplier-payments', queryParameters: filters),
  ).map(SupplierPayment.fromJson).toList(growable: false);
  Future<SupplierPayment> getSupplierPayment(int id) async =>
      SupplierPayment.fromJson(
        Map<String, dynamic>.from(
          await _api.get('finance/supplier-payments/$id') as Map,
        ),
      );
  Future<void> paySupplierInvoices(Map<String, dynamic> payload) =>
      _api.post('finance/supplier-payments', data: payload);
  Future<void> reverseSupplierPayment(int id) =>
      _api.post('finance/supplier-payments/$id/reverse');

  Future<ProfitAndLossReport> getProfitAndLoss({
    Map<String, dynamic>? filters,
  }) async => ProfitAndLossReport.fromJson(
    await getFinanceMap(
      'finance/reports/profit-loss',
      queryParameters: filters,
    ),
  );
  Future<BalanceSheetReport> getBalanceSheet({
    Map<String, dynamic>? filters,
  }) async => BalanceSheetReport.fromJson(
    await getFinanceMap(
      'finance/reports/balance-sheet',
      queryParameters: filters,
    ),
  );
  Future<CashFlowReport> getCashFlow({Map<String, dynamic>? filters}) async =>
      CashFlowReport.fromJson(
        await getFinanceMap(
          'finance/reports/cash-flow',
          queryParameters: filters,
        ),
      );
  Future<TrialBalanceReport> getTrialBalance({
    Map<String, dynamic>? filters,
  }) async => TrialBalanceReport.fromJson(
    await getFinanceMap(
      'finance/reports/trial-balance',
      queryParameters: filters,
    ),
  );
  Future<GeneralLedgerReport> getGeneralLedgerReport({
    Map<String, dynamic>? filters,
  }) async => GeneralLedgerReport.fromJson(
    await getFinanceMap(
      'finance/reports/general-ledger',
      queryParameters: filters,
    ),
  );
  Future<SupplierAgingReport> getSupplierAging({
    Map<String, dynamic>? filters,
  }) async => SupplierAgingReport.fromJson(
    await getFinanceMap(
      'finance/reports/supplier-aging',
      queryParameters: filters,
    ),
  );
  Future<SupplierStatementReport> getSupplierStatementReport({
    Map<String, dynamic>? filters,
  }) async => SupplierStatementReport.fromJson(
    await getFinanceMap(
      'finance/reports/supplier-statement',
      queryParameters: filters,
    ),
  );

  Map<String, dynamic>? _query(Map<String, dynamic> values) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(values)
      ..removeWhere((String _, dynamic value) => value == null || value == '');
    return result.isEmpty ? null : result;
  }

  Future<Map<String, dynamic>> getFinanceMapFrom(
    Future<dynamic> response,
  ) async {
    final dynamic value = await response;
    return Map<String, dynamic>.from(value as Map);
  }
}
