import 'package:equatable/equatable.dart';

class CustomerImportCounts extends Equatable {
  const CustomerImportCounts({
    required this.total,
    required this.ready,
    required this.warnings,
    required this.rejected,
    required this.duplicateCandidates,
    required this.processed,
    required this.createdCustomers,
    required this.skippedCustomers,
    required this.failedRows,
    required this.createdGroups,
    required this.createdMemberships,
  });

  final int total;
  final int ready;
  final int warnings;
  final int rejected;
  final int duplicateCandidates;
  final int processed;
  final int createdCustomers;
  final int skippedCustomers;
  final int failedRows;
  final int createdGroups;
  final int createdMemberships;

  factory CustomerImportCounts.fromJson(Map<String, dynamic> json) =>
      CustomerImportCounts(
        total: _int(json, 'total'),
        ready: _int(json, 'ready'),
        warnings: _int(json, 'warnings'),
        rejected: _int(json, 'rejected'),
        duplicateCandidates: _int(json, 'duplicateCandidates'),
        processed: _int(json, 'processed'),
        createdCustomers: _int(json, 'createdCustomers'),
        skippedCustomers: _int(json, 'skippedCustomers'),
        failedRows: _int(json, 'failedRows'),
        createdGroups: _int(json, 'createdGroups'),
        createdMemberships: _int(json, 'createdMemberships'),
      );

  @override
  List<Object?> get props => <Object?>[
    total,
    ready,
    warnings,
    rejected,
    duplicateCandidates,
    processed,
    createdCustomers,
    skippedCustomers,
    failedRows,
    createdGroups,
    createdMemberships,
  ];
}

class CustomerImportIssue extends Equatable {
  const CustomerImportIssue({
    required this.rowNumber,
    required this.name,
    required this.status,
    required this.classification,
    required this.warnings,
    required this.errors,
  });

  final int rowNumber;
  final String? name;
  final String status;
  final String classification;
  final List<String> warnings;
  final List<String> errors;

  factory CustomerImportIssue.fromJson(Map<String, dynamic> json) =>
      CustomerImportIssue(
        rowNumber: _int(json, 'rowNumber'),
        name: json['name'] is String ? json['name'] as String : null,
        status: _string(json, 'status'),
        classification: _string(json, 'classification'),
        warnings: _strings(json['warnings']),
        errors: _strings(json['errors']),
      );

  @override
  List<Object?> get props => <Object?>[
    rowNumber,
    name,
    status,
    classification,
    warnings,
    errors,
  ];
}

class CustomerImportStatus extends Equatable {
  const CustomerImportStatus({
    required this.id,
    required this.filename,
    required this.fingerprint,
    required this.encoding,
    required this.delimiter,
    required this.status,
    required this.createMissingGroups,
    required this.counts,
    required this.matchedGroups,
    required this.missingGroups,
    required this.issues,
    required this.errorReportAvailable,
    this.failureCode,
  });

  final int id;
  final String filename;
  final String fingerprint;
  final String encoding;
  final String delimiter;
  final String status;
  final bool? createMissingGroups;
  final CustomerImportCounts counts;
  final List<String> matchedGroups;
  final List<String> missingGroups;
  final List<CustomerImportIssue> issues;
  final bool errorReportAvailable;
  final String? failureCode;

  factory CustomerImportStatus.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> counts = _map(json, 'counts');
    final Map<String, dynamic> groups = _map(json, 'groups');
    return CustomerImportStatus(
      id: _int(json, 'id'),
      filename: _string(json, 'filename'),
      fingerprint: _string(json, 'fingerprint'),
      encoding: _string(json, 'encoding'),
      delimiter: _string(json, 'delimiter'),
      status: _string(json, 'status'),
      createMissingGroups: json['createMissingGroups'] is bool
          ? json['createMissingGroups'] as bool
          : null,
      counts: CustomerImportCounts.fromJson(counts),
      matchedGroups: _strings(groups['matched']),
      missingGroups: _strings(groups['missing']),
      issues:
          (json['issues'] is List ? json['issues'] as List : const <dynamic>[])
              .map(
                (dynamic value) =>
                    CustomerImportIssue.fromJson(_mapValue(value)),
              )
              .toList(growable: false),
      errorReportAvailable: json['errorReportAvailable'] == true,
      failureCode: json['failureCode'] is String
          ? json['failureCode'] as String
          : null,
    );
  }

  bool get isTerminal =>
      status == 'completed' ||
      status == 'completed_with_errors' ||
      status == 'failed';

  @override
  List<Object?> get props => <Object?>[
    id,
    filename,
    fingerprint,
    encoding,
    delimiter,
    status,
    createMissingGroups,
    counts,
    matchedGroups,
    missingGroups,
    issues,
    errorReportAvailable,
    failureCode,
  ];
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  return _mapValue(value);
}

Map<String, dynamic> _mapValue(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : throw const FormatException(
        'Customer import response object is invalid.',
      );

String _string(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Customer import response field $key is invalid.');
}

int _int(Map<String, dynamic> json, String key) {
  final dynamic value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Customer import response field $key is invalid.');
}

List<String> _strings(dynamic value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}
