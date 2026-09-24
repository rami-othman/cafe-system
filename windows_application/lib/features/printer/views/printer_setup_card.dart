import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../operational_context/controllers/operational_branch_cubit.dart';
import '../../operational_context/models/operational_branch_state.dart';
import '../../pos/controllers/pos_cubit.dart';
import '../../pos/controllers/pos_state.dart';
import '../controllers/printer_setup_cubit.dart';
import '../models/printer_config.dart';
import '../widgets/printer_config_fields.dart';
import '../widgets/printer_test_print_control.dart';

class PrinterSetupCard extends StatefulWidget {
  const PrinterSetupCard({super.key});

  @override
  State<PrinterSetupCard> createState() => _PrinterSetupCardState();
}

class _PrinterSetupCardState extends State<PrinterSetupCard> {
  @override
  void initState() {
    super.initState();
    final operational = context.read<OperationalBranchCubit>();
    if (operational.state.branches.isEmpty && !operational.state.isLoading) {
      operational.loadBranches(
        preferredBranchId: context.read<PosCubit>().state.branchId,
      );
    } else {
      operational.selectBranch(context.read<PosCubit>().state.branchId);
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<PosCubit, PosState>(
    listenWhen: (previous, current) => previous.branchId != current.branchId,
    listener: (context, state) =>
        context.read<OperationalBranchCubit>().selectBranch(state.branchId),
    child: BlocBuilder<OperationalBranchCubit, OperationalBranchState>(
      builder: (BuildContext context, OperationalBranchState branchState) {
        final l10n = context.l10n;
        if (branchState.isLoading) {
          return const _Card(child: Center(child: CircularProgressIndicator()));
        }
        final bool selected = branchState.branches.any(
          (branch) =>
              branch.id == branchState.selectedBranchId && branch.isActive,
        );
        if (!selected) {
          return _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CardHeader(title: l10n.printerSetupTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  branchState.errorMessage == null
                      ? l10n.printerSetupNoActiveBranch
                      : l10n.printerSetupCouldNotLoadBranch,
                ),
                ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: l10n.commonRetry,
                    icon: Icons.refresh,
                    variant: AppButtonVariant.outlined,
                    onPressed: () =>
                        context.read<OperationalBranchCubit>().loadBranches(
                          preferredBranchId: context
                              .read<PosCubit>()
                              .state
                              .branchId,
                        ),
                  ),
                ],
              ],
            ),
          );
        }
        return _BranchPrinterSetupCard(
          key: ValueKey<int>(branchState.selectedBranchId!),
          branchId: branchState.selectedBranchId!,
        );
      },
    ),
  );
}

class _BranchPrinterSetupCard extends StatelessWidget {
  const _BranchPrinterSetupCard({super.key, required this.branchId});
  final int branchId;

  @override
  Widget build(BuildContext context) => BlocProvider<PrinterSetupCubit>(
    create: (_) => serviceLocator<PrinterSetupCubit>()..load(branchId),
    child: _PrinterSetupPanel(branchId: branchId),
  );
}

class _PrinterSetupPanel extends StatelessWidget {
  const _PrinterSetupPanel({required this.branchId});
  final int branchId;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<PrinterSetupCubit, PrinterSetupState>(
    builder: (BuildContext context, PrinterSetupState state) {
      final l10n = context.l10n;
      final PrinterSetupCubit cubit = context.read<PrinterSetupCubit>();
      if (state.status == PrinterSetupStatus.loading) {
        return const _Card(child: Center(child: CircularProgressIndicator()));
      }
      if (state.branchDefaults == null) {
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CardHeader(title: l10n.printerSetupTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.printerSetupCouldNotLoad),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.commonRetry,
                icon: Icons.refresh,
                variant: AppButtonVariant.outlined,
                onPressed: () => cubit.load(branchId),
              ),
            ],
          ),
        );
      }
      final DevicePrinterSettings settings = state.deviceSettings;
      final PrinterConfig editable = settings.useBranchDefaults
          ? state.branchDefaults!
          : settings.localOverride;
      final bool local = !settings.useBranchDefaults;
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardHeader(title: l10n.printerSetupTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.printerSetupDescription),
            const SizedBox(height: AppSpacing.lg),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.printerSetupUseBranchDefaults),
                subtitle: Text(
                  settings.useBranchDefaults
                      ? l10n.printerSetupUsingBranchDefaults
                      : l10n.printerSetupUsingLocalOverride,
                ),
                value: settings.useBranchDefaults,
                onChanged: state.isTesting ? null : cubit.setUseBranchDefaults,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrinterConfigFields(
              nameKey: const Key('printer-name'),
              hostKey: const Key('printer-ip'),
              portKey: const Key('printer-port'),
              paperWidthKey: const Key('printer-paper-width'),
              config: editable,
              enabled: local && !state.isTesting,
              onChanged: cubit.updateLocalOverride,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.failure != null)
              PrinterResultBanner(failure: state.failure!),
            if (state.status == PrinterSetupStatus.success)
              const PrinterSuccessBanner(),
            Row(
              children: <Widget>[
                AppButton(
                  label: l10n.printerSetupSaveDeviceSettings,
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: state.isTesting ? null : cubit.saveDeviceSettings,
                ),
                const SizedBox(width: AppSpacing.md),
                AppButton(
                  label: state.isTesting
                      ? l10n.printerTesting
                      : state.failure == null
                      ? l10n.printerTestPrint
                      : l10n.printerRetryTestPrint,
                  icon: state.isTesting ? null : Icons.print_outlined,
                  onPressed: state.isTesting
                      ? null
                      : () => cubit.testPrint(Localizations.localeOf(context)),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Text(title, style: AppTextStyles.titleMedium),
      const SizedBox(width: AppSpacing.sm),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: AppRadius.pillRadius,
        ),
        child: Text(
          context.l10n.printerSetupThisDevice,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
        ),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.panel,
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
