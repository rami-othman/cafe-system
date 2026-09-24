import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../printer/models/printer_config.dart';
import '../controllers/cafe_configuration_cubits.dart';
import '../controllers/printing_cubit.dart';

class PrintingScreen extends StatelessWidget {
  const PrintingScreen({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<PrintingCubit, PrintingState>(
    listenWhen: (previous, current) =>
        previous.status != current.status &&
        current.status == CafeConfigurationLoadStatus.success,
    listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.cafeConfigurationPrintingSaved)),
    ),
    builder: (context, state) {
      final l10n = context.l10n;
      final cubit = context.read<PrintingCubit>();
      if (state.status == CafeConfigurationLoadStatus.failure &&
          state.branches.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.cafeConfigurationCouldNotLoad),
              TextButton(onPressed: cubit.load, child: Text(l10n.commonRetry)),
            ],
          ),
        );
      }
      return SingleChildScrollView(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.cafeConfigurationPrinting,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.cafeConfigurationPrintingSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (state.branches.isEmpty &&
                          state.status != CafeConfigurationLoadStatus.loading)
                        Text(l10n.cafeConfigurationNoBranches)
                      else if (state.branches.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.cafeConfigurationBranchName,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                key: const Key('printing-branch'),
                                isExpanded: true,
                                value: state.selectedBranchId,
                                items: state.branches
                                    .map(
                                      (branch) => DropdownMenuItem(
                                        value: branch.id,
                                        child: Text(branch.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged:
                                    state.status ==
                                        CafeConfigurationLoadStatus.submitting
                                    ? null
                                    : (id) async {
                                        if (id == null) return;
                                        if (state.isDirty) {
                                          final discard = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) => AlertDialog(
                                              content: Text(
                                                l10n.cafeConfigurationPrintingDiscard,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                  child: Text(
                                                    l10n.commonCancel,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                  child: Text(
                                                    l10n.cafeConfigurationReset,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (discard != true ||
                                              !context.mounted) {
                                            return;
                                          }
                                        }
                                        await cubit.selectBranch(id);
                                      },
                              ),
                            ),
                          ),
                        ),
                      if (state.branch == null &&
                          state.branches.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        state.status == CafeConfigurationLoadStatus.loading
                            ? const CircularProgressIndicator()
                            : TextButton(
                                onPressed: () =>
                                    cubit.selectBranch(state.selectedBranchId!),
                                child: Text(l10n.commonRetry),
                              ),
                      ],
                      if (state.branch != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.cafeConfigurationReceiptPrinting,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Material(
                          color: AppColors.transparent,
                          child: SwitchListTile.adaptive(
                            key: const Key('printing-enabled'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.cafeConfigurationReceiptPrintingEnabled,
                            ),
                            value: state.config.enabled,
                            onChanged: (enabled) => cubit.update(
                              config: state.config.copyWith(enabled: enabled),
                            ),
                          ),
                        ),
                        if (state.config.enabled) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          _PrinterFields(state: state, cubit: cubit),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        const Divider(height: 1),
                        Material(
                          color: AppColors.transparent,
                          child: SwitchListTile.adaptive(
                            key: const Key('printing-auto'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.cafeConfigurationAutoPrint),
                            value: state.autoPrintAfterPayment,
                            onChanged: (value) =>
                                cubit.update(autoPrintAfterPayment: value),
                          ),
                        ),
                        if (state.error == 'validation')
                          Text(
                            l10n.cafeConfigurationPrinterInvalid,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        if (state.error == 'save')
                          Text(
                            l10n.cafeConfigurationSaveFailed,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            const Spacer(),
                            TextButton(
                              onPressed: state.isDirty ? cubit.reset : null,
                              child: Text(l10n.cafeConfigurationReset),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            FilledButton(
                              onPressed:
                                  state.isDirty &&
                                      state.status !=
                                          CafeConfigurationLoadStatus.submitting
                                  ? cubit.save
                                  : null,
                              child: Text(l10n.cafeConfigurationSaveChanges),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PrinterFields extends StatelessWidget {
  const _PrinterFields({required this.state, required this.cubit});

  final PrintingState state;
  final PrintingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget name = TextFormField(
      key: ValueKey(
        'printing-name-${state.selectedBranchId}-${state.formVersion}',
      ),
      initialValue: state.config.name,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPrinterName),
      onChanged: (value) =>
          cubit.update(config: state.config.copyWith(name: value)),
    );
    final Widget host = TextFormField(
      key: ValueKey(
        'printing-host-${state.selectedBranchId}-${state.formVersion}',
      ),
      initialValue: state.config.ipAddress,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPrinterHost),
      onChanged: (value) =>
          cubit.update(config: state.config.copyWith(ipAddress: value)),
    );
    final Widget port = TextFormField(
      key: ValueKey(
        'printing-port-${state.selectedBranchId}-${state.formVersion}',
      ),
      initialValue: state.config.port.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPrinterPort),
      onChanged: (value) => cubit.update(
        config: state.config.copyWith(port: int.tryParse(value) ?? 0),
      ),
    );
    final Widget width = DropdownButtonFormField<PrinterPaperWidth>(
      key: ValueKey(
        'printing-width-${state.selectedBranchId}-${state.formVersion}',
      ),
      initialValue: state.config.paperWidth,
      decoration: InputDecoration(labelText: l10n.cafeConfigurationPaperWidth),
      items: PrinterPaperWidth.values
          .map(
            (width) =>
                DropdownMenuItem(value: width, child: Text(width.apiValue)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          cubit.update(config: state.config.copyWith(paperWidth: value));
        }
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: <Widget>[
              name,
              const SizedBox(height: AppSpacing.lg),
              host,
              const SizedBox(height: AppSpacing.lg),
              port,
              const SizedBox(height: AppSpacing.lg),
              width,
            ],
          );
        }
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: name),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: host),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(child: port),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: width),
              ],
            ),
          ],
        );
      },
    );
  }
}
