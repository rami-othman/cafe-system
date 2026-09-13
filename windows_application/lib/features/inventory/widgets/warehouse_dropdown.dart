import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../finance_inventory_setup/models/finance_setup_models.dart';
import '../../operational_context/controllers/operational_branch_cubit.dart';
import '../../operational_context/models/operational_branch_state.dart';

int? activeInventoryBranchId(BuildContext context) =>
    context.read<OperationalBranchCubit>().state.selectedBranchId;

/// Warehouses belonging to the currently active branch (the top-level
/// [OperationalBranchCubit] selection), excluding inactive/legacy ones. This
/// is the single rule for "which warehouses can this screen offer" - every
/// warehouse dropdown in the Inventory module goes through it so a warehouse
/// from a different branch never appears as, or silently stays, selected.
List<WarehouseLocation> branchWarehouses(
  BuildContext context,
  List<WarehouseLocation> warehouses,
) {
  final int? branchId = activeInventoryBranchId(context);

  return warehouses
      .where(
        (WarehouseLocation warehouse) =>
            !warehouse.isLegacy &&
            warehouse.isActive &&
            (warehouse.branchId == null || warehouse.branchId == branchId),
      )
      .toList(growable: false);
}

/// A warehouse selector scoped to the active branch. The selected value is
/// always the warehouse's [WarehouseLocation.id] - never its display name or
/// the object itself - and a previously selected id that has fallen out of
/// the active branch's scope (e.g. after a top-level branch change) is
/// displayed as "all warehouses" instead of tripping Flutter's DropdownButton
/// assertion or silently keeping a stale id that no longer matches what's
/// shown on screen.
///
/// This widget only controls what is *displayed*. The caller's own
/// warehouse-id state is the source of truth sent to the API; pair this with
/// [BranchChangeReload] so that a stale id is actually reset (not just
/// hidden) when the active branch changes.
class WarehouseDropdown extends StatelessWidget {
  const WarehouseDropdown({
    super.key,
    required this.value,
    required this.warehouses,
    required this.onChanged,
    this.allLabel = 'كل مخازن الفرع',
    this.width = 220,
  });

  final int? value;
  final List<WarehouseLocation> warehouses;
  final ValueChanged<int?> onChanged;
  final String allLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the active branch changes so `visible` (and, if the
    // previously selected warehouse fell out of scope, `selectedValue`) is
    // recomputed immediately rather than on this dropdown's next unrelated
    // rebuild.
    context.watch<OperationalBranchCubit>();
    final List<WarehouseLocation> visible = branchWarehouses(
      context,
      warehouses,
    );
    final int? selectedValue =
        visible.any((WarehouseLocation warehouse) => warehouse.id == value)
        ? value
        : null;

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<int?>(
        key: ValueKey<int?>(selectedValue),
        initialValue: selectedValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'المخزن',
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
        ),
        items: <DropdownMenuItem<int?>>[
          DropdownMenuItem<int?>(value: null, child: Text(allLabel)),
          ...visible.map(
            (WarehouseLocation warehouse) => DropdownMenuItem<int?>(
              value: warehouse.id,
              child: Text(
                warehouse.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Calls [onBranchChanged] whenever the top-level active branch changes.
/// Wrap a screen's build output in this so a warehouse selected under one
/// branch is actually reset (and its data reloaded) rather than just hidden
/// by [WarehouseDropdown] the next time the active branch changes - without
/// every screen re-deriving its own [BlocListener] for this.
class BranchChangeReload extends StatelessWidget {
  const BranchChangeReload({
    super.key,
    required this.onBranchChanged,
    required this.child,
  });

  final VoidCallback onBranchChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<OperationalBranchCubit, OperationalBranchState>(
        listenWhen:
            (OperationalBranchState previous, OperationalBranchState current) =>
                previous.selectedBranchId != current.selectedBranchId,
        listener: (BuildContext context, OperationalBranchState state) =>
            onBranchChanged(),
        child: child,
      );
}
