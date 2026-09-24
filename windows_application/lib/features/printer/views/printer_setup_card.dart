import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import '../services/printer_service.dart';

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
                const Text('Printer Setup', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  branchState.errorMessage == null
                      ? 'No active branch selected'
                      : 'Could not load the active branch.',
                ),
                ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Retry',
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
      final PrinterSetupCubit cubit = context.read<PrinterSetupCubit>();
      if (state.status == PrinterSetupStatus.loading) {
        return const _Card(child: Center(child: CircularProgressIndicator()));
      }
      if (state.branchDefaults == null) {
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Printer Setup', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              const Text('Printer setup could not be loaded.'),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Retry',
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
            const Text('Printer Setup', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Configure the network thermal printer used by this Windows PC or Android tablet.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use Branch Defaults'),
                subtitle: Text(
                  settings.useBranchDefaults
                      ? 'Using the shared default printer for the active branch.'
                      : 'Using this device-only printer override.',
                ),
                value: settings.useBranchDefaults,
                onChanged: state.isTesting ? null : cubit.setUseBranchDefaults,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const Key('printer-name'),
              enabled: local && !state.isTesting,
              initialValue: editable.name,
              decoration: const InputDecoration(labelText: 'Printer Name'),
              onChanged: (String value) =>
                  cubit.updateLocalOverride(editable.copyWith(name: value)),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const Key('printer-ip'),
              enabled: local && !state.isTesting,
              initialValue: editable.ipAddress,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'IP Address'),
              onChanged: (String value) => cubit.updateLocalOverride(
                editable.copyWith(ipAddress: value),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              key: const Key('printer-port'),
              enabled: local && !state.isTesting,
              initialValue: editable.port.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
              onChanged: (String value) => cubit.updateLocalOverride(
                editable.copyWith(port: int.tryParse(value) ?? 0),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<PrinterPaperWidth>(
              key: const Key('printer-paper-width'),
              initialValue: editable.paperWidth,
              decoration: const InputDecoration(labelText: 'Paper Width'),
              items: PrinterPaperWidth.values
                  .map(
                    (PrinterPaperWidth width) =>
                        DropdownMenuItem<PrinterPaperWidth>(
                          value: width,
                          child: Text(width.apiValue),
                        ),
                  )
                  .toList(growable: false),
              onChanged: local && !state.isTesting
                  ? (PrinterPaperWidth? width) {
                      if (width != null) {
                        cubit.updateLocalOverride(
                          editable.copyWith(paperWidth: width),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.failure != null) _ResultBanner(failure: state.failure!),
            if (state.status == PrinterSetupStatus.success)
              const _SuccessBanner(),
            Row(
              children: <Widget>[
                AppButton(
                  label: 'Save Device Settings',
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: state.isTesting ? null : cubit.saveDeviceSettings,
                ),
                const SizedBox(width: AppSpacing.md),
                AppButton(
                  label: state.isTesting
                      ? 'Testing...'
                      : state.failure == null
                      ? 'Test Print'
                      : 'Retry Test Print',
                  icon: state.isTesting ? null : Icons.print_outlined,
                  onPressed: state.isTesting ? null : cubit.testPrint,
                ),
              ],
            ),
          ],
        ),
      );
    },
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

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.lg),
    child: Text('Print successful', style: TextStyle(color: AppColors.success)),
  );
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.failure});
  final PrinterPrintFailure failure;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Text(switch (failure) {
      PrinterPrintFailure.invalidConfiguration => 'Invalid configuration',
      PrinterPrintFailure.timeout =>
        'Printer timeout. Check the printer network and try again.',
      PrinterPrintFailure.unreachable =>
        'Printer unreachable. Check the IP address, port, and network.',
      PrinterPrintFailure.unsupported =>
        'Network printing is unavailable on this platform.',
      PrinterPrintFailure.failed => 'Printer setup could not be loaded.',
    }, style: const TextStyle(color: AppColors.danger)),
  );
}
