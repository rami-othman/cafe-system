import '../../pos/models/branch.dart';
import 'operational_branch_repository.dart';

/// Explicit deterministic source for widget tests and offline test harnesses.
/// It is never registered for a runtime backend configuration.
class FakeOperationalBranchRepository implements OperationalBranchReader {
  const FakeOperationalBranchRepository({
    this.branches = const <Branch>[
      Branch(
        id: 1,
        name: 'Downtown',
        currency: 'SYP',
        timezone: 'Asia/Damascus',
        isActive: true,
      ),
    ],
  });

  final List<Branch> branches;

  @override
  Future<List<Branch>> getActiveBranches() async => branches;
}
