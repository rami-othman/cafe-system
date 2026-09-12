import 'package:equatable/equatable.dart';

class CustomerPhoneDraft extends Equatable {
  const CustomerPhoneDraft({
    required this.rowId,
    required this.rawNumber,
    required this.type,
    required this.isPrimary,
  });

  final String rowId;
  final String rawNumber;
  final String type;
  final bool isPrimary;

  CustomerPhoneDraft copyWith({
    String? rawNumber,
    String? type,
    bool? isPrimary,
  }) => CustomerPhoneDraft(
    rowId: rowId,
    rawNumber: rawNumber ?? this.rawNumber,
    type: type ?? this.type,
    isPrimary: isPrimary ?? this.isPrimary,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rawNumber': rawNumber,
    'type': type,
    'isPrimary': isPrimary,
  };

  @override
  List<Object> get props => <Object>[rowId, rawNumber, type, isPrimary];
}

class CustomerDraft extends Equatable {
  const CustomerDraft({
    required this.name,
    this.email,
    this.birthDate,
    this.notes,
    this.phones = const <CustomerPhoneDraft>[],
    this.groupIds = const <int>{},
  });

  final String name;
  final String? email;
  final DateTime? birthDate;
  final String? notes;
  final List<CustomerPhoneDraft> phones;
  final Set<int> groupIds;

  bool get hasExactlyOnePrimary =>
      phones.where((CustomerPhoneDraft phone) => phone.isPrimary).length == 1;
  bool get isReadyToSubmit =>
      name.trim().isNotEmpty && (phones.isEmpty || hasExactlyOnePrimary);

  CustomerDraft copyWith({
    String? name,
    String? email,
    DateTime? birthDate,
    String? notes,
    List<CustomerPhoneDraft>? phones,
    Set<int>? groupIds,
    bool clearEmail = false,
    bool clearBirthDate = false,
    bool clearNotes = false,
  }) => CustomerDraft(
    name: name ?? this.name,
    email: clearEmail ? null : email ?? this.email,
    birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
    notes: clearNotes ? null : notes ?? this.notes,
    phones: phones ?? this.phones,
    groupIds: groupIds ?? this.groupIds,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'email': email,
    'birthDate': birthDate == null
        ? null
        : '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
    'notes': notes,
    'phones': phones
        .map((CustomerPhoneDraft phone) => phone.toJson())
        .toList(growable: false),
    'groupIds': groupIds.toList()..sort(),
  };

  @override
  List<Object?> get props => <Object?>[
    name,
    email,
    birthDate,
    notes,
    phones,
    groupIds,
  ];
}

class GroupDraft extends Equatable {
  const GroupDraft({required this.name});

  final String name;

  bool get isReadyToSubmit => name.trim().isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name.trim()};

  @override
  List<Object> get props => <Object>[name];
}
