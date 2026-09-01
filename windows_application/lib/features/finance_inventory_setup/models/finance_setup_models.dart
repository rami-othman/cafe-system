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
    this.branchName,
    this.bankName,
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
  final String? branchName;
  final String? bankName;
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
        branchName: readString(json['branchName']).isEmpty
            ? null
            : readString(json['branchName']),
        bankName: readString(json['bankName']).isEmpty
            ? null
            : readString(json['bankName']),
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
  });
  final int id;
  final String code;
  final String name;
  final String type;
  final int financialAccountId;
  final String financialAccountCode;
  final bool isActive;
  factory PaymentMethodSetting.fromJson(Map<String, dynamic> json) =>
      PaymentMethodSetting(
        id: readInt(json['id']) ?? 0,
        code: readString(json['code']),
        name: readString(json['name']),
        type: readString(json['type']),
        financialAccountId: readInt(json['financialAccountId']) ?? 0,
        financialAccountCode: readString(json['financialAccountCode']),
        isActive: readBool(json['isActive']),
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
    required this.date,
    required this.type,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });
  final String date;
  final String type;
  final String reference;
  final String debit;
  final String credit;
  final String runningBalance;
  factory SupplierStatementLine.fromJson(Map<String, dynamic> json) =>
      SupplierStatementLine(
        date: readString(json['date']),
        type: readString(json['type']),
        reference: readString(json['reference']),
        debit: readString(json['debit']),
        credit: readString(json['credit']),
        runningBalance: readString(json['runningBalance']),
      );
}
