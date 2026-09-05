import '../../pos/models/json_helpers.dart';

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

/// One financial-account row inside P&L, Balance Sheet, or Trial Balance.
/// Every field is whatever `FinancialReportQueryService::accountRows()`
/// returned; not every report populates every field.
class ReportAccountRow {
  const ReportAccountRow({
    required this.id,
    required this.code,
    required this.name,
    required this.group,
    required this.normalBalance,
    this.parentAccountId,
    this.debit,
    this.credit,
    this.normalisedBalance,
    this.openingDebit,
    this.openingCredit,
    this.periodDebit,
    this.periodCredit,
    this.closingDebit,
    this.closingCredit,
  });
  final int id;
  final String code;
  final String name;
  final String group;
  final String normalBalance;
  final int? parentAccountId;
  final String? debit;
  final String? credit;
  final String? normalisedBalance;
  final String? openingDebit;
  final String? openingCredit;
  final String? periodDebit;
  final String? periodCredit;
  final String? closingDebit;
  final String? closingCredit;

  factory ReportAccountRow.fromJson(Map<String, dynamic> json) => ReportAccountRow(
    id: readInt(json['id']) ?? 0,
    code: readString(json['code']),
    name: readString(json['name']),
    group: readString(json['group']),
    normalBalance: readString(json['normalBalance']),
    parentAccountId: readInt(json['parentAccountId']),
    debit: readString(json['debit']).isEmpty ? null : readString(json['debit']),
    credit: readString(json['credit']).isEmpty ? null : readString(json['credit']),
    normalisedBalance: readString(json['normalisedBalance']).isEmpty ? null : readString(json['normalisedBalance']),
    openingDebit: readString(json['openingDebit']).isEmpty ? null : readString(json['openingDebit']),
    openingCredit: readString(json['openingCredit']).isEmpty ? null : readString(json['openingCredit']),
    periodDebit: readString(json['periodDebit']).isEmpty ? null : readString(json['periodDebit']),
    periodCredit: readString(json['periodCredit']).isEmpty ? null : readString(json['periodCredit']),
    closingDebit: readString(json['closingDebit']).isEmpty ? null : readString(json['closingDebit']),
    closingCredit: readString(json['closingCredit']).isEmpty ? null : readString(json['closingCredit']),
  );
}

class ReportComparisonValue {
  const ReportComparisonValue({required this.current, required this.previous, required this.change, this.percentageChange});
  final String current;
  final String previous;
  final String change;
  final String? percentageChange;
  factory ReportComparisonValue.fromJson(Map<String, dynamic> json) => ReportComparisonValue(
    current: readString(json['current'], fallback: '0.00'),
    previous: readString(json['previous'], fallback: '0.00'),
    change: readString(json['change'], fallback: '0.00'),
    percentageChange: readString(json['percentageChange']).isEmpty ? null : readString(json['percentageChange']),
  );
}

/// `GET finance/reports/profit-loss`. Every section, total, and the COGS
/// integrity signal are Laravel's own ledger aggregation — Flutter never
/// recomputes revenue, COGS, or profit.
class ProfitAndLossReport {
  const ProfitAndLossReport({
    required this.dateFrom,
    required this.dateTo,
    required this.revenue,
    required this.costOfSales,
    required this.operatingExpenses,
    required this.totalRevenue,
    required this.totalCostOfSales,
    required this.totalOperatingExpenses,
    required this.grossProfit,
    required this.netOperatingProfit,
    required this.ledgerBased,
    required this.cogsComplete,
    required this.unpostedInventoryEventsCount,
    this.comparison,
  });
  final String dateFrom;
  final String dateTo;
  final List<ReportAccountRow> revenue;
  final List<ReportAccountRow> costOfSales;
  final List<ReportAccountRow> operatingExpenses;
  final String totalRevenue;
  final String totalCostOfSales;
  final String totalOperatingExpenses;
  final String grossProfit;
  final String netOperatingProfit;
  final bool ledgerBased;
  final bool cogsComplete;
  final int unpostedInventoryEventsCount;
  final Map<String, ReportComparisonValue>? comparison;

  factory ProfitAndLossReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> sections = _map(json['sections']);
    final Map<String, dynamic> totals = _map(json['totals']);
    final Map<String, dynamic> integrity = _map(json['integrity']);
    List<ReportAccountRow> section(String key) =>
        readMapList(sections[key]).map(ReportAccountRow.fromJson).toList(growable: false);
    Map<String, ReportComparisonValue>? comparison;
    if (json['comparison'] is Map) {
      comparison = _map(json['comparison']).map(
        (String key, dynamic value) => MapEntry<String, ReportComparisonValue>(
          key,
          ReportComparisonValue.fromJson(_map(value)),
        ),
      );
    }
    return ProfitAndLossReport(
      dateFrom: readString(json['dateFrom']),
      dateTo: readString(json['dateTo']),
      revenue: section('revenue'),
      costOfSales: section('costOfSales'),
      operatingExpenses: section('operatingExpenses'),
      totalRevenue: readString(totals['revenue'], fallback: '0.00'),
      totalCostOfSales: readString(totals['costOfSales'], fallback: '0.00'),
      totalOperatingExpenses: readString(totals['operatingExpenses'], fallback: '0.00'),
      grossProfit: readString(totals['grossProfit'], fallback: '0.00'),
      netOperatingProfit: readString(totals['netOperatingProfit'], fallback: '0.00'),
      ledgerBased: readBool(integrity['ledgerBased'], fallback: true),
      cogsComplete: readBool(integrity['cogsComplete'], fallback: true),
      unpostedInventoryEventsCount: readInt(integrity['unpostedInventoryEventsCount']) ?? 0,
      comparison: comparison,
    );
  }
}

/// `GET finance/reports/balance-sheet`.
class BalanceSheetReport {
  const BalanceSheetReport({
    required this.asOfDate,
    required this.assets,
    required this.totalAssets,
    required this.liabilities,
    required this.totalLiabilities,
    required this.equity,
    required this.currentPeriodEarnings,
    required this.totalEquity,
    required this.balanced,
    required this.difference,
  });
  final String asOfDate;
  final List<ReportAccountRow> assets;
  final String totalAssets;
  final List<ReportAccountRow> liabilities;
  final String totalLiabilities;
  final List<ReportAccountRow> equity;
  final String currentPeriodEarnings;
  final String totalEquity;
  final bool balanced;
  final String difference;

  factory BalanceSheetReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> assets = _map(json['assets']);
    final Map<String, dynamic> liabilities = _map(json['liabilities']);
    final Map<String, dynamic> equity = _map(json['equity']);
    final Map<String, dynamic> earnings = _map(equity['currentPeriodEarnings']);
    final Map<String, dynamic> integrity = _map(json['integrity']);
    return BalanceSheetReport(
      asOfDate: readString(json['asOfDate']),
      assets: readMapList(assets['accounts']).map(ReportAccountRow.fromJson).toList(growable: false),
      totalAssets: readString(assets['total'], fallback: '0.00'),
      liabilities: readMapList(liabilities['accounts']).map(ReportAccountRow.fromJson).toList(growable: false),
      totalLiabilities: readString(liabilities['total'], fallback: '0.00'),
      equity: readMapList(equity['accounts']).map(ReportAccountRow.fromJson).toList(growable: false),
      currentPeriodEarnings: readString(earnings['amount'], fallback: '0.00'),
      totalEquity: readString(equity['total'], fallback: '0.00'),
      balanced: readBool(integrity['balanced'], fallback: true),
      difference: readString(integrity['difference'], fallback: '0.00'),
    );
  }
}

class CashFlowItem {
  const CashFlowItem({required this.journalId, required this.reference, required this.date, required this.sourceType, required this.amount});
  final int journalId;
  final String reference;
  final String date;
  final String sourceType;
  final String amount;
  factory CashFlowItem.fromJson(Map<String, dynamic> json) => CashFlowItem(
    journalId: readInt(json['journalId']) ?? 0,
    reference: readString(json['reference']),
    date: readString(json['date']),
    sourceType: readString(json['sourceType']),
    amount: readString(json['amount'], fallback: '0.00'),
  );
}

/// `GET finance/reports/cash-flow`.
class CashFlowReport {
  const CashFlowReport({
    required this.dateFrom,
    required this.dateTo,
    required this.operating,
    required this.investing,
    required this.financing,
    required this.internalTransfer,
    required this.unclassified,
    required this.openingCashBanks,
    required this.closingCashBanks,
    required this.netCashFlow,
    required this.reconciled,
    required this.difference,
    required this.unclassifiedAmount,
  });
  final String dateFrom;
  final String dateTo;
  final List<CashFlowItem> operating;
  final List<CashFlowItem> investing;
  final List<CashFlowItem> financing;
  final List<CashFlowItem> internalTransfer;
  final List<CashFlowItem> unclassified;
  final String openingCashBanks;
  final String closingCashBanks;
  final String netCashFlow;
  final bool reconciled;
  final String difference;
  final String unclassifiedAmount;

  factory CashFlowReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> sections = _map(json['sections']);
    final Map<String, dynamic> integrity = _map(json['integrity']);
    List<CashFlowItem> section(String key) =>
        readMapList(sections[key]).map(CashFlowItem.fromJson).toList(growable: false);
    return CashFlowReport(
      dateFrom: readString(json['dateFrom']),
      dateTo: readString(json['dateTo']),
      operating: section('operating'),
      investing: section('investing'),
      financing: section('financing'),
      internalTransfer: section('internal_transfer'),
      unclassified: section('unclassified'),
      openingCashBanks: readString(json['openingCashBanks'], fallback: '0.00'),
      closingCashBanks: readString(json['closingCashBanks'], fallback: '0.00'),
      netCashFlow: readString(json['netCashFlow'], fallback: '0.00'),
      reconciled: readBool(integrity['reconciled'], fallback: true),
      difference: readString(integrity['difference'], fallback: '0.00'),
      unclassifiedAmount: readString(integrity['unclassified'], fallback: '0.00'),
    );
  }
}

/// `GET finance/reports/trial-balance`.
class TrialBalanceReport {
  const TrialBalanceReport({
    required this.dateFrom,
    required this.dateTo,
    required this.accounts,
    required this.totalDebit,
    required this.totalCredit,
    required this.difference,
    required this.balanced,
  });
  final String dateFrom;
  final String dateTo;
  final List<ReportAccountRow> accounts;
  final String totalDebit;
  final String totalCredit;
  final String difference;
  final bool balanced;
  factory TrialBalanceReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> totals = _map(json['totals']);
    return TrialBalanceReport(
      dateFrom: readString(json['dateFrom']),
      dateTo: readString(json['dateTo']),
      accounts: readMapList(json['accounts']).map(ReportAccountRow.fromJson).toList(growable: false),
      totalDebit: readString(totals['debit'], fallback: '0.00'),
      totalCredit: readString(totals['credit'], fallback: '0.00'),
      difference: readString(totals['difference'], fallback: '0.00'),
      balanced: readBool(totals['balanced'], fallback: true),
    );
  }
}

class GeneralLedgerLine {
  const GeneralLedgerLine({
    required this.id,
    required this.accountingDate,
    required this.journalId,
    required this.journalReference,
    required this.sourceType,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.sourceId,
  });
  final int id;
  final String accountingDate;
  final int journalId;
  final String journalReference;
  final String? sourceType;
  final int? sourceId;
  final String description;
  final String debit;
  final String credit;
  final String runningBalance;
  factory GeneralLedgerLine.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> journal = _map(json['journal']);
    final Map<String, dynamic> source = _map(json['source']);
    return GeneralLedgerLine(
      id: readInt(json['id']) ?? 0,
      accountingDate: readString(json['accountingDate']),
      journalId: readInt(journal['id']) ?? 0,
      journalReference: readString(journal['reference']),
      sourceType: readString(source['type']).isEmpty ? null : readString(source['type']),
      sourceId: readInt(source['id']),
      description: readString(json['description']),
      debit: readString(json['debit'], fallback: '0.00'),
      credit: readString(json['credit'], fallback: '0.00'),
      runningBalance: readString(json['runningBalance'], fallback: '0.00'),
    );
  }
}

/// `GET finance/reports/general-ledger`. Opening/closing/running balances are
/// all backend-computed — Flutter only renders them.
class GeneralLedgerReport {
  const GeneralLedgerReport({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.normalBalance,
    required this.dateFrom,
    required this.dateTo,
    required this.openingBalance,
    required this.lines,
    required this.closingBalance,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });
  final int accountId;
  final String accountCode;
  final String accountName;
  final String normalBalance;
  final String dateFrom;
  final String dateTo;
  final String openingBalance;
  final List<GeneralLedgerLine> lines;
  final String closingBalance;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  factory GeneralLedgerReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> account = _map(json['account']);
    final Map<String, dynamic> meta = _map(json['meta']);
    return GeneralLedgerReport(
      accountId: readInt(account['id']) ?? 0,
      accountCode: readString(account['code']),
      accountName: readString(account['name']),
      normalBalance: readString(account['normalBalance']),
      dateFrom: readString(json['dateFrom']),
      dateTo: readString(json['dateTo']),
      openingBalance: readString(json['openingBalance'], fallback: '0.00'),
      lines: readMapList(json['lines']).map(GeneralLedgerLine.fromJson).toList(growable: false),
      closingBalance: readString(json['closingBalance'], fallback: '0.00'),
      currentPage: readInt(meta['currentPage']) ?? 1,
      perPage: readInt(meta['perPage']) ?? 50,
      total: readInt(meta['total']) ?? 0,
      lastPage: readInt(meta['lastPage']) ?? 1,
    );
  }
}

class SupplierAgingRow {
  const SupplierAgingRow({
    required this.supplierId,
    required this.supplierName,
    required this.current,
    required this.days1To30,
    required this.days31To60,
    required this.days61To90,
    required this.days90Plus,
    required this.totalOutstanding,
  });
  final int supplierId;
  final String supplierName;
  final String current;
  final String days1To30;
  final String days31To60;
  final String days61To90;
  final String days90Plus;
  final String totalOutstanding;
  factory SupplierAgingRow.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> supplier = _map(json['supplier']);
    return SupplierAgingRow(
      supplierId: readInt(supplier['id']) ?? 0,
      supplierName: readString(supplier['name']),
      current: readString(json['current'], fallback: '0.00'),
      days1To30: readString(json['days1To30'], fallback: '0.00'),
      days31To60: readString(json['days31To60'], fallback: '0.00'),
      days61To90: readString(json['days61To90'], fallback: '0.00'),
      days90Plus: readString(json['days90Plus'], fallback: '0.00'),
      totalOutstanding: readString(json['totalOutstanding'], fallback: '0.00'),
    );
  }
}

/// `GET finance/reports/supplier-aging`.
class SupplierAgingReport {
  const SupplierAgingReport({
    required this.asOfDate,
    required this.suppliers,
    required this.totalCurrent,
    required this.totalDays1To30,
    required this.totalDays31To60,
    required this.totalDays61To90,
    required this.totalDays90Plus,
    required this.totalOutstanding,
  });
  final String asOfDate;
  final List<SupplierAgingRow> suppliers;
  final String totalCurrent;
  final String totalDays1To30;
  final String totalDays31To60;
  final String totalDays61To90;
  final String totalDays90Plus;
  final String totalOutstanding;
  factory SupplierAgingReport.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> totals = _map(json['totals']);
    return SupplierAgingReport(
      asOfDate: readString(json['asOfDate']),
      suppliers: readMapList(json['suppliers']).map(SupplierAgingRow.fromJson).toList(growable: false),
      totalCurrent: readString(totals['current'], fallback: '0.00'),
      totalDays1To30: readString(totals['days1To30'], fallback: '0.00'),
      totalDays31To60: readString(totals['days31To60'], fallback: '0.00'),
      totalDays61To90: readString(totals['days61To90'], fallback: '0.00'),
      totalDays90Plus: readString(totals['days90Plus'], fallback: '0.00'),
      totalOutstanding: readString(totals['totalOutstanding'], fallback: '0.00'),
    );
  }
}

class SupplierStatementReportLine {
  const SupplierStatementReportLine({
    required this.date,
    required this.type,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningOutstanding,
    required this.resourceKind,
    required this.resourceId,
  });
  final String date;
  final String type;
  final String reference;
  final String description;
  final String debit;
  final String credit;
  final String runningOutstanding;
  final String? resourceKind;
  final int? resourceId;
  factory SupplierStatementReportLine.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> drillDown = _map(json['drillDown']);
    return SupplierStatementReportLine(
      date: readString(json['date']),
      type: readString(json['type']),
      reference: readString(json['reference']),
      description: readString(json['description']),
      debit: readString(json['debit'], fallback: '0.00'),
      credit: readString(json['credit'], fallback: '0.00'),
      runningOutstanding: readString(json['runningOutstanding'], fallback: '0.00'),
      resourceKind: readString(drillDown['resourceKind']).isEmpty ? null : readString(drillDown['resourceKind']),
      resourceId: readInt(drillDown['id']),
    );
  }
}

/// `GET finance/reports/supplier-statement`.
class SupplierStatementReport {
  const SupplierStatementReport({
    required this.supplierId,
    required this.dateFrom,
    required this.dateTo,
    required this.openingBalance,
    required this.lines,
    required this.closingBalance,
  });
  final int supplierId;
  final String dateFrom;
  final String dateTo;
  final String openingBalance;
  final List<SupplierStatementReportLine> lines;
  final String closingBalance;
  factory SupplierStatementReport.fromJson(Map<String, dynamic> json) => SupplierStatementReport(
    supplierId: readInt(json['supplierId']) ?? 0,
    dateFrom: readString(json['dateFrom']),
    dateTo: readString(json['dateTo']),
    openingBalance: readString(json['openingBalance'], fallback: '0.00'),
    lines: readMapList(json['lines']).map(SupplierStatementReportLine.fromJson).toList(growable: false),
    closingBalance: readString(json['closingBalance'], fallback: '0.00'),
  );
}
