import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/cafe_configuration_models.dart';
import '../repositories/cafe_configuration_repository.dart';
import 'cafe_configuration_cubits.dart';

class CafeConfigurationOverviewState extends Equatable {
  const CafeConfigurationOverviewState({
    this.status = CafeConfigurationLoadStatus.loading,
    this.profile,
    this.branches = const <CafeConfigurationBranch>[],
    this.activeTeamCount = 0,
    this.teamCount = 0,
    this.tax,
  });
  final CafeConfigurationLoadStatus status;
  final CafeProfile? profile;
  final List<CafeConfigurationBranch> branches;
  final int activeTeamCount;
  final int teamCount;
  final CafeTax? tax;
  @override
  List<Object?> get props => <Object?>[
    status,
    profile?.name,
    branches,
    activeTeamCount,
    teamCount,
    tax?.rate,
  ];
}

class CafeConfigurationOverviewCubit
    extends Cubit<CafeConfigurationOverviewState> {
  CafeConfigurationOverviewCubit(this._repository)
    : super(const CafeConfigurationOverviewState());
  final CafeConfigurationRepository _repository;
  Future<void> load() async {
    if (isClosed) return;
    emit(const CafeConfigurationOverviewState());
    try {
      final (
        CafeProfile,
        List<CafeConfigurationBranch>,
        TeamPage,
        TeamPage,
        CafeTax,
      )
      values = await (
        _repository.getProfile(),
        _repository.getBranches(),
        _repository.getEmployees(perPage: 1),
        _repository.getEmployees(perPage: 1, status: 'active'),
        _repository.getTax(),
      ).wait;
      if (isClosed) return;
      emit(
        CafeConfigurationOverviewState(
          status: CafeConfigurationLoadStatus.ready,
          profile: values.$1,
          branches: values.$2,
          teamCount: values.$3.total,
          activeTeamCount: values.$4.total,
          tax: values.$5,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        const CafeConfigurationOverviewState(
          status: CafeConfigurationLoadStatus.failure,
        ),
      );
    }
  }
}
