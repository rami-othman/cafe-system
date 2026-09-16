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
import '../controllers/bar_check_cubit.dart';
import '../controllers/bar_check_state.dart';
import '../models/bar_check_line.dart';

class BarCheckScreenArgs {
  const BarCheckScreenArgs({required this.shiftId, required this.warehouseId});

  final int shiftId;
  final int warehouseId;
}

/// Dedicated, minimal counting screen for the cashier's own required shift
/// bar check — reached only from the shift-close flow, never from a general
/// Inventory module. Shows just what is needed to perform the check: item,
/// expected/counted quantity, unit, and a submit action.
class BarCheckScreen extends StatefulWidget {
  const BarCheckScreen({super.key, required this.args});

  static const String routePath = '/shift-close/bar-check';
  static const String routeName = 'shift-close-bar-check';

  final BarCheckScreenArgs args;

  @override
  State<BarCheckScreen> createState() => _BarCheckScreenState();
}

class _BarCheckScreenState extends State<BarCheckScreen> {
  final Map<int, TextEditingController> _quantityControllers =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _reasonControllers =
      <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    context.read<BarCheckCubit>().start(
      shiftId: widget.args.shiftId,
      warehouseId: widget.args.warehouseId,
    );
  }

  @override
  void dispose() {
    for (final TextEditingController controller
        in _quantityControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _reasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BarCheckCubit, BarCheckState>(
      listener: (BuildContext context, BarCheckState state) {
        if (state.status == BarCheckStatus.posted && context.canPop()) {
          context.pop(true);
        }
      },
      builder: (BuildContext context, BarCheckState state) {
        return DesktopPageLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.barCheckTitle,
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.barCheckSubtitle,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (state.status == BarCheckStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.status == BarCheckStatus.error)
                Text(
                  state.errorMessage ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.dangerStrong,
                  ),
                )
              else
                Expanded(child: _buildLines(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLines(BuildContext context, BarCheckState state) {
    final List<BarCheckLine> lines = state.session?.lines ?? const <BarCheckLine>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (state.blockedOnManagerReview)
          Container(
            key: const Key('bar-check-manager-review-banner'),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: AppRadius.panel,
            ),
            child: Text(
              context.l10n.barCheckPendingManagerReview,
              style: AppTextStyles.bodySmall,
            ),
          ),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              state.errorMessage!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dangerStrong,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) =>
                _buildLine(context, lines[index]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('bar-check-submit-button'),
          label: context.l10n.barCheckSubmitAndClose,
          isExpanded: true,
          onPressed: state.isBusy || state.session == null
              ? null
              : () => context.read<BarCheckCubit>().submitAndFinish(),
        ),
      ],
    );
  }

  Widget _buildLine(BuildContext context, BarCheckLine line) {
    final TextEditingController quantityController = _quantityControllers
        .putIfAbsent(
          line.itemId,
          () => TextEditingController(
            text: line.isCounted ? line.countedQuantity : '',
          ),
        );
    final TextEditingController reasonController = _reasonControllers
        .putIfAbsent(line.itemId, TextEditingController.new);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.panel,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  line.itemName,
                  style: AppTextStyles.bodyLarge,
                ),
              ),
              Text(
                '${context.l10n.barCheckExpectedLabel}: ${line.expectedQuantity} ${line.unit}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: Key('bar-check-line-${line.itemId}-quantity'),
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.barCheckCountedLabel,
                    suffixText: line.unit,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  key: Key('bar-check-line-${line.itemId}-reason'),
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: context.l10n.barCheckReasonLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                key: Key('bar-check-line-${line.itemId}-save'),
                label: context.l10n.commonSave,
                variant: AppButtonVariant.outlined,
                onPressed: () => context.read<BarCheckCubit>().countLine(
                  itemId: line.itemId,
                  countedQuantity: quantityController.text.trim(),
                  unit: line.unit,
                  reason: reasonController.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
