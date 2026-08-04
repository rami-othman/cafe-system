// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:equatable/equatable.dart';

import '../../../pos/models/json_helpers.dart';

/// Server-owned metadata for an immutable Menu snapshot. Status remains a
/// string so newer backend statuses can be displayed safely.
class PublishedVersion extends Equatable {
  const PublishedVersion({
    required this.id,
    required this.versionNumber,
    required this.checksum,
    required this.status,
    required this.publishedAt,
    this.publicationId,
    this.publicationStatus,
    this.isCurrent = false,
    this.changeSummary,
    this.sourcePublicationId,
    this.branchId,
    this.channel,
  });

  factory PublishedVersion.fromJson(Map<String, dynamic> json) =>
      PublishedVersion(
        id: readInt(json['id']) ?? 0,
        versionNumber: readInt(json['versionNumber']) ?? 0,
        checksum: readString(json['checksum']),
        status: readString(json['status'], fallback: 'unknown'),
        publishedAt: readString(json['publishedAt']),
        publicationId: readInt(json['publicationId']),
        publicationStatus: json['publicationStatus'] == null
            ? null
            : readString(json['publicationStatus'], fallback: 'unknown'),
        isCurrent: readBool(json['isCurrent']),
        changeSummary: json['changeSummary'] is Map
            ? Map<String, dynamic>.from(json['changeSummary'] as Map)
            : null,
        sourcePublicationId: readInt(json['sourcePublicationId']),
        branchId: readInt(json['branchId']),
        channel: json['channel'] == null ? null : readString(json['channel']),
      );

  final int id;
  final int versionNumber;
  final String checksum;
  final String status;
  final String publishedAt;
  final int? publicationId;
  final String? publicationStatus;
  final bool isCurrent;
  final Map<String, dynamic>? changeSummary;
  final int? sourcePublicationId;
  final int? branchId;
  final String? channel;

  @override
  List<Object?> get props => <Object?>[
    id,
    versionNumber,
    checksum,
    status,
    publishedAt,
    publicationId,
    publicationStatus,
    isCurrent,
    changeSummary,
    sourcePublicationId,
    branchId,
    channel,
  ];
}

class PublishedVersionPage extends Equatable {
  const PublishedVersionPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });
  factory PublishedVersionPage.fromEnvelope(Map<String, dynamic> json) {
    final dynamic rows = json['data'];
    final Map meta = json['meta'] is Map
        ? json['meta'] as Map
        : const <String, dynamic>{};
    if (rows is! List)
      throw const FormatException(
        'Invalid published version history response.',
      );
    return PublishedVersionPage(
      items: rows
          .whereType<Map>()
          .map(
            (row) => PublishedVersion.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
      page: readInt(meta['currentPage']) ?? 1,
      perPage: readInt(meta['perPage']) ?? 20,
      total: readInt(meta['total']) ?? 0,
    );
  }
  final List<PublishedVersion> items;
  final int page;
  final int perPage;
  final int total;
  bool get hasPrevious => page > 1;
  bool get hasNext => page * perPage < total;
  @override
  List<Object?> get props => <Object?>[items, page, perPage, total];
}

class SnapshotSummary extends Equatable {
  const SnapshotSummary({
    required this.menuCount,
    required this.sectionCount,
    required this.productCount,
    required this.variantCount,
    required this.modifierGroupCount,
  });
  factory SnapshotSummary.fromJson(Map<String, dynamic> json) =>
      SnapshotSummary(
        menuCount: readInt(json['menuCount']) ?? 0,
        sectionCount: readInt(json['sectionCount']) ?? 0,
        productCount: readInt(json['productCount']) ?? 0,
        variantCount: readInt(json['variantCount']) ?? 0,
        modifierGroupCount: readInt(json['modifierGroupCount']) ?? 0,
      );
  final int menuCount;
  final int sectionCount;
  final int productCount;
  final int variantCount;
  final int modifierGroupCount;
  @override
  List<Object?> get props => <Object?>[
    menuCount,
    sectionCount,
    productCount,
    variantCount,
    modifierGroupCount,
  ];
}

class PublishedVersionDetail extends Equatable {
  const PublishedVersionDetail({
    required this.version,
    required this.summary,
    this.payload,
  });
  factory PublishedVersionDetail.fromJson(Map<String, dynamic> json) {
    final dynamic summary = json['snapshotSummary'];
    if (summary is! Map)
      throw const FormatException('Invalid published version detail response.');
    return PublishedVersionDetail(
      version: PublishedVersion.fromJson(json),
      summary: SnapshotSummary.fromJson(Map<String, dynamic>.from(summary)),
      payload: json['payload'] is Map || json['payload'] is List
          ? json['payload']
          : null,
    );
  }
  final PublishedVersion version;
  final SnapshotSummary summary;
  final dynamic payload;
  @override
  List<Object?> get props => <Object?>[version, summary, payload];
}

class VersionComparison extends Equatable {
  const VersionComparison({
    required this.fromId,
    required this.fromVersionNumber,
    required this.toId,
    required this.toVersionNumber,
    required this.sameChecksum,
    required this.truncated,
    required this.changes,
  });
  factory VersionComparison.fromJson(Map<String, dynamic> json) {
    final Map from = json['fromVersion'] is Map
        ? json['fromVersion'] as Map
        : const <String, dynamic>{};
    final Map to = json['toVersion'] is Map
        ? json['toVersion'] as Map
        : const <String, dynamic>{};
    final Map rawChanges = json['changes'] is Map
        ? json['changes'] as Map
        : const <String, dynamic>{};
    return VersionComparison(
      fromId: readInt(from['id']) ?? 0,
      fromVersionNumber: readInt(from['versionNumber']) ?? 0,
      toId: readInt(to['id']) ?? 0,
      toVersionNumber: readInt(to['versionNumber']) ?? 0,
      sameChecksum: readBool(json['sameChecksum']),
      truncated: readBool(json['truncated']),
      changes: rawChanges.map(
        (key, value) => MapEntry(
          '$key',
          (value as List? ?? const <dynamic>[])
              .map((entry) => '$entry')
              .toList(growable: false),
        ),
      ),
    );
  }
  final int fromId;
  final int fromVersionNumber;
  final int toId;
  final int toVersionNumber;
  final bool sameChecksum;
  final bool truncated;
  final Map<String, List<String>> changes;
  @override
  List<Object?> get props => <Object?>[
    fromId,
    fromVersionNumber,
    toId,
    toVersionNumber,
    sameChecksum,
    truncated,
    changes,
  ];
}

class RollbackResult extends Equatable {
  const RollbackResult({
    required this.rolledBack,
    required this.noChanges,
    required this.publicationId,
    required this.sourceVersionId,
    required this.sourceVersionNumber,
    required this.versionId,
    required this.versionNumber,
    required this.checksum,
    required this.status,
  });
  factory RollbackResult.fromJson(Map<String, dynamic> json) {
    final Map source = json['sourceVersion'] is Map
        ? json['sourceVersion'] as Map
        : const <String, dynamic>{};
    final Map version = json['version'] is Map
        ? json['version'] as Map
        : const <String, dynamic>{};
    return RollbackResult(
      rolledBack: readBool(json['rolledBack']),
      noChanges: readBool(json['noChanges']),
      publicationId: readInt(json['publicationId']),
      sourceVersionId: readInt(source['id']) ?? 0,
      sourceVersionNumber: readInt(source['versionNumber']) ?? 0,
      versionId: readInt(version['id']) ?? 0,
      versionNumber: readInt(version['versionNumber']) ?? 0,
      checksum: readString(version['checksum']),
      status: readString(version['status'], fallback: 'unknown'),
    );
  }
  final bool rolledBack;
  final bool noChanges;
  final int? publicationId;
  final int sourceVersionId;
  final int sourceVersionNumber;
  final int versionId;
  final int versionNumber;
  final String checksum;
  final String status;
  @override
  List<Object?> get props => <Object?>[
    rolledBack,
    noChanges,
    publicationId,
    sourceVersionId,
    sourceVersionNumber,
    versionId,
    versionNumber,
    checksum,
    status,
  ];
}
