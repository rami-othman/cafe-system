class CafeProfile {
  const CafeProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.timezone,
    required this.currency,
    required this.status,
  });

  final String name;
  final String? email;
  final String? phone;
  final String timezone;
  final String currency;
  final String status;

  factory CafeProfile.fromJson(Map<String, dynamic> json) => CafeProfile(
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    timezone: json['timezone'] as String? ?? 'UTC',
    currency: json['currency'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );
}

class CafeProfileDraft {
  const CafeProfileDraft({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.timezone = 'UTC',
  });

  final String name;
  final String email;
  final String phone;
  final String timezone;

  factory CafeProfileDraft.fromProfile(CafeProfile profile) => CafeProfileDraft(
    name: profile.name,
    email: profile.email ?? '',
    phone: profile.phone ?? '',
    timezone: profile.timezone,
  );

  CafeProfileDraft copyWith({
    String? name,
    String? email,
    String? phone,
    String? timezone,
  }) => CafeProfileDraft(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    timezone: timezone ?? this.timezone,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'email': email.trim().isEmpty ? null : email.trim(),
    'phone': phone.trim().isEmpty ? null : phone.trim(),
    'timezone': timezone,
  };
}

class CafeConfigurationBranch {
  const CafeConfigurationBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.timezone,
    required this.currency,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String timezone;
  final String currency;
  final bool isActive;

  factory CafeConfigurationBranch.fromJson(Map<String, dynamic> json) =>
      CafeConfigurationBranch(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        timezone: json['timezone'] as String? ?? 'UTC',
        currency: json['currency'] as String? ?? '',
        isActive: json['isActive'] == true,
      );
}

class BranchDraft {
  const BranchDraft({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.timezone = 'UTC',
  });

  final String name;
  final String address;
  final String phone;
  final String timezone;

  factory BranchDraft.fromBranch(CafeConfigurationBranch branch) => BranchDraft(
    name: branch.name,
    address: branch.address ?? '',
    phone: branch.phone ?? '',
    timezone: branch.timezone,
  );

  BranchDraft copyWith({
    String? name,
    String? address,
    String? phone,
    String? timezone,
  }) => BranchDraft(
    name: name ?? this.name,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    timezone: timezone ?? this.timezone,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'address': address.trim().isEmpty ? null : address.trim(),
    'phone': phone.trim().isEmpty ? null : phone.trim(),
    'timezone': timezone,
  };
}

class TenantRole {
  const TenantRole({
    required this.id,
    required this.code,
    required this.name,
    required this.assignable,
  });

  final int id;
  final String code;
  final String name;
  final bool assignable;

  factory TenantRole.fromJson(Map<String, dynamic> json) => TenantRole(
    id: (json['id'] as num?)?.toInt() ?? 0,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    assignable: json['assignable'] == true,
  );
}

class TeamBranchAssignment {
  const TeamBranchAssignment({required this.id, required this.name});

  final int id;
  final String name;

  factory TeamBranchAssignment.fromJson(Map<String, dynamic> json) =>
      TeamBranchAssignment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
      );
}

class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.role,
    required this.status,
    required this.allBranches,
    required this.isProtectedOwner,
    required this.assignedBranches,
    required this.mustChangePassword,
  });

  final int id;
  final String name;
  final String? email;
  final String? username;
  final TenantRole role;
  final String status;
  final bool allBranches;
  final bool isProtectedOwner;
  final List<TeamBranchAssignment> assignedBranches;
  final bool mustChangePassword;

  bool get isOwner => role.code == 'owner' || isProtectedOwner;
  bool get isManager => role.code == 'manager';
  bool get isEmployee => role.code == 'employee';
  bool get isActive => status == 'active';
  bool get isDeactivated => status == 'deactivated';
  bool get isArchived => status == 'archived';
  int get passwordMinimum => isManager ? 10 : 8;
  String get login => isEmployee ? (username ?? '') : (email ?? '');

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    username: json['username'] as String?,
    role: TenantRole.fromJson(_jsonMap(json['role'])),
    status: json['status'] as String? ?? 'active',
    allBranches: json['allBranches'] == true,
    isProtectedOwner: json['isProtectedOwner'] == true,
    assignedBranches: _jsonList(
      json['assignedBranches'],
    ).map(TeamBranchAssignment.fromJson).toList(growable: false),
    mustChangePassword: json['mustChangePassword'] == true,
  );
}

class TeamPage {
  const TeamPage({
    required this.members,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  final List<TeamMember> members;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
}

class TeamMemberDraft {
  const TeamMemberDraft({
    this.name = '',
    this.email = '',
    this.username = '',
    this.roleId = 0,
    this.roleCode = 'employee',
    this.branchIds = const <int>[],
    this.temporaryPassword = '',
    this.temporaryPasswordConfirmation = '',
  });

  final String name;
  final String email;
  final String username;
  final int roleId;
  final String roleCode;
  final List<int> branchIds;
  final String temporaryPassword;
  final String temporaryPasswordConfirmation;

  bool get isManager => roleCode == 'manager';
  int get passwordMinimum => isManager ? 10 : 8;

  TeamMemberDraft copyWith({
    String? name,
    String? email,
    String? username,
    int? roleId,
    String? roleCode,
    List<int>? branchIds,
    String? temporaryPassword,
    String? temporaryPasswordConfirmation,
  }) => TeamMemberDraft(
    name: name ?? this.name,
    email: email ?? this.email,
    username: username ?? this.username,
    roleId: roleId ?? this.roleId,
    roleCode: roleCode ?? this.roleCode,
    branchIds: branchIds ?? this.branchIds,
    temporaryPassword: temporaryPassword ?? this.temporaryPassword,
    temporaryPasswordConfirmation:
        temporaryPasswordConfirmation ?? this.temporaryPasswordConfirmation,
  );

  factory TeamMemberDraft.fromMember(TeamMember member) => TeamMemberDraft(
    name: member.name,
    email: member.email ?? '',
    username: member.username ?? '',
    roleId: member.role.id,
    roleCode: member.role.code,
    branchIds: member.assignedBranches
        .map((TeamBranchAssignment b) => b.id)
        .toList(),
  );

  Map<String, dynamic> toCreateJson() => <String, dynamic>{
    'name': name.trim(),
    'email': email.trim(),
    if (!isManager) 'username': username.trim(),
    'roleId': roleId,
    'branchIds': branchIds,
    'temporaryPassword': temporaryPassword,
    'temporaryPassword_confirmation': temporaryPasswordConfirmation,
  };

  Map<String, dynamic> toUpdateJson({required bool includePassword}) =>
      <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'username': isManager ? null : username.trim(),
        'roleId': roleId,
        'branchIds': branchIds,
        if (includePassword) ...<String, dynamic>{
          'temporaryPassword': temporaryPassword,
          'temporaryPassword_confirmation': temporaryPasswordConfirmation,
        },
      };
}

class CafeTax {
  const CafeTax(this.rate);
  final double rate;
  double get percentage => rate * 100;
  factory CafeTax.fromJson(Map<String, dynamic> json) =>
      CafeTax((json['taxRate'] as num?)?.toDouble() ?? 0);
}

Map<String, dynamic> _jsonMap(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : <String, dynamic>{};

List<Map<String, dynamic>> _jsonList(dynamic value) => value is List
    ? value.map(_jsonMap).toList(growable: false)
    : const <Map<String, dynamic>>[];
