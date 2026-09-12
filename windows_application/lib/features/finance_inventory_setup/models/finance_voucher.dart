import '../../pos/models/json_helpers.dart';

class FinanceVoucher {
  const FinanceVoucher({
    required this.id,
    required this.documentNumber,
    required this.documentType,
    required this.status,
    required this.documentDate,
    required this.amount,
    required this.financialLocationId,
    this.branchId,
    this.branchName,
    this.financialLocationName,
    this.description,
    this.externalReference,
    this.journalEntryId,
    this.reversalJournalEntryId,
    this.lines = const <FinanceVoucherLine>[],
    this.allowedActions = const <String>[],
  });

  final int id;
  final String documentNumber, documentType, status, documentDate, amount;
  final int financialLocationId;
  final int? branchId, journalEntryId, reversalJournalEntryId;
  final String? branchName, financialLocationName, description, externalReference;
  final List<FinanceVoucherLine> lines;
  final List<String> allowedActions;

  factory FinanceVoucher.fromJson(Map<String, dynamic> json) => FinanceVoucher(
    id: readInt(json['id']) ?? 0,
    documentNumber: readString(json['documentNumber']),
    documentType: readString(json['documentType']),
    status: readString(json['status']),
    documentDate: readString(json['documentDate']),
    amount: readString(json['amount']),
    financialLocationId: readInt(json['financialLocationId']) ?? 0,
    branchId: readInt(json['branchId']),
    branchName: _optional(json['branchName']),
    financialLocationName: _optional(json['financialLocationName']),
    description: _optional(json['description']),
    externalReference: _optional(json['externalReference']),
    journalEntryId: readInt(json['journalEntryId']),
    reversalJournalEntryId: readInt(json['reversalJournalEntryId']),
    lines: readMapList(json['lines']).map(FinanceVoucherLine.fromJson).toList(growable: false),
    allowedActions: (json['allowedActions'] as List? ?? const <dynamic>[]).map((value) => '$value').toList(growable: false),
  );
}

class FinanceVoucherLine {
  const FinanceVoucherLine({required this.accountId, required this.accountCode, required this.accountNameAr, required this.debit, required this.credit, this.description});
  final int accountId;
  final String accountCode, accountNameAr, debit, credit;
  final String? description;
  factory FinanceVoucherLine.fromJson(Map<String, dynamic> json) => FinanceVoucherLine(
    accountId: readInt(json['accountId']) ?? 0,
    accountCode: readString(json['accountCode']),
    accountNameAr: readString(json['accountNameAr']),
    debit: readString(json['debit']), credit: readString(json['credit']), description: _optional(json['description']),
  );
}

String? _optional(Object? value) {
  final result = readString(value);
  return result.isEmpty ? null : result;
}
