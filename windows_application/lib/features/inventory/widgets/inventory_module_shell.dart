import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../operational_context/controllers/operational_branch_cubit.dart';
import '../../pos/controllers/pos_cubit.dart';
import '../../pos/controllers/pos_state.dart';
import 'inventory_navigation_bar.dart';

/// Shared inventory frame. The navigation is outside the expanded page body,
/// which keeps it fixed while dashboards, tables, and forms scroll.
class InventoryModuleShell extends StatefulWidget {
  const InventoryModuleShell({
    super.key,
    required this.selectedTab,
    required this.child,
  });

  final String selectedTab;
  final Widget child;

  @override
  State<InventoryModuleShell> createState() => _InventoryModuleShellState();
}

class _InventoryModuleShellState extends State<InventoryModuleShell> {
  @override
  void initState() {
    super.initState();
    _loadAndSynchronizeBranch();
  }

  Future<void> _loadAndSynchronizeBranch() async {
    final OperationalBranchCubit operational =
        context.read<OperationalBranchCubit>();
    await operational.loadBranches(
      preferredBranchId: context.read<PosCubit>().state.branchId,
    );
    if (!mounted) return;
    operational.selectBranch(context.read<PosCubit>().state.branchId);
  }

  @override
  Widget build(BuildContext context) => BlocListener<PosCubit, PosState>(
    listenWhen: (PosState previous, PosState current) =>
        previous.branchId != current.branchId,
    listener: (BuildContext context, PosState state) {
      context.read<OperationalBranchCubit>().selectBranch(state.branchId);
    },
    child: ColoredBox(
      color: AppColors.contentBackground,
      child: Column(
        children: <Widget>[
          InventoryNavigationBar(selected: widget.selectedTab),
          Expanded(child: widget.child),
        ],
      ),
    ),
  );
}
