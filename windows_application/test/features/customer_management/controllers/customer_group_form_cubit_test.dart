import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_form_cubit.dart';
import 'package:windows_application/features/customer_management/controllers/customer_group_form_state.dart';
import 'package:windows_application/features/customer_management/models/customer_drafts.dart';
import 'package:windows_application/features/customer_management/models/customer_group_models.dart';
import 'package:windows_application/features/customer_management/repositories/customer_management_repository.dart';
import 'package:windows_application/features/customer_management/models/customer_models.dart';

void main() {
  test(
    'validates name, saves only name, and retains draft on failure',
    () async {
      final _FormRepository repository = _FormRepository(
        error: StateError('offline'),
      );
      final CustomerGroupFormCubit cubit = CustomerGroupFormCubit(repository);
      cubit.initializeCreate();
      cubit.setName(' VIP ');

      await cubit.submit();

      expect(repository.drafts.single.toJson(), <String, dynamic>{
        'name': 'VIP',
      });
      expect(cubit.state.status, CustomerGroupFormStatus.failure);
      expect(cubit.state.draft.name, ' VIP ');
      await cubit.close();
    },
  );

  test(
    'successful create exposes the authoritative group for detail navigation',
    () async {
      final _FormRepository repository = _FormRepository();
      final CustomerGroupFormCubit cubit = CustomerGroupFormCubit(repository);
      cubit.initializeCreate();
      cubit.setName('VIP');

      await cubit.submit();

      expect(cubit.state.status, CustomerGroupFormStatus.success);
      expect(cubit.state.savedGroup?.id, 8);
      await cubit.close();
    },
  );
}

class _FormRepository implements CustomerManagementRepository {
  _FormRepository({this.error});
  final Object? error;
  final List<GroupDraft> drafts = <GroupDraft>[];

  @override
  Future<CustomerGroup> createGroup(GroupDraft draft) {
    drafts.add(draft);
    if (error != null) return Future<CustomerGroup>.error(error!);
    return Future<CustomerGroup>.value(
      const CustomerGroup(
        id: 8,
        name: 'VIP',
        lifecycle: CustomerLifecycle.active,
        memberCount: 0,
      ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
