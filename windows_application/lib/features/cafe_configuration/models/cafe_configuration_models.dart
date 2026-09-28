import '../../printer/models/printer_config.dart';

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
    this.posInventoryWarehouseId,
    this.branchType = 'cafe',
    this.posCashFinancialLocationId,
    this.shiftCloseDestinationFinancialLocationId,
    this.cashVarianceAccountId,
    this.shiftClosingFloatAmount = '0.00',
    this.shiftCloseTime,
    this.availableShiftCloseDestinations = const <BranchCashLocationOption>[],
    this.availablePosCashLocations = const <BranchCashLocationOption>[],
    this.effectivePosInventoryWarehouseId,
    this.posInventoryWarehouseSource = 'not_configured',
    this.availablePosWarehouses = const <BranchWarehouseOption>[],
    this.printerConfig = const PrinterConfig(),
    this.autoPrintAfterPayment = false,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String timezone;
  final String currency;
  final bool isActive;
  final int? posInventoryWarehouseId;
  final String branchType;
  final int? posCashFinancialLocationId;
  final int? shiftCloseDestinationFinancialLocationId;
  final int? cashVarianceAccountId;
  final String shiftClosingFloatAmount;
  final String? shiftCloseTime;
  final List<BranchCashLocationOption> availableShiftCloseDestinations;
  final List<BranchCashLocationOption> availablePosCashLocations;
  final int? effectivePosInventoryWarehouseId;
  final String posInventoryWarehouseSource;
  final List<BranchWarehouseOption> availablePosWarehouses;
  final PrinterConfig printerConfig;
  final bool autoPrintAfterPayment;

  factory CafeConfigurationBranch.fromJson(
    Map<String, dynamic> json,
  ) => CafeConfigurationBranch(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    timezone: json['timezone'] as String? ?? 'UTC',
    currency: json['currency'] as String? ?? '',
    isActive: json['isActive'] == true,
    posInventoryWarehouseId: ((json['branchType'] == 'factory' ? json['defaultWarehouseId'] : json['posInventoryWarehouseId']) as num?)?.toInt(),
    branchType: json['branchType'] as String? ?? 'cafe',
    posCashFinancialLocationId: (json['posCashFinancialLocationId'] as num?)
        ?.toInt(),
    shiftCloseDestinationFinancialLocationId:
        (json['shiftCloseDestinationFinancialLocationId'] as num?)?.toInt(),
    cashVarianceAccountId: (json['cashVarianceAccountId'] as num?)?.toInt(),
    shiftClosingFloatAmount:
        json['shiftClosingFloatAmount']?.toString() ?? '0.00',
    shiftCloseTime: json['shiftCloseTime'] as String?,
    availableShiftCloseDestinations:
        (json['availableShiftCloseDestinations'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (row) => BranchCashLocationOption.fromJson(
                row.cast<String, dynamic>(),
              ),
            )
            .toList(growable: false),
    availablePosCashLocations:
        (json['availablePosCashLocations'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (row) => BranchCashLocationOption.fromJson(
                row.cast<String, dynamic>(),
              ),
            )
            .toList(growable: false),
    effectivePosInventoryWarehouseId:
        (json['effectivePosInventoryWarehouseId'] as num?)?.toInt(),
    posInventoryWarehouseSource:
        json['posInventoryWarehouseSource'] as String? ?? 'not_configured',
    availablePosWarehouses:
        (json['availablePosWarehouses'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (row) =>
                  BranchWarehouseOption.fromJson(row.cast<String, dynamic>()),
            )
            .toList(growable: false),
    printerConfig: PrinterConfig(
      name: json['defaultPrinterName'] as String? ?? '',
      ipAddress: json['defaultPrinterIp'] as String? ?? '',
      port: (json['defaultPrinterPort'] as num?)?.toInt() ?? 9100,
      paperWidth: PrinterPaperWidth.fromApiValue(json['defaultPaperWidth']),
      enabled: json['receiptPrintingEnabled'] == true,
    ),
    autoPrintAfterPayment: json['autoPrintAfterPayment'] == true,
  );
}

class BranchCashLocationOption {
  const BranchCashLocationOption({required this.id, required this.name});
  final int id;
  final String name;
  factory BranchCashLocationOption.fromJson(Map<String, dynamic> json) =>
      BranchCashLocationOption(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );
}

class BranchFinancialAccountOption {
  const BranchFinancialAccountOption({
    required this.id,
    required this.code,
    required this.nameAr,
  });
  final int id;
  final String code;
  final String nameAr;
  String get label => '$code — $nameAr';
  factory BranchFinancialAccountOption.fromJson(Map<String, dynamic> json) =>
      BranchFinancialAccountOption(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String? ?? '',
        nameAr: json['nameAr'] as String? ?? '',
      );
}

class BranchWarehouseOption {
  const BranchWarehouseOption({
    required this.id,
    required this.name,
    required this.type,
  });
  final int id;
  final String name;
  final String type;
  factory BranchWarehouseOption.fromJson(Map<String, dynamic> json) =>
      BranchWarehouseOption(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
      );
}

class BranchDraft {
  const BranchDraft({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.timezone = 'UTC',
    this.warehouseName = '',
    this.branchType = 'cafe',
    this.posInventoryWarehouseId,
    this.posCashFinancialLocationId,
    this.shiftCloseDestinationFinancialLocationId,
    this.cashVarianceAccountId,
    this.shiftClosingFloatAmount = '0.00',
    this.shiftCloseTime,
    this.printerConfig = const PrinterConfig(),
    this.autoPrintAfterPayment = false,
  });

  final String name;
  final String address;
  final String phone;
  final String timezone;
  // Only used when creating a new branch: the branch cannot operate without
  // a place to hold stock, so its one warehouse is named right here — there
  // is no separate "main"/"primary" warehouse concept to configure later.
  final String warehouseName;
  final String branchType;
  final int? posInventoryWarehouseId;
  final int? posCashFinancialLocationId;
  final int? shiftCloseDestinationFinancialLocationId;
  final int? cashVarianceAccountId;
  final String shiftClosingFloatAmount;
  final String? shiftCloseTime;
  final PrinterConfig printerConfig;
  final bool autoPrintAfterPayment;

  factory BranchDraft.fromBranch(CafeConfigurationBranch branch) => BranchDraft(
    name: branch.name,
    branchType: branch.branchType,
    address: branch.address ?? '',
    phone: branch.phone ?? '',
    timezone: branch.timezone,
    posInventoryWarehouseId: branch.posInventoryWarehouseId,
    posCashFinancialLocationId: branch.posCashFinancialLocationId,
    shiftCloseDestinationFinancialLocationId:
        branch.shiftCloseDestinationFinancialLocationId,
    cashVarianceAccountId: branch.cashVarianceAccountId,
    shiftClosingFloatAmount: branch.shiftClosingFloatAmount,
    shiftCloseTime: branch.shiftCloseTime,
    printerConfig: branch.printerConfig,
    autoPrintAfterPayment: branch.autoPrintAfterPayment,
  );

  BranchDraft copyWith({
    String? name,
    String? address,
    String? phone,
    String? timezone,
    String? warehouseName,
    String? branchType,
    int? posInventoryWarehouseId,
    int? posCashFinancialLocationId,
    int? shiftCloseDestinationFinancialLocationId,
    int? cashVarianceAccountId,
    String? shiftClosingFloatAmount,
    String? shiftCloseTime,
    PrinterConfig? printerConfig,
    bool? autoPrintAfterPayment,
    bool clearPosInventoryWarehouseId = false,
    bool clearCashVarianceAccountId = false,
  }) => BranchDraft(
    name: name ?? this.name,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    timezone: timezone ?? this.timezone,
    warehouseName: warehouseName ?? this.warehouseName,
    branchType: branchType ?? this.branchType,
    posInventoryWarehouseId: clearPosInventoryWarehouseId
        ? null
        : posInventoryWarehouseId ?? this.posInventoryWarehouseId,
    posCashFinancialLocationId:
        posCashFinancialLocationId ?? this.posCashFinancialLocationId,
    shiftCloseDestinationFinancialLocationId:
        shiftCloseDestinationFinancialLocationId ??
        this.shiftCloseDestinationFinancialLocationId,
    cashVarianceAccountId: clearCashVarianceAccountId
        ? null
        : cashVarianceAccountId ?? this.cashVarianceAccountId,
    shiftClosingFloatAmount:
        shiftClosingFloatAmount ?? this.shiftClosingFloatAmount,
    shiftCloseTime: shiftCloseTime ?? this.shiftCloseTime,
    printerConfig: printerConfig ?? this.printerConfig,
    autoPrintAfterPayment: autoPrintAfterPayment ?? this.autoPrintAfterPayment,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'address': address.trim().isEmpty ? null : address.trim(),
    'phone': phone.trim().isEmpty ? null : phone.trim(),
    'timezone': timezone,
    if (warehouseName.trim().isNotEmpty) 'warehouseName': warehouseName.trim(),
    'branchType': branchType,
    'posInventoryWarehouseId': posInventoryWarehouseId,
    if (posCashFinancialLocationId != null)
      'posCashFinancialLocationId': posCashFinancialLocationId,
    'shiftCloseDestinationFinancialLocationId':
        shiftCloseDestinationFinancialLocationId,
    'cashVarianceAccountId': cashVarianceAccountId,
    'shiftClosingFloatAmount': shiftClosingFloatAmount,
    'shiftCloseTime': shiftCloseTime?.trim().isEmpty == true
        ? null
        : shiftCloseTime,
    'receiptPrintingEnabled': printerConfig.enabled,
    'defaultPaperWidth': printerConfig.paperWidth.apiValue,
    'autoPrintAfterPayment': autoPrintAfterPayment,
    'defaultPrinterName': printerConfig.name.trim().isEmpty
        ? null
        : printerConfig.name.trim(),
    'defaultPrinterIp': printerConfig.ipAddress.trim().isEmpty
        ? null
        : printerConfig.ipAddress.trim(),
    'defaultPrinterPort': printerConfig.port,
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
  // factory_manager shares manager's email-login identity and 10-char
  // password minimum (see DefaultTenantRoleService/TenantEmployeeService on
  // the backend); the name stays isManager since every caller here means
  // "this role logs in by email, not username".
  bool get isManager => role.code == 'manager' || role.code == 'factory_manager';
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

  bool get isManager => roleCode == 'manager' || roleCode == 'factory_manager';
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
