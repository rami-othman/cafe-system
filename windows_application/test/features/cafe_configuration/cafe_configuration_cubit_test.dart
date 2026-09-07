import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/cafe_configuration/controllers/cafe_configuration_cubits.dart';
import 'package:windows_application/features/cafe_configuration/controllers/tax_cubit.dart';
import 'package:windows_application/features/cafe_configuration/models/cafe_configuration_models.dart';
import 'package:windows_application/features/cafe_configuration/repositories/cafe_configuration_repository.dart';
import 'package:windows_application/features/cafe_configuration/widgets/cafe_configuration_navigation.dart';

void main() {
  group('Cafe Configuration navigation', () {
    test('selects Overview and Cafe Profile from their routes', () {
      expect(
        CafeConfigurationDestination.forPath('/cafe-configuration/overview'),
        CafeConfigurationDestination.overview,
      );
      expect(
        CafeConfigurationDestination.forPath('/cafe-configuration/profile'),
        CafeConfigurationDestination.profile,
      );
    });

    test('keeps Branches selected for nested create and edit routes', () {
      expect(
        CafeConfigurationDestination.forPath(
          '/cafe-configuration/branches/new',
        ),
        CafeConfigurationDestination.branches,
      );
      expect(
        CafeConfigurationDestination.forPath(
          '/cafe-configuration/branches/7/edit',
        ),
        CafeConfigurationDestination.branches,
      );
    });

    test('selects Team & Access and Tax from their routes', () {
      expect(
        CafeConfigurationDestination.forPath('/cafe-configuration/team'),
        CafeConfigurationDestination.team,
      );
      expect(
        CafeConfigurationDestination.forPath('/cafe-configuration/tax'),
        CafeConfigurationDestination.tax,
      );
    });
  });

  group('CafeProfileCubit', () {
    test('loads profile and detects dirty changes', () async {
      final _FakeRepository repository = _FakeRepository();
      final CafeProfileCubit cubit = CafeProfileCubit(repository);

      await cubit.load();
      cubit.update(cubit.state.draft.copyWith(name: 'Changed Cafe'));

      expect(cubit.state.profile!.name, 'Cafe 618');
      expect(cubit.state.isDirty, isTrue);
    });

    test('resets to the latest loaded values', () async {
      final CafeProfileCubit cubit = CafeProfileCubit(_FakeRepository());
      await cubit.load();
      cubit.update(cubit.state.draft.copyWith(phone: '123'));
      cubit.reset();

      expect(cubit.state.draft.phone, '+963 11 123 4567');
      expect(cubit.state.isDirty, isFalse);
    });

    test('does not duplicate an in-flight save', () async {
      final _FakeRepository repository = _FakeRepository(blockUpdate: true);
      final CafeProfileCubit cubit = CafeProfileCubit(repository);
      await cubit.load();
      cubit.update(cubit.state.draft.copyWith(name: 'Changed Cafe'));

      final Future<void> first = cubit.save();
      final Future<void> second = cubit.save();
      await Future<void>.delayed(Duration.zero);
      repository.completeUpdate();
      await Future.wait(<Future<void>>[first, second]);

      expect(repository.profileUpdates, 1);
    });
  });

  group('BranchEditorCubit', () {
    test('uses the cafe profile timezone for a new branch', () async {
      final BranchEditorCubit cubit = BranchEditorCubit(_FakeRepository());

      await cubit.initialize();

      expect(cubit.state.draft.timezone, 'Asia/Damascus');
    });

    test('requires a branch name before create', () async {
      final BranchEditorCubit cubit = BranchEditorCubit(_FakeRepository());
      await cubit.initialize();
      await cubit.save();

      expect(cubit.state.errors['name'], 'required');
    });

    test('loads branch status without lifecycle actions', () async {
      final BranchEditorCubit cubit = BranchEditorCubit(
        _FakeRepository(),
        branchId: 4,
      );
      await cubit.initialize();

      expect(cubit.state.branch!.isActive, isFalse);
      expect(cubit.state.branch!.currency, 'SYP');
    });
  });

  group('TaxCubit', () {
    test('converts API fractional tax to an editable percentage', () async {
      final TaxCubit cubit = TaxCubit(_FakeRepository());
      await cubit.load();

      expect(cubit.state.draftPercentage, '8.00');
      cubit.update('10');
      expect(cubit.state.isDirty, isTrue);
    });

    test('accepts the inclusive UI boundary values 0 and 100', () async {
      final _FakeRepository repository = _FakeRepository();
      final TaxCubit cubit = TaxCubit(repository);
      await cubit.load();
      cubit.update('0');
      expect(await cubit.save(), isTrue);
      cubit.update('100');
      expect(await cubit.save(), isTrue);
    });
  });

  group('TeamCubit', () {
    test('defaults employee drafts to the employee password rule', () {
      const TeamMemberDraft draft = TeamMemberDraft();
      expect(draft.passwordMinimum, 8);
      expect(draft.copyWith(roleCode: 'manager').passwordMinimum, 10);
    });
  });
}

class _FakeRepository implements CafeConfigurationRepository {
  _FakeRepository({this.blockUpdate = false});
  final bool blockUpdate;
  final Completer<void> _updateGate = Completer<void>();
  int profileUpdates = 0;

  CafeProfile get _profile => const CafeProfile(
    name: 'Cafe 618',
    email: 'owner@example.test',
    phone: '+963 11 123 4567',
    timezone: 'Asia/Damascus',
    currency: 'SYP',
    status: 'active',
  );

  void completeUpdate() {
    if (!_updateGate.isCompleted) _updateGate.complete();
  }

  @override
  Future<CafeProfile> getProfile() async => _profile;
  @override
  Future<CafeProfile> updateProfile(CafeProfileDraft draft) async {
    profileUpdates++;
    if (blockUpdate) await _updateGate.future;
    return CafeProfile(
      name: draft.name,
      email: draft.email,
      phone: draft.phone,
      timezone: draft.timezone,
      currency: 'SYP',
      status: 'active',
    );
  }

  @override
  Future<List<CafeConfigurationBranch>> getBranches() async =>
      const <CafeConfigurationBranch>[];
  @override
  Future<CafeConfigurationBranch> getBranch(int id) async =>
      const CafeConfigurationBranch(
        id: 4,
        name: 'Inactive',
        address: null,
        phone: null,
        timezone: 'Asia/Damascus',
        currency: 'SYP',
        isActive: false,
      );
  @override
  Future<CafeConfigurationBranch> createBranch(BranchDraft draft) async =>
      const CafeConfigurationBranch(
        id: 5,
        name: 'New',
        address: null,
        phone: null,
        timezone: 'Asia/Damascus',
        currency: 'SYP',
        isActive: true,
      );
  @override
  Future<CafeConfigurationBranch> updateBranch(
    int id,
    BranchDraft draft,
  ) async => await getBranch(id);
  @override
  Future<List<TenantRole>> getRoles() async => const <TenantRole>[];
  @override
  Future<TeamPage> getEmployees({
    int page = 1,
    int perPage = 20,
    String? search,
    String? role,
    String? status,
    int? branchId,
  }) async => const TeamPage(
    members: <TeamMember>[],
    currentPage: 1,
    lastPage: 1,
    perPage: 20,
    total: 0,
  );
  @override
  Future<TeamMember> getEmployee(int id) => throw UnimplementedError();
  @override
  Future<TeamMember> createEmployee(TeamMemberDraft draft) =>
      throw UnimplementedError();
  @override
  Future<TeamMember> updateEmployee(
    int id,
    TeamMemberDraft draft, {
    required bool includePassword,
  }) => throw UnimplementedError();
  @override
  Future<TeamMember> activateEmployee(int id) => throw UnimplementedError();
  @override
  Future<TeamMember> deactivateEmployee(int id) => throw UnimplementedError();
  @override
  Future<TeamMember> archiveEmployee(int id) => throw UnimplementedError();
  @override
  Future<TeamMember> resetEmployeePassword(int id, String password) =>
      throw UnimplementedError();
  @override
  Future<CafeTax> getTax() async => const CafeTax(.08);
  @override
  Future<CafeTax> updateTax(double rate) async => CafeTax(rate);
}
