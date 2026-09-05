import '../../../core/network/dio_api_client.dart';
import '../models/cafe_configuration_models.dart';

abstract interface class CafeConfigurationRepository {
  Future<CafeProfile> getProfile();
  Future<CafeProfile> updateProfile(CafeProfileDraft draft);
  Future<List<CafeConfigurationBranch>> getBranches();
  Future<CafeConfigurationBranch> getBranch(int id);
  Future<CafeConfigurationBranch> createBranch(BranchDraft draft);
  Future<CafeConfigurationBranch> updateBranch(int id, BranchDraft draft);
  Future<List<TenantRole>> getRoles();
  Future<TeamPage> getEmployees({
    int page = 1,
    int perPage = 20,
    String? search,
    String? role,
    String? status,
    int? branchId,
  });
  Future<TeamMember> getEmployee(int id);
  Future<TeamMember> createEmployee(TeamMemberDraft draft);
  Future<TeamMember> updateEmployee(
    int id,
    TeamMemberDraft draft, {
    required bool includePassword,
  });
  Future<TeamMember> activateEmployee(int id);
  Future<TeamMember> deactivateEmployee(int id);
  Future<TeamMember> archiveEmployee(int id);
  Future<TeamMember> resetEmployeePassword(int id, String password);
  Future<CafeTax> getTax();
  Future<CafeTax> updateTax(double rate);
}

class ApiCafeConfigurationRepository implements CafeConfigurationRepository {
  ApiCafeConfigurationRepository(this._apiClient);
  final DioApiClient _apiClient;

  @override
  Future<CafeProfile> getProfile() async => CafeProfile.fromJson(
    _map(await _apiClient.get('cafe-configuration/profile')),
  );

  @override
  Future<CafeProfile> updateProfile(CafeProfileDraft draft) async =>
      CafeProfile.fromJson(
        _map(
          await _apiClient.put(
            'cafe-configuration/profile',
            data: draft.toJson(),
          ),
        ),
      );

  @override
  Future<List<CafeConfigurationBranch>> getBranches() async {
    final dynamic response = await _apiClient.get(
      'cafe-configuration/branches',
    );
    final List<dynamic> rows = response is List ? response : const <dynamic>[];
    return rows
        .map((dynamic row) => CafeConfigurationBranch.fromJson(_map(row)))
        .toList(growable: false);
  }

  @override
  Future<CafeConfigurationBranch> getBranch(int id) async =>
      CafeConfigurationBranch.fromJson(
        _map(await _apiClient.get('cafe-configuration/branches/$id')),
      );

  @override
  Future<CafeConfigurationBranch> createBranch(BranchDraft draft) async =>
      CafeConfigurationBranch.fromJson(
        _map(
          await _apiClient.post(
            'cafe-configuration/branches',
            data: draft.toJson(),
          ),
        ),
      );

  @override
  Future<CafeConfigurationBranch> updateBranch(
    int id,
    BranchDraft draft,
  ) async => CafeConfigurationBranch.fromJson(
    _map(
      await _apiClient.put(
        'cafe-configuration/branches/$id',
        data: draft.toJson(),
      ),
    ),
  );

  @override
  Future<List<TenantRole>> getRoles() async {
    final dynamic response = await _apiClient.get('roles');
    final List<dynamic> rows = response is List ? response : const <dynamic>[];
    return rows
        .map((dynamic row) => TenantRole.fromJson(_map(row)))
        .toList(growable: false);
  }

  @override
  Future<TeamPage> getEmployees({
    int page = 1,
    int perPage = 20,
    String? search,
    String? role,
    String? status,
    int? branchId,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (role != null && role.isNotEmpty) 'role': role,
      if (status != null && status.isNotEmpty) 'status': status,
      'branchId': branchId,
    };
    final Map<String, dynamic> envelope = _map(
      await _apiClient.getEnvelope('employees', queryParameters: query),
    );
    final List<dynamic> rows = envelope['data'] is List
        ? envelope['data'] as List<dynamic>
        : const <dynamic>[];
    final Map<String, dynamic> meta = _map(envelope['meta']);
    return TeamPage(
      members: rows
          .map((dynamic row) => TeamMember.fromJson(_map(row)))
          .toList(growable: false),
      currentPage: (meta['currentPage'] as num?)?.toInt() ?? page,
      lastPage: (meta['lastPage'] as num?)?.toInt() ?? 1,
      perPage: (meta['perPage'] as num?)?.toInt() ?? perPage,
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  @override
  Future<TeamMember> getEmployee(int id) async =>
      TeamMember.fromJson(_map(await _apiClient.get('employees/$id')));

  @override
  Future<TeamMember> createEmployee(TeamMemberDraft draft) async =>
      TeamMember.fromJson(
        _map(await _apiClient.post('employees', data: draft.toCreateJson())),
      );

  @override
  Future<TeamMember> updateEmployee(
    int id,
    TeamMemberDraft draft, {
    required bool includePassword,
  }) async => TeamMember.fromJson(
    _map(
      await _apiClient.put(
        'employees/$id',
        data: draft.toUpdateJson(includePassword: includePassword),
      ),
    ),
  );

  @override
  Future<TeamMember> activateEmployee(int id) async => TeamMember.fromJson(
    _map(await _apiClient.post('employees/$id/activate')),
  );

  @override
  Future<TeamMember> deactivateEmployee(int id) async => TeamMember.fromJson(
    _map(await _apiClient.post('employees/$id/deactivate')),
  );

  @override
  Future<TeamMember> archiveEmployee(int id) async =>
      TeamMember.fromJson(_map(await _apiClient.post('employees/$id/archive')));

  @override
  Future<TeamMember> resetEmployeePassword(int id, String password) async =>
      TeamMember.fromJson(
        _map(
          await _apiClient.post(
            'employees/$id/reset-password',
            data: <String, dynamic>{
              'temporaryPassword': password,
              'temporaryPassword_confirmation': password,
            },
          ),
        ),
      );

  @override
  Future<CafeTax> getTax() async =>
      CafeTax.fromJson(_map(await _apiClient.get('cafe-configuration/tax')));

  @override
  Future<CafeTax> updateTax(double rate) async => CafeTax.fromJson(
    _map(
      await _apiClient.put(
        'cafe-configuration/tax',
        data: <String, dynamic>{'taxRate': rate},
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.cast<String, dynamic>()
    : <String, dynamic>{};
