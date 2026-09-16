import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../pos/controllers/pos_cubit.dart';
import '../../pos/controllers/pos_state.dart';
import '../controllers/shift_close_cubit.dart';
import '../controllers/shift_close_state.dart';
import 'bar_check_screen.dart';

/// Minimal shift-close screen: enter closing cash and close the shift. When
/// the branch has an active required bar check, this screen routes to the
/// dedicated Bar Check flow first and then finishes the close automatically
/// on return — the cashier never has to enter the full Inventory Center.
class ShiftCloseScreen extends StatefulWidget {
  const ShiftCloseScreen({super.key});

  @override
  State<ShiftCloseScreen> createState() => _ShiftCloseScreenState();
}

class _ShiftCloseScreenState extends State<ShiftCloseScreen> {
  final TextEditingController _closingCashController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _closingCashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PosState posState = context.watch<PosCubit>().state;
    final int? shiftId = posState.shiftId;
    final int branchId = posState.branchId;

    return BlocConsumer<ShiftCloseCubit, ShiftCloseState>(
      listener: (BuildContext context, ShiftCloseState state) {
        if (state.requiredBarCheckWarehouseId != null && shiftId != null) {
          final int warehouseId = state.requiredBarCheckWarehouseId!;
          context.read<ShiftCloseCubit>().acknowledgeBarCheckRoute();
          _routeToBarCheck(context, shiftId: shiftId, warehouseId: warehouseId);
        } else if (state.status == ShiftCloseStatus.closed) {
          context.read<PosCubit>().refreshShift();
          if (context.canPop()) context.pop();
        }
      },
      builder: (BuildContext context, ShiftCloseState state) {
        return DesktopPageLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.shiftCloseTitle,
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.shiftCloseSubtitle,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.panel,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.shiftCloseClosingCashLabel,
                        style: AppTextStyles.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        key: const Key('shift-close-closing-cash-field'),
                        controller: _closingCashController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        context.l10n.shiftCloseNoteLabel,
                        style: AppTextStyles.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        key: const Key('shift-close-note-field'),
                        controller: _noteController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (state.errorMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          state.errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.dangerStrong,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(
                        key: const Key('shift-close-submit-button'),
                        label: context.l10n.shiftCloseSubmit,
                        isExpanded: true,
                        onPressed: shiftId == null || state.isSubmitting
                            ? null
                            : () => context.read<ShiftCloseCubit>().closeShift(
                                shiftId: shiftId,
                                branchId: branchId,
                                closingCash:
                                    double.tryParse(
                                      _closingCashController.text.trim(),
                                    ) ??
                                    0,
                                note: _noteController.text,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _routeToBarCheck(
    BuildContext context, {
    required int shiftId,
    required int warehouseId,
  }) async {
    final bool? posted = await context.push<bool>(
      BarCheckScreen.routePath,
      extra: BarCheckScreenArgs(shiftId: shiftId, warehouseId: warehouseId),
    );
    if (posted == true && context.mounted) {
      final ShiftCloseCubit cubit = context.read<ShiftCloseCubit>();
      final PosState pos = context.read<PosCubit>().state;
      if (pos.shiftId != null) {
        await cubit.closeShift(
          shiftId: pos.shiftId!,
          branchId: pos.branchId,
          closingCash:
              double.tryParse(_closingCashController.text.trim()) ?? 0,
          note: _noteController.text,
        );
      }
    }
  }
}
