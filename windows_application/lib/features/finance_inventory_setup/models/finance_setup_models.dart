import '../../pos/models/json_helpers.dart';

class SetupStatus {
  const SetupStatus({
    required this.systemAccountsReady,
    required this.centralWarehouseReady,
    required this.branchWarehouseCoverageReady,
    required this.financialSetupReady,
    required this.missingBranchWarehouses,
    this.accountCount = 0,
    this.activeAccountCount = 0,
    this.inactiveAccountCount = 0,
    this.systemAccountCount = 0,
    this.journalCount = 0,
    this.draftJournalCount = 0,
    this.postedJournalCount = 0,
    this.reversedOriginalCount = 0,
    this.journalEngineReady = false,
    this.journalReversalReady = false,
    this.postingInfrastructureReady = false,
    this.defaultAccounts = const <DefaultFinancialAccount>[],
    this.cashBankAccountCount = 0,
    this.cashBankBalance = '0.00',
    this.activePaymentMethodCount = 0,
    this.expensesToday = '0.00',
    this.expensesThisMonth = '0.00',
    this.pendingExpenseCount = 0,
    this.unpaidExpenseCount = 0,
    this.totalPayables = '0.00',
    this.overduePayables = '0.00',
    this.openSupplierInvoiceCount = 0,
    this.activeSupplierCount = 0,
  });

  final bool systemAccountsReady;
  final bool centralWarehouseReady;
  final bool branchWarehouseCoverageReady;
  final bool financialSetupReady;
  final List<String> missingBranchWarehouses;
  final int accountCount;
  final int activeAccountCount;
  final int inactiveAccountCount;
  final int systemAccountCount;
  final int journalCount;
  final int draftJournalCount;
  final int postedJournalCount;
  final int reversedOriginalCount;
  final bool journalEngineReady;
  final bool journalReversalReady;
  final bool postingInfrastructureReady;
  final List<DefaultFinancialAccount> defaultAccounts;
  final int cashBankAccountCount;
  final String cashBankBalance;
  final int activePaymentMethodCount;
  final String expensesToday;
  final String expensesThisMonth;
  final int pendingExpenseCount;
  final int unpaidExpenseCount;
  final String totalPayables;
  final String overduePayables;
  final int openSupplierInvoiceCount;
  final int activeSupplierCount;

  factory SetupStatus.fromJson(Map<String, dynamic> json) => SetupStatus(
    systemAccountsReady: readBool(json['systemAccountsReady']),
    centralWarehouseReady: readBool(json['centralWarehouseReady']),
    branchWarehouseCoverageReady: readBool(
      json['branchWarehouseCoverageReady'],
    ),
    financialSetupReady: readBool(json['financialSetupReady']),
    accountCount: readInt(json['accountCount']) ?? 0,
    activeAccountCount: readInt(json['activeAccountCount']) ?? 0,
    inactiveAccountCount: readInt(json['inactiveAccountCount']) ?? 0,
    systemAccountCount: readInt(json['systemAccountCount']) ?? 0,
    journalCount: readInt(json['journalCount']) ?? 0,
    draftJournalCount: readInt(json['draftJournalCount']) ?? 0,
    postedJournalCount: readInt(json['postedJournalCount']) ?? 0,
    reversedOriginalCount: readInt(json['reversedOriginalCount']) ?? 0,
    journalEngineReady: readBool(json['journalEngineReady']),
    journalReversalReady: readBool(json['journalReversalReady']),
    postingInfrastructureReady: readBool(json['postingInfrastructureReady']),
    cashBankAccountCount: readInt(json['cashBankAccountCount']) ?? 0,
    cashBankBalance: readString(json['cashBankBalance'], fallback: '0.00'),
    activePaymentMethodCount: readInt(json['activePaymentMethodCount']) ?? 0,
    expensesToday: readString(json['expensesToday'], fallback: '0.00'),
    expensesThisMonth: readString(json['expensesThisMonth'], fallback: '0.00'),
    pendingExpenseCount: readInt(json['pendingExpenseCount']) ?? 0,
    unpaidExpenseCount: readInt(json['unpaidExpenseCount']) ?? 0,
    totalPayables: readString(json['totalPayables'], fallback: '0.00'),
    overduePayables: readString(json['overduePayables'], fallback: '0.00'),
    openSupplierInvoiceCount: readInt(json['openSupplierInvoiceCount']) ?? 0,
    activeSupplierCount: readInt(json['activeSupplierCount']) ?? 0,
    defaultAccounts: readMapList(
      json['defaultAccounts'],
    ).map(DefaultFinancialAccount.fromJson).toList(growable: false),
    missingBranchWarehouses: readMapList(json['missingBranchWarehouses'])
        .map((Map<String, dynamic> item) => readString(item['name']))
        .toList(growable: false),
  );
}

class DefaultFinancialAccount {
  const DefaultFinancialAccount({
    required this.code,
    required this.nameAr,
    required this.accountGroup,
    required this.isActive,
  });
  final String code;
  final String nameAr;
  final String accountGroup;
  final bool isActive;
  factory DefaultFinancialAccount.fromJson(Map<String, dynamic> json) =>
      DefaultFinancialAccount(
        code: readString(json['code']),
        nameAr: readString(json['nameAr']),
        accountGroup: readString(json['accountGroup']),
        isActive: readBool(json['isActive']),
      );
}

class FinancialLocation {
  const FinancialLocation({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.type,
    required this.financialAccountId,
    required this.financialAccountCode,
    required this.balance,
    required this.todayIncoming,
    required this.todayOutgoing,
    required this.isActive,
    this.branchId,
    this.branchName,
    this.bankName,
    this.financialAccountNameAr,
    this.maskedReference,
  });
  final int id;
  final String code;
  final String name;
  final String kind;
  final String type;
  final int financialAccountId;
  final String financialAccountCode;
  final String balance;
  final String todayIncoming;
  final String todayOutgoing;
  final bool isActive;
  final int? branchId;
  final String? branchName;
  final String? bankName;
  final String? financialAccountNameAr;
  final String? maskedReference;
  factory FinancialLocation.fromJson(Map<String, dynamic> json) =>
      FinancialLocation(
        id: readInt(json['id']) ?? 0,
        code: readString(json['code']),
        name: readString(json['name']),
        kind: readString(json['kind']),
        type: readString(json['type']),
        financialAccountId: readInt(json['financialAccountId']) ?? 0,
        financialAccountCode: readString(json['financialAccountCode']),
        balance: readString(json['balance'], fallback: '0.00'),
        todayIncoming: readString(json['todayIncoming'], fallback: '0.00'),
        todayOutgoing: readString(json['todayOutgoing'], fallback: '0.00'),
        isActive: readBool(json['isActive']),
        branchId: readInt(json['branchId']),
        branchName: readString(json['branchName']).isEmpty
            ? null
            : readString(json['branchName']),
        bankName: readString(json['bankName']).isEmpty
            ? null
            : readString(json['bankName']),
        financialAccountNameAr: readString(json['financialAccountNameAr']).isEmpty
            ? null
            : readString(json['financialAccountNameAr']),
        maskedReference: readString(json['maskedReference']).isEmpty
            ? null
            : readString(json['maskedReference']),
      );
}

/// Detail contract returned by both cash and bank transaction endpoints.
/// The server owns balances and transaction ordering; Flutter only parses it.
class FinancialLocationTransactions {
  const FinancialLocationTransactions({
    required this.location,
    required this.transactions,
  });

  final FinancialLocation location;
  final List<Map<String, dynamic>> transactions;

  factory FinancialLocationTransactions.fromJson(Map<String, dynamic> json) =>
      FinancialLocationTransactions(
        location: FinancialLocation.fromJson(
          json['location'] is Map
              ? Map<String, dynamic>.from(json['location'] as Map)
              : const <String, dynamic>{},
        ),
        transactions: readMapList(json['transactions']),
      );
}

class PaymentMethodSetting {
  const PaymentMethodSetting({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.financialAccountId,
    required this.financialAccountCode,
    required this.isActive,
    this.financialLocationId,
    this.financialLocationName,
  });
  final int id;
  final String code;
  final String name;
  final String type;
  final int financialAccountId;
  final String financialAccountCode;
  final bool isActive;
  final int? financialLocationId;
  final String? financialLocationName;
  factory PaymentMethodSetting.fromJson(Map<String, dynamic> json) =>
      PaymentMethodSetting(
        id: readInt(json['id']) ?? 0,
        code: readString(json['code']),
        name: readString(json['name']),
        type: readString(json['type']),
        financialAccountId: readInt(json['financialAccountId']) ?? 0,
        financialAccountCode: readString(json['financialAccountCode']),
        isActive: readBool(json['isActive']),
        financialLocationId: readInt(json['financialLocationId']),
        financialLocationName: readString(json['financialLocationName']).isEmpty
            ? null
            : readString(json['financialLocationName']),
      );
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.financialAccountId,
    required this.financialAccountCode,
    required this.isActive,
    this.financialAccountName,
    this.sortOrder = 0,
  });
  final int id;
  final String code;
  final String name;
  final int financialAccountId;
  final String financialAccountCode;
  final bool isActive;
  final String? financialAccountName;
  final int sortOrder;
  factory ExpenseCategory.fromJson(Map<String, dynamic> json) =>
      ExpenseCategory(
        id: readInt(json['id']) ?? 0,
        code: readString(json['code']),
        name: readString(json['name']),
        financialAccountId: readInt(json['financialAccountId']) ?? 0,
        financialAccountCode: readString(json['financialAccountCode']),
        isActive: readBool(json['isActive']),
        financialAccountName: readString(json['financialAccountName']).isEmpty
            ? null
            : readString(json['financialAccountName']),
        sortOrder: readInt(json['sortOrder']) ?? 0,
      );
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.expenseNumber,
    required this.expenseCategoryId,
    required this.expenseCategoryName,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.expenseDate,
    required this.description,
    required this.status,
    required this.paymentStatus,
    this.expenseCategoryCode,
    this.branchId,
    this.branchName,
    this.notes,
    this.paymentMethodId,
    this.paymentMethodName,
    this.financialLocationId,
    this.financialLocationName,
    this.paidAt,
    this.journalEntryId,
    this.reversalJournalEntryId,
    this.createdByName,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.allowedActions = const <String>[],
  });
  final int id;
  final String expenseNumber;
  final int expenseCategoryId;
  final String expenseCategoryName;
  final String amount;
  final String taxAmount;
  final String totalAmount;
  final String expenseDate;
  final String description;
  final String status;
  final String paymentStatus;
  final String? expenseCategoryCode;
  final int? branchId;
  final String? branchName;
  final String? notes;
  final int? paymentMethodId;
  final String? paymentMethodName;
  final int? financialLocationId;
  final String? financialLocationName;
  final String? paidAt;
  final int? journalEntryId;
  final int? reversalJournalEntryId;
  final String? createdByName;
  final String? approvedAt;
  final String? rejectedAt;
  final String? rejectionReason;
  final String? createdAt;
  final String? updatedAt;
  /// Backend-computed, permission- and approval-policy-aware transitions
  /// (e.g. never includes `approve` for the expense's own creator). The
  /// canonical source for which lifecycle actions to render — never
  /// re-derived from `status` alone.
  final List<String> allowedActions;
  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
    id: readInt(json['id']) ?? 0,
    expenseNumber: readString(json['expenseNumber']),
    expenseCategoryId: readInt(json['expenseCategoryId']) ?? 0,
    expenseCategoryName: readString(json['expenseCategoryName']),
    expenseCategoryCode: readString(json['expenseCategoryCode']).isEmpty
        ? null
        : readString(json['expenseCategoryCode']),
    amount: readString(json['amount']),
    taxAmount: readString(json['taxAmount']),
    totalAmount: readString(json['totalAmount']),
    expenseDate: readString(json['expenseDate']),
    description: readString(json['description']),
    status: readString(json['status']),
    paymentStatus: readString(json['paymentStatus']),
    branchId: readInt(json['branchId']),
    branchName: readString(json['branchName']).isEmpty
        ? null
        : readString(json['branchName']),
    notes: readString(json['notes']).isEmpty ? null : readString(json['notes']),
    paymentMethodId: readInt(json['paymentMethodId']),
    paymentMethodName: readString(json['paymentMethodName']).isEmpty
        ? null
        : readString(json['paymentMethodName']),
    financialLocationId: readInt(json['financialLocationId']),
    financialLocationName: readString(json['financialLocationName']).isEmpty
        ? null
        : readString(json['financialLocationName']),
    paidAt: readString(json['paidAt']).isEmpty
        ? null
        : readString(json['paidAt']),
    journalEntryId: readInt(json['journalEntryId']),
    reversalJournalEntryId: readInt(json['reversalJournalEntryId']),
    createdByName: readString(json['createdByName']).isEmpty
        ? null
        : readString(json['createdByName']),
    approvedAt: readString(json['approvedAt']).isEmpty
        ? null
        : readString(json['approvedAt']),
    rejectedAt: readString(json['rejectedAt']).isEmpty
        ? null
        : readString(json['rejectedAt']),
    rejectionReason: readString(json['rejectionReason']).isEmpty
        ? null
        : readString(json['rejectionReason']),
    createdAt: readString(json['createdAt']).isEmpty
        ? null
        : readString(json['createdAt']),
    updatedAt: readString(json['updatedAt']).isEmpty
        ? null
        : readString(json['updatedAt']),
    allowedActions: readStringList(json['allowedActions']),
  );
}

class WarehouseLocation {
  const WarehouseLocation({
    required this.id,
    required this.name,
    required this.displayName,
    required this.code,
    required this.type,
    required this.typeLabel,
    required this.isActive,
    required this.isLegacy,
    this.branchId,
    this.branchName,
    this.notes,
  });
  final int id;
  final int? branchId;
  final String? branchName;
  final String name;
  final String displayName;
  final String code;
  final String type;
  final String typeLabel;
  final bool isActive;
  final bool isLegacy;
  final String? notes;

  factory WarehouseLocation.fromJson(Map<String, dynamic> json) =>
      WarehouseLocation(
        id: readInt(json['id']) ?? 0,
        branchId: readInt(json['branchId']),
        branchName: readString(json['branchName']).isEmpty
            ? null
            : readString(json['branchName']),
        name: readString(json['name']),
        displayName: readString(
          json['displayName'],
          fallback: readString(json['name']),
        ),
        code: readString(json['code']),
        type: readString(json['type']),
        typeLabel: readString(json['typeLabel'], fallback: 'Warehouse'),
        isActive: readBool(json['isActive']),
        isLegacy:
            readBool(json['isLegacy']) ||
            readString(json['code']).startsWith('LEGACY-'),
        notes: readString(json['notes']).isEmpty
            ? null
            : readString(json['notes']),
      );
}

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.accountGroup,
    required this.normalBalance,
    required this.isActive,
    required this.isSystemProtected,
    this.parentAccountId,
    this.parentCode,
    this.parentNameAr,
  });
  final int id;
  final int? parentAccountId;
  final String? parentCode;
  final String? parentNameAr;
  final String code;
  final String nameAr;
  final String nameEn;
  final String accountGroup;
  final String normalBalance;
  final bool isActive;
  final bool isSystemProtected;

  factory FinancialAccount.fromJson(Map<String, dynamic> json) =>
      FinancialAccount(
        id: readInt(json['id']) ?? 0,
        parentAccountId: readInt(json['parentAccountId']),
        parentCode: readString(json['parentCode']).isEmpty
            ? null
            : readString(json['parentCode']),
        parentNameAr: readString(json['parentNameAr']).isEmpty
            ? null
            : readString(json['parentNameAr']),
        code: readString(json['code']),
        nameAr: readString(json['nameAr']),
        nameEn: readString(json['nameEn']),
        accountGroup: readString(json['accountGroup']),
        normalBalance: readString(json['normalBalance']),
        isActive: readBool(json['isActive']),
        isSystemProtected: readBool(json['isSystemProtected']),
      );
}

class JournalLine {
  const JournalLine({
    required this.accountId,
    required this.accountCode,
    required this.accountNameAr,
    required this.debit,
    required this.credit,
    this.description,
  });
  final int accountId;
  final String accountCode;
  final String accountNameAr;
  final String debit;
  final String credit;
  final String? description;

  factory JournalLine.fromJson(Map<String, dynamic> json) => JournalLine(
    accountId: readInt(json['accountId']) ?? 0,
    accountCode: readString(json['accountCode']),
    accountNameAr: readString(json['accountNameAr']),
    debit: readString(json['debit'], fallback: '0.00'),
    credit: readString(json['credit'], fallback: '0.00'),
    description: readString(json['description']).isEmpty
        ? null
        : readString(json['description']),
  );
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.entryNumber,
    required this.entryDate,
    required this.sourceType,
    required this.status,
    required this.debitTotal,
    required this.creditTotal,
    required this.lines,
    this.description,
    this.branchName,
    this.branchId,
    this.sourceId,
    this.sourceEvent,
    this.reversalOfId,
    this.isReversed = false,
    this.createdAt,
    this.updatedAt,
    this.postedAt,
    this.createdBy,
    this.postedBy,
  });
  final int id;
  final String entryNumber;
  final String entryDate;
  final String sourceType;
  final String status;
  final String debitTotal;
  final String creditTotal;
  final String? description;
  final String? branchName;
  final int? branchId;
  final int? sourceId;
  final String? sourceEvent;
  final int? reversalOfId;
  final bool isReversed;
  final String? createdAt;
  final String? updatedAt;
  final String? postedAt;
  final int? createdBy;
  final int? postedBy;
  final List<JournalLine> lines;

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: readInt(json['id']) ?? 0,
    entryNumber: readString(json['entryNumber']),
    entryDate: readString(json['entryDate']),
    sourceType: readString(json['sourceType']),
    status: readString(json['status']),
    debitTotal: readString(json['debitTotal'], fallback: '0.00'),
    creditTotal: readString(json['creditTotal'], fallback: '0.00'),
    description: readString(json['description']).isEmpty
        ? null
        : readString(json['description']),
    branchName: readString(json['branchName']).isEmpty
        ? null
        : readString(json['branchName']),
    branchId: readInt(json['branchId']),
    sourceId: readInt(json['sourceId']),
    sourceEvent: readString(json['sourceEvent']).isEmpty
        ? null
        : readString(json['sourceEvent']),
    reversalOfId: readInt(json['reversalOfId']),
    isReversed: readBool(json['isReversed']),
    createdAt: readString(json['createdAt']).isEmpty
        ? null
        : readString(json['createdAt']),
    updatedAt: readString(json['updatedAt']).isEmpty
        ? null
        : readString(json['updatedAt']),
    postedAt: readString(json['postedAt']).isEmpty
        ? null
        : readString(json['postedAt']),
    createdBy: readInt(json['createdBy']),
    postedBy: readInt(json['postedBy']),
    lines: readMapList(
      json['lines'],
    ).map(JournalLine.fromJson).toList(growable: false),
  );
}

class Supplier {
  const Supplier({
    required this.id,
    required this.supplierNumber,
    required this.name,
    required this.isActive,
    this.phone,
    this.email,
    this.address,
    this.contactPerson,
    this.taxNumber,
    this.paymentTermsDays = 0,
    this.notes,
    this.outstandingBalance = '0.00',
    this.overdueBalance = '0.00',
    this.openInvoiceCount = 0,
    this.lastInvoiceDate,
    this.totalInvoiced,
    this.totalPaid,
    this.allowedActions = const <String>[],
  });
  final int id;
  final String supplierNumber;
  final String name;
  final bool isActive;
  final String? phone;
  final String? email;
  final String? address;
  final String? contactPerson;
  final String? taxNumber;
  final int paymentTermsDays;
  final String? notes;
  final String outstandingBalance;
  final String overdueBalance;
  final int openInvoiceCount;
  final String? lastInvoiceDate;
  final String? totalInvoiced;
  final String? totalPaid;
  final List<String> allowedActions;
  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: readInt(json['id']) ?? 0,
    supplierNumber: readString(json['supplierNumber']),
    name: readString(json['name']),
    isActive: readBool(json['isActive'], fallback: true),
    phone: readString(json['phone']).isEmpty ? null : readString(json['phone']),
    email: readString(json['email']).isEmpty ? null : readString(json['email']),
    address: readString(json['address']).isEmpty
        ? null
        : readString(json['address']),
    contactPerson: readString(json['contactPerson']).isEmpty
        ? null
        : readString(json['contactPerson']),
    taxNumber: readString(json['taxNumber']).isEmpty
        ? null
        : readString(json['taxNumber']),
    paymentTermsDays: readInt(json['paymentTermsDays']) ?? 0,
    notes: readString(json['notes']).isEmpty ? null : readString(json['notes']),
    outstandingBalance: readString(
      json['outstandingBalance'],
      fallback: '0.00',
    ),
    overdueBalance: readString(json['overdueBalance'], fallback: '0.00'),
    openInvoiceCount: readInt(json['openInvoiceCount']) ?? 0,
    lastInvoiceDate: readString(json['lastInvoiceDate']).isEmpty
        ? null
        : readString(json['lastInvoiceDate']),
    totalInvoiced: json['totalInvoiced'] == null
        ? null
        : readString(json['totalInvoiced']),
    totalPaid: json['totalPaid'] == null ? null : readString(json['totalPaid']),
    allowedActions: readStringList(json['allowedActions']),
  );
}

class SupplierInvoice {
  const SupplierInvoice({
    required this.id,
    required this.internalReference,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceDate,
    required this.dueDate,
    required this.invoiceType,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.remainingAmount,
    required this.status,
    required this.isOverdue,
    this.branchId,
    this.branchName,
    this.expenseCategoryId,
    this.expenseCategoryName,
    this.debitAccountId,
    this.debitAccountCode,
    this.debitAccountName,
    this.description,
    this.notes,
    this.journalEntryId,
    this.reversalJournalEntryId,
    this.postedAt,
    this.allowedActions = const <String>[],
  });
  final int id;
  final String internalReference;
  final String invoiceNumber;
  final int supplierId;
  final String supplierName;
  final int? branchId;
  final String? branchName;
  final String invoiceDate;
  final String dueDate;
  final String invoiceType;
  final int? expenseCategoryId;
  final String? expenseCategoryName;
  final int? debitAccountId;
  final String? debitAccountCode;
  final String? debitAccountName;
  final String subtotal;
  final String taxAmount;
  final String totalAmount;
  final String remainingAmount;
  final String status;
  final bool isOverdue;
  final String? description;
  final String? notes;
  final int? journalEntryId;
  final int? reversalJournalEntryId;
  final String? postedAt;
  final List<String> allowedActions;
  factory SupplierInvoice.fromJson(Map<String, dynamic> json) =>
      SupplierInvoice(
        id: readInt(json['id']) ?? 0,
        internalReference: readString(json['internalReference']),
        invoiceNumber: readString(json['invoiceNumber']),
        supplierId: readInt(json['supplierId']) ?? 0,
        supplierName: readString(json['supplierName']),
        branchId: readInt(json['branchId']),
        branchName: readString(json['branchName']).isEmpty
            ? null
            : readString(json['branchName']),
        invoiceDate: readString(json['invoiceDate']),
        dueDate: readString(json['dueDate']),
        invoiceType: readString(json['invoiceType']),
        expenseCategoryId: readInt(json['expenseCategoryId']),
        expenseCategoryName: readString(json['expenseCategoryName']).isEmpty
            ? null
            : readString(json['expenseCategoryName']),
        debitAccountId: readInt(json['debitAccountId']),
        debitAccountCode: readString(json['debitAccountCode']).isEmpty
            ? null
            : readString(json['debitAccountCode']),
        debitAccountName: readString(json['debitAccountName']).isEmpty
            ? null
            : readString(json['debitAccountName']),
        subtotal: readString(json['subtotal']),
        taxAmount: readString(json['taxAmount']),
        totalAmount: readString(json['totalAmount']),
        remainingAmount: readString(json['remainingAmount']),
        status: readString(json['status']),
        isOverdue: readBool(json['isOverdue']),
        description: readString(json['description']).isEmpty
            ? null
            : readString(json['description']),
        notes: readString(json['notes']).isEmpty
            ? null
            : readString(json['notes']),
        journalEntryId: readInt(json['journalEntryId']),
        reversalJournalEntryId: readInt(json['reversalJournalEntryId']),
        postedAt: readString(json['postedAt']).isEmpty
            ? null
            : readString(json['postedAt']),
        allowedActions: readStringList(json['allowedActions']),
      );
}

class SupplierPayment {
  const SupplierPayment({
    required this.id,
    required this.paymentNumber,
    required this.supplierId,
    required this.supplierName,
    required this.paymentDate,
    required this.amount,
    required this.paymentMethodName,
    required this.financialLocationName,
    required this.status,
    this.externalReference,
    this.notes,
    this.journalEntryId,
    this.reversalJournalEntryId,
    this.allocations = const <PaymentAllocationLine>[],
    this.allowedActions = const <String>[],
  });
  final int id;
  final String paymentNumber;
  final int supplierId;
  final String supplierName;
  final String paymentDate;
  final String amount;
  final String paymentMethodName;
  final String financialLocationName;
  final String status;
  final String? externalReference;
  final String? notes;
  final int? journalEntryId;
  final int? reversalJournalEntryId;
  final List<PaymentAllocationLine> allocations;
  final List<String> allowedActions;
  factory SupplierPayment.fromJson(Map<String, dynamic> json) =>
      SupplierPayment(
        id: readInt(json['id']) ?? 0,
        paymentNumber: readString(json['paymentNumber']),
        supplierId: readInt(json['supplierId']) ?? 0,
        supplierName: readString(json['supplierName']),
        paymentDate: readString(json['paymentDate']),
        amount: readString(json['amount']),
        paymentMethodName: readString(json['paymentMethodName']),
        financialLocationName: readString(json['financialLocationName']),
        status: readString(json['status']),
        externalReference: readString(json['externalReference']).isEmpty
            ? null
            : readString(json['externalReference']),
        notes: readString(json['notes']).isEmpty
            ? null
            : readString(json['notes']),
        journalEntryId: readInt(json['journalEntryId']),
        reversalJournalEntryId: readInt(json['reversalJournalEntryId']),
        allocations: readMapList(
          json['allocations'],
        ).map(PaymentAllocationLine.fromJson).toList(growable: false),
        allowedActions: readStringList(json['allowedActions']),
      );
}

class PaymentAllocationLine {
  const PaymentAllocationLine({
    required this.invoiceId,
    required this.invoiceReference,
    required this.amount,
  });
  final int invoiceId;
  final String invoiceReference;
  final String amount;
  factory PaymentAllocationLine.fromJson(Map<String, dynamic> json) =>
      PaymentAllocationLine(
        invoiceId: readInt(json['invoiceId']) ?? 0,
        invoiceReference: readString(json['invoiceReference']),
        amount: readString(json['amount']),
      );
}

class SupplierStatementLine {
  const SupplierStatementLine({
    required this.id,
    required this.date,
    required this.type,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });
  final int id;
  final String date;
  final String type;
  final String reference;
  final String debit;
  final String credit;
  final String runningBalance;
  factory SupplierStatementLine.fromJson(Map<String, dynamic> json) =>
      SupplierStatementLine(
        id: readInt(json['id']) ?? 0,
        date: readString(json['date']),
        type: readString(json['type']),
        reference: readString(json['reference']),
        debit: readString(json['debit']),
        credit: readString(json['credit']),
        runningBalance: readString(json['runningBalance']),
      );
}

class ReconciliationAccount {
  const ReconciliationAccount({
    required this.financialAccountId,
    required this.financialAccountCode,
    required this.financialAccountName,
    this.financialLocationId,
    this.name,
    this.locationType,
    this.branchId,
    this.branchName,
  });
  final int financialAccountId;
  final String financialAccountCode;
  final String financialAccountName;
  final int? financialLocationId;
  final String? name;
  final String? locationType;
  final int? branchId;
  final String? branchName;
  factory ReconciliationAccount.fromJson(Map<String, dynamic> json) =>
      ReconciliationAccount(
        financialAccountId: readInt(json['financialAccountId']) ?? 0,
        financialAccountCode: readString(json['financialAccountCode']),
        financialAccountName: readString(json['financialAccountName']),
        financialLocationId: readInt(json['financialLocationId']),
        name: readString(json['name']).isEmpty ? null : readString(json['name']),
        locationType: readString(json['type']).isEmpty ? null : readString(json['type']),
        branchId: readInt(json['branchId']),
        branchName: readString(json['branchName']).isEmpty
            ? null
            : readString(json['branchName']),
      );
}

class ReconciliationBalances {
  const ReconciliationBalances({
    this.bookOpening,
    this.bookClosing,
    this.externalOpening,
    this.externalClosing,
    this.actualCash,
    this.difference,
    this.differenceDirection,
  });
  final String? bookOpening;
  final String? bookClosing;
  final String? externalOpening;
  final String? externalClosing;
  final String? actualCash;
  final String? difference;
  final String? differenceDirection;
  factory ReconciliationBalances.fromJson(Map<String, dynamic> json) =>
      ReconciliationBalances(
        bookOpening: json['bookOpening'] == null ? null : readString(json['bookOpening']),
        bookClosing: json['bookClosing'] == null ? null : readString(json['bookClosing']),
        externalOpening: json['externalOpening'] == null
            ? null
            : readString(json['externalOpening']),
        externalClosing: json['externalClosing'] == null
            ? null
            : readString(json['externalClosing']),
        actualCash: json['actualCash'] == null ? null : readString(json['actualCash']),
        difference: json['difference'] == null ? null : readString(json['difference']),
        differenceDirection: json['differenceDirection'] == null
            ? null
            : readString(json['differenceDirection']),
      );
}

class ReconciliationSummary {
  const ReconciliationSummary({
    this.systemTransactionsCount = 0,
    this.statementLinesCount = 0,
    this.matchedCount = 0,
    this.unmatchedSystemCount = 0,
    this.unmatchedStatementCount = 0,
    this.matchedAmount = '0.00',
    this.unmatchedSystemAmount = '0.00',
    this.unmatchedStatementAmount = '0.00',
  });
  final int systemTransactionsCount;
  final int statementLinesCount;
  final int matchedCount;
  final int unmatchedSystemCount;
  final int unmatchedStatementCount;
  final String matchedAmount;
  final String unmatchedSystemAmount;
  final String unmatchedStatementAmount;
  factory ReconciliationSummary.fromJson(Map<String, dynamic> json) =>
      ReconciliationSummary(
        systemTransactionsCount: readInt(json['systemTransactionsCount']) ?? 0,
        statementLinesCount: readInt(json['statementLinesCount']) ?? 0,
        matchedCount: readInt(json['matchedCount']) ?? 0,
        unmatchedSystemCount: readInt(json['unmatchedSystemCount']) ?? 0,
        unmatchedStatementCount: readInt(json['unmatchedStatementCount']) ?? 0,
        matchedAmount: readString(json['matchedAmount'], fallback: '0.00'),
        unmatchedSystemAmount: readString(json['unmatchedSystemAmount'], fallback: '0.00'),
        unmatchedStatementAmount: readString(
          json['unmatchedStatementAmount'],
          fallback: '0.00',
        ),
      );

  /// Simple display derivation from backend-truth counts (not an accounting
  /// decision): the share of statement lines that are fully matched.
  /// Backend has no `progressPct` field, and cash sessions have no
  /// statement lines at all — 100% (nothing left to match) in that case.
  double get progressPercent => statementLinesCount == 0
      ? 100
      : (statementLinesCount - unmatchedStatementCount) / statementLinesCount * 100;
}

class ReconciliationSession {
  const ReconciliationSession({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    required this.account,
    required this.periodFrom,
    required this.periodTo,
    required this.balances,
    required this.summary,
    required this.canComplete,
    this.blockingReasons = const <String>[],
    this.createdBy,
    this.completedBy,
    this.createdAt,
    this.completedAt,
    this.allowedActions = const <String>[],
    this.statementLines = const <ReconciliationStatementLine>[],
    this.matches = const <ReconciliationMatchRecord>[],
  });
  final int id;
  final String reference;
  final String type;
  final String status;
  final ReconciliationAccount account;
  final String periodFrom;
  final String periodTo;
  final ReconciliationBalances balances;
  final ReconciliationSummary summary;
  final bool canComplete;
  final List<String> blockingReasons;
  final int? createdBy;
  final int? completedBy;
  final String? createdAt;
  final String? completedAt;
  final List<String> allowedActions;
  final List<ReconciliationStatementLine> statementLines;
  final List<ReconciliationMatchRecord> matches;

  factory ReconciliationSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> period = json['period'] is Map
        ? Map<String, dynamic>.from(json['period'] as Map)
        : const <String, dynamic>{};
    return ReconciliationSession(
      id: readInt(json['id']) ?? 0,
      reference: readString(json['reference']),
      type: readString(json['type']),
      status: readString(json['status']),
      account: ReconciliationAccount.fromJson(
        json['account'] is Map ? Map<String, dynamic>.from(json['account'] as Map) : const <String, dynamic>{},
      ),
      periodFrom: readString(period['from']),
      periodTo: readString(period['to']),
      balances: ReconciliationBalances.fromJson(
        json['balances'] is Map ? Map<String, dynamic>.from(json['balances'] as Map) : const <String, dynamic>{},
      ),
      summary: ReconciliationSummary.fromJson(
        json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : const <String, dynamic>{},
      ),
      canComplete: readBool(json['canComplete']),
      blockingReasons: readStringList(json['blockingReasons']),
      createdBy: readInt(json['createdBy']),
      completedBy: readInt(json['completedBy']),
      createdAt: readString(json['createdAt']).isEmpty ? null : readString(json['createdAt']),
      completedAt: readString(json['completedAt']).isEmpty ? null : readString(json['completedAt']),
      allowedActions: readStringList(json['allowedActions']),
      statementLines: readMapList(
        json['statementLines'],
      ).map(ReconciliationStatementLine.fromJson).toList(growable: false),
      matches: readMapList(
        json['matches'],
      ).map(ReconciliationMatchRecord.fromJson).toList(growable: false),
    );
  }
}

class ReconciliationStatementLine {
  const ReconciliationStatementLine({
    required this.id,
    required this.transactionDate,
    required this.reference,
    required this.description,
    required this.amount,
    required this.direction,
    required this.matchedAmount,
    required this.remainingAmount,
    this.valueDate,
    this.externalIdentifier,
  });
  final int id;
  final String transactionDate;
  final String? valueDate;
  final String reference;
  final String description;
  final String amount;
  final String direction;
  final String? externalIdentifier;
  final String matchedAmount;
  final String remainingAmount;
  factory ReconciliationStatementLine.fromJson(Map<String, dynamic> json) =>
      ReconciliationStatementLine(
        id: readInt(json['id']) ?? 0,
        transactionDate: readString(json['transactionDate']),
        valueDate: readString(json['valueDate']).isEmpty ? null : readString(json['valueDate']),
        reference: readString(json['reference']),
        description: readString(json['description']),
        amount: readString(json['amount']),
        direction: readString(json['direction']),
        externalIdentifier: readString(json['externalIdentifier']).isEmpty
            ? null
            : readString(json['externalIdentifier']),
        matchedAmount: readString(json['matchedAmount'], fallback: '0.00'),
        remainingAmount: readString(json['remainingAmount'], fallback: '0.00'),
      );
}

class ReconciliationMatchRecord {
  const ReconciliationMatchRecord({
    required this.id,
    required this.statementLineId,
    required this.journalEntryId,
    required this.journalReference,
    required this.amount,
  });
  final int id;
  final int statementLineId;
  final int journalEntryId;
  final String journalReference;
  final String amount;
  factory ReconciliationMatchRecord.fromJson(Map<String, dynamic> json) =>
      ReconciliationMatchRecord(
        id: readInt(json['id']) ?? 0,
        statementLineId: readInt(json['statementLineId']) ?? 0,
        journalEntryId: readInt(json['journalEntryId']) ?? 0,
        journalReference: readString(json['journalReference']),
        amount: readString(json['amount']),
      );
}

class ReconciliationSystemTransaction {
  const ReconciliationSystemTransaction({
    required this.journalEntryId,
    required this.reference,
    required this.date,
    required this.description,
    required this.direction,
    required this.amount,
    required this.matchedAmount,
  });
  final int journalEntryId;
  final String reference;
  final String date;
  final String description;
  final String direction;
  final String amount;
  final String matchedAmount;
  factory ReconciliationSystemTransaction.fromJson(Map<String, dynamic> json) =>
      ReconciliationSystemTransaction(
        journalEntryId: readInt(json['journalEntryId']) ?? 0,
        reference: readString(json['reference']),
        date: readString(json['date']),
        description: readString(json['description']),
        direction: readString(json['direction']),
        amount: readString(json['amount']),
        matchedAmount: readString(json['matchedAmount'], fallback: '0.00'),
      );
}

class ReconciliationSuggestion {
  const ReconciliationSuggestion({
    required this.statementLineId,
    required this.confidence,
    required this.candidates,
  });
  final int statementLineId;
  final String? confidence;
  final List<ReconciliationSystemTransaction> candidates;
  factory ReconciliationSuggestion.fromJson(Map<String, dynamic> json) =>
      ReconciliationSuggestion(
        statementLineId: readInt(json['statementLineId']) ?? 0,
        confidence: readString(json['confidence']).isEmpty ? null : readString(json['confidence']),
        candidates: readMapList(
          json['candidates'],
        ).map(ReconciliationSystemTransaction.fromJson).toList(growable: false),
      );
}

/// Daily Closing list row (`GET finance/daily-closings`). Every value is the
/// backend's own computed closing snapshot; Flutter only formats it.
class DailyClosingListItem {
  const DailyClosingListItem({
    required this.id,
    required this.reference,
    required this.businessDate,
    required this.branchId,
    required this.branchName,
    required this.status,
    required this.readiness,
    required this.warningsCount,
    required this.netSales,
    required this.expectedCash,
    required this.actualCash,
    required this.difference,
    this.closedBy,
    this.closedAt,
    this.allowedActions = const <String>[],
  });
  final int id;
  final String reference;
  final String businessDate;
  final int branchId;
  final String branchName;
  final String status;
  final String readiness;
  final int warningsCount;
  final String netSales;
  final String? expectedCash;
  final String? actualCash;
  final String? difference;
  final int? closedBy;
  final String? closedAt;
  final List<String> allowedActions;

  factory DailyClosingListItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> branch = json['branch'] is Map
        ? Map<String, dynamic>.from(json['branch'] as Map)
        : const <String, dynamic>{};
    return DailyClosingListItem(
      id: readInt(json['id']) ?? 0,
      reference: readString(json['reference']),
      businessDate: readString(json['businessDate']),
      branchId: readInt(branch['id']) ?? 0,
      branchName: readString(branch['name']),
      status: readString(json['status']),
      readiness: readString(json['readiness']),
      warningsCount: readInt(json['warningsCount']) ?? 0,
      netSales: readString(json['netSales'], fallback: '0.00'),
      expectedCash: readString(json['expectedCash']).isEmpty ? null : readString(json['expectedCash']),
      actualCash: readString(json['actualCash']).isEmpty ? null : readString(json['actualCash']),
      difference: readString(json['difference']).isEmpty ? null : readString(json['difference']),
      closedBy: readInt(json['closedBy']),
      closedAt: readString(json['closedAt']).isEmpty ? null : readString(json['closedAt']),
      allowedActions: readStringList(json['allowedActions']),
    );
  }
}

class DailyClosingSales {
  const DailyClosingSales({
    required this.grossSales,
    required this.discounts,
    required this.refunds,
    required this.netSales,
    required this.cashSales,
    required this.cardSales,
    required this.otherSales,
  });
  final String grossSales;
  final String discounts;
  final String refunds;
  final String netSales;
  final String cashSales;
  final String cardSales;
  final String otherSales;
  factory DailyClosingSales.fromJson(Map<String, dynamic> json) => DailyClosingSales(
    grossSales: readString(json['grossSales'], fallback: '0.00'),
    discounts: readString(json['discounts'], fallback: '0.00'),
    refunds: readString(json['refunds'], fallback: '0.00'),
    netSales: readString(json['netSales'], fallback: '0.00'),
    cashSales: readString(json['cashSales'], fallback: '0.00'),
    cardSales: readString(json['cardSales'], fallback: '0.00'),
    otherSales: readString(json['otherSales'], fallback: '0.00'),
  );
}

class DailyClosingCashFigures {
  const DailyClosingCashFigures({
    required this.openingCash,
    required this.cashSales,
    required this.cashRefunds,
    required this.expensesCash,
    required this.supplierPaymentsCash,
    required this.transfersIn,
    required this.transfersOut,
    required this.expectedCash,
    this.actualCash,
    this.difference,
    this.differenceState,
  });
  final String openingCash;
  final String cashSales;
  final String cashRefunds;
  final String expensesCash;
  final String supplierPaymentsCash;
  final String transfersIn;
  final String transfersOut;
  final String expectedCash;
  final String? actualCash;
  final String? difference;
  final String? differenceState;
  factory DailyClosingCashFigures.fromJson(Map<String, dynamic> json) => DailyClosingCashFigures(
    openingCash: readString(json['openingCash'], fallback: '0.00'),
    cashSales: readString(json['cashSales'], fallback: '0.00'),
    cashRefunds: readString(json['cashRefunds'], fallback: '0.00'),
    expensesCash: readString(json['expensesCash'], fallback: '0.00'),
    supplierPaymentsCash: readString(json['supplierPaymentsCash'], fallback: '0.00'),
    transfersIn: readString(json['transfersIn'], fallback: '0.00'),
    transfersOut: readString(json['transfersOut'], fallback: '0.00'),
    expectedCash: readString(json['expectedCash'], fallback: '0.00'),
    actualCash: readString(json['actualCash']).isEmpty ? null : readString(json['actualCash']),
    difference: readString(json['difference']).isEmpty ? null : readString(json['difference']),
    differenceState: readString(json['differenceState']).isEmpty ? null : readString(json['differenceState']),
  );
}

class DailyClosingOperations {
  const DailyClosingOperations({
    required this.expensesTotal,
    required this.pendingExpensesCount,
    required this.supplierPaymentsTotal,
    required this.wasteValue,
    required this.stockShortageValue,
    required this.stockSurplusValue,
  });
  final String expensesTotal;
  final int pendingExpensesCount;
  final String supplierPaymentsTotal;
  final String wasteValue;
  final String stockShortageValue;
  final String stockSurplusValue;
  factory DailyClosingOperations.fromJson(Map<String, dynamic> json) => DailyClosingOperations(
    expensesTotal: readString(json['expensesTotal'], fallback: '0.00'),
    pendingExpensesCount: readInt(json['pendingExpensesCount']) ?? 0,
    supplierPaymentsTotal: readString(json['supplierPaymentsTotal'], fallback: '0.00'),
    wasteValue: readString(json['wasteValue'], fallback: '0.00'),
    stockShortageValue: readString(json['stockShortageValue'], fallback: '0.00'),
    stockSurplusValue: readString(json['stockSurplusValue'], fallback: '0.00'),
  );
}

class DailyClosingShiftsSummary {
  const DailyClosingShiftsSummary({required this.total, required this.open, required this.closed});
  final int total;
  final int open;
  final int closed;
  factory DailyClosingShiftsSummary.fromJson(Map<String, dynamic> json) => DailyClosingShiftsSummary(
    total: readInt(json['total']) ?? 0,
    open: readInt(json['open']) ?? 0,
    closed: readInt(json['closed']) ?? 0,
  );
}

class DailyClosingReconciliationSummary {
  const DailyClosingReconciliationSummary({
    required this.required_,
    required this.complete,
    required this.unresolvedCount,
    required this.requiredCount,
    required this.completedCount,
    required this.incompleteCount,
    this.accounts = const <Map<String, dynamic>>[],
  });
  final bool required_;
  final bool complete;
  final int unresolvedCount;
  final int requiredCount;
  final int completedCount;
  final int incompleteCount;
  final List<Map<String, dynamic>> accounts;
  factory DailyClosingReconciliationSummary.fromJson(Map<String, dynamic> json) =>
      DailyClosingReconciliationSummary(
        required_: readBool(json['required']),
        complete: readBool(json['complete']),
        unresolvedCount: readInt(json['unresolvedCount']) ?? 0,
        requiredCount: readInt(json['requiredCount']) ?? 0,
        completedCount: readInt(json['completedCount']) ?? 0,
        incompleteCount: readInt(json['incompleteCount']) ?? 0,
        accounts: readMapList(json['accounts']),
      );
}

class DailyClosingFinancialIntegrity {
  const DailyClosingFinancialIntegrity({
    required this.draftJournals,
    required this.missingPostings,
    required this.failedPostings,
    required this.lateActivityAfterClose,
  });
  final int draftJournals;
  final int missingPostings;
  final int failedPostings;
  final int lateActivityAfterClose;
  factory DailyClosingFinancialIntegrity.fromJson(Map<String, dynamic> json) => DailyClosingFinancialIntegrity(
    draftJournals: readInt(json['draftJournals']) ?? 0,
    missingPostings: readInt(json['missingPostings']) ?? 0,
    failedPostings: readInt(json['failedPostings']) ?? 0,
    lateActivityAfterClose: readInt(json['lateActivityAfterClose']) ?? 0,
  );
}

/// A backend readiness blocker/warning row. Extra fields (`count`, `amount`,
/// `items`, `financialAccountId`, …) vary by `code` and are kept raw — the
/// UI reads only what a given code defines rather than modelling every shape.
class DailyClosingIssue {
  const DailyClosingIssue({required this.code, required this.severity, required this.raw});
  final String code;
  final String severity;
  final Map<String, dynamic> raw;
  factory DailyClosingIssue.fromJson(Map<String, dynamic> json) =>
      DailyClosingIssue(code: readString(json['code']), severity: readString(json['severity']), raw: json);
}

class DailyClosingLateActivity {
  const DailyClosingLateActivity({
    required this.journalId,
    required this.reference,
    required this.sourceType,
    required this.amount,
    required this.postedAt,
    this.sourceId,
  });
  final int journalId;
  final String reference;
  final String? sourceType;
  final int? sourceId;
  final String? amount;
  final String postedAt;
  factory DailyClosingLateActivity.fromJson(Map<String, dynamic> json) => DailyClosingLateActivity(
    journalId: readInt(json['journalId']) ?? 0,
    reference: readString(json['reference']),
    sourceType: readString(json['sourceType']).isEmpty ? null : readString(json['sourceType']),
    sourceId: readInt(json['sourceId']),
    amount: readString(json['amount']).isEmpty ? null : readString(json['amount']),
    postedAt: readString(json['postedAt']),
  );
}

/// Daily Closing detail/workspace (`GET finance/daily-closings/{id}` and the
/// `GET finance/daily-closing?branchId&date` preview that gets-or-creates the
/// row). Readiness, blockers, warnings, and every figure are Laravel's own
/// `DailyClosingService::present()` snapshot — this screen only renders it.
class DailyClosingDetail {
  const DailyClosingDetail({
    required this.id,
    required this.reference,
    required this.businessDate,
    required this.status,
    required this.readiness,
    required this.canClose,
    required this.branchId,
    required this.branchName,
    required this.sales,
    required this.refunds,
    required this.cash,
    required this.operations,
    required this.shifts,
    required this.reconciliation,
    required this.financialIntegrity,
    this.paymentBreakdown = const <Map<String, dynamic>>[],
    this.lateActivity = const <DailyClosingLateActivity>[],
    this.blockers = const <DailyClosingIssue>[],
    this.warnings = const <DailyClosingIssue>[],
    this.closedBy,
    this.closedAt,
    this.allowedActions = const <String>[],
  });
  final int id;
  final String reference;
  final String businessDate;
  final String status;
  final String readiness;
  final bool canClose;
  final int branchId;
  final String branchName;
  final DailyClosingSales sales;
  final Map<String, dynamic> refunds;
  final DailyClosingCashFigures cash;
  final DailyClosingOperations operations;
  final DailyClosingShiftsSummary shifts;
  final DailyClosingReconciliationSummary reconciliation;
  final DailyClosingFinancialIntegrity financialIntegrity;
  final List<Map<String, dynamic>> paymentBreakdown;
  final List<DailyClosingLateActivity> lateActivity;
  final List<DailyClosingIssue> blockers;
  final List<DailyClosingIssue> warnings;
  final int? closedBy;
  final String? closedAt;
  final List<String> allowedActions;

  bool get isClosed => status == 'closed';

  factory DailyClosingDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> branch = json['branch'] is Map
        ? Map<String, dynamic>.from(json['branch'] as Map)
        : const <String, dynamic>{};
    final Map<String, dynamic> integrityIssues = json['integrityIssues'] is Map
        ? Map<String, dynamic>.from(json['integrityIssues'] as Map)
        : const <String, dynamic>{};
    return DailyClosingDetail(
      id: readInt(json['id']) ?? 0,
      reference: readString(json['reference']),
      businessDate: readString(json['businessDate']),
      status: readString(json['status'], fallback: 'open'),
      readiness: readString(json['readiness']),
      canClose: readBool(json['canClose']),
      branchId: readInt(branch['id']) ?? 0,
      branchName: readString(branch['name']),
      sales: DailyClosingSales.fromJson(_map(json['sales'])),
      refunds: _map(json['refunds']),
      cash: DailyClosingCashFigures.fromJson(_map(json['cash'])),
      operations: DailyClosingOperations.fromJson(_map(json['operations'])),
      shifts: DailyClosingShiftsSummary.fromJson(_map(json['shifts'])),
      reconciliation: DailyClosingReconciliationSummary.fromJson(_map(json['reconciliation'])),
      financialIntegrity: DailyClosingFinancialIntegrity.fromJson(_map(json['financialIntegrity'])),
      paymentBreakdown: readMapList(json['paymentBreakdown']),
      lateActivity: readMapList(
        integrityIssues['lateActivity'],
      ).map(DailyClosingLateActivity.fromJson).toList(growable: false),
      blockers: readMapList(json['blockers']).map(DailyClosingIssue.fromJson).toList(growable: false),
      warnings: readMapList(json['warnings']).map(DailyClosingIssue.fromJson).toList(growable: false),
      closedBy: readInt(json['closedBy']),
      closedAt: readString(json['closedAt']).isEmpty ? null : readString(json['closedAt']),
      allowedActions: readStringList(json['allowedActions']),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
