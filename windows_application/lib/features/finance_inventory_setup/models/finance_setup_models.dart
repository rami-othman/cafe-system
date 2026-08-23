import '../../pos/models/json_helpers.dart';

class SetupStatus {
  const SetupStatus({
    required this.systemAccountsReady,
    required this.centralWarehouseReady,
    required this.branchWarehouseCoverageReady,
    required this.financialSetupReady,
    required this.missingBranchWarehouses,
  });

  final bool systemAccountsReady;
  final bool centralWarehouseReady;
  final bool branchWarehouseCoverageReady;
  final bool financialSetupReady;
  final List<String> missingBranchWarehouses;

  factory SetupStatus.fromJson(Map<String, dynamic> json) => SetupStatus(
    systemAccountsReady: readBool(json['systemAccountsReady']),
    centralWarehouseReady: readBool(json['centralWarehouseReady']),
    branchWarehouseCoverageReady: readBool(
      json['branchWarehouseCoverageReady'],
    ),
    financialSetupReady: readBool(json['financialSetupReady']),
    missingBranchWarehouses: readMapList(json['missingBranchWarehouses'])
        .map((Map<String, dynamic> item) => readString(item['name']))
        .toList(growable: false),
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
  });
  final int id;
  final int? parentAccountId;
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
    lines: readMapList(
      json['lines'],
    ).map(JournalLine.fromJson).toList(growable: false),
  );
}
