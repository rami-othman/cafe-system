import '../../../core/network/dio_api_client.dart';
import '../../pos/models/branch.dart';
import '../../pos/models/json_helpers.dart';

class OperationalBranchRepository {
  const OperationalBranchRepository({this.apiClient});

  final DioApiClient? apiClient;

  Future<List<Branch>> getActiveBranches() async {
    if (apiClient == null) {
      return const <Branch>[
        Branch(
          id: 1,
          name: 'Downtown',
          currency: 'SYP',
          timezone: 'Asia/Damascus',
          isActive: true,
        ),
      ];
    }

    return readMapList(await apiClient!.get('branches'))
        .map(Branch.fromJson)
        .where((Branch branch) => branch.isActive)
        .toList(growable: false);
  }
}
