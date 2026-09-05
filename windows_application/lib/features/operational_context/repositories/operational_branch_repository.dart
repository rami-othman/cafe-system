import '../../../core/network/dio_api_client.dart';
import '../../pos/models/branch.dart';
import '../../pos/models/json_helpers.dart';

abstract interface class OperationalBranchReader {
  Future<List<Branch>> getActiveBranches();
}

/// Runtime source of operational branches. Branches are always API-owned.
class OperationalBranchRepository implements OperationalBranchReader {
  const OperationalBranchRepository({required this.apiClient});

  final DioApiClient apiClient;

  @override
  Future<List<Branch>> getActiveBranches() async {
    return readMapList(await apiClient.get('branches'))
        .map(Branch.fromJson)
        .where((Branch branch) => branch.isActive)
        .toList(growable: false);
  }
}
