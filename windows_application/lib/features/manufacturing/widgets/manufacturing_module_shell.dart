import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/dio_api_client.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/controllers/auth_session_cubit.dart';
import '../../operational_context/controllers/operational_branch_cubit.dart';
import '../../operational_context/models/operational_branch_state.dart';
import 'manufacturing_navigation_bar.dart';

/// Shared Manufacturing frame, mirroring [InventoryModuleShell]'s fixed
/// navigation bar above a scrollable page body — except the operational
/// branch here is resolved independently of [PosCubit] (Phase 2): this shell
/// never reads or writes it, and never listens to it. On mount it asks
/// [OperationalBranchCubit] for a factory branch (see [ensureFactoryBranch]);
/// until one resolves, or if none exists at all, it renders an explanatory
/// empty state instead of the navigation bar and page body.
class ManufacturingModuleShell extends StatefulWidget {
  const ManufacturingModuleShell({
    super.key,
    required this.selectedTab,
    required this.child,
  });

  final String selectedTab;
  final Widget child;

  @override
  State<ManufacturingModuleShell> createState() =>
      _ManufacturingModuleShellState();
}

class _ManufacturingModuleShellState extends State<ManufacturingModuleShell> {
  @override
  void initState() {
    super.initState();
    _ensureFactoryBranch();
  }

  void _ensureFactoryBranch() {
    final List<int>? preferredIds = context
        .read<AuthSessionCubit>()
        .state
        .session
        ?.user
        .factoryBranchIds;
    context.read<OperationalBranchCubit>().ensureFactoryBranch(
      preferredIds: preferredIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final OperationalBranchState branchState = context
        .watch<OperationalBranchCubit>()
        .state;
    final bool hasFactoryBranch = branchState.branches.any(
      (branch) => branch.isFactory && branch.id == branchState.selectedBranchId,
    );
    if (serviceLocator.isRegistered<DioApiClient>()) {
      serviceLocator<DioApiClient>().scopeBranchId = hasFactoryBranch ? branchState.selectedBranchId : null;
    }

    if (!hasFactoryBranch) {
      if (branchState.isLoading) {
        return const ColoredBox(
          color: AppColors.contentBackground,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final bool isOwner =
          context.read<AuthSessionCubit>().state.session?.user.role ==
          'owner';
      return ColoredBox(
        color: AppColors.contentBackground,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              isOwner
                  ? 'لا يوجد معمل. أنشئ فرعاً من نوع معمل من إعدادات المقهى.'
                  : 'لا يوجد معمل مرتبط بحسابك.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.contentBackground,
      child: Column(
        children: <Widget>[
          ManufacturingNavigationBar(selected: widget.selectedTab),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
